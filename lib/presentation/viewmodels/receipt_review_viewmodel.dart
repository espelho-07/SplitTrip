import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/duplicate_receipt_detector.dart';
import '../../domain/enums/expense_category.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/receipt_data.dart';

/// ViewModel managing state for the Receipt Review & Correction experience.
class ReceiptReviewViewModel extends ChangeNotifier {
  ReceiptData _receipt;
  final List<Expense> _existingTripExpenses;
  DuplicateReceiptMatch? _duplicateMatch;
  final Uuid _uuid;

  ReceiptReviewViewModel({
    required ReceiptData initialReceipt,
    this._existingTripExpenses = const [],
    Uuid? uuid,
  })  : _receipt = initialReceipt,
        _uuid = uuid ?? const Uuid() {
    _checkForDuplicates();
  }

  ReceiptData get receipt => _receipt;
  DuplicateReceiptMatch? get duplicateMatch => _duplicateMatch;
  int get calculatedTotalInPaise => _receipt.calculatedTotalInPaise;
  bool get isConsistent => _receipt.isCalculationConsistent;
  int get differenceInPaise => _receipt.calculationDifferenceInPaise;

  void _checkForDuplicates() {
    _duplicateMatch = DuplicateReceiptDetector.detectDuplicate(
      receipt: _receipt,
      existingExpenses: _existingTripExpenses,
    );
  }

  void updateMerchant({
    String? name,
    String? address,
    String? phone,
    String? gstin,
  }) {
    _receipt = _receipt.copyWith(
      merchant: _receipt.merchant.copyWith(
        name: name,
        address: address,
        phone: phone,
        gstin: gstin,
      ),
    );
    _checkForDuplicates();
    notifyListeners();
  }

  void updateMetadata({
    String? receiptNumber,
    DateTime? date,
    String? time,
  }) {
    _receipt = _receipt.copyWith(
      receipt: _receipt.receipt.copyWith(
        receiptNumber: receiptNumber,
        date: date,
        time: time,
      ),
    );
    _checkForDuplicates();
    notifyListeners();
  }

  void updateCategory(ExpenseCategory cat) {
    _receipt = _receipt.copyWith(predictedCategory: cat);
    notifyListeners();
  }

  void updateItem(
    String id, {
    String? name,
    double? quantity,
    int? unitPriceInPaise,
    int? totalPriceInPaise,
  }) {
    final updatedItems = _receipt.items.map((item) {
      if (item.id != id) return item;

      final newQty = quantity ?? item.quantity;
      final newUnitPrice = unitPriceInPaise ?? item.unitPriceInPaise;
      // Auto-recalculate line total if qty or unit price changed without explicit line total
      final newTotal = totalPriceInPaise ?? (newQty * newUnitPrice).round();

      return item.copyWith(
        name: name ?? item.name,
        quantity: newQty,
        unitPriceInPaise: newUnitPrice,
        totalPriceInPaise: newTotal,
      );
    }).toList();

    _receipt = _receipt.copyWith(items: updatedItems);
    _syncSummaryFromItems();
    notifyListeners();
  }

  void addItem({
    required String name,
    double quantity = 1.0,
    required int unitPriceInPaise,
    int? totalPriceInPaise,
  }) {
    final lineTotal = totalPriceInPaise ?? (quantity * unitPriceInPaise).round();
    final newItem = ReceiptItem(
      id: _uuid.v4(),
      name: name,
      quantity: quantity,
      unitPriceInPaise: unitPriceInPaise,
      totalPriceInPaise: lineTotal,
      confidence: 1.0,
    );

    final updatedItems = List<ReceiptItem>.from(_receipt.items)..add(newItem);
    _receipt = _receipt.copyWith(items: updatedItems);
    _syncSummaryFromItems();
    notifyListeners();
  }

  void removeItem(String id) {
    final updatedItems = _receipt.items.where((i) => i.id != id).toList();
    _receipt = _receipt.copyWith(items: updatedItems);
    _syncSummaryFromItems();
    notifyListeners();
  }

  void _syncSummaryFromItems() {
    // When line items are added or modified, update subtotal to reflect items sum
    final itemsSum = _receipt.itemsSumInPaise;
    final int currentSubtotal = _receipt.items.isNotEmpty
        ? itemsSum
        : (_receipt.summary.subtotalInPaise ?? 0);

    // Recalculate grand total
    final discount = _receipt.summary.discountInPaise ?? 0;
    final taxes = _receipt.summary.totalTaxesInPaise;
    final charges = _receipt.summary.additionalChargesInPaise ?? 0;
    final tip = _receipt.summary.tipInPaise ?? 0;
    final roundOff = _receipt.summary.roundOffInPaise ?? 0;

    final rawExpected = currentSubtotal - discount + taxes + charges + tip + roundOff;
    final expectedTotal = rawExpected > 0 ? rawExpected : 0;

    _receipt = _receipt.copyWith(
      summary: _receipt.summary.copyWith(
        subtotalInPaise: currentSubtotal > 0 ? currentSubtotal : null,
        totalInPaise: expectedTotal > 0
            ? expectedTotal
            : (_receipt.items.isEmpty ? _receipt.summary.totalInPaise : 0),
      ),
    );
    _checkForDuplicates();
  }

  void updateSummary({
    int? subtotalInPaise,
    int? discountInPaise,
    int? totalInPaise,
    int? roundOffInPaise,
    int? additionalChargesInPaise,
    int? tipInPaise,
    List<ReceiptTaxItem>? taxes,
  }) {
    _receipt = _receipt.copyWith(
      summary: _receipt.summary.copyWith(
        subtotalInPaise: subtotalInPaise,
        discountInPaise: discountInPaise,
        totalInPaise: totalInPaise,
        roundOffInPaise: roundOffInPaise,
        additionalChargesInPaise: additionalChargesInPaise,
        tipInPaise: tipInPaise,
        taxes: taxes,
      ),
    );
    _checkForDuplicates();
    notifyListeners();
  }

  void applyCalculatedTotal() {
    final calculated = _receipt.calculatedTotalInPaise;
    if (calculated > 0) {
      updateSummary(totalInPaise: calculated);
    }
  }
}
