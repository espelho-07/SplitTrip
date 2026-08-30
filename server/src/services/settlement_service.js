const crypto = require('crypto');
const { db } = require('../db/database');
const { AppError } = require('../middleware/error_handler');
const pushNotificationService = require('./push_notification_service');

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

    const isActuallyPaid = status === 'paid' || status === 'confirmed' || status === 'completed';
    const now = new Date().toISOString();
    const settlement = {
      id: id || `stl_${crypto.randomUUID().replace(/-/g, '').substring(0, 12)}`,
      tripId,
      fromMemberId: fromMember.id,
      toMemberId: toMember.id,
      amountInPaise,
      paymentReference: paymentReference || null,
      recipientUpiId: recipientUpiId || null,
      status: isActuallyPaid ? 'confirmed' : (status || 'marked_paid'),
      note: note || null,
      isSettled: isActuallyPaid,
      recordedByUserId: user.id,
      markedPaidAt: now,
      settledAt: isActuallyPaid ? now : null,
      confirmedAt: isActuallyPaid ? now : null,
      disputedAt: null,
      disputeReason: null,
      transactionRef: paymentReference || null,
      proofImageUrl: null,
      proofNote: null,
      proofSubmittedAt: null,
      createdAt: now,
    };

    db.insert('settlements', settlement);
    db.update('trips', tripId, { updatedAt: now, revision: (trip.revision || 1) + 1 });

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
        status: settlement.status,
      },
    });

    const allSettlements = this.getSettlementsForTrip(tripId);

    // 2. Build notification payload (used by both WebSocket and FCM)
    const notificationPayload = {
      type: 'settlement_marked_paid',
      tripId,
      tripName: trip.name,
      settlementId: settlement.id,
      payerName: fromMember.displayName || 'Friend',
      payerUserId: fromMember.userId,
      recipientMemberId: toMember.id,
      recipientUserId: toMember.userId,
      amountInPaise,
      currency: trip.currencyCode || 'INR',
      message: `${fromMember.displayName} marked ₹${(amountInPaise / 100).toFixed(0)} as paid to you`,
      timestamp: now,
    };

    if (realtimeHub) {
      // Broadcast 'settlement_marked_paid' — matches the Flutter TripDetailViewModel listener
      realtimeHub.broadcastToTrip(tripId, 'settlement_marked_paid', {
        tripId,
        settlementId: settlement.id,
        settlement,
        settlements: allSettlements,
        notification: notificationPayload,
        // Also include recipientUserId at top-level for fallback detection
        recipientUserId: toMember.userId,
        payerName: fromMember.displayName,
        amountInPaise,
      });
    }

    // FCM push to receiver (works even when app is backgrounded or terminated)
    if (toMember.userId) {
      pushNotificationService.sendToUser(db, toMember.userId, {
        title: 'Payment Sent — Confirm Receipt 💸',
        body: `${fromMember.displayName} marked ₹${(amountInPaise / 100).toFixed(0)} as paid to you. Tap to confirm.`,
        data: {
          type: 'settlement_marked_paid',
          route: `/trip/${tripId}`,
          tripId,
          settlementId: settlement.id,
          idempotencyKey: `${settlement.id}_marked_paid`,
        },
      });
    }

    return { settlement, settlements: allSettlements };
  }

  /**
   * Confirms a settlement payment by the recipient or trip creator.
   * Transitions settlement status to 'confirmed' and sets isSettled to true.
   */
  confirmSettlement(user, tripId, settlementId, realtimeHub = null) {
    const settlement = db.get('settlements', settlementId);
    if (!settlement || settlement.tripId !== tripId) {
      throw AppError.notFound('Settlement not found');
    }

    const trip = db.get('trips', tripId);
    if (!trip) throw AppError.notFound('Trip not found');

    const authMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === user.id);
    if (!authMember) throw AppError.forbidden('You are not a member of this trip');

    const toMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.id === settlement.toMemberId);
    const fromMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.id === settlement.fromMemberId);

    const isReceiver = toMember && toMember.userId === user.id;
    const isTripCreator = trip.creatorId === user.id || authMember.role === 'creator';

    if (!isReceiver && !isTripCreator) {
      throw AppError.forbidden('Only the payment receiver or trip creator can confirm this payment');
    }

    const now = new Date().toISOString();
    const updatedSettlement = {
      ...settlement,
      status: 'confirmed',
      isSettled: true,
      confirmedAt: now,
      settledAt: now,
    };

    db.update('settlements', settlementId, updatedSettlement);
    db.update('trips', tripId, { updatedAt: now, revision: (trip.revision || 1) + 1 });

    const tripService = require('./trip_service');
    tripService.logActivity(tripId, {
      type: 'settlement_confirmed',
      actorId: user.id,
      actorName: toMember?.displayName || user.displayName || 'Receiver',
      description: `${toMember?.displayName || 'Receiver'} confirmed receiving ₹${(settlement.amountInPaise / 100).toFixed(0)} from ${fromMember?.displayName || 'Payer'} ✓`,
      metadata: {
        settlementId,
        fromMemberId: settlement.fromMemberId,
        fromUserId: fromMember?.userId,
        toMemberId: settlement.toMemberId,
        toUserId: toMember?.userId,
        amountInPaise: settlement.amountInPaise,
        status: 'confirmed',
      },
    });

    const allSettlements = this.getSettlementsForTrip(tripId);

    if (realtimeHub) {
      realtimeHub.broadcastToTrip(tripId, 'settlement_confirmed', {
        tripId,
        settlement: updatedSettlement,
        settlements: allSettlements,
        notification: {
          type: 'settlement_confirmed',
          tripId,
          tripName: trip.name,
          settlementId,
          payerName: fromMember?.displayName || 'Friend',
          payerUserId: fromMember?.userId,
          receiverName: toMember?.displayName || 'Friend',
          amountInPaise: settlement.amountInPaise,
          currency: trip.currencyCode || 'INR',
          message: `${toMember?.displayName || 'Receiver'} confirmed your payment of ₹${(settlement.amountInPaise / 100).toFixed(0)} ✓`,
          timestamp: now,
        },
      });
    }

    // FCM push to payer (notify them that the receiver confirmed)
    if (fromMember?.userId) {
      pushNotificationService.sendToUser(db, fromMember.userId, {
        title: 'Payment Confirmed ✅',
        body: `${toMember?.displayName || 'Your friend'} confirmed receiving ₹${(settlement.amountInPaise / 100).toFixed(0)}. Payment complete!`,
        data: {
          type: 'settlement_confirmed',
          route: `/trip/${tripId}`,
          tripId,
          settlementId,
          idempotencyKey: `${settlementId}_confirmed`,
        },
      });
    }

    return { settlement: updatedSettlement, settlements: allSettlements };
  }

  /**
   * Disputes a settlement payment by the recipient when money was not received.
   * Transitions settlement status to 'disputed' and keeps isSettled false.
   */
  disputeSettlement(user, tripId, settlementId, { reason = null } = {}, realtimeHub = null) {
    const settlement = db.get('settlements', settlementId);
    if (!settlement || settlement.tripId !== tripId) {
      throw AppError.notFound('Settlement not found');
    }

    const trip = db.get('trips', tripId);
    if (!trip) throw AppError.notFound('Trip not found');

    const authMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === user.id);
    if (!authMember) throw AppError.forbidden('You are not a member of this trip');

    const toMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.id === settlement.toMemberId);
    const fromMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.id === settlement.fromMemberId);

    const isReceiver = toMember && toMember.userId === user.id;
    const isTripCreator = trip.creatorId === user.id || authMember.role === 'creator';

    if (!isReceiver && !isTripCreator) {
      throw AppError.forbidden('Only the payment receiver or trip creator can dispute this payment');
    }

    const now = new Date().toISOString();
    const updatedSettlement = {
      ...settlement,
      status: 'disputed',
      isSettled: false,
      disputedAt: now,
      disputeReason: reason || 'Marked not received by receiver',
    };

    db.update('settlements', settlementId, updatedSettlement);
    db.update('trips', tripId, { updatedAt: now, revision: (trip.revision || 1) + 1 });

    const tripService = require('./trip_service');
    tripService.logActivity(tripId, {
      type: 'settlement_disputed',
      actorId: user.id,
      actorName: toMember?.displayName || user.displayName || 'Receiver',
      description: `${toMember?.displayName || 'Receiver'} reported that ₹${(settlement.amountInPaise / 100).toFixed(0)} was NOT received from ${fromMember?.displayName || 'Payer'}`,
      metadata: {
        settlementId,
        fromMemberId: settlement.fromMemberId,
        fromUserId: fromMember?.userId,
        toMemberId: settlement.toMemberId,
        toUserId: toMember?.userId,
        amountInPaise: settlement.amountInPaise,
        status: 'disputed',
        reason: reason || 'Not received',
      },
    });

    const allSettlements = this.getSettlementsForTrip(tripId);

    if (realtimeHub) {
      realtimeHub.broadcastToTrip(tripId, 'settlement_disputed', {
        tripId,
        settlement: updatedSettlement,
        settlements: allSettlements,
        notification: {
          type: 'settlement_disputed',
          tripId,
          tripName: trip.name,
          settlementId,
          payerName: fromMember?.displayName || 'Friend',
          payerUserId: fromMember?.userId,
          receiverName: toMember?.displayName || 'Friend',
          amountInPaise: settlement.amountInPaise,
          currency: trip.currencyCode || 'INR',
          message: `${toMember?.displayName || 'Receiver'} reported that your ₹${(settlement.amountInPaise / 100).toFixed(0)} payment was not received`,
          timestamp: now,
        },
      });
    }

    // FCM push to payer (notify them that the receiver disputed the payment)
    if (fromMember?.userId) {
      pushNotificationService.sendToUser(db, fromMember.userId, {
        title: 'Payment Disputed ⚠️',
        body: `${toMember?.displayName || 'Your friend'} reported they didn't receive your ₹${(settlement.amountInPaise / 100).toFixed(0)} payment. Please review.`,
        data: {
          type: 'settlement_disputed',
          route: `/trip/${tripId}`,
          tripId,
          settlementId,
          idempotencyKey: `${settlementId}_disputed`,
        },
      });
    }

    return { settlement: updatedSettlement, settlements: allSettlements };
  }

  /**
   * Submits payment proof (UTR / transaction reference / screenshot / note) by the payer.
   * Transitions settlement status to 'proof_submitted'.
   */
  submitPaymentProof(user, tripId, settlementId, { transactionRef = null, proofImageUrl = null, proofNote = null } = {}, realtimeHub = null) {
    const settlement = db.get('settlements', settlementId);
    if (!settlement || settlement.tripId !== tripId) {
      throw AppError.notFound('Settlement not found');
    }

    const trip = db.get('trips', tripId);
    if (!trip) throw AppError.notFound('Trip not found');

    const authMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === user.id);
    if (!authMember) throw AppError.forbidden('You are not a member of this trip');

    const fromMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.id === settlement.fromMemberId);
    const toMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.id === settlement.toMemberId);

    const isPayer = fromMember && fromMember.userId === user.id;
    const isTripCreator = trip.creatorId === user.id || authMember.role === 'creator';

    if (!isPayer && !isTripCreator) {
      throw AppError.forbidden('Only the payment payer or trip creator can submit payment proof');
    }

    const now = new Date().toISOString();
    const updatedSettlement = {
      ...settlement,
      status: 'proof_submitted',
      isSettled: false,
      transactionRef: transactionRef || settlement.transactionRef || settlement.paymentReference,
      proofImageUrl: proofImageUrl || settlement.proofImageUrl,
      proofNote: proofNote || settlement.proofNote,
      proofSubmittedAt: now,
    };

    db.update('settlements', settlementId, updatedSettlement);
    db.update('trips', tripId, { updatedAt: now, revision: (trip.revision || 1) + 1 });

    const tripService = require('./trip_service');
    tripService.logActivity(tripId, {
      type: 'payment_proof_submitted',
      actorId: user.id,
      actorName: fromMember?.displayName || user.displayName || 'Payer',
      description: `${fromMember?.displayName || 'Payer'} submitted payment proof for ₹${(settlement.amountInPaise / 100).toFixed(0)} to ${toMember?.displayName || 'Receiver'}`,
      metadata: {
        settlementId,
        fromMemberId: settlement.fromMemberId,
        fromUserId: fromMember?.userId,
        toMemberId: settlement.toMemberId,
        toUserId: toMember?.userId,
        amountInPaise: settlement.amountInPaise,
        transactionRef,
        status: 'proof_submitted',
      },
    });

    const allSettlements = this.getSettlementsForTrip(tripId);

    if (realtimeHub) {
      // Use 'payment_proof_submitted' to match Flutter listener in TripDetailViewModel
      realtimeHub.broadcastToTrip(tripId, 'payment_proof_submitted', {
        tripId,
        settlement: updatedSettlement,
        settlements: allSettlements,
        notification: {
          type: 'payment_proof_submitted',
          tripId,
          tripName: trip.name,
          settlementId,
          payerName: fromMember?.displayName || 'Friend',
          payerUserId: fromMember?.userId,
          recipientMemberId: toMember?.id,
          recipientUserId: toMember?.userId,
          amountInPaise: settlement.amountInPaise,
          currency: trip.currencyCode || 'INR',
          message: `Payment proof submitted by ${fromMember?.displayName || 'Payer'} for ₹${(settlement.amountInPaise / 100).toFixed(0)}`,
          timestamp: now,
        },
      });
    }

    // FCM push to receiver (notify them that payer submitted proof)
    if (toMember?.userId) {
      pushNotificationService.sendToUser(db, toMember.userId, {
        title: 'Payment Proof Uploaded 📎',
        body: `${fromMember?.displayName || 'Your friend'} submitted payment proof for ₹${(settlement.amountInPaise / 100).toFixed(0)}. Review and confirm receipt.`,
        data: {
          type: 'payment_proof_submitted',
          route: `/trip/${tripId}`,
          tripId,
          settlementId,
          idempotencyKey: `${settlementId}_proof`,
        },
      });
    }

    return { settlement: updatedSettlement, settlements: allSettlements };
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
    return settlements.sort((a, b) => new Date(b.settledAt || b.confirmedAt || b.createdAt) - new Date(a.settledAt || a.confirmedAt || a.createdAt));
  }
}

module.exports = new SettlementService();
