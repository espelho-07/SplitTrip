'use strict';

const { db } = require('../db/database');
const crypto = require('crypto');
const AppError = require('../middleware/error_handler').AppError;

class NotificationService {
  /**
   * Creates a persistent notification for a specific recipient user.
   */
  createNotification({
    recipientUserId,
    actorUserId = null,
    actorName = 'Member',
    tripId = null,
    tripName = null,
    paymentId = null,
    settlementId = null,
    expenseId = null,
    type = 'PAYMENT_CONFIRMATION_REQUIRED',
    title = 'Notification',
    body = '',
    amountInPaise = 0,
    currencyCode = 'INR',
    route = null,
    metadata = {},
  }) {
    if (!recipientUserId) {
      console.warn('[NotificationService] createNotification skipped: missing recipientUserId');
      return null;
    }

    const now = new Date().toISOString();
    const id = 'notif_' + crypto.randomUUID().replace(/-/g, '').substring(0, 12);

    const record = {
      id,
      recipientUserId,
      actorUserId,
      actorName,
      tripId,
      tripName,
      paymentId: paymentId || settlementId,
      settlementId: settlementId || paymentId,
      expenseId,
      type,
      title,
      body,
      description: body,
      amountInPaise,
      route: route || (tripId ? `/trip/${tripId}${expenseId ? `?expenseId=${expenseId}` : (settlementId ? `?settlementId=${settlementId}` : '')}` : '/notifications'),
      status: 'UNREAD', // 'UNREAD' | 'READ' | 'RESOLVED'
      isRead: false,
      metadata,
      createdAt: now,
      updatedAt: now,
      resolvedAt: null,
    };

    db.insert('notifications', record);
    console.info(`[NotificationService] NOTIFICATION CREATED: id=${id}, recipient=${recipientUserId}, type=${type}`);
    return record;
  }

  /**
   * Dispatches notifications and push alerts for a newly created expense.
   */
  async notifyExpenseCreated({ actor, trip, expense, authMember, realtimeHub = null }) {
    if (!trip || !expense || !actor) return;

    const pushService = require('./push_notification_service');
    const formattedAmt = '₹' + (expense.amountInPaise / 100).toLocaleString('en-IN', { maximumFractionDigits: 2 });
    const actorName = authMember?.displayName || actor.displayName || 'A member';
    const tripName = trip.name || 'Trip';

    // 1. Resolve eligible active members of the trip, excluding the actor
    const members = db.find('trip_members', (m) => m.tripId === trip.id && m.status !== 'merged');
    const recipientUserIds = new Set();

    for (const m of members) {
      if (m.userId && !m.userId.startsWith('unclaimed_') && m.userId !== actor.id) {
        recipientUserIds.add(m.userId);
      }
    }

    console.info(`[NotificationService] EXPENSE CREATED DISPATCH: trip=${trip.id}, expense=${expense.id}, recipients=${recipientUserIds.size}`);

    for (const recipientUserId of recipientUserIds) {
      // Idempotency check: verify notification not already created for this expense and recipient
      const existing = db.findOne('notifications', (n) => 
        n.recipientUserId === recipientUserId && 
        n.expenseId === expense.id && 
        n.type === 'EXPENSE_CREATED' && 
        !n.deleted
      );
      if (existing) continue;

      const title = 'New expense added';
      const body = `${actorName} added ${formattedAmt} to ${tripName}.`;
      const route = `/trip/${trip.id}?expenseId=${expense.id}`;

      // Persist in database notifications table
      this.createNotification({
        recipientUserId,
        actorUserId: actor.id,
        actorName,
        tripId: trip.id,
        tripName,
        expenseId: expense.id,
        type: 'EXPENSE_CREATED',
        title,
        body,
        amountInPaise: expense.amountInPaise,
        route,
        metadata: {
          expenseTitle: expense.title,
          category: expense.category,
        },
      });

      // Dispatch FCM Push Notification for background/terminated devices
      pushService.sendToUser(db, recipientUserId, {
        title,
        body,
        data: {
          type: 'expense_created',
          tripId: trip.id,
          tripName,
          expenseId: expense.id,
          actorUserId: actor.id,
          actorName,
          amountInPaise: String(expense.amountInPaise),
          route,
          channelId: 'kith_activity',
        },
      });
    }
  }

