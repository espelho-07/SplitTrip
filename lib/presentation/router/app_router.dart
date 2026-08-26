import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../views/add_expense/add_expense_view.dart';
import '../views/cloud/cloud_settings_view.dart';
import '../views/guide/setup_guide_view.dart';
import '../views/help/help_faq_view.dart';
import '../views/home/home_view.dart';
import '../views/language/language_select_view.dart';
import '../views/onboarding/onboarding_view.dart';
import '../views/personal/category_breakdown_view.dart';
import '../views/personal/lending_borrowing_view.dart';
import '../views/personal/widgets/add_personal_expense_sheet.dart';
import '../views/splash/splash_view.dart';
import '../views/trip/create_trip_view.dart';
import '../views/trip/join_trip_view.dart';
import '../views/trip/trip_detail_view.dart';
import '../views/widgets/widget_gallery_view.dart';

class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashView(),
      ),
      GoRoute(
        path: '/language-select',
        builder: (context, state) {
          final isSettings = state.uri.queryParameters['isSettings'] == 'true';
          return LanguageSelectView(isFromSettings: isSettings);
        },
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
        path: '/cloud-settings',
        builder: (context, state) => const CloudSettingsView(),
      ),
      GoRoute(
        path: '/personal/debts',
        builder: (context, state) => const LendingBorrowingView(),
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
              return AddExpenseView(tripId: tripId);
            },
          ),
        ],
      ),
    ],
  );

  /// Dispatches deep links originating from AppWidgets or external intents directly into Kith.
  static void handleDeepLink(String deepLinkUri) {
    try {
      final uri = Uri.parse(deepLinkUri);
      final path = uri.path;
      final host = uri.host;

      if (host == 'expense' || path.startsWith('/expense')) {
        final action = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : host;
        router.go('/home');
        final ctx = navigatorKey.currentContext;
        if (ctx != null) {
          if (action == 'voice') {
            AddPersonalExpenseSheet.show(ctx, initialVoice: true);
          } else if (action == 'receipt') {
            AddPersonalExpenseSheet.show(ctx);
          } else {
            final amount = uri.queryParameters['amount'];
            AddPersonalExpenseSheet.show(ctx, initialAmount: amount);
          }
        }
      } else if (host == 'budget' || path.startsWith('/budget')) {
        router.go('/home');
      } else if (host == 'personal' || path.startsWith('/personal')) {
        if (path.contains('debts')) {
          router.push('/personal/debts');
        } else {
          router.go('/home');
        }
      } else if (host == 'trips' || path.startsWith('/trips')) {
        router.go('/home');
      } else if (host == 'trip' || path.startsWith('/trip')) {
        final segments = uri.pathSegments;
        if (segments.isNotEmpty) {
          final tripId = segments.last;
          router.push('/trip/$tripId');
        } else {
          router.go('/home');
        }
      } else if (host == 'create-trip' || path.startsWith('/create-trip')) {
        router.push('/create-trip');
      } else if (host == 'widgets' || path.startsWith('/widgets')) {
        router.push('/widgets');
      } else if (host == 'auth' || path.startsWith('/auth')) {
        router.go('/onboarding');
      } else if (host == 'join' || path.startsWith('/join')) {
        final code = uri.queryParameters['code'];
        router.push('/join-trip${code != null ? '?code=$code' : ''}');
      } else {
        router.go('/home');
      }
    } catch (e) {
      debugPrint('[AppRouter] Error handling deep link: $e');
    }
  }
}
