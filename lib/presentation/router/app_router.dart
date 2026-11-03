import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../views/add_expense/add_expense_view.dart';
import '../views/cloud/cloud_settings_view.dart';
import '../views/guide/setup_guide_view.dart';
import '../views/help/help_faq_view.dart';
import '../views/home/home_view.dart';
import '../views/language/language_select_view.dart';
import '../views/legal/privacy_policy_view.dart';
import '../views/onboarding/onboarding_view.dart';
import '../views/onboarding/walkthrough_view.dart';
import '../views/splash/splash_view.dart';
import '../views/trip/create_trip_view.dart';
import '../views/trip/join_trip_view.dart';
import '../views/trip/qr_scanner_view.dart';
import '../views/trip/trip_detail_view.dart';
import '../views/trip/trip_members_view.dart';
import '../views/trip/trip_memories_view.dart';
import '../views/widgets/widget_gallery_view.dart';
import '../views/settings/master_settings_view.dart';
import '../views/profile/nirniq_profile_view.dart';
import '../views/notifications/notifications_view.dart';
import '../views/payment/payment_methods_view.dart';
import '../views/trip/trip_preview_view.dart';
import '../views/version/update_required_view.dart';
import '../views/admin/admin_shell_view.dart';
import '../viewmodels/admin/admin_dashboard_viewmodel.dart';

