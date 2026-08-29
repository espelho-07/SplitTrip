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
import '../views/personal/category_breakdown_view.dart';
import '../views/personal/budgets_view.dart';
import '../views/personal/spend_analytics_view.dart';
import '../views/personal/balances_overall_view.dart';
import '../views/trip/settle_up_view.dart';
import '../views/personal/lending_borrowing_view.dart';
import '../views/personal/widgets/add_personal_expense_sheet.dart';
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

        // If it's an expense action, schedule the bottom sheet and redirect to /home
        if (host == 'expense' || path.contains('expense') || fullPath.contains('expense')) {
          final action = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : host;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final ctx = navigatorKey.currentContext;
            if (ctx != null) {
              if (action == 'voice' || uri.queryParameters['mode'] == 'voice') {
                AddPersonalExpenseSheet.show(ctx, initialVoice: true);
              } else if (action == 'receipt' || uri.queryParameters['mode'] == 'receipt') {
                AddPersonalExpenseSheet.show(ctx);
              } else {
                final amount = uri.queryParameters['amount'];
                AddPersonalExpenseSheet.show(ctx, initialAmount: amount);
              }
            }
          });
          return '/home';
        }

        if (host == 'create-trip' || fullPath.contains('create-trip')) {
          return '/create-trip';
        }
        if (host == 'debts' || fullPath.contains('debts')) {
          return '/personal/debts';
        }
        if (host == 'categories' || fullPath.contains('categories')) {
          return '/personal/categories';
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
        path: '/personal/debts',
        builder: (context, state) => const LendingBorrowingView(),
      ),
      GoRoute(
        path: '/add-expense',
        builder: (context, state) {
          final tabStr = state.uri.queryParameters['tab'];
          final initialTab = tabStr != null ? (int.tryParse(tabStr) ?? 2) : 2;
          return AddExpenseView(
            tripId: state.uri.queryParameters['tripId'] ?? '',
            initialTab: initialTab,
          );
        },
      ),
      GoRoute(
        path: '/budgets',
        builder: (context, state) => const BudgetsView(),
      ),
      GoRoute(
        path: '/balances',
        builder: (context, state) => const BalancesOverallView(),
      ),
      GoRoute(
        path: '/settle-up',
        builder: (context, state) => const SettleUpView(),
      ),
      GoRoute(
        path: '/analytics',
        builder: (context, state) => const SpendAnalyticsView(),
      ),
      GoRoute(
        path: '/personal/categories',
        builder: (context, state) => const CategoryBreakdownView(),
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
          return TripDetailView(tripId: tripId);
        },
        routes: [
          GoRoute(
            path: 'add-expense',
            builder: (context, state) {
              final tripId = state.pathParameters['tripId']!;
              final tabStr = state.uri.queryParameters['tab'];
              final initialTab = tabStr != null ? (int.tryParse(tabStr) ?? 2) : 2;
              return AddExpenseView(
                tripId: tripId,
                initialTab: initialTab,
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

      if (host == 'expense' || path.contains('expense') || fullPath.contains('expense')) {
        final action = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : host;
        router.go('/home');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = navigatorKey.currentContext;
          if (ctx != null) {
            if (action == 'voice' || uri.queryParameters['mode'] == 'voice') {
              AddPersonalExpenseSheet.show(ctx, initialVoice: true);
            } else if (action == 'receipt' || uri.queryParameters['mode'] == 'receipt') {
              AddPersonalExpenseSheet.show(ctx);
            } else {
              final amount = uri.queryParameters['amount'];
              AddPersonalExpenseSheet.show(ctx, initialAmount: amount);
            }
          }
        });
      } else if (host == 'create-trip' || fullPath.contains('create-trip')) {
        router.push('/create-trip');
      } else if (host == 'debts' || fullPath.contains('debts')) {
        router.push('/personal/debts');
      } else if (host == 'categories' || fullPath.contains('categories')) {
        router.push('/personal/categories');
      } else if (host == 'budget' || path.startsWith('/budget')) {
        router.go('/home');
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
