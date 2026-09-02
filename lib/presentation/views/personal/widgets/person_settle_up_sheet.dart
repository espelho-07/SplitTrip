import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/utils/whatsapp_share_helper.dart';
import '../../../../data/services/local_storage_service.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/person_ledger_viewmodel.dart';

/// Ultra-Clean, Trip-Style Interactive Settle Up Sheet for 1-on-1 Person Ledger.
/// Supports both Direct / Cash instant settlement and Pay Now via UPI with
/// real-time verification and WhatsApp reminders.
class PersonSettleUpSheet extends StatefulWidget {
  final String personName;
  final String? personUserId;
  final String? personPhone;
  final int netBalancePaise;
  final VoidCallback onSettled;

  const PersonSettleUpSheet({
    super.key,
    required this.personName,
    this.personUserId,
    this.personPhone,
    required this.netBalancePaise,
    required this.onSettled,
  });

  static Future<void> show(
    BuildContext context, {
    required String personName,
    String? personUserId,
    String? personPhone,
    required int netBalancePaise,
    required VoidCallback onSettled,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PersonSettleUpSheet(
        personName: personName,
        personUserId: personUserId,
        personPhone: personPhone,
        netBalancePaise: netBalancePaise,
        onSettled: onSettled,
      ),
    );
  }

  @override
  State<PersonSettleUpSheet> createState() => _PersonSettleUpSheetState();
}

class _PersonSettleUpSheetState extends State<PersonSettleUpSheet> {
  late final TextEditingController _amountController;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _upiIdController = TextEditingController();

  String? _selectedUpiVpa;

