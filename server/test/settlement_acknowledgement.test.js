const { describe, test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { db } = require('../src/db/database');
const authService = require('../src/services/auth_service');
const tripService = require('../src/services/trip_service');
const expenseService = require('../src/services/expense_service');
const settlementService = require('../src/services/settlement_service');

describe('Two-Sided Settlement & Payment Acknowledgement System Tests', () => {
  beforeEach(() => {
    db.clearAll();
  });

  test('1. Payer marks paid -> enters marked_paid state (isSettled: false), does NOT prematurely clear balance', () => {
    const { user: userA } = authService.createGuest({ displayName: 'Y (Receiver)' });
    const { user: userB } = authService.createGuest({ displayName: 'X (Payer)' });

    const trip = tripService.createTrip(userA, { name: 'Goa Trip' });
    const memberY = trip.members.find((m) => m.userId === userA.id);

    const joined = tripService.joinTripByCode(userB, trip.inviteCode);
    const memberX = joined.members.find((m) => m.userId === userB.id);

    // Y pays ₹600 for Dinner split equally (X owes Y ₹300 / 30,000 paise)
    expenseService.createExpense(userA, trip.id, {
      title: 'Dinner',
      amountInPaise: 60000,
      paidById: memberY.id,
      splitType: 'equal',
      splits: [
        { memberId: memberY.id, amountInPaise: 30000 },
        { memberId: memberX.id, amountInPaise: 30000 },
      ],
    });

    let balanceX = expenseService.getBalanceSummary(trip.id, userB.id);
    assert.equal(balanceX.currentUserOwedInPaise, 30000);

    // X marks ₹300 paid to Y
    const { settlement } = settlementService.recordSettlement(userB, trip.id, {
      fromMemberId: memberX.id,
      toMemberId: memberY.id,
      amountInPaise: 30000,
      status: 'marked_paid',
      paymentReference: 'UPI_REF_1234',
    });

    assert.equal(settlement.status, 'marked_paid');
    assert.equal(settlement.isSettled, false);
    assert.ok(settlement.markedPaidAt);

    // Balance must NOT be zero yet! (Still awaiting receiver confirmation)
    balanceX = expenseService.getBalanceSummary(trip.id, userB.id);
    assert.equal(balanceX.currentUserOwedInPaise, 30000);
    assert.equal(balanceX.simplifiedSettlements.length, 1);
  });

  test('2. Receiver confirms receipt -> transitions to confirmed (isSettled: true), debt is cleared from active list', () => {
    const { user: userA } = authService.createGuest({ displayName: 'Y (Receiver)' });
    const { user: userB } = authService.createGuest({ displayName: 'X (Payer)' });

    const trip = tripService.createTrip(userA, { name: 'Goa Trip' });
    const memberY = trip.members.find((m) => m.userId === userA.id);
    const joined = tripService.joinTripByCode(userB, trip.inviteCode);
    const memberX = joined.members.find((m) => m.userId === userB.id);

    expenseService.createExpense(userA, trip.id, {
      title: 'Dinner',
      amountInPaise: 60000,
      paidById: memberY.id,
      splitType: 'equal',
      splits: [
        { memberId: memberY.id, amountInPaise: 30000 },
        { memberId: memberX.id, amountInPaise: 30000 },
      ],
    });

    const { settlement } = settlementService.recordSettlement(userB, trip.id, {
      fromMemberId: memberX.id,
      toMemberId: memberY.id,
      amountInPaise: 30000,
      status: 'marked_paid',
    });

    // Y confirms payment received
    const result = settlementService.confirmSettlement(userA, trip.id, settlement.id);
    assert.equal(result.settlement.status, 'confirmed');
    assert.equal(result.settlement.isSettled, true);
    assert.ok(result.settlement.confirmedAt);

    // Debt is now settled and removed from active list
    const balanceX = expenseService.getBalanceSummary(trip.id, userB.id);
    assert.equal(balanceX.currentUserOwedInPaise, 0);
    assert.equal(balanceX.simplifiedSettlements.length, 0);
  });

  test('3. Receiver disputes payment -> transitions to disputed, payer can submit proof', () => {
    const { user: userA } = authService.createGuest({ displayName: 'Y (Receiver)' });
    const { user: userB } = authService.createGuest({ displayName: 'X (Payer)' });

    const trip = tripService.createTrip(userA, { name: 'Goa Trip' });
    const memberY = trip.members.find((m) => m.userId === userA.id);
    const joined = tripService.joinTripByCode(userB, trip.inviteCode);
    const memberX = joined.members.find((m) => m.userId === userB.id);

    expenseService.createExpense(userA, trip.id, {
      title: 'Dinner',
      amountInPaise: 60000,
      paidById: memberY.id,
      splitType: 'equal',
      splits: [
        { memberId: memberY.id, amountInPaise: 30000 },
        { memberId: memberX.id, amountInPaise: 30000 },
      ],
    });

    const { settlement } = settlementService.recordSettlement(userB, trip.id, {
      fromMemberId: memberX.id,
      toMemberId: memberY.id,
      amountInPaise: 30000,
      status: 'marked_paid',
    });

    // Y disputes: "Didn't receive in my bank account"
    const disputeRes = settlementService.disputeSettlement(userA, trip.id, settlement.id, {
      reason: 'No money received in bank account',
    });
    assert.equal(disputeRes.settlement.status, 'disputed');
    assert.equal(disputeRes.settlement.isSettled, false);
    assert.equal(disputeRes.settlement.disputeReason, 'No money received in bank account');

    // X submits proof
    const proofRes = settlementService.submitPaymentProof(userB, trip.id, settlement.id, {
      transactionRef: 'UTR9988776655',
      proofNote: 'Transferred via PhonePe UPI at 10:15 PM',
    });
    assert.equal(proofRes.settlement.status, 'proof_submitted');
    assert.equal(proofRes.settlement.isSettled, false);
    assert.equal(proofRes.settlement.transactionRef, 'UTR9988776655');

    // Y reviews proof and confirms
    const finalConfirm = settlementService.confirmSettlement(userA, trip.id, settlement.id);
    assert.equal(finalConfirm.settlement.status, 'confirmed');
    assert.equal(finalConfirm.settlement.isSettled, true);

    const balanceX = expenseService.getBalanceSummary(trip.id, userB.id);
    assert.equal(balanceX.currentUserOwedInPaise, 0);
  });

  test('4. Authorization check: Payer cannot confirm their own payment (only receiver or creator can confirm)', () => {
    const { user: userA } = authService.createGuest({ displayName: 'Y (Receiver)' });
    const { user: userB } = authService.createGuest({ displayName: 'X (Payer)' });

    const trip = tripService.createTrip(userA, { name: 'Goa Trip' });
    const memberY = trip.members.find((m) => m.userId === userA.id);
    const joined = tripService.joinTripByCode(userB, trip.inviteCode);
    const memberX = joined.members.find((m) => m.userId === userB.id);

    expenseService.createExpense(userA, trip.id, {
      title: 'Dinner',
      amountInPaise: 60000,
      paidById: memberY.id,
      splitType: 'equal',
      splits: [
        { memberId: memberY.id, amountInPaise: 30000 },
        { memberId: memberX.id, amountInPaise: 30000 },
      ],
    });

    const { settlement } = settlementService.recordSettlement(userB, trip.id, {
      fromMemberId: memberX.id,
      toMemberId: memberY.id,
      amountInPaise: 30000,
      status: 'marked_paid',
    });

    // Payer (userB) tries to confirm their own payment -> 403 Forbidden
    assert.throws(
      () => settlementService.confirmSettlement(userB, trip.id, settlement.id),
      (err) => err.statusCode === 403
    );
  });
});
