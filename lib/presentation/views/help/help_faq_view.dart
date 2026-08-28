import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/kith_brand.dart';
import '../../widgets/progress/progress.dart';
import '../onboarding/widgets/recovery_key_sheet.dart';

class FaqTopic {
  final String category;
  final String categoryLabel;
  final String categoryIcon;
  final String question;
  final String answer;
  final String? tip;
  final String? actionLabel;
  final VoidCallback? onAction;

  const FaqTopic({
    required this.category,
    this.categoryLabel = '',
    this.categoryIcon = '⚡',
    required this.question,
    required this.answer,
    this.tip,
    this.actionLabel,
    this.onAction,
  });

  String get categoryKey => category;
}

typedef FaqItem = FaqTopic;

class HelpFaqView extends StatefulWidget {
  const HelpFaqView({super.key});

  @override
  State<HelpFaqView> createState() => _HelpFaqViewState();
}

class _HelpFaqViewState extends State<HelpFaqView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  final Set<int> _expandedIndices = {};
  final Map<int, bool> _feedbackMap = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FaqTopic> _buildFaqList(BuildContext context) {
    final l10n = context.l10n;

    return [
      // 1. GETTING STARTED
      FaqTopic(
        category: 'GETTING STARTED',
        categoryLabel: l10n.faqCatGettingStarted,
        categoryIcon: '⚡',
        question: 'How do I get started with Kith?',
        answer:
            'You can start immediately as an anonymous guest without entering a password, or sign in seamlessly with Google. Choose whether you want Trips & Group Splitting only, or the full experience with Personal Expenses & Monthly Budgets.',
        tip: 'Pro-Tip: You can switch between guest and Google mode anytime without losing your local trips or expenses.',
        actionLabel: 'Open Setup Guide',
        onAction: () => context.push('/guide'),
      ),
      FaqTopic(
        category: 'GETTING STARTED',
        categoryLabel: l10n.faqCatGettingStarted,
        categoryIcon: '⚡',
        question: 'How do I switch between Personal Expenses and Trips?',
        answer:
            'Use the floating bottom navigation bar to transition between your private Personal Finance ledger and your collaborative Group Trips.',
        tip: 'Navigation Tip: Double-tapping the active tab quickly scrolls to top or refreshes the view.',
      ),

      // 2. ACCOUNT & SECURITY
      FaqTopic(
        category: 'ACCOUNT & SECURITY',
        categoryLabel: l10n.faqCatSecurity,
        categoryIcon: '🛡️',
        question: 'What is a Recovery Key and how does it protect me?',
        answer:
            'Your Recovery Key (e.g. KITH-ABCD-EFGH) is a cryptographic 128-bit backup token generated securely on your device. You can enter it on any new phone to restore your account identity, trips, and expenses without needing a password.',
        tip: 'Security Guarantee: We store only a one-way cryptographic SHA-256 hash on our servers. Your plaintext key is private to you.',
        actionLabel: 'View Recovery Key Sheet',
        onAction: () => RecoveryKeySheet.show(context),
      ),
      FaqTopic(
        category: 'ACCOUNT & SECURITY',
        categoryLabel: l10n.faqCatSecurity,
        categoryIcon: '🛡️',
        question: 'Can I use Kith completely without a Google account?',
        answer:
            'Yes! Kith has a true Guest-First architecture. You can create unlimited trips, add members, split bills, and track personal budgets 100% anonymously with your Recovery Key.',
      ),
      FaqTopic(
        category: 'ACCOUNT & SECURITY',
        categoryLabel: l10n.faqCatSecurity,
        categoryIcon: '🛡️',
        question: 'What happens if I sign out or switch devices?',
        answer:
            'Signing out safely wipes cached tokens on this device. Your data is stored safely in the cloud. You can sign right back in using your Google account or Recovery Key.',
      ),

      // 3. PERSONAL EXPENSES
      FaqTopic(
        category: 'PERSONAL EXPENSES',
        categoryLabel: l10n.faqCatPersonal,
        categoryIcon: '💳',
        question: 'How does personal expense tracking work?',
        answer:
            'In the Personal tab, tap + to log expenses with categories (Food, Transport, Bills, Shopping, etc.), set monthly spending limits, and track friend lending & borrowing with exact paise math.',
        tip: 'Insight: Personal expenses are strictly private to you and are never visible to your trip members.',
      ),
      FaqTopic(
        category: 'PERSONAL EXPENSES',
        categoryLabel: l10n.faqCatPersonal,
        categoryIcon: '💳',
        question: 'Can I set and monitor a monthly spending budget?',
        answer:
            'Yes! Tap the budget card on the Personal Home tab to configure a monthly limit. Kith automatically computes your daily spending runway and alerts you before you exceed your target.',
        tip: 'Runway Math: Kith dynamically divides remaining budget by remaining days in the month to calculate your optimal daily runway.',
      ),
      FaqTopic(
        category: 'PERSONAL EXPENSES',
        categoryLabel: l10n.faqCatPersonal,
        categoryIcon: '💳',
        question: 'How does Lending and Borrowing (Debts) tracking work?',
        answer:
            'Open Personal → Debts to record money you lent or borrowed from friends outside of trips. You can record partial or full repayments anytime with timestamped transaction receipts.',
      ),

      // 4. TRIPS
      FaqTopic(
        category: 'TRIPS',
        categoryLabel: l10n.faqCatTrips,
        categoryIcon: '✈️',
        question: 'How do I create and customize a new trip?',
        answer:
            'Go to Trips → tap + New Trip → choose between "Split Only" or "Split + Journey" mode, select your destination, custom emoji, gradient theme, currency, and invite initial friends.',
        tip: 'Travel Tip: In Split + Journey mode, every expense automatically attaches to your trip timeline as a memorable stop.',
      ),
      FaqTopic(
        category: 'TRIPS',
        categoryLabel: l10n.faqCatTrips,
        categoryIcon: '✈️',
        question: 'How do I invite friends to join my trip?',
        answer:
            'Open your trip and tap the Invite button. Friends can join instantly by typing your unique 6-character alphanumeric code (e.g. GOA24X) or scanning your trip QR code with their camera.',
      ),

      // 5. SPLITTING EXPENSES
      FaqTopic(
        category: 'SPLITTING EXPENSES',
        categoryLabel: l10n.faqCatSplitting,
        categoryIcon: '⚖️',
        question: 'What split modes does Kith support?',
        answer:
            'Kith supports: 1) Split Equally among selected members, 2) Exact Amounts (paise-perfect), and 3) Custom Percentages. The internal MoneyEngine guarantees zero remainder rounding loss.',
        tip: 'Zero Loss Formula: Any odd paise left over from uneven divisions are deterministically distributed one paise per member in payer order.',
      ),
      FaqTopic(
        category: 'SPLITTING EXPENSES',
        categoryLabel: l10n.faqCatSplitting,
        categoryIcon: '⚖️',
        question: 'Can multiple people pay for a single expense?',
        answer:
            'Yes! In the Add Expense screen, select multiple payers and specify how much each person contributed, or select a single payer and split across any subset of members.',
      ),

      // 6. SETTLEMENTS
      FaqTopic(
        category: 'SETTLEMENTS',
        categoryLabel: l10n.faqCatSettlements,
        categoryIcon: '🤝',
        question: 'How does Debt Simplification work?',
        answer:
            'Kith uses an optimized graph-reduction settlement algorithm. Instead of 10 people sending 45 micro-payments to each other, Kith simplifies the mesh to the minimal direct transfers required to settle all balances to zero.',
        tip: 'Efficiency: An n-person mesh of debts is reduced to at most n-1 direct transfers with zero arithmetic discrepancy.',
      ),
      FaqTopic(
        category: 'SETTLEMENTS',
        categoryLabel: l10n.faqCatSettlements,
        categoryIcon: '🤝',
        question: 'How do I record a settlement payment?',
        answer:
            'In Trip Details, scroll to the Settlements section → tap "Record Payment" next to any suggested transfer to mark it resolved, or tap "Settle Up" to record custom amount payments.',
      ),

      // 7. VOICE INTELLIGENCE
      FaqTopic(
        category: 'VOICE INTELLIGENCE',
        categoryLabel: l10n.faqCatVoice,
        categoryIcon: '🎙️',
        question: 'How does Voice Expense entry work?',
        answer:
            'Tap the microphone icon, speak naturally in English or Hindi (e.g. "Dinner for 1200 paid by Rahul for everyone"), review the generated draft, and tap Save. Nothing is saved without your visual confirmation.',
        tip: 'Privacy Assurance: Voice audio is processed solely for intent extraction and is never recorded in the background or sold to third parties.',
      ),
      FaqTopic(
        category: 'VOICE INTELLIGENCE',
        categoryLabel: l10n.faqCatVoice,
        categoryIcon: '🎙️',
        question: 'What languages does Voice Split understand?',
        answer:
            'Kith\'s voice parser natively understands conversational English, Hindi, Hinglish, and Gujarati speech patterns with natural number words (e.g. "pachas hazar", "chhe sau").',
      ),

      // 8. RECEIPTS & OCR
      FaqTopic(
        category: 'RECEIPTS & OCR',
        categoryLabel: l10n.faqCatReceipts,
        categoryIcon: '🧾',
        question: 'How does Receipt & Bill Scanning work?',
        answer:
            'Tap the Receipt Camera icon, snap a photo of any restaurant bill or store invoice. On-device AI OCR detects the merchant, total amount, taxes, and date, filling the expense form automatically for your review.',
        tip: 'On-Device Processing: OCR extraction runs on your device, ensuring fast recognition even in low-connectivity areas.',
      ),

      // 9. QR & TRIP JOINING
      FaqTopic(
        category: 'QR & TRIP JOINING',
        categoryLabel: l10n.faqCatQr,
        categoryIcon: '📷',
        question: 'How do I scan a QR code to join a trip?',
        answer:
            'Go to Trips → tap Join Trip → tap "Scan QR Code". Point your camera at your friend\'s screen or shared poster to join the trip in under a second.',
      ),

      // 10. CLOUD SYNCHRONIZATION
      FaqTopic(
        category: 'CLOUD SYNCHRONIZATION',
        categoryLabel: l10n.faqCatCloud,
        categoryIcon: '☁️',
        question: 'How does Cloud Sync work?',
        answer:
            'Kith uses an offline-first mutation queue. Every action you take is saved locally in milliseconds and synced with Supabase PostgreSQL as soon as an active internet connection is detected.',
        tip: 'Idempotency: Every mutation has a client UUID. Retrying a sync or reconnection will never produce duplicate charges.',
      ),
      FaqTopic(
        category: 'CLOUD SYNCHRONIZATION',
        categoryLabel: l10n.faqCatCloud,
        categoryIcon: '☁️',
        question: 'Why does it say "Changes waiting to sync"?',
        answer:
            'If you create or edit expenses while offline, Kith queues them securely. When your connection returns or you tap "Sync now", all changes upload automatically in background.',
      ),

      // 11. OFFLINE MODE
      FaqTopic(
        category: 'OFFLINE MODE',
        categoryLabel: l10n.faqCatOffline,
        categoryIcon: '📶',
        question: 'Can I use Kith completely offline during flights or remote treks?',
        answer:
            'Yes! You can view trips, add expenses, split bills, check balances, and browse help completely offline. Everything syncs automatically when you return to coverage.',
      ),

      // 12. DATA PRIVACY
      FaqTopic(
        category: 'DATA PRIVACY',
        categoryLabel: l10n.faqCatPrivacy,
        categoryIcon: '🔒',
        question: 'Can other people see my personal expenses?',
        answer:
            'No! Your personal expenses, budgets, and lending/borrowing records are strictly private to your account. Only group trip expenses are shared with invited trip members.',
        tip: 'Data Minimization: We never collect unnecessary location, contacts, or background metrics.',
        actionLabel: 'Read Privacy Policy',
        onAction: () => context.push('/privacy-policy'),
      ),

      // 13. TROUBLESHOOTING
      FaqTopic(
        category: 'TROUBLESHOOTING',
        categoryLabel: l10n.faqCatTroubleshooting,
        categoryIcon: '🛠️',
        question: 'Google Sign-In was cancelled or failed. What do I do?',
        answer:
            'Ensure your device has an active internet connection. If Google Play services is temporarily unavailable, Kith provides an instant guest session and email recovery fallback so you are never locked out.',
      ),
      FaqTopic(
        category: 'TROUBLESHOOTING',
        categoryLabel: l10n.faqCatTroubleshooting,
        categoryIcon: '🛠️',
        question: 'How do I export my trip summary report?',
        answer:
            'Open your trip → tap the menu in the top right → select "Export Summary" to generate CSV spreadsheets or formatted plain text breakdowns shareable via WhatsApp or email.',
      ),
    ];
  }

  List<FaqTopic> _filterFaqs(List<FaqTopic> allFaqs) {
    return allFaqs.where((faq) {
      if (_selectedCategory != null && faq.categoryKey != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return faq.question.toLowerCase().contains(q) ||
          faq.answer.toLowerCase().contains(q) ||
          faq.categoryLabel.toLowerCase().contains(q) ||
          (faq.tip != null && faq.tip!.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final allFaqs = _buildFaqList(context);
    final filteredFaqs = _filterFaqs(allFaqs);

    // Extract unique categories in order
    final categories = <Map<String, String>>[];
    final seenKeys = <String>{};
    for (final f in allFaqs) {
      if (!seenKeys.contains(f.categoryKey)) {
        seenKeys.add(f.categoryKey);
        categories.add({
          'key': f.categoryKey,
          'label': f.categoryLabel.isNotEmpty ? f.categoryLabel : f.categoryKey,
          'icon': f.categoryIcon,
        });
      }
    }

    final bgColor = isDark ? const Color(0xFF080C0E) : const Color(0xFFFAFBFB);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Ambient Radial Emerald Background Glow
          Positioned(
            top: -100,
            right: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                        .withValues(alpha: isDark ? 0.09 : 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // 1. TOP APP BAR
                _buildTopBar(context, isDark, reduceMotion),

                // 2. MAIN SCROLLABLE CONTENT
                Expanded(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // HERO SECTION
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Hero Title
                              Text(
                                l10n.faqHeroTitle,
                                style: AppTypography.displayHero(isDark: isDark).copyWith(
                                  height: 1.15,
                                  letterSpacing: -0.8,
                                  fontSize: 30,
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Subtitle
                              Text(
                                l10n.faqHeroSub,
                                style: AppTypography.bodyMedium(isDark: isDark).copyWith(
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Stats Badge Row
                              _buildStatsPill(l10n.faqBadgeStats, isDark),

                              const SizedBox(height: 18),

                              // Interactive Setup Guide Hero Banner
                              _buildGuideBanner(context, isDark, l10n),

                              const SizedBox(height: 18),

                              // Search Bar
                              _buildSearchBar(isDark, l10n),
                            ],
                          )
                              .animate()
                              .fadeIn(duration: reduceMotion ? 1.ms : 300.ms)
                              .slideY(begin: reduceMotion ? 0 : 0.04, end: 0),
                        ),
                      ),

                      // HORIZONTAL CATEGORY STREAM
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 12),
                          child: _buildCategoryChips(categories, isDark, l10n),
                        ),
                      ),

                      // RESULTS COUNT HEADER
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.faqSearchResults(filteredFaqs.length).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                              if (_selectedCategory != null || _searchQuery.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    HapticHelper.light();
                                    setState(() {
                                      _selectedCategory = null;
                                      _searchQuery = '';
                                      _searchController.clear();
                                    });
                                  },
                                  child: Text(
                                    'Reset filters',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // FAQ CARDS LIST
                      if (filteredFaqs.isEmpty)
                        SliverToBoxAdapter(
                          child: _buildEmptyState(isDark, l10n),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, index) {
                                final item = filteredFaqs[index];
                                final isExpanded = _expandedIndices.contains(index);
                                final feedback = _feedbackMap[index];

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: _buildMasterFaqCard(
                                    context: ctx,
                                    item: item,
                                    index: index,
                                    isExpanded: isExpanded,
                                    feedback: feedback,
                                    isDark: isDark,
                                    l10n: l10n,
                                  ),
                                );
                              },
                              childCount: filteredFaqs.length,
                            ),
                          ),
                        ),

                      // BOTTOM SUPPORT DECK
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 32.0),
                          child: _buildSupportDeck(context, isDark, l10n),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isDark, bool reduceMotion) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          // Back Button with Glass Container
          InkWell(
            onTap: () {
              HapticHelper.light();
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Center Brand Badge
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                KithLogoMark(size: 16, isDark: isDark),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'KITH · HELP',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Interactive Guide Shortcut
          InkWell(
            onTap: () {
              HapticHelper.medium();
              context.push('/guide');
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.emeraldPrimary.withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.emeraldPrimary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.menu_book_rounded, size: 14, color: AppColors.emeraldPrimary),
                  const SizedBox(width: 4),
                  Text(
                    'Guide',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsPill(String statsText, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.emeraldPrimary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            statsText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideBanner(BuildContext context, bool isDark, AppLocalizations l10n) {
    return InkWell(
      onTap: () {
        HapticHelper.medium();
        context.push('/guide');
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppColors.emeraldPrimary.withValues(alpha: 0.22),
                    AppColors.indigoAccent.withValues(alpha: 0.16),
                  ]
                : [
                    AppColors.emeraldPrimary.withValues(alpha: 0.12),
                    AppColors.indigoAccent.withValues(alpha: 0.08),
                  ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.emeraldPrimary.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.emeraldPrimary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                color: AppColors.emeraldPrimary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      const Text(
                        'Interactive Setup Guide',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldPrimary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'TOUR',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Step-by-step visual walkthrough with direct feature shortcuts.',
                    style: AppTypography.bodySmall(isDark: isDark).copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.emeraldPrimary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _searchQuery.isNotEmpty
              ? AppColors.emeraldPrimary.withValues(alpha: 0.5)
              : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
          width: _searchQuery.isNotEmpty ? 1.4 : 1.0,
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() => _searchQuery = val.trim());
        },
        style: TextStyle(
          fontSize: 14,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
        decoration: InputDecoration(
          hintText: l10n.faqSearchHint,
          hintStyle: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: _searchQuery.isNotEmpty ? AppColors.emeraldPrimary : (isDark ? Colors.white38 : Colors.black38),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    HapticHelper.light();
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildCategoryChips(
    List<Map<String, String>> categories,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        physics: const BouncingScrollPhysics(),
        children: [
          // ALL TOPICS Pill
          _buildFilterPill(
            label: l10n.faqCatAll,
            icon: '✨',
            isSelected: _selectedCategory == null,
            isDark: isDark,
            onTap: () {
              HapticHelper.selection();
              setState(() => _selectedCategory = null);
            },
          ),
          const SizedBox(width: 8),

          // Categories
          ...categories.map((cat) {
            final isSelected = _selectedCategory == cat['key'];
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _buildFilterPill(
                label: cat['label']!,
                icon: cat['icon']!,
                isSelected: isSelected,
                isDark: isDark,
                onTap: () {
                  HapticHelper.selection();
                  setState(() => _selectedCategory = isSelected ? null : cat['key']);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required String icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.emeraldPrimary
              : (isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.emeraldPrimary
                : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.emeraldPrimary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterFaqCard({
    required BuildContext context,
    required FaqTopic item,
    required int index,
    required bool isExpanded,
    required bool? feedback,
    required bool isDark,
    required AppLocalizations l10n,
  }) {
    final borderColor = isExpanded
        ? AppColors.emeraldPrimary.withValues(alpha: 0.45)
        : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: isExpanded ? 1.4 : 1.0,
        ),
        boxShadow: isExpanded
            ? [
                BoxShadow(
                  color: AppColors.emeraldPrimary.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            HapticHelper.light();
            setState(() {
              if (isExpanded) {
                _expandedIndices.remove(index);
              } else {
                _expandedIndices.add(index);
              }
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Tag + Chevron Row
                Row(
                  children: [
                    // Category Badge
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(item.categoryIcon, style: const TextStyle(fontSize: 10)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                (item.categoryLabel.isNotEmpty ? item.categoryLabel : item.category).toUpperCase(),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: AppColors.emeraldPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Expand Indicator Badge
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isExpanded
                              ? AppColors.emeraldPrimary.withValues(alpha: 0.15)
                              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: isExpanded
                              ? AppColors.emeraldPrimary
                              : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Question Title
                Text(
                  item.question,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),

                // Expanded Section
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Divider(
                        height: 1,
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                      const SizedBox(height: 12),

                      // Answer Paragraph
                      Text(
                        item.answer,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.55,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),

                      // Optional Tip Box
                      if (item.tip != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F171A)
                                : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.emeraldPrimary.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('💡', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.tip!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.45,
                                    color: isDark ? AppColors.emeraldLight : AppColors.emeraldDark,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Optional Direct Action Button
                      if (item.actionLabel != null && item.onAction != null) ...[
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () {
                            HapticHelper.medium();
                            item.onAction!();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.emeraldPrimary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.emeraldPrimary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.actionLabel!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: AppColors.emeraldPrimary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Micro-Feedback Row (Wrap avoids any right-overflow on all screens)
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Text(
                            l10n.faqHelpfulQuestion,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                          if (feedback == null) ...[
                            _buildFeedbackBtn(
                              label: '👍 ${l10n.faqHelpfulYes}',
                              isDark: isDark,
                              onTap: () {
                                HapticHelper.medium();
                                setState(() => _feedbackMap[index] = true);
                              },
                            ),
                            _buildFeedbackBtn(
                              label: '👎 ${l10n.faqHelpfulNo}',
                              isDark: isDark,
                              onTap: () {
                                HapticHelper.light();
                                setState(() => _feedbackMap[index] = false);
                              },
                            ),
                          ] else ...[
                            Text(
                              l10n.faqHelpfulThanks,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.emeraldPrimary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  crossFadeState:
                      isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 220),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackBtn({
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 36,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No matching answers found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try searching with simple words like "Google", "trips", "recovery", or "split"',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall(isDark: isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportDeck(BuildContext context, bool isDark, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: AppColors.emeraldPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.faqSupportTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.faqSupportDesc,
                      style: AppTypography.bodySmall(isDark: isDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Copy Email Action
              Expanded(
                child: InkWell(
                  onTap: () {
                    HapticHelper.medium();
                    Clipboard.setData(const ClipboardData(text: 'support@nirniq.com'));
                    KithSuccessToast.show(context, l10n.faqCopiedEmail);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldPrimary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.email_outlined, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            l10n.faqSupportEmailBtn,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Open Guide Action
              Expanded(
                child: InkWell(
                  onTap: () {
                    HapticHelper.medium();
                    context.push('/guide');
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.menu_book_rounded, size: 16, color: AppColors.emeraldPrimary),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            l10n.faqSupportGuideBtn,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
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
}
