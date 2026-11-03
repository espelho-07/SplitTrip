import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../domain/enums/trip_lifecycle.dart';
import '../../domain/models/guest_user.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/balance_summary.dart';
import '../../data/services/local_storage_service.dart';

/// Data transfer snapshot that is serialized into SharedPreferences for native AppWidgets.
class KithWidgetSnapshot {
  final int spentPaise;
  final int budgetPaise;
  final int remainingPaise;
  final int dailyRunwayPaise;
  final String comparisonText;
  final String monthName;
  final int moneyOwedTotalPaise;
  final List<Map<String, dynamic>> topDebts;
  final int moneyYouOweTotalPaise;
  final List<Map<String, dynamic>> topYouOwe;
  final String activeTripId;
  final String activeTripTitle;
  final String activeTripEmoji;
  final int activeTripSpentPaise;
  final int activeTripUserBalancePaise;
  final int activeTripMemberCount;
  final String smartHeadline;
  final String smartSubtext;
  final String smartActionLabel;
  final String smartActionDeepLink;
  final bool isPrivacyMode;
  final bool isSignedOut;
  final String localeCode;
  final int lastUpdatedMillis;

  const KithWidgetSnapshot({
    required this.spentPaise,
    required this.budgetPaise,
    required this.remainingPaise,
    required this.dailyRunwayPaise,
    required this.comparisonText,
    required this.monthName,
    required this.moneyOwedTotalPaise,
    required this.topDebts,
    required this.moneyYouOweTotalPaise,
    required this.topYouOwe,
    required this.activeTripId,
    required this.activeTripTitle,
    required this.activeTripEmoji,
    required this.activeTripSpentPaise,
    required this.activeTripUserBalancePaise,
    required this.activeTripMemberCount,
    required this.smartHeadline,
    required this.smartSubtext,
    required this.smartActionLabel,
    required this.smartActionDeepLink,
    required this.isPrivacyMode,
    required this.isSignedOut,
    required this.localeCode,
    required this.lastUpdatedMillis,
  });

  Map<String, dynamic> toJson() => {
        'spentPaise': spentPaise,
        'budgetPaise': budgetPaise,
        'remainingPaise': remainingPaise,
        'dailyRunwayPaise': dailyRunwayPaise,
        'comparisonText': comparisonText,
        'monthName': monthName,
        'moneyOwedTotalPaise': moneyOwedTotalPaise,
        'topDebts': topDebts,
        'moneyYouOweTotalPaise': moneyYouOweTotalPaise,
        'topYouOwe': topYouOwe,
        'activeTripId': activeTripId,
        'activeTripTitle': activeTripTitle,
        'activeTripEmoji': activeTripEmoji,
        'activeTripSpentPaise': activeTripSpentPaise,
        'activeTripUserBalancePaise': activeTripUserBalancePaise,
        'activeTripMemberCount': activeTripMemberCount,
        'smartHeadline': smartHeadline,
        'smartSubtext': smartSubtext,
        'smartActionLabel': smartActionLabel,
        'smartActionDeepLink': smartActionDeepLink,
        'isPrivacyMode': isPrivacyMode,
        'isSignedOut': isSignedOut,
        'localeCode': localeCode,
        'lastUpdatedMillis': lastUpdatedMillis,
      };

