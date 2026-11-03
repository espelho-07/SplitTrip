import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/models/admin/admin_models.dart';

void main() {
  group('Admin Models & Serialization Tests', () {
    test('AdminRole enum normalization and permission hierarchy', () {
      expect(AdminRole.fromString('super_admin'), equals(AdminRole.superAdmin));
      expect(AdminRole.fromString('super-admin'), equals(AdminRole.superAdmin));
      expect(AdminRole.fromString('ADMIN'), equals(AdminRole.admin));
      expect(AdminRole.fromString('support_admin'), equals(AdminRole.supportAdmin));
      expect(AdminRole.fromString('analyst'), equals(AdminRole.analyst));
      expect(AdminRole.fromString('moderator'), equals(AdminRole.moderator));
      expect(AdminRole.fromString(null), equals(AdminRole.moderator)); // Default lowest privilege
    });

    test('AdminUser JSON serialization and deserialization', () {
      final now = DateTime.now();
      final user = AdminUser(
        id: 'usr_admin_001',
        email: 'owner@kith.app',
        displayName: 'Platform Owner',
        avatarUrl: 'https://kith.app/avatar.png',
        role: AdminRole.superAdmin,
        grantedAt: now,
        grantedBy: 'system_bootstrap',
        lastActiveAt: now,
      );

      final json = user.toJson();
      expect(json['id'], equals('usr_admin_001'));
      expect(json['email'], equals('owner@kith.app'));
      expect(json['role'], equals('super_admin'));

      final restored = AdminUser.fromJson(json);
      expect(restored.id, equals(user.id));
      expect(restored.email, equals(user.email));
      expect(restored.displayName, equals(user.displayName));
      expect(restored.role, equals(AdminRole.superAdmin));
      expect(restored.grantedBy, equals('system_bootstrap'));
      expect(restored.hasPermission(AdminPermission.suspendUsers), isTrue);
    });

    test('ManagedUser JSON serialization and suspension status', () {
      final now = DateTime.now();
      final user = ManagedUser(
        id: 'usr_guest_42',
        displayName: 'Traveler Alice',
        email: null,
        isGuest: true,
        status: UserAccountStatus.suspended,
        createdAt: now,
        tripCount: 3,
        expenseCount: 12,
        suspendedAt: now,
        suspensionReason: 'Abusive spam reports',
      );

      expect(user.isSuspended, isTrue);
      expect(user.status, equals(UserAccountStatus.suspended));

      final json = user.toJson();
      expect(json['id'], equals('usr_guest_42'));
      expect(json['isGuest'], isTrue);
      expect(json['status'], equals('suspended'));
      expect(json['suspensionReason'], equals('Abusive spam reports'));

      final restored = ManagedUser.fromJson(json);
      expect(restored.id, equals(user.id));
      expect(restored.isGuest, isTrue);
      expect(restored.isSuspended, isTrue);
      expect(restored.suspensionReason, equals('Abusive spam reports'));
    });

    test('UserFeedback JSON serialization and category parsing', () {
      final now = DateTime.now();
      final feedback = UserFeedback(
        id: 'fb_100',
        userId: 'usr_200',
        userDisplayName: 'Bob',
        category: FeedbackCategory.bugReport,
        subject: 'Offline sync failed',
        description: 'Failed to sync trip while offline in flight mode',
        priority: FeedbackPriority.critical,
        status: FeedbackStatus.newStatus,
        createdAt: now,
        updatedAt: now,
        isPublic: false,
      );

      final json = feedback.toJson();
      expect(json['id'], equals('fb_100'));
      expect(json['category'], equals('bug_report'));
      expect(json['priority'], equals('critical'));

      final restored = UserFeedback.fromJson(json);
      expect(restored.id, equals(feedback.id));
      expect(restored.category, equals(FeedbackCategory.bugReport));
      expect(restored.priority, equals(FeedbackPriority.critical));
      expect(restored.status, equals(FeedbackStatus.newStatus));
      expect(restored.isPublic, isFalse);
    });

    test('FeedbackInternalNote isolation and JSON integrity', () {
      final now = DateTime.now();
      final note = FeedbackInternalNote(
        id: 'note_1',
        feedbackId: 'fb_100',
        adminUserId: 'admin_1',
        adminDisplayName: 'Support Lead',
        note: 'Verified with logs: user device network disconnected mid-stream.',
        createdAt: now,
      );

      final json = note.toJson();
      expect(json['feedback_id'], equals('fb_100'));
      expect(json['admin_user_id'], equals('admin_1'));

      final restored = FeedbackInternalNote.fromJson(json);
      expect(restored.note, equals(note.note));
      expect(restored.adminDisplayName, equals('Support Lead'));
    });

    test('FeatureRequest and atomic upvote model serialization', () {
      final now = DateTime.now();
      final req = FeatureRequest(
        id: 'feat_1',
        title: 'CSV Export for Personal Expenses',
        description: 'Allow exporting spending ledger to CSV spreadsheet',
        status: 'open',
        upvoteCount: 42,
        hasVoted: true,
        createdAt: now,
        updatedAt: now,
      );

      final json = req.toJson();
      expect(json['upvote_count'], equals(42));
      expect(json['has_voted'], isTrue);

      final restored = FeatureRequest.fromJson(json);
      expect(restored.title, equals(req.title));
      expect(restored.upvoteCount, equals(42));
      expect(restored.hasVoted, isTrue);
    });

    test('AdminAnnouncement scheduling and audience calculation', () {
      final now = DateTime.now();
      final futureStart = now.add(const Duration(hours: 2));
      final pastStart = now.subtract(const Duration(hours: 2));
      final pastEnd = now.subtract(const Duration(hours: 1));
      final futureEnd = now.add(const Duration(days: 3));

      final scheduled = AdminAnnouncement(
        id: 'ann_1',
        title: 'Maintenance Upcoming',
        message: 'System will undergo maintenance tonight.',
        targetAudience: AnnouncementAudience.all,
        startsAt: futureStart,
        expiresAt: futureEnd,
        createdBy: 'admin_1',
        createdAt: now,
        updatedAt: now,
      );
      expect(scheduled.isActive, isFalse); // Not started yet

      final active = AdminAnnouncement(
        id: 'ann_2',
        title: 'Welcome to KITH v2',
        message: 'Explore the newly released offline mesh sync.',
        targetAudience: AnnouncementAudience.registered,
        startsAt: pastStart,
        expiresAt: futureEnd,
        createdBy: 'admin_1',
        createdAt: now,
        updatedAt: now,
      );
      expect(active.isActive, isTrue); // In valid active window

      final expired = AdminAnnouncement(
        id: 'ann_3',
        title: 'Old Notice',
        message: 'This notice expired.',
        targetAudience: AnnouncementAudience.guest,
        startsAt: pastStart,
        expiresAt: pastEnd,
        createdBy: 'admin_1',
        createdAt: now,
        updatedAt: now,
      );
      expect(expired.isActive, isFalse); // Already expired
    });

    test('AdminAuditLog JSON round-trip with state diff', () {
      final now = DateTime.now();
      final log = AdminAuditLog(
        id: 'log_001',
        adminUserId: 'admin_super',
        adminEmail: 'owner@kith.app',
        action: AuditAction.userSuspended,
        targetType: 'user',
        targetId: 'usr_bad_actor',
        previousState: {'is_suspended': false},
        newState: {'is_suspended': true, 'reason': 'Violation of Terms of Service'},
        ipAddress: '192.168.1.1',
        userAgent: 'KithAdminWeb/1.0',
        createdAt: now,
      );

      final json = log.toJson();
      expect(json['action'], equals('user_suspended'));
      expect(json['target_id'], equals('usr_bad_actor'));
      expect(json['previous_state']['is_suspended'], isFalse);
      expect(json['new_state']['is_suspended'], isTrue);

      final restored = AdminAuditLog.fromJson(json);
      expect(restored.action, equals(AuditAction.userSuspended));
      expect(restored.previousState?['is_suspended'], isFalse);
      expect(restored.newState?['reason'], equals('Violation of Terms of Service'));
    });
  });
}
