const { WebSocketServer, WebSocket } = require('ws');
const { db } = require('../db/database');

class RealtimeHub {
  constructor() {
    this.wss = null;
    // Map of tripId -> Set of WebSockets
    this.tripRooms = new Map();
    // Map of WebSocket -> Set of subscribed tripIds
    this.clientSubscriptions = new Map();
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

  _handleClientMessage(ws, message) {
    const { action, tripId, token } = message;

    // Handle authentication message
    if (action === 'auth') {
      if (token) {
        const session = db.findOne('sessions', (s) => s.token === token);
        if (session) {
          ws.user = db.get('users', session.userId);
          ws.send(JSON.stringify({ type: 'auth_success', user: ws.user }));
          return;
        }
      }
      ws.send(JSON.stringify({ type: 'auth_failed', message: 'Invalid session token' }));
      return;
    }

    // Handle room subscription
    if (action === 'subscribe') {
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
        clientSubs.add(tripId);
      }

      ws.send(JSON.stringify({ type: 'subscribed', tripId }));
      return;
    }

    // Handle unsubscribe
    if (action === 'unsubscribe') {
      if (tripId && this.tripRooms.has(tripId)) {
        this.tripRooms.get(tripId).delete(ws);
      }
      const clientSubs = this.clientSubscriptions.get(ws);
      if (clientSubs && tripId) {
        clientSubs.delete(tripId);
      }
      ws.send(JSON.stringify({ type: 'unsubscribed', tripId }));
      return;
    }
  }

  _cleanupClient(ws) {
    const clientSubs = this.clientSubscriptions.get(ws);
    if (clientSubs) {
      for (const tripId of clientSubs) {
        if (this.tripRooms.has(tripId)) {
          this.tripRooms.get(tripId).delete(ws);
        }
      }
      this.clientSubscriptions.delete(ws);
    }
  }

  broadcastToTrip(tripId, eventType, data, excludeWs = null) {
    const room = this.tripRooms.get(tripId);
    if (!room || room.size === 0) return;

    const payload = JSON.stringify({
      type: eventType,
      tripId,
      data,
      timestamp: new Date().toISOString(),
    });

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
