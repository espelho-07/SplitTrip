const crypto = require('crypto');
const { db } = require('../db/database');
const { AppError } = require('../middleware/error_handler');
const notificationService = require('./notification_service');

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
    return db.find('trip_members', (m) => m.tripId === tripId && m.status !== 'merged');
  }

  _enrichTrip(trip) {
    if (!trip) return null;
    const members = this._getMembersForTrip(trip.id);
    return {
      ...trip,
      revision: trip.revision || 1,
      completionMode: trip.completionMode || null,
      startedAt: trip.startedAt || trip.createdAt,
      completedAt: trip.completedAt || null,
      completedBy: trip.completedBy || null,
      members: members.map((m) => {
        const u = db.get('users', m.userId) || {};
        const isUnclaimed = m.status === 'unclaimed' || (m.userId && m.userId.startsWith('unclaimed_'));
        return {
          id: m.id,
          userId: m.userId,
          displayName: m.displayName,
          avatarUrl: m.avatarUrl || null,
          role: m.role || 'member',
          status: m.status || (isUnclaimed ? 'unclaimed' : 'claimed'),
          isClaimed: typeof m.isClaimed === 'boolean' ? m.isClaimed : !isUnclaimed,
          claimToken: m.claimToken || null,
          isVirtual: m.isVirtual !== undefined ? m.isVirtual : isUnclaimed,
          mergedIntoMemberId: m.mergedIntoMemberId || null,
          joinedAt: m.joinedAt,
          lastSeenAt: m.lastSeenAt || m.joinedAt || null,
          lastSyncedRevision: m.lastSyncedRevision || trip.revision || 1,
          pendingMutationsCount: m.pendingMutationsCount || 0,
          upiId: m.upiId || u.upiId || null,
        };
      }),
    };
  }


  createTrip(user, { id, inviteCode: customInviteCode, name, description, emoji, coverGradientIndex, currencyCode, initialFriendNames = [], tripMode = 'split_only', members } = {}, realtimeHub = null) {
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
      startedAt: now,
      completedAt: null,
      completedBy: null,
      createdAt: now,
      updatedAt: now,
    };

    db.insert('trips', trip);

    // Determine creator member ID (preserving client-generated ID when supplied)
    let creatorMemberId = `mbr_${crypto.randomUUID().replace(/-/g, '').substring(0, 10)}`;
    if (Array.isArray(members) && members.length > 0) {
      const clientCreator = members.find((m) => m.userId === user.id || m.role === 'creator');
      if (clientCreator && clientCreator.id && typeof clientCreator.id === 'string' && clientCreator.id.startsWith('mbr_')) {
        creatorMemberId = clientCreator.id;
      }
    }

    // Creator membership
    const creatorMember = {
      id: creatorMemberId,
      tripId,
      userId: user.id,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl || null,
      role: 'creator',
      status: 'claimed',
      isClaimed: true,
      joinedAt: now,
      lastSeenAt: now,
      lastSyncedRevision: 1,
      pendingMutationsCount: 0,
      upiId: user.upiId || null,
    };
    db.insert('trip_members', creatorMember);

    // Initial friends (unclaimed placeholders, preserving client-generated IDs and claimTokens)
    if (Array.isArray(initialFriendNames)) {
      for (const friendName of initialFriendNames) {
        if (friendName && friendName.trim()) {
          const cleanName = friendName.trim();
          let friendMemberId = `mbr_${crypto.randomUUID().replace(/-/g, '').substring(0, 10)}`;
          let friendClaimToken = `clm_${crypto.randomUUID().replace(/-/g, '').substring(0, 10)}`;
          let friendUserId = `unclaimed_${crypto.randomUUID().replace(/-/g, '').substring(0, 8)}`;

          if (Array.isArray(members) && members.length > 0) {
            const clientFriend = members.find(
              (m) => m.displayName && m.displayName.trim().toLowerCase() === cleanName.toLowerCase() && m.id !== creatorMemberId
            );
            if (clientFriend) {
              if (clientFriend.id && typeof clientFriend.id === 'string' && clientFriend.id.startsWith('mbr_')) {
                friendMemberId = clientFriend.id;
              }
              if (clientFriend.claimToken) {
                friendClaimToken = clientFriend.claimToken;
              }
              if (clientFriend.userId) {
                friendUserId = clientFriend.userId;
              }
            }
          }

          const placeholderMember = {
            id: friendMemberId,
            tripId,
            userId: friendUserId,
            displayName: cleanName,
            avatarUrl: null,
            role: 'member',
            status: 'unclaimed',
            isClaimed: false,
            claimToken: friendClaimToken,
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

  getActivityLogs(tripId, userId, { limit = 100, offset = 0 } = {}) {
    const trip = db.get('trips', tripId);
    if (!trip) throw AppError.notFound('Trip not found');

    const authMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === userId);
    if (!authMember) throw AppError.forbidden('Not authorized to view activity logs for this trip');

    const logs = db.find('activity_logs', (a) => a.tripId === tripId);
    const sorted = logs.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    const safeLimit = Math.min(200, Math.max(1, parseInt(limit, 10) || 100));
    const safeOffset = Math.max(0, parseInt(offset, 10) || 0);
    return sorted.slice(safeOffset, safeOffset + safeLimit);
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

    const unclaimedMembers = members
      .filter((m) => m.status === 'unclaimed' || m.isClaimed === false || (m.userId && m.userId.startsWith('unclaimed_')))
      .map((m) => ({
        id: m.id,
        displayName: m.displayName,
        avatarUrl: m.avatarUrl || null,
      }));

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
      unclaimedMembers,
    };
  }

  joinTripByCode(user, inviteCode, { claimMemberId, claimToken } = {}, realtimeHub = null) {
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

    // 1. Idempotency Check: if user is already a member, return existing trip
    const existingMember = db.findOne('trip_members', (m) => m.tripId === trip.id && m.userId === user.id);
    if (existingMember) {
      return this._enrichTrip(trip);
    }

    const now = new Date().toISOString();
    let activeMember;

    // 2. Authoritative Claim Flow: claim a specific unclaimed participant placeholder
    if (claimMemberId) {
      const targetMember = db.findOne('trip_members', (m) => m.tripId === trip.id && m.id === claimMemberId);
      if (!targetMember) {
        throw AppError.notFound('Target member not found in this trip.');
      }

      // 2a. Concurrency & double claim prevention / token reuse prevention
      if (
        targetMember.status === 'claimed' ||
        targetMember.isClaimed === true ||
        (targetMember.userId && !targetMember.userId.startsWith('unclaimed_') && targetMember.userId !== user.id)
      ) {
        throw AppError.conflict('This member participant has already been claimed.');
      }

      // 2b. Strict claimToken validation
      if (targetMember.claimToken && typeof targetMember.claimToken === 'string' && targetMember.claimToken.trim().length > 0) {
        if (!claimToken || typeof claimToken !== 'string' || claimToken.trim() !== targetMember.claimToken.trim()) {
          throw AppError.forbidden('Invalid or missing claim token for this participant.');
        }
      } else {
        // Safe backward compatibility for legacy members without stored claim tokens:
        // Prevent unauthorized hijacking by requiring creator authorization.
        if (trip.creatorId !== user.id) {
          throw AppError.forbidden('This legacy participant record requires creator authorization to claim.');
        }
      }

      // Atomically link user identity to the existing participant record
      // Invalidate claimToken upon successful claim to prevent token reuse
      db.update('trip_members', targetMember.id, {
        userId: user.id,
        avatarUrl: user.avatarUrl || targetMember.avatarUrl || null,
        status: 'claimed',
        isClaimed: true,
        claimToken: null,
        joinedAt: now,
        lastSeenAt: now,
        upiId: user.upiId || targetMember.upiId || null,
      });
      activeMember = db.get('trip_members', targetMember.id);

      this.logActivity(trip.id, {
        type: 'member_joined',
        actorId: user.id,
        actorName: user.displayName,
        description: `${user.displayName} joined as ${targetMember.displayName}`,
        metadata: { memberId: activeMember.id, claimed: true, originalDisplayName: targetMember.displayName },
      });
    } else {
      // 3. New Member Flow: create fresh member record
      activeMember = {
        id: `mbr_${crypto.randomUUID().replace(/-/g, '').substring(0, 10)}`,
        tripId: trip.id,
        userId: user.id,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl || null,
        role: 'member',
        status: 'claimed',
        isClaimed: true,
        joinedAt: now,
        lastSeenAt: now,
        lastSyncedRevision: 1,
        pendingMutationsCount: 0,
        upiId: user.upiId || null,
      };
      db.insert('trip_members', activeMember);

      this.logActivity(trip.id, {
        type: 'member_joined',
        actorId: user.id,
        actorName: user.displayName,
        description: `${user.displayName} joined the trip`,
        metadata: { memberId: activeMember.id, claimed: false },
      });
    }

    db.update('trips', trip.id, { updatedAt: now });

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

    // Dispatch member joined notifications and push alerts
    notificationService.notifyMemberJoined({
      trip: enriched,
      member: activeMember,
      actor: user,
      realtimeHub,
    });

    return enriched;
  }

  addMember(tripId, currentUserId, { id: memberId, userId: explicitUserId, displayName, claimToken: explicitClaimToken, isVirtual = true }, realtimeHub = null) {
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
    const finalId = memberId || `mbr_${crypto.randomUUID().replace(/-/g, '').substring(0, 10)}`;

    // Check if member already exists by ID (idempotency)
    const existing = db.findOne('trip_members', (m) => m.tripId === tripId && m.id === finalId);
    if (existing) {
      return this._enrichTrip(trip);
    }

    // Check if an unclaimed member with the same display name already exists (idempotency)
    const cleanName = displayName.trim().toLowerCase();
    const existingByName = db.findOne('trip_members', (m) => 
      m.tripId === tripId && 
      m.status === 'unclaimed' && 
      (m.displayName || '').trim().toLowerCase() === cleanName
    );
    if (existingByName) {
      return this._enrichTrip(trip);
    }

    const newMember = {
      id: finalId,
      tripId,
      userId: explicitUserId || `unclaimed_${crypto.randomUUID().replace(/-/g, '').substring(0, 8)}`,
      displayName: displayName.trim(),
      avatarUrl: null,
      role: 'member',
      status: 'unclaimed',
      isClaimed: false,
      isVirtual: isVirtual !== false,
      claimToken: explicitClaimToken || `clm_${crypto.randomUUID().replace(/-/g, '').substring(0, 10)}`,
      joinedAt: now,
      lastSeenAt: now,
      lastSyncedRevision: 1,
      pendingMutationsCount: 0,
    };

    db.insert('trip_members', newMember);
    db.update('trips', tripId, { updatedAt: now });

    this.logActivity(tripId, {
      type: 'member_joined',
      actorId: currentUserId,
      actorName: authMember.displayName,
      description: `${authMember.displayName} added "${displayName.trim()}"`,
      metadata: { memberId: newMember.id, isUnclaimed: true },
    });

    const enriched = this._enrichTrip(trip);

    if (realtimeHub) {
      realtimeHub.broadcastToTrip(tripId, 'member_added', {
        tripId,
        member: newMember,
        trip: enriched,
      });
    }

    return enriched;
  }

  renameMember(tripId, currentUserId, memberId, newDisplayName, realtimeHub = null) {
    if (!newDisplayName || !newDisplayName.trim()) {
      throw AppError.badRequest('Member display name is required');
    }

    const trip = db.get('trips', tripId);
    if (!trip) throw AppError.notFound('Trip not found');

    const authMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === currentUserId);
    if (!authMember) throw AppError.forbidden('Not authorized for this trip');

    if (trip.creatorId !== currentUserId && authMember.role !== 'creator') {
      throw AppError.forbidden('Only the trip creator can rename members');
    }

    const targetMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.id === memberId);
    if (!targetMember) throw AppError.notFound('Member not found in this trip');

    const isRealUser = targetMember.userId && !targetMember.userId.startsWith('unclaimed_');
    if (isRealUser && targetMember.isClaimed !== false && targetMember.status !== 'unclaimed') {
      throw AppError.forbidden('Cannot rename registered Kith users. Their identity belongs to their Kith profile.');
    }

    const oldName = targetMember.displayName;
    const now = new Date().toISOString();
    db.update('trip_members', memberId, {
      displayName: newDisplayName.trim(),
      updatedAt: now,
    });
    db.update('trips', tripId, { updatedAt: now });

    this.logActivity(tripId, {
      type: 'member_renamed',
      actorId: currentUserId,
      actorName: authMember.displayName,
      description: `${authMember.displayName} renamed "${oldName}" to "${newDisplayName.trim()}"`,
      metadata: { memberId, oldName, newName: newDisplayName.trim() },
    });

    const enriched = this._enrichTrip(db.get('trips', tripId));

    if (realtimeHub) {
      realtimeHub.broadcastToTrip(tripId, 'member_renamed', {
        tripId,
        memberId,
        oldName,
        displayName: newDisplayName.trim(),
        trip: enriched,
      });
    }

    return enriched;
  }

  removeMember(tripId, currentUserId, memberId, realtimeHub = null) {
    const trip = db.get('trips', tripId);
    if (!trip) throw AppError.notFound('Trip not found');

    const authMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === currentUserId);
    if (!authMember) throw AppError.forbidden('Not authorized for this trip');

    if (trip.creatorId !== currentUserId && authMember.role !== 'creator') {
      throw AppError.forbidden('Only the trip creator can remove members');
    }

    const targetMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.id === memberId);
    if (!targetMember) throw AppError.notFound('Member not found in this trip');

    if (targetMember.id === authMember.id || targetMember.userId === trip.creatorId || targetMember.role === 'creator') {
      throw AppError.forbidden('Cannot remove the trip creator');
    }

    // Financial Safety Check: verify no expenses paid, no splits, and no settlements
    const expenses = db.find('expenses', (e) => e.tripId === tripId && !e.isDeleted);
    const hasExpensesPaid = expenses.some((e) => e.paidById === memberId);
    const hasExpenseSplits = expenses.some((e) =>
      (e.splits || []).some((s) => s.memberId === memberId && (s.amountInPaise > 0 || s.amount > 0))
    );
    const settlements = db.find('settlements', (s) => s.tripId === tripId);
    const hasSettlements = settlements.some((s) => s.fromMemberId === memberId || s.toMemberId === memberId);

    if (hasExpensesPaid || hasExpenseSplits || hasSettlements) {
      throw AppError.badRequest(
        'Cannot remove member with financial activity. Expenses or settlements are linked to this member. Settle all debts and reassign or merge their activity first.'
      );
    }

    // Safe deletion of participant with zero financial footprint
    db.delete('trip_members', memberId);

    const now = new Date().toISOString();
    const newRevision = (trip.revision || 1) + 1;
    db.update('trips', tripId, { revision: newRevision, updatedAt: now });

    this.logActivity(tripId, {
      type: 'member_removed',
      actorId: currentUserId,
      actorName: authMember.displayName,
      description: `${authMember.displayName} removed "${targetMember.displayName}"`,
      metadata: { memberId, removedDisplayName: targetMember.displayName },
    });

    const enriched = this._enrichTrip(db.get('trips', tripId));

    if (realtimeHub) {
      realtimeHub.broadcastToTrip(tripId, 'member_removed', {
        tripId,
        memberId,
        displayName: targetMember.displayName,
        trip: enriched,
      });
    }

    return enriched;
  }

  mergeMembers(tripId, currentUserId, { sourceMemberId, canonicalMemberId, operationId } = {}, realtimeHub = null) {
    if (!sourceMemberId || !canonicalMemberId) {
      throw AppError.badRequest('Both sourceMemberId and canonicalMemberId are required');
    }

    if (sourceMemberId === canonicalMemberId) {
      throw AppError.badRequest('Cannot merge a member into themselves');
    }

    const trip = db.get('trips', tripId);
    if (!trip) throw AppError.notFound('Trip not found');

    const authMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === currentUserId);
    if (!authMember) throw AppError.forbidden('Not authorized for this trip');

    if (trip.creatorId !== currentUserId && authMember.role !== 'creator') {
      throw AppError.forbidden('Only the trip creator can merge members');
    }

    const sourceMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.id === sourceMemberId);
    const canonicalMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.id === canonicalMemberId);

    if (!sourceMember || !canonicalMember) {
      throw AppError.notFound('One or both members not found in this trip');
    }

    if (sourceMember.role === 'creator' || sourceMember.userId === trip.creatorId) {
      throw AppError.forbidden('Cannot merge the trip creator away. The creator must remain canonical.');
    }

    // Protect against silently merging two distinct authenticated Kith users
    const isSourceReal = sourceMember.userId && !sourceMember.userId.startsWith('unclaimed_');
    const isCanonicalReal = canonicalMember.userId && !canonicalMember.userId.startsWith('unclaimed_');
    if (isSourceReal && isCanonicalReal && sourceMember.userId !== canonicalMember.userId) {
      throw AppError.badRequest(
        'Cannot merge two distinct authenticated Kith accounts. Merging is reserved for unclaimed members and duplicate profiles.'
      );
    }

    const now = new Date().toISOString();

    // 1. Repoint all Expenses & Splits atomically
    const expenses = db.find('expenses', (e) => e.tripId === tripId);
    for (const exp of expenses) {
      let expModified = false;
      let updatedPayer = exp.paidById;

      if (exp.paidById === sourceMemberId) {
        updatedPayer = canonicalMemberId;
        expModified = true;
      }

      let updatedSplits = [...(exp.splits || [])];
      const sourceSplitIdx = updatedSplits.findIndex((s) => s.memberId === sourceMemberId);
      const canonSplitIdx = updatedSplits.findIndex((s) => s.memberId === canonicalMemberId);

      if (sourceSplitIdx !== -1) {
        expModified = true;
        if (canonSplitIdx !== -1) {
          // Combine shares for same expense
          const sSplit = updatedSplits[sourceSplitIdx];
          const cSplit = updatedSplits[canonSplitIdx];
          updatedSplits[canonSplitIdx] = {
            ...cSplit,
            amountInPaise: (cSplit.amountInPaise || 0) + (sSplit.amountInPaise || 0),
            amount: (cSplit.amount || 0) + (sSplit.amount || 0),
          };
          updatedSplits.splice(sourceSplitIdx, 1);
        } else {
          // Repoint source split to canonical member
          updatedSplits[sourceSplitIdx] = {
            ...updatedSplits[sourceSplitIdx],
            memberId: canonicalMemberId,
          };
        }
      }

      if (expModified) {
        db.update('expenses', exp.id, {
          paidById: updatedPayer,
          splits: updatedSplits,
          updatedAt: now,
        });
      }
    }

    // 2. Repoint all Settlements atomically
    const settlements = db.find('settlements', (s) => s.tripId === tripId);
    for (const s of settlements) {
      let sMod = false;
      let fromM = s.fromMemberId;
      let toM = s.toMemberId;

      if (s.fromMemberId === sourceMemberId) {
        fromM = canonicalMemberId;
        sMod = true;
      }
      if (s.toMemberId === sourceMemberId) {
        toM = canonicalMemberId;
        sMod = true;
      }

      if (sMod) {
        db.update('settlements', s.id, {
          fromMemberId: fromM,
          toMemberId: toM,
          updatedAt: now,
        });
      }
    }

    // 3. Mark source member as merged tombstone (excluded from active roster)
    db.update('trip_members', sourceMemberId, {
      status: 'merged',
      mergedIntoMemberId: canonicalMemberId,
      updatedAt: now,
    });

    // 4. Increment trip revision and log activity
    const newRevision = (trip.revision || 1) + 1;
    db.update('trips', tripId, { revision: newRevision, updatedAt: now });

    this.logActivity(tripId, {
      type: 'members_merged',
      actorId: currentUserId,
      actorName: authMember.displayName,
      description: `${authMember.displayName} merged "${sourceMember.displayName}" into "${canonicalMember.displayName}"`,
      metadata: {
        sourceMemberId,
        canonicalMemberId,
        sourceDisplayName: sourceMember.displayName,
        canonicalDisplayName: canonicalMember.displayName,
        operationId: operationId || null,
      },
    });

    const enriched = this._enrichTrip(db.get('trips', tripId));

    if (realtimeHub) {
      realtimeHub.broadcastToTrip(tripId, 'members_merged', {
        tripId,
        sourceMemberId,
        canonicalMemberId,
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
      const isCurrentUser = m.userId === currentUserId || (authMember && m.id === authMember.id);
      const isVirtual = m.isVirtual === true || m.isClaimed === false || !m.userId || (m.userId && (m.userId.startsWith('unclaimed_') || m.userId.startsWith('virtual_'))) || m.role === 'virtual' || Boolean(m.claimToken);
      const isOnline = isCurrentUser || isVirtual ? true : (realtimeHub ? realtimeHub.isTripMemberConnected(tripId, m.userId) : false);
      const memberRevision = isVirtual ? tripRevision : (m.lastSyncedRevision || 1);
      const pendingCount = isVirtual ? 0 : (m.pendingMutationsCount || 0);
      const lastSeenDate = m.lastSeenAt ? new Date(m.lastSeenAt) : null;

      const freshAckMs = 2 * 60 * 1000;
      let syncStatus = 'synced';
      if (isVirtual) {
        syncStatus = 'synced';
      } else if (pendingCount > 0) {
        syncStatus = isOnline ? 'pending' : 'offline';
      } else if (memberRevision < tripRevision) {
        syncStatus = isOnline ? 'pending' : 'offline';
      } else if (!isOnline && !isCurrentUser) {
        const acknowledgedRecently = lastSeenDate && (nowDate - lastSeenDate) <= freshAckMs;
        // An offline participant can create expenses after the last acknowledgement.
        // A stale ack is not evidence that their local queue is empty.
        syncStatus = acknowledgedRecently ? 'synced' : 'unknown';
      }

      return {
        memberId: m.id,
        userId: m.userId,
        displayName: m.displayName,
        avatarUrl: m.avatarUrl || null,
        isCreator: m.role === 'creator',
        isCurrentUser,
        isVirtual,
        isOnline,
        syncStatus,
        acknowledgedRevision: memberRevision,
        pendingCount,
        lastSeenAt: m.lastSeenAt || null,
        lastSyncFormatted: isVirtual ? 'Virtual member' : this._formatLastSync(m.lastSeenAt),
      };
    });

    const unsyncedCount = participants.filter((p) => !p.isVirtual && (p.syncStatus !== 'synced' || p.pendingCount > 0)).length;
    const isFullySynced = unsyncedCount === 0;

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

    // Dispatch trip completed notifications and push alerts
    notificationService.notifyTripCompleted({
      trip: enriched,
      actor: { id: currentUserId, displayName: authMember.displayName },
      realtimeHub,
    });

    return enriched;
  }

  reconcileDuplicateMembers(tripId) {
    const trip = db.get('trips', tripId);
    if (!trip) return null;

    const members = this._getMembersForTrip(tripId);
    const byUserId = new Map();

    for (const m of members) {
      if (!m.userId || m.userId.startsWith('unclaimed_')) continue;
      if (!byUserId.has(m.userId)) {
        byUserId.set(m.userId, []);
      }
      byUserId.get(m.userId).push(m);
    }

    let changed = false;
    for (const [userId, userMembers] of byUserId.entries()) {
      if (userMembers.length > 1) {
        // Keep the primary member (first joined or claimed)
        const primary = userMembers[0];
        const duplicates = userMembers.slice(1);

        for (const dup of duplicates) {
          // Re-attach any expenses or splits pointing to duplicate member
          const expenses = db.find('expenses', (e) => e.tripId === tripId);
          for (const exp of expenses) {
            let expModified = false;
            let updatedPayer = exp.paidById;
            if (exp.paidById === dup.id) {
              updatedPayer = primary.id;
              expModified = true;
            }

            const updatedSplits = (exp.splits || []).map((s) => {
              if (s.memberId === dup.id) {
                expModified = true;
                return { ...s, memberId: primary.id };
              }
              return s;
            });

            if (expModified) {
              db.update('expenses', exp.id, {
                paidById: updatedPayer,
                splits: updatedSplits,
              });
            }
          }

          // Delete the duplicate member record
          db.delete('trip_members', dup.id);
          changed = true;
        }
      }
    }

    if (changed) {
      db.update('trips', tripId, { updatedAt: new Date().toISOString() });
    }

    return this._enrichTrip(db.get('trips', tripId));
  }
}

module.exports = new TripService();
