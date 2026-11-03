import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/models/admin/admin_role.dart';
import 'package:kith_app/presentation/views/admin/widgets/admin_confirm_dialog.dart';
import 'package:kith_app/presentation/views/admin/widgets/admin_metric_card.dart';
import 'package:kith_app/presentation/views/admin/widgets/admin_permission_guard.dart';

void main() {
  group('Admin Permission Guard Widget Tests', () {
    testWidgets('Renders restricted message when role lacks permission', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminPermissionGuard(
              permission: AdminPermission.suspendUsers,
              currentRole: AdminRole.analyst, // Analyst cannot suspend users
              child: Text('PROTECTED_CONTENT'),
            ),
          ),
        ),
      );

      expect(find.text('PROTECTED_CONTENT'), findsNothing);
      expect(find.text('Permission Restricted'), findsOneWidget);
      expect(find.byIcon(Icons.lock_person_outlined), findsOneWidget);
    });

    testWidgets('Renders protected child when role possesses permission', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminPermissionGuard(
              permission: AdminPermission.suspendUsers,
              currentRole: AdminRole.admin, // Admin can suspend users
              child: Text('PROTECTED_CONTENT'),
            ),
          ),
        ),
      );

      expect(find.text('PROTECTED_CONTENT'), findsOneWidget);
      expect(find.text('Permission Restricted'), findsNothing);
    });
  });

  group('Admin Metric Card Widget Tests', () {
    testWidgets('Renders metric title, value, and subtitle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminMetricCard(
              title: 'Total Active Users',
              value: '1,420',
              subtitle: '+12% from last week',
              icon: Icons.people_outline,
            ),
          ),
        ),
      );

      expect(find.text('Total Active Users'), findsOneWidget);
      expect(find.text('1,420'), findsOneWidget);
      expect(find.text('+12% from last week'), findsOneWidget);
      expect(find.byIcon(Icons.people_outline), findsOneWidget);
    });

    testWidgets('Shows loading shimmer when isLoading is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminMetricCard(
              title: 'Total Active Users',
              value: '1,420',
              icon: Icons.people_outline,
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.text('1,420'), findsNothing);
    });
  });

  group('Admin Confirm Dialog Widget Tests', () {
    testWidgets('Renders confirmation dialog and triggers dismissal on Cancel', (tester) async {
      String? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await AdminConfirmDialog.show(
                      context,
                      title: 'Suspend Account',
                      message: 'Are you sure you want to suspend this account?',
                      isDestructive: true,
                    );
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Suspend Account'), findsOneWidget);
      expect(find.text('Are you sure you want to suspend this account?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Suspend Account'), findsNothing);
      expect(result, isNull);
    });

    testWidgets('Enforces reason requirement before allowing confirmation', (tester) async {
      String? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await AdminConfirmDialog.show(
                      context,
                      title: 'Suspend User',
                      message: 'Mandatory reason required.',
                      isDestructive: true,
                      requireReason: true,
                      reasonHint: 'Enter suspension justification...',
                    );
                  },
                  child: const Text('Open Suspend Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Suspend Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Suspend User'), findsOneWidget);

      // Tapping Confirm with empty reason displays validation error
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.text('A non-empty justification is strictly required.'), findsOneWidget);
      expect(result, isNull);

      // Enter justification
      await tester.enterText(find.byType(TextField), 'Terms of service violation');
      await tester.pumpAndSettle();

      // Tap Confirm again
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(result, equals('Terms of service violation'));
    });
  });
}
