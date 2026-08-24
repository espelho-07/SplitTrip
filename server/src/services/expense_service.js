const crypto = require('crypto');
const { db } = require('../db/database');
const { AppError } = require('../middleware/error_handler');
const settlementService = require('./settlement_service');

class ExpenseService {
  createExpense(user, tripId, {
    id = null,
    title,
    amountInPaise,
    category = 'general',
    paidById,
    splitType = 'equal',
    splits = [],
    voiceTranscript = null,
    receiptUrl = null,
  }, realtimeHub = null) {
    // Idempotency: return existing expense if already created with this ID
    if (id) {
      const existing = db.get('expenses', id);
      if (existing && existing.tripId === tripId && !existing.isDeleted) {
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

    // Lifecycle check
    if (trip.lifecycleState === 'completed' || trip.lifecycleState === 'settled') {
      throw AppError.badRequest(`Cannot add expense to a ${trip.lifecycleState} trip`);
    }

    // Verify payer member exists in trip
    const payerMember = db.findOne('trip_members', (m) => m.tripId === tripId && (m.id === paidById || m.userId === paidById));
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

    const now = new Date().toISOString();
    const expense = {
      id: id || `exp_${crypto.randomUUID().replace(/-/g, '').substring(0, 12)}`,
      tripId,
      title: title.trim(),
      amountInPaise,
      category,
      paidById: payerMember.id,
      splitType,
      splits: validatedSplits,
      voiceTranscript: voiceTranscript || null,
      receiptUrl: receiptUrl || null,
      isDeleted: false,
      createdByUserId: user.id,
      createdAt: now,
      updatedAt: now,
    };

    db.insert('expenses', expense);
    db.update('trips', tripId, { updatedAt: now });

    const balanceSummary = this.getBalanceSummary(tripId, user.id);

    if (realtimeHub) {
      realtimeHub.broadcastToTrip(tripId, 'expense_added', {
        tripId,
        expense,
        balanceSummary,
      });
    }

    return { expense, balanceSummary };
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
      throw AppError.badRequest(`Cannot delete expense in a ${trip.lifecycleState} trip`);
    }

    const expense = db.get('expenses', expenseId);
    if (!expense || expense.tripId !== tripId || expense.isDeleted) {
      throw AppError.notFound('Expense not found');
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
    db.update('trips', tripId, { updatedAt: now });

    const balanceSummary = this.getBalanceSummary(tripId, user.id);

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

      // Credit payer
      if (totalPaidByMember[expense.paidById] !== undefined) {
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
    const simplifiedSettlements = settlementService.simplifyDebts(netBalances, recordedSettlements);

    // Current user context
    const currentMember = members.find((m) => m.userId === currentUserId || m.id === currentUserId);
    let currentUserNetBalanceInPaise = 0;
    let currentUserOwedInPaise = 0;
    let currentUserReceivableInPaise = 0;

    if (currentMember) {
      currentUserNetBalanceInPaise = netBalances[currentMember.id] || 0;
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
