import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/kith_components.dart';
import '../../../../core/widgets/pill_badge.dart';
import '../../../../data/services/admin/admin_exceptions.dart';
import '../../../../data/services/admin/feature_request_service.dart';
import '../../../../domain/models/admin/admin_models.dart';

/// Feature Request Moderation & Public Roadmap Management Section.
class AdminFeatureRequestsSection extends StatefulWidget {
  const AdminFeatureRequestsSection({super.key});

  @override
  State<AdminFeatureRequestsSection> createState() => _AdminFeatureRequestsSectionState();
}

class _AdminFeatureRequestsSectionState extends State<AdminFeatureRequestsSection> {
  final FeatureRequestService _service = FeatureRequestService();
  List<FeatureRequest> _features = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFeatures();
  }

  Future<void> _loadFeatures() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _service.fetchFeatureRequests();
      setState(() {
        _features = list;
      });
    } on AdminBackendUnavailableException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load public feature requests: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    'Public Feature Roadmap & Upvotes',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Community-driven feature backlog sorted by verified atomic upvotes.',
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
                onPressed: _loadFeatures,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                        ),
                      )
                    : _features.isEmpty
                        ? const Center(
                            child: EmptyStateView(
                              emoji: '💡',
                              title: 'No Public Feature Requests',
                              subtitle: 'No features have been approved for public voting yet. Triage feature requests in the Feedback inbox.',
                            ),
                          )
                        : ListView.separated(
                            itemCount: _features.length,
                            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) {
                              final item = _features[index];
                              return KithSurface(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Row(
                                  children: [
                                    // Upvote Badge Box
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: AppColors.emeraldPrimary.withValues(alpha: isDark ? 0.15 : 0.08),
                                        borderRadius: AppRadius.mdBorder,
                                        border: Border.all(color: AppColors.emeraldPrimary.withValues(alpha: 0.3)),
                                      ),
                                      child: Column(
                                        children: [
                                          const Icon(Icons.arrow_upward_rounded, size: 18, color: AppColors.emeraldLight),
                                          Text(
                                            item.upvoteCount.toString(),
                                            style: const TextStyle(
                                              color: AppColors.emeraldLight,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.title,
                                                  style: TextStyle(
                                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              PillBadge(label: item.status.toUpperCase(), color: AppColors.indigoAccent),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item.description,
                                            style: TextStyle(
                                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                              fontSize: 13,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
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
}
