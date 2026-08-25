const crypto = require('crypto');
const { db } = require('../db/database');
const { AppError } = require('../middleware/error_handler');

class JourneyService {
  createMoment(user, tripId, {
    id = null,
    title,
    placeName = null,
    note = null,
    latitude = null,
    longitude = null,
    occurredAt = null,
    dayIndex = 1,
    photoUrls = [],
    expenseId = null,
  }, realtimeHub = null) {
    if (!title || !title.trim()) {
      throw AppError.badRequest('Moment title is required');
    }

    const trip = db.get('trips', tripId);
    if (!trip) throw AppError.notFound('Trip not found');

    const authMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === user.id);
    if (!authMember) throw AppError.forbidden('You are not a member of this trip');

    // Idempotency: return existing moment if already created with this ID
    if (id) {
      const existing = db.get('trip_journey_moments', id);
      if (existing && existing.tripId === tripId) {
        return existing;
      }
    }

    const momentId = id || `moment_${crypto.randomBytes(8).toString('hex')}`;
    const now = new Date().toISOString();

    const moment = {
      id: momentId,
      tripId,
      createdBy: user.id,
      creatorName: authMember.displayName || user.displayName || 'Member',
      title: title.trim(),
      placeName: placeName ? placeName.trim() : null,
      note: note ? note.trim() : null,
      latitude: typeof latitude === 'number' ? latitude : null,
      longitude: typeof longitude === 'number' ? longitude : null,
      occurredAt: occurredAt || now,
      dayIndex: Number.isInteger(dayIndex) && dayIndex > 0 ? dayIndex : 1,
      photoUrls: Array.isArray(photoUrls) ? photoUrls : [],
      expenseId: expenseId || null,
      createdAt: now,
      updatedAt: now,
    };

    db.insert('trip_journey_moments', moment);

    if (realtimeHub) {
      realtimeHub.broadcastToTrip(tripId, {
        type: 'journey_moment_added',
        tripId,
        data: moment,
      });
    }

    return moment;
  }

  getTripMoments(user, tripId) {
    const trip = db.get('trips', tripId);
    if (!trip) throw AppError.notFound('Trip not found');

    const authMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === user.id);
    if (!authMember) throw AppError.forbidden('You are not a member of this trip');

    const moments = db.find('trip_journey_moments', (m) => m.tripId === tripId);
    return moments.sort((a, b) => {
      if (a.dayIndex !== b.dayIndex) return a.dayIndex - b.dayIndex;
      return new Date(a.occurredAt) - new Date(b.occurredAt);
    });
  }

  updateMoment(user, tripId, momentId, updates, realtimeHub = null) {
    const trip = db.get('trips', tripId);
    if (!trip) throw AppError.notFound('Trip not found');

    const authMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === user.id);
    if (!authMember) throw AppError.forbidden('You are not a member of this trip');

    const moment = db.get('trip_journey_moments', momentId);
    if (!moment || moment.tripId !== tripId) {
      throw AppError.notFound('Journey moment not found');
    }

    // Only moment creator or trip creator can update
    if (moment.createdBy !== user.id && trip.creatorId !== user.id) {
      throw AppError.forbidden('You can only edit your own moments');
    }

    const updated = {
      ...moment,
      title: updates.title !== undefined ? updates.title.trim() : moment.title,
      placeName: updates.placeName !== undefined ? updates.placeName : moment.placeName,
      note: updates.note !== undefined ? updates.note : moment.note,
      latitude: updates.latitude !== undefined ? updates.latitude : moment.latitude,
      longitude: updates.longitude !== undefined ? updates.longitude : moment.longitude,
      occurredAt: updates.occurredAt !== undefined ? updates.occurredAt : moment.occurredAt,
      dayIndex: updates.dayIndex !== undefined ? updates.dayIndex : moment.dayIndex,
      photoUrls: Array.isArray(updates.photoUrls) ? updates.photoUrls : moment.photoUrls,
      expenseId: updates.expenseId !== undefined ? updates.expenseId : moment.expenseId,
      updatedAt: new Date().toISOString(),
    };

    db.update('trip_journey_moments', momentId, updated);

    if (realtimeHub) {
      realtimeHub.broadcastToTrip(tripId, {
        type: 'journey_moment_updated',
        tripId,
        data: updated,
      });
    }

    return updated;
  }

  deleteMoment(user, tripId, momentId, realtimeHub = null) {
    const trip = db.get('trips', tripId);
    if (!trip) throw AppError.notFound('Trip not found');

    const authMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === user.id);
    if (!authMember) throw AppError.forbidden('You are not a member of this trip');

    const moment = db.get('trip_journey_moments', momentId);
    if (!moment || moment.tripId !== tripId) {
      throw AppError.notFound('Journey moment not found');
    }

    // Only moment creator or trip creator can delete
    if (moment.createdBy !== user.id && trip.creatorId !== user.id) {
      throw AppError.forbidden('You can only delete your own moments');
    }

    db.delete('trip_journey_moments', momentId);

    if (realtimeHub) {
      realtimeHub.broadcastToTrip(tripId, {
        type: 'journey_moment_deleted',
        tripId,
        momentId,
      });
    }

    return { success: true, momentId };
  }
}

module.exports = new JourneyService();
