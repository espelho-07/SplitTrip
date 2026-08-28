import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/payment/upi_validator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../data/services/local_storage_service.dart';

class SettleUpView extends StatefulWidget {
  const SettleUpView({super.key});

  @override
  State<SettleUpView> createState() => _SettleUpViewState();
}

class _SettleUpViewState extends State<SettleUpView> {
  final Set<String> _selectedPeople = {'Rohan', 'Priya', 'Karan'};
  final TextEditingController _upiController = TextEditingController(text: 'darpan@okhdfcbank');
  String? _upiError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final storage = context.read<LocalStorageService>();
        final raw = storage.getString('kith_saved_upi_items');
        if (raw != null && raw.isNotEmpty) {
          final list = jsonDecode(raw) as List<dynamic>;
          if (list.isNotEmpty) {
            final first = list.first as Map<String, dynamic>;
            final vpa = first['vpa'] as String?;
            if (vpa != null && vpa.isNotEmpty) {
              setState(() {
                _upiController.text = vpa;
              });
            }
          }
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _upiController.dispose();
    super.dispose();
  }

  void _handleSendRequest() {
    final vpa = _upiController.text.trim();
    if (!UpiValidator.isValidUpiId(vpa)) {
      setState(() {
        _upiError = 'Please enter a valid UPI ID (e.g. name@okhdfcbank)';
      });
      HapticHelper.heavy();
      return;
    }

    setState(() => _upiError = null);
    HapticHelper.success();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment request for ₹ 2,450 sent to selected members with UPI: $vpa! ✓')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final people = [
      {'name': 'Rohan', 'amount': '₹ 1,200', 'status': 'Pending'},
      {'name': 'Priya', 'amount': '₹ 650', 'status': 'Pending'},
      {'name': 'Karan', 'amount': '₹ 600', 'status': 'Pending'},
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Settle Up', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  // Hero Card: Total you will receive ₹ 2,450
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F1418) : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total you will receive',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '₹ 2,450',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF14B8A6),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
                          ),
                          alignment: Alignment.center,
                          child: const Text('💵', style: TextStyle(fontSize: 28)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Select people to settle up with',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // People checkbox list
                  for (final p in people)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F1418) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Checkbox.adaptive(
                            value: _selectedPeople.contains(p['name']),
                            activeColor: const Color(0xFF14B8A6),
                            onChanged: (val) {
                              HapticHelper.selection();
                              setState(() {
                                if (val == true) {
                                  _selectedPeople.add(p['name']!);
                                } else {
                                  _selectedPeople.remove(p['name']!);
                                }
                              });
                            },
                          ),
                          MemberAvatar(name: p['name']!, size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['name']!,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                                Text(
                                  'via UPI Direct',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            p['amount']!,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // UPI ID field
                  TextField(
                    controller: _upiController,
                    decoration: InputDecoration(
                      labelText: 'Your Receiving UPI ID',
                      hintText: 'yourname@upi',
                      errorText: _upiError,
                      prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F1418) : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom CTA
            GestureDetector(
              onTap: _handleSendRequest,
              child: Container(
                height: 52,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Request ₹ 2,450 via UPI',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Members will receive your UPI payment link notification',
              style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
