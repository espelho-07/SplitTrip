const { Pool } = require('pg');

class PostgresAdapter {
  constructor(connectionString = process.env.DATABASE_URL) {
    this.connectionString = connectionString;
    this.pool = null;
    if (this.connectionString) {
      this._initPool();
    }
  }

  _initPool() {
    const isCloud = this.connectionString.includes('supabase') ||
                    this.connectionString.includes('render.com') ||
                    this.connectionString.includes('amazonaws.com') ||
                    this.connectionString.includes('pooler.supabase.com') ||
                    process.env.NODE_ENV === 'staging' ||
                    process.env.NODE_ENV === 'production';

    this.pool = new Pool({
      connectionString: this.connectionString,
      ssl: isCloud ? { rejectUnauthorized: false } : false,
      max: 10,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 8000,
      statement_timeout: 10000,
    });

    this.pool.on('error', (err) => {
      console.error('[DB] Unexpected error on idle PostgreSQL client:', err.message);
    });
  }

  get isConnected() {
    return this.pool !== null;
  }

  /**
   * Masks sensitive credentials when serialized to JSON
   */
  toJSON() {
    return {
      isConnected: this.isConnected,
      sanitizedHost: this.connectionString ? this.connectionString.replace(/:[^:@]+@/, ':***@') : null,
    };
  }

  async query(text, params = []) {
    if (!this.pool) {
      throw new Error('PostgreSQL client is not configured with a DATABASE_URL');
    }
    const start = Date.now();
    const res = await this.pool.query(text, params);
    const duration = Date.now() - start;
    if (process.env.DEBUG_SQL) {
      console.log('Executed query', { text, duration, rows: res.rowCount });
    }
    return res;
  }

  async transaction(callback) {
    if (!this.pool) {
      throw new Error('PostgreSQL client is not configured with a DATABASE_URL');
    }
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const result = await callback(client);
      await client.query('COMMIT');
      return result;
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }

  async close() {
    if (this.pool) {
      await this.pool.end();
      this.pool = null;
    }
  }
}

module.exports = PostgresAdapter;
