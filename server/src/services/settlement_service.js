const crypto = require('crypto');
const { db } = require('../db/database');
const { AppError } = require('../middleware/error_handler');

class SettlementService {
  /**
   * Greedy min-cash-flow graph reduction algorithm.
   * Transforms O(N^2) pairwise debts into minimal O(N) direct transfers.
   * Preserves 100% integer paise conservation.
   */
  simplifyDebts(netBalances, recordedSettlements = []) {
    // Start with original net balances
    const adjustedBalances = { ...netBalances };

    // Apply recorded settlements to net balances
    for (const stl of recordedSettlements) {
      if (stl.isSettled) {
        if (adjustedBalances[stl.fromMemberId] !== undefined) {
          adjustedBalances[stl.fromMemberId] += stl.amountInPaise;
        }
        if (adjustedBalances[stl.toMemberId] !== undefined) {
          adjustedBalances[stl.toMemberId] -= stl.amountInPaise;
        }
      }
    }

    // Separate creditors and debtors
    const debtors = [];
    const creditors = [];

    for (const [memberId, balance] of Object.entries(adjustedBalances)) {
      if (balance < 0) {
        debtors.push({ memberId, amount: -balance });
      } else if (balance > 0) {
        creditors.push({ memberId, amount: balance });
      }
    }

    // Sort descending for minimal transactions
    debtors.sort((a, b) => b.amount - a.amount);
    creditors.sort((a, b) => b.amount - a.amount);

    const transactions = [];
    let dIdx = 0;
    let cIdx = 0;

    while (dIdx < debtors.length && cIdx < creditors.length) {
      const debtor = debtors[dIdx];
      const creditor = creditors[cIdx];

      const settleAmount = Math.min(debtor.amount, creditor.amount);

      if (settleAmount > 0) {
        transactions.push({
          id: `stl_${crypto.randomUUID().replace(/-/g, '').substring(0, 10)}`,
          fromMemberId: debtor.memberId,
          toMemberId: creditor.memberId,
          amountInPaise: settleAmount,
          currency: 'INR',
          isSettled: false,
          settledAt: null,
        });

        debtor.amount -= settleAmount;
        creditor.amount -= settleAmount;
      }

      if (debtor.amount === 0) dIdx++;
      if (creditor.amount === 0) cIdx++;
    }

    return transactions;
  }

  /**
   * Records an explicit settlement payment between two members.
   * Validates participant membership, caller authorization, lifecycle state,
   * and ensures settlement amount does not exceed the debtor's actual pending debt.
   */
  recordSettlement(user, tripId, {
    id = null,
    fromMemberId,
    toMemberId,
    amountInPaise,
    paymentReference = null,
    recipientUpiId = null,
    status = 'paid',
    note = null,
  }, realtimeHub = null) {
    if (id) {
      const existing = db.get('settlements', id);
      if (existing) {
        return { settlement: existing, settlements: this.getSettlementsForTrip(tripId) };
      }
    }

    if (!Number.isInteger(amountInPaise) || amountInPaise <= 0) {
      throw AppError.badRequest('Settlement amount must be a positive integer in paise');
    }

    const trip = db.get('trips', tripId);
    if (!trip) throw AppError.notFound('Trip not found');

    if (trip.lifecycleState === 'settled') {
      throw AppError.badRequest('This trip is already settled. No further settlements can be recorded.');
    }

    const authMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === user.id);
    if (!authMember) throw AppError.forbidden('You are not a member of this trip');

    const fromMember = db.findOne('trip_members', (m) => m.tripId === tripId && (m.id === fromMemberId || m.userId === fromMemberId));
    const toMember = db.findOne('trip_members', (m) => m.tripId === tripId && (m.id === toMemberId || m.userId === toMemberId));

    if (!fromMember || !toMember) {
      throw AppError.badRequest('Both settlement participants must be members of this trip');
    }

    if (fromMember.id === toMember.id) {
      throw AppError.badRequest('Settlement cannot be made to the same member');
    }

    // Authorization: User must be payer, receiver, or trip creator
    const isPayer = fromMember.userId === user.id;
    const isReceiver = toMember.userId === user.id;
    const isTripCreator = trip.creatorId === user.id || authMember.role === 'creator';

    if (!isPayer && !isReceiver && !isTripCreator) {
      throw AppError.forbidden('You do not have permission to record this settlement');
    }

