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

  test('Google Sign-In: Resolves to ONE canonical user and preserves identity on re-login', () => {
    // 1. Initial Google Sign-In
    const login1 = authService.loginWithGoogle({
      email: 'alex.traveler@gmail.com',
      displayName: 'Alex Traveler',
      googleId: 'goog_sub_1234567890',
      photoUrl: 'https://lh3.googleusercontent.com/a/photo.jpg',
    });

    assert.ok(login1.user.id);
    assert.equal(login1.user.email, 'alex.traveler@gmail.com');
    assert.equal(login1.user.isGuest, false);
    assert.ok(login1.token);

    const canonicalUserId = login1.user.id;

    // 2. Re-login from same device or different device with SAME Google account
    const login2 = authService.loginWithGoogle({
      email: 'alex.traveler@gmail.com',
      displayName: 'Alex Traveler (Updated)',
      googleId: 'goog_sub_1234567890',
    });

    assert.equal(login2.user.id, canonicalUserId, 'Must resolve to identical canonical user ID');
    assert.equal(login2.user.email, 'alex.traveler@gmail.com');

    // 3. Different Google Account on another device creates distinct user
    const loginUserB = authService.loginWithGoogle({
      email: 'sarah.nomad@gmail.com',
      displayName: 'Sarah Nomad',
      googleId: 'goog_sub_9876543210',
    });

    assert.notEqual(loginUserB.user.id, canonicalUserId, 'User B must have distinct user ID');
    assert.equal(loginUserB.user.email, 'sarah.nomad@gmail.com');
  });

  test('Google Sign-In: Upgrades active guest session and preserves created trips and expenses', () => {
    // 1. User starts as guest and creates data
    const guest = authService.createGuest({ displayName: 'Anonymous Explorer' });
    const guestId = guest.user.id;

    // Create a trip with this guest
    db.insert('trips', {
      id: 'trip_guest_001',
      name: 'Himalayan Trek',
      createdBy: guestId,
      inviteCode: 'HIM001',
    });

    // 2. Guest signs in with Google to link/upgrade account
    const linked = authService.loginWithGoogle({
      email: 'explorer@gmail.com',
      displayName: 'Explorer',
      googleId: 'goog_sub_555',
      currentGuestUserId: guestId,
    });

    assert.equal(linked.user.id, guestId, 'Guest identity upgraded to permanent Google account');
    assert.equal(linked.user.email, 'explorer@gmail.com');
    assert.equal(linked.user.isGuest, false);

    // Verify trip ownership is intact
    const trip = db.get('trips', 'trip_guest_001');
    assert.equal(trip.createdBy, guestId);
  });

  test('Session Logout: Invalidates token immediately from backend sessions', () => {
    const login = authService.loginWithGoogle({
      email: 'test.logout@gmail.com',
      displayName: 'Test User',
      googleId: 'goog_sub_logout_111',
    });

    const token = login.token;
    const sessionBefore = db.findOne('sessions', (s) => s.token === token);
    assert.ok(sessionBefore, 'Session must exist before logout');

    // Logout
    const logoutRes = authService.logout(`Bearer ${token}`);
    assert.equal(logoutRes.success, true);

    const sessionAfter = db.findOne('sessions', (s) => s.token === token);
    assert.equal(sessionAfter, null, 'Session must be removed from database after logout');
  });
});
