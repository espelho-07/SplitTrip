const crypto = require('crypto');
const { db } = require('../db/database');
const { dbManager } = require('../db/db_manager');
const { AppError } = require('../middleware/error_handler');
const settlementService = require('./settlement_service');

class ExpenseService {
  constructor(adapter = null) {
    this.adapter = adapter || dbManager.getAdapter();
  }

  createExpense(user, tripId, {
    id = null,
    title,
    amountInPaise,
    category = 'general',
    paidById,
    paidByMap = null,
    splitType = 'equal',
    splits = [],
    voiceTranscript = null,
    receiptUrl = null,
  }, realtimeHub = null) {
    // Idempotency: return existing expense if already created with this ID
    if (id) {
      const existing = db.get('expenses', id);
      if (existing && existing.tripId === tripId) {
        // Same client id is a retry. Do not insert a second row, and do not
        // resurrect an expense that was already deleted.
        const balanceSummary = this.getBalanceSummary(tripId, user.id);
        return { expense: existing, balanceSummary };
      }
    }
    if (!title || !title.trim()) {
      throw AppError.badRequest('Expense title is required');
    }

    if (!Number.isInteger(amountInPaise) || amountInPaise <= 0) {
      throw AppError.badRequest('Amount must be a positive integer in smallest currency units (paise)');
    }

    const trip = db.get('trips', tripId);
    if (!trip) throw AppError.notFound('Trip not found');

    const authMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === user.id);
    if (!authMember) throw AppError.forbidden('You are not a member of this trip');
    const now = new Date().toISOString();

    // Lifecycle check & late expense handling
    let isLateReconciled = false;
    if (trip.lifecycleState === 'completed' || trip.lifecycleState === 'completed_with_pending_changes' || trip.lifecycleState === 'settled') {
      // Reopen trip to active state to incorporate late added expense and preserve financial integrity
      db.update('trips', tripId, { lifecycleState: 'active', updatedAt: now });
      isLateReconciled = true;
    }

    // Verify payer member exists in trip or validate multi-payer allocation
    let validatedPaidByMap = null;
    let payerMember = null;

    if (paidByMap && typeof paidByMap === 'object' && Object.keys(paidByMap).length > 0) {
      let paidBySum = 0;
      validatedPaidByMap = {};
      for (const [pId, amt] of Object.entries(paidByMap)) {
        const member = db.findOne('trip_members', (m) => m.tripId === tripId && (m.id === pId || m.userId === pId));
        if (!member) {
          throw AppError.badRequest(`Payer member ${pId} is not part of this trip`);
        }
        const numAmt = Number(amt);
        if (!Number.isInteger(numAmt) || numAmt < 0) {
          throw AppError.badRequest(`Amount for payer ${pId} must be a non-negative integer in paise`);
        }
        paidBySum += numAmt;
        validatedPaidByMap[member.id] = numAmt;
      }
      if (paidBySum !== amountInPaise) {
        throw AppError.badRequest(
          `Paid sum mismatch: Total is ₹${(amountInPaise / 100).toFixed(2)} (${amountInPaise}p) but payers sum to ₹${(paidBySum / 100).toFixed(2)} (${paidBySum}p)`
        );
      }
      if (paidById) {
        payerMember = db.findOne('trip_members', (m) => m.tripId === tripId && (m.id === paidById || m.userId === paidById));
      }
      if (!payerMember && Object.keys(validatedPaidByMap).length > 0) {
        const firstPayerId = Object.keys(validatedPaidByMap)[0];
        payerMember = db.get('trip_members', firstPayerId);
      }
    } else {
      payerMember = db.findOne('trip_members', (m) => m.tripId === tripId && (m.id === paidById || m.userId === paidById));
    }

    if (!payerMember) {
      throw AppError.badRequest('Payer member is not part of this trip');
    }

    if (!Array.isArray(splits) || splits.length === 0) {
      throw AppError.badRequest('At least one participant split is required');
    }

    // Server-Side Financial Validation: Sum of splits must strictly equal total amount
    let splitSum = 0;
    const validatedSplits = [];

