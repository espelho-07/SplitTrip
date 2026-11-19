import 'package:uuid/uuid.dart';
import '../../domain/enums/expense_category.dart';
import '../../domain/models/receipt_data.dart';

/// Intelligent, multi-pass deterministic parser for receipt text.
/// Extracts merchant details, line items, taxes, discounts, and totals
/// into strict integer paise representations without floating-point financial math.
class ReceiptParserService {
  final Uuid _uuid;

  ReceiptParserService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  /// Parses raw text extracted from OCR into structured [ReceiptData].
  ReceiptData parse({
    required String rawText,
    required String imagePath,
    String? tripCurrencyCode,
  }) {
    final currency = tripCurrencyCode ?? 'INR';
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return ReceiptData(
        id: _uuid.v4(),
        imagePath: imagePath,
        receipt: ReceiptMetadata(currency: currency),
        ocr: const ReceiptOcrResult(
          status: 'failed',
          confidence: OcrConfidenceLevel.low,
          warnings: ['No readable text found on receipt.'],
          rawText: '',
        ),
      );
    }

    final warnings = <String>[];

    // 1. Merchant Extraction
    final merchant = _extractMerchant(lines);

    // 2. Metadata (Receipt Number, Date, Time)
    final metadata = _extractMetadata(lines, currency: currency);

    // 3. Taxes, Discounts, Subtotal, Grand Total
    final summary = _extractSummary(lines);

    // 4. Line Items
    final items = _extractItems(lines, summary: summary);

    // 5. Payment Method
    final payment = _extractPaymentMethod(lines);

    // 6. Category Prediction
    final predictedCategory = _predictCategory(
      merchantName: merchant.name,
      items: items,
      rawText: rawText,
    );

    // 7. Validation & Confidence Scoring
    OcrConfidenceLevel confidence = OcrConfidenceLevel.high;

    if (summary.totalInPaise == null || summary.totalInPaise! <= 0) {
      warnings.add('Total amount could not be confidently identified.');
      confidence = OcrConfidenceLevel.needsVerification;
    }

    if (items.isEmpty && (summary.totalInPaise == null || summary.totalInPaise! <= 0)) {
      warnings.add('No itemized breakdown or valid total found.');
      confidence = OcrConfidenceLevel.low;
    }

    final tempReceipt = ReceiptData(
      id: _uuid.v4(),
      imagePath: imagePath,
      merchant: merchant,
      receipt: metadata,
      items: items,
      summary: summary,
      payment: payment,
      predictedCategory: predictedCategory,
      ocr: ReceiptOcrResult(
        status: 'completed',
        confidence: confidence,
        warnings: warnings,
        rawText: rawText,
      ),
    );

    if (summary.totalInPaise != null && summary.totalInPaise! > 0 && items.isNotEmpty) {
      if (!tempReceipt.isCalculationConsistent) {
        final diffPaise = tempReceipt.calculationDifferenceInPaise;
        final diffRupees = (diffPaise.abs() / 100.0).toStringAsFixed(2);
        final sign = diffPaise > 0 ? '+' : '-';
        warnings.add(
          'Receipt calculation does not strictly match the extracted total (difference: $sign₹$diffRupees). Please verify.',
        );
        confidence = OcrConfidenceLevel.needsVerification;
      }
    }