  /**
   * Dispatches notifications and push alerts for an edited expense.
   */
  async notifyExpenseUpdated({ actor, trip, oldExpense, newExpense, authMember, realtimeHub = null }) {
    if (!trip || !newExpense || !actor) return;

    const pushService = require('./push_notification_service');
    const oldAmt = '₹' + (oldExpense.amountInPaise / 100).toLocaleString('en-IN', { maximumFractionDigits: 2 });
    const newAmt = '₹' + (newExpense.amountInPaise / 100).toLocaleString('en-IN', { maximumFractionDigits: 2 });
    const actorName = authMember?.displayName || actor.displayName || 'A member';
    const tripName = trip.name || 'Trip';

    const members = db.find('trip_members', (m) => m.tripId === trip.id && m.status !== 'merged');
    const recipientUserIds = new Set();

    for (const m of members) {
      if (m.userId && !m.userId.startsWith('unclaimed_') && m.userId !== actor.id) {
        recipientUserIds.add(m.userId);
      }
    }

    console.info(`[NotificationService] EXPENSE UPDATED DISPATCH: trip=${trip.id}, expense=${newExpense.id}, recipients=${recipientUserIds.size}`);

    for (const recipientUserId of recipientUserIds) {
      const title = 'Expense updated';
      let body;
      if (oldExpense.amountInPaise !== newExpense.amountInPaise) {
        body = `${actorName} updated ${newExpense.title} from ${oldAmt} to ${newAmt}.`;
      } else {
        body = `${actorName} updated "${newExpense.title}" in ${tripName}.`;
      }
      const route = `/trip/${trip.id}?expenseId=${newExpense.id}`;

      this.createNotification({
        recipientUserId,
        actorUserId: actor.id,
        actorName,
        tripId: trip.id,
        tripName,
        expenseId: newExpense.id,
        type: 'EXPENSE_UPDATED',
        title,
        body,
        amountInPaise: newExpense.amountInPaise,
        route,
        metadata: {
          expenseTitle: newExpense.title,
          oldAmountInPaise: oldExpense.amountInPaise,
          newAmountInPaise: newExpense.amountInPaise,
        },
      });

      pushService.sendToUser(db, recipientUserId, {
        title,
        body,
        data: {
          type: 'expense_updated',
          tripId: trip.id,
          tripName,
          expenseId: newExpense.id,
          actorUserId: actor.id,
          actorName,
          amountInPaise: String(newExpense.amountInPaise),
          route,
          channelId: 'kith_activity',
        },
      });
    }
  }

  /**
   * Dispatches notifications and push alerts for a deleted expense.
   */
  async notifyExpenseDeleted({ actor, trip, expense, authMember, realtimeHub = null }) {
    if (!trip || !expense || !actor) return;

    const pushService = require('./push_notification_service');
    const formattedAmt = '₹' + (expense.amountInPaise / 100).toLocaleString('en-IN', { maximumFractionDigits: 2 });
    const actorName = authMember?.displayName || actor.displayName || 'A member';
    const tripName = trip.name || 'Trip';

    const members = db.find('trip_members', (m) => m.tripId === trip.id && m.status !== 'merged');
    const recipientUserIds = new Set();

    for (const m of members) {
      if (m.userId && !m.userId.startsWith('unclaimed_') && m.userId !== actor.id) {
        recipientUserIds.add(m.userId);
      }
    }

    console.info(`[NotificationService] EXPENSE DELETED DISPATCH: trip=${trip.id}, expense=${expense.id}, recipients=${recipientUserIds.size}`);

    for (const recipientUserId of recipientUserIds) {
      const title = 'Expense removed';
      const body = `${actorName} removed the ${formattedAmt} "${expense.title}" expense.`;
      const route = `/trip/${trip.id}`; // Navigates to trip overview, not broken deleted expense detail

      this.createNotification({
        recipientUserId,
        actorUserId: actor.id,
        actorName,
        tripId: trip.id,
        tripName,
        expenseId: expense.id,
        type: 'EXPENSE_DELETED',
        title,
        body,
        amountInPaise: expense.amountInPaise,
        route,
        metadata: {
          expenseTitle: expense.title,
        },
      });

      pushService.sendToUser(db, recipientUserId, {
        title,
        body,
        data: {
          type: 'expense_deleted',
          tripId: trip.id,
          tripName,
          expenseId: expense.id,
          actorUserId: actor.id,
          actorName,
          amountInPaise: String(expense.amountInPaise),
          route,
          channelId: 'kith_activity',
        },
      });
    }
  }

