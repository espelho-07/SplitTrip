const fs = require('fs');
const PostgresAdapter = require('./postgres_adapter');
const MigrationRunner = require('./migration_runner');
const env = require('../config/env');

class DatabaseManager {
  constructor() {
    this.pgAdapter = process.env.DATABASE_URL ? new PostgresAdapter(process.env.DATABASE_URL) : null;
  }

  get isPostgresActive() {
    return this.pgAdapter !== null && this.pgAdapter.isConnected;
  }

  async init() {
    if (this.isPostgresActive) {
      console.log('[Kith Database] Initializing PostgreSQL connection...');
      try {
        await this.pgAdapter.query('SELECT 1');
        console.log('[Kith Database] PostgreSQL connection verified.');
        console.log('[Kith Database] Running database schema migrations...');
        const migrationResult = await MigrationRunner.runMigrations(this.pgAdapter);
        console.log('[Kith Database] Migrations complete:', migrationResult);
      } catch (err) {
        console.error('[Kith Database] PostgreSQL initialization warning:', err.message);
      }
    } else {
      console.log(`[Kith Database] Using file-based storage fallback at: ${env.DATA_DIR}`);
      if (!fs.existsSync(env.DATA_DIR)) {
        fs.mkdirSync(env.DATA_DIR, { recursive: true });
      }
    }
  }

  async checkReadiness() {
    if (this.isPostgresActive) {
      try {
        await this.pgAdapter.query('SELECT 1');
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
          error: 'PostgreSQL database unreachable',
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
    };
  }
}

const dbManager = new DatabaseManager();
module.exports = { DatabaseManager, dbManager };
