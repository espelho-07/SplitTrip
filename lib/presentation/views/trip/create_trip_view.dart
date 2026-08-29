import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/kith_components.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/create_trip_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../widgets/progress/progress.dart';

/// Redesigned, visually stunning & energetic Create Trip Experience.
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
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    HapticHelper.medium();

    final stageNotifier = ValueNotifier<int>(0);
    final stages = [
      ProgressStage(label: l10n.createTripStageInit, description: l10n.createTripStageInitDesc),
      ProgressStage(label: l10n.createTripStageMember, description: l10n.createTripStageMemberDesc),
      ProgressStage(label: l10n.createTripStageSpace, description: l10n.createTripStageSpaceDesc),
      ProgressStage(label: l10n.createTripStageSync, description: l10n.createTripStageSyncDesc),
    ];

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

              // 2. SCROLLABLE FORM CONTENT
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  children: [
                    // 1. LIVE HERO TRIP PREVIEW CARD (Interactive)
                    _buildHeroTripPreviewCard(createVm, isDark, l10n),

                    const SizedBox(height: 16),

                    // QUICK INSPIRATION CHIPS
                    _buildInspirationChips(isDark, l10n),

                    const SizedBox(height: 20),

                    // SECTION 1: TRIP IDENTITY (Name Input + Emoji Selector + Color Palette)
                    _buildTripIdentitySection(createVm, isDark, l10n),

                    const SizedBox(height: 20),

                    // SECTION 2: EXPERIENCE MODE (Split+Journey vs Split Only)
                    _buildExperienceModeSection(createVm, isDark, l10n),

                    const SizedBox(height: 20),

                    // SECTION 3: BASE CURRENCY (Horizontal Pills)
                    _buildCurrencySection(createVm, isDark, l10n),

                    const SizedBox(height: 20),

                    // SECTION 4: CREW & CO-TRAVELERS
                    _buildCrewSection(createVm, isDark, l10n),

                    const SizedBox(height: 30),
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
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () async {
              HapticHelper.light();
              if (hasUnsavedData) {
                final shouldPop = await _showDiscardDialog(context, isDark, l10n);
                if (shouldPop && context.mounted) {
                  context.pop();
                }
              } else {
                context.pop();
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
              ),
            ),
          ),

          Text(
            l10n.createTripAppbarTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
            ),
          ),

          const SizedBox(width: 32),
        ],
      ),
    );
  }

  /// Interactive Live Preview Card rendering real-time trip aesthetics.
  Widget _buildHeroTripPreviewCard(CreateTripViewModel createVm, bool isDark, AppLocalizations l10n) {
    final gradient = AppColors.getGradient(createVm.coverGradientIndex);
    final tripName = createVm.name.trim().isEmpty ? l10n.translate('create_trip_hero_preview') : createVm.name.trim();
    final isJourney = createVm.tripMode == 'split_and_journey';

    return Container(
      width: double.infinity,
      height: 130,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withValues(alpha: isDark ? 0.35 : 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle Pattern Overlay
          Positioned(
            right: -20,
            bottom: -20,
            child: Opacity(
              opacity: 0.18,
              child: Text(
                createVm.emoji,
                style: const TextStyle(fontSize: 120),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Tag Badges
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isJourney ? Icons.auto_awesome_rounded : Icons.pie_chart_outline_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isJourney ? l10n.createTripModeFullTitle : l10n.createTripModeSplitTitle,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        createVm.currencyCode,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),

                // Trip Title & Emoji
                Row(
                  children: [
                    Text(
                      createVm.emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tripName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.4,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Quick 1-tap inspiration chips for fast naming.
  Widget _buildInspirationChips(bool isDark, AppLocalizations l10n) {
    final ideas = _getTripIdeas(l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            l10n.createTripQuickIdeas.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
            ),
          ),
        ),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: ideas.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final idea = ideas[index];
              return GestureDetector(
                onTap: () => _applyTripIdea(idea),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(idea['emoji']!, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        idea['name']!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextPrimary : const Color(0xFF334155),
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
    );
  }

  /// Trip Identity Card: Name + Emoji + Color Palette
  Widget _buildTripIdentitySection(CreateTripViewModel createVm, bool isDark, AppLocalizations l10n) {
    final gradient = AppColors.getGradient(createVm.coverGradientIndex);

    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRIP DETAILS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),

          // Emoji Button + Name TextField Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Emoji Selector Button
              GestureDetector(
                onTap: () {
                  HapticHelper.selection();
                  setState(() => _showEmojiTray = !_showEmojiTray);
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: gradient[0].withValues(alpha: isDark ? 0.25 : 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: gradient[0].withValues(alpha: isDark ? 0.6 : 0.4),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    createVm.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name Input Field (Borderless)
              Expanded(
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161D24) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: createVm.name.trim().isNotEmpty
                          ? const Color(0xFF14B8A6).withValues(alpha: 0.6)
                          : (isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
                      width: 1.2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                    ),
                    decoration: KithInputDecoration.borderless(
                      hintText: l10n.createTripNameHint,
                      hintStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                      ),
                      suffixIcon: createVm.name.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                HapticHelper.light();
                                _nameController.clear();
                                createVm.setName('');
                              },
                              child: const Icon(Icons.clear_rounded, size: 18),
                            )
                          : null,
                    ),
                    onChanged: createVm.setName,
                  ),
                ),
              ),
            ],
          ),

          // Expandable Emoji Picker Grid
          if (_showEmojiTray) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161D24) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _emojis.map((em) {
                  final isSelected = createVm.emoji == em;
                  return InkWell(
                    onTap: () {
                      HapticHelper.selection();
                      createVm.setEmoji(em);
                      setState(() => _showEmojiTray = false);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF14B8A6).withValues(alpha: 0.25)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected
                            ? Border.all(color: const Color(0xFF14B8A6), width: 1.5)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(em, style: const TextStyle(fontSize: 20)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 18),

          // Theme Color Gradient Swatches
          Row(
            children: [
              Text(
                'Theme Color',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF334155),
                ),
              ),
              const Spacer(),
              Row(
                children: List.generate(AppColors.tripGradients.length, (index) {
                  final isSelected = createVm.coverGradientIndex == index;
                  final g = AppColors.getGradient(index);
                  return GestureDetector(
                    onTap: () {
                      HapticHelper.selection();
                      createVm.setCoverGradientIndex(index);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: g),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 2.2)
                            : Border.all(color: isDark ? Colors.white24 : Colors.black12, width: 1),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: g[0].withValues(alpha: 0.6),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
                          : null,
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Clean, energetic Experience Mode Selector.
  Widget _buildExperienceModeSection(CreateTripViewModel createVm, bool isDark, AppLocalizations l10n) {
    final isJourney = createVm.tripMode == 'split_and_journey';

    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.createTripExpMode.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              // Option 1: Split + Journey
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticHelper.selection();
                    createVm.setTripMode('split_and_journey');
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      color: isJourney
                          ? const Color(0xFF14B8A6).withValues(alpha: isDark ? 0.2 : 0.12)
                          : (isDark ? const Color(0xFF161D24) : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isJourney
                            ? const Color(0xFF14B8A6)
                            : (isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
                        width: isJourney ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 22,
                          color: isJourney ? const Color(0xFF14B8A6) : (isDark ? AppColors.darkTextMuted : const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.createTripModeFullTitle,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isJourney ? FontWeight.w800 : FontWeight.w600,
                            color: isJourney
                                ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                : (isDark ? AppColors.darkTextSecondary : const Color(0xFF475569)),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.createTripModeFullDesc,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Option 2: Split Only
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticHelper.selection();
                    createVm.setTripMode('split_only');
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      color: !isJourney
                          ? const Color(0xFF14B8A6).withValues(alpha: isDark ? 0.2 : 0.12)
                          : (isDark ? const Color(0xFF161D24) : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: !isJourney
                            ? const Color(0xFF14B8A6)
                            : (isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
                        width: !isJourney ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.pie_chart_outline_rounded,
                          size: 22,
                          color: !isJourney ? const Color(0xFF14B8A6) : (isDark ? AppColors.darkTextMuted : const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.createTripModeSplitTitle,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: !isJourney ? FontWeight.w800 : FontWeight.w600,
                            color: !isJourney
                                ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                : (isDark ? AppColors.darkTextSecondary : const Color(0xFF475569)),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.createTripModeSplitDesc,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Currency Selector Pills
  Widget _buildCurrencySection(CreateTripViewModel createVm, bool isDark, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.createTripBaseCurrency.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _currencies.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final c = _currencies[index];
                final isSelected = createVm.currencyCode == c['code'];

                return InkWell(
                  onTap: () {
                    HapticHelper.selection();
                    createVm.setCurrencyCode(c['code']!);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF14B8A6)
                          : (isDark ? const Color(0xFF161D24) : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF14B8A6)
                            : (isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
                        width: 1.2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      c['label']!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? AppColors.darkTextPrimary : const Color(0xFF334155)),
                      ),
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

  /// Crew & Co-Travelers Section
  Widget _buildCrewSection(CreateTripViewModel createVm, bool isDark, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
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
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                ),
              ),
              if (createVm.friendNames.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${createVm.friendNames.length} ${l10n.tripCardMemberPlural(createVm.friendNames.length)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF14B8A6),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Instant QR Notice
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161D24) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 20,
                  color: Color(0xFF14B8A6),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.createTripQrHint,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Expandable Offline Friend Option
          GestureDetector(
            onTap: () {
              HapticHelper.light();
              setState(() => _showManualFriends = !_showManualFriends);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _showManualFriends ? Icons.keyboard_arrow_up_rounded : Icons.person_add_alt_1_rounded,
                    size: 18,
                    color: const Color(0xFF14B8A6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.createTripAddFriendManual,
                    style: TextStyle(
                      fontSize: 12.5,
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161D24) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: TextField(
                      controller: _friendController,
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                      ),
                      decoration: KithInputDecoration.borderless(
                        hintText: l10n.createTripFriendHint,
                        hintStyle: TextStyle(
                          fontSize: 13,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B8A6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),

            if (createVm.friendNames.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: createVm.friendNames.map((name) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B8A6).withValues(alpha: isDark ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF14B8A6).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            HapticHelper.light();
                            createVm.removeFriendName(name);
                          },
                          child: const Icon(Icons.close_rounded, size: 15),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
          height: 52,
          child: ElevatedButton(
            onPressed: createVm.isValid && !createVm.isCreating ? _handleCreate : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14B8A6),
              foregroundColor: Colors.white,
              disabledBackgroundColor: isDark ? const Color(0xFF1E2830) : const Color(0xFFE2E8F0),
              disabledForegroundColor: isDark ? Colors.white30 : Colors.black26,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: const Color(0xFF14B8A6).withValues(alpha: 0.4),
            ),
            child: createVm.isCreating
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.createTripSubmitBtn,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
