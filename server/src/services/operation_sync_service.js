'use strict';

const crypto = require('crypto');
const { db } = require('../db/database');
const { AppError } = require('../middleware/error_handler');
const expenseService = require('./expense_service');
const settlementService = require('./settlement_service');
const tripService = require('./trip_service');

class OperationSyncService {
  /**
   * Applies a single client mutation operation idempotently.
   * If operation was already processed, returns the previous result without duplicate mutations.
   */
  applyOperation(user, tripId, operation, realtimeHub = null) {
    if (!operation || typeof operation !== 'object') {
      throw AppError.badRequest('Invalid operation payload');
    }

    const opId = operation.id || operation.operationId || operation.idempotencyKey;
    if (!opId || !opId.toString().trim()) {
      throw AppError.badRequest('Operation must have a stable unique operation_id');
    }
    const cleanOpId = opId.toString().trim();

    const trip = db.get('trips', tripId);
    if (!trip) throw AppError.notFound('Trip not found');

    const authMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === user.id);
    if (!authMember) throw AppError.forbidden('You are not a member of this trip');

    // 1. Strict Deduplication / Idempotency Check
    const existingOp = db.get('processed_operations', cleanOpId);
    if (existingOp && existingOp.tripId === tripId) {
      return {
        status: 'ALREADY_PROCESSED',
        operationId: cleanOpId,
        type: existingOp.type,
        processedAt: existingOp.processedAt,
        serverRevision: trip.revision || 1,
        entityId: existingOp.entityId,
      };
    }

    const opType = (operation.type || '').toString().trim();
    const payload = operation.payload || {};
    const now = new Date().toISOString();
    let entityId = payload.id || null;
    let result = null;

    // 2. Dispatch and Execute Mutation based on Operation Type
    switch (opType) {
      case 'addExpense':
      case 'createExpense':
      case 'EXPENSE_CREATED': {
        const expenseId = payload.id || null;
        const res = expenseService.createExpense(user, tripId, {
          id: expenseId,
          title: payload.title,
          amountInPaise: payload.amountInPaise,
          category: payload.category || 'general',
          paidById: payload.paidById,
          paidByMap: payload.paidByMap || null,
          splitType: payload.splitType || 'equal',
          splits: payload.splits || [],
          voiceTranscript: payload.voiceTranscript || null,
          receiptUrl: payload.receiptUrl || null,
        }, realtimeHub);
        entityId = res.expense.id;
        result = { expenseId: res.expense.id };
        break;
      }

      case 'updateExpense':
      case 'EXPENSE_UPDATED': {
        const expenseId = payload.id || payload.expenseId;
        if (!expenseId) throw AppError.badRequest('Expense ID required for updateExpense');
        const res = expenseService.updateExpense(user, tripId, expenseId, {
          title: payload.title,
          amountInPaise: payload.amountInPaise,
          category: payload.category,
          paidById: payload.paidById,
          paidByMap: payload.paidByMap || null,
          splitType: payload.splitType,
          splits: payload.splits,
          voiceTranscript: payload.voiceTranscript,
          receiptUrl: payload.receiptUrl,
          updatedAt: payload.updatedAt,
        }, realtimeHub);
        entityId = expenseId;
        result = { expenseId };
        break;
      }

      case 'deleteExpense':
      case 'EXPENSE_DELETED': {
        const expenseId = payload.id || payload.expenseId;
        if (!expenseId) throw AppError.badRequest('Expense ID required for deleteExpense');
        expenseService.deleteExpense(tripId, expenseId, user, realtimeHub);
        entityId = expenseId;
        result = { expenseId, deleted: true };
        break;
      }

      case 'recordTripSettlement':
      case 'recordSettlement':
      case 'SETTLEMENT_RECORDED': {
        const stlId = payload.id || payload.settlementId || null;
        const res = settlementService.recordSettlement(user, tripId, {
          id: stlId,
          fromMemberId: payload.fromMemberId,
          toMemberId: payload.toMemberId,
          amountInPaise: payload.amountInPaise,
          paymentReference: payload.paymentReference || payload.transactionRef,
          recipientUpiId: payload.recipientUpiId,
          status: payload.status || 'marked_paid',
          note: payload.note,
        }, realtimeHub);
        entityId = res.settlement.id;
        result = { settlementId: res.settlement.id };
        break;
      }

      case 'confirmTripSettlement':
      case 'confirmSettlement':
      case 'SETTLEMENT_CONFIRMED': {
        const stlId = payload.id || payload.settlementId;
        if (!stlId) throw AppError.badRequest('Settlement ID required for confirmation');
        const res = settlementService.confirmSettlement(user, tripId, stlId, realtimeHub);
        entityId = stlId;
        result = { settlementId: stlId, status: 'confirmed' };
        break;
      }

      case 'disputeTripSettlement':
      case 'disputeSettlement':
      case 'SETTLEMENT_DISPUTED': {
        const stlId = payload.id || payload.settlementId;
        if (!stlId) throw AppError.badRequest('Settlement ID required for dispute');
        const res = settlementService.disputeSettlement(user, tripId, stlId, { reason: payload.reason }, realtimeHub);
        entityId = stlId;
        result = { settlementId: stlId, status: 'disputed' };
        break;
      }

      case 'submitSettlementProof':
      case 'submitPaymentProof':
      case 'PAYMENT_PROOF_SUBMITTED': {
        const stlId = payload.id || payload.settlementId;
        if (!stlId) throw AppError.badRequest('Settlement ID required for proof submission');
        const res = settlementService.submitPaymentProof(user, tripId, stlId, {
          transactionRef: payload.transactionRef || payload.paymentReference,
          proofImageUrl: payload.proofImageUrl,
          proofNote: payload.proofNote,
        }, realtimeHub);
        entityId = stlId;
        result = { settlementId: stlId, status: 'proof_submitted' };
        break;
      }

      case 'updateTripLifecycle':
      case 'LIFECYCLE_UPDATED': {
        const newLifecycle = payload.lifecycleState || payload.lifecycle;
        const res = tripService.updateLifecycle(tripId, user.id, newLifecycle, realtimeHub);
        entityId = tripId;
        result = { lifecycleState: newLifecycle };
        break;
      }

      case 'completeTrip':
      case 'TRIP_COMPLETED': {
        const res = tripService.completeTrip(tripId, user.id, {
          completionMode: payload.completionMode || 'NORMAL',
          expectedRevision: payload.expectedRevision,
        }, realtimeHub);
        entityId = tripId;
        result = { completed: true, completionMode: payload.completionMode || 'NORMAL' };
        break;
      }

      case 'mergeMembers':
      case 'MEMBERS_MERGED': {
        const res = tripService.mergeMembers(tripId, user.id, {
          sourceMemberId: payload.sourceMemberId,
          canonicalMemberId: payload.canonicalMemberId,
          operationId: cleanOpId,
        }, realtimeHub);
        entityId = payload.canonicalMemberId;
        result = { sourceMemberId: payload.sourceMemberId, canonicalMemberId: payload.canonicalMemberId };
        break;
      }

      case 'addMember':
      case 'MEMBER_ADDED': {
        const res = tripService.addMember(tripId, user.id, {
          id: payload.id,
          userId: payload.userId,
          displayName: payload.displayName,
          claimToken: payload.claimToken,
          isVirtual: payload.isVirtual !== false,
        }, realtimeHub);
        entityId = tripId;
        result = { memberAdded: true };
        break;
      }

      case 'renameMember':
      case 'MEMBER_RENAMED': {
        const res = tripService.renameMember(
          tripId,
          user.id,
          payload.memberId,
          payload.newDisplayName || payload.displayName,
          realtimeHub,
        );
        entityId = payload.memberId;
        result = { memberRenamed: true };
        break;
      }

      default:
        throw AppError.badRequest(`Unsupported sync operation type: ${opType}`);
    }

