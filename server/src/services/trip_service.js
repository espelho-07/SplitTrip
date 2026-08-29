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
      members: members.map((m) => {
        const u = db.get('users', m.userId) || {};
        return {
          id: m.id,
          userId: m.userId,
          displayName: m.displayName,
          avatarUrl: m.avatarUrl || null,
          role: m.role || 'member',
          joinedAt: m.joinedAt,
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
    const updated = db.update('trips', tripId, {
      lifecycleState: newLifecycle,
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
}

module.exports = new TripService();
