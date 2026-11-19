import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/services/duplicate_receipt_detector.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../domain/models/expense.dart';
import '../../../domain/models/receipt_data.dart';
import '../../viewmodels/receipt_review_viewmodel.dart';

/// Production-grade Receipt Review & Correction Screen.
/// Gives users complete control to review, edit, and validate all extracted fields
/// before transferring confirmed data into the Add Expense flow.
class ReceiptReviewView extends StatefulWidget {
  final ReceiptData initialReceipt;
  final List<Expense> existingTripExpenses;
  final ValueChanged<ReceiptData> onConfirmed;

  const ReceiptReviewView({
    super.key,
    required this.initialReceipt,
    this.existingTripExpenses = const [],
    required this.onConfirmed,
  });

  @override
  State<ReceiptReviewView> createState() => _ReceiptReviewViewState();
}

class _ReceiptReviewViewState extends State<ReceiptReviewView> {
  late final ReceiptReviewViewModel _viewModel;
  late final TextEditingController _merchantController;
  late final TextEditingController _addressController;
  late final TextEditingController _receiptNumController;
  late final TextEditingController _totalController;

  @override
  void initState() {
    super.initState();
    _viewModel = ReceiptReviewViewModel(
      initialReceipt: widget.initialReceipt,
      existingTripExpenses: widget.existingTripExpenses,
    );

    _merchantController = TextEditingController(text: _viewModel.receipt.merchant.name ?? '');
    _addressController = TextEditingController(text: _viewModel.receipt.merchant.address ?? '');
    _receiptNumController = TextEditingController(text: _viewModel.receipt.receipt.receiptNumber ?? '');
    final totalRupees = (_viewModel.receipt.summary.totalInPaise ?? 0) / 100.0;
    _totalController = TextEditingController(
      text: totalRupees > 0 ? (totalRupees % 1 == 0 ? totalRupees.toInt().toString() : totalRupees.toStringAsFixed(2)) : '',
    );
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _addressController.dispose();
    _receiptNumController.dispose();
    _totalController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _showFullScreenImage(BuildContext context, String imagePath) {
    HapticHelper.light();
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.5,
                  child: File(imagePath).existsSync()
                      ? Image.file(File(imagePath), fit: BoxFit.contain)
                      : const Center(
                          child: Text('Receipt image unavailable', style: TextStyle(color: Colors.white)),
                        ),
                ),
              ),
              Positioned(
                top: 40,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    HapticHelper.selection();
    final current = _viewModel.receipt.receipt.date ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      _viewModel.updateMetadata(date: picked);
    }
  }

  void _showAddItemDialog(BuildContext context) {
    HapticHelper.medium();
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2630) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add Receipt Item',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Item Name',
                    hintText: 'e.g. Masala Dosa',
                  ),
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Qty'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Unit Price (₹)',
                          prefixText: '₹ ',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                AppButton(
                  text: 'Add to Receipt',
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
                    final priceRupees = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                    final unitPricePaise = (priceRupees * 100).round();

                    if (name.isNotEmpty && unitPricePaise > 0) {
                      _viewModel.addItem(
                        name: name,
                        quantity: qty,
                        unitPriceInPaise: unitPricePaise,
                      );
                      HapticHelper.light();
                      Navigator.of(ctx).pop();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditItemDialog(BuildContext context, ReceiptItem item) {
    HapticHelper.medium();
    final nameCtrl = TextEditingController(text: item.name);
    final qtyCtrl = TextEditingController(text: item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toString());
    final priceRupees = item.unitPriceInPaise / 100.0;
    final priceCtrl = TextEditingController(text: priceRupees % 1 == 0 ? priceRupees.toInt().toString() : priceRupees.toStringAsFixed(2));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2630) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit Item',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Item Name'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Qty'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Unit Price (₹)',
                          prefixText: '₹ ',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                      onPressed: () {
                        _viewModel.removeItem(item.id);
                        Navigator.of(ctx).pop();
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        text: 'Save Changes',
                        onPressed: () {
                          final name = nameCtrl.text.trim();
                          final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
                          final priceRupees = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                          final unitPricePaise = (priceRupees * 100).round();

                          if (name.isNotEmpty && unitPricePaise > 0) {
                            _viewModel.updateItem(
                              item.id,
                              name: name,
                              quantity: qty,
                              unitPriceInPaise: unitPricePaise,
                            );
                            Navigator.of(ctx).pop();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditTotalDialog(BuildContext context, ReceiptReviewViewModel vm, int currentTotalPaise) {
    HapticHelper.medium();
    final totalRupees = currentTotalPaise > 0 ? (currentTotalPaise / 100.0) : 0.0;
    final totalCtrl = TextEditingController(
      text: totalRupees > 0
          ? (totalRupees % 1 == 0 ? totalRupees.toInt().toString() : totalRupees.toStringAsFixed(2))
          : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2630) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit Grand Total',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: totalCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Total Amount (₹)',
                    hintText: 'e.g. 450.00',
                    prefixText: '₹ ',
                  ),
                ),
                const SizedBox(height: 20),
                AppButton(
                  text: 'Save Total',
                  onPressed: () {
                    final entered = double.tryParse(totalCtrl.text.trim()) ?? 0.0;
                    final paise = (entered * 100).round();
                    if (paise > 0) {
                      vm.updateSummary(totalInPaise: paise);
                      _totalController.text = totalCtrl.text.trim();
                      HapticHelper.light();
                      Navigator.of(ctx).pop();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleContinue() {
    HapticHelper.light();
    final receipt = _viewModel.receipt;
    final totalInPaise = receipt.summary.totalInPaise ?? receipt.calculatedTotalInPaise;

    if (totalInPaise <= 0) {
      HapticHelper.warning();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify or enter the total receipt amount before continuing.'),
          backgroundColor: Color(0xFFE11D48),
        ),
      );
      return;
    }

    final confirmedReceipt = receipt.copyWith(
      merchant: receipt.merchant.copyWith(
        name: _merchantController.text.trim().isNotEmpty
            ? _merchantController.text.trim()
            : 'Receipt Expense',
        address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
      ),
      receipt: receipt.receipt.copyWith(
        receiptNumber: _receiptNumController.text.trim().isNotEmpty ? _receiptNumController.text.trim() : null,
      ),
      summary: receipt.summary.copyWith(totalInPaise: totalInPaise),
    );

    widget.onConfirmed(confirmedReceipt);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChangeNotifierProvider<ReceiptReviewViewModel>.value(
      value: _viewModel,
      child: Consumer<ReceiptReviewViewModel>(
        builder: (context, vm, _) {
          final receipt = vm.receipt;
          final totalPaise = receipt.summary.totalInPaise ?? vm.calculatedTotalInPaise;
          final dateStr = receipt.receipt.date != null
              ? DateFormat('dd MMM yyyy').format(receipt.receipt.date!)
              : 'Select Date';

          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
            appBar: AppBar(
              backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text(
                'Review Receipt 🧾',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // SECTION A: IMAGE PREVIEW & CONFIDENCE
                  _buildImageAndConfidenceSection(context, isDark, receipt, vm),
                  const SizedBox(height: 16),

                  // DUPLICATE ALERT (IF ANY)
                  if (vm.duplicateMatch != null) ...[
                    _buildDuplicateAlertCard(isDark, vm.duplicateMatch!),
                    const SizedBox(height: 16),
                  ],

                  // SECTION B: MERCHANT INFORMATION CARD
                  _buildMerchantCard(isDark, dateStr),
                  const SizedBox(height: 16),

                  // SECTION C: PURCHASED ITEMS CARD
                  _buildItemsCard(context, isDark, vm),
                  const SizedBox(height: 16),

                  // SECTION D: BILL BREAKDOWN & TOTAL
                  _buildBreakdownCard(isDark, receipt, vm, totalPaise),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            bottomNavigationBar: _buildBottomBar(isDark, totalPaise),
          );
        },
      ),
    );
  }

  Widget _buildImageAndConfidenceSection(
    BuildContext context,
    bool isDark,
    ReceiptData receipt,
    ReceiptReviewViewModel vm,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141A21) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF222B35) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Thumbnail with tap to expand
          GestureDetector(
            onTap: () => _showFullScreenImage(context, receipt.imagePath),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 96,
                    color: isDark ? Colors.black26 : Colors.grey[200],
                    child: File(receipt.imagePath).existsSync()
                        ? Image.file(File(receipt.imagePath), fit: BoxFit.cover)
                        : const Icon(Icons.receipt_long_rounded, color: Colors.grey),
                  ),
                  Container(
                    width: 72,
                    height: 96,
                    color: Colors.black.withValues(alpha: 0.2),
                    child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 24),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          // OCR Status & Warnings
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: receipt.ocr.confidence == OcrConfidenceLevel.high
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            receipt.ocr.confidence == OcrConfidenceLevel.high
                                ? Icons.check_circle_rounded
                                : Icons.info_outline_rounded,
                            size: 13,
                            color: receipt.ocr.confidence == OcrConfidenceLevel.high
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            receipt.ocr.confidence == OcrConfidenceLevel.high
                                ? 'High Confidence'
                                : 'Needs Verification',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: receipt.ocr.confidence == OcrConfidenceLevel.high
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  receipt.ocr.warnings.isNotEmpty
                      ? receipt.ocr.warnings.first
                      : 'Receipt scanned and structured items extracted.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!vm.isConsistent && vm.differenceInPaise != 0) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      HapticHelper.selection();
                      vm.applyCalculatedTotal();
                      final totalRupees = vm.calculatedTotalInPaise / 100.0;
                      _totalController.text = totalRupees % 1 == 0
                          ? totalRupees.toInt().toString()
                          : totalRupees.toStringAsFixed(2);
                    },
                    child: const Text(
                      '⚡ Sync Total to Items Sum',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0EA5E9),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuplicateAlertCard(bool isDark, DuplicateReceiptMatch match) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Potential Duplicate Receipt',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B)),
                ),
                const SizedBox(height: 2),
                Text(
                  match.reason,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMerchantCard(bool isDark, String dateStr) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141A21) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF222B35) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MERCHANT DETAILS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _merchantController,
            decoration: const InputDecoration(
              labelText: 'Merchant / Place Name',
              prefixIcon: Icon(Icons.storefront_rounded, size: 20),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _receiptNumController,
                  decoration: const InputDecoration(
                    labelText: 'Receipt / Bill No.',
                    prefixIcon: Icon(Icons.tag_rounded, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(context),
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                    ),
                    child: Text(dateStr, style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
          if (_addressController.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(Icons.location_on_outlined, size: 18),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsCard(BuildContext context, bool isDark, ReceiptReviewViewModel vm) {
    final items = vm.receipt.items;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141A21) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF222B35) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PURCHASED ITEMS (${items.length})',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: Colors.grey),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Item', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                onPressed: () => _showAddItemDialog(context),
              ),
            ],
          ),
          if (items.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No itemized breakdown found. You can add items manually.', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            ),
          ] else ...[
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (ctx, index) {
                final item = items[index];
                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onTap: () => _showEditItemDialog(context, item),
                    title: Text(
                      item.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} × ${CurrencyFormatter.formatPaise(item.unitPriceInPaise)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          CurrencyFormatter.formatPaise(item.totalPriceInPaise),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreakdownCard(
    bool isDark,
    ReceiptData receipt,
    ReceiptReviewViewModel vm,
    int totalPaise,
  ) {
    final summary = receipt.summary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141A21) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF222B35) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BILL BREAKDOWN',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          if (summary.subtotalInPaise != null)
            _buildSummaryRow('Subtotal', CurrencyFormatter.formatPaise(summary.subtotalInPaise!)),
          if (summary.discountInPaise != null && summary.discountInPaise! > 0)
            _buildSummaryRow('Discount', '- ${CurrencyFormatter.formatPaise(summary.discountInPaise!)}', isGreen: true),
          for (final tax in summary.taxes)
            _buildSummaryRow(
              '${tax.name}${tax.rate != null ? " (${tax.rate}%)" : ""}',
              '+ ${CurrencyFormatter.formatPaise(tax.amountInPaise)}',
            ),
          if (summary.additionalChargesInPaise != null && summary.additionalChargesInPaise! > 0)
            _buildSummaryRow('Service / Extra Charges', '+ ${CurrencyFormatter.formatPaise(summary.additionalChargesInPaise!)}'),
          if (summary.roundOffInPaise != null && summary.roundOffInPaise != 0)
            _buildSummaryRow('Round Off', CurrencyFormatter.formatPaise(summary.roundOffInPaise!)),
          const Divider(height: 20),
          InkWell(
            onTap: () => _showEditTotalDialog(context, vm, totalPaise),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Grand Total',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ],
                  ),
                  if (totalPaise > 0)
                    Text(
                      CurrencyFormatter.formatPaise(totalPaise),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF10B981),
                      ),
                    )
                  else
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Tap to enter total',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.edit_rounded, size: 14, color: Color(0xFFF59E0B)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isGreen ? const Color(0xFF10B981) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isDark, int totalPaise) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, -3),
            blurRadius: 8,
          ),
        ],
      ),
      child: AppButton(
        text: 'Continue to Add Expense (${CurrencyFormatter.formatPaise(totalPaise)})',
        onPressed: _handleContinue,
      ),
    );
  }
}
