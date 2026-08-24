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
});
