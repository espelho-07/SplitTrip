import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import 'kith_inline_progress.dart';

enum SyncState {
  synced,
  syncing,
  offline,
  pendingChanges,
  live,
  reconnecting,
}

/// Subtle, non-intrusive status pill for background sync and network connectivity.
class KithSyncIndicator extends StatelessWidget {
  final SyncState state;
  final int pendingCount;
  final VoidCallback? onTap;

  const KithSyncIndicator({
    super.key,
    required this.state,
    this.pendingCount = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    Color badgeBg;
    Color textColor;
    Widget icon;
    String label;

    switch (state) {
      case SyncState.synced:
        badgeBg = AppColors.emeraldPrimary.withValues(alpha: 0.12);
        textColor = isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;
        icon = Icon(Icons.check_circle_outline_rounded, size: 13, color: textColor);
        label = l10n.translate('sync_state_synced');
        if (label == 'sync_state_synced') label = '✓ Synced';
        break;

      case SyncState.syncing:
        badgeBg = AppColors.indigoAccent.withValues(alpha: 0.12);
        textColor = AppColors.indigoAccent;
        icon = KithInlineProgress(size: 11, strokeWidth: 1.8, color: textColor);
        label = l10n.translate('sync_state_syncing');
        if (label == 'sync_state_syncing') label = 'Syncing…';
        break;

      case SyncState.offline:
        badgeBg = Colors.grey.withValues(alpha: 0.15);
        textColor = isDark ? Colors.white60 : Colors.black54;
        icon = Icon(Icons.cloud_off_outlined, size: 13, color: textColor);
        label = l10n.translate('sync_state_offline');
        if (label == 'sync_state_offline') label = 'Offline Ready';
        break;

      case SyncState.pendingChanges:
        badgeBg = Colors.orange.withValues(alpha: 0.15);
        textColor = Colors.orange;
        icon = Icon(Icons.sync_problem_rounded, size: 13, color: textColor);
        if (pendingCount <= 1) {
          label = l10n.translate('sync_state_pending_single');
          if (label == 'sync_state_pending_single') label = '1 change waiting';
        } else {
          final tmpl = l10n.translate('sync_state_pending_multiple');
          label = tmpl == 'sync_state_pending_multiple'
              ? '$pendingCount changes waiting'
              : tmpl.replaceAll('{count}', pendingCount.toString());
        }
        break;

      case SyncState.live:
        badgeBg = AppColors.emeraldPrimary.withValues(alpha: 0.12);
        textColor = isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;
        icon = Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: textColor, shape: BoxShape.circle),
        );
        label = l10n.translate('sync_state_live');
        if (label == 'sync_state_live') label = 'Live';
        break;

      case SyncState.reconnecting:
        badgeBg = Colors.amber.withValues(alpha: 0.15);
        textColor = Colors.amber.shade800;
        icon = KithInlineProgress(size: 11, strokeWidth: 1.8, color: textColor);
        label = l10n.translate('sync_state_reconnecting');
        if (label == 'sync_state_reconnecting') label = 'Reconnecting…';
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.fullBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: badgeBg,
          borderRadius: AppRadius.fullBorder,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

