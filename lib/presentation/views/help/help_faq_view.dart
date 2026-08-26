import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/surface_card.dart';

class FaqItem {
  final String category;
  final String question;
  final String answer;

  const FaqItem({
    required this.category,
    required this.question,
    required this.answer,
  });
}

class HelpFaqView extends StatefulWidget {
  const HelpFaqView({super.key});

  @override
  State<HelpFaqView> createState() => _HelpFaqViewState();
}

class _HelpFaqViewState extends State<HelpFaqView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;

  static const List<FaqItem> _allFaqs = [
    // 1. GETTING STARTED
    FaqItem(
      category: 'GETTING STARTED',
      question: 'How do I get started with Kith?',
      answer:
          'You can start immediately as a guest or sign in with Google. Choose whether you want Trips & Group Splitting only, or the full suite with Personal Expenses & Budgets.',
    ),
    FaqItem(
      category: 'GETTING STARTED',
      question: 'How do I switch between Personal Expenses and Trips?',
      answer:
          'Tap the navigation bar at the bottom of the home screen to seamlessly switch between your Personal Ledger and your Group Trips.',
    ),

    // 2. ACCOUNT & SECURITY
    FaqItem(
      category: 'ACCOUNT & SECURITY',
      question: 'What is a Recovery Key?',
      answer:
          'Your Recovery Key (e.g. KITH-ABCD-EFGH) is a cryptographic backup code generated on your device. You can use it on any new phone to restore your account, trips, and expenses without needing a password.',
    ),
    FaqItem(
      category: 'ACCOUNT & SECURITY',
      question: 'Can I use Kith without Google?',
      answer:
          'Yes! Kith works 100% anonymously with guest identities and Recovery Keys. Linking with Google is optional for automatic cross-device sync.',
    ),
    FaqItem(
      category: 'ACCOUNT & SECURITY',
      question: 'What happens if I sign out?',
      answer:
          'Signing out clears cached credentials on this device. Your data stays safe in the cloud. You can sign right back in using your Google account or Recovery Key.',
    ),

    // 3. PERSONAL EXPENSES
    FaqItem(
      category: 'PERSONAL EXPENSES',
      question: 'How does personal expense tracking work?',
      answer:
          'Tap + in the Personal tab to log expenses with categories (Food, Transport, Bills, etc.), set monthly budgets, and track lending/borrowing with friends.',
    ),
    FaqItem(
      category: 'PERSONAL EXPENSES',
      question: 'Can I set a monthly budget?',
      answer:
          'Yes! Tap the budget card on the Personal Home tab to set a target limit. Kith alerts you when you approach or exceed your budget.',
    ),
    FaqItem(
      category: 'PERSONAL EXPENSES',
      question: 'How does Lending and Borrowing tracking work?',
      answer:
          'Open Personal → Debts to record money you lent or borrowed. You can record partial or full repayments anytime to keep balances exact.',
    ),

    // 4. TRIPS
    FaqItem(
      category: 'TRIPS',
      question: 'How do I create a new trip?',
      answer:
          'Go to Trips → tap + New Trip → select your trip type (Weekend Getaway, Road Trip, Vacation, etc.) → enter a trip name and currency → tap Create. You are immediately taken to your new trip.',
    ),
    FaqItem(
      category: 'TRIPS',
      question: 'How do I invite friends to a trip?',
      answer:
          'Open your trip and tap Invite. Friends can join by entering the 6-character code (e.g. GOA24X) or scanning your trip QR code.',
    ),

    // 5. SPLITTING EXPENSES
    FaqItem(
      category: 'SPLITTING EXPENSES',
      question: 'What split modes does Kith support?',
      answer:
          'Kith supports: 1) Split Equally among selected members, 2) Exact Amounts (paise-perfect), and 3) Custom Percentages. The MoneyEngine guarantees no rounding loss.',
    ),
    FaqItem(
      category: 'SPLITTING EXPENSES',
      question: 'Can one person pay for multiple people?',
      answer:
          'Yes! When adding an expense, select who paid and check the specific members who are splitting that cost.',
    ),

    // 6. SETTLEMENTS
    FaqItem(
      category: 'SETTLEMENTS',
      question: 'How does Debt Simplification work?',
      answer:
          'Kith uses an optimized graph settlement algorithm. Instead of 10 people sending micro-payments to each other, Kith simplifies the mesh to the minimum direct transfers required to settle all debts.',
    ),
    FaqItem(
      category: 'SETTLEMENTS',
      question: 'How do I record a settlement payment?',
      answer:
          'In your Trip details, scroll to Settlements → tap "Record Payment" next to any suggested transfer to mark it resolved.',
    ),

    // 7. VOICE INTELLIGENCE
    FaqItem(
      category: 'VOICE INTELLIGENCE',
      question: 'How does Voice Expense entry work?',
      answer:
          'Tap the microphone icon, speak naturally in English or Hindi (e.g. "Dinner for 1200 paid by Rahul for everyone"), review the generated draft, and tap Save. Nothing is saved without your visual confirmation.',
    ),
    FaqItem(
      category: 'VOICE INTELLIGENCE',
      question: 'Does Kith record audio in the background?',
      answer:
          'No. The microphone is only activated while you explicitly press and speak into the voice capture screen.',
    ),

    // 8. RECEIPTS & OCR
    FaqItem(
      category: 'RECEIPTS & OCR',
      question: 'How does Receipt Scanning work?',
      answer:
          'Tap the Receipt Camera icon, snap a photo of any restaurant bill or store invoice. On-device AI OCR detects the merchant, total amount, and date, filling the expense form automatically for your review.',
    ),

    // 9. QR & TRIP JOINING
    FaqItem(
      category: 'QR & TRIP JOINING',
      question: 'How do I scan a QR code to join?',
      answer:
          'Go to Trips → tap Join Trip → tap "Scan QR Code". Align the camera with your friend\'s screen to join the trip instantly.',
    ),

    // 10. CLOUD SYNCHRONIZATION
    FaqItem(
      category: 'CLOUD SYNCHRONIZATION',
      question: 'How does Cloud Sync work?',
      answer:
          'Kith uses an offline-first mutation queue. Every action you take is saved locally in milliseconds and synced with Supabase PostgreSQL as soon as an internet connection is detected.',
    ),
    FaqItem(
      category: 'CLOUD SYNCHRONIZATION',
      question: 'Why does it say "Changes waiting"?',
      answer:
          'If you create or edit expenses while offline, Kith queues them locally. When your connection returns or you tap "Sync now", all changes upload automatically.',
    ),

    // 11. OFFLINE MODE
    FaqItem(
      category: 'OFFLINE MODE',
      question: 'Can I use Kith completely offline?',
      answer:
          'Yes! You can view trips, add expenses, split bills, check balances, and browse help offline. Changes queue locally and push when you reconnect.',
    ),

    // 12. DATA PRIVACY
    FaqItem(
      category: 'DATA PRIVACY',
      question: 'Can other people see my personal expenses?',
      answer:
          'No! Your personal expenses, budgets, and lending/borrowing records are private to your account. Only group trip expenses are shared with invited trip members.',
    ),

    // 13. TROUBLESHOOTING
    FaqItem(
      category: 'TROUBLESHOOTING',
      question: 'Google Sign-In was cancelled or failed. What do I do?',
      answer:
          'Ensure your device has an active internet connection. If Google Play services is unavailable, Kith provides an instant email verification fallback so you are never blocked.',
    ),
    FaqItem(
      category: 'TROUBLESHOOTING',
      question: 'How do I export my trip summary?',
      answer:
          'Open your trip → tap the menu in the top right → select "Export Summary" to generate CSV reports or shareable plain text breakdowns.',
    ),
  ];

  List<FaqItem> get _filteredFaqs {
    return _allFaqs.where((faq) {
      if (_selectedCategory != null && faq.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return faq.question.toLowerCase().contains(q) ||
          faq.answer.toLowerCase().contains(q) ||
          faq.category.toLowerCase().contains(q);
    }).toList();
  }

  List<String> get _categories {
    final set = <String>{};
    for (final f in _allFaqs) {
      set.add(f.category);
    }
    return set.toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final faqs = _filteredFaqs;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Help & FAQ'),
            Text(
              'Kith by Nirniq',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      ),
      body: Column(
        children: [
          // Interactive Setup Guide Banner
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
            child: InkWell(
              onTap: () {
                HapticHelper.medium();
                Navigator.of(context).pushNamed('/guide');
              },
              borderRadius: AppRadius.mdBorder,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            AppColors.emeraldPrimary.withValues(alpha: 0.25),
                            AppColors.indigoAccent.withValues(alpha: 0.2),
                          ]
                        : [
                            AppColors.emeraldPrimary.withValues(alpha: 0.12),
                            AppColors.indigoAccent.withValues(alpha: 0.08),
                          ],
                  ),
                  borderRadius: AppRadius.mdBorder,
                  border: Border.all(
                    color: AppColors.emeraldPrimary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldPrimary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.menu_book_rounded, color: AppColors.emeraldPrimary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'How Kith Works • Setup Guide',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Interactive feature tour with direct action shortcuts',
                            style: AppTypography.bodySmall(isDark: isDark),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.emeraldPrimary),
                  ],
                ),
              ),
            ),
          ),

          // Search Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() => _searchQuery = val.trim());
              },
              decoration: InputDecoration(
                hintText: 'Search help (e.g. Google, split, offline, recovery)…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.mdBorder,
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.mdBorder,
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                  ),
                ),
              ),
            ),
          ),

          // Category Chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('ALL TOPICS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    selected: _selectedCategory == null,
                    selectedColor: AppColors.emeraldPrimary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.emeraldPrimary,
                    onSelected: (_) {
                      HapticHelper.selection();
                      setState(() => _selectedCategory = null);
                    },
                  ),
                ),
                ..._categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(cat, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      selected: isSelected,
                      selectedColor: AppColors.emeraldPrimary.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.emeraldPrimary,
                      onSelected: (_) {
                        HapticHelper.selection();
                        setState(() => _selectedCategory = isSelected ? null : cat);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // FAQ List
          Expanded(
            child: faqs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'No help topics found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Try searching for "Google", "trips", "recovery", or "split"',
                            style: AppTypography.bodySmall(isDark: isDark),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                    itemCount: faqs.length,
                    itemBuilder: (ctx, index) {
                      final item = faqs[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: SurfaceCard(
                          backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                          padding: EdgeInsets.zero,
                          child: Theme(
                            data: Theme.of(ctx).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              leading: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.emeraldPrimary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.help_outline_rounded,
                                  size: 18,
                                  color: AppColors.emeraldPrimary,
                                ),
                              ),
                              title: Text(
                                item.question,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              subtitle: Text(
                                item.category,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: AppColors.emeraldPrimary,
                                ),
                              ),
                              children: [
                                Text(
                                  item.answer,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
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
}
