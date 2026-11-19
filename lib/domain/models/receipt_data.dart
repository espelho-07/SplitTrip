import 'package:uuid/uuid.dart';
import '../enums/expense_category.dart';

enum OcrConfidenceLevel {
  high,
  needsVerification,
  low,
}

class ReceiptMerchant {
  final String? name;
  final String? address;
  final String? phone;
  final String? gstin;

  const ReceiptMerchant({
    this.name,
    this.address,
    this.phone,
    this.gstin,
  });

  ReceiptMerchant copyWith({
    String? name,
    String? address,
    String? phone,
    String? gstin,
  }) {
    return ReceiptMerchant(
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      gstin: gstin ?? this.gstin,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'address': address,
    'phone': phone,
    'gstin': gstin,
  };

  factory ReceiptMerchant.fromJson(Map<String, dynamic> json) => ReceiptMerchant(
    name: json['name'] as String?,
    address: json['address'] as String?,
    phone: json['phone'] as String?,
    gstin: json['gstin'] as String?,
  );
}

class ReceiptMetadata {
  final String? receiptNumber;
  final DateTime? date;
  final String? time;
  final String currency;

  const ReceiptMetadata({
    this.receiptNumber,
    this.date,
    this.time,
    this.currency = 'INR',
  });

  ReceiptMetadata copyWith({
    String? receiptNumber,
    DateTime? date,
    String? time,
    String? currency,
  }) {
    return ReceiptMetadata(
      receiptNumber: receiptNumber ?? this.receiptNumber,
      date: date ?? this.date,
      time: time ?? this.time,
      currency: currency ?? this.currency,
    );
  }

  Map<String, dynamic> toJson() => {
    'receiptNumber': receiptNumber,
    'date': date?.toIso8601String(),
    'time': time,
    'currency': currency,
  };

  factory ReceiptMetadata.fromJson(Map<String, dynamic> json) => ReceiptMetadata(
    receiptNumber: json['receiptNumber'] as String?,
    date: json['date'] != null ? DateTime.tryParse(json['date'] as String) : null,
    time: json['time'] as String?,
    currency: (json['currency'] as String?) ?? 'INR',
  );
}

class ReceiptTaxItem {
  final String name;
  final double? rate;
  final int amountInPaise;

  const ReceiptTaxItem({
    required this.name,
    this.rate,
    required this.amountInPaise,
  });

  ReceiptTaxItem copyWith({
    String? name,
    double? rate,
    int? amountInPaise,
  }) {
    return ReceiptTaxItem(
      name: name ?? this.name,
      rate: rate ?? this.rate,
      amountInPaise: amountInPaise ?? this.amountInPaise,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'rate': rate,
    'amountInPaise': amountInPaise,
  };

  factory ReceiptTaxItem.fromJson(Map<String, dynamic> json) => ReceiptTaxItem(
    name: (json['name'] ?? 'Tax').toString(),
    rate: (json['rate'] as num?)?.toDouble(),
    amountInPaise: (json['amountInPaise'] as num?)?.toInt() ?? 0,
  );
}

class ReceiptItem {
  final String id;
  final String name;
  final double quantity;
  final int unitPriceInPaise;
  final int totalPriceInPaise;
  final double confidence;

  const ReceiptItem({
    required this.id,
    required this.name,
    this.quantity = 1.0,
    required this.unitPriceInPaise,
    required this.totalPriceInPaise,
    this.confidence = 1.0,
  });

  ReceiptItem copyWith({
    String? id,
    String? name,
    double? quantity,
    int? unitPriceInPaise,
    int? totalPriceInPaise,
    double? confidence,
  }) {
    return ReceiptItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unitPriceInPaise: unitPriceInPaise ?? this.unitPriceInPaise,
      totalPriceInPaise: totalPriceInPaise ?? this.totalPriceInPaise,
      confidence: confidence ?? this.confidence,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'unitPriceInPaise': unitPriceInPaise,
    'totalPriceInPaise': totalPriceInPaise,
    'confidence': confidence,
  };

  factory ReceiptItem.fromJson(Map<String, dynamic> json) => ReceiptItem(
    id: (json['id'] ?? const Uuid().v4()).toString(),
    name: (json['name'] ?? 'Item').toString(),
    quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
    unitPriceInPaise: (json['unitPriceInPaise'] as num?)?.toInt() ?? 0,
    totalPriceInPaise: (json['totalPriceInPaise'] as num?)?.toInt() ?? 0,
    confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
  );
}

class ReceiptSummary {
  final int? subtotalInPaise;
  final int? discountInPaise;
  final List<ReceiptTaxItem> taxes;
  final int? additionalChargesInPaise;
  final int? tipInPaise;
  final int? roundOffInPaise;
  final int? totalInPaise;

