const { describe, it } = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');

describe('Supabase Migrations Integrity & Foreign Key Static Audit', () => {
  const migrationsDir = path.join(__dirname, '..', '..', 'supabase', 'migrations');

  it('Verifies all migration files exist in supabase/migrations/ in valid sequence', () => {
    assert.ok(fs.existsSync(migrationsDir), 'supabase/migrations directory must exist');
    const files = fs.readdirSync(migrationsDir).filter(f => f.endsWith('.sql'));
    assert.strictEqual(files.length, 13, `Expected 13 migration files, found ${files.length}: ${files.join(', ')}`);
  });

  it('Verifies all migration files use valid 14-digit timestamp prefixes in ascending order', () => {
    const files = fs.readdirSync(migrationsDir).filter(f => f.endsWith('.sql')).sort();
    
    // Check 14-digit format: YYYYMMDDHHMMSS_name.sql
    const timestampRegex = /^\d{14}_[\w-]+\.sql$/;
    for (const file of files) {
      assert.ok(timestampRegex.test(file), `File ${file} must follow YYYYMMDDHHMMSS_name.sql naming convention`);
    }

    // Verify expected exact filenames
    const expected = [
      '20260901000001_schema_baseline.sql',
      '20260901000002_rls_security_policies.sql',
      '20261031000001_virtual_members_and_data_integrity.sql',
      '20261031000002_ipo_management_system.sql',
      '20261101000001_rls_security_hardening.sql',
      '20261101000002_harden_budgets_and_notifications_rls.sql',
      '20261101000003_ipo_guru_centralized_cache.sql',
      '20261101000004_ipo_internal_tables_defense_in_depth.sql',
      '20261101000005_ipo_gmp_last_valid_at.sql',
      '20261101000006_ipo_atomic_upsert_and_quota_lock.sql',
      '20261120000001_offline_sync_and_free_tier_optimization.sql',
      '20261120000002_allow_unclaimed_member_spot_claim.sql',
      '20261120000003_authoritative_account_deletion_and_revocation.sql'
    ];

    assert.deepStrictEqual(files, expected, 'Migration files must match exact ordered sequence');
  });

  it('Verifies every foreign key REFERENCES points to an existing relation', () => {
    const files = fs.readdirSync(migrationsDir).filter(f => f.endsWith('.sql')).sort();
    const createdTables = new Set();
    const allForeignKeys = [];

    // Built-in PostgreSQL / Supabase extensions tables allowed
    const systemCatalogs = new Set(['auth.users', 'extensions.pg_stat_statements']);

    for (const file of files) {
      const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');
      
      // Discover created tables
      const tableMatches = sql.matchAll(/CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?([a-zA-Z0-9_]+)/gi);
      for (const match of tableMatches) {
        createdTables.add(match[1].toLowerCase());
      }

      // Discover REFERENCES
      const refMatches = sql.matchAll(/REFERENCES\s+([a-zA-Z0-9_\.]+)\s*\(([a-zA-Z0-9_]+)\)/gi);
      for (const match of refMatches) {
        allForeignKeys.push({
          file,
          targetTable: match[1].toLowerCase(),
          targetColumn: match[2].toLowerCase(),
          fullMatch: match[0]
        });
      }
    }

    // Regression check: verify nonexistent table "user_accounts" is NEVER referenced
    const invalidAccountsRef = allForeignKeys.filter(fk => fk.targetTable === 'user_accounts');
    assert.strictEqual(
      invalidAccountsRef.length,
      0,
      `Nonexistent table "user_accounts" must NOT be referenced! Found: ${JSON.stringify(invalidAccountsRef)}`
    );

    // Verify all FK targets exist
    for (const fk of allForeignKeys) {
      const isCreated = createdTables.has(fk.targetTable) || systemCatalogs.has(fk.targetTable);
      assert.ok(
        isCreated,
        `In ${fk.file}: Foreign key reference "${fk.fullMatch}" points to table "${fk.targetTable}" which is never created!`
      );
    }
  });

  it('Verifies trigger functions kith_log_sync_event and kith_acquire_sync_lock have SECURITY DEFINER', () => {
    const hardeningSql = fs.readFileSync(
      path.join(migrationsDir, '20261101000001_rls_security_hardening.sql'),
      'utf8'
    );

    // kith_acquire_sync_lock
    assert.ok(
      hardeningSql.includes('CREATE OR REPLACE FUNCTION kith_acquire_sync_lock()'),
      'Must define kith_acquire_sync_lock'
    );
    const acquireLockDef = hardeningSql.substring(
      hardeningSql.indexOf('CREATE OR REPLACE FUNCTION kith_acquire_sync_lock()'),
      hardeningSql.indexOf('CREATE TRIGGER trg_lock_trips')
    );
    assert.ok(acquireLockDef.includes('SECURITY DEFINER'), 'kith_acquire_sync_lock must be SECURITY DEFINER');
    assert.ok(acquireLockDef.includes('SET search_path = public, pg_temp'), 'kith_acquire_sync_lock must have search_path');

    // kith_log_sync_event
    assert.ok(
      hardeningSql.includes('CREATE OR REPLACE FUNCTION kith_log_sync_event()'),
      'Must define kith_log_sync_event'
    );
    const logEventDef = hardeningSql.substring(
      hardeningSql.indexOf('CREATE OR REPLACE FUNCTION kith_log_sync_event()'),
      hardeningSql.indexOf('CREATE TRIGGER trg_events_trips')
    );
    assert.ok(logEventDef.includes('SECURITY DEFINER'), 'kith_log_sync_event must be SECURITY DEFINER');
    assert.ok(logEventDef.includes('SET search_path = public, pg_temp'), 'kith_log_sync_event must have search_path');
  });

  it('Verifies zero destructive table drops or truncates exist across all migrations', () => {
    const files = fs.readdirSync(migrationsDir).filter(f => f.endsWith('.sql'));
    for (const file of files) {
      const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');
      assert.ok(!/DROP\s+TABLE/i.test(sql), `File ${file} contains forbidden DROP TABLE statement`);
      assert.ok(!/(?:^|;|\s)TRUNCATE\s+(?:TABLE\s+)?[a-z0-9_]+/i.test(sql), `File ${file} contains forbidden TRUNCATE statement`);
      assert.ok(!/DROP\s+COLUMN/i.test(sql), `File ${file} contains forbidden DROP COLUMN statement`);
    }
  });

  it('Verifies financial precision invariant: money amounts must be integer paise (BIGINT)', () => {
    const files = fs.readdirSync(migrationsDir).filter(f => f.endsWith('.sql'));
    for (const file of files) {
      const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');
      
      // Expenses table amount_in_paise must be BIGINT
      if (sql.includes('expenses') && sql.includes('amount_in_paise')) {
        assert.ok(
          sql.includes('amount_in_paise BIGINT'),
          `File ${file} must define amount_in_paise as BIGINT`
        );
      }
    }
  });

  it('Verifies every table referenced in ENABLE ROW LEVEL SECURITY is created across migrations', () => {
    const files = fs.readdirSync(migrationsDir).filter(f => f.endsWith('.sql')).sort();
    const createdTables = new Set();
    const rlsTables = [];

    for (const file of files) {
      const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');
      
      const tableMatches = sql.matchAll(/CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?([a-zA-Z0-9_]+)/gi);
      for (const match of tableMatches) {
        createdTables.add(match[1].toLowerCase());
      }

      const rlsMatches = sql.matchAll(/ALTER\s+TABLE\s+([a-zA-Z0-9_]+)\s+ENABLE\s+ROW\s+LEVEL\s+SECURITY/gi);
      for (const match of rlsMatches) {
        rlsTables.push({ file, table: match[1].toLowerCase() });
      }
    }

    for (const item of rlsTables) {
      assert.ok(
        createdTables.has(item.table),
        `In ${item.file}: Table "${item.table}" has RLS enabled but is never created in migrations!`
      );
    }
  });
});
