import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'network_connectivity_service.dart';

class ConnectivityGuard {
  final NetworkConnectivityService _connectivityService;

  ConnectivityGuard([NetworkConnectivityService? connectivityService])
      : _connectivityService = connectivityService ?? NetworkConnectivityServiceImpl();

  /// Checks if device is online.
  /// If offline, immediately blocks execution and displays a floating notification alert.
  Future<bool> checkOnlineOrNotify(
    BuildContext context, {
    required String actionName,
    String? customMessage,
  }) async {
    final online = await _connectivityService.isOnline();
    if (!online) {
      if (context.mounted) {
        final message = customMessage ??
            'You need to connect to the internet to $actionName.';
        _showOfflineAlert(context, message);
      }
      return false;
    }
    return true;
  }

  void _showOfflineAlert(BuildContext context, String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppSpacing.md),
        backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgBorder,
          side: const BorderSide(color: Colors.amberAccent, width: 1.2),
        ),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: Colors.amberAccent,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Internet Connection Required',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
