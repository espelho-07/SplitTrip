const fs = require('fs');
const path = require('path');
const PostgresAdapter = require('../src/db/postgres_adapter');
const MigrationRunner = require('../src/db/migration_runner');

/**
 * Safely migrates file-based JSON data storage into PostgreSQL.
 */
async function migrateJsonToPostgres({
  dataDir = path.join(__dirname, '..', 'data_storage'),
  databaseUrl = process.env.DATABASE_URL,
} = {}) {
  if (!databaseUrl) {
    throw new Error('DATABASE_URL environment variable is required to execute migration');
  }

  const adapter = new PostgresAdapter(databaseUrl);
  try {
    // 1. Ensure migrations are applied
    console.log('Running PostgreSQL schema migrations...');
    const migrationResult = await MigrationRunner.runMigrations(adapter);
    console.log('Schema migrations complete:', migrationResult);

    const stats = {
      users: 0,
      sessions: 0,
      trips: 0,
      tripMembers: 0,
      expenses: 0,
      expenseSplits: 0,
      settlements: 0,
    };

    await adapter.transaction(async (client) => {
      // 2. Migrate Users
      const usersFile = path.join(dataDir, 'users.json');
      if (fs.existsSync(usersFile)) {
        const users = JSON.parse(fs.readFileSync(usersFile, 'utf8'));
        for (const user of users) {
          if (user.id && user.displayName) {
            await client.query(
              `INSERT INTO users (id, display_name, avatar_url, recovery_key_hash, is_guest, email, created_at, last_active_at)
               VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
               ON CONFLICT (id) DO UPDATE SET
                 display_name = EXCLUDED.display_name,
                 avatar_url = EXCLUDED.avatar_url,
                 last_active_at = EXCLUDED.last_active_at`,
              [
                user.id,
                user.displayName,
                user.avatarUrl || null,
                user.recoveryKeyHash || '',
                user.isGuest ?? true,
                user.email || null,
                user.createdAt || new Date().toISOString(),
                user.lastActiveAt || new Date().toISOString(),
              ]
            );
            stats.users++;
          }
        }
      }

      // 3. Migrate Sessions
      const sessionsFile = path.join(dataDir, 'sessions.json');
      if (fs.existsSync(sessionsFile)) {
        const sessions = JSON.parse(fs.readFileSync(sessionsFile, 'utf8'));
        for (const sess of sessions) {
          if (sess.id && sess.token && sess.userId) {
            await client.query(
              `INSERT INTO sessions (id, token, user_id, created_at, expires_at)
               VALUES ($1, $2, $3, $4, $5)
               ON CONFLICT (id) DO NOTHING`,
              [
                sess.id,
                sess.token,
                sess.userId,
                sess.createdAt || new Date().toISOString(),
                sess.expiresAt || new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(),
              ]
            );
            stats.sessions++;
          }
        }
      }

      // 4. Migrate Trips
      const tripsFile = path.join(dataDir, 'trips.json');
      if (fs.existsSync(tripsFile)) {
        const trips = JSON.parse(fs.readFileSync(tripsFile, 'utf8'));
        for (const trip of trips) {
          if (trip.id && trip.name && trip.creatorId) {
            await client.query(
              `INSERT INTO trips (id, name, description, emoji, cover_gradient_index, currency_code, creator_id, invite_code, lifecycle_state, created_at, updated_at)
               VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
               ON CONFLICT (id) DO UPDATE SET
                 name = EXCLUDED.name,
                 lifecycle_state = EXCLUDED.lifecycle_state,
                 updated_at = EXCLUDED.updated_at`,
              [
                trip.id,
                trip.name,
                trip.description || null,
                trip.emoji || '✈️',
                trip.coverGradientIndex ?? 0,
                trip.currencyCode || 'INR',
                trip.creatorId,
                trip.inviteCode,
                trip.lifecycleState || 'active',
                trip.createdAt || new Date().toISOString(),
                trip.updatedAt || new Date().toISOString(),
              ]
            );
            stats.trips++;
          }
        }
      }

      // 5. Migrate Trip Members
      const membersFile = path.join(dataDir, 'trip_members.json');
      if (fs.existsSync(membersFile)) {
        const members = JSON.parse(fs.readFileSync(membersFile, 'utf8'));
        for (const member of members) {
          if (member.id && member.tripId && member.userId) {
            await client.query(
              `INSERT INTO trip_members (id, trip_id, user_id, display_name, avatar_url, role, joined_at)
               VALUES ($1, $2, $3, $4, $5, $6, $7)
               ON CONFLICT (id) DO UPDATE SET
                 display_name = EXCLUDED.display_name,
                 role = EXCLUDED.role`,
              [
                member.id,
                member.tripId,
                member.userId,
                member.displayName,
                member.avatarUrl || null,
                member.role || 'member',
                member.joinedAt || new Date().toISOString(),
              ]
            );
            stats.tripMembers++;
          }
        }
      }

      // 6. Migrate Expenses & Splits
      const expensesFile = path.join(dataDir, 'expenses.json');
      if (fs.existsSync(expensesFile)) {
        const expenses = JSON.parse(fs.readFileSync(expensesFile, 'utf8'));
        for (const exp of expenses) {
          if (exp.id && exp.tripId && exp.amountInPaise) {
            await client.query(
              `INSERT INTO expenses (id, trip_id, title, amount_in_paise, category, paid_by_id, split_type, voice_transcript, receipt_url, is_deleted, deleted_at, created_by_id, created_at, updated_at)
               VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
               ON CONFLICT (id) DO UPDATE SET
                 title = EXCLUDED.title,
                 is_deleted = EXCLUDED.is_deleted,
                 deleted_at = EXCLUDED.deleted_at,
                 updated_at = EXCLUDED.updated_at`,
              [
                exp.id,
                exp.tripId,
                exp.title,
                BigInt(exp.amountInPaise),
                exp.category || 'general',
                exp.paidById,
                exp.splitType || 'equal',
                exp.voiceTranscript || null,
                exp.receiptUrl || null,
                exp.isDeleted ?? false,
                exp.deletedAt || null,
                exp.createdById || exp.paidById,
                exp.createdAt || new Date().toISOString(),
                exp.updatedAt || new Date().toISOString(),
              ]
            );
            stats.expenses++;

            if (Array.isArray(exp.splits)) {
              for (const split of exp.splits) {
                const splitId = `split_${exp.id}_${split.memberId}`;
                await client.query(
                  `INSERT INTO expense_splits (id, expense_id, member_id, amount_in_paise, shares, percentage)
                   VALUES ($1, $2, $3, $4, $5, $6)
                   ON CONFLICT (expense_id, member_id) DO UPDATE SET
                     amount_in_paise = EXCLUDED.amount_in_paise`,
                  [
                    splitId,
                    exp.id,
                    split.memberId,
                    BigInt(split.amountInPaise),
                    split.shares || null,
                    split.percentage || null,
                  ]
                );
                stats.expenseSplits++;
              }
            }
          }
        }
      }

      // 7. Migrate Settlements
      const settlementsFile = path.join(dataDir, 'settlements.json');
      if (fs.existsSync(settlementsFile)) {
        const settlements = JSON.parse(fs.readFileSync(settlementsFile, 'utf8'));
        for (const stl of settlements) {
          if (stl.id && stl.tripId && stl.amountInPaise) {
            await client.query(
              `INSERT INTO settlements (id, trip_id, from_member_id, to_member_id, amount_in_paise, payment_reference, note, is_settled, recorded_by_id, created_at, settled_at)
               VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
               ON CONFLICT (id) DO UPDATE SET
                 is_settled = EXCLUDED.is_settled,
                 settled_at = EXCLUDED.settled_at`,
              [
                stl.id,
                stl.tripId,
                stl.fromMemberId,
                stl.toMemberId,
                BigInt(stl.amountInPaise),
                stl.paymentReference || null,
                stl.note || null,
                stl.isSettled ?? true,
                stl.recordedById || stl.fromMemberId,
                stl.createdAt || new Date().toISOString(),
                stl.settledAt || new Date().toISOString(),
              ]
            );
            stats.settlements++;
          }
        }
      }
    });

    console.log('✅ PostgreSQL Migration successful. Summary of migrated records:');
    console.table(stats);
    return stats;
  } finally {
    await adapter.close();
  }
}

if (require.main === module) {
  migrateJsonToPostgres()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('Migration failed:', err);
      process.exit(1);
    });
}

module.exports = { migrateJsonToPostgres };
