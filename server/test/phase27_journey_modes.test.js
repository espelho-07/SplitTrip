const { test, describe, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const authService = require('../src/services/auth_service');
const tripService = require('../src/services/trip_service');
const expenseService = require('../src/services/expense_service');
const journeyService = require('../src/services/journey_service');
const { db } = require('../src/db/database');

describe('Phase 27 Core Intelligence & Journey Modes Test Suite', () => {
  beforeEach(() => {
    db.clearAll();
  });

  test('1. Trip Modes: Split Only vs Split + Journey creation', () => {
    const auth = authService.loginWithGoogle({
      email: 'creator@kith.app',
      displayName: 'Creator',
      googleId: 'g_creator_27',
    });

    // Create Split-only trip
    const splitOnlyTrip = tripService.createTrip(auth.user, {
      name: 'Weekend Expenses',
      tripMode: 'split_only',
    });
    assert.equal(splitOnlyTrip.tripMode, 'split_only');

    // Create Split + Journey trip
    const journeyTrip = tripService.createTrip(auth.user, {
      name: 'Goa Vacation 2026',
      tripMode: 'split_and_journey',
    });
    assert.equal(journeyTrip.tripMode, 'split_and_journey');
  });

  test('2. Automatic Journey Moment Creation from Trip Expense in Split + Journey mode', () => {
    const auth = authService.loginWithGoogle({
      email: 'creator@kith.app',
      displayName: 'Creator',
      googleId: 'g_creator_27',
    });

    const trip = tripService.createTrip(auth.user, {
      name: 'Goa Vacation 2026',
      tripMode: 'split_and_journey',
    });

    const members = db.find('trip_members', (m) => m.tripId === trip.id);

    // Add Dinner expense
    const res = expenseService.createExpense(auth.user, trip.id, {
      title: "Fisherman's Wharf Dinner",
      amountInPaise: 120000,
      category: 'food',
      paidById: members[0].id,
      splitType: 'equal',
      splits: [{ memberId: members[0].id, amountInPaise: 120000 }],
    });

    assert.equal(res.expense.amountInPaise, 120000);

    // Verify automatic Journey moment created and linked to expense
    const moments = journeyService.getTripMoments(auth.user, trip.id);
    assert.equal(moments.length, 1);
    assert.equal(moments[0].expenseId, res.expense.id);
    assert.ok(moments[0].title.includes("Fisherman's Wharf Dinner"));
    assert.equal(moments[0].placeName, "Fisherman's Wharf Dinner");
  });

  test('3. Split-Only Trip does NOT automatically clutter Journey moments', () => {
    const auth = authService.loginWithGoogle({
      email: 'creator@kith.app',
      displayName: 'Creator',
      googleId: 'g_creator_27',
    });

    const trip = tripService.createTrip(auth.user, {
      name: 'Flat Rent & Groceries',
      tripMode: 'split_only',
    });

    const members = db.find('trip_members', (m) => m.tripId === trip.id);

    // Add rent expense
    expenseService.createExpense(auth.user, trip.id, {
      title: 'Monthly Rent',
      amountInPaise: 2500000,
      category: 'stay',
      paidById: members[0].id,
      splitType: 'equal',
      splits: [{ memberId: members[0].id, amountInPaise: 2500000 }],
    });

    // Verify moments remain clean and empty for Split-only trips
    const moments = journeyService.getTripMoments(auth.user, trip.id);
    assert.equal(moments.length, 0);
  });
});