class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/splash',
    errorBuilder: (context, state) {
      debugPrint('[AppRouter] Route error for ${state.uri}: ${state.error}');
      return const HomeView();
    },
    redirect: (context, state) {
      final uri = state.uri;
      final uriString = uri.toString();

      // Handle 'kith://' custom scheme deep links sent directly to GoRouter by platform
      if (uri.scheme == 'kith' || uriString.startsWith('kith://')) {
        final host = uri.host.toLowerCase();
        final path = uri.path.toLowerCase();
        final fullPath = (host.isNotEmpty ? '/$host' : '') + path;



        if (host == 'create-trip' || fullPath.contains('create-trip')) {
          return '/create-trip';
        }
        if (host == 'widgets' || fullPath.contains('widgets')) {
          return '/widgets';
        }
        if (host == 'guide' || fullPath.contains('guide')) {
          return '/guide';
        }
        if (host == 'help' || fullPath.contains('help')) {
          return '/help';
        }
        if (host == 'cloud-settings' || fullPath.contains('cloud-settings')) {
          return '/cloud-settings';
        }
        if (host == 'auth' || host == 'onboarding' || fullPath.contains('auth')) {
          return '/onboarding';
        }
        if (host == 'trip' || fullPath.startsWith('/trip')) {
          final segments = uri.pathSegments;
          if (segments.isNotEmpty && segments.last != 'trip') {
            return '/trip/${segments.last}';
          }
          return '/home';
        }
        if (host == 'join' || fullPath.contains('join')) {
          final code = uri.queryParameters['code'];
          return code != null ? '/join-trip?code=$code' : '/join-trip';
        }
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashView(),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashView(),
      ),
      GoRoute(
        path: '/update-required',
        builder: (context, state) => const UpdateRequiredView(),
      ),
      GoRoute(
        path: '/language-select',
        builder: (context, state) {
          final isSettings = state.uri.queryParameters['isSettings'] == 'true';
          return LanguageSelectView(isFromSettings: isSettings);
        },
      ),
      GoRoute(
        path: '/walkthrough',
        builder: (context, state) => const WalkthroughView(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingView(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeView(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsView(),
      ),
      GoRoute(
        path: '/qr-scanner',
        builder: (context, state) => const QrScannerView(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const NirniqProfileView(),
      ),
      GoRoute(
        path: '/payment-methods',
        builder: (context, state) => const PaymentMethodsView(),
      ),
      GoRoute(
        path: '/trip-preview',
        builder: (context, state) => TripPreviewView(code: state.uri.queryParameters['code']),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const MasterSettingsView(),
      ),
      GoRoute(
        path: '/widgets',
        builder: (context, state) => const WidgetGalleryView(),
      ),
      GoRoute(
        path: '/guide',
        builder: (context, state) => const SetupGuideView(),
      ),
      GoRoute(
        path: '/help',
        builder: (context, state) => const HelpFaqView(),
      ),
      GoRoute(
        path: '/privacy-policy',
        builder: (context, state) => const PrivacyPolicyView(),
      ),
      GoRoute(
        path: '/cloud-settings',
        builder: (context, state) => const CloudSettingsView(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminShellView(initialSection: AdminSection.overview),
      ),
      GoRoute(
        path: '/admin/:section',
        builder: (context, state) {
          final sectionParam = state.pathParameters['section'];
          final section = AdminSection.fromRoute(sectionParam);
          return AdminShellView(initialSection: section);
        },
      ),
      GoRoute(
        path: '/create-trip',
        builder: (context, state) => const CreateTripView(),
      ),
      GoRoute(
        path: '/join-trip',
        builder: (context, state) {
          final code = state.uri.queryParameters['code'];
          return JoinTripView(initialCode: code);
        },
      ),
      GoRoute(
        path: '/join',
        builder: (context, state) {
          final code = state.uri.queryParameters['code'];
          return JoinTripView(initialCode: code);
        },
      ),
      GoRoute(
        path: '/trip/:tripId',
        builder: (context, state) {
          final tripId = state.pathParameters['tripId']!;
          final settlementId = state.uri.queryParameters['settlementId'];
          final expenseId = state.uri.queryParameters['expenseId'];
          return TripDetailView(
            tripId: tripId,
            settlementId: settlementId,
            expenseId: expenseId,
          );
        },
        routes: [
          GoRoute(
            path: 'add-expense',
            builder: (context, state) {
              final tripId = state.pathParameters['tripId']!;
              final tabStr = state.uri.queryParameters['tab'];
              final initialTab = tabStr != null ? (int.tryParse(tabStr) ?? 2) : 2;
              final personName = state.uri.queryParameters['person'] ?? state.uri.queryParameters['personName'];
              final memberId = state.uri.queryParameters['memberId'];
              final title = state.uri.queryParameters['title'];
              final amountStr = state.uri.queryParameters['amount'];
              final amountInPaise = amountStr != null ? int.tryParse(amountStr) : null;
              return AddExpenseView(
                tripId: tripId,
                initialTab: initialTab,
                initialPersonName: personName,
                initialMemberId: memberId,
                initialTitle: title,
                initialAmountInPaise: amountInPaise,
              );
            },
          ),
          GoRoute(
            path: 'members',
            builder: (context, state) {
              final tripId = state.pathParameters['tripId']!;
              return TripMembersView(tripId: tripId);
            },
          ),
          GoRoute(
            path: 'memories',
            builder: (context, state) {
              final tripId = state.pathParameters['tripId']!;
              return TripMemoriesView(tripId: tripId);
            },
          ),
        ],
      ),
    ],
  );

  /// Dispatches deep links originating from AppWidgets or external intents directly into Kith.
  static void handleDeepLink(String deepLinkUri) {
    try {
      final cleanUri = deepLinkUri.trim();
      if (cleanUri.isEmpty) return;

      final uri = Uri.parse(cleanUri);
      final host = uri.host.toLowerCase();
      final path = uri.path.toLowerCase();
      final fullPath = (host.isNotEmpty ? '/$host' : '') + path;

      debugPrint('[AppRouter] handleDeepLink: $cleanUri (host: $host, path: $path, full: $fullPath)');

      if (host == 'create-trip' || fullPath.contains('create-trip')) {
        router.push('/create-trip');
      } else if (host == 'expense' || path.contains('expense') || fullPath.contains('expense')) {
        final tripId = uri.queryParameters['tripId'];
        if (tripId != null && tripId.isNotEmpty) {
          router.push('/trip/$tripId/add-expense');
        } else {
          router.go('/home');
        }
      } else if (host == 'widgets' || fullPath.contains('widgets')) {
        router.push('/widgets');
      } else if (host == 'guide' || fullPath.contains('guide')) {
        router.push('/guide');
      } else if (host == 'help' || fullPath.contains('help')) {
        router.push('/help');
      } else if (host == 'cloud-settings' || fullPath.contains('cloud-settings')) {
        router.push('/cloud-settings');
      } else if (host == 'auth' || path.startsWith('/auth') || host == 'onboarding') {
        router.go('/onboarding');
      } else if (host == 'trip' || fullPath.startsWith('/trip')) {
        final segments = uri.pathSegments;
        if (segments.isNotEmpty && segments.last != 'trip') {
          final tripId = segments.last;
          router.push('/trip/$tripId');
        } else {
          router.go('/home');
        }
      } else if (host == 'join' || fullPath.contains('join')) {
        final code = uri.queryParameters['code'];
        router.push('/join-trip${code != null ? '?code=$code' : ''}');
      } else {
        router.go('/home');
      }
    } catch (e) {
      debugPrint('[AppRouter] Error handling deep link: $e');
      router.go('/home');
    }
  }
}