    return tempReceipt.copyWith(
      ocr: ReceiptOcrResult(
        status: 'completed',
        confidence: confidence,
        warnings: warnings,
        rawText: rawText,
      ),
    );
  }

  // ==========================================
  // MERCHANT EXTRACTION
  // ==========================================

  ReceiptMerchant _extractMerchant(List<String> lines) {
    String? name;
    String? address;
    String? phone;
    String? gstin;

    final headerLines = lines.take(8).toList();

    // Regex for GSTIN (15 chars Indian format)
    final gstinRegex = RegExp(r'\b([0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1})\b', caseSensitive: false);
    // Regex for Phone Number (Indian mobile or landline)
    final phoneRegex = RegExp(r'(?:phone|tel|ph|mob|mobile|call|contact)?[:\s\.-]*([+]?[0-9]{1,4}[\s-]?)?([6-9][0-9]{4}[\s-]?[0-9]{5}|[0-9]{3,4}[\s-]?[0-9]{6,8})\b', caseSensitive: false);

    // Identify GSTIN & Phone across header lines
    for (final line in headerLines) {
      if (gstin == null) {
        final match = gstinRegex.firstMatch(line);
        if (match != null) {
          gstin = match.group(1)?.toUpperCase();
        }
      }
      if (phone == null) {
        final match = phoneRegex.firstMatch(line);
        if (match != null) {
          phone = match.group(0)?.replaceAll(RegExp(r'(?:phone|tel|ph|mob|mobile|call|contact)[:\s\.-]*', caseSensitive: false), '').trim();
        }
      }
    }

    // Skip generic noise lines to find the true merchant name
    final ignoredHeaders = [
      'tax invoice',
      'retail invoice',
      'cash memo',
      'original for recipient',
      'bill of supply',
      'welcome',
      'receipt',
      'invoice',
      'kot',
      'table',
      'estimate',
      'order summary',
      'pos',
      'thank you',
      'gstin',
    ];

    for (final line in headerLines) {
      final lower = line.toLowerCase().trim();
      final isIgnored = ignoredHeaders.any((h) => lower.startsWith(h) || lower == h);
      final isGstinOrPhone = (gstin != null && line.contains(gstin)) || (phone != null && line.contains(phone));
      final isDateOrTime = RegExp(r'\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}').hasMatch(line);

      if (!isIgnored && !isGstinOrPhone && !isDateOrTime && lower.length >= 3) {
        if (name == null) {
          name = line;
        } else if (address == null && !lower.contains('bill') && !lower.contains('date')) {
          address = line;
          break;
        }
      }
    }

    return ReceiptMerchant(
      name: name,
      address: address,
      phone: phone,
      gstin: gstin,
    );
  }

  // ==========================================
  // METADATA EXTRACTION (RECEIPT #, DATE, TIME)
  // ==========================================

  ReceiptMetadata _extractMetadata(List<String> lines, {required String currency}) {
    String? receiptNumber;
    DateTime? date;
    String? time;

    // Receipt / Invoice Number regex requiring explicit separator
    final receiptNumRegex = RegExp(
      r'\b(?:(?:tax\s+)?invoice\s*ref|(?:tax\s+)?invoice\s*(?:no|num|number)?|bill\s*(?:no|num|number)?|receipt\s*(?:no|num)?|order\s*(?:no|num)?|token\s*(?:no|num)?|ref\s*(?:no)?|inv\s*(?:no|num)?)\s*[:#\.-]\s*([A-Za-z0-9\/-]{3,24})\b',
      caseSensitive: false,
    );

    // Date regexes
    final dateNumericRegex = RegExp(r'\b(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})\b');
    final dateIsoRegex = RegExp(r'\b(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})\b');
    final dateTextRegex = RegExp(
      r'\b(\d{1,2})[\s\/-](Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[\s\/-](\d{2,4})\b',
      caseSensitive: false,
    );

    // Time regex
    final timeRegex = RegExp(r'\b(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)?\b', caseSensitive: false);

    for (final line in lines) {
      if (receiptNumber == null) {
        final match = receiptNumRegex.firstMatch(line);
        if (match != null) {
          final candidate = match.group(1)?.trim();
          if (candidate != null &&
              !candidate.toLowerCase().contains('date') &&
              !candidate.toLowerCase().contains('time') &&
              candidate.length >= 2) {
            receiptNumber = candidate;
          }
        }
      }

      if (date == null) {
        // Try Text Date (e.g., 15 Nov 2024)
        final matchText = dateTextRegex.firstMatch(line);
        if (matchText != null) {
          date = _parseTextDate(matchText.group(1)!, matchText.group(2)!, matchText.group(3)!);
        } else {
          // Try ISO Date (YYYY-MM-DD)
          final matchIso = dateIsoRegex.firstMatch(line);
          if (matchIso != null) {
            final y = int.tryParse(matchIso.group(1)!);
            final m = int.tryParse(matchIso.group(2)!);
            final d = int.tryParse(matchIso.group(3)!);
            if (y != null && m != null && d != null && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
              date = DateTime(y, m, d);
            }
          } else {
            // Try DD/MM/YYYY or MM/DD/YYYY
            final matchNum = dateNumericRegex.firstMatch(line);
            if (matchNum != null) {
              final dOrM = int.tryParse(matchNum.group(1)!);
              final mOrD = int.tryParse(matchNum.group(2)!);
              var y = int.tryParse(matchNum.group(3)!);
              if (y != null && y < 100) y += 2000;

              if (dOrM != null && mOrD != null && y != null) {
                // In India, DD/MM/YYYY is standard. If dOrM > 12, it must be DD.
                if (dOrM <= 31 && mOrD <= 12) {
                  date = DateTime(y, mOrD, dOrM);
                } else if (dOrM <= 12 && mOrD <= 31) {
                  date = DateTime(y, dOrM, mOrD);
                }
              }
            }
          }
        }
      }

      if (time == null) {
        final matchTime = timeRegex.firstMatch(line);
        if (matchTime != null) {
          time = matchTime.group(0);
        }
      }
    }

    return ReceiptMetadata(
      receiptNumber: receiptNumber,
      date: date,
      time: time,
      currency: currency,
    );
  }

  DateTime? _parseTextDate(String dayStr, String monthStr, String yearStr) {
    final d = int.tryParse(dayStr);
    var y = int.tryParse(yearStr);
    if (y != null && y < 100) y += 2000;
    if (d == null || y == null) return null;

    final mLower = monthStr.toLowerCase();
    const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    final mIndex = months.indexWhere((m) => mLower.startsWith(m));
    if (mIndex == -1) return null;

    final m = mIndex + 1;
    if (d >= 1 && d <= 31) {
      return DateTime(y, m, d);
    }
    return null;
  }

  // ==========================================
  // SUMMARY EXTRACTION (TOTAL, SUBTOTAL, TAXES, DISCOUNTS)
  // ==========================================

  ReceiptSummary _extractSummary(List<String> lines) {
    int? subtotalInPaise;
    int? discountInPaise;
    int? totalInPaise;
    int? roundOffInPaise;
    int? tipInPaise;
    int? additionalChargesInPaise;
    final taxes = <ReceiptTaxItem>[];

    // Priority grand total regexes
    final totalRegex = RegExp(
      r'\b(?:grand\s*total|net\s*payable|amount\s*payable|total\s*amount|total\s*due|net\s*amount|bill\s*amount|total\s*rs|total\s*inr|balance\s*due|total\b)[\s\.:₹=RsINR]*([0-9,]+(?:\.[0-9]{1,2})?)\b',
      caseSensitive: false,
    );

    final subtotalRegex = RegExp(
      r'\b(?:sub\s*total|subtotal|item\s*total|gross\s*amount|gross\s*total)[\s\.:₹=RsINR]*([0-9,]+(?:\.[0-9]{1,2})?)\b',
      caseSensitive: false,
    );

    final discountRegex = RegExp(
      r'\b(?:discount|disc|promo|offer|less)[\s\.:₹=RsINR\(\)]*([0-9,]+(?:\.[0-9]{1,2})?)\b',
      caseSensitive: false,
    );

    final roundOffRegex = RegExp(
      r'\b(?:round\s*off|roundoff|rnd\s*off)[\s\.:₹=RsINR]*([+-]?[0-9,]+(?:\.[0-9]{1,2})?)\b',
      caseSensitive: false,
    );

    final tipRegex = RegExp(
      r'\b(?:tip|gratuity)[\s\.:₹=RsINR]*([0-9,]+(?:\.[0-9]{1,2})?)\b',
      caseSensitive: false,
    );

    final serviceChargeRegex = RegExp(
      r'\b(?:service\s*charge|delivery\s*charge|container\s*charge|packaging\s*charge)[\s\.:₹=RsINR]*([0-9,]+(?:\.[0-9]{1,2})?)\b',
      caseSensitive: false,
    );

    // GST/Tax regexes
    final cgstRegex = RegExp(r'\b(?:cgst|c\.gst)\s*@?\s*([0-9]+(?:\.[0-9]+)?)?%?[\s\.:₹=RsINR]*([0-9,]+(?:\.[0-9]{1,2})?)\b', caseSensitive: false);
    final sgstRegex = RegExp(r'\b(?:sgst|s\.gst)\s*@?\s*([0-9]+(?:\.[0-9]+)?)?%?[\s\.:₹=RsINR]*([0-9,]+(?:\.[0-9]{1,2})?)\b', caseSensitive: false);
    final igstRegex = RegExp(r'\b(?:igst|i\.gst)\s*@?\s*([0-9]+(?:\.[0-9]+)?)?%?[\s\.:₹=RsINR]*([0-9,]+(?:\.[0-9]{1,2})?)\b', caseSensitive: false);
    final vatRegex = RegExp(r'\b(?:vat|tax|gst)\s*@?\s*([0-9]+(?:\.[0-9]+)?)?%?[\s\.:₹=RsINR]*([0-9,]+(?:\.[0-9]{1,2})?)\b', caseSensitive: false);

    // Scan bottom-up for totals as they typically appear near the bottom
    for (int i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];

      if (totalInPaise == null) {
        final match = totalRegex.firstMatch(line);
        if (match != null) {
          final amt = _parsePaise(match.group(1));
          if (amt != null && amt > 0) {
            totalInPaise = amt;
          }
        }
      }

      if (subtotalInPaise == null) {
        final match = subtotalRegex.firstMatch(line);
        if (match != null) {
          subtotalInPaise = _parsePaise(match.group(1));
        }
      }

      if (discountInPaise == null) {
        final match = discountRegex.firstMatch(line);
        if (match != null) {
          discountInPaise = _parsePaise(match.group(1));
        }
      }

      if (roundOffInPaise == null) {
        final match = roundOffRegex.firstMatch(line);
        if (match != null) {
          roundOffInPaise = _parsePaise(match.group(1));
        }
      }

      if (tipInPaise == null) {
        final match = tipRegex.firstMatch(line);
        if (match != null) {
          tipInPaise = _parsePaise(match.group(1));
        }
      }

      if (additionalChargesInPaise == null) {
        final match = serviceChargeRegex.firstMatch(line);
        if (match != null) {
          additionalChargesInPaise = _parsePaise(match.group(1));
        }
      }

      // Check Taxes
      final cgstMatch = cgstRegex.firstMatch(line);
      if (cgstMatch != null) {
        final rate = double.tryParse(cgstMatch.group(1) ?? '');
        final amt = _parsePaise(cgstMatch.group(2));
        if (amt != null && amt > 0 && !taxes.any((t) => t.name == 'CGST')) {
          taxes.add(ReceiptTaxItem(name: 'CGST', rate: rate, amountInPaise: amt));
        }
      }

      final sgstMatch = sgstRegex.firstMatch(line);
      if (sgstMatch != null) {
        final rate = double.tryParse(sgstMatch.group(1) ?? '');
        final amt = _parsePaise(sgstMatch.group(2));
        if (amt != null && amt > 0 && !taxes.any((t) => t.name == 'SGST')) {
          taxes.add(ReceiptTaxItem(name: 'SGST', rate: rate, amountInPaise: amt));
        }
      }

      final igstMatch = igstRegex.firstMatch(line);
      if (igstMatch != null) {
        final rate = double.tryParse(igstMatch.group(1) ?? '');
        final amt = _parsePaise(igstMatch.group(2));
        if (amt != null && amt > 0 && !taxes.any((t) => t.name == 'IGST')) {
          taxes.add(ReceiptTaxItem(name: 'IGST', rate: rate, amountInPaise: amt));
        }
      }

      final vatMatch = vatRegex.firstMatch(line);
      if (vatMatch != null && taxes.isEmpty) {
        final rate = double.tryParse(vatMatch.group(1) ?? '');
        final amt = _parsePaise(vatMatch.group(2));
        if (amt != null && amt > 0) {
          taxes.add(ReceiptTaxItem(name: 'GST/Tax', rate: rate, amountInPaise: amt));
        }
      }
    }

    return ReceiptSummary(
      subtotalInPaise: subtotalInPaise,
      discountInPaise: discountInPaise,
      taxes: taxes.reversed.toList(),
      additionalChargesInPaise: additionalChargesInPaise,
      tipInPaise: tipInPaise,
      roundOffInPaise: roundOffInPaise,
      totalInPaise: totalInPaise,
    );
  }

  // ==========================================
  // LINE ITEM EXTRACTION
  // ==========================================

  List<ReceiptItem> _extractItems(List<String> lines, {required ReceiptSummary summary}) {
    final items = <ReceiptItem>[];

    final summaryKeywords = [
      'subtotal',
      'sub total',
      'total',
      'cgst',
      'sgst',
      'igst',
      'tax',
      'vat',
      'discount',
      'disc',
      'round off',
      'roundoff',
      'cash tendered',
      'change',
      'balance due',
      'amount paid',
      'card',
      'upi',
      'tip',
      'delivery charge',
      'service charge',
    ];

    // Pattern 1: Item Name [optional qty 'x' or 'nos'] [Price] [Total]
    // e.g. "Paneer Masala 2 x 150.00 300.00" or "Burger 1 120.00" or "Coffee 150.00"
    final lineItemRegex = RegExp(
      r'^(.*?)\s+(?:(\d+(?:\.\d+)?)\s*(?:x|nos|kg|qty|pc|pcs)?\s+)?(?:[₹=RsINR\s]*([0-9,]+(?:\.[0-9]{1,2})?)\s+)?([0-9,]+(?:\.[0-9]{1,2}))\s*$',
      caseSensitive: false,
    );

    for (final line in lines) {
      final lower = line.toLowerCase().trim();

      // Skip lines that match known summary or metadata keywords
      final isSummaryLine = summaryKeywords.any((k) => lower.startsWith(k) || lower.contains('$k:'));
      final isGstinOrPhone = lower.contains('gstin') || lower.contains('phone') || lower.contains('tel:');
      final isDateOrTime = RegExp(r'\b\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}\b').hasMatch(line);

      if (isSummaryLine || isGstinOrPhone || isDateOrTime || lower.length < 4) {
        continue;
      }

      final match = lineItemRegex.firstMatch(line);
      if (match != null) {
        final nameCandidate = match.group(1)?.trim();
        final qtyStr = match.group(2);
        final unitPriceStr = match.group(3);
        final totalStr = match.group(4);

        if (nameCandidate == null || nameCandidate.isEmpty || nameCandidate.length < 2) {
          continue;
        }

        // Avoid false positive where name is purely numeric or punctuation
        if (!RegExp(r'[a-zA-Z]').hasMatch(nameCandidate)) {
          continue;
        }

        final lineTotalPaise = _parsePaise(totalStr);
        if (lineTotalPaise == null || lineTotalPaise <= 0) {
          continue;
        }

        final qty = double.tryParse(qtyStr ?? '') ?? 1.0;
        var unitPricePaise = _parsePaise(unitPriceStr);
        if (unitPricePaise == null || unitPricePaise <= 0) {
          unitPricePaise = (lineTotalPaise / (qty > 0 ? qty : 1.0)).round();
        }

        // Check if item looks valid
        items.add(
          ReceiptItem(
            id: _uuid.v4(),
            name: nameCandidate,
            quantity: qty,
            unitPriceInPaise: unitPricePaise,
            totalPriceInPaise: lineTotalPaise,
            confidence: 0.95,
          ),
        );
      }
    }

    return items;
  }

  // ==========================================
  // PAYMENT METHOD EXTRACTION
  // ==========================================

  ReceiptPayment _extractPaymentMethod(List<String> lines) {
    for (final line in lines.reversed) {
      final lower = line.toLowerCase();
      if (lower.contains('upi') || lower.contains('gpay') || lower.contains('google pay') || lower.contains('phonepe') || lower.contains('paytm')) {
        return const ReceiptPayment(method: 'UPI');
      }
      if (lower.contains('credit card') || lower.contains('debit card') || lower.contains('visa') || lower.contains('mastercard') || lower.contains('rupay') || lower.contains('pos sale')) {
        return const ReceiptPayment(method: 'Card');
      }
      if (lower.contains('cash') && !lower.contains('cashback')) {
        return const ReceiptPayment(method: 'Cash');
      }
      if (lower.contains('net banking')) {
        return const ReceiptPayment(method: 'Net Banking');
      }
    }
    return const ReceiptPayment(method: null);
  }

  // ==========================================
  // CATEGORY PREDICTION
  // ==========================================

  ExpenseCategory? _predictCategory({
    String? merchantName,
    required List<ReceiptItem> items,
    required String rawText,
  }) {
    if (merchantName != null && merchantName.isNotEmpty) {
      final m = merchantName.toLowerCase();
      if (m.contains('supermarket') ||
          m.contains('mart') ||
          m.contains('grocery') ||
          m.contains('hypermarket') ||
          m.contains('provisions') ||
          m.contains('bazaar')) {
        return ExpenseCategory.groceries;
      }
      if (m.contains('petrol') ||
          m.contains('fuel') ||
          m.contains('hp ') ||
          m.contains('indian oil') ||
          m.contains('bharat petroleum') ||
          m.contains('shell')) {
        return ExpenseCategory.transport;
      }
      if (m.contains('cinema') || m.contains('theatre') || m.contains('pvr') || m.contains('inox')) {
        return ExpenseCategory.activities;
      }
      if (m.contains('hotel') || m.contains('resort') || m.contains('homestay') || m.contains('hostel') || m.contains('inn') || m.contains('lodge')) {
        return ExpenseCategory.stay;
      }
      if (m.contains('restaurant') ||
          m.contains('cafe') ||
          m.contains('bistro') ||
          m.contains('dhaba') ||
          m.contains('bakery') ||
          m.contains('pizza') ||
          m.contains('burger') ||
          m.contains('biryani') ||
          m.contains('kitchen')) {
        return ExpenseCategory.food;
      }
    }

    final combined = StringBuffer();
    if (merchantName != null) combined.write('$merchantName ');
    for (final item in items) {
      combined.write('${item.name} ');
    }
    combined.write(rawText);
    final text = combined.toString().toLowerCase();

    // Food / Restaurant
    if (text.contains('restaurant') ||
        text.contains('cafe') ||
        text.contains('bistro') ||
        text.contains('dhaba') ||
        text.contains('hotel') ||
        text.contains('pizza') ||
        text.contains('burger') ||
        text.contains('biryani') ||
        text.contains('dosa') ||
        text.contains('coffee') ||
        text.contains('tea') ||
        text.contains('bar') ||
        text.contains('food') ||
        text.contains('swiggy') ||
        text.contains('zomato')) {
      return ExpenseCategory.food;
    }

    // Groceries / Supermarket
    if (text.contains('supermarket') ||
        text.contains('mart') ||
        text.contains('grocery') ||
        text.contains('hypermarket') ||
        text.contains('provisions') ||
        text.contains('bazaar') ||
        text.contains('blinkit') ||
        text.contains('zepto') ||
        text.contains('instamart') ||
        text.contains('vegetables') ||
        text.contains('fruits')) {
      return ExpenseCategory.groceries;
    }

    // Transport / Fuel
    if (text.contains('petrol') ||
        text.contains('fuel') ||
        text.contains('diesel') ||
        text.contains('cng') ||
        text.contains('uber') ||
        text.contains('ola') ||
        text.contains('rapido') ||
        text.contains('taxi') ||
        text.contains('toll') ||
        text.contains('fastag') ||
        text.contains('parking')) {
      return ExpenseCategory.transport;
    }

    // Shopping
    if (text.contains('clothing') ||
        text.contains('apparel') ||
        text.contains('fashion') ||
        text.contains('mall') ||
        text.contains('retail') ||
        text.contains('footwear') ||
        text.contains('electronics') ||
        text.contains('zara') ||
        text.contains('h&m')) {
      return ExpenseCategory.shopping;
    }

    // Entertainment / Activities
    if (text.contains('cinema') ||
        text.contains('movie') ||
        text.contains('pvr') ||
        text.contains('inox') ||
        text.contains('theatre') ||
        text.contains('amusement') ||
        text.contains('tickets')) {
      return ExpenseCategory.activities;
    }

    // General fallback
    return ExpenseCategory.predictFromTitle(merchantName ?? '');
  }

  // ==========================================
  // HELPER: PARSE PAISE (ZERO FLOATING ARITHMETIC)
  // ==========================================

  int? _parsePaise(String? amountStr) {
    if (amountStr == null) return null;
    final cleaned = amountStr.replaceAll(',', '').trim();
    if (cleaned.isEmpty) return null;

    final parts = cleaned.split('.');
    if (parts.length == 1) {
      final rupees = int.tryParse(parts[0]);
      return rupees != null ? rupees * 100 : null;
    } else if (parts.length == 2) {
      final rupees = int.tryParse(parts[0]);
      var paiseStr = parts[1];
      if (paiseStr.length == 1) paiseStr += '0';
      if (paiseStr.length > 2) paiseStr = paiseStr.substring(0, 2);
      final paise = int.tryParse(paiseStr);

      if (rupees != null && paise != null) {
        if (rupees < 0) {
          return rupees * 100 - paise;
        }
        return rupees * 100 + paise;
      }
    }
    return null;
  }
}
