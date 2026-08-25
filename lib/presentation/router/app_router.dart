import 'package:go_router/go_router.dart';
import '../views/add_expense/add_expense_view.dart';
import '../views/cloud/cloud_settings_view.dart';
import '../views/help/help_faq_view.dart';
import '../views/home/home_view.dart';
import '../views/onboarding/onboarding_view.dart';
import '../views/personal/category_breakdown_view.dart';
import '../views/personal/lending_borrowing_view.dart';
import '../views/splash/splash_view.dart';
import '../views/trip/create_trip_view.dart';
import '../views/trip/join_trip_view.dart';
import '../views/trip/trip_detail_view.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashView(),
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
}