  /**
   * Dispatches notifications and push alerts when a member joins a trip.
   */
  async notifyMemberJoined({ trip, member, actor, realtimeHub = null }) {
    if (!trip || !member || !actor) return;

    const pushService = require('./push_notification_service');
    const actorName = member.displayName || actor.displayName || 'A new member';
    const tripName = trip.name || 'Trip';

    // 1. Resolve eligible active members of the trip, excluding the newly joined user
    const members = db.find('trip_members', (m) => m.tripId === trip.id && m.status !== 'merged');
    const recipientUserIds = new Set();

    for (const m of members) {
      if (m.userId && !m.userId.startsWith('unclaimed_') && m.userId !== actor.id) {
        recipientUserIds.add(m.userId);
      }
    }

    console.info(`[NotificationService] MEMBER JOINED DISPATCH: trip=${trip.id}, member=${member.id}, recipients=${recipientUserIds.size}`);

    for (const recipientUserId of recipientUserIds) {
      const existing = db.findOne('notifications', (n) =>
        n.recipientUserId === recipientUserId &&
        n.tripId === trip.id &&
        n.actorUserId === actor.id &&
        n.type === 'MEMBER_JOINED' &&
        !n.deleted
      );
      if (existing) continue;

      const title = 'Member joined trip';
      const body = `${actorName} joined "${tripName}".`;
      const route = `/trip/${trip.id}`;

      this.createNotification({
        recipientUserId,
        actorUserId: actor.id,
        actorName,
        tripId: trip.id,
        tripName,
        type: 'MEMBER_JOINED',
        title,
        body,
        route,
        metadata: {
          memberId: member.id,
          tripId: trip.id,
        },
      });

      pushService.sendToUser(db, recipientUserId, {
        title,
        body,
        data: {
          type: 'member_joined',
          tripId: trip.id,
          tripName,
          actorUserId: actor.id,
          actorName,
          route,
          channelId: 'kith_activity',
        },
      });
    }
  }

  /**
   * Dispatches notifications and push alerts when a trip is completed / settled.
   */
  async notifyTripCompleted({ trip, actor, realtimeHub = null }) {
    if (!trip || !actor) return;

    const pushService = require('./push_notification_service');
    const actorName = actor.displayName || 'Creator';
    const tripName = trip.name || 'Trip';

    const members = db.find('trip_members', (m) => m.tripId === trip.id && m.status !== 'merged');
    const recipientUserIds = new Set();

    for (const m of members) {
      if (m.userId && !m.userId.startsWith('unclaimed_') && m.userId !== actor.id) {
        recipientUserIds.add(m.userId);
      }
    }

    console.info(`[NotificationService] TRIP COMPLETED DISPATCH: trip=${trip.id}, recipients=${recipientUserIds.size}`);

    for (const recipientUserId of recipientUserIds) {
      const title = 'Trip completed 🎉';
      const body = `"${tripName}" was marked completed by ${actorName}.`;
      const route = `/trip/${trip.id}`;

      this.createNotification({
        recipientUserId,
        actorUserId: actor.id,
        actorName,
        tripId: trip.id,
        tripName,
        type: 'TRIP_COMPLETED',
        title,
        body,
        route,
        metadata: {
          tripId: trip.id,
        },
      });

      pushService.sendToUser(db, recipientUserId, {
        title,
        body,
        data: {
          type: 'trip_completed',
          tripId: trip.id,
          tripName,
          actorUserId: actor.id,
          actorName,
          route,
          channelId: 'kith_activity',
        },
      });
    }
  }

  /**
   * Retrieves all notifications for a specific user, newest first.
   */
  getNotificationsForUser(userId, { limit = 100, offset = 0 } = {}) {
    if (!userId) return [];
    const notifs = db.find('notifications', (r) => r.recipientUserId === userId && !r.deleted);
    const sorted = notifs.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    const safeLimit = Math.min(200, Math.max(1, parseInt(limit, 10) || 100));
    const safeOffset = Math.max(0, parseInt(offset, 10) || 0);
    return sorted.slice(safeOffset, safeOffset + safeLimit);
  }

