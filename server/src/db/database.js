const fs = require('fs');
const path = require('path');
const env = require('../config/env');

class Database {
  constructor(dataDir = env.DATA_DIR, options = {}) {
    this.dataDir = dataDir;
    this.inMemory = options.inMemory || false;
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

  _persistTable(tableName) {
    if (this.inMemory) return;
    try {
      const filePath = path.join(this.dataDir, `${tableName}.json`);
      const tmpPath = path.join(this.dataDir, `${tableName}.${Date.now()}.${Math.random().toString(36).substring(2, 6)}.tmp`);
      const data = Array.from(this.tables[tableName].values());
      fs.writeFileSync(tmpPath, JSON.stringify(data, null, 2), 'utf8');
      fs.renameSync(tmpPath, filePath);
    } catch (e) {
      // Fallback direct write if atomic rename is constrained on filesystem
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
    this._persistTable(tableName);
    return { ...cloned };
  }

  update(tableName, id, updaterOrPartial) {
    const table = this.tables[tableName];
    if (!table || !table.has(id)) return null;

    const existing = table.get(id);
    const updated = typeof updaterOrPartial === 'function'
      ? updaterOrPartial(existing)
      : { ...existing, ...updaterOrPartial, id };

    table.set(id, updated);
    this._persistTable(tableName);
    return { ...updated };
  }

  delete(tableName, id) {
    const table = this.tables[tableName];
    if (!table || !table.has(id)) return false;

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
  }
}

const dbInstance = new Database();
module.exports = { Database, db: dbInstance };
