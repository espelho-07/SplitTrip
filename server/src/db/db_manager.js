const fs = require('fs');
const PostgresAdapter = require('./postgres_adapter');
const MigrationRunner = require('./migration_runner');
const env = require('../config/env');

class DatabaseManager {
  constructor() {
    this.pgAdapter = process.env.DATABASE_URL ? new PostgresAdapter(process.env.DATABASE_URL) : null;
    this.isReady = false;
    this.lastError = null;
  }

  get isPostgresActive() {
    return this.pgAdapter !== null && this.pgAdapter.isConnected;
  }

  getAdapter() {
    if (process.env.DB_ENGINE === 'memory') {
      return null;
    }
    return this.pgAdapter;
  }

  async init() {
    console.log('[DB] initialization started');

    if (this.isPostgresActive) {
      try {
        // Finite 15-second timeout for DB connect and migration
        const initPromise = (async () => {
          await this.pgAdapter.query('SELECT 1');
          console.log('[DB] connection established');

          console.log('[Kith Database] Running database schema migrations...');
          const migrationResult = await MigrationRunner.runMigrations(this.pgAdapter);
          console.log('[DB] migrations completed');
          console.log('[Kith Database] Migration summary:', migrationResult);
          const { db } = require('./database');
          db.setPostgresAdapter(this.pgAdapter);
          this.isReady = true;
          this.lastError = null;
        })();

        const timeoutPromise = new Promise((_, reject) =>
          setTimeout(() => reject(new Error('PostgreSQL initialization timed out after 15s')), 15000)
        );

        await Promise.race([initPromise, timeoutPromise]);
      } catch (err) {
        this.isReady = false;
        this.lastError = err.message;
        console.error('[Kith Database] PostgreSQL initialization warning:', err.message);
      }
    } else {
      console.log(`[Kith Database] Using file-based storage fallback at: ${env.DATA_DIR}`);
      try {
        if (!fs.existsSync(env.DATA_DIR)) {
          fs.mkdirSync(env.DATA_DIR, { recursive: true });
        }
        this.isReady = true;
        this.lastError = null;
        console.log('[DB] connection established (local storage)');
      } catch (err) {
        this.isReady = false;
        this.lastError = err.message;
        console.error('[Kith Database] Local storage initialization error:', err.message);
      }
    }
  }

  async checkReadiness() {
    if (this.isPostgresActive) {
      try {
        const queryPromise = this.pgAdapter.query('SELECT 1');
        const timeoutPromise = new Promise((_, reject) =>
          setTimeout(() => reject(new Error('Readiness check query timed out')), 3000)
        );
        await Promise.race([queryPromise, timeoutPromise]);

        return {
          status: 'ready',
          service: 'kith-backend',
          database: 'postgresql',
          timestamp: new Date().toISOString(),
        };
      } catch (err) {
        return {
          status: 'not_ready',
          service: 'kith-backend',
          database: 'postgresql',
          error: 'PostgreSQL database unreachable',
          timestamp: new Date().toISOString(),
        };
      }
    }

    if (fs.existsSync(env.DATA_DIR)) {
      return {
        status: 'ready',
        service: 'kith-backend',
        database: 'filesystem',
        timestamp: new Date().toISOString(),
      };
    }

    return {
      status: 'not_ready',
      service: 'kith-backend',
      error: 'Storage directory inaccessible',
      timestamp: new Date().toISOString(),
    };
  }
}

const dbManager = new DatabaseManager();
module.exports = { DatabaseManager, dbManager };
