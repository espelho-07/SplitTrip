import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/kith_components.dart';
import '../../../core/widgets/trip_cover_background.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/create_trip_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../widgets/progress/progress.dart';

/// Energetic, rich, and visually refined Create Trip Experience for Kith.
/// Features interactive live hero preview, mode selection, gradient palette, and crew builder,
/// with compact small-to-medium card sizing for optimal ergonomics.
class CreateTripView extends StatefulWidget {
  const CreateTripView({super.key});

  @override
  State<CreateTripView> createState() => _CreateTripViewState();
}

class _CreateTripViewState extends State<CreateTripView> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _friendController = TextEditingController();
  bool _showManualFriends = false;
  bool _showEmojiTray = false;

  List<Map<String, String>> _getTripIdeas(AppLocalizations l10n) => [
    {'name': l10n.translate('trip_idea_goa'), 'emoji': '🏖️', 'gradient': '0'},
    {'name': l10n.translate('trip_idea_manali'), 'emoji': '🏔️', 'gradient': '1'},
    {'name': l10n.translate('trip_idea_weekend'), 'emoji': '🍕', 'gradient': '2'},
    {'name': l10n.translate('trip_idea_roadtrip'), 'emoji': '🚗', 'gradient': '3'},
    {'name': l10n.translate('trip_idea_birthday'), 'emoji': '🎉', 'gradient': '4'},
    {'name': l10n.translate('trip_idea_camping'), 'emoji': '🏕️', 'gradient': '5'},
    {'name': l10n.translate('trip_idea_euro'), 'emoji': '✈️', 'gradient': '0'},
  ];

  static const List<String> _emojis = [
    '✈️', '🏖️', '🏔️', '🍕', '🚗', '🌴',
    '🏕️', '🎿', '🎉', '🏠', '☕', '🛳️',
    '🌲', '🧳', '🛵', '🎸', '🍹', '🏰',
    '🌊', '🚴', '⛺', '🎳', '🍔', '🗼'
  ];

  static const List<Map<String, String>> _currencies = [
    {'code': 'INR', 'symbol': '₹', 'label': '₹ INR'},
    {'code': 'USD', 'symbol': r'$', 'label': r'$ USD'},
    {'code': 'EUR', 'symbol': '€', 'label': '€ EUR'},
    {'code': 'GBP', 'symbol': '£', 'label': '£ GBP'},
    {'code': 'JPY', 'symbol': '¥', 'label': '¥ JPY'},
    {'code': 'AED', 'symbol': 'AED', 'label': 'AED'},
  ];



  @override
  void dispose() {
    _nameController.dispose();
    _friendController.dispose();
    super.dispose();
  }

  void _applyTripIdea(Map<String, String> idea) {
    HapticHelper.light();
    final name = idea['name']!;
    final emoji = idea['emoji']!;
    final gradIndex = int.tryParse(idea['gradient'] ?? '0') ?? 0;

    _nameController.text = name;
    final createVm = context.read<CreateTripViewModel>();
    createVm.setName(name);
    createVm.setEmoji(emoji);
    createVm.setCoverGradientIndex(gradIndex);
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
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final stages = [
      ProgressStage(label: l10n.createTripStageInit, description: l10n.createTripStageInitDesc),
      ProgressStage(label: l10n.createTripStageMember, description: l10n.createTripStageMemberDesc),
      ProgressStage(label: l10n.createTripStageSpace, description: l10n.createTripStageSpaceDesc),
      ProgressStage(label: l10n.createTripStageSync, description: l10n.createTripStageSyncDesc),
    ];

    final stageNotifier = ValueNotifier<int>(0);
    final isDarkNow = Theme.of(context).brightness == Brightness.dark;

    HapticHelper.medium();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) {
        return ValueListenableBuilder<int>(
          valueListenable: stageNotifier,
          builder: (ctx, activeStage, _) {
            return Dialog(
              backgroundColor: isDarkNow ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
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

  Future<bool> _showDiscardDialog(BuildContext context, bool isDark, AppLocalizations l10n) async {
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
    return shouldPop ?? false;
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
        final shouldPop = await _showDiscardDialog(context, isDark, l10n);
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              // 1. TOP APP BAR
              _buildTopBar(context, isDark, hasUnsavedData, l10n),

              // 2. SCROLLABLE FORM CONTENT (Compact Small-to-Medium Sizing)
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 6.0),
                  children: [
                    // HERO TRIP PREVIEW CARD (Compact 112px height)
                    _buildHeroTripPreviewCard(createVm, isDark, l10n),

                    const SizedBox(height: 12),

                    // QUICK INSPIRATION CHIPS
                    _buildInspirationChips(isDark, l10n),

                    const SizedBox(height: 16),

                    // SECTION 1: TRIP IDENTITY
                    _buildTripIdentitySection(createVm, isDark, l10n),

                    const SizedBox(height: 16),

                    // SECTION 2: EXPERIENCE MODE
                    _buildExperienceModeSection(createVm, isDark, l10n),

                    const SizedBox(height: 16),

                    // SECTION 3: BASE CURRENCY
                    _buildCurrencySection(createVm, isDark, l10n),

                    const SizedBox(height: 16),

                    // SECTION 4: CREW & CO-TRAVELERS
                    _buildCrewSection(createVm, isDark, l10n),

                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // 3. STICKY BOTTOM ACTION DECK
              _buildStickyBottomDeck(context, createVm, isDark, l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isDark, bool hasUnsavedData, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () async {
              HapticHelper.light();
              if (hasUnsavedData) {
                final shouldPop = await _showDiscardDialog(context, isDark, l10n);
                if (shouldPop && context.mounted) Navigator.of(context).pop();
              } else {
                Navigator.of(context).pop();
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161D24) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Icon(
                Icons.close_rounded,
                size: 19,
                color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
              ),
            ),
          ),
          Text(
            l10n.createTripAppbarTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  /// Interactive Live Hero Card with Scenic Vector Artwork Background (~116px height)
  Widget _buildHeroTripPreviewCard(
    CreateTripViewModel createVm,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final hasName = createVm.name.trim().isNotEmpty;
    final activeTheme = TripBackgroundThemes.getTheme(createVm.coverGradientIndex);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: activeTheme.gradientColors.first.withValues(alpha: isDark ? 0.40 : 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TripCoverBackground(
        themeIndex: createVm.coverGradientIndex,
        borderRadius: 18,
        height: 116,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Emoji Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.2),
              ),
              child: Center(
                child: Text(createVm.emoji, style: const TextStyle(fontSize: 30)),
              ),
            ),
            const SizedBox(width: 14),

            // Trip Name & Badges
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    hasName ? createVm.name : l10n.translate('trip_idea_goa'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                      shadows: [
                        Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.8),
                        ),
                        child: Text(
                          createVm.tripMode == 'split_and_journey' ? 'Split + Journey' : 'Split Only',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.8),
                        ),
                        child: Text(
                          createVm.currencyCode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          activeTheme.emoji,
                          style: const TextStyle(fontSize: 10.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Quick Inspiration Chips
  Widget _buildInspirationChips(bool isDark, AppLocalizations l10n) {
    final ideas = _getTripIdeas(l10n);
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: ideas.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final idea = ideas[index];
          return InkWell(
            onTap: () => _applyTripIdea(idea),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141C24) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(idea['emoji']!, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                  Text(
                    idea['name']!,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Section 1: Trip Identity (Compact Card)
  Widget _buildTripIdentitySection(
    CreateTripViewModel createVm,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111820) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.createTripNameLabel.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),

          // Name Input Row with Emoji Trigger
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  HapticHelper.light();
                  setState(() => _showEmojiTray = !_showEmojiTray);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF18222C) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Center(
                    child: Text(createVm.emoji, style: const TextStyle(fontSize: 22)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF18222C) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                    ),
                    decoration: KithInputDecoration.borderless(
                      hintText: l10n.createTripNameHint,
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                      ),
                    ),
                    onChanged: (val) => createVm.setName(val),
                  ),
                ),
              ),
            ],
          ),

          // Collapsible Emoji Tray
          if (_showEmojiTray) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161E27) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _emojis.map((emoji) {
                  final isSelected = createVm.emoji == emoji;
                  return GestureDetector(
                    onTap: () {
                      HapticHelper.selection();
                      createVm.setEmoji(emoji);
                      setState(() => _showEmojiTray = false);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF14B8A6).withValues(alpha: isDark ? 0.3 : 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(color: const Color(0xFF14B8A6), width: 1.5)
                            : null,
                      ),
                      child: Center(
                        child: Text(emoji, style: const TextStyle(fontSize: 19)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Scenic Artwork Theme Selector (Mountains, Beach, Forest, Skyline, Dunes, Aurora, Minimal)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'BACKGROUND THEME & ARTWORK',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                ),
              ),
              Text(
                TripBackgroundThemes.getTheme(createVm.coverGradientIndex).name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF14B8A6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 58,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: TripBackgroundThemes.themes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final theme = TripBackgroundThemes.themes[index];
                final isSelected = createVm.coverGradientIndex == theme.id;
                return InkWell(
                  onTap: () {
                    HapticHelper.selection();
                    createVm.setCoverGradientIndex(theme.id);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 92,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: theme.gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: isSelected ? 2.0 : 0.8,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: theme.gradientColors.first.withValues(alpha: 0.6),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(theme.emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(
                          theme.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                            shadows: const [
                              Shadow(color: Colors.black45, blurRadius: 2),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Section 2: Experience Mode (Compact Small-to-Medium Cards)
  Widget _buildExperienceModeSection(
    CreateTripViewModel createVm,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111820) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.createTripExpMode.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),

          // Side-by-Side Compact Mode Cards
          Row(
            children: [
              // Mode 1: Split Only
              Expanded(
                child: _buildModeCard(
                  title: l10n.createTripModeSplitTitle,
                  desc: l10n.createTripModeSplitDesc,
                  icon: Icons.bolt_rounded,
                  modeValue: 'split_only',
                  isSelected: createVm.tripMode == 'split_only',
                  isDark: isDark,
                  onTap: () => createVm.setTripMode('split_only'),
                ),
              ),
              const SizedBox(width: 8),

              // Mode 2: Split + Journey
              Expanded(
                child: _buildModeCard(
                  title: l10n.createTripModeFullTitle,
                  desc: l10n.createTripModeFullDesc,
                  icon: Icons.auto_awesome_rounded,
                  modeValue: 'split_and_journey',
                  isSelected: createVm.tripMode == 'split_and_journey',
                  isDark: isDark,
                  onTap: () => createVm.setTripMode('split_and_journey'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String desc,
    required IconData icon,
    required String modeValue,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final primaryColor = const Color(0xFF14B8A6);
    return InkWell(
      onTap: () {
        HapticHelper.selection();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: isDark ? 0.16 : 0.1)
              : (isDark ? const Color(0xFF161E27) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? primaryColor
                      : (isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E))
                          : (isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.2,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Section 3: Base Currency
  Widget _buildCurrencySection(
    CreateTripViewModel createVm,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111820) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.createTripBaseCurrency.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _currencies.map((curr) {
                final isSelected = createVm.currencyCode == curr['code'];
                final primaryColor = const Color(0xFF14B8A6);
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: InkWell(
                    onTap: () {
                      HapticHelper.selection();
                      createVm.setCurrencyCode(curr['code']!);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryColor.withValues(alpha: isDark ? 0.2 : 0.12)
                            : (isDark ? const Color(0xFF161E27) : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? primaryColor
                              : (isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
                          width: isSelected ? 1.4 : 0.8,
                        ),
                      ),
                      child: Text(
                        curr['label']!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E))
                              : (isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A)),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Section 4: Crew & Co-Travelers
  Widget _buildCrewSection(
    CreateTripViewModel createVm,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111820) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.createTripCrewTitle.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${createVm.friendNames.length + 1} members',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF14B8A6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // QR Fast-Join Banner (Compact)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF14B8A6).withValues(alpha: isDark ? 0.1 : 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF14B8A6).withValues(alpha: 0.25),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.qr_code_scanner_rounded, size: 20, color: Color(0xFF14B8A6)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.createTripQrHint,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Add Friend Manual Expandable
          GestureDetector(
            onTap: () {
              HapticHelper.light();
              setState(() => _showManualFriends = !_showManualFriends);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161E27) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_add_alt_1_rounded, size: 16, color: Color(0xFF14B8A6)),
                  const SizedBox(width: 6),
                  Text(
                    l10n.createTripAddFriendManual,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _showManualFriends ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),

          if (_showManualFriends || createVm.friendNames.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161E27) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                        width: 0.8,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: TextField(
                      controller: _friendController,
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                      ),
                      decoration: KithInputDecoration.borderless(
                        hintText: l10n.createTripFriendHint,
                        hintStyle: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                        ),
                      ),
                      onSubmitted: (_) => _addFriend(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _addFriend,
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B8A6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(Icons.add_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),

            if (createVm.friendNames.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: createVm.friendNames.map((name) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B8A6).withValues(alpha: isDark ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF14B8A6).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488),
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            HapticHelper.light();
                            createVm.removeFriendName(name);
                          },
                          child: const Icon(Icons.close_rounded, size: 14),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Sticky Bottom Action Deck
  Widget _buildStickyBottomDeck(
    BuildContext context,
    CreateTripViewModel createVm,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF080C0E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: createVm.isValid && !createVm.isCreating ? _handleCreate : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14B8A6),
              foregroundColor: Colors.white,
              disabledBackgroundColor: isDark ? const Color(0xFF1E2830) : const Color(0xFFE2E8F0),
              disabledForegroundColor: isDark ? Colors.white30 : Colors.black26,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
            child: createVm.isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.createTripSubmitBtn,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
