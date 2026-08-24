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
      members: members.map((m) => ({
        id: m.id,
        userId: m.userId,
        displayName: m.displayName,
        avatarUrl: m.avatarUrl || null,
        role: m.role || 'member',
        joinedAt: m.joinedAt,
      })),
    };
  }

  createTrip(user, { name, description, emoji, coverGradientIndex, currencyCode, initialFriendNames = [] }) {
    if (!name || !name.trim()) {
      throw AppError.badRequest('Trip name is required');
    }

    const tripId = `trip_${crypto.randomUUID().replace(/-/g, '').substring(0, 12)}`;
    let inviteCode = this._generateInviteCode();

    // Ensure code uniqueness
    while (db.findOne('trips', (t) => t.inviteCode === inviteCode)) {
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

    return this._enrichTrip(trip);
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
    if (!inviteCode || !inviteCode.trim()) {
      throw AppError.badRequest('Join code is required');
    }

    const cleanCode = inviteCode.trim().toUpperCase();
    const trip = db.findOne('trips', (t) => t.inviteCode === cleanCode || t.id === cleanCode);

    if (!trip) {
      throw AppError.notFound('No trip found for this invite code');
    }

    const creator = db.get('users', trip.creatorId);
    const members = this._getMembersForTrip(trip.id);

    return {
      tripId: trip.id,
      name: trip.name,
      emoji: trip.emoji,
      coverGradientIndex: trip.coverGradientIndex,
      currencyCode: trip.currencyCode,
      creatorName: creator ? creator.displayName : 'Trip Creator',
      memberCount: members.length,
      lifecycleState: trip.lifecycleState,
      inviteCode: trip.inviteCode,
    };
  }

  joinTripByCode(user, inviteCode, realtimeHub = null) {
    if (!inviteCode || !inviteCode.trim()) {
      throw AppError.badRequest('Join code is required');
    }

    const cleanCode = inviteCode.trim().toUpperCase();
    const trip = db.findOne('trips', (t) => t.inviteCode === cleanCode || t.id === cleanCode);

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
    const newMember = {
      id: `mbr_${crypto.randomUUID().replace(/-/g, '').substring(0, 10)}`,
      tripId: trip.id,
      userId: user.id,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl || null,
      role: 'member',
      joinedAt: now,
    };

    db.insert('trip_members', newMember);
    db.update('trips', trip.id, { updatedAt: now });

    const enriched = this._enrichTrip(trip);

    if (realtimeHub) {
      realtimeHub.broadcastToTrip(trip.id, 'member_joined', {
        tripId: trip.id,
        member: newMember,
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