    // 3. Record in Authoritative Processed Operations Table
    const updatedTrip = db.get('trips', tripId) || trip;
    const processedOpRecord = {
      id: cleanOpId,
      tripId,
      actorUserId: user.id,
      entityId: entityId || null,
      type: opType,
      processedAt: now,
      serverRevision: updatedTrip.revision || 1,
    };
    db.insert('processed_operations', processedOpRecord);

    return {
      status: 'APPLIED',
      operationId: cleanOpId,
      type: opType,
      processedAt: now,
      serverRevision: updatedTrip.revision || 1,
      entityId,
      result,
    };
  }

  /**
   * Batch processes an array of client operations in dependency order.
   * Returns an array of execution results corresponding to each operation.
   */
  batchSyncOperations(user, tripId, operations = [], realtimeHub = null) {
    if (!Array.isArray(operations)) {
      throw AppError.badRequest('Operations must be an array');
    }

    const trip = db.get('trips', tripId);
    if (!trip) throw AppError.notFound('Trip not found');

    const authMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === user.id);
    if (!authMember) throw AppError.forbidden('You are not a member of this trip');

    const results = [];
    for (const op of operations) {
      try {
        const res = this.applyOperation(user, tripId, op, realtimeHub);
        results.push(res);
      } catch (err) {
        const opId = op.id || op.operationId || 'unknown';
        results.push({
          status: 'FAILED',
          operationId: opId,
          errorCode: err.code || 'OPERATION_ERROR',
          errorMessage: err.message || 'Operation failed',
        });
      }
    }

    const finalTrip = tripService.getTripById(tripId, user.id);
    const balanceSummary = expenseService.getBalanceSummary(tripId, user.id);

    return {
      tripId,
      processedCount: results.length,
      serverRevision: finalTrip.revision || 1,
      results,
      trip: finalTrip,
      balanceSummary,
    };
  }

  /**
   * Returns list of operations processed for a trip since a specific revision or watermark.
   */
  getOperationsSince(tripId, userId, { sinceRevision = 0, knownOperationIds = [] } = {}) {
    const trip = db.get('trips', tripId);
    if (!trip) throw AppError.notFound('Trip not found');

    const authMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === userId);
    if (!authMember) throw AppError.forbidden('You are not a member of this trip');

    const knownSet = new Set(Array.isArray(knownOperationIds) ? knownOperationIds : []);
    const ops = db.find('processed_operations', (op) =>
      op.tripId === tripId &&
      (op.serverRevision || 0) >= sinceRevision &&
      !knownSet.has(op.id)
    );

    return {
      tripId,
      currentRevision: trip.revision || 1,
      operations: ops.sort((a, b) => (a.serverRevision || 0) - (b.serverRevision || 0)),
    };
  }
}

module.exports = new OperationSyncService();