    // Financial Validation: Ensure debtor actually owes money and amount doesn't exceed debt
    const expenses = db.find('expenses', (e) => e.tripId === tripId && !e.isDeleted);
    const prevSettlements = this.getSettlementsForTrip(tripId);

    let debtorPaid = 0;
    let debtorOwed = 0;
    for (const exp of expenses) {
      if (exp.paidById === fromMember.id) debtorPaid += exp.amountInPaise;
      for (const s of exp.splits) {
        if (s.memberId === fromMember.id) debtorOwed += s.amountInPaise;
      }
    }
    let debtorNetDebt = debtorOwed - debtorPaid;
    for (const stl of prevSettlements) {
      if (stl.fromMemberId === fromMember.id) debtorNetDebt -= stl.amountInPaise;
      if (stl.toMemberId === fromMember.id) debtorNetDebt += stl.amountInPaise;
    }

    if (debtorNetDebt <= 0) {
      throw AppError.badRequest(`${fromMember.displayName} does not have any pending debt to settle in this trip.`);
    }

    if (amountInPaise > debtorNetDebt) {
      throw AppError.badRequest(
        `Settlement amount ₹${(amountInPaise / 100).toFixed(2)} exceeds ${fromMember.displayName}'s total pending debt of ₹${(debtorNetDebt / 100).toFixed(2)}`
      );
    }

    const now = new Date().toISOString();
    const settlement = {
      id: id || `stl_${crypto.randomUUID().replace(/-/g, '').substring(0, 12)}`,
      tripId,
      fromMemberId: fromMember.id,
      toMemberId: toMember.id,
      amountInPaise,
      paymentReference: paymentReference || null,
      recipientUpiId: recipientUpiId || null,
      status: status || 'paid',
      note: note || null,
      isSettled: status === 'paid',
      recordedByUserId: user.id,
      settledAt: now,
      createdAt: now,
    };

    db.insert('settlements', settlement);
    db.update('trips', tripId, { updatedAt: now });

    // 1. Log Trip Activity for settlement event
    const tripService = require('./trip_service');
    tripService.logActivity(tripId, {
      type: 'settlement_recorded',
      actorId: user.id,
      actorName: fromMember.displayName || user.displayName || 'Member',
      description: `${fromMember.displayName} marked ₹${(amountInPaise / 100).toFixed(0)} as paid to ${toMember.displayName}`,
      metadata: {
        settlementId: settlement.id,
        fromMemberId: fromMember.id,
        fromUserId: fromMember.userId,
        toMemberId: toMember.id,
        toUserId: toMember.userId,
        amountInPaise,
        status: 'marked_paid',
      },
    });

    const allSettlements = this.getSettlementsForTrip(tripId);

    // 2. Broadcast realtime event with recipient notification
    if (realtimeHub) {
      realtimeHub.broadcastToTrip(tripId, 'settlement_recorded', {
        tripId,
        settlement,
        settlements: allSettlements,
        notification: {
          type: 'settlement_marked_paid',
          tripId,
          tripName: trip.name,
          payerName: fromMember.displayName || 'Friend',
          payerUserId: fromMember.userId,
          recipientMemberId: toMember.id,
          recipientUserId: toMember.userId,
          amountInPaise,
          currency: trip.currencyCode || 'INR',
          message: `${fromMember.displayName} marked ₹${(amountInPaise / 100).toFixed(0)} as paid to you`,
          timestamp: now,
        },
      });
    }

    return { settlement, settlements: allSettlements };
  }

  /**
   * Retrieves all settlements recorded for a trip with optional user membership verification.
   */
  getSettlementsForTrip(userOrTripId, possibleTripId) {
    let user = null;
    let tripId = null;
    if (possibleTripId !== undefined) {
      user = userOrTripId;
      tripId = possibleTripId;
    } else {
      tripId = userOrTripId;
    }

    if (user && tripId) {
      const trip = db.get('trips', tripId);
      if (!trip) throw AppError.notFound('Trip not found');
      const isMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === user.id);
      if (!isMember) throw AppError.forbidden('You are not a member of this trip');
    }

    const settlements = db.find('settlements', (s) => s.tripId === tripId);
    return settlements.sort((a, b) => new Date(b.settledAt || b.createdAt) - new Date(a.settledAt || a.createdAt));
  }
}

module.exports = new SettlementService();
