import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/kith_components.dart';
import '../../../../domain/models/admin/admin_role.dart';

/// In-place permission guard that conditionally renders [child] or an access restricted card.
class AdminPermissionGuard extends StatelessWidget {
  final AdminPermission permission;
  final AdminRole? currentRole;
  final Widget child;

  const AdminPermissionGuard({
    super.key,
    required this.permission,
    required this.currentRole,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (currentRole != null && currentRole!.hasPermission(permission)) {
      return child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: KithSurface(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.amberAccent.withValues(alpha: isDark ? 0.15 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_person_outlined,
                  size: 36,
                  color: AppColors.amberAccent,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Permission Restricted',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Your current role (${currentRole?.label ?? "Unassigned"}) does not have privilege to access this module (${permission.name}). Contact a Super Administrator for role assignment.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