  /**
   * Returns the count of unread notifications for a user.
   */
  getUnreadCount(userId) {
    if (!userId) return 0;
    const unread = db.find('notifications', (r) => r.recipientUserId === userId && r.status === 'UNREAD' && !r.deleted);
    return unread.length;
  }

  /**
   * Marks a specific notification as read.
   */
  markAsRead(userId, notificationId) {
    const notif = db.get('notifications', notificationId);
    if (!notif) throw AppError.notFound('Notification not found');
    if (notif.recipientUserId !== userId) throw AppError.forbidden('Access denied');

    const updated = db.update('notifications', notificationId, {
      status: notif.status === 'RESOLVED' ? 'RESOLVED' : 'READ',
      isRead: true,
      updatedAt: new Date().toISOString(),
    });
    return updated;
  }

  /**
   * Marks all notifications as read for a user.
   */
  markAllAsRead(userId) {
    const userNotifs = db.find('notifications', (r) => r.recipientUserId === userId && r.status === 'UNREAD' && !r.deleted);
    const now = new Date().toISOString();
    for (const n of userNotifs) {
      db.update('notifications', n.id, {
        status: 'READ',
        isRead: true,
        updatedAt: now,
      });
    }
    return { success: true, count: userNotifs.length };
  }

  /**
   * Resolves a notification linked to a settlement ID (e.g. when confirmed or disputed).
   */
  resolveNotificationForSettlement(settlementId, resolutionStatus = 'RESOLVED') {
    if (!settlementId) return;
    const notifs = db.find('notifications', (r) => (r.settlementId === settlementId || r.paymentId === settlementId) && !r.deleted);
    const now = new Date().toISOString();
    for (const n of notifs) {
      db.update('notifications', n.id, {
        status: resolutionStatus,
        isRead: true,
        resolvedAt: now,
        updatedAt: now,
      });
    }
  }

  /**
   * Retrieves all pending settlement verifications across all trips for the authenticated user.
   */
  getPendingSettlementsForUser(userId) {
    if (!userId) return { pending: [], disputed: [] };

    // Find all trips where this user is a member
    const memberRecords = db.find('trip_members', (m) => m.userId === userId && m.status !== 'merged');
    const memberIds = new Set(memberRecords.map((m) => m.id));

    // Find settlements where this user is receiver and status is awaiting confirmation (marked_paid)
    const pendingSettlements = db.find('settlements', (s) => {
      return (
        memberIds.has(s.toMemberId) &&
        (s.status === 'marked_paid' || s.status === 'pending_verification' || (!s.isSettled && s.status !== 'confirmed' && s.status !== 'disputed'))
      );
    });

    // Also find disputed settlements where this user is the payer
    const disputedSettlements = db.find('settlements', (s) => {
      return memberIds.has(s.fromMemberId) && s.status === 'disputed';
    });

    // Enrich with trip name and member details
    const enrich = (s) => {
      const trip = db.get('trips', s.tripId) || {};
      const fromMember = db.get('trip_members', s.fromMemberId) || {};
      const toMember = db.get('trip_members', s.toMemberId) || {};

      return {
        id: 'pvr_' + s.id,
        settlementId: s.id,
        tripId: s.tripId,
        tripName: trip.name || 'Trip',
        payerMemberId: s.fromMemberId,
        payerUserId: fromMember.userId || null,
        payerName: fromMember.displayName || 'Friend',
        receiverMemberId: s.toMemberId,
        receiverUserId: toMember.userId || userId,
        receiverName: toMember.displayName || 'You',
        amountInPaise: s.amountInPaise,
        paymentMethod: s.paymentMethod || 'Direct',
        status: s.status === 'disputed' ? 'disputed' : 'pending_verification',
        paymentReference: s.paymentReference || s.transactionRef || null,
        markedAt: s.markedPaidAt || s.createdAt,
        disputeReason: s.disputeReason || null,
        proofImageUrl: s.proofImageUrl || null,
        proofNote: s.proofNote || null,
      };
    };

    return {
      pending: pendingSettlements.map(enrich),
      disputed: disputedSettlements.map(enrich),
    };
  }
}

module.exports = new NotificationService();
