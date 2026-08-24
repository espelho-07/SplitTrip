const { test, describe, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const authService = require('../src/services/auth_service');
const { db } = require('../src/db/database');

describe('Auth Service Tests', () => {
  beforeEach(() => {
    db.clearAll();
  });

  test('Creates a guest user with cryptographic recovery key and session token', () => {
    const res = authService.createGuest({ displayName: 'Alex' });

    assert.ok(res.user.id.startsWith('usr_'));
    assert.equal(res.user.displayName, 'Alex');
    assert.ok(res.user.recoveryKey.startsWith('KITH-'));
    assert.equal(res.user.recoveryKey.split('-').length, 3);
    assert.ok(res.token.startsWith('kith_sess_'));

    // Check stored user has hash and not raw key
    const storedUser = db.get('users', res.user.id);
    assert.ok(storedUser.recoveryKeyHash);
    assert.equal(storedUser.recoveryKey, undefined);
  });

  test('Recovers guest session across devices using recovery key', () => {
    const initial = authService.createGuest({ displayName: 'Sarah' });
    const recoveryKey = initial.user.recoveryKey;

    const recovered = authService.recoverGuest({ recoveryKey });
    assert.equal(recovered.user.id, initial.user.id);
    assert.equal(recovered.user.displayName, 'Sarah');
    assert.ok(recovered.token.startsWith('kith_sess_'));
  });

  test('Rejects recovery with invalid recovery key', () => {
    assert.throws(
      () => authService.recoverGuest({ recoveryKey: 'KITH-FAK1-KEY9' }),
      (err) => err.statusCode === 401
    );
  });

  test('Syncs locally generated offline guest user and allows recovery', () => {
    const offlineId = 'usr_offline1234';
    const offlineKey = 'KITH-AB12-CD34';
    const offlineToken = 'kith_sess_localoffline99';

    const syncRes = authService.syncGuest({
      id: offlineId,
      displayName: 'Offline Traveler',
      recoveryKey: offlineKey,
      token: offlineToken,
    });

    assert.equal(syncRes.success, true);
    assert.equal(syncRes.user.id, offlineId);

    // Verify recovery with various formats (lowercase, spaces, without KITH prefix)
    const recovered1 = authService.recoverGuest({ recoveryKey: 'kith-ab12-cd34' });
    assert.equal(recovered1.user.id, offlineId);

    const recovered2 = authService.recoverGuest({ recoveryKey: 'AB12CD34' });
    assert.equal(recovered2.user.id, offlineId);

    const recovered3 = authService.recoverGuest({ recoveryKey: 'ab12 cd34' });
    assert.equal(recovered3.user.id, offlineId);
  });
});
