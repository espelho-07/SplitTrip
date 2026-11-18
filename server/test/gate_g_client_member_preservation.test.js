const { test, describe, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const authService = require('../src/services/auth_service');
const tripService = require('../src/services/trip_service');
const { db } = require('../src/db/database');

describe('Gate G: Client Member ID Preservation Tests', () => {
  let creator;

  beforeEach(() => {
    db.clearAll();
    const cRes = authService.createGuest({ displayName: 'Dj' });
    creator = cRes.user;
  });

  test('Preserves client-generated member ID and friend IDs when client provides members array', () => {
    const clientCreatorMemberId = 'mbr_client_dj_123';
    const clientFriendKId = 'mbr_client_k_456';
    const clientFriendBId = 'mbr_client_b_789';
    const clientClaimTokenK = 'clm_token_k_111';

    const clientMembers = [
      {
        id: clientCreatorMemberId,
        userId: creator.id,
        displayName: 'Dj',
        role: 'creator',
      },
      {
        id: clientFriendKId,
        userId: 'unclaimed_k_001',
        displayName: 'K',
        claimToken: clientClaimTokenK,
        role: 'member',
      },
      {
        id: clientFriendBId,
        userId: 'unclaimed_b_002',
        displayName: 'B',
        claimToken: 'clm_token_b_222',
        role: 'member',
      },
    ];

    const trip = tripService.createTrip(creator, {
      id: 'trip_birthday_bash_001',
      name: 'Birthday Bash',
      initialFriendNames: ['K', 'B'],
      members: clientMembers,
    });

    assert.equal(trip.id, 'trip_birthday_bash_001');
    assert.equal(trip.members.length, 3);

    const djMember = trip.members.find((m) => m.displayName === 'Dj');
    const kMember = trip.members.find((m) => m.displayName === 'K');
    const bMember = trip.members.find((m) => m.displayName === 'B');

    assert.ok(djMember, 'Dj member must exist');
    assert.equal(djMember.id, clientCreatorMemberId, 'Creator member ID must match client-generated ID');
    assert.equal(djMember.userId, creator.id);

    assert.ok(kMember, 'K member must exist');
    assert.equal(kMember.id, clientFriendKId, 'K member ID must match client-generated ID');
    assert.equal(kMember.claimToken, clientClaimTokenK, 'K claim token must be preserved');

    assert.ok(bMember, 'B member must exist');
    assert.equal(bMember.id, clientFriendBId, 'B member ID must match client-generated ID');
  });

  test('Safely generates server UUIDs when legacy client does not provide members array (backwards compatible)', () => {
    const trip = tripService.createTrip(creator, {
      name: 'Old Client Trip',
      initialFriendNames: ['Friend1'],
    });

    assert.equal(trip.members.length, 2);
    assert.ok(trip.members[0].id.startsWith('mbr_'));
    assert.ok(trip.members[1].id.startsWith('mbr_'));
  });
});
