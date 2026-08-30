const fs = require('fs');
const path = require('path');
const env = require('../config/env');

class Database {
  constructor(dataDir = env.DATA_DIR, options = {}) {
    this.dataDir = dataDir;
    this.inMemory = options.inMemory || process.env.NODE_ENV === 'test';
    this.tables = {
      users: new Map(),
      sessions: new Map(),
      trips: new Map(),
      trip_members: new Map(),
      invites: new Map(),
      expenses: new Map(),
      settlements: new Map(),
      activity_logs: new Map(),
      personal_expenses: new Map(),
      personal_debts: new Map(),
      personal_repayments: new Map(),
      personal_budgets: new Map(),
      trip_journey_moments: new Map(),
      user_fcm_tokens: new Map(),
      notifications: new Map(),
      processed_operations: new Map(),
    };

    // Secondary Indexes for O(1) concurrent lookups
    this.indexes = {
      users: { byEmail: new Map(), byKeyHash: new Map() },
      sessions: { byToken: new Map(), byUserId: new Map() },
      trips: { byInviteCode: new Map() },
      trip_members: { byTripId: new Map(), byUserId: new Map() },
      expenses: { byTripId: new Map() },
      settlements: { byTripId: new Map() },
      notifications: { byRecipientUserId: new Map() },
      processed_operations: { byTripId: new Map() },
    };

    if (!this.inMemory) {
      this._initStorage();
    }
  }

  _initStorage() {
    if (!fs.existsSync(this.dataDir)) {
      fs.mkdirSync(this.dataDir, { recursive: true });
    }

    for (const tableName of Object.keys(this.tables)) {
      const filePath = path.join(this.dataDir, `${tableName}.json`);
      if (fs.existsSync(filePath)) {
        try {
          const raw = fs.readFileSync(filePath, 'utf8');
          const data = JSON.parse(raw);
          const map = new Map();
          for (const item of data) {
            if (item && item.id) {
              map.set(item.id, item);
              this._addToIndexes(tableName, item);
            }
          }
          this.tables[tableName] = map;
        } catch (e) {
          console.error(`Failed to load ${tableName}.json, initializing empty map`, e);
          this.tables[tableName] = new Map();
        }
      } else {
        this._persistTable(tableName);
      }
    }
  }

  _addToIndexes(tableName, item) {
    if (!item) return;

    if (tableName === 'users') {
      if (item.email) this.indexes.users.byEmail.set(item.email.toLowerCase(), item.id);
      if (item.recoveryKeyHash) this.indexes.users.byKeyHash.set(item.recoveryKeyHash, item.id);
    } else if (tableName === 'sessions') {
      if (item.token) this.indexes.sessions.byToken.set(item.token, item.id);
      if (item.userId) {
        if (!this.indexes.sessions.byUserId.has(item.userId)) {
          this.indexes.sessions.byUserId.set(item.userId, new Set());
        }
        this.indexes.sessions.byUserId.get(item.userId).add(item.id);
      }
    } else if (tableName === 'trips') {
      if (item.inviteCode) this.indexes.trips.byInviteCode.set(item.inviteCode.toUpperCase(), item.id);
    } else if (tableName === 'trip_members') {
      if (item.tripId) {
        if (!this.indexes.trip_members.byTripId.has(item.tripId)) {
          this.indexes.trip_members.byTripId.set(item.tripId, new Set());
        }
        this.indexes.trip_members.byTripId.get(item.tripId).add(item.id);
      }
      if (item.userId) {
        if (!this.indexes.trip_members.byUserId.has(item.userId)) {
          this.indexes.trip_members.byUserId.set(item.userId, new Set());
        }
        this.indexes.trip_members.byUserId.get(item.userId).add(item.id);
      }
    } else if (tableName === 'expenses') {
      if (item.tripId) {
        if (!this.indexes.expenses.byTripId.has(item.tripId)) {
          this.indexes.expenses.byTripId.set(item.tripId, new Set());
        }
        this.indexes.expenses.byTripId.get(item.tripId).add(item.id);
      }
    } else if (tableName === 'settlements') {
      if (item.tripId) {
        if (!this.indexes.settlements.byTripId.has(item.tripId)) {
          this.indexes.settlements.byTripId.set(item.tripId, new Set());
        }
        this.indexes.settlements.byTripId.get(item.tripId).add(item.id);
      }
    } else if (tableName === 'notifications') {
      if (item.recipientUserId) {
        if (!this.indexes.notifications.byRecipientUserId.has(item.recipientUserId)) {
          this.indexes.notifications.byRecipientUserId.set(item.recipientUserId, new Set());
        }
        this.indexes.notifications.byRecipientUserId.get(item.recipientUserId).add(item.id);
      }
    } else if (tableName === 'processed_operations') {
      if (item.tripId) {
        if (!this.indexes.processed_operations.byTripId.has(item.tripId)) {
          this.indexes.processed_operations.byTripId.set(item.tripId, new Set());
        }
        this.indexes.processed_operations.byTripId.get(item.tripId).add(item.id);
      }
    }
  }

