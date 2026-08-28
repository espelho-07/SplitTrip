const { WebSocketServer, WebSocket } = require('ws');
const crypto = require('crypto');
const { db } = require('../db/database');

class RealtimeHub {
  constructor() {
    this.wss = null;
    // Map of tripId -> Set of WebSockets
    this.tripRooms = new Map();
    // Map of userId -> Set of WebSockets
    this.userRooms = new Map();
    // Map of WebSocket -> Set of subscribed room keys ('trip:xxx' or 'user:xxx')
    this.clientSubscriptions = new Map();
    // In-memory sliding buffer for recent events: roomKey -> Array of events (max 100)
    this.eventBuffer = new Map();
    this.MAX_BUFFER_PER_ROOM = 100;
  }

  attach(server) {
    this.wss = new WebSocketServer({ server, path: '/ws' });

    this.wss.on('connection', (ws, req) => {
      // Extract token from URL query string if provided
      const url = new URL(req.url, 'http://localhost');
      const token = url.searchParams.get('token');
      let authenticatedUser = null;

      if (token) {
        const session = db.findOne('sessions', (s) => s.token === token);
        if (session) {
          authenticatedUser = db.get('users', session.userId);
        }
      }

      ws.user = authenticatedUser;
      ws.isAlive = true;
      this.clientSubscriptions.set(ws, new Set());

      if (authenticatedUser) {
        this._subscribeUserRoom(ws, authenticatedUser.id);
      }

      ws.on('pong', () => {
        ws.isAlive = true;
      });

      ws.on('message', (messageRaw) => {
        try {
          const message = JSON.parse(messageRaw.toString());
          this._handleClientMessage(ws, message);
        } catch (e) {
          ws.send(JSON.stringify({ type: 'error', message: 'Invalid JSON payload' }));
        }
      });

      ws.on('close', () => {
        this._cleanupClient(ws);
      });

      // Send welcome handshake
      ws.send(JSON.stringify({
        type: 'connected',
        userId: authenticatedUser ? authenticatedUser.id : null,
        timestamp: new Date().toISOString(),
      }));
    });

    // Heartbeat keepalive
    this.heartbeatInterval = setInterval(() => {
      if (!this.wss) return;
      this.wss.clients.forEach((ws) => {
        if (!ws.isAlive) {
          this._cleanupClient(ws);
          return ws.terminate();
        }
        ws.isAlive = false;
        ws.ping();
      });
    }, 30000);
  }

  _subscribeUserRoom(ws, userId) {
    if (!this.userRooms.has(userId)) {
      this.userRooms.set(userId, new Set());
    }
    this.userRooms.get(userId).add(ws);

    const clientSubs = this.clientSubscriptions.get(ws);
    if (clientSubs) {
      clientSubs.add(`user:${userId}`);
    }
  }

  _handleClientMessage(ws, message) {
    const action = message.action || message.type;
    const { tripId, userId, token, sinceTimestamp } = message;

    // Handle authentication message
    if (action === 'auth') {
      if (token) {
        const session = db.findOne('sessions', (s) => s.token === token);
        if (session) {
          ws.user = db.get('users', session.userId);
          if (ws.user) {
            this._subscribeUserRoom(ws, ws.user.id);
          }
          ws.send(JSON.stringify({ type: 'auth_success', user: ws.user }));
          return;
        }
      }
      ws.send(JSON.stringify({ type: 'auth_failed', message: 'Invalid session token' }));
      return;
    }

    // Handle room subscription
    if (action === 'subscribe') {
      // User room subscription
      if (userId || message.scope === 'user') {
        const targetUserId = userId || (ws.user ? ws.user.id : null);
        if (targetUserId) {
          this._subscribeUserRoom(ws, targetUserId);
          ws.send(JSON.stringify({ type: 'subscribed', scope: 'user', userId: targetUserId }));
          return;
        }
      }

      if (!tripId) {
        ws.send(JSON.stringify({ type: 'error', message: 'tripId is required for subscribe' }));
        return;
      }

      // Check authorization if user is authenticated
      if (ws.user) {
        const membership = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === ws.user.id);
        if (!membership) {
          ws.send(JSON.stringify({ type: 'error', message: `Not a member of trip ${tripId}` }));
          return;
        }
      }

      if (!this.tripRooms.has(tripId)) {
        this.tripRooms.set(tripId, new Set());
      }
      this.tripRooms.get(tripId).add(ws);

      const clientSubs = this.clientSubscriptions.get(ws);
      if (clientSubs) {
        clientSubs.add(`trip:${tripId}`);
      }

      ws.send(JSON.stringify({ type: 'subscribed', tripId }));
      return;
    }