  const ReceiptSummary({
    this.subtotalInPaise,
    this.discountInPaise,
    this.taxes = const [],
    this.additionalChargesInPaise,
    this.tipInPaise,
    this.roundOffInPaise,
    this.totalInPaise,
  });

  int get totalTaxesInPaise {
    return taxes.fold<int>(0, (sum, t) => sum + t.amountInPaise);
  }

  ReceiptSummary copyWith({
    int? subtotalInPaise,
    int? discountInPaise,
    List<ReceiptTaxItem>? taxes,
    int? additionalChargesInPaise,
    int? tipInPaise,
    int? roundOffInPaise,
    int? totalInPaise,
  }) {
    return ReceiptSummary(
      subtotalInPaise: subtotalInPaise ?? this.subtotalInPaise,
      discountInPaise: discountInPaise ?? this.discountInPaise,
      taxes: taxes ?? this.taxes,
      additionalChargesInPaise: additionalChargesInPaise ?? this.additionalChargesInPaise,
      tipInPaise: tipInPaise ?? this.tipInPaise,
      roundOffInPaise: roundOffInPaise ?? this.roundOffInPaise,
      totalInPaise: totalInPaise ?? this.totalInPaise,
    );
  }

  Map<String, dynamic> toJson() => {
    'subtotalInPaise': subtotalInPaise,
    'discountInPaise': discountInPaise,
    'taxes': taxes.map((t) => t.toJson()).toList(),
    'additionalChargesInPaise': additionalChargesInPaise,
    'tipInPaise': tipInPaise,
    'roundOffInPaise': roundOffInPaise,
    'totalInPaise': totalInPaise,
  };

  factory ReceiptSummary.fromJson(Map<String, dynamic> json) => ReceiptSummary(
    subtotalInPaise: (json['subtotalInPaise'] as num?)?.toInt(),
    discountInPaise: (json['discountInPaise'] as num?)?.toInt(),
    taxes: (json['taxes'] as List<dynamic>?)
            ?.map((t) => ReceiptTaxItem.fromJson(t as Map<String, dynamic>))
            .toList() ??
        const [],
    additionalChargesInPaise: (json['additionalChargesInPaise'] as num?)?.toInt(),
    tipInPaise: (json['tipInPaise'] as num?)?.toInt(),
    roundOffInPaise: (json['roundOffInPaise'] as num?)?.toInt(),
    totalInPaise: (json['totalInPaise'] as num?)?.toInt(),
  );
}

class ReceiptPayment {
  final String? method;

  const ReceiptPayment({this.method});

  ReceiptPayment copyWith({String? method}) => ReceiptPayment(method: method ?? this.method);

  Map<String, dynamic> toJson() => {'method': method};

  factory ReceiptPayment.fromJson(Map<String, dynamic> json) => ReceiptPayment(
    method: json['method'] as String?,
  );
}

class ReceiptOcrResult {
  final String status;
  final OcrConfidenceLevel confidence;
  final List<String> warnings;
  final String rawText;

  const ReceiptOcrResult({
    this.status = 'completed',
    this.confidence = OcrConfidenceLevel.high,
    this.warnings = const [],
    this.rawText = '',
  });

