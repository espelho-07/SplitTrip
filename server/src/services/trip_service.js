const crypto = require('crypto');
const { db } = require('../db/database');
const { AppError } = require('../middleware/error_handler');

class TripService {
  _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let code = '';
    for (let i = 0; i < 6; i++) {
      code += chars.charAt(crypto.randomInt(0, chars.length));
    }
    return code;
  }

  _getMembersForTrip(tripId) {
    return db.find('trip_members', (m) => m.tripId === tripId);
  }

  _enrichTrip(trip) {
    if (!trip) return null;
    const members = this._getMembersForTrip(trip.id);
    return {
      ...trip,
      revision: trip.revision || 1,
      completionMode: trip.completionMode || null,
      completedAt: trip.completedAt || null,
      completedBy: trip.completedBy || null,
      members: members.map((m) => {
        const u = db.get('users', m.userId) || {};
        return {
          id: m.id,
          userId: m.userId,
          displayName: m.displayName,
          avatarUrl: m.avatarUrl || null,
          role: m.role || 'member',
          joinedAt: m.joinedAt,
          lastSeenAt: m.lastSeenAt || m.joinedAt || null,
          lastSyncedRevision: m.lastSyncedRevision || trip.revision || 1,
          pendingMutationsCount: m.pendingMutationsCount || 0,
          upiId: m.upiId || u.upiId || null,
        };
      }),
    };
  }

  createTrip(user, { id, inviteCode: customInviteCode, name, description, emoji, coverGradientIndex, currencyCode, initialFriendNames = [], tripMode = 'split_only' } = {}, realtimeHub = null) {
    if (!name || !name.trim()) {
      throw AppError.badRequest('Trip name is required');
    }

    // Check if trip with client-provided ID already exists (idempotent create)
    if (id) {
      const existingTrip = db.get('trips', id);
      if (existingTrip) {
        return this._enrichTrip(existingTrip);
      }
    }

    const tripId = id && id.trim() ? id.trim() : `trip_${crypto.randomUUID().replace(/-/g, '').substring(0, 12)}`;
    let inviteCode = customInviteCode ? customInviteCode.trim().toUpperCase() : this._generateInviteCode();

    // Ensure code uniqueness (if collision with a different trip, generate unique code)
    while (db.findOne('trips', (t) => t.inviteCode === inviteCode && t.id !== tripId)) {
      inviteCode = this._generateInviteCode();
    }

    const now = new Date().toISOString();
    const trip = {
      id: tripId,
      name: name.trim(),
      description: description ? description.trim() : null,
      emoji: emoji || '✈️',
      coverGradientIndex: typeof coverGradientIndex === 'number' ? coverGradientIndex : 0,
      currencyCode: (currencyCode || 'INR').toUpperCase(),
      creatorId: user.id,
      inviteCode,
      tripMode: tripMode === 'split_and_journey' ? 'split_and_journey' : 'split_only',
      lifecycleState: 'active',
      revision: 1,
      completionMode: null,
      completedAt: null,
      completedBy: null,
      createdAt: now,
      updatedAt: now,
    };

    db.insert('trips', trip);

    // Creator membership
    const creatorMember = {
      id: `mbr_${crypto.randomUUID().replace(/-/g, '').substring(0, 10)}`,
      tripId,
      userId: user.id,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl || null,
      role: 'creator',
      joinedAt: now,
      lastSeenAt: now,
      lastSyncedRevision: 1,
      pendingMutationsCount: 0,
      upiId: user.upiId || null,
    };
    db.insert('trip_members', creatorMember);

    // Initial friends
    if (Array.isArray(initialFriendNames)) {
      for (const friendName of initialFriendNames) {
        if (friendName && friendName.trim()) {
          const placeholderMember = {
            id: `mbr_${crypto.randomUUID().replace(/-/g, '').substring(0, 10)}`,
            tripId,
            userId: `guest_${crypto.randomUUID().replace(/-/g, '').substring(0, 8)}`,
            displayName: friendName.trim(),
            avatarUrl: null,
            role: 'member',
            joinedAt: now,
            lastSeenAt: now,
            lastSyncedRevision: 1,
            pendingMutationsCount: 0,
          };
          db.insert('trip_members', placeholderMember);
        }
      }
    }

    this.logActivity(tripId, {
      type: 'trip_created',
      actorId: user.id,
      actorName: user.displayName,
      description: `${user.displayName} created the trip "${name.trim()}"`,
      metadata: { tripId, emoji: trip.emoji },
    });

    const enriched = this._enrichTrip(trip);

    if (realtimeHub) {
      realtimeHub.broadcastToUser(user.id, 'trip_created', { trip: enriched });
    }

    return enriched;
  }

  logActivity(tripId, { type, actorId, actorName, description, metadata = {} }) {
    const id = `act_${crypto.randomUUID().replace(/-/g, '').substring(0, 12)}`;
    const activity = {
      id,
      tripId,
      type, // 'trip_created', 'member_joined', 'expense_added', 'expense_updated', 'expense_deleted', 'settlement_recorded', 'lifecycle_updated'
      actorId,
      actorName: actorName || 'Member',
      description,
      metadata,
      createdAt: new Date().toISOString(),
    };
    db.insert('activity_logs', activity);
    return activity;
  }

  getActivityLogs(tripId, userId) {
    const trip = db.get('trips', tripId);
    if (!trip) throw AppError.notFound('Trip not found');

    const authMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === userId);
    if (!authMember) throw AppError.forbidden('Not authorized to view activity logs for this trip');

    const logs = db.find('activity_logs', (a) => a.tripId === tripId);
    return logs.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
  }

  getTripById(tripId, userId) {
    const trip = db.get('trips', tripId);
    if (!trip) {
      throw AppError.notFound('Trip not found');
    }

    const membership = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === userId);
    if (!membership) {
      throw AppError.forbidden('You are not a member of this trip');
    }

    return this._enrichTrip(trip);
  }

  getUserTrips(userId) {
    const memberships = db.find('trip_members', (m) => m.userId === userId);
    const tripIds = new Set(memberships.map((m) => m.tripId));

    const trips = [];
    for (const tripId of tripIds) {
      const trip = db.get('trips', tripId);
      if (trip) {
        trips.push(this._enrichTrip(trip));
      }
    }

    // Sort newest first
    return trips.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
  }

  getTripPreviewByCode(inviteCode) {
    if (!inviteCode || !inviteCode.toString().trim()) {
      throw AppError.badRequest('Join code is required');
    }

    const cleanCode = inviteCode.toString().trim().toUpperCase().replace(/[\s\-]/g, '');
    const trip = db.findOne('trips', (t) =>
      (t.inviteCode && t.inviteCode.toUpperCase() === cleanCode) ||
      (t.id && t.id.toUpperCase() === cleanCode)
    );

    if (!trip) {
      throw AppError.notFound('No trip found for this invite code');
    }

    const creator = db.get('users', trip.creatorId);
    const members = this._getMembersForTrip(trip.id);

    return {
      id: trip.id,
      tripId: trip.id,
      name: trip.name,
      emoji: trip.emoji,
      coverGradientIndex: trip.coverGradientIndex,
      currencyCode: trip.currencyCode,
      creatorName: creator?.displayName || 'A Kith user',
      memberCount: members.length,
      lifecycleState: trip.lifecycleState,
      inviteCode: trip.inviteCode,
    };
  }

  joinTripByCode(user, inviteCode, realtimeHub = null) {
    if (!inviteCode || !inviteCode.toString().trim()) {
      throw AppError.badRequest('Join code is required');
    }

    const cleanCode = inviteCode.toString().trim().toUpperCase().replace(/[\s\-]/g, '');
    const trip = db.findOne('trips', (t) =>
      (t.inviteCode && t.inviteCode.toUpperCase() === cleanCode) ||
      (t.id && t.id.toUpperCase() === cleanCode)
    );

    if (!trip) {
      throw AppError.notFound('No trip found with this code. Please check and try again.');
    }

    // Check if trip is settled/locked
    if (trip.lifecycleState === 'settled') {
      throw AppError.badRequest('This trip is already settled and closed.');
    }

    // Check if already a member
    const existingMember = db.findOne('trip_members', (m) => m.tripId === trip.id && m.userId === user.id);
    if (existingMember) {
      return this._enrichTrip(trip);
    }

    const now = new Date().toISOString();

    // Check if there is an unlinked placeholder member created via initialFriendNames
    const placeholderMember = db.findOne(
      'trip_members',
      (m) => m.tripId === trip.id &&
             m.userId.startsWith('guest_') &&
             m.displayName.trim().toLowerCase() === user.displayName.trim().toLowerCase()
    );

    let activeMember;
    if (placeholderMember) {
      // Upgrade existing placeholder member with authenticated user
      db.update('trip_members', placeholderMember.id, {
        userId: user.id,
        avatarUrl: user.avatarUrl || placeholderMember.avatarUrl,
        joinedAt: now,
      });
      activeMember = db.get('trip_members', placeholderMember.id);
    } else {
      // Create new member record
      activeMember = {
        id: `mbr_${crypto.randomUUID().replace(/-/g, '').substring(0, 10)}`,
        tripId: trip.id,
        userId: user.id,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl || null,
        role: 'member',
        joinedAt: now,
        upiId: user.upiId || null,
      };
      db.insert('trip_members', activeMember);
    }

    db.update('trips', trip.id, { updatedAt: now });

    this.logActivity(trip.id, {
      type: 'member_joined',
      actorId: user.id,
      actorName: user.displayName,
      description: `${user.displayName} joined the trip`,
      metadata: { memberId: activeMember.id },
    });

    const enriched = this._enrichTrip(trip);

    if (realtimeHub) {
      realtimeHub.broadcastToTrip(trip.id, 'member_joined', {
        tripId: trip.id,
        member: activeMember,
        trip: enriched,
      });
      realtimeHub.broadcastToUser(user.id, 'trip_joined', {
        trip: enriched,
      });
    }

    return enriched;
  }

  addMember(tripId, currentUserId, { displayName }, realtimeHub = null) {
    if (!displayName || !displayName.trim()) {
      throw AppError.badRequest('Member display name is required');
    }

    const trip = db.get('trips', tripId);
    if (!trip) throw AppError.notFound('Trip not found');

    const authMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === currentUserId);
    if (!authMember) throw AppError.forbidden('You are not authorized to add members to this trip');

    if (trip.lifecycleState === 'settled') {
      throw AppError.badRequest('Cannot add members to a settled trip');
    }

    const now = new Date().toISOString();
    const newMember = {
      id: `mbr_${crypto.randomUUID().replace(/-/g, '').substring(0, 10)}`,
      tripId,
      userId: `guest_${crypto.randomUUID().replace(/-/g, '').substring(0, 8)}`,
      displayName: displayName.trim(),
      avatarUrl: null,
      role: 'member',
      joinedAt: now,
    };

    db.insert('trip_members', newMember);
    db.update('trips', tripId, { updatedAt: now });

    this.logActivity(tripId, {
      type: 'member_joined',
      actorId: currentUserId,
      actorName: authMember.displayName,
      description: `${authMember.displayName} added ${displayName.trim()} to the trip`,
      metadata: { memberId: newMember.id },
    });

    const enriched = this._enrichTrip(trip);

    if (realtimeHub) {
      realtimeHub.broadcastToTrip(tripId, 'member_joined', {
        tripId,
        member: newMember,
        trip: enriched,
      });
    }

    return enriched;
  }

  updateLifecycle(tripId, currentUserId, newLifecycle, realtimeHub = null) {
    const validStates = ['draft', 'active', 'completing', 'completed', 'settling', 'settled'];
    if (!validStates.includes(newLifecycle)) {
      throw AppError.badRequest(`Invalid lifecycle state: ${newLifecycle}`);
    }

    const trip = db.get('trips', tripId);
    if (!trip) throw AppError.notFound('Trip not found');

    const authMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === currentUserId);
    if (!authMember) throw AppError.forbidden('Not a member of this trip');

    // Only creator can update lifecycle
    if (trip.creatorId !== currentUserId && authMember.role !== 'creator') {
      throw AppError.forbidden('Only the trip creator can complete or change trip lifecycle state');
    }

    const now = new Date().toISOString();
    const newRevision = (trip.revision || 1) + 1;
    const updated = db.update('trips', tripId, {
      lifecycleState: newLifecycle,
      revision: newRevision,
      updatedAt: now,
    });

    this.logActivity(tripId, {
      type: 'lifecycle_updated',
      actorId: currentUserId,
      actorName: authMember.displayName,
      description: `${authMember.displayName} changed trip state to ${newLifecycle.toUpperCase()}`,
      metadata: { lifecycleState: newLifecycle },
    });

    const enriched = this._enrichTrip(updated);

    if (realtimeHub) {
      realtimeHub.broadcastToTrip(tripId, 'lifecycle_updated', {
        tripId,
        lifecycleState: newLifecycle,
        trip: enriched,
      });
    }

    return enriched;
  }

  _formatLastSync(date) {
    if (!date) return 'Unknown';
    const diffMs = Date.now() - new Date(date).getTime();
    if (diffMs < 0) return 'Just now';
    const diffSec = Math.floor(diffMs / 1000);
    if (diffSec < 45) return 'Just now';
    const diffMin = Math.floor(diffSec / 60);
    if (diffMin < 60) return `${diffMin}m ago`;
    const diffHr = Math.floor(diffMin / 60);
    if (diffHr < 24) return `${diffHr}h ago`;
    const diffDay = Math.floor(diffHr / 24);
    return `${diffDay}d ago`;
  }

  getTripSyncStatus(tripId, currentUserId, realtimeHub = null) {
    const trip = db.get('trips', tripId);
    if (!trip) throw AppError.notFound('Trip not found');

    const authMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === currentUserId);
    if (!authMember) throw AppError.forbidden('Not a member of this trip');

    // Update current user's lastSeenAt
    const now = new Date().toISOString();
    db.update('trip_members', authMember.id, { lastSeenAt: now });

    const members = this._getMembersForTrip(tripId);
    const tripRevision = trip.revision || 1;
    const nowDate = new Date();

    const participants = members.map((m) => {
      const isCurrentUser = m.userId === currentUserId;
      const isOnline = isCurrentUser ? true : (realtimeHub ? realtimeHub.isTripMemberConnected(tripId, m.userId) : false);
      const memberRevision = m.lastSyncedRevision || 1;
      const pendingCount = m.pendingMutationsCount || 0;
      const lastSeenDate = m.lastSeenAt ? new Date(m.lastSeenAt) : null;

      let syncStatus = 'synced';
      if (pendingCount > 0) {
        syncStatus = isOnline ? 'pending' : 'offline';
      } else if (memberRevision < tripRevision) {
        syncStatus = isOnline ? 'pending' : 'offline';
      } else if (!isOnline && !isCurrentUser && lastSeenDate && (nowDate - lastSeenDate > 1000 * 60 * 60 * 2)) {
        // If not online and not seen in 2 hours with no pending changes, still consider synced if revision matches
        syncStatus = memberRevision >= tripRevision ? 'synced' : 'offline';
      } else if (!isOnline && !isCurrentUser && !lastSeenDate) {
        syncStatus = 'unknown';
      }

      return {
        memberId: m.id,
        userId: m.userId,
        displayName: m.displayName,
        avatarUrl: m.avatarUrl || null,
        isCreator: m.role === 'creator',
        isCurrentUser,
        isOnline,
        syncStatus,
        acknowledgedRevision: memberRevision,
        pendingCount,
        lastSeenAt: m.lastSeenAt || null,
        lastSyncFormatted: this._formatLastSync(m.lastSeenAt),
      };
    });

    const isFullySynced = participants.every((p) => p.syncStatus === 'synced' && p.pendingCount === 0);
    const unsyncedCount = participants.filter((p) => p.syncStatus !== 'synced' || p.pendingCount > 0).length;

    return {
      tripId: trip.id,
      tripName: trip.name,
      currentRevision: tripRevision,
      lifecycleState: trip.lifecycleState,
      completionMode: trip.completionMode || null,
      completedAt: trip.completedAt || null,
      completedBy: trip.completedBy || null,
      isFullySynced,
      canCompleteNormally: isFullySynced && (trip.lifecycleState === 'active' || trip.lifecycleState === 'completing'),
      totalParticipants: participants.length,
      syncedParticipantsCount: participants.length - unsyncedCount,
      unsyncedParticipantsCount: unsyncedCount,
      participants,
    };
  }

  acknowledgeSync(tripId, currentUserId, { revision = null, pendingCount = 0 } = {}) {
    const trip = db.get('trips', tripId);
    if (!trip) throw AppError.notFound('Trip not found');

    const authMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === currentUserId);
    if (!authMember) throw AppError.forbidden('Not a member of this trip');

    const now = new Date().toISOString();
    const ackRevision = typeof revision === 'number' ? revision : (trip.revision || 1);

    db.update('trip_members', authMember.id, {
      lastSyncedRevision: ackRevision,
      pendingMutationsCount: typeof pendingCount === 'number' ? pendingCount : 0,
      lastSeenAt: now,
    });

    return {
      tripId,
      userId: currentUserId,
      acknowledgedRevision: ackRevision,
      pendingCount: pendingCount || 0,
      timestamp: now,
    };
  }

  requestTripSync(tripId, currentUserId, realtimeHub = null) {
    const trip = db.get('trips', tripId);
    if (!trip) throw AppError.notFound('Trip not found');

    const authMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === currentUserId);
    if (!authMember) throw AppError.forbidden('Not a member of this trip');

    const now = new Date().toISOString();
    if (realtimeHub) {
      realtimeHub.broadcastToTrip(tripId, 'trip_sync_requested', {
        tripId,
        requestedByUserId: currentUserId,
        requestedByName: authMember.displayName,
        timestamp: now,
      });
    }

    return {
      tripId,
      requested: true,
      timestamp: now,
    };
  }

  completeTrip(tripId, currentUserId, { completionMode = 'NORMAL', expectedRevision = null } = {}, realtimeHub = null) {
    const trip = db.get('trips', tripId);
    if (!trip) throw AppError.notFound('Trip not found');

    const authMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === currentUserId);
    if (!authMember) throw AppError.forbidden('Not a member of this trip');

    if (trip.creatorId !== currentUserId && authMember.role !== 'creator') {
      throw AppError.forbidden('Only the trip creator can complete or change trip lifecycle state');
    }

    // Idempotency: if already completed, return existing trip
    if (trip.lifecycleState === 'completed' || trip.lifecycleState === 'completed_with_pending_changes') {
      return this._enrichTrip(trip);
    }

    const currentRevision = trip.revision || 1;
    // Concurrency conflict check
    if (typeof expectedRevision === 'number' && currentRevision > expectedRevision) {
      throw AppError.conflict(
        `Trip was modified by another member (revision ${currentRevision} > expected ${expectedRevision}) while finalizing. Please review the latest changes.`,
        { currentRevision, expectedRevision }
      );
    }

    const normalizedMode = (completionMode || 'NORMAL').toUpperCase();
    const isForced = normalizedMode === 'FORCED_WITH_PENDING_SYNC' || normalizedMode === 'FORCED';

    if (!isForced) {
      const syncStatus = this.getTripSyncStatus(tripId, currentUserId, realtimeHub);
      if (!syncStatus.isFullySynced) {
        throw AppError.badRequest(
          'Cannot complete trip normally: one or more participants have un-synced changes. Use forced completion if intended.',
          { unsyncedCount: syncStatus.unsyncedParticipantsCount, participants: syncStatus.participants }
        );
      }
    }

    const now = new Date().toISOString();
    const targetState = isForced ? 'completed_with_pending_changes' : 'completed';
    const targetMode = isForced ? 'forced_with_pending_sync' : 'normal';

    const updated = db.update('trips', tripId, {
      lifecycleState: targetState,
      completionMode: targetMode,
      completedAt: now,
      completedBy: currentUserId,
      revision: currentRevision + 1,
      updatedAt: now,
    });

    this.logActivity(tripId, {
      type: 'lifecycle_updated',
      actorId: currentUserId,
      actorName: authMember.displayName,
      description: isForced
        ? `${authMember.displayName} marked trip as completed with pending sync warnings`
        : `${authMember.displayName} completed the trip`,
      metadata: {
        lifecycleState: targetState,
        completionMode: targetMode,
        completedAt: now,
      },
    });

    const enriched = this._enrichTrip(updated);

    if (realtimeHub) {
      realtimeHub.broadcastToTrip(tripId, 'lifecycle_updated', {
        tripId,
        lifecycleState: targetState,
        completionMode: targetMode,
        trip: enriched,
      });
      realtimeHub.broadcastToTrip(tripId, 'trip_completed', {
        tripId,
        lifecycleState: targetState,
        completionMode: targetMode,
        completedAt: now,
        completedBy: currentUserId,
        trip: enriched,
      });
    }

    return enriched;
  }
}

module.exports = new TripService();
