const { describe, it } = require('node:test');
const assert = require('node:assert');
const { Client } = require('pg');

describe('PostgreSQL Two-Connection Concurrency & Commit-Order Integration Tests', () => {
  const dbUrl = process.env.SUPABASE_DB_URL || process.env.PG_URL || process.env.DATABASE_URL;

  it('Verifies concurrent commit ordering, non-contiguous sequence tolerance, and zero-loss pagination', async (t) => {
    if (!dbUrl) {
      t.skip('Skipping live PostgreSQL two-session concurrency test: No PostgreSQL connection URL provided in environment (process.env.SUPABASE_DB_URL / process.env.DATABASE_URL)');
      return;
    }

    let clientA;
    let clientB;
    let clientAdmin;

    try {
      clientAdmin = new Client({ connectionString: dbUrl, statement_timeout: 5000 });
      await clientAdmin.connect();
    } catch (err) {
      t.skip(`Skipping live PostgreSQL two-session concurrency test: Unable to connect to database at ${dbUrl.replace(/:[^:]*@/, ':***@')} (${err.message})`);
      return;
    }

    try {
      // Setup test fixtures
      await clientAdmin.query(`
        DELETE FROM expenses WHERE trip_id = 'trip_concurrency_test_01';
        DELETE FROM trip_members WHERE trip_id = 'trip_concurrency_test_01';
        DELETE FROM trips WHERE id = 'trip_concurrency_test_01';
        DELETE FROM guest_sessions WHERE id IN ('user_concurrency_a', 'user_concurrency_b');

        INSERT INTO guest_sessions (id, session_token_hash, display_name)
        VALUES ('user_concurrency_a', encode(sha256('token_concurrency_a_32chars_long_1'::bytea), 'hex'), 'Tester A'),
               ('user_concurrency_b', encode(sha256('token_concurrency_b_32chars_long_2'::bytea), 'hex'), 'Tester B')
        ON CONFLICT (id) DO NOTHING;

        INSERT INTO trips (id, creator_id, name, invite_code)
        VALUES ('trip_concurrency_test_01', 'user_concurrency_a', 'Concurrency Test Trip', 'CONCURR00001')
        ON CONFLICT (id) DO NOTHING;

        INSERT INTO trip_members (id, trip_id, user_id, display_name, role)
        VALUES ('mbr_concurrency_01', 'trip_concurrency_test_01', 'user_concurrency_a', 'Tester A', 'admin'),
               ('mbr_concurrency_02', 'trip_concurrency_test_01', 'user_concurrency_b', 'Tester B', 'member')
        ON CONFLICT (id) DO NOTHING;
      `);

      // Connect two distinct, independent client sessions
      clientA = new Client({ connectionString: dbUrl, statement_timeout: 10000 });
      clientB = new Client({ connectionString: dbUrl, statement_timeout: 10000 });
      await clientA.connect();
      await clientB.connect();

      // Session A sets identity
      await clientA.query(`SET "request.headers" TO '{"x-kith-session-token": "token_concurrency_a_32chars_long_1"}';`);
      // Session B sets identity
      await clientB.query(`SET "request.headers" TO '{"x-kith-session-token": "token_concurrency_b_32chars_long_2"}';`);

      // ───────────────────────────────────────────────────────────────────────
      // SCENARIO 1: Session A holds advisory lock; Session B blocks until A commits
      // Proves: Sequence allocation order is STRICTLY IDENTICAL to commit order.
      // ───────────────────────────────────────────────────────────────────────
      await clientA.query('BEGIN;');
      await clientA.query(`
        INSERT INTO expenses (id, trip_id, title, amount_in_paise, paid_by_id)
        VALUES ('exp_conc_a_001', 'trip_concurrency_test_01', 'Expense from Session A', 150000, 'mbr_concurrency_01');
      `);

      let sessionBCompleted = false;
      const startTime = Date.now();

      // Fire Session B concurrently — it must block on the advisory lock held by Session A
      const sessionBPromise = (async () => {
        await clientB.query('BEGIN;');
        await clientB.query(`
          INSERT INTO expenses (id, trip_id, title, amount_in_paise, paid_by_id)
          VALUES ('exp_conc_b_001', 'trip_concurrency_test_01', 'Expense from Session B', 250000, 'mbr_concurrency_02');
        `);
        await clientB.query('COMMIT;');
        sessionBCompleted = true;
      })();

      // Verify Session B is blocked (did not complete immediately)
      await new Promise(resolve => setTimeout(resolve, 300));
      assert.strictEqual(sessionBCompleted, false, 'Session B must wait for Session A to release the advisory lock');

      // Now Session A commits, releasing the advisory lock
      await clientA.query('COMMIT;');

      // Session B should now finish
      await sessionBPromise;
      const elapsed = Date.now() - startTime;
      assert.ok(elapsed >= 300, `Expected Session B to wait on advisory lock (elapsed: ${elapsed}ms)`);
      assert.strictEqual(sessionBCompleted, true, 'Session B must complete successfully after Session A commits');

      // ───────────────────────────────────────────────────────────────────────
      // SCENARIO 2: Monotonic Ordering (seqA < seqB) Without Requiring Contiguity
      // BIGSERIAL sequences may have gaps (from rollbacks or server restarts).
      // We assert seqA < seqB (monotonicity) and event visibility, NOT seqB === seqA + 1.
      // ───────────────────────────────────────────────────────────────────────
      const resA = await clientAdmin.query(`SELECT seq, action, event_timestamp FROM kith_sync_events WHERE record_id = 'exp_conc_a_001'`);
      const resB = await clientAdmin.query(`SELECT seq, action, event_timestamp FROM kith_sync_events WHERE record_id = 'exp_conc_b_001'`);

      assert.strictEqual(resA.rows.length, 1, 'Must have recorded sync event for Exp A');
      assert.strictEqual(resB.rows.length, 1, 'Must have recorded sync event for Exp B');

      const seqA = BigInt(resA.rows[0].seq);
      const seqB = BigInt(resB.rows[0].seq);

      assert.ok(
        seqA < seqB,
        `Commit order guarantee: seqA (${seqA}) must be strictly less than seqB (${seqB})`
      );

      // Verify kith_fetch_sync_events returns both in exact order
      const eventsRes = await clientAdmin.query(`
        SELECT * FROM kith_fetch_sync_events(0, 100) WHERE record_id IN ('exp_conc_a_001', 'exp_conc_b_001');
      `);
      assert.strictEqual(eventsRes.rows.length, 2, 'Fetcher must return both events without skipping');
      assert.strictEqual(eventsRes.rows[0].record_id, 'exp_conc_a_001');
      assert.strictEqual(eventsRes.rows[1].record_id, 'exp_conc_b_001');

      // ───────────────────────────────────────────────────────────────────────
      // SCENARIO 3: Rollback Sequence Gap & Cursor Pagination Tolerance
      // Rollback consumes a BIGSERIAL sequence number permanently.
      // Verify:
      // 1. The aborted transaction leaves zero rows in kith_sync_events.
      // 2. The next committed transaction succeeds with a higher sequence number.
      // 3. The cursor pagination (seq > last_seq) tolerates the gap and finds the new event.
      // ───────────────────────────────────────────────────────────────────────
      await clientA.query('BEGIN;');
      await clientA.query(`
        INSERT INTO expenses (id, trip_id, title, amount_in_paise, paid_by_id)
        VALUES ('exp_conc_aborted', 'trip_concurrency_test_01', 'Aborted Expense', 99999, 'mbr_concurrency_01');
      `);
      await clientA.query('ROLLBACK;');

      // Verify no phantom event was recorded
      const abortedExpense = await clientAdmin.query(`SELECT * FROM expenses WHERE id = 'exp_conc_aborted'`);
      const abortedEvent = await clientAdmin.query(`SELECT * FROM kith_sync_events WHERE record_id = 'exp_conc_aborted'`);
      assert.strictEqual(abortedExpense.rows.length, 0, 'Rolled-back expense must not exist in expenses table');
      assert.strictEqual(abortedEvent.rows.length, 0, 'Rolled-back transaction must leave no sync events in kith_sync_events');

      // Now insert a third committed expense
      await clientB.query('BEGIN;');
      await clientB.query(`
        INSERT INTO expenses (id, trip_id, title, amount_in_paise, paid_by_id)
        VALUES ('exp_conc_c_003', 'trip_concurrency_test_01', 'Expense Post-Rollback', 350000, 'mbr_concurrency_02');
      `);
      await clientB.query('COMMIT;');

      const resC = await clientAdmin.query(`SELECT seq FROM kith_sync_events WHERE record_id = 'exp_conc_c_003'`);
      assert.strictEqual(resC.rows.length, 1, 'Committed expense post-rollback must produce sync event');
      const seqC = BigInt(resC.rows[0].seq);
      assert.ok(seqC > seqB, `Sequence seqC (${seqC}) must be strictly greater than seqB (${seqB})`);

      // Verify cursor pagination from seqB skips the burned/gapped sequence number and returns seqC
      const paginatedRes = await clientAdmin.query(`
        SELECT * FROM kith_fetch_sync_events($1, 100) WHERE record_id = 'exp_conc_c_003'
      `, [seqB.toString()]);
      assert.strictEqual(paginatedRes.rows.length, 1, 'Cursor pagination past seqB must find seqC despite sequence gap');
      assert.strictEqual(paginatedRes.rows[0].record_id, 'exp_conc_c_003');

      // ───────────────────────────────────────────────────────────────────────
      // SCENARIO 4: Multi-Table Transaction with Re-entrant Advisory Lock
      // Verify modifying trips and trip_members within the same transaction succeeds
      // without self-deadlock (re-entrant advisory lock).
      // ───────────────────────────────────────────────────────────────────────
      await clientA.query('BEGIN;');
      await clientA.query(`
        UPDATE trips SET description = 'Multi-table update test' WHERE id = 'trip_concurrency_test_01';
      `);
      await clientA.query(`
        UPDATE trip_members SET role = 'admin' WHERE id = 'mbr_concurrency_02';
      `);
      await clientA.query('COMMIT;');

      const multiEvents = await clientAdmin.query(`
        SELECT table_name, action FROM kith_sync_events 
        WHERE record_id IN ('trip_concurrency_test_01', 'mbr_concurrency_02') AND action = 'UPDATE'
      `);
      assert.ok(multiEvents.rows.length >= 2, 'Multi-table transaction must record sync events for both tables');

    } finally {
      // Isolated test teardown
      if (clientAdmin) {
        try {
          await clientAdmin.query(`
            DELETE FROM expenses WHERE trip_id = 'trip_concurrency_test_01';
            DELETE FROM trip_members WHERE trip_id = 'trip_concurrency_test_01';
            DELETE FROM trips WHERE id = 'trip_concurrency_test_01';
            DELETE FROM guest_sessions WHERE id IN ('user_concurrency_a', 'user_concurrency_b');
            DELETE FROM kith_sync_events WHERE record_id IN ('exp_conc_a_001', 'exp_conc_b_001', 'exp_conc_aborted', 'exp_conc_c_003', 'trip_concurrency_test_01', 'mbr_concurrency_02');
          `);
        } catch (_) {}
        await clientAdmin.end();
      }
      if (clientA) await clientA.end();
      if (clientB) await clientB.end();
    }
  });
});
