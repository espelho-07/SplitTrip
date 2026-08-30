'use strict';

const { db } = require('../db/database');

/**
 * Storage Retention & Data Compaction Service.
 * Manages lifecycle of transient, temporary, soft-deleted, and historical records.
 * 
 * Invariants:
 * 1. Active financial history (expenses, settlements, payments, trips) is NEVER deleted.
 * 2. Replay protection operations are retained for 30 days before safe compaction.
 * 3. Soft-deleted tokens and expired sessions are safely purged.
 */
class StorageRetentionService {
  /**
   * Runs a complete storage retention & compaction cycle.
   */
  runRetentionCycle({
    sessionRetentionDays = 7,
    tokenRetentionDays = 30,
    notificationRetentionDays = 90,
    deletedExpenseRetentionDays = 60,
    operationRetentionDays = 30,
  } = {}) {
    const now = new Date();
    const summary = {
      timestamp: now.toISOString(),
      prunedSessions: 0,
      prunedTokens: 0,
      prunedNotifications: 0,
      prunedExpenses: 0,
      compactedOperations: 0,
    };

    // 1. Prune Expired Sessions
    const sessions = db.find('sessions', (s) => {
      if (!s.expiresAt) return false;
      const expiry = new Date(s.expiresAt);
      return expiry < now;
    });

    for (const session of sessions) {
      db.delete('sessions', session.id);
      summary.prunedSessions++;
    }

    // 2. Prune Stale & Deleted FCM Tokens older than tokenRetentionDays
    const tokenThreshold = new Date(now.getTime() - tokenRetentionDays * 24 * 60 * 60 * 1000);
    const staleTokens = db.find('user_fcm_tokens', (t) => {
      if (t.deleted && t.deletedAt && new Date(t.deletedAt) < tokenThreshold) return true;
      if (t.updatedAt && new Date(t.updatedAt) < tokenThreshold) return true;
      return false;
    });

    for (const token of staleTokens) {
      db.delete('user_fcm_tokens', token.id);
      summary.prunedTokens++;
    }

    // 3. Prune Resolved/Read Notifications older than notificationRetentionDays
    const notifThreshold = new Date(now.getTime() - notificationRetentionDays * 24 * 60 * 60 * 1000);
    const oldNotifications = db.find('notifications', (n) => {
      if (n.deleted) return true;
      if ((n.status === 'READ' || n.status === 'RESOLVED') && new Date(n.updatedAt || n.createdAt) < notifThreshold) {
        return true;
      }
      return false;
    });

    for (const n of oldNotifications) {
      db.delete('notifications', n.id);
      summary.prunedNotifications++;
    }

    // 4. Prune Soft-Deleted Expenses older than deletedExpenseRetentionDays
    const expenseThreshold = new Date(now.getTime() - deletedExpenseRetentionDays * 24 * 60 * 60 * 1000);
    const oldDeletedExpenses = db.find('expenses', (e) => {
      return e.isDeleted && e.deletedAt && new Date(e.deletedAt) < expenseThreshold;
    });

    for (const exp of oldDeletedExpenses) {
      db.delete('expenses', exp.id);
      summary.prunedExpenses++;
    }

    // 5. Compact Processed Operations older than operationRetentionDays
    const opThreshold = new Date(now.getTime() - operationRetentionDays * 24 * 60 * 60 * 1000);
    const oldOperations = db.find('processed_operations', (op) => {
      const ts = op.processedAt ? new Date(op.processedAt) : new Date(op.createdAt || 0);
      return ts < opThreshold;
    });

    for (const op of oldOperations) {
      db.delete('processed_operations', op.id);
      summary.compactedOperations++;
    }

    return summary;
  }
}

const storageRetentionService = new StorageRetentionService();
module.exports = { StorageRetentionService, storageRetentionService };
