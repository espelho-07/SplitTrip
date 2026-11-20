import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/app_config.dart';
import 'core/config/supabase_config.dart';
import 'core/events/app_event_bus.dart';
import 'core/network/api_client.dart';
import 'core/network/realtime_client.dart' as kith_realtime;
import 'core/localization/app_language.dart';
import 'core/localization/app_localizations.dart';
import 'core/payment/payment_service.dart';
import 'core/services/app_version_service.dart';
import 'core/services/fcm_service.dart';
import 'core/services/kith_widget_service.dart';
import 'core/services/play_in_app_update_service.dart';
import 'core/services/security_lock_service.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/expense_repository.dart';
import 'data/repositories/trip_repository.dart';
import 'data/repositories/user_repository.dart';
import 'data/services/auth_service.dart';
import 'data/services/local_migration_runner.dart';
import 'data/services/local_storage_service.dart';
import 'data/services/p2p_sync_service.dart';
import 'data/services/sync_service.dart';
import 'domain/services/notification_service.dart';
import 'presentation/router/app_router.dart';
import 'presentation/viewmodels/add_expense_viewmodel.dart';
import 'presentation/viewmodels/auth_viewmodel.dart';
import 'presentation/viewmodels/create_trip_viewmodel.dart';
import 'presentation/viewmodels/currency_viewmodel.dart';
import 'presentation/viewmodels/home_viewmodel.dart';
import 'presentation/viewmodels/join_trip_viewmodel.dart';
import 'presentation/viewmodels/locale_viewmodel.dart';
import 'presentation/viewmodels/theme_viewmodel.dart';
import 'presentation/viewmodels/trip_detail_viewmodel.dart';
import 'presentation/viewmodels/version_viewmodel.dart';
import 'presentation/views/security/app_lock_screen.dart';
import 'data/services/admin/admin_audit_service.dart';
import 'data/services/admin/admin_service.dart';
import 'data/services/admin/admin_user_service.dart';
import 'data/services/admin/analytics_service.dart';
import 'data/services/admin/announcement_service.dart';
import 'data/services/admin/feature_request_service.dart';
import 'data/services/admin/feedback_service.dart';
import 'presentation/viewmodels/admin/admin_announcements_viewmodel.dart';
import 'presentation/viewmodels/admin/admin_audit_logs_viewmodel.dart';
import 'presentation/viewmodels/admin/admin_dashboard_viewmodel.dart';
import 'presentation/viewmodels/admin/admin_feedback_viewmodel.dart';
import 'presentation/viewmodels/admin/admin_users_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (required for FCM push notifications)
  await Firebase.initializeApp();

  // Register FCM background handler — must be called before runApp
  FcmService.registerBackgroundHandler();

  // Set immersive system overlays
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  // Initialize Supabase for Google identity verification (signInWithIdToken).
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey, // ignore: deprecated_member_use
    );
  }

  // Initialize Local-First Persistent Storage & Services
  final storageService = await LocalStorageService.init();
  final migrationRunner = LocalMigrationRunner(storageService);
  await migrationRunner.runPendingMigrations();

  final savedServerUrl = storageService.getSavedServerUrl();
  if (savedServerUrl != null && savedServerUrl.isNotEmpty) {
    AppConfig.setCustomServerUrl(savedServerUrl);
  }

  // Initialize Networking & Realtime Clients
  final apiClient = ApiClient();
  final realtimeClient = kith_realtime.RealtimeClient();
  realtimeClient.connect();

  final syncService = SyncService(storageService);
  final p2pSyncService = P2PSyncService(storageService, syncService);
  final authService = AuthService(
    storage: storageService,
    apiClient: apiClient,
    realtimeClient: realtimeClient,
  );

  // Initialize App Version Service & Version Management
  final appVersionService = AppVersionService(
    apiClient: apiClient,
    storage: storageService,
    syncService: syncService,
  );
  final playInAppUpdateService = PlayInAppUpdateService();

  // Initialize Production Security Lock Service
  final securityLockService = SecurityLockService(storageService);

  // Cross-ViewModel reactive event bus (created before repositories)
  final appEventBus = AppEventBus();

  // Repositories
  final userRepo = UserRepository(authService: authService);
  final tripRepo = TripRepository(
    storage: storageService,
    syncService: syncService,
    apiClient: apiClient,
    realtimeClient: realtimeClient,
    eventBus: appEventBus,
  );
  final expenseRepo = ExpenseRepository(
    storage: storageService,
    syncService: syncService,
    apiClient: apiClient,
    realtimeClient: realtimeClient,
    eventBus: appEventBus,
  );

  apiClient.onConnectivityChanged = (isOnline) {
    syncService.handleConnectivityChange(isOnline);
    if (!isOnline) {
      realtimeClient.disconnect();
    } else {
      if (!realtimeClient.isConnected) {
        realtimeClient.connect();
      }
    }
  };

  final widgetService = KithWidgetService(storage: storageService);
  widgetService.onDeepLinkReceived = (deepLinkUri) {
    AppRouter.handleDeepLink(deepLinkUri);
  };

  // Initialize Notification Service
  final notificationService = NotificationService(storageService, realtimeClient);
  await notificationService.init();

  // Initialize Firebase Cloud Messaging service for background/terminated push delivery
  final fcmService = FcmService(
    apiClient: apiClient,
    storage: storageService,
    notificationService: notificationService,
  );
  // Wire up deep-link navigation from notification taps
  fcmService.onNavigate = (route) {
    AppRouter.router.go(route);
  };

  // Defer non-critical background services until after first frame renders to maximize cold-start speed
  WidgetsBinding.instance.addPostFrameCallback((_) {
    syncService.startPeriodicSync(apiClient);
    unawaited(syncService.flushQueue(apiClient));
    unawaited(p2pSyncService.start());
    unawaited(appVersionService.checkVersion());
    unawaited(widgetService.checkInitialDeepLink());

    final currentUser = authService.getCurrentUser();
    if (currentUser != null) {
      final cachedTrips = tripRepo.getCachedTrips();
      unawaited(widgetService.syncSnapshot(
        currentUser: currentUser,
        trips: cachedTrips,
      ));
    } else {
      unawaited(widgetService.syncSnapshot(currentUser: null));
    }

    unawaited(fcmService.init());
  });

  // Initialize Administration Services
  final adminService = AdminService();
  final adminUserService = AdminUserService();
  final feedbackService = FeedbackService();
  final featureRequestService = FeatureRequestService();
  final announcementService = AnnouncementService();
  final adminAuditService = AdminAuditService();
  final analyticsService = AnalyticsService();

  runApp(
    MultiProvider(
      providers: [
        Provider<AppEventBus>.value(value: appEventBus),
        Provider<LocalStorageService>.value(value: storageService),
        Provider<NotificationService>.value(value: notificationService),
        Provider<FcmService>.value(value: fcmService),
        Provider<kith_realtime.RealtimeClient>.value(value: realtimeClient),
        Provider<ApiClient>.value(value: apiClient),
        Provider<SyncService>.value(value: syncService),
        Provider<P2PSyncService>.value(value: p2pSyncService),
        Provider<LocalMigrationRunner>.value(value: migrationRunner),
        Provider<AppVersionService>.value(value: appVersionService),
        Provider<UserRepository>.value(value: userRepo),
        Provider<TripRepository>.value(value: tripRepo),
        Provider<ExpenseRepository>.value(value: expenseRepo),
        ChangeNotifierProvider<SecurityLockService>.value(value: securityLockService),
        ChangeNotifierProvider<KithWidgetService>.value(value: widgetService),
        ChangeNotifierProvider(create: (_) => PaymentService()),
        ChangeNotifierProvider(create: (_) => CurrencyViewModel(storage: storageService)),
        ChangeNotifierProvider(create: (_) => ThemeViewModel(storage: storageService)),
        ChangeNotifierProvider(create: (_) => LocaleViewModel(storage: storageService)),
        ChangeNotifierProvider(create: (_) => AuthViewModel(userRepo: userRepo)),
        ChangeNotifierProvider<PlayInAppUpdateService>.value(value: playInAppUpdateService),
        ChangeNotifierProvider(
          create: (_) => VersionViewModel(
            versionService: appVersionService,
            inAppUpdateService: playInAppUpdateService,
          )..checkForUpdates(),
        ),
        ChangeNotifierProvider(
          create: (_) => HomeViewModel(
            tripRepo: tripRepo,
            expenseRepo: expenseRepo,
            storage: storageService,
            realtimeClient: realtimeClient,
            eventBus: appEventBus,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => TripDetailViewModel(
            tripRepo: tripRepo,
            expenseRepo: expenseRepo,
            storage: storageService,
            realtimeClient: realtimeClient,
          ),
        ),
        ChangeNotifierProvider(create: (_) => CreateTripViewModel(tripRepo: tripRepo)),
        ChangeNotifierProvider(create: (_) => JoinTripViewModel(tripRepo: tripRepo)),
        ChangeNotifierProvider(create: (_) => AddExpenseViewModel(expenseRepo: expenseRepo)),
        Provider<AdminService>.value(value: adminService),
        Provider<AdminUserService>.value(value: adminUserService),
        Provider<FeedbackService>.value(value: feedbackService),
        Provider<FeatureRequestService>.value(value: featureRequestService),
        Provider<AnnouncementService>.value(value: announcementService),
        Provider<AdminAuditService>.value(value: adminAuditService),
        Provider<AnalyticsService>.value(value: analyticsService),
        ChangeNotifierProvider(
          create: (_) => AdminDashboardViewModel(
            adminService: adminService,
            analyticsService: analyticsService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => AdminUsersViewModel(
            userService: adminUserService,
            auditService: adminAuditService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => AdminFeedbackViewModel(
            feedbackService: feedbackService,
            auditService: adminAuditService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => AdminAnnouncementsViewModel(
            announcementService: announcementService,
            auditService: adminAuditService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => AdminAuditLogsViewModel(
            auditService: adminAuditService,
          ),
        ),
      ],
      child: const KithApp(),
    ),
  );
}

class KithApp extends StatefulWidget {
  const KithApp({super.key});

  @override
  State<KithApp> createState() => _KithAppState();
}

class _KithAppState extends State<KithApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      final security = context.read<SecurityLockService>();
      security.lock();
      try {
        final syncService = context.read<SyncService>();
        final apiClient = context.read<ApiClient>();
        unawaited(syncService.flushQueue(apiClient));
      } catch (_) {}
    } else if (state == AppLifecycleState.resumed) {
      final versionVm = context.read<VersionViewModel>();
      versionVm.checkForUpdates();
      try {
        final authVm = context.read<AuthViewModel>();
        unawaited(authVm.validateActiveSession());
      } catch (_) {}
      try {
        final syncService = context.read<SyncService>();
        final apiClient = context.read<ApiClient>();
        unawaited(syncService.flushQueue(apiClient, force: true));
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeVm = context.watch<ThemeViewModel>();
    final localeVm = context.watch<LocaleViewModel>();
    final security = context.watch<SecurityLockService>();

    return MaterialApp.router(
      title: 'Kith',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeVm.themeMode,
      locale: localeVm.locale,
      supportedLocales: AppLanguage.values.map((l) => l.locale).toList(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: AppRouter.router,
      builder: (context, child) {
        return Stack(
          children: [
            ?child,
            if (security.isLocked)
              const AppLockScreen(),
          ],
        );
      },
    );
  }
}
