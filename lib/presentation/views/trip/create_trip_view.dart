import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/create_trip_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';

/// Minimal, clean, Apple-inspired Create Trip Experience for Kith.
class CreateTripView extends StatefulWidget {
  const CreateTripView({super.key});

  @override
  State<CreateTripView> createState() => _CreateTripViewState();
}

class _CreateTripViewState extends State<CreateTripView> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _friendController = TextEditingController();
  bool _showEmojiPicker = false;

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
    {'code': 'AED', 'symbol': 'AED', 'label': 'AED'},
  ];

  static const List<Map<String, String>> _quickIdeas = [
    {'name': 'Goa', 'emoji': '🏖️'},
    {'name': 'Manali', 'emoji': '🏔️'},
    {'name': 'Weekend Dinner', 'emoji': '🍕'},
    {'name': 'Road Trip', 'emoji': '🚗'},
    {'name': 'Birthday Party', 'emoji': '🎉'},
  ];

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

    if (createVm.isCreating) return;

    final user = authVm.currentUser;
    if (user == null) return;

    if (!createVm.isValid) {
      HapticHelper.medium();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a trip name'),
          backgroundColor: AppColors.negativeRedDark,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticHelper.medium();
    final trip = await createVm.createTrip(user);

    if (trip != null && mounted) {
      homeVm.refresh(user.id);
      context.go('/trip/${trip.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final createVm = context.watch<CreateTripViewModel>();

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, size: 22, color: textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Create Trip',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              // 1. Trip Name & Emoji Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trip name',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Emoji Picker Button
                        GestureDetector(
                          onTap: () {
                            HapticHelper.light();
                            setState(() => _showEmojiPicker = !_showEmojiPicker);
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(createVm.emoji, style: const TextStyle(fontSize: 22)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Trip Name Input
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            autofocus: true,
                            onChanged: createVm.setName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. Goa 2026',
                              hintStyle: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Collapsible Emoji Tray
                    if (_showEmojiPicker) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _emojis.map((em) {
                          final isSelected = createVm.emoji == em;
                          return GestureDetector(
                            onTap: () {
                              HapticHelper.selection();
                              createVm.setEmoji(em);
                              setState(() => _showEmojiPicker = false);
                            },
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark ? AppColors.emeraldLight.withValues(alpha: 0.3) : AppColors.emeraldPrimary.withValues(alpha: 0.15))
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: isSelected
                                    ? Border.all(color: AppColors.emeraldPrimary, width: 1.5)
                                    : null,
                              ),
                              child: Center(
                                child: Text(em, style: const TextStyle(fontSize: 20)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Quick Idea Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickIdeas.map((idea) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          HapticHelper.light();
                          _nameController.text = idea['name']!;
                          createVm.setName(idea['name']!);
                          createVm.setEmoji(idea['emoji']!);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor, width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(idea['emoji']!, style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(
                                idea['name']!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              // 2. Who's Coming Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Who's coming?",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textSecondary),
                        ),
                        Text(
                          '${createVm.friendNames.length + 1} members',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Add Person Input
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor, width: 0.8),
                            ),
                            child: TextField(
                              controller: _friendController,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _addFriend(),
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Add friend name (e.g. Rahul)',
                                hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _addFriend,
                          style: IconButton.styleFrom(
                            backgroundColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 20),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Member Chips (You + Friends)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // You (Creator)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'You (Admin)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Added Friends
                        ...createVm.friendNames.map((name) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textPrimary),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () {
                                    HapticHelper.light();
                                    createVm.removeFriendName(name);
                                  },
                                  child: Icon(Icons.close_rounded, size: 14, color: textSecondary),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3. Currency Selector
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Currency',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: _currencies.map((curr) {
                        final isSelected = createVm.currencyCode == curr['code'];
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticHelper.selection();
                              createVm.setCurrencyCode(curr['code']!);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                                    : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? Colors.transparent : borderColor,
                                  width: 0.8,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  curr['label']!,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Sticky Bottom "Create Trip" Button
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: createVm.isCreating ? null : _handleCreate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: createVm.isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Create Trip',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
