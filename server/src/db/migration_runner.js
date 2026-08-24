const fs = require('fs');
const path = require('path');

class MigrationRunner {
  static async runMigrations(adapter, migrationsDir = path.join(__dirname, '..', '..', 'migrations')) {
    if (!adapter.isConnected) {
      throw new Error('Cannot run migrations without an active database connection');
    }

    await adapter.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version VARCHAR(255) PRIMARY KEY,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `);

    const files = fs.readdirSync(migrationsDir)
      .filter((f) => f.endsWith('.sql'))
      .sort();

    const appliedResult = await adapter.query('SELECT version FROM schema_migrations');
    const appliedVersions = new Set(appliedResult.rows.map((r) => r.version));

    const newlyApplied = [];

    for (const file of files) {
      if (!appliedVersions.has(file)) {
        const filePath = path.join(migrationsDir, file);
        const sql = fs.readFileSync(filePath, 'utf8');

        await adapter.transaction(async (client) => {
          await client.query(sql);
          await client.query('INSERT INTO schema_migrations (version) VALUES ($1)', [file]);
        });

        newlyApplied.push(file);
      }
    }

    return {
      totalFiles: files.length,
      newlyApplied,
      alreadyApplied: appliedVersions.size,
    };
  }
}

module.exports = MigrationRunner;