    // Handle catchup request on reconnect
    if (action === 'catchup') {
      const roomKey = tripId ? `trip:${tripId}` : (userId ? `user:${userId}` : (ws.user ? `user:${ws.user.id}` : null));
      if (!roomKey) {
        ws.send(JSON.stringify({ type: 'error', message: 'room identifier required for catchup' }));
        return;
      }

      const events = this.eventBuffer.get(roomKey) || [];
      const sinceDate = sinceTimestamp ? new Date(sinceTimestamp) : new Date(0);
      const missedEvents = events.filter((e) => new Date(e.timestamp) > sinceDate);

      ws.send(JSON.stringify({
        type: 'catchup_response',
        roomKey,
        events: missedEvents,
        timestamp: new Date().toISOString(),
      }));
      return;
    }

    // Handle unsubscribe
    if (action === 'unsubscribe') {
      if (tripId && this.tripRooms.has(tripId)) {
        this.tripRooms.get(tripId).delete(ws);
      }
      const clientSubs = this.clientSubscriptions.get(ws);
      if (clientSubs && tripId) {
        clientSubs.delete(`trip:${tripId}`);
      }
      ws.send(JSON.stringify({ type: 'unsubscribed', tripId }));
      return;
    }
  }

  _cleanupClient(ws) {
    const clientSubs = this.clientSubscriptions.get(ws);
    if (clientSubs) {
      for (const roomKey of clientSubs) {
        if (roomKey.startsWith('trip:')) {
          const tripId = roomKey.replace('trip:', '');
          if (this.tripRooms.has(tripId)) {
            this.tripRooms.get(tripId).delete(ws);
          }
        } else if (roomKey.startsWith('user:')) {
          const userId = roomKey.replace('user:', '');
          if (this.userRooms.has(userId)) {
            this.userRooms.get(userId).delete(ws);
          }
        }
      }
      this.clientSubscriptions.delete(ws);
    }
  }

  _pushToBuffer(roomKey, event) {
    if (!this.eventBuffer.has(roomKey)) {
      this.eventBuffer.set(roomKey, []);
    }
    const buf = this.eventBuffer.get(roomKey);
    buf.push(event);
    if (buf.length > this.MAX_BUFFER_PER_ROOM) {
      buf.shift();
    }
  }

  broadcastToTrip(tripId, eventType, data, excludeWs = null) {
    const room = this.tripRooms.get(tripId);
    const now = new Date().toISOString();
    const eventId = `evt_${crypto.randomUUID().replace(/-/g, '').substring(0, 12)}`;

    const event = {
      eventId,
      type: eventType,
      eventType,
      entityType: eventType.split('_')[0] || 'unknown',
      entityId: data?.id || data?.expense?.id || data?.settlement?.id || data?.moment?.id || null,
      tripId,
      actorId: data?.actorId || null,
      data,
      payload: data,
      version: 1,
      timestamp: now,
    };

    this._pushToBuffer(`trip:${tripId}`, event);

    if (!room || room.size === 0) return;

    const payload = JSON.stringify(event);

    for (const client of room) {
      if (client !== excludeWs && client.readyState === WebSocket.OPEN) {
        try {
          client.send(payload);
        } catch (e) {
          console.error(`Failed to send event to client in trip ${tripId}`, e);
        }
      }
    }
  }

  broadcastToUser(userId, eventType, data, excludeWs = null) {
    const room = this.userRooms.get(userId);
    const now = new Date().toISOString();
    const eventId = `evt_${crypto.randomUUID().replace(/-/g, '').substring(0, 12)}`;

    const event = {
      eventId,
      type: eventType,
      eventType,
      entityType: eventType.split('_')[0] || 'personal',
      entityId: data?.id || data?.expense?.id || data?.debt?.id || null,
      userId,
      actorId: userId,
      data,
      payload: data,
      version: 1,
      timestamp: now,
    };

    this._pushToBuffer(`user:${userId}`, event);

    if (!room || room.size === 0) return;

    const payload = JSON.stringify(event);

    for (const client of room) {
      if (client !== excludeWs && client.readyState === WebSocket.OPEN) {
        try {
          client.send(payload);
        } catch (e) {
          console.error(`Failed to send event to user ${userId}`, e);
        }
      }
    }
  }

  close() {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
    }
    if (this.wss) {
      this.wss.close();
    }
  }
}

const realtimeHubInstance = new RealtimeHub();
module.exports = { RealtimeHub, realtimeHub: realtimeHubInstance };