  ReceiptOcrResult copyWith({
    String? status,
    OcrConfidenceLevel? confidence,
    List<String>? warnings,
    String? rawText,
  }) {
    return ReceiptOcrResult(
      status: status ?? this.status,
      confidence: confidence ?? this.confidence,
      warnings: warnings ?? this.warnings,
      rawText: rawText ?? this.rawText,
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'confidence': confidence.name,
    'warnings': warnings,
    'rawText': rawText,
  };

  factory ReceiptOcrResult.fromJson(Map<String, dynamic> json) => ReceiptOcrResult(
    status: (json['status'] ?? 'completed').toString(),
    confidence: OcrConfidenceLevel.values.firstWhere(
      (c) => c.name == json['confidence'],
      orElse: () => OcrConfidenceLevel.needsVerification,
    ),
    warnings: (json['warnings'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    rawText: (json['rawText'] ?? '').toString(),
  );
}

class ReceiptData {
  final String id;
  final String imagePath;
  final ReceiptMerchant merchant;
  final ReceiptMetadata receipt;
  final List<ReceiptItem> items;
  final ReceiptSummary summary;
  final ReceiptPayment payment;
  final ReceiptOcrResult ocr;
  final ExpenseCategory? predictedCategory;

  const ReceiptData({
    required this.id,
    required this.imagePath,
    this.merchant = const ReceiptMerchant(),
    this.receipt = const ReceiptMetadata(),
    this.items = const [],
    this.summary = const ReceiptSummary(),
    this.payment = const ReceiptPayment(),
    this.ocr = const ReceiptOcrResult(),
    this.predictedCategory,
  });

  /// Deterministic sum of items in integer paise
  int get itemsSumInPaise {
    return items.fold<int>(0, (sum, item) => sum + item.totalPriceInPaise);
  }

  /// Calculates expected grand total from components:
  /// (Items sum or subtotal) - discounts + taxes + charges + tip + roundoff
  int get calculatedTotalInPaise {
    final baseAmount = (summary.subtotalInPaise != null && summary.subtotalInPaise! > 0)
        ? summary.subtotalInPaise!
        : itemsSumInPaise;
    final discount = summary.discountInPaise ?? 0;
    final taxes = summary.totalTaxesInPaise;
    final charges = summary.additionalChargesInPaise ?? 0;
    final tip = summary.tipInPaise ?? 0;
    final roundOff = summary.roundOffInPaise ?? 0;

    final calculated = baseAmount - discount + taxes + charges + tip + roundOff;
    return calculated < 0 ? 0 : calculated;
  }

  /// Checks arithmetic consistency between calculated total and extracted total.
  /// Allows ±100 paise (₹1.00) leeway for rounding discrepancies on printed bills.
  bool get isCalculationConsistent {
    if (summary.totalInPaise == null || summary.totalInPaise! <= 0) return false;
    final diff = (calculatedTotalInPaise - summary.totalInPaise!).abs();
    return diff <= 100;
  }

  /// Difference between calculated total and extracted total in paise.
  int get calculationDifferenceInPaise {
    if (summary.totalInPaise == null) return 0;
    return calculatedTotalInPaise - summary.totalInPaise!;
  }

  ReceiptData copyWith({
    String? id,
    String? imagePath,
    ReceiptMerchant? merchant,
    ReceiptMetadata? receipt,
    List<ReceiptItem>? items,
    ReceiptSummary? summary,
    ReceiptPayment? payment,
    ReceiptOcrResult? ocr,
    ExpenseCategory? predictedCategory,
  }) {
    return ReceiptData(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      merchant: merchant ?? this.merchant,
      receipt: receipt ?? this.receipt,
      items: items ?? this.items,
      summary: summary ?? this.summary,
      payment: payment ?? this.payment,
      ocr: ocr ?? this.ocr,
      predictedCategory: predictedCategory ?? this.predictedCategory,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'imagePath': imagePath,
    'merchant': merchant.toJson(),
    'receipt': receipt.toJson(),
    'items': items.map((i) => i.toJson()).toList(),
    'summary': summary.toJson(),
    'payment': payment.toJson(),
    'ocr': ocr.toJson(),
    'predictedCategory': predictedCategory?.name,
  };

  factory ReceiptData.fromJson(Map<String, dynamic> json) => ReceiptData(
    id: (json['id'] ?? const Uuid().v4()).toString(),
    imagePath: (json['imagePath'] ?? '').toString(),
    merchant: json['merchant'] != null
        ? ReceiptMerchant.fromJson(json['merchant'] as Map<String, dynamic>)
        : const ReceiptMerchant(),
    receipt: json['receipt'] != null
        ? ReceiptMetadata.fromJson(json['receipt'] as Map<String, dynamic>)
        : const ReceiptMetadata(),
    items: (json['items'] as List<dynamic>?)
            ?.map((i) => ReceiptItem.fromJson(i as Map<String, dynamic>))
            .toList() ??
        const [],
    summary: json['summary'] != null
        ? ReceiptSummary.fromJson(json['summary'] as Map<String, dynamic>)
        : const ReceiptSummary(),
    payment: json['payment'] != null
        ? ReceiptPayment.fromJson(json['payment'] as Map<String, dynamic>)
        : const ReceiptPayment(),
    ocr: json['ocr'] != null
        ? ReceiptOcrResult.fromJson(json['ocr'] as Map<String, dynamic>)
        : const ReceiptOcrResult(),
    predictedCategory: json['predictedCategory'] != null
        ? ExpenseCategory.fromString(json['predictedCategory'] as String)
        : null,
  );
}
