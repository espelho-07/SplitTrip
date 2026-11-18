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
        return parseDeepLinkToRoute(uriString);
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
          final memberId = state.uri.queryParameters['memberId'] ?? state.uri.queryParameters['claimMemberId'];
          final token = state.uri.queryParameters['token'] ?? state.uri.queryParameters['claimToken'];
          return JoinTripView(
            initialCode: code,
            claimMemberId: memberId,
            claimToken: token,
          );
        },
      ),
      GoRoute(
        path: '/join',
        builder: (context, state) {
          final code = state.uri.queryParameters['code'];
          final memberId = state.uri.queryParameters['memberId'] ?? state.uri.queryParameters['claimMemberId'];
          final token = state.uri.queryParameters['token'] ?? state.uri.queryParameters['claimToken'];
          return JoinTripView(
            initialCode: code,
            claimMemberId: memberId,
            claimToken: token,
          );
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

  static const Set<String> _sensitiveQueryParams = {
    'token',
    'claimtoken',
    'secret',
    'p2p_secret',
    'p2psecret',
    'key',
    's',
    'password',
    'auth',
    'authorization',
    'bearer',
  };

  /// Redacts sensitive query parameters (such as tokens, claim credentials, and secrets)
  /// from deep links and routes for safe logging and diagnostic telemetry.
  static String redactDeepLink(String? uriString) {
    if (uriString == null || uriString.trim().isEmpty) return '';
    final trimmed = uriString.trim();

    try {
      final uri = Uri.parse(trimmed);
      if (!uri.hasQuery) return trimmed;

      final sanitizedParams = <String, String>{};
      for (final entry in uri.queryParameters.entries) {
        final keyLower = entry.key.toLowerCase();
        if (_sensitiveQueryParams.contains(keyLower)) {
          sanitizedParams[entry.key] = '[REDACTED]';
        } else {
          sanitizedParams[entry.key] = entry.value;
        }
      }

      final queryStr = sanitizedParams.entries.map((e) {
        final val = e.value == '[REDACTED]' ? '[REDACTED]' : Uri.encodeQueryComponent(e.value);
        return '${Uri.encodeQueryComponent(e.key)}=$val';
      }).join('&');

      final baseUri = trimmed.split('?').first;
      return '$baseUri?$queryStr';
    } catch (_) {
      final regex = RegExp(r'([?&])([a-zA-Z0-9_\-]+)=([^&]*)');
      return trimmed.replaceAllMapped(regex, (match) {
        final prefix = match.group(1)!;
        final key = match.group(2)!;
        final val = match.group(3)!;
        if (_sensitiveQueryParams.contains(key.toLowerCase())) {
          return '$prefix$key=[REDACTED]';
        }
        return '$prefix$key=$val';
      });
    }
  }

  /// Parses any incoming deep link URI (kith://, https://, or relative /path)
  /// into a canonical in-app GoRouter route, preserving subroutes and query parameters.
  static String? parseDeepLinkToRoute(String deepLinkUri) {
    try {
      final cleanUri = deepLinkUri.trim();
      if (cleanUri.isEmpty) return null;

      // Direct relative routes (e.g. /trip/trip_123?expenseId=exp_456)
      if (cleanUri.startsWith('/') && !cleanUri.startsWith('//')) {
        return cleanUri;
      }

      final uri = Uri.parse(cleanUri);
      final scheme = uri.scheme.toLowerCase();
      if (scheme.isNotEmpty && scheme != 'kith' && scheme != 'https' && scheme != 'http') {
        return null;
      }

      final host = uri.host.toLowerCase();
      final query = uri.hasQuery ? '?${uri.query}' : '';

      // Normalize segments regardless of whether authority is kith.app or direct scheme
      // e.g.:
      // kith://kith.app/trip/t1?expenseId=e1 -> segments: ['trip', 't1']
      // kith://trip/t1?expenseId=e1          -> segments: ['trip', 't1']
      // https://kith.app/join?code=XYZ      -> segments: ['join']
      final List<String> segments;
      if (host == 'kith.app') {
        segments = uri.pathSegments;
      } else if (host.isNotEmpty) {
        segments = [host, ...uri.pathSegments];
      } else {
        segments = uri.pathSegments;
      }

      if (segments.isEmpty) return '/home';

      final firstSegment = segments.first.toLowerCase();

      // 1. Trip Routes (e.g. /trip/123, /trip/123/members, /trip/123/add-expense)
      if (firstSegment == 'trip') {
        if (segments.length >= 2) {
          final tripId = segments[1];
          if (segments.length >= 3) {
            final subroute = segments[2].toLowerCase();
            if (subroute == 'members') {
              return '/trip/$tripId/members$query';
            } else if (subroute == 'add-expense') {
              return '/trip/$tripId/add-expense$query';
            } else if (subroute == 'memories') {
              return '/trip/$tripId/memories$query';
            }
          }
          return '/trip/$tripId$query';
        }
        return '/home';
      }

      // 2. Join Trip / Invitation Links (e.g. kith://join?code=..., https://kith.app/join?...)
      if (firstSegment == 'join' || firstSegment == 'join-trip') {
        final code = uri.queryParameters['code'];
        final memberId = uri.queryParameters['memberId'] ?? uri.queryParameters['claimMemberId'];
        final token = uri.queryParameters['token'] ?? uri.queryParameters['claimToken'];
        final params = <String, String>{};
        if (code != null && code.isNotEmpty) params['code'] = code;
        if (memberId != null && memberId.isNotEmpty) params['memberId'] = memberId;
        if (token != null && token.isNotEmpty) params['token'] = token;
        final joinQuery = params.isNotEmpty ? '?${Uri(queryParameters: params).query}' : '';
        return '/join-trip$joinQuery';
      }

      // 3. Quick Expense Creation
      if (firstSegment == 'expense') {
        final tripId = uri.queryParameters['tripId'];
        if (tripId != null && tripId.isNotEmpty) {
          return '/trip/$tripId/add-expense$query';
        }
        return '/home';
      }

      // 4. Other Standard Screens
      if (firstSegment == 'create-trip') return '/create-trip';
      if (firstSegment == 'widgets') return '/widgets';
      if (firstSegment == 'guide') return '/guide';
      if (firstSegment == 'help') return '/help';
      if (firstSegment == 'cloud-settings') return '/cloud-settings';
      if (firstSegment == 'auth' || firstSegment == 'onboarding') return '/onboarding';
      if (firstSegment == 'notifications') return '/notifications';
      if (firstSegment == 'settings') return '/settings';
      if (firstSegment == 'home') return '/home';

      return '/home';
    } catch (e) {
      debugPrint('[AppRouter] Error parsing deep link ${redactDeepLink(deepLinkUri)}: $e');
      return null;
    }
  }

  /// Dispatches deep links originating from AppWidgets or external intents directly into Kith.
  static void handleDeepLink(String deepLinkUri) {
    try {
      final targetRoute = parseDeepLinkToRoute(deepLinkUri);
      if (targetRoute != null && targetRoute.isNotEmpty) {
        debugPrint('[AppRouter] handleDeepLink: routing to ${redactDeepLink(targetRoute)}');
        router.push(targetRoute);
      }
    } catch (e) {
      debugPrint('[AppRouter] Error handling deep link: $e');
      router.go('/home');
    }
  }
}
