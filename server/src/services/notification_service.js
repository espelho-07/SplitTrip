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
      type,
      title,
      body,
      description: body,
      amountInPaise,
      route: route || (tripId ? `/trip/${tripId}?settlementId=${settlementId || paymentId}` : '/notifications'),
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
   * Retrieves all notifications for a specific user, newest first.
   */
  getNotificationsForUser(userId) {
    if (!userId) return [];
    const notifs = db.find('notifications', (r) => r.recipientUserId === userId && !r.deleted);
    return notifs.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
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
