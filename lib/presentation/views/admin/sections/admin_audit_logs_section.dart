import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/kith_components.dart';
import '../../../../core/widgets/pill_badge.dart';
import '../../../../domain/models/admin/admin_models.dart';
import '../../../viewmodels/admin/admin_audit_logs_viewmodel.dart';

/// Immutable Administrative Audit Ledger Viewer Section.
class AdminAuditLogsSection extends StatefulWidget {
  const AdminAuditLogsSection({super.key});

  @override
  State<AdminAuditLogsSection> createState() => _AdminAuditLogsSectionState();
}

class _AdminAuditLogsSectionState extends State<AdminAuditLogsSection> {
  final Set<String> _expandedLogIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminAuditLogsViewModel>().fetchLogs(reset: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminAuditLogsViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Immutable Administrative Audit Ledger',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Append-only record of all privileged actions, state transitions, and actor identities.',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  Icons.refresh_rounded,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                onPressed: () => vm.fetchLogs(reset: true),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Expanded(
            child: vm.isLoading && vm.logs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : vm.errorMessage != null
                    ? Center(
                        child: Text(
                          vm.errorMessage!,
                          style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                        ),
                      )
                    : vm.logs.isEmpty
                        ? const Center(
                            child: EmptyStateView(
                              emoji: '🔒',
                              title: 'Audit Ledger is Clean',
                              subtitle: 'No administrative actions have been logged yet.',
                            ),
                          )
                        : ListView.separated(
                            itemCount: vm.logs.length + (vm.hasMore ? 1 : 0),
                            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) {
                              if (index == vm.logs.length) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(AppSpacing.md),
                                    child: KithButton(
                                      label: 'Load More Records',
                                      variant: KithButtonVariant.secondary,
                                      onPressed: () => vm.fetchLogs(),
                                    ),
                                  ),
                                );
                              }

                              final log = vm.logs[index];
                              final isExpanded = _expandedLogIds.contains(log.id);

                              return KithSurface(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                onTap: () {
                                  setState(() {
                                    if (isExpanded) {
                                      _expandedLogIds.remove(log.id);
                                    } else {
                                      _expandedLogIds.add(log.id);
                                    }
                                  });
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            PillBadge(label: log.action.label, color: _getActionColor(log.action)),
                                            const SizedBox(width: AppSpacing.xs),
                                            Text(
                                              '${log.targetType.toUpperCase()}: ${log.targetId}',
                                              style: TextStyle(
                                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          log.createdAt.toLocal().toString().split('.')[0],
                                          style: TextStyle(
                                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Actor: ${log.adminEmail ?? log.adminUserId}',
                                      style: TextStyle(
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                    if (isExpanded && (log.previousState != null || log.newState != null)) ...[
                                      const SizedBox(height: AppSpacing.md),
                                      Container(
                                        padding: const EdgeInsets.all(AppSpacing.sm),
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                                          borderRadius: AppRadius.smBorder,
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (log.previousState != null) ...[
                                              const Text('PREVIOUS STATE:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.negativeRedDark)),
                                              Text(
                                                const JsonEncoder.withIndent('  ').convert(log.previousState),
                                                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                                              ),
                                              const SizedBox(height: 6),
                                            ],
                                            if (log.newState != null) ...[
                                              const Text('NEW STATE:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.positiveGreenDark)),
                                              Text(
                                                const JsonEncoder.withIndent('  ').convert(log.newState),
                                                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Color _getActionColor(AuditAction action) {
    switch (action) {
      case AuditAction.userSuspended:
        return AppColors.negativeRedDark;
      case AuditAction.userUnsuspended:
        return AppColors.positiveGreenDark;
      case AuditAction.roleAssigned:
      case AuditAction.initialOwnerProvisioned:
        return AppColors.emeraldLight;
      case AuditAction.roleRevoked:
        return AppColors.negativeRedLight;
      case AuditAction.announcementCreated:
      case AuditAction.announcementUpdated:
        return AppColors.indigoAccent;
      case AuditAction.announcementExpired:
        return AppColors.amberAccent;
      default:
        return AppColors.tealAccent;
    }
  }
}
