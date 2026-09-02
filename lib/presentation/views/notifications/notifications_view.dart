import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../data/services/local_storage_service.dart';
import '../../../domain/models/payment_verification_request.dart';
import '../../../domain/services/notification_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../payment/payment_verification_view.dart';

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  String _selectedFilter = 'all';
  bool _pushEnabled = true;
  bool _expenseAlerts = true;
  bool _settleAlerts = true;
  bool _tripAlerts = true;
  bool _ipoAlerts = true;

  List<AppNotificationItem> _notifications = [];
  String? _loadingNotificationId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
    });
  }

  void _loadNotifications() {
    final storage = context.read<LocalStorageService>();
    final raw = storage.getSavedNotifications();
    setState(() {
      _pushEnabled = storage.getBool('notif_pref_push') ?? true;
      _expenseAlerts = storage.getBool('notif_pref_expense') ?? true;
      _settleAlerts = storage.getBool('notif_pref_settlement') ?? true;
      _tripAlerts = storage.getBool('notif_pref_trip') ?? true;
      _ipoAlerts = storage.getBool('notif_pref_ipo') ?? true;

      _notifications = raw.map((json) => AppNotificationItem.fromJson(json)).toList();
    });

    // Background sync latest notifications & pending settlements from server
    final authVm = Provider.of<AuthViewModel?>(context, listen: false);
    final user = authVm?.currentUser;
    if (user != null) {
      final notifService = Provider.of<NotificationService?>(context, listen: false);
      final apiClient = Provider.of<ApiClient?>(context, listen: false);
      final expenseRepo = Provider.of<ExpenseRepository?>(context, listen: false);
      if (notifService != null && apiClient != null) {
        Future.microtask(() async {
          await notifService.syncServerNotifications(apiClient);
          if (expenseRepo != null) {
            await expenseRepo.syncPendingVerifications(user.id);
          }
          if (mounted) {
            final updatedRaw = storage.getSavedNotifications();
            setState(() {
              _notifications = updatedRaw.map((json) => AppNotificationItem.fromJson(json)).toList();
            });
          }
        });
      }
    }
  }

  Future<void> _markAllAsRead() async {
    HapticHelper.medium();
    final storage = context.read<LocalStorageService>();
    final apiClient = Provider.of<ApiClient?>(context, listen: false);
    await storage.markAllNotificationsAsRead();
    if (apiClient != null) {
      try {
        await apiClient.post('/notifications/read-all', body: {});
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      for (final n in _notifications) {
        n.isRead = true;
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read ✓'),
          backgroundColor: AppColors.emeraldPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showPreferencesSheet(BuildContext context, bool isDark, AppLocalizations l10n) {
    HapticHelper.light();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F1418) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.tune_rounded, size: 20, color: AppColors.emeraldLight),
                  const SizedBox(width: 8),
                  Text(
                    l10n.notificationsSettingsTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildPrefSwitch(
                title: l10n.notificationsPushToggle,
                subtitle: 'Receive real-time push alerts on this device',
                value: _pushEnabled,
                isDark: isDark,
                onChanged: (v) {
                  final storage = context.read<LocalStorageService>();
                  storage.setBool('notif_pref_push', v);
                  setSheetState(() => _pushEnabled = v);
                  setState(() => _pushEnabled = v);
                },
              ),
              _buildPrefSwitch(
                title: l10n.notificationsExpenseToggle,
                subtitle: 'Notify when a friend logs or edits a shared expense',
                value: _expenseAlerts,
                isDark: isDark,
                onChanged: (v) {
                  final storage = context.read<LocalStorageService>();
                  storage.setBool('notif_pref_expense', v);
                  setSheetState(() => _expenseAlerts = v);
                  setState(() => _expenseAlerts = v);
                },
              ),
              _buildPrefSwitch(
                title: l10n.notificationsSettleToggle,
                subtitle: 'Instant alerts when debt is settled via UPI',
                value: _settleAlerts,
                isDark: isDark,
                onChanged: (v) {
                  final storage = context.read<LocalStorageService>();
                  storage.setBool('notif_pref_settlement', v);
                  setSheetState(() => _settleAlerts = v);
                  setState(() => _settleAlerts = v);
                },
              ),
              _buildPrefSwitch(
                title: l10n.notificationsTripToggle,
                subtitle: 'Alerts when members join or itinerary updates',
                value: _tripAlerts,
                isDark: isDark,
                onChanged: (v) {
                  final storage = context.read<LocalStorageService>();
                  storage.setBool('notif_pref_trip', v);
                  setSheetState(() => _tripAlerts = v);
                  setState(() => _tripAlerts = v);
                },
              ),
              _buildPrefSwitch(
                title: 'IPO Reminders & Status Alerts',
                subtitle: 'Timely reminders for IPO opening, closing, allotment & listing',
                value: _ipoAlerts,
                isDark: isDark,
                onChanged: (v) {
                  final storage = context.read<LocalStorageService>();
                  final notifService = context.read<NotificationService>();
                  storage.setBool('notif_pref_ipo', v);
                  notifService.setPreference(NotificationCategory.ipoActivity, v);
                  setSheetState(() => _ipoAlerts = v);
                  setState(() => _ipoAlerts = v);
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrefSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required bool isDark,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: AppColors.emeraldLight,
            onChanged: (v) {
              HapticHelper.selection();
              onChanged(v);
            },
          ),
        ],
      ),
    );
  }

  List<AppNotificationItem> get _filteredList {
    if (_selectedFilter == 'all') return _notifications;
    if (_selectedFilter == 'expenses') {
      return _notifications.where((n) => n.type == NotificationType.expense).toList();
    }
    if (_selectedFilter == 'settlements') {
      return _notifications.where((n) => n.type == NotificationType.settlement).toList();
    }
    if (_selectedFilter == 'trips') {
      return _notifications.where((n) => n.type == NotificationType.trip).toList();
    }
    if (_selectedFilter == 'ipos') {
      return _notifications.where((n) => n.type == NotificationType.ipo).toList();
    }
    return _notifications;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final items = _filteredList;
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(
              l10n.notificationsTitle,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.emeraldLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded, size: 20),
            tooltip: l10n.notificationsMarkRead,
            onPressed: _notifications.isEmpty ? null : _markAllAsRead,
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 20),
            tooltip: l10n.notificationsSettingsTitle,
            onPressed: () => _showPreferencesSheet(context, isDark, l10n),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 44,
            margin: const EdgeInsets.symmetric(vertical: 6.0),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              children: [
                _buildFilterChip('all', l10n.notificationsTabAll, isDark),
                _buildFilterChip('expenses', l10n.notificationsTabExpenses, isDark),
                _buildFilterChip('settlements', l10n.notificationsTabSettlements, isDark),
                _buildFilterChip('trips', l10n.notificationsTabTrips, isDark),
                _buildFilterChip('ipos', 'IPOs', isDark),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? _buildEmptyState(isDark, l10n)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    physics: const BouncingScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) => _buildNotificationCard(items[idx], isDark),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, bool isDark) {
    final isSelected = _selectedFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: () {
          HapticHelper.selection();
          setState(() => _selectedFilter = key);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.emeraldLight
                : (isDark ? const Color(0xFF141A20) : const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : (isDark ? AppColors.darkTextSecondary : const Color(0xFF475569)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(AppNotificationItem item, bool isDark) {
    IconData icon;
    Color iconColor;
    Color iconBg;

    switch (item.type) {
      case NotificationType.settlement:
        icon = Icons.payments_rounded;
        iconColor = AppColors.positiveGreenLight;
        iconBg = AppColors.positiveGreenLight.withValues(alpha: 0.15);
        break;
      case NotificationType.expense:
        icon = Icons.receipt_long_rounded;
        iconColor = AppColors.emeraldLight;
        iconBg = AppColors.emeraldLight.withValues(alpha: 0.15);
        break;
      case NotificationType.trip:
        icon = Icons.flight_takeoff_rounded;
        iconColor = AppColors.indigoAccent;
        iconBg = AppColors.indigoAccent.withValues(alpha: 0.15);
        break;
      case NotificationType.ipo:
        icon = Icons.show_chart_rounded;
        iconColor = isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;
        iconBg = (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.15);
        break;
      case NotificationType.system:
        icon = Icons.auto_awesome_rounded;
        iconColor = AppColors.amberAccent;
        iconBg = AppColors.amberAccent.withValues(alpha: 0.15);
        break;
    }

    final isLoadingThis = _loadingNotificationId == item.id;

    return GestureDetector(
      onTap: () async {
        HapticHelper.light();
        setState(() {
          _loadingNotificationId = item.id;
          item.isRead = true;
        });

        final storage = context.read<LocalStorageService>();
        storage.markNotificationAsRead(item.id);

        try {
          if (item.type == NotificationType.settlement) {
            final authVm = Provider.of<AuthViewModel?>(context, listen: false);
            final currentUserId = authVm?.currentUser?.id;
            if (currentUserId != null) {
              var pending = storage.getPendingVerificationsForReceiver(userId: currentUserId);
              if (pending.isEmpty) {
                final expenseRepo = Provider.of<ExpenseRepository?>(context, listen: false);
                if (expenseRepo != null) {
                  await expenseRepo.syncPendingVerifications(currentUserId);
                  pending = storage.getPendingVerificationsForReceiver(userId: currentUserId);
                }
              }
              if (pending.isNotEmpty) {
                final req = PaymentVerificationRequest.fromJson(pending.first);
                if (mounted) {
                  setState(() => _loadingNotificationId = null);
                  await PaymentVerificationView.show(context, request: req);
                  _loadNotifications();
                  return;
                }
              }
            }
          }

          if (item.route != null && item.route!.isNotEmpty && mounted) {
            final targetRoute = item.route!;
            setState(() => _loadingNotificationId = null);
            await context.push(targetRoute);
            if (mounted) {
              _loadNotifications();
            }
          }
        } finally {
          if (mounted) {
            setState(() => _loadingNotificationId = null);
          }
        }
      },

      child: Container(
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: isDark
              ? (item.isRead ? const Color(0xFF0F1418) : const Color(0xFF141D24))
              : (item.isRead ? Colors.white : const Color(0xFFF0FDF4)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? (item.isRead ? AppColors.darkBorderSubtle : AppColors.emeraldLight.withValues(alpha: 0.3))
                : (item.isRead ? AppColors.lightBorderSubtle : AppColors.emeraldLight.withValues(alpha: 0.4)),
            width: item.isRead ? 1 : 1.4,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: isLoadingThis
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.emeraldLight,
                      ),
                    )
                  : Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Text(
                        item.timeAgo,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475569),
                    ),
                  ),
                  if (item.actionLabel != null || isLoadingThis) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldLight.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLoadingThis) ...[
                            const SizedBox(
                              width: 11,
                              height: 11,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                color: AppColors.emeraldLight,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Opening...',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.emeraldLight,
                              ),
                            ),
                          ] else ...[
                            Text(
                              '${item.actionLabel!} →',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.emeraldLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!item.isRead) ...[
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.emeraldLight,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.emeraldLight.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.notifications_off_rounded, size: 36, color: AppColors.emeraldLight),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.notificationsEmptyTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.notificationsEmptyDesc,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
