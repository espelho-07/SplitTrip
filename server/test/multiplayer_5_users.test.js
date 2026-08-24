const { test, describe, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const authService = require('../src/services/auth_service');
const tripService = require('../src/services/trip_service');
const expenseService = require('../src/services/expense_service');
const { db } = require('../src/db/database');

describe('Multiplayer 5-User Trip End-to-End Simulation', () => {
  beforeEach(() => {
    db.clearAll();
  });

  test('5 independent users join same trip, add multi-payer expenses, reconcile balances and settle up', () => {
    // 1. Five independent users register as guests
    const uRahul = authService.createGuest({ displayName: 'Rahul' });
    const uAman = authService.createGuest({ displayName: 'Aman' });
    const uPriya = authService.createGuest({ displayName: 'Priya' });
    const uSneha = authService.createGuest({ displayName: 'Sneha' });
    const uVikram = authService.createGuest({ displayName: 'Vikram' });

    // 2. Rahul creates the trip
    let trip = tripService.createTrip(uRahul.user, {
      name: 'Goa Escape 2026',
      emoji: '🏖️',
      currencyCode: 'INR',
    });

    const inviteCode = trip.inviteCode;
    assert.equal(inviteCode.length, 6);

    // 3. Other 4 members join via invite code
    trip = tripService.joinTripByCode(uAman.user, inviteCode);
    trip = tripService.joinTripByCode(uPriya.user, inviteCode);
    trip = tripService.joinTripByCode(uSneha.user, inviteCode);
    trip = tripService.joinTripByCode(uVikram.user, inviteCode);

    assert.equal(trip.members.length, 5);

    const mRahul = trip.members.find((m) => m.userId === uRahul.user.id);
    const mAman = trip.members.find((m) => m.userId === uAman.user.id);
    const mPriya = trip.members.find((m) => m.userId === uPriya.user.id);
    const mSneha = trip.members.find((m) => m.userId === uSneha.user.id);
    const mVikram = trip.members.find((m) => m.userId === uVikram.user.id);

    // 4. Expense 1: Rahul pays ₹6,000 for train for all 5 members (₹1,200 / 120000p each)
    expenseService.createExpense(uRahul.user, trip.id, {
      title: 'Train to Goa',
      amountInPaise: 600000,
      category: 'transport',
      paidById: mRahul.id,
      splitType: 'equal',
      splits: [
        { memberId: mRahul.id, amountInPaise: 120000 },
        { memberId: mAman.id, amountInPaise: 120000 },
        { memberId: mPriya.id, amountInPaise: 120000 },
        { memberId: mSneha.id, amountInPaise: 120000 },
        { memberId: mVikram.id, amountInPaise: 120000 },
      ],
    });

    // 5. Expense 2: Aman pays ₹2,500 for dinner for all 5 members (₹500 / 50000p each)
    expenseService.createExpense(uAman.user, trip.id, {
      title: 'Beachside Dinner',
      amountInPaise: 250000,
      category: 'food',
      paidById: mAman.id,
      splitType: 'equal',
      splits: [
        { memberId: mRahul.id, amountInPaise: 50000 },
        { memberId: mAman.id, amountInPaise: 50000 },
        { memberId: mPriya.id, amountInPaise: 50000 },
        { memberId: mSneha.id, amountInPaise: 50000 },
        { memberId: mVikram.id, amountInPaise: 50000 },
      ],
    });

    // 6. Expense 3: Priya pays ₹1,500 for drinks split between Priya, Sneha, Vikram (₹500 / 50000p each)
    expenseService.createExpense(uPriya.user, trip.id, {
      title: 'Sunset Cocktails',
      amountInPaise: 150000,
      category: 'drinks',
      paidById: mPriya.id,
      splitType: 'equal',
      splits: [
        { memberId: mPriya.id, amountInPaise: 50000 },
        { memberId: mSneha.id, amountInPaise: 50000 },
        { memberId: mVikram.id, amountInPaise: 50000 },
      ],
    });

    // 7. Verify Balance Sheet and Conservation of Money
    const summary = expenseService.getBalanceSummary(trip.id, uRahul.user.id);
    assert.equal(summary.totalTripSpendingInPaise, 1000000); // ₹10,000 total

    // Check individual net balances
    assert.equal(summary.netBalancesInPaise[mRahul.id], 430000); // +₹4,300
    assert.equal(summary.netBalancesInPaise[mAman.id], 80000); // +₹800
    assert.equal(summary.netBalancesInPaise[mPriya.id], -70000); // -₹700
    assert.equal(summary.netBalancesInPaise[mSneha.id], -220000); // -₹2,200
    assert.equal(summary.netBalancesInPaise[mVikram.id], -220000); // -₹2,200

    // Strict zero-sum balance invariant: Sum(netBalances) === 0
    const sumNet = Object.values(summary.netBalancesInPaise).reduce((a, b) => a + b, 0);
    assert.equal(sumNet, 0);

    // 8. Rahul completes the trip
    const completedTrip = tripService.updateLifecycle(trip.id, uRahul.user.id, 'completed');
    assert.equal(completedTrip.lifecycleState, 'completed');

    // Verify simplified settlement transfers
    const settlements = summary.simplifiedSettlements;
    assert.ok(settlements.length > 0 && settlements.length <= 4); // Max 4 transfers for 5 people

    const totalSettledAmount = settlements.reduce((sum, s) => sum + s.amountInPaise, 0);
    assert.equal(totalSettledAmount, 510000); // Total transferred must equal total debt (4300 + 800) = 5100

    // 9. Vikram recovers his account on another device using his recovery key
    const recoveredVikram = authService.recoverGuest({ recoveryKey: uVikram.user.recoveryKey });
    assert.equal(recoveredVikram.user.id, uVikram.user.id);

    // Vikram can access the trip and sees his net owed amount
    const vikramSummary = expenseService.getBalanceSummary(trip.id, recoveredVikram.user.id);
    assert.equal(vikramSummary.currentUserNetBalanceInPaise, -220000);
    assert.equal(vikramSummary.currentUserOwedInPaise, 220000);
  });
});
