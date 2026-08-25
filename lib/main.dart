import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/app_config.dart';
import 'core/config/supabase_config.dart';
import 'core/network/api_client.dart';
import 'core/network/realtime_client.dart' as kith_realtime;
import 'core/theme/app_theme.dart';
import 'data/repositories/expense_repository.dart';
import 'data/repositories/personal_repository.dart';
import 'data/repositories/trip_repository.dart';
import 'data/repositories/user_repository.dart';
import 'data/services/auth_service.dart';
import 'data/services/local_storage_service.dart';
import 'data/services/sync_service.dart';
import 'presentation/router/app_router.dart';
import 'presentation/viewmodels/add_expense_viewmodel.dart';
import 'presentation/viewmodels/auth_viewmodel.dart';
import 'presentation/viewmodels/create_trip_viewmodel.dart';
import 'presentation/viewmodels/home_viewmodel.dart';
import 'presentation/viewmodels/join_trip_viewmodel.dart';
import 'presentation/viewmodels/personal_expense_viewmodel.dart';
import 'presentation/viewmodels/theme_viewmodel.dart';
import 'presentation/viewmodels/trip_detail_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set immersive system overlays
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  // Initialize Supabase for Google identity verification (signInWithIdToken).
  // The anon key is public — Row Level Security controls data access.
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey, // ignore: deprecated_member_use
    );
  }

  // Initialize Local-First Persistent Storage & Services
  final storageService = await LocalStorageService.init();
  final savedServerUrl = storageService.getSavedServerUrl();
  if (savedServerUrl != null && savedServerUrl.isNotEmpty) {
    AppConfig.setCustomServerUrl(savedServerUrl);
  }

  // Initialize Networking & Realtime Clients
  final apiClient = ApiClient();
  final realtimeClient = kith_realtime.RealtimeClient();
  realtimeClient.connect();

  final syncService = SyncService(storageService);
  final authService = AuthService(
    storage: storageService,
    apiClient: apiClient,
    realtimeClient: realtimeClient,
  );

  // Trigger background offline queue flush
  unawaited(syncService.flushQueue(apiClient));

  // Repositories
  final userRepo = UserRepository(authService: authService);
  final tripRepo = TripRepository(
    storage: storageService,
    syncService: syncService,
    apiClient: apiClient,
    realtimeClient: realtimeClient,
  );
  final expenseRepo = ExpenseRepository(
    storage: storageService,
    syncService: syncService,
    apiClient: apiClient,
    realtimeClient: realtimeClient,
  );
  final personalRepo = PersonalRepository(
    storage: storageService,
    syncService: syncService,
    apiClient: apiClient,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<LocalStorageService>.value(value: storageService),
        Provider<ApiClient>.value(value: apiClient),
        Provider<SyncService>.value(value: syncService),
        Provider<UserRepository>.value(value: userRepo),
        Provider<TripRepository>.value(value: tripRepo),
        Provider<ExpenseRepository>.value(value: expenseRepo),
        Provider<PersonalRepository>.value(value: personalRepo),
        ChangeNotifierProvider(create: (_) => ThemeViewModel(storage: storageService)),
        ChangeNotifierProvider(create: (_) => AuthViewModel(userRepo: userRepo)),
        ChangeNotifierProvider(
          create: (_) => HomeViewModel(tripRepo: tripRepo, expenseRepo: expenseRepo),
        ),
        ChangeNotifierProvider(
          create: (_) => PersonalExpenseViewModel(
            personalRepo: personalRepo,
            tripRepo: tripRepo,
            expenseRepo: expenseRepo,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => TripDetailViewModel(
            tripRepo: tripRepo,
            expenseRepo: expenseRepo,
            realtimeClient: realtimeClient,
          ),
        ),
        ChangeNotifierProvider(create: (_) => CreateTripViewModel(tripRepo: tripRepo)),
        ChangeNotifierProvider(create: (_) => JoinTripViewModel(tripRepo: tripRepo)),
        ChangeNotifierProvider(create: (_) => AddExpenseViewModel(expenseRepo: expenseRepo)),
      ],
      child: const KithApp(),
    ),
  );
}

class KithApp extends StatelessWidget {
  const KithApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeVm = context.watch<ThemeViewModel>();

    return MaterialApp.router(
      title: 'Kith',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeVm.themeMode,
      routerConfig: AppRouter.router,
    );
  }
}