  _removeFromIndexes(tableName, item) {
    if (!item) return;

    if (tableName === 'users') {
      if (item.email) this.indexes.users.byEmail.delete(item.email.toLowerCase());
      if (item.recoveryKeyHash) this.indexes.users.byKeyHash.delete(item.recoveryKeyHash);
    } else if (tableName === 'sessions') {
      if (item.token) this.indexes.sessions.byToken.delete(item.token);
      if (item.userId && this.indexes.sessions.byUserId.has(item.userId)) {
        this.indexes.sessions.byUserId.get(item.userId).delete(item.id);
      }
    } else if (tableName === 'trips') {
      if (item.inviteCode) this.indexes.trips.byInviteCode.delete(item.inviteCode.toUpperCase());
    } else if (tableName === 'trip_members') {
      if (item.tripId && this.indexes.trip_members.byTripId.has(item.tripId)) {
        this.indexes.trip_members.byTripId.get(item.tripId).delete(item.id);
      }
      if (item.userId && this.indexes.trip_members.byUserId.has(item.userId)) {
        this.indexes.trip_members.byUserId.get(item.userId).delete(item.id);
      }
    } else if (tableName === 'expenses') {
      if (item.tripId && this.indexes.expenses.byTripId.has(item.tripId)) {
        this.indexes.expenses.byTripId.get(item.tripId).delete(item.id);
      }
    } else if (tableName === 'settlements') {
      if (item.tripId && this.indexes.settlements.byTripId.has(item.tripId)) {
        this.indexes.settlements.byTripId.get(item.tripId).delete(item.id);
      }
    } else if (tableName === 'notifications') {
      if (item.recipientUserId && this.indexes.notifications.byRecipientUserId.has(item.recipientUserId)) {
        this.indexes.notifications.byRecipientUserId.get(item.recipientUserId).delete(item.id);
      }
    } else if (tableName === 'processed_operations') {
      if (item.tripId && this.indexes.processed_operations.byTripId.has(item.tripId)) {
        this.indexes.processed_operations.byTripId.get(item.tripId).delete(item.id);
      }
    }
  }

  _persistTable(tableName) {
    if (this.inMemory) return;
    try {
      const filePath = path.join(this.dataDir, `${tableName}.json`);
      const tmpPath = path.join(this.dataDir, `${tableName}.${Date.now()}.${Math.random().toString(36).substring(2, 6)}.tmp`);
      const data = Array.from(this.tables[tableName].values());
      fs.writeFileSync(tmpPath, JSON.stringify(data, null, 2), 'utf8');
      fs.renameSync(tmpPath, filePath);
    } catch (e) {
      try {
        const filePath = path.join(this.dataDir, `${tableName}.json`);
        const data = Array.from(this.tables[tableName].values());
        fs.writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf8');
      } catch (_) {}
    }
  }

  // Generic Operations
  get(tableName, id) {
    const table = this.tables[tableName];
    if (!table) return null;
    const item = table.get(id);
    return item ? { ...item } : null;
  }

  find(tableName, predicate) {
    const table = this.tables[tableName];
    if (!table) return [];
    const results = [];
    for (const item of table.values()) {
      if (predicate(item)) {
        results.push({ ...item });
      }
    }
    return results;
  }

  findOne(tableName, predicate) {
    const table = this.tables[tableName];
    if (!table) return null;
    for (const item of table.values()) {
      if (predicate(item)) {
        return { ...item };
      }
    }
    return null;
  }

  insert(tableName, item) {
    const table = this.tables[tableName];
    if (!table) throw new Error(`Unknown table ${tableName}`);
    if (!item.id) throw new Error('Item must have an id');
    if (table.has(item.id)) throw new Error(`Item ${item.id} already exists in ${tableName}`);

    // Enforce UNIQUE(tripId, userId) for active/claimed memberships
    if (tableName === 'trip_members' && item.tripId && item.userId && !item.userId.startsWith('unclaimed_')) {
      for (const existing of table.values()) {
        if (existing.tripId === item.tripId && existing.userId === item.userId && existing.id !== item.id) {
          throw new Error(`User ${item.userId} is already a member of trip ${item.tripId}`);
        }
      }
    }

    const cloned = { ...item };
    table.set(item.id, cloned);
    this._addToIndexes(tableName, cloned);
    this._persistTable(tableName);
    return { ...cloned };
  }

  update(tableName, id, updaterOrPartial) {
    const table = this.tables[tableName];
    if (!table || !table.has(id)) return null;

    const existing = table.get(id);
    this._removeFromIndexes(tableName, existing);

    const updated = typeof updaterOrPartial === 'function'
      ? updaterOrPartial(existing)
      : { ...existing, ...updaterOrPartial, id };

    table.set(id, updated);
    this._addToIndexes(tableName, updated);
    this._persistTable(tableName);
    return { ...updated };
  }

  delete(tableName, id) {
    const table = this.tables[tableName];
    if (!table || !table.has(id)) return false;

    const existing = table.get(id);
    this._removeFromIndexes(tableName, existing);
    table.delete(id);
    this._persistTable(tableName);
    return true;
  }

  // Clear all data (used in test teardown)
  clearAll() {
    for (const tableName of Object.keys(this.tables)) {
      this.tables[tableName].clear();
      this._persistTable(tableName);
    }
    for (const group of Object.values(this.indexes)) {
      for (const map of Object.values(group)) {
        map.clear();
      }
    }
  }
}

const dbInstance = new Database();
module.exports = { Database, db: dbInstance };