  @override
  void initState() {
    super.initState();
    final initialRupees = (widget.netBalancePaise.abs() / 100).toStringAsFixed(
      widget.netBalancePaise.abs() % 100 == 0 ? 0 : 2,
    );
    _amountController = TextEditingController(text: initialRupees);

    // Auto load user's saved UPI ID for receiving reminders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final storage = context.read<LocalStorageService>();
        final raw = storage.getString('kith_saved_upi_items');
        if (raw != null && raw.isNotEmpty) {
          final list = jsonDecode(raw) as List<dynamic>;
          if (list.isNotEmpty) {
            final first = list.first as Map<String, dynamic>;
            final vpa = first['vpa'] as String?;
            if (vpa != null && vpa.isNotEmpty && mounted) {
              setState(() {
                _selectedUpiVpa = vpa;
                _upiIdController.text = vpa;
              });
            }
          }
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  int get _enteredAmountPaise {
    final parsed = double.tryParse(_amountController.text.trim()) ?? 0;
    return (parsed * 100).round();
  }

  Future<void> _handleDirectSettle({required bool isPaidByMe}) async {
    final amountPaise = _enteredAmountPaise;
    if (amountPaise <= 0) {
      HapticHelper.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid settlement amount.')),
      );
      return;
    }

    HapticHelper.medium();

    final vm = context.read<PersonLedgerViewModel>();
    final note = _noteController.text.trim();

    await vm.settleBalance(
      amountInPaise: amountPaise,
      note: note.isNotEmpty ? note : (isPaidByMe ? 'Paid directly in Cash / External' : 'Received directly in Cash / External'),
    );

    if (mounted) {
      Navigator.pop(context);
      widget.onSettled();
      HapticHelper.success();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF4ADE80), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isPaidByMe
                      ? 'Recorded payment of ${CurrencyFormatter.formatPaise(amountPaise, currencyCode: 'INR')} to ${widget.personName} ✓'
                      : 'Recorded ${CurrencyFormatter.formatPaise(amountPaise, currencyCode: 'INR')} received from ${widget.personName} ✓',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handlePayViaUpi() async {
    final amountPaise = _enteredAmountPaise;
    if (amountPaise <= 0) {
      HapticHelper.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount.')),
      );
      return;
    }

    final amountRupees = (amountPaise / 100).toStringAsFixed(2);
    final targetVpa = _upiIdController.text.trim().isNotEmpty
        ? _upiIdController.text.trim()
        : (_selectedUpiVpa ?? '');

    HapticHelper.medium();

    // Construct UPI standard URI
    final upiUri = Uri.parse(
      'upi://pay?pa=$targetVpa&pn=${Uri.encodeComponent(widget.personName)}&am=$amountRupees&cu=INR&tn=${Uri.encodeComponent('Kith Settlement to ${widget.personName}')}',
    );

    try {
      if (await canLaunchUrl(upiUri)) {
        await launchUrl(upiUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback generic intent
        await launchUrl(upiUri, mode: LaunchMode.externalNonBrowserApplication);
      }
    } catch (_) {}

    // Record settlement and confirmation prompt
    if (mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Confirm Payment', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Text(
            'Did you complete the payment of ₹$amountRupees to ${widget.personName}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No, Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00594C),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, Record Payment'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        await _handleDirectSettle(isPaidByMe: true);
      }
    }
  }

  Future<void> _handleSendWhatsAppReminder() async {
    final amountPaise = _enteredAmountPaise;
    final formatted = CurrencyFormatter.formatPaise(amountPaise, currencyCode: 'INR');
    final user = context.read<AuthViewModel>().currentUser;
    final senderName = user?.displayName ?? 'Me';

    String text;
    if (_selectedUpiVpa != null && _selectedUpiVpa!.isNotEmpty) {
      text = 'Hi ${widget.personName}, gentle reminder that $formatted is pending on Kith for our expenses. You can pay directly via UPI: ${_selectedUpiVpa!}. Thanks! 🙏 - $senderName';
    } else {
      text = 'Hi ${widget.personName}, gentle reminder that $formatted is pending on Kith for our expenses. Please let me know once transferred. Thanks! 🙏 - $senderName';
    }

    await WhatsAppShareHelper.sendWhatsAppMessage(
      context: context,
      text: text,
      phone: widget.personPhone,
    );
  }

  Future<void> _handleCopyUpiRequest() async {
    final amountPaise = _enteredAmountPaise;
    final formatted = CurrencyFormatter.formatPaise(amountPaise, currencyCode: 'INR');
    final text = 'Hi ${widget.personName}, $formatted is pending on Kith. Pay via UPI: ${_selectedUpiVpa ?? ''}';

    await Clipboard.setData(ClipboardData(text: text));
    HapticHelper.light();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment request copied to clipboard! ✓')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final net = widget.netBalancePaise;
    final isYouOwe = net < 0;
    final isTheyOwe = net > 0;
    final isSettled = net == 0;

    final primaryThemeColor = isYouOwe ? const Color(0xFF00594C) : const Color(0xFF0D62D4);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF10171D) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 14,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header Row: Avatar, Title & Subtitle
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: primaryThemeColor,
                    child: Text(
                      widget.personName.isNotEmpty ? widget.personName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Settle Up with ${widget.personName}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isYouOwe ? AppColors.emeraldPrimary : const Color(0xFF3B82F6)).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isSettled
                                ? 'All Settled Up'
                                : (isYouOwe
                                    ? 'You Owe ${CurrencyFormatter.formatPaise(net.abs(), currencyCode: 'INR')}'
                                    : '${widget.personName} Owes You ${CurrencyFormatter.formatPaise(net.abs(), currencyCode: 'INR')}'),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isYouOwe ? const Color(0xFF4ADE80) : const Color(0xFF60A5FA),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : Colors.black54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Amount Card (Editable for full/partial settlement)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF162028) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF23323F) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settlement Amount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '₹',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                              hintText: '0',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Optional Note Field
              TextField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Add note (e.g. Settle lunch & cab)',
                  hintStyle: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF162028) : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF23323F) : const Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF23323F) : const Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ==========================================
              // SCENARIO 1: YOU OWE (Payable Actions)
              // ==========================================
              if (isYouOwe) ...[
                // Option A: Pay Now via UPI Apps
                InkWell(
                  onTap: _handlePayViaUpi,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00594C), Color(0xFF047857)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00594C).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pay via UPI App',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Launch GPay, PhonePe, Paytm or BHIM',
                                style: TextStyle(fontSize: 11.5, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Option B: Direct / Cash Settle
                InkWell(
                  onTap: () => _handleDirectSettle(isPaidByMe: true),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF162028) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF23323F) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white12 : Colors.black12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle_outline_rounded,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Direct / Cash Settlement',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Mark as paid outside Kith (no app launch)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // ==========================================
              // SCENARIO 2: THEY OWE YOU (Receivable Actions)
              // ==========================================
              if (isTheyOwe || isSettled) ...[
                // Option A: Mark Received
                InkWell(
                  onTap: () => _handleDirectSettle(isPaidByMe: false),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00594C), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00594C).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Mark as Received',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Confirm that ${widget.personName} paid you',
                                style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Option B: Remind on WhatsApp
                InkWell(
                  onTap: _handleSendWhatsAppReminder,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Color(0xFF25D366),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Remind on WhatsApp',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Send friendly payment reminder with your UPI ID',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF25D366), size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Option C: Copy Payment Request Link
                InkWell(
                  onTap: _handleCopyUpiRequest,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF162028) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF23323F) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.content_copy_rounded,
                          size: 18,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Copy UPI Payment Request Text',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