    for (const split of splits) {
      if (!split.memberId) {
        throw AppError.badRequest('Each split must specify a valid memberId');
      }

      const member = db.findOne('trip_members', (m) => m.tripId === tripId && (m.id === split.memberId || m.userId === split.memberId));
      if (!member) {
        throw AppError.badRequest(`Split participant ${split.memberId} is not in this trip`);
      }

      if (!Number.isInteger(split.amountInPaise) || split.amountInPaise < 0) {
        throw AppError.badRequest('Each split amount must be a non-negative integer in paise');
      }

      splitSum += split.amountInPaise;
      validatedSplits.push({
        memberId: member.id,
        amountInPaise: split.amountInPaise,
        shares: typeof split.shares === 'number' ? split.shares : null,
        percentage: typeof split.percentage === 'number' ? split.percentage : null,
      });
    }

    if (splitSum !== amountInPaise) {
      throw AppError.badRequest(
        `Split sum mismatch: Total is ₹${(amountInPaise / 100).toFixed(2)} (${amountInPaise}p) but splits sum to ₹${(splitSum / 100).toFixed(2)} (${splitSum}p)`
      );
    }

    const newRevision = (trip.revision || 1) + 1;
    const expense = {
      id: id || `exp_${crypto.randomUUID().replace(/-/g, '').substring(0, 12)}`,
      tripId,
      title: title.trim(),
      amountInPaise,
      category,
      paidById: payerMember.id,
      paidByMap: validatedPaidByMap,
      splitType,
      splits: validatedSplits,
      voiceTranscript: voiceTranscript || null,
      receiptUrl: receiptUrl || null,
      isDeleted: false,
      isLateReconciled,
      createdByUserId: user.id,
      createdAt: now,
      updatedAt: now,
    };

    db.insert('expenses', expense);
    db.update('trips', tripId, { updatedAt: now, revision: newRevision });
    // Update user's member lastSyncedRevision and lastSeenAt
    db.update('trip_members', authMember.id, { lastSyncedRevision: newRevision, lastSeenAt: now });

    // Automatic Journey / Memory Enrichment for Split + Journey trips
    if (trip.tripMode === 'split_and_journey') {
      try {
        const journeyService = require('./journey_service');
        const categoryEmojis = {
          food: '🍴',
          transport: '🚆',
          stay: '🏨',
          drinks: '☕',
          activities: '🎟️',
          shopping: '🛍️',
          groceries: '🛒',
          general: '📍',
        };
        const emoji = categoryEmojis[category] || '📍';

        journeyService.createMoment(user, tripId, {
          title: `${emoji} ${title.trim()}`,
          placeName: title.trim(),
          note: `Expense ₹${(amountInPaise / 100).toFixed(2)} paid by ${payerMember.displayName}`,
          expenseId: expense.id,
          occurredAt: now,
        }, realtimeHub);
      } catch (err) {
        // Non-blocking journey enrichment
      }
    }

    const tripService = require('./trip_service');
    tripService.logActivity(tripId, {
      type: 'expense_added',
      actorId: user.id,
      actorName: authMember.displayName,
      description: `${authMember.displayName} added "${title.trim()}" for ₹${(amountInPaise / 100).toFixed(2)}`,
      metadata: { expenseId: expense.id, amountInPaise },
    });

    const balanceSummary = this.getBalanceSummary(tripId, user.id);

    try {
      const notificationService = require('./notification_service');
      notificationService.notifyExpenseCreated({
        actor: user,
        trip,
        expense,
        authMember,
        realtimeHub,
      });
    } catch (err) {
      console.warn('[ExpenseService] notifyExpenseCreated notice:', err.message);
    }

    if (realtimeHub) {
      realtimeHub.broadcastToTrip(tripId, 'expense_added', {
        tripId,
        expense,
        balanceSummary,
      });
    }

