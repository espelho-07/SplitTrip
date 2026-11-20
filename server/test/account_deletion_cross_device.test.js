const { describe, it } = require('node:test');
const assert = require('node:assert');
const authService = require('../src/services/auth_service');
const { db } = require('../src/db/database');
const { AppError } = require('../src/middleware/error_handler');

describe('Authoritative Global Account Deletion & Multi-Device Revocation Suite', () => {
  it('1. Phone B deletes account -> Phone A active session is revoked and returns 403 ACCOUNT_DELETED', async () => {
    // 1. Create guest user (Phone A session)
    const phoneA = authService.createGuest({ displayName: 'Test Traveler Phone A' });
    const userId = phoneA.user.id;
    const recoveryKey = phoneA.user.recoveryKey;
    const sessionTokenA = phoneA.token;

    assert.ok(userId, 'User ID must be generated');
    assert.ok(recoveryKey, 'Recovery key must be generated');

    // 2. Phone B logs in via recovery key -> gets sessionTokenB
    const phoneB = authService.recoverGuest({ recoveryKey });
    const sessionTokenB = phoneB.token;
    assert.strictEqual(phoneB.user.id, userId);
    assert.notStrictEqual(sessionTokenA, sessionTokenB, 'Phone B gets its own session token');

    // Mock RealtimeHub
    const broadcastEvents = [];
    let terminatedUserId = null;
    const mockRealtimeHub = {
      broadcastToUser: (uid, eventType, data) => {
        broadcastEvents.push({ uid, eventType, data });
      },
      terminateUser: (uid) => {
        terminatedUserId = uid;
      },
    };

    // 3. Phone B deletes account
    const deleteResult = authService.deleteAccount(userId, mockRealtimeHub);
    assert.strictEqual(deleteResult.success, true);

    // 4. Verify tombstone in deleted_accounts
    const tombstone = db.findOne('deleted_accounts', (d) => d.userId === userId);
    assert.ok(tombstone, 'Tombstone must be registered in deleted_accounts table');
    assert.ok(tombstone.recoveryKeyHash, 'Tombstone must record recoveryKeyHash');

    // 5. Verify real-time broadcast and socket termination occurred
    assert.strictEqual(terminatedUserId, userId, 'RealtimeHub terminateUser must be called for deleted user');
    const delEvent = broadcastEvents.find((e) => e.eventType === 'account_deleted');
    assert.ok(delEvent, 'RealtimeHub must broadcast account_deleted event');

    // 6. Verify Phone A session is gone
    const sessionAInDb = db.findOne('sessions', (s) => s.token === sessionTokenA);
    assert.strictEqual(sessionAInDb, null, 'Phone A session must be purged from database');

    // 7. Verify Phone A cannot make authenticated requests (authMiddleware simulation)
    const checkStatus = authService.checkAccountStatus({ userId, recoveryKey });
    assert.strictEqual(checkStatus.isDeleted, true);
    assert.strictEqual(checkStatus.status, 'DELETED');

    // 8. Verify Phone A attempting to recover with the same recovery key is permanently rejected with 403 ACCOUNT_DELETED
    assert.throws(
      () => {
        authService.recoverGuest({ recoveryKey });
      },
      (err) => {
        assert.ok(err instanceof AppError);
        assert.strictEqual(err.statusCode, 403);
        assert.strictEqual(err.code, 'ACCOUNT_DELETED');
        assert.match(err.message, /permanently deleted/i);
        return true;
      }
    );

    // 9. Verify idempotent deletion: deleting again does not crash and returns alreadyDeleted: true
    const secondDelete = authService.deleteAccount(userId, mockRealtimeHub);
    assert.strictEqual(secondDelete.success, true);
    assert.strictEqual(secondDelete.alreadyDeleted, true);
  });
});
