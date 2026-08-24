const { describe, test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { db } = require('../src/db/database');
const authService = require('../src/services/auth_service');
const tripService = require('../src/services/trip_service');
const expenseService = require('../src/services/expense_service');
const settlementService = require('../src/services/settlement_service');

describe('Settlement Service Ledger & Reduction Tests', () => {
  beforeEach(() => {
    db.clearAll();
  });

  test('Records settlement between debtor and creditor, reducing net outstanding debts to zero', () => {
    // 1. Setup two guest users
    const { user: userA } = authService.createGuest({ displayName: 'Alice' });
    const { user: userB } = authService.createGuest({ displayName: 'Bob' });

    // 2. Alice creates trip
    const trip = tripService.createTrip(userA, { name: 'Goa Weekend' });
    const aliceMember = trip.members.find((m) => m.userId === userA.id);

    // 3. Bob joins
    const joinedTrip = tripService.joinTripByCode(userB, trip.inviteCode);
    const bobMember = joinedTrip.members.find((m) => m.userId === userB.id);

    // 4. Alice pays ₹2,000 (200,000 paise) for resort, split equally (100,000p each)
    expenseService.createExpense(userA, trip.id, {
      title: 'Resort Stay',
      amountInPaise: 200000,
      paidById: aliceMember.id,
      splitType: 'equal',
      splits: [
        { memberId: aliceMember.id, amountInPaise: 100000 },
        { memberId: bobMember.id, amountInPaise: 100000 },
      ],
    });

    // Verify Bob owes Alice ₹1,000
    let balance = expenseService.getBalanceSummary(trip.id, userB.id);
    assert.equal(balance.currentUserOwedInPaise, 100000);
    assert.equal(balance.simplifiedSettlements.length, 1);
    assert.equal(balance.simplifiedSettlements[0].fromMemberId, bobMember.id);
    assert.equal(balance.simplifiedSettlements[0].toMemberId, aliceMember.id);
    assert.equal(balance.simplifiedSettlements[0].amountInPaise, 100000);

    // 5. Bob records settlement payment to Alice (₹1,000)
    const { settlement, settlements } = settlementService.recordSettlement(userB, trip.id, {
      fromMemberId: bobMember.id,
      toMemberId: aliceMember.id,
      amountInPaise: 100000,
      paymentReference: 'UPI_TXN_98765',
      note: 'Settled resort bill',
    });

    assert.equal(settlement.isSettled, true);
    assert.equal(settlement.amountInPaise, 100000);
    assert.equal(settlements.length, 1);

    // 6. Verify residual simplified debts are now 0
    balance = expenseService.getBalanceSummary(trip.id, userB.id);
    assert.equal(balance.simplifiedSettlements.length, 0);
    assert.equal(balance.recordedSettlements.length, 1);
  });

  test('Rejects invalid settlement amounts or unauthorized members', () => {
    const { user: userA } = authService.createGuest({ displayName: 'Charlie' });
    const { user: userB } = authService.createGuest({ displayName: 'Dave' });
    const { user: stranger } = authService.createGuest({ displayName: 'Stranger' });

    const trip = tripService.createTrip(userA, { name: 'Camping Trip' });
    const memberA = trip.members.find((m) => m.userId === userA.id);

    const joinedTrip = tripService.joinTripByCode(userB, trip.inviteCode);
    const memberB = joinedTrip.members.find((m) => m.userId === userB.id);

    // Add expense: Charlie pays ₹1,000 split equally (Dave owes ₹500 / 50,000 paise)
    expenseService.createExpense(userA, trip.id, {
      title: 'Camp Gear',
      amountInPaise: 100000,
      paidById: memberA.id,
      splitType: 'equal',
      splits: [
        { memberId: memberA.id, amountInPaise: 50000 },
        { memberId: memberB.id, amountInPaise: 50000 },
      ],
    });

    // Stranger cannot record settlement (403 Forbidden)
    assert.throws(
      () => {
        settlementService.recordSettlement(stranger, trip.id, {
          fromMemberId: memberB.id,
          toMemberId: memberA.id,
          amountInPaise: 50000,
        });
      },
      (err) => err.statusCode === 403
    );

    // Negative amount rejected (400 Bad Request)
    assert.throws(
      () => {
        settlementService.recordSettlement(userB, trip.id, {
          fromMemberId: memberB.id,
          toMemberId: memberA.id,
          amountInPaise: -500,
        });
      },
      (err) => err.statusCode === 400
    );

    // Excessive settlement amount: Dave owes ₹500, but tries to settle ₹10,000 (1,000,000 paise) -> Rejected (400 Bad Request)
    assert.throws(
      () => {
        settlementService.recordSettlement(userB, trip.id, {
          fromMemberId: memberB.id,
          toMemberId: memberA.id,
          amountInPaise: 1000000,
        });
      },
      (err) => err.statusCode === 400
    );

    // Member with 0 debt (Charlie owes 0) tries to settle -> Rejected (400 Bad Request)
    assert.throws(
      () => {
        settlementService.recordSettlement(userA, trip.id, {
          fromMemberId: memberA.id,
          toMemberId: memberB.id,
          amountInPaise: 25000,
        });
      },
      (err) => err.statusCode === 400
    );
  });
});