    return { expense, balanceSummary };
  }

  updateExpense(user, tripId, expenseId, { title, amountInPaise, category = 'general', paidById, paidByMap = null, splitType = 'equal', splits = [], voiceTranscript, receiptUrl, updatedAt: clientUpdatedAt = null }, realtimeHub = null) {
    const trip = db.get('trips', tripId);
    if (!trip) throw AppError.notFound('Trip not found');

    const authMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === user.id);
    if (!authMember) throw AppError.forbidden('Not a member of this trip');

    if (trip.lifecycleState === 'completed' || trip.lifecycleState === 'settled') {
      db.update('trips', tripId, { lifecycleState: 'active', updatedAt: new Date().toISOString() });
    }

    const existing = db.get('expenses', expenseId);
    if (!existing || existing.tripId !== tripId || existing.isDeleted) {
      throw AppError.notFound('Expense not found');
    }

    // Last-Write-Wins: an older client timestamp must not replace a newer server expense.
    if (existing.updatedAt && clientUpdatedAt) {
      const clientTime = new Date(clientUpdatedAt).getTime();
      const serverTime = new Date(existing.updatedAt).getTime();
      if (!Number.isNaN(clientTime) && clientTime < serverTime) {
        const balanceSummary = this.getBalanceSummary(tripId, user.id);
        return { expense: existing, balanceSummary };
      }
    }

    const isTripCreator = trip.creatorId === user.id || authMember.role === 'creator';
    const isExpenseCreator = existing.createdByUserId === user.id;
    const isPayer = existing.paidById === authMember.id;

    if (!isTripCreator && !isExpenseCreator && !isPayer) {
      throw AppError.forbidden('You do not have permission to edit this expense');
    }

    if (!title || !title.trim()) {
      throw AppError.badRequest('Expense title is required');
    }

    if (!Number.isInteger(amountInPaise) || amountInPaise <= 0) {
      throw AppError.badRequest('Amount must be a positive integer in paise');
    }

    // Verify payer member exists in trip or validate multi-payer allocation
    let validatedPaidByMap = null;
    let payerMember = null;

    if (paidByMap && typeof paidByMap === 'object' && Object.keys(paidByMap).length > 0) {
      let paidBySum = 0;
      validatedPaidByMap = {};
      for (const [pId, amt] of Object.entries(paidByMap)) {
        const member = db.findOne('trip_members', (m) => m.tripId === tripId && (m.id === pId || m.userId === pId));
        if (!member) {
          throw AppError.badRequest(`Payer member ${pId} is not part of this trip`);
        }
        const numAmt = Number(amt);
        if (!Number.isInteger(numAmt) || numAmt < 0) {
          throw AppError.badRequest(`Amount for payer ${pId} must be a non-negative integer in paise`);
        }
        paidBySum += numAmt;
        validatedPaidByMap[member.id] = numAmt;
      }
      if (paidBySum !== amountInPaise) {
        throw AppError.badRequest(
          `Paid sum mismatch: Total is ₹${(amountInPaise / 100).toFixed(2)} (${amountInPaise}p) but payers sum to ₹${(paidBySum / 100).toFixed(2)} (${paidBySum}p)`
        );
      }
      if (paidById) {
        payerMember = db.findOne('trip_members', (m) => m.tripId === tripId && (m.id === paidById || m.userId === paidById));
      }
      if (!payerMember && Object.keys(validatedPaidByMap).length > 0) {
        const firstPayerId = Object.keys(validatedPaidByMap)[0];
        payerMember = db.get('trip_members', firstPayerId);
      }
    } else {
      payerMember = db.findOne('trip_members', (m) => m.tripId === tripId && (m.id === paidById || m.userId === paidById));
    }

    if (!payerMember) {
      throw AppError.badRequest('Payer must be a member of this trip');
    }

    if (!Array.isArray(splits) || splits.length === 0) {
      throw AppError.badRequest('At least one participant split is required');
    }

    let splitSum = 0;
    const validatedSplits = [];
    for (const split of splits) {
      if (!split.memberId) throw AppError.badRequest('Each split must specify a valid memberId');
      const member = db.findOne('trip_members', (m) => m.tripId === tripId && (m.id === split.memberId || m.userId === split.memberId));
      if (!member) throw AppError.badRequest(`Split participant ${split.memberId} is not in this trip`);
      if (!Number.isInteger(split.amountInPaise) || split.amountInPaise < 0) {
        throw AppError.badRequest('Each split amount must be a non-negative integer in paise');
      }
      splitSum += split.amountInPaise;
      validatedSplits.push({
        memberId: member.id,
        amountInPaise: split.amountInPaise,
        shares: typeof split.shares === 'number' ? split.shares : null,
        percentage: typeof split.percentage === 'number' ? split.percentage : null,
      });
    }

    if (splitSum !== amountInPaise) {
      throw AppError.badRequest(
        `Split sum mismatch: Total is ₹${(amountInPaise / 100).toFixed(2)} but splits sum to ₹${(splitSum / 100).toFixed(2)}`
      );
    }

    const now = new Date().toISOString();
    const updated = {
      ...existing,
      title: title.trim(),
      amountInPaise,
      category,
      paidById: payerMember.id,
      paidByMap: validatedPaidByMap,
      splitType,
      splits: validatedSplits,
      voiceTranscript: voiceTranscript || existing.voiceTranscript || null,
      receiptUrl: receiptUrl || existing.receiptUrl || null,
      updatedAt: now,
    };

    db.update('expenses', expenseId, updated);
    db.update('trips', tripId, { updatedAt: now, revision: (trip.revision || 1) + 1 });
    db.update('trip_members', authMember.id, { lastSyncedRevision: (trip.revision || 1) + 1, lastSeenAt: now });

    const tripService = require('./trip_service');
    tripService.logActivity(tripId, {
      type: 'expense_updated',
      actorId: user.id,
      actorName: authMember.displayName,
      description: `${authMember.displayName} updated "${title.trim()}" (₹${(amountInPaise / 100).toFixed(2)})`,
      metadata: { expenseId, amountInPaise },
    });

    const balanceSummary = this.getBalanceSummary(tripId, user.id);

    try {
      const notificationService = require('./notification_service');
      notificationService.notifyExpenseUpdated({
        actor: user,
        trip,
        oldExpense: existing,
        newExpense: updated,
        authMember,
        realtimeHub,
      });
    } catch (err) {
      console.warn('[ExpenseService] notifyExpenseUpdated notice:', err.message);
    }

    if (realtimeHub) {
      realtimeHub.broadcastToTrip(tripId, 'expense_updated', {
        tripId,
        expense: updated,
        balanceSummary,
      });
    }

    return { expense: updated, balanceSummary };
  }

  getExpenses(tripId, userId) {
    const trip = db.get('trips', tripId);
    if (!trip) throw AppError.notFound('Trip not found');

    const authMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === userId);
    if (!authMember) throw AppError.forbidden('Not authorized to view expenses for this trip');

    const expenses = db.find('expenses', (e) => e.tripId === tripId && !e.isDeleted);
    return expenses.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
  }

  deleteExpense(tripId, expenseId, user, realtimeHub = null) {
    const trip = db.get('trips', tripId);
    if (!trip) throw AppError.notFound('Trip not found');

    const authMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === user.id);
    if (!authMember) throw AppError.forbidden('Not a member of this trip');

    if (trip.lifecycleState === 'completed' || trip.lifecycleState === 'settled') {
      db.update('trips', tripId, { lifecycleState: 'active', updatedAt: new Date().toISOString() });
    }

    const expense = db.get('expenses', expenseId);
    if (!expense || expense.tripId !== tripId) {
      throw AppError.notFound('Expense not found');
    }
    if (expense.isDeleted) {
      return { expense, balanceSummary: this.getBalanceSummary(tripId, user.id), alreadyDeleted: true };
    }

    // Only creator of trip, creator of expense, or payer can delete
    const isTripCreator = trip.creatorId === user.id || authMember.role === 'creator';
    const isExpenseCreator = expense.createdByUserId === user.id;
    const isPayer = expense.paidById === authMember.id;

    if (!isTripCreator && !isExpenseCreator && !isPayer) {
      throw AppError.forbidden('You do not have permission to delete this expense');
    }

    const now = new Date().toISOString();
    db.update('expenses', expenseId, { isDeleted: true, updatedAt: now });
    db.update('trips', tripId, { updatedAt: now, revision: (trip.revision || 1) + 1 });
    db.update('trip_members', authMember.id, { lastSyncedRevision: (trip.revision || 1) + 1, lastSeenAt: now });

    const tripService = require('./trip_service');
    tripService.logActivity(tripId, {
      type: 'expense_deleted',
      actorId: user.id,
      actorName: authMember.displayName,
      description: `${authMember.displayName} removed expense "${expense.title}"`,
      metadata: { expenseId },
    });

    const balanceSummary = this.getBalanceSummary(tripId, user.id);

    try {
      const notificationService = require('./notification_service');
      notificationService.notifyExpenseDeleted({
        actor: user,
        trip,
        expense,
        authMember,
        realtimeHub,
      });
    } catch (err) {
      console.warn('[ExpenseService] notifyExpenseDeleted notice:', err.message);
    }

    if (realtimeHub) {
      realtimeHub.broadcastToTrip(tripId, 'expense_deleted', {
        tripId,
        expenseId,
        balanceSummary,
      });
    }

    return { success: true, balanceSummary };
  }

  getBalanceSummary(tripId, currentUserId) {
    const trip = db.get('trips', tripId);
    if (!trip) throw AppError.notFound('Trip not found');

    const members = db.find('trip_members', (m) => m.tripId === tripId);
    const expenses = db.find('expenses', (e) => e.tripId === tripId && !e.isDeleted);

    const totalPaidByMember = {};
    const totalOwedByMember = {};
    const netBalances = {};

    for (const m of members) {
      totalPaidByMember[m.id] = 0;
      totalOwedByMember[m.id] = 0;
      netBalances[m.id] = 0;
    }

    let totalTripSpending = 0;

    for (const expense of expenses) {
      totalTripSpending += expense.amountInPaise;

      // Credit payer(s) (supports single or multi-payer custom contributions)
      if (expense.paidByMap && typeof expense.paidByMap === 'object' && Object.keys(expense.paidByMap).length > 0) {
        for (const [payerId, amt] of Object.entries(expense.paidByMap)) {
          if (totalPaidByMember[payerId] !== undefined) {
            totalPaidByMember[payerId] += Number(amt);
          }
        }
      } else if (totalPaidByMember[expense.paidById] !== undefined) {
        totalPaidByMember[expense.paidById] += expense.amountInPaise;
      }

      // Debit participants
      for (const split of expense.splits) {
        if (totalOwedByMember[split.memberId] !== undefined) {
          totalOwedByMember[split.memberId] += split.amountInPaise;
        }
      }
    }

    // Calculate net balances: Paid - Owed
    for (const m of members) {
      netBalances[m.id] = totalPaidByMember[m.id] - totalOwedByMember[m.id];
    }

    const recordedSettlements = settlementService.getSettlementsForTrip(tripId);
    const adjustedBalances = { ...netBalances };
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
    const simplifiedSettlements = settlementService.simplifyDebts(netBalances, recordedSettlements);

    // Current user context
    const currentMember = members.find((m) => m.userId === currentUserId || m.id === currentUserId);
    let currentUserNetBalanceInPaise = 0;
    let currentUserOwedInPaise = 0;
    let currentUserReceivableInPaise = 0;

    if (currentMember) {
      currentUserNetBalanceInPaise = adjustedBalances[currentMember.id] || 0;
      if (currentUserNetBalanceInPaise < 0) {
        currentUserOwedInPaise = -currentUserNetBalanceInPaise;
      } else {
        currentUserReceivableInPaise = currentUserNetBalanceInPaise;
      }
    }

    return {
      tripId,
      totalTripSpendingInPaise: totalTripSpending,
      totalPaidByMemberInPaise: totalPaidByMember,
      totalOwedByMemberInPaise: totalOwedByMember,
      netBalancesInPaise: netBalances,
      currentUserNetBalanceInPaise,
      currentUserOwedInPaise,
      currentUserReceivableInPaise,
      simplifiedSettlements,
      recordedSettlements,
    };
  }
}

module.exports = new ExpenseService();
