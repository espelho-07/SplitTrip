import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/create_trip_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../widgets/progress/progress.dart';

class CreateTripView extends StatefulWidget {
  const CreateTripView({super.key});

  @override
  State<CreateTripView> createState() => _CreateTripViewState();
}

class _CreateTripViewState extends State<CreateTripView> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _friendController = TextEditingController();

  static const List<String> _emojis = ['✈️', '🏖️', '🏔️', '🍕', '🚗', '🌴', '🏕️', '🎿', '🎉', '🏠', '☕', '🛳️'];

  @override
  void dispose() {
    _nameController.dispose();
    _friendController.dispose();
    super.dispose();
  }

  void _addFriend() {
    final text = _friendController.text.trim();
    if (text.isNotEmpty) {
      context.read<CreateTripViewModel>().addFriendName(text);
      _friendController.clear();
      HapticHelper.light();
    }
  }

  Future<void> _handleCreate() async {
    final createVm = context.read<CreateTripViewModel>();
    final authVm = context.read<AuthViewModel>();
    final homeVm = context.read<HomeViewModel>();
    final l10n = context.l10n;

    if (createVm.isCreating) return;

    final user = authVm.currentUser;
    if (user == null) return;

    if (!createVm.isValid) {
      HapticHelper.medium();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.createTripErrName),
          backgroundColor: AppColors.negativeRedDark,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    HapticHelper.light();

    final stageNotifier = ValueNotifier<int>(0);
    final stages = [
      ProgressStage(label: l10n.createTripStageInit, description: l10n.createTripStageInitDesc),
      ProgressStage(label: l10n.createTripStageMember, description: l10n.createTripStageMemberDesc),
      ProgressStage(label: l10n.createTripStageSpace, description: l10n.createTripStageSpaceDesc),
      ProgressStage(label: l10n.createTripStageSync, description: l10n.createTripStageSyncDesc),
    ];

    // Show stage-based progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) {
        return ValueListenableBuilder<int>(
          valueListenable: stageNotifier,
          builder: (ctx, activeStage, _) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return Dialog(
              backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: KithStageProgress(
                  title: l10n.createTripProgressTitle,
                  stages: stages,
                  currentStageIndex: activeStage,
                ),
              ),
            );
          },
        );
      },
    );

    // Sequential stage progression
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) stageNotifier.value = 1;
    });
    Future.delayed(const Duration(milliseconds: 550), () {
      if (mounted) stageNotifier.value = 2;
    });
    Future.delayed(const Duration(milliseconds: 850), () {
      if (mounted) stageNotifier.value = 3;
    });

    final trip = await createVm.createTrip(user);

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // Close progress dialog

      if (trip != null) {
        homeVm.addTripLocally(trip, user.id);
        _nameController.clear();
        _friendController.clear();
        createVm.reset();
        context.pushReplacement('/trip/${trip.id}');
        KithSuccessToast.show(context, '${l10n.tripsTitle} ✓');
      } else {
        HapticHelper.error();
        final err = createVm.errorMessage ?? l10n.statusErrorGeneral;
        showDialog(
          context: context,
          builder: (errCtx) => AlertDialog(
            title: Text(l10n.statusErrorGeneral),
            content: Text('$err ${l10n.createTripDiscardDesc}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(errCtx),
                child: Text(l10n.createTripDiscardKeep),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(errCtx);
                  _handleCreate();
                },
                child: Text(l10n.actionRetry),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final createVm = context.watch<CreateTripViewModel>();
    final l10n = context.l10n;
    final hasUnsavedData = createVm.name.trim().isNotEmpty || createVm.friendNames.isNotEmpty;

    return PopScope(
      canPop: !hasUnsavedData,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
            backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
            title: Text(l10n.createTripDiscardTitle, style: AppTypography.titleLarge(isDark: isDark)),
            content: Text(
              l10n.createTripDiscardDesc,
              style: AppTypography.bodyMedium(isDark: isDark),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.createTripDiscardKeep),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.negativeRedDark),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.createTripDiscardConfirm),
              ),
            ],
          ),
        );
        if ((shouldPop ?? false) && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          title: Text(l10n.createTripAppBarTitle),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () async {
              if (hasUnsavedData) {
                final shouldPop = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
                    backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                    title: Text(l10n.createTripDiscardTitle, style: AppTypography.titleLarge(isDark: isDark)),
                    content: Text(
                      l10n.createTripDiscardDesc,
                      style: AppTypography.bodyMedium(isDark: isDark),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(l10n.createTripDiscardKeep),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.negativeRedDark),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(l10n.createTripDiscardConfirm),
                      ),
                    ],
                  ),
                );
                if ((shouldPop ?? false) && context.mounted) {
                  context.pop();
                }
              } else {
                context.pop();
              }
            },
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Trip Preview Banner
                Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppColors.getGradient(createVm.coverGradientIndex),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: AppRadius.xlBorder,
                  ),
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(createVm.emoji, style: const TextStyle(fontSize: 28)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          createVm.name.isEmpty ? l10n.createTripPreviewPlaceholder : createVm.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Trip Name Input
                Text(
                  l10n.createTripNameLabel,
                  style: AppTypography.titleSmall(isDark: isDark),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: l10n.createTripNameHint,
                    prefixIcon: const Icon(Icons.flight_takeoff_rounded, size: 20),
                  ),
                  onChanged: createVm.setName,
                ),

                const SizedBox(height: AppSpacing.lg),

                // Emoji Picker
                Text(
                  l10n.createTripIconLabel,
                  style: AppTypography.titleSmall(isDark: isDark),
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _emojis.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final em = _emojis[index];
                      final isSelected = createVm.emoji == em;
                      return GestureDetector(
                        onTap: () {
                          HapticHelper.selection();
                          createVm.setEmoji(em);
                        },
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.2)
                                : (isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle),
                            borderRadius: AppRadius.mdBorder,
                            border: isSelected
                                ? Border.all(
                                    color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                                    width: 2,
                                  )
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(em, style: const TextStyle(fontSize: 22)),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Gradient Theme Picker
                Text(
                  l10n.createTripGradientLabel,
                  style: AppTypography.titleSmall(isDark: isDark),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(AppColors.tripGradients.length, (index) {
                    final isSelected = createVm.coverGradientIndex == index;
                    final gradient = AppColors.getGradient(index);
                    return GestureDetector(
                      onTap: () {
                        HapticHelper.selection();
                        createVm.setCoverGradientIndex(index);
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: gradient),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: gradient[0].withValues(alpha: 0.5),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Trip Mode Selector
                Text(
                  l10n.createTripModeLabel,
                  style: AppTypography.titleSmall(isDark: isDark),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: _buildTripModeCard(
                        title: l10n.createTripModeSplitOnlyTitle,
                        subtitle: l10n.createTripModeSplitOnlySub,
                        icon: Icons.pie_chart_outline_rounded,
                        mode: 'split_only',
                        createVm: createVm,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTripModeCard(
                        title: l10n.createTripModeJourneyTitle,
                        subtitle: l10n.createTripModeJourneySub,
                        icon: Icons.auto_awesome_rounded,
                        mode: 'split_and_journey',
                        createVm: createVm,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),

                // Currency Selection
                Text(
                  l10n.createTripCurrencyLabel,
                  style: AppTypography.titleSmall(isDark: isDark),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    _buildCurrencyChip('INR', '₹ INR', createVm, isDark),
                    const SizedBox(width: 8),
                    _buildCurrencyChip('USD', '\$ USD', createVm, isDark),
                    const SizedBox(width: 8),
                    _buildCurrencyChip('EUR', '€ EUR', createVm, isDark),
                    const SizedBox(width: 8),
                    _buildCurrencyChip('GBP', '£ GBP', createVm, isDark),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),

                // Add Initial Friends
                Text(
                  l10n.createTripFriendsLabel,
                  style: AppTypography.titleSmall(isDark: isDark),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.createTripFriendsSub,
                  style: AppTypography.bodySmall(isDark: isDark),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _friendController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: l10n.createTripFriendHint,
                          prefixIcon: const Icon(Icons.person_add_outlined, size: 20),
                        ),
                        onSubmitted: (_) => _addFriend(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      onPressed: _addFriend,
                      icon: const Icon(Icons.add_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                        foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
                        padding: const EdgeInsets.all(14),
                      ),
                    ),
                  ],
                ),

                if (createVm.friendNames.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: createVm.friendNames.map((name) {
                      return Chip(
                        label: Text(name),
                        deleteIcon: const Icon(Icons.close_rounded, size: 16),
                        onDeleted: () => createVm.removeFriendName(name),
                        backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.fullBorder),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: AppSpacing.xxl),

                // Create CTA
                AppButton(
                  text: l10n.createTripCta,
                  icon: Icons.check_circle_outline_rounded,
                  isFullWidth: true,
                  isLoading: createVm.isCreating,
                  onPressed: createVm.isValid ? _handleCreate : null,
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrencyChip(String code, String label, CreateTripViewModel createVm, bool isDark) {
    final isSelected = createVm.currencyCode == code;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticHelper.selection();
          createVm.setCurrencyCode(code);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.18)
                : (isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle),
            borderRadius: AppRadius.mdBorder,
            border: Border.all(
              color: isSelected
                  ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                  : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              fontSize: 13,
              color: isSelected
                  ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTripModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String mode,
    required CreateTripViewModel createVm,
    required bool isDark,
  }) {
    final isSelected = createVm.tripMode == mode;
    final activeColor = isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;

    return GestureDetector(
      onTap: () {
        HapticHelper.selection();
        createVm.setTripMode(mode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.12)
              : (isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle),
          borderRadius: AppRadius.mdBorder,
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? activeColor : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                ),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, size: 16, color: activeColor),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 14,
                color: isSelected
                    ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