  factory KithWidgetSnapshot.fromJson(Map<String, dynamic> json) =>
      KithWidgetSnapshot(
        spentPaise: (json['spentPaise'] as num?)?.toInt() ?? 0,
        budgetPaise: (json['budgetPaise'] as num?)?.toInt() ?? 0,
        remainingPaise: (json['remainingPaise'] as num?)?.toInt() ?? 0,
        dailyRunwayPaise: (json['dailyRunwayPaise'] as num?)?.toInt() ?? 0,
        comparisonText: json['comparisonText'] as String? ?? 'Spent this month',
        monthName: json['monthName'] as String? ?? 'This Month',
        moneyOwedTotalPaise: (json['moneyOwedTotalPaise'] as num?)?.toInt() ?? 0,
        topDebts: (json['topDebts'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        moneyYouOweTotalPaise:
            (json['moneyYouOweTotalPaise'] as num?)?.toInt() ?? 0,
        topYouOwe: (json['topYouOwe'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        activeTripId: json['activeTripId'] as String? ?? '',
        activeTripTitle: json['activeTripTitle'] as String? ?? '',
        activeTripEmoji: json['activeTripEmoji'] as String? ?? '✈️',
        activeTripSpentPaise:
            (json['activeTripSpentPaise'] as num?)?.toInt() ?? 0,
        activeTripUserBalancePaise:
            (json['activeTripUserBalancePaise'] as num?)?.toInt() ?? 0,
        activeTripMemberCount:
            (json['activeTripMemberCount'] as num?)?.toInt() ?? 0,
        smartHeadline: json['smartHeadline'] as String? ?? 'Everything is up to date ✓',
        smartSubtext: json['smartSubtext'] as String? ?? 'All settled',
        smartActionLabel: json['smartActionLabel'] as String? ?? 'Open Kith',
        smartActionDeepLink:
            json['smartActionDeepLink'] as String? ?? 'kith://home',
        isPrivacyMode: json['isPrivacyMode'] as bool? ?? false,
        isSignedOut: json['isSignedOut'] as bool? ?? false,
        localeCode: json['localeCode'] as String? ?? 'en',
        lastUpdatedMillis: (json['lastUpdatedMillis'] as num?)?.toInt() ?? 0,
      );

  factory KithWidgetSnapshot.signedOut() => KithWidgetSnapshot(
        spentPaise: 0,
        budgetPaise: 0,
        remainingPaise: 0,
        dailyRunwayPaise: 0,
        comparisonText: 'Sign in to see spending',
        monthName: 'Month',
        moneyOwedTotalPaise: 0,
        topDebts: const [],
        moneyYouOweTotalPaise: 0,
        topYouOwe: const [],
        activeTripId: '',
        activeTripTitle: '',
        activeTripEmoji: '✈️',
        activeTripSpentPaise: 0,
        activeTripUserBalancePaise: 0,
        activeTripMemberCount: 0,
        smartHeadline: 'Welcome to Kith',
        smartSubtext: 'Sign in to sync your expenses and trips',
        smartActionLabel: 'Sign In',
        smartActionDeepLink: 'kith://auth',
        isPrivacyMode: false,
        isSignedOut: true,
        localeCode: 'en',
        lastUpdatedMillis: DateTime.now().millisecondsSinceEpoch,
      );
}

/// Service managing bidirectional communication between Flutter and Android AppWidgets.
class KithWidgetService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('com.nirniq.kith/widgets');
  static const String _prefKey = 'kith_widget_snapshot';
  static const String _privacyKey = 'kith_widget_privacy_mode';

  final LocalStorageService storage;
  bool _isPrivacyMode = false;
  Function(String deepLink)? onDeepLinkReceived;

  KithWidgetService({required this.storage}) {
    _isPrivacyMode = storage.getBool(_privacyKey) ?? false;
    _initChannel();
  }

  bool get isPrivacyMode => _isPrivacyMode;

  void _initChannel() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final deepLink = call.arguments as String?;
        if (deepLink != null && onDeepLinkReceived != null) {
          onDeepLinkReceived!(deepLink);
        }
      }
    });
    // Check initial deep link on cold launch
    checkInitialDeepLink();
  }

  Future<void> checkInitialDeepLink() async {
    try {
      final initialLink = await _channel.invokeMethod<String>('getInitialDeepLink');
      if (initialLink != null && initialLink.isNotEmpty && onDeepLinkReceived != null) {
        onDeepLinkReceived!(initialLink);
      }
    } catch (_) {}
  }

  Future<void> setPrivacyMode(bool enabled) async {
    if (_isPrivacyMode == enabled) return;
    _isPrivacyMode = enabled;
    await storage.setBool(_privacyKey, enabled);
    notifyListeners();
  }

  Future<bool> isPinningSupported() async {
    try {
      final supported = await _channel.invokeMethod<bool>('isPinningSupported');
      return supported ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPinWidget(String widgetType) async {
    try {
      final success = await _channel.invokeMethod<bool>(
        'requestPinWidget',
        {'type': widgetType},
      );
      return success ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Builds a complete snapshot of current financial data and syncs with Android AppWidgets.
  Future<void> syncSnapshot({
    GuestUser? currentUser,
    List<Trip>? trips,
    Map<String, BalanceSummary>? tripBalances,
    String localeCode = 'en',
  }) async {
    if (currentUser == null) {
      final snapshot = KithWidgetSnapshot.signedOut();
      await _persistAndNotify(snapshot);
      return;
    }

    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final monthName = (now.month >= 1 && now.month <= 12) ? months[now.month - 1] : 'This Month';

    // 1. Trip Expenses Calculation
    int totalSpentPaise = 0;
    if (tripBalances != null) {
      for (final summary in tripBalances.values) {
        totalSpentPaise += summary.totalTripSpentInPaise;
      }
    }

    String comparisonText = 'Trip expenses';

    // 2. Budget & Runway (Trip only defaults)
    const budgetPaise = 0;
    const remainingPaise = 0;
    const dailyRunwayPaise = 0;

    // 3. Debts & Balances across Trips
    int owedTotalPaise = 0;
    int youOweTotalPaise = 0;
    if (tripBalances != null) {
      for (final summary in tripBalances.values) {
        final net = summary.currentUserNetBalanceInPaise;
        if (net > 0) {
          owedTotalPaise += net;
        } else if (net < 0) {
          youOweTotalPaise += net.abs();
        }
      }
    }

    final topDebtsList = <Map<String, dynamic>>[];
    final topYouOweList = <Map<String, dynamic>>[];

    // 4. Active Trip
    String activeTripId = '';
    String activeTripTitle = '';
    String activeTripEmoji = '✈️';
    int activeTripSpentPaise = 0;
    int activeTripUserBalancePaise = 0;
    int activeTripMemberCount = 0;

    if (trips != null && trips.isNotEmpty) {
      final activeTrip = trips.firstWhere(
        (t) => t.lifecycleState == TripLifecycle.active,
        orElse: () => trips.first,
      );
      activeTripId = activeTrip.id;
      activeTripTitle = activeTrip.name;
      activeTripEmoji = activeTrip.emoji;
      activeTripMemberCount = activeTrip.members.length;

      final summary = tripBalances?[activeTrip.id];
      if (summary != null) {
        activeTripUserBalancePaise = summary.currentUserNetBalanceInPaise;
        activeTripSpentPaise = summary.totalTripSpentInPaise;
      }
    }

    // 5. Smart Kith Intelligence Ranking
    String smartHeadline = 'Everything is up to date ✓';
    String smartSubtext = 'Plan your next adventure with friends';
    String smartActionLabel = 'New Trip';
    String smartActionDeepLink = 'kith://create-trip';

    if (activeTripId.isNotEmpty && activeTripUserBalancePaise.abs() > 0) {
      final balRupees = (activeTripUserBalancePaise.abs() / 100).toStringAsFixed(0);
      if (activeTripUserBalancePaise > 0) {
        smartHeadline = "You're owed ₹$balRupees in $activeTripTitle";
        smartSubtext = 'Unsettled balances pending from friends';
      } else {
        smartHeadline = 'You owe ₹$balRupees in $activeTripTitle';
        smartSubtext = 'Settle up with group members';
      }
      smartActionLabel = 'Settle';
      smartActionDeepLink = 'kith://trip/$activeTripId';
    } else if (activeTripId.isNotEmpty) {
      smartHeadline = '$activeTripTitle: Everything settled ✓';
      smartSubtext = '$activeTripMemberCount members · Tap to view trip';
      smartActionLabel = 'View Trip';
      smartActionDeepLink = 'kith://trip/$activeTripId';
    }

    final snapshot = KithWidgetSnapshot(
      spentPaise: totalSpentPaise,
      budgetPaise: budgetPaise,
      remainingPaise: remainingPaise,
      dailyRunwayPaise: dailyRunwayPaise,
      comparisonText: comparisonText,
      monthName: monthName,
      moneyOwedTotalPaise: owedTotalPaise > 0 ? owedTotalPaise : 0,
      topDebts: topDebtsList,
      moneyYouOweTotalPaise: youOweTotalPaise > 0 ? youOweTotalPaise : 0,
      topYouOwe: topYouOweList,
      activeTripId: activeTripId,
      activeTripTitle: activeTripTitle,
      activeTripEmoji: activeTripEmoji,
      activeTripSpentPaise: activeTripSpentPaise,
      activeTripUserBalancePaise: activeTripUserBalancePaise,
      activeTripMemberCount: activeTripMemberCount,
      smartHeadline: smartHeadline,
      smartSubtext: smartSubtext,
      smartActionLabel: smartActionLabel,
      smartActionDeepLink: smartActionDeepLink,
      isPrivacyMode: _isPrivacyMode,
      isSignedOut: false,
      localeCode: localeCode,
      lastUpdatedMillis: now.millisecondsSinceEpoch,
    );

    await _persistAndNotify(snapshot);
  }

  Future<void> _persistAndNotify(KithWidgetSnapshot snapshot) async {
    try {
      final jsonStr = jsonEncode(snapshot.toJson());
      await storage.setString(_prefKey, jsonStr);
      await _channel.invokeMethod('updateWidgets');
    } catch (e) {
      debugPrint('[KithWidgetService] Widget update failed: $e');
    }
  }
}
