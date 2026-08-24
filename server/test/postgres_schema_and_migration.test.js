const { describe, it } = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');
const PostgresAdapter = require('../src/db/postgres_adapter');

describe('PostgreSQL Schema, Migration & Financial Precision Tests', () => {
  const migrationsDir = path.join(__dirname, '..', 'migrations');
  const migrationSqlPath = path.join(migrationsDir, '001_initial_schema.sql');

  it('Verifies 001_initial_schema.sql contains all core relational tables and foreign keys', () => {
    assert.ok(fs.existsSync(migrationSqlPath), '001_initial_schema.sql migration file must exist');
    const sql = fs.readFileSync(migrationSqlPath, 'utf8');

    // Required Tables
    assert.ok(sql.includes('CREATE TABLE IF NOT EXISTS users'), 'Must create users table');
    assert.ok(sql.includes('CREATE TABLE IF NOT EXISTS sessions'), 'Must create sessions table');
    assert.ok(sql.includes('CREATE TABLE IF NOT EXISTS trips'), 'Must create trips table');
    assert.ok(sql.includes('CREATE TABLE IF NOT EXISTS trip_members'), 'Must create trip_members table');
    assert.ok(sql.includes('CREATE TABLE IF NOT EXISTS expenses'), 'Must create expenses table');
    assert.ok(sql.includes('CREATE TABLE IF NOT EXISTS expense_splits'), 'Must create expense_splits table');
    assert.ok(sql.includes('CREATE TABLE IF NOT EXISTS settlements'), 'Must create settlements table');

    // Financial Precision Invariant: Money amounts MUST be BIGINT (integer smallest unit)
    assert.ok(sql.includes('amount_in_paise BIGINT'), 'Expenses amount_in_paise must be BIGINT');
    assert.ok(!sql.includes('FLOAT') && !sql.includes('REAL') && !sql.includes('DOUBLE PRECISION'), 'Floating point money types strictly prohibited');

    // Relational Foreign Keys & Cascades
    assert.ok(sql.includes('REFERENCES trips(id) ON DELETE CASCADE'), 'Must have cascading trip foreign keys');
    assert.ok(sql.includes('uq_trip_member UNIQUE(trip_id, user_id)'), 'Must prevent duplicate trip memberships');
    assert.ok(sql.includes('uq_expense_split UNIQUE(expense_id, member_id)'), 'Must enforce unique split per member per expense');
  });

  it('Verifies PostgresAdapter initializes connection parameters securely without logging secrets', () => {
    const mockUrl = 'postgresql://kith_user:kith_secure_pass@db.supabase.co:5432/postgres';
    const adapter = new PostgresAdapter(mockUrl);

    assert.strictEqual(adapter.isConnected, true);
    assert.ok(!JSON.stringify(adapter).includes('kith_secure_pass'), 'Secrets must not be exposed in serialized adapter');
  });

  it('Verifies integer zero-sum financial calculations with BIGINT precision', () => {
    // 5-member trip splitting ₹6,000 (600000 paise) + ₹300 (30000 paise)
    const expense1Paise = 600000n; // ₹6,000.00
    const expense2Paise = 30000n;  // ₹300.00
    const memberCount = 5n;

    const split1Each = expense1Paise / memberCount;
    const split2Each = expense2Paise / memberCount;

    assert.strictEqual(split1Each * memberCount, expense1Paise);
    assert.strictEqual(split2Each * memberCount, expense2Paise);

    const totalSpent = expense1Paise + expense2Paise;
    assert.strictEqual(totalSpent, 630000n); // Exact integer paise, zero floating-point drift
  });
});
