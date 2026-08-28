import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_feedback_helper.dart';

enum NotificationType { expense, settlement, trip, system }

class AppNotificationItem {
  final String id;
  final String title;
  final String description;
  final String timeAgo;
  final NotificationType type;
  bool isRead;
  final String? route;
  final String? actionLabel;

  AppNotificationItem({
    required this.id,
    required this.title,
    required this.description,
    required this.timeAgo,
    required this.type,
    this.isRead = false,
    this.route,
    this.actionLabel,
  });
}

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

  late List<AppNotificationItem> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = [
      AppNotificationItem(
        id: 'notif_1',
        title: 'Settlement Payment Received',
        description: 'Rohan Sharma recorded a settlement payment of ₹1,200 via UPI for Goa Airbnb.',
        timeAgo: '5m ago',
        type: NotificationType.settlement,
        isRead: false,
        route: '/personal/balances',
        actionLabel: 'View Ledger',
      ),
      AppNotificationItem(
        id: 'notif_2',
        title: 'New Expense Added',
        description: 'Priya Patel added "Seafood Dinner" for ₹2,400 in Goa Holiday.',
        timeAgo: '1h ago',
        type: NotificationType.expense,
        isRead: false,
        actionLabel: 'View Expense',
      ),
      AppNotificationItem(
        id: 'notif_3',
        title: 'New Member Joined Trip',
        description: 'Amit Verma joined "Goa Holiday" using your invite code GOA777.',
        timeAgo: '3h ago',
        type: NotificationType.trip,
        isRead: true,
        actionLabel: 'View Crew',
      ),
      AppNotificationItem(
        id: 'notif_4',
        title: 'Budget Runway Alert',
        description: 'You have used 71% of your August monthly budget. ₹5,750 remaining.',
        timeAgo: '1d ago',
        type: NotificationType.system,
        isRead: true,
        route: '/personal/budgets',
        actionLabel: 'View Budget',
      ),
      AppNotificationItem(
        id: 'notif_5',
        title: 'Trip Invitation Created',
        description: 'Invite code for "Himachal Roadtrip" is ready to share with friends.',
        timeAgo: '2d ago',
        type: NotificationType.trip,
        isRead: true,
        actionLabel: 'Share Code',
      ),
    ];
  }

  void _markAllAsRead() {
    HapticHelper.medium();
    setState(() {
      for (final n in _notifications) {
        n.isRead = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications marked as read ✓'),
        backgroundColor: AppColors.emeraldPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
                  setSheetState(() => _tripAlerts = v);
                  setState(() => _tripAlerts = v);
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
      case NotificationType.system:
        icon = Icons.auto_awesome_rounded;
        iconColor = AppColors.amberAccent;
        iconBg = AppColors.amberAccent.withValues(alpha: 0.15);
        break;
    }

    return GestureDetector(
      onTap: () {
        HapticHelper.light();
        setState(() => item.isRead = true);
        if (item.route != null) {
          context.push(item.route!);
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
              child: Icon(icon, color: iconColor, size: 20),
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
                  if (item.actionLabel != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldLight.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${item.actionLabel!} →',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emeraldLight,
                        ),
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
