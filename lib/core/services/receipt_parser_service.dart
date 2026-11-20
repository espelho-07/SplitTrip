import 'dart:math' as math;
import 'package:uuid/uuid.dart';
import '../../domain/enums/expense_category.dart';
import '../../domain/models/receipt_data.dart';

/// Internal model holding spatial row clustering result.
class _SpatialReconstructionResult {
  final List<String> lines;
  final bool isTwoColumn;

  const _SpatialReconstructionResult({
    required this.lines,
    required this.isTwoColumn,
  });
}

/// Internal helper for grouping OCR elements by horizontal row bands.
class _SpatialRow {
  double top;
  double bottom;
  final List<OcrLine> elements;

  _SpatialRow(OcrLine initial)
      : top = initial.boundingBox.top,
        bottom = initial.boundingBox.bottom,
        elements = [initial];

  double get centerY => (top + bottom) / 2.0;
  double get height => bottom - top;

  void add(OcrLine line) {
    elements.add(line);
    if (line.boundingBox.top < top) top = line.boundingBox.top;
    if (line.boundingBox.bottom > bottom) bottom = line.boundingBox.bottom;
  }

  String toMergedText() {
    elements.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
    return elements.map((e) => e.text.trim()).where((t) => t.isNotEmpty).join(' ');
  }
}

/// Intelligent, multi-pass deterministic parser for receipt text.
/// Extracts merchant details, line items, taxes, discounts, and totals
/// into strict integer paise representations without floating-point financial math.
///
/// Features spatial 2D row reconstruction, Indian GST & HSN/SAC code filtering,
/// mathematical verification, and granular field-level confidence scoring.
class ReceiptParserService {
  final Uuid _uuid;

  ReceiptParserService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  /// Parses raw text and optional structured spatial OCR lines into [ReceiptData].
  ReceiptData parse({
    required String rawText,
    List<OcrLine>? structuredLines,
    required String imagePath,
    String? tripCurrencyCode,
  }) {
    final currency = tripCurrencyCode ?? 'INR';

    final bool twoColumnDetected;
    final List<String> lines;

    // 0. Spatial Reconstruction (if bounding box lines are provided)
    if (structuredLines != null && structuredLines.isNotEmpty) {
      final spatialResult = _reconstructSpatialLines(structuredLines);
      lines = spatialResult.lines;
      twoColumnDetected = spatialResult.isTwoColumn;
    } else {
      lines = rawText
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      twoColumnDetected = false;
    }

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
          fieldConfidence: ReceiptFieldConfidence(
            merchant: FieldVerificationStatus.needsReview,
            date: FieldVerificationStatus.needsReview,
            total: FieldVerificationStatus.needsReview,
            taxes: FieldVerificationStatus.needsReview,
            items: FieldVerificationStatus.needsReview,
            fieldWarnings: ['Image text could not be extracted.'],
          ),
          isTwoColumnDetected: false,
        ),
      );
    }

    final warnings = <String>[];

    // 1. Merchant Extraction
    final merchant = _extractMerchant(lines);

    // 2. Metadata (Receipt Number, Date, Time)
    final metadata = _extractMetadata(lines, currency: currency);

    // 3. Taxes, Discounts, Subtotal, Grand Total
    var summary = _extractSummary(lines);

    // 4. Line Items (multi-pass with HSN/SAC filtering)
    final items = _extractItems(lines, summary: summary);

    // 5. Payment Method
    final payment = _extractPaymentMethod(lines);

    // 6. Category Prediction
    final predictedCategory = _predictCategory(
      merchantName: merchant.name,
      items: items,
      rawText: rawText,
    );

    // 7. Base and Expected Total Calculations
    final itemsSumPaise = items.fold<int>(0, (sum, i) => sum + i.totalPriceInPaise);
    final baseAmountPaise = (summary.subtotalInPaise != null && summary.subtotalInPaise! > 0)
        ? summary.subtotalInPaise!
        : itemsSumPaise;

    final discountPaise = summary.discountInPaise ?? 0;
    final taxesPaise = summary.totalTaxesInPaise;
    final chargesPaise = summary.additionalChargesInPaise ?? 0;
    final tipPaise = summary.tipInPaise ?? 0;
    final roundOffPaise = summary.roundOffInPaise ?? 0;

    final calculatedTotalPaise = math.max(
      0,
      baseAmountPaise - discountPaise + taxesPaise + chargesPaise + tipPaise + roundOffPaise,
    );

    // 8. If printed total was missing, infer from calculatedTotalPaise
    bool wasTotalInferred = false;
    if ((summary.totalInPaise == null || summary.totalInPaise! <= 0) && calculatedTotalPaise > 0) {
      summary = summary.copyWith(totalInPaise: calculatedTotalPaise);
      wasTotalInferred = true;
      warnings.add(
        'Grand Total was inferred from item breakdown (₹${(calculatedTotalPaise / 100.0).toStringAsFixed(2)}). Please verify.',
      );
    }

    // 9. Validation & Mathematical Consistency Scoring
    OcrConfidenceLevel confidence = OcrConfidenceLevel.high;

    if (summary.totalInPaise == null || summary.totalInPaise! <= 0) {
      warnings.add('Total amount could not be confidently identified.');
      confidence = OcrConfidenceLevel.needsVerification;
    }

    if (items.isEmpty && (summary.totalInPaise == null || summary.totalInPaise! <= 0)) {
      warnings.add('No itemized breakdown or valid total found.');
      confidence = OcrConfidenceLevel.low;
    }

    // Check calculation difference
    bool isCalculationConsistent = false;
    int diffPaise = 0;

    if (summary.totalInPaise != null && summary.totalInPaise! > 0) {
      if (items.isNotEmpty || summary.subtotalInPaise != null) {
        diffPaise = calculatedTotalPaise - summary.totalInPaise!;
        isCalculationConsistent = diffPaise.abs() <= 100;

        if (!isCalculationConsistent && !wasTotalInferred) {
          final diffRupees = (diffPaise.abs() / 100.0).toStringAsFixed(2);
          final sign = diffPaise > 0 ? '+' : '-';
          warnings.add(
            'Receipt calculation does not strictly match the extracted total (difference: $sign₹$diffRupees). Please verify.',
          );
          confidence = OcrConfidenceLevel.needsVerification;
        }
      } else {
        // Total found but no items or subtotal
        isCalculationConsistent = true;
      }
    }

    if (wasTotalInferred && confidence == OcrConfidenceLevel.high) {
      confidence = OcrConfidenceLevel.needsVerification;
    }

    // 10. Granular Field-Level Confidence Calculation
    final fieldConfidence = _computeFieldConfidence(
      merchant: merchant,
      metadata: metadata,
      summary: summary,
      items: items,
      calculatedTotal: calculatedTotalPaise,
      isConsistent: isCalculationConsistent,
      wasTotalInferred: wasTotalInferred,
      diffPaise: diffPaise,
    );

    return ReceiptData(
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
        fieldConfidence: fieldConfidence,
        isTwoColumnDetected: twoColumnDetected,
      ),
    );
  }

  // ==========================================
  // SPATIAL ROW RECONSTRUCTION
  // ==========================================

  _SpatialReconstructionResult _reconstructSpatialLines(List<OcrLine> ocrLines) {
    if (ocrLines.isEmpty) {
      return const _SpatialReconstructionResult(lines: [], isTwoColumn: false);
    }

    final valid = ocrLines.where((l) => l.text.trim().isNotEmpty).toList();
    if (valid.isEmpty) {
      return const _SpatialReconstructionResult(lines: [], isTwoColumn: false);
    }

    // Sort primarily by top coordinate
    valid.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    final rows = <_SpatialRow>[];

    for (final line in valid) {
      _SpatialRow? bestRow;
      double bestOverlap = 0.0;

      for (final row in rows) {
        final verticalOverlap = (math.min(line.boundingBox.bottom, row.bottom) -
                math.max(line.boundingBox.top, row.top))
            .clamp(0.0, double.infinity);
        final minHeight = math.min(line.boundingBox.height, row.height);

        if (minHeight > 0) {
          final overlapRatio = verticalOverlap / minHeight;
          final centerDiff = (line.boundingBox.centerY - row.centerY).abs();

          if (overlapRatio > 0.35 || centerDiff <= minHeight * 0.45) {
            if (overlapRatio > bestOverlap) {
              bestOverlap = overlapRatio;
              bestRow = row;
            }
          }
        }
      }

      if (bestRow != null) {
        bestRow.add(line);
      } else {
        rows.add(_SpatialRow(line));
      }
    }

    // Sort rows top-to-bottom
    rows.sort((a, b) => a.top.compareTo(b.top));

    bool isTwoColumn = false;
    final mergedLines = <String>[];

    for (final row in rows) {
      if (row.elements.length >= 2) {
        row.elements.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
        for (int i = 0; i < row.elements.length - 1; i++) {
          final gap = row.elements[i + 1].boundingBox.left - row.elements[i].boundingBox.right;
          if (gap > 20.0) {
            isTwoColumn = true;
            break;
          }
        }
      }
      final merged = row.toMergedText();
      if (merged.isNotEmpty) {
        mergedLines.add(merged);
      }
    }

    return _SpatialReconstructionResult(
      lines: mergedLines,
      isTwoColumn: isTwoColumn,
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

    final headerLines = lines.take(10).toList();

    // Regex for GSTIN (15 chars Indian format: 2-digit state code, 10-char PAN, 1 entity, 1 Z, 1 check digit)
    final gstinRegex = RegExp(
      r'\b([0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}[Zz][0-9A-Z]{1})\b',
    );
    // Regex for Phone Number (Indian mobile or landline)
    final phoneRegex = RegExp(
      r'(?:phone|tel|ph|mob|mobile|call|contact)?[:\s\.-]*([+]?[0-9]{1,4}[\s-]?)?([6-9][0-9]{4}[\s-]?[0-9]{5}|[0-9]{3,4}[\s-]?[0-9]{6,8})\b',
      caseSensitive: false,
    );

    // Identify GSTIN & Phone across header lines
    for (final line in headerLines) {
      if (gstin == null) {
        final match = gstinRegex.firstMatch(line);
        if (match != null) {
          final candidateGstin = match.group(1)?.toUpperCase();
          if (candidateGstin != null && _isValidGstinStateCode(candidateGstin)) {
            gstin = candidateGstin;
          }
        }
      }
      if (phone == null) {
        final match = phoneRegex.firstMatch(line);
        if (match != null) {
          phone = match
              .group(0)
              ?.replaceAll(
                RegExp(r'(?:phone|tel|ph|mob|mobile|call|contact)[:\s\.-]*', caseSensitive: false),
                '',
              )
              .trim();
        }
      }
    }

    // Skip generic noise lines to find the true merchant name
    final ignoredHeaders = [
      'tax invoice',
      'retail invoice',
      'cash memo',
      'original for recipient',
      'duplicate for transporter',
      'triplicate for supplier',
      'bill of supply',
      'bill of sale',
      'customer copy',
      'merchant copy',
      'welcome',
      'receipt',
      'invoice',
      'kot',
      'table',
      'estimate',
      'order summary',
      'pos',
      'thank you',
      'visit again',
      'gstin',
      'fssai',
      'cin',
      'pan',
      'order id',
      'token no',
      'server:',
      'waiter:',
      'steward:',
      'pax:',
    ];

    for (final line in headerLines) {
      final lower = line.toLowerCase().trim();
      final isIgnored = ignoredHeaders.any((h) => lower.startsWith(h) || lower == h);
      final isGstinOrPhone =
          (gstin != null && line.contains(gstin)) || (phone != null && line.contains(phone));
      final isDateOrTime = RegExp(r'\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}').hasMatch(line);
      final isPurelyNumeric = !RegExp(r'[a-zA-Z]').hasMatch(line);
      // Reject lines that look like item pricing (e.g. "Cold Coffee 1 120.00") or summary keywords
      final hasPriceSuffix = RegExp(r'\b\d+[\.,]\d{2}\s*$').hasMatch(line) ||
          RegExp(r'\s+\d+(?:\.\d+)?\s+[₹$€£RsINR]?\s*\d+').hasMatch(line);
      final hasSummaryKeyword = [
        'total',
        'subtotal',
        'sub total',
        'tax',
        'cgst',
        'sgst',
        'igst',
        'vat',
        'discount',
        'round off',
        'balance',
        'tendered',
        'change due',
      ].any((k) => lower.contains(k));

      if (!isIgnored &&
          !isGstinOrPhone &&
          !isDateOrTime &&
          !isPurelyNumeric &&
          !hasPriceSuffix &&
          !hasSummaryKeyword &&
          lower.length >= 3) {
        if (name == null) {
          name = line.trim();
        } else if (address == null &&
            !lower.contains('bill') &&
            !lower.contains('date') &&
            !lower.contains('time') &&
            !lower.contains('invoice')) {
          address = line.trim();
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

  bool _isValidGstinStateCode(String gstin) {
    if (gstin.length < 2) return false;
    final stateCode = int.tryParse(gstin.substring(0, 2));
    if (stateCode == null) return false;
    // Valid Indian state/UT codes are 01 through 38, plus 97 (other territory) and 99 (centre)
    return (stateCode >= 1 && stateCode <= 38) || stateCode == 97 || stateCode == 99;
  }

  // ==========================================
  // METADATA EXTRACTION (RECEIPT #, DATE, TIME)
  // ==========================================

  ReceiptMetadata _extractMetadata(List<String> lines, {required String currency}) {
    String? receiptNumber;
    DateTime? date;
    String? time;

    // Receipt / Invoice Number regex requiring explicit separator or identifier
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
        // Try Text Date (e.g., 15 Nov 2024 or 15-Nov-2024)
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
            if (y != null && m != null && d != null && _isValidDate(y, m, d)) {
              date = DateTime(y, m, d);
            }
          } else {
            // Try DD/MM/YYYY or MM/DD/YYYY
            final matchNum = dateNumericRegex.firstMatch(line);
            if (matchNum != null) {
              final first = int.tryParse(matchNum.group(1)!);
              final second = int.tryParse(matchNum.group(2)!);
              var y = int.tryParse(matchNum.group(3)!);
              if (y != null && y < 100) y += 2000;

              if (first != null && second != null && y != null) {
                final isUsd = currency.toUpperCase() == 'USD';

                if (isUsd) {
                  // US convention: first is Month, second is Day
                  if (first <= 12 && second <= 31 && _isValidDate(y, first, second)) {
                    date = DateTime(y, first, second);
                  } else if (first <= 31 && second <= 12 && _isValidDate(y, second, first)) {
                    date = DateTime(y, second, first);
                  }
                } else {
                  // Standard / Indian convention: first is Day, second is Month
                  if (first <= 31 && second <= 12 && _isValidDate(y, second, first)) {
                    date = DateTime(y, second, first);
                  } else if (first <= 12 && second <= 31 && _isValidDate(y, first, second)) {
                    date = DateTime(y, first, second);
                  }
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
    if (_isValidDate(y, m, d)) {
      return DateTime(y, m, d);
    }
    return null;
  }

  bool _isValidDate(int y, int m, int d) {
    final currentYear = DateTime.now().year;
    if (y < 2000 || y > currentYear + 1) return false;
    if (m < 1 || m > 12) return false;
    if (d < 1 || d > 31) return false;
    final candidate = DateTime(y, m, d);
    return candidate.year == y && candidate.month == m && candidate.day == d;
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

    // Grand total regexes with priority ranking
    final highPriorityTotalRegex = RegExp(
      r'\b(?:grand\s*total|net\s*payable|amount\s*payable|total\s*payable|invoice\s*total|bill\s*total|final\s*amount|total\s*net|net\s*amount\s*payable)\b[\s\.:₹=RsINR\-\/]*([0-9OoSsIl,]+(?:\.[0-9OoSsIl]{1,2})?)\b',
      caseSensitive: false,
    );

    final standardTotalRegex = RegExp(
      r'\b(?:total\s*amount|net\s*amount|bill\s*amount|total\s*rs|total\s*inr|balance\s*due|total\b)[\s\.:₹=RsINR\-\/]*([0-9OoSsIl,]+(?:\.[0-9OoSsIl]{1,2})?)\b',
      caseSensitive: false,
    );

    final subtotalRegex = RegExp(
      r'\b(?:sub\s*total|subtotal|item\s*total|items\s*total|gross\s*amount|gross\s*total|taxable\s*value|taxable\s*amount|total\s*before\s*tax)[\s\.:₹=RsINR\-\/]*([0-9OoSsIl,]+(?:\.[0-9OoSsIl]{1,2})?)\b',
      caseSensitive: false,
    );

    final discountRegex = RegExp(
      r'\b(?:discount|disc|promo|offer|special\s*discount|less|rebate)[\s\.:₹=RsINR\(\)\-]*([0-9OoSsIl,]+(?:\.[0-9OoSsIl]{1,2})?)\b',
      caseSensitive: false,
    );

    final roundOffRegex = RegExp(
      r'\b(?:round\s*off|roundoff|rnd\s*off|r\/o|rounding)[\s\.:₹=RsINR]*([+-]?[0-9OoSsIl,]+(?:\.[0-9OoSsIl]{1,2})?)\b',
      caseSensitive: false,
    );

    final tipRegex = RegExp(
      r'\b(?:tip|gratuity)[\s\.:₹=RsINR\-]*([0-9OoSsIl,]+(?:\.[0-9OoSsIl]{1,2})?)\b',
      caseSensitive: false,
    );

    final serviceChargeRegex = RegExp(
      r'\b(?:service\s*charge|svc\s*chg|s\.c\.|staff\s*contribution)[\s\.:₹=RsINR\-]*([0-9OoSsIl,]+(?:\.[0-9OoSsIl]{1,2})?)\b',
      caseSensitive: false,
    );

    final packagingChargeRegex = RegExp(
      r'\b(?:delivery\s*charge|packaging\s*charge|container\s*charge|packing\s*charge)[\s\.:₹=RsINR\-]*([0-9OoSsIl,]+(?:\.[0-9OoSsIl]{1,2})?)\b',
      caseSensitive: false,
    );

    // GST/Tax regexes
    final cgstRegex = RegExp(
      r'\b(?:cgst|c\.gst)\b(?:\s*@?\s*([0-9]+(?:\.[0-9]+)?)%?)?[\s\.:₹=RsINR\-\/]*([0-9OoSsIl,]+(?:\.[0-9OoSsIl]{1,2})?)\b',
      caseSensitive: false,
    );
    final sgstRegex = RegExp(
      r'\b(?:sgst|s\.gst)\b(?:\s*@?\s*([0-9]+(?:\.[0-9]+)?)%?)?[\s\.:₹=RsINR\-\/]*([0-9OoSsIl,]+(?:\.[0-9OoSsIl]{1,2})?)\b',
      caseSensitive: false,
    );
    final igstRegex = RegExp(
      r'\b(?:igst|i\.gst)\b(?:\s*@?\s*([0-9]+(?:\.[0-9]+)?)%?)?[\s\.:₹=RsINR\-\/]*([0-9OoSsIl,]+(?:\.[0-9OoSsIl]{1,2})?)\b',
      caseSensitive: false,
    );
    final utgstRegex = RegExp(
      r'\b(?:utgst|ut\.gst)\b(?:\s*@?\s*([0-9]+(?:\.[0-9]+)?)%?)?[\s\.:₹=RsINR\-\/]*([0-9OoSsIl,]+(?:\.[0-9OoSsIl]{1,2})?)\b',
      caseSensitive: false,
    );
    final vatRegex = RegExp(
      r'\b(?:vat|v\.a\.t)\b(?:\s*@?\s*([0-9]+(?:\.[0-9]+)?)%?)?[\s\.:₹=RsINR\-\/]*([0-9OoSsIl,]+(?:\.[0-9OoSsIl]{1,2})?)\b',
      caseSensitive: false,
    );
    final genericTaxRegex = RegExp(
      r'\b(?:total\s+tax|tax|gst)\b(?:\s*@?\s*([0-9]+(?:\.[0-9]+)?)%?)?[\s\.:₹=RsINR\-\/]*([0-9OoSsIl,]+(?:\.[0-9OoSsIl]{1,2})?)\b',
      caseSensitive: false,
    );

    // Lines that must NEVER be parsed as a Grand Total
    final totalBlacklistKeywords = [
      'tendered',
      'cash received',
      'cash paid',
      'customer paid',
      'amount paid',
      'cash given',
      'change due',
      'change returned',
      'balance returned',
      'balance due: 0',
      'total qty',
      'total quantity',
      'total items',
      'total pcs',
      'total weight',
      'total savings',
      'you saved',
    ];

    // Scan bottom-up for totals, taxes, and adjustments
    for (int i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      final lower = line.toLowerCase().trim();

      // Skip lines in the total blacklist
      final isBlacklisted = totalBlacklistKeywords.any((k) => lower.contains(k));

      // 1. Check Subtotal
      if (subtotalInPaise == null) {
        final match = subtotalRegex.firstMatch(line);
        if (match != null) {
          subtotalInPaise = _parsePaise(match.group(1));
        }
      }

      // 2. Check Grand Total
      if (!isBlacklisted) {
        // Try high-priority match first
        final highMatch = highPriorityTotalRegex.firstMatch(line);
        if (highMatch != null) {
          final amt = _parsePaise(highMatch.group(1));
          if (amt != null && amt > 0) {
            totalInPaise ??= amt;
          }
        } else if (totalInPaise == null) {
          // Standard match
          final match = standardTotalRegex.firstMatch(line);
          if (match != null) {
            final amt = _parsePaise(match.group(1));
            if (amt != null && amt > 0) {
              totalInPaise = amt;
            }
          }
        }
      }

      // 3. Check Discount
      if (discountInPaise == null) {
        final match = discountRegex.firstMatch(line);
        if (match != null) {
          discountInPaise = _parsePaise(match.group(1));
        }
      }

      // 4. Check Round Off
      if (roundOffInPaise == null) {
        final match = roundOffRegex.firstMatch(line);
        if (match != null) {
          roundOffInPaise = _parsePaise(match.group(1));
        }
      }

      // 5. Check Tip
      if (tipInPaise == null) {
        final match = tipRegex.firstMatch(line);
        if (match != null) {
          tipInPaise = _parsePaise(match.group(1));
        }
      }

      // 6. Check Service Charge / Delivery / Packaging Charges
      if (additionalChargesInPaise == null) {
        final svcMatch = serviceChargeRegex.firstMatch(line);
        if (svcMatch != null) {
          additionalChargesInPaise = _parsePaise(svcMatch.group(1));
        } else {
          final pkgMatch = packagingChargeRegex.firstMatch(line);
          if (pkgMatch != null) {
            additionalChargesInPaise = _parsePaise(pkgMatch.group(1));
          }
        }
      }

      // 7. Check Taxes (search all occurrences on the line)
      for (final match in cgstRegex.allMatches(line)) {
        final rate = double.tryParse(match.group(1) ?? '');
        final amt = _parsePaise(match.group(2));
        if (amt != null && amt > 0 && !taxes.any((t) => t.name == 'CGST' && t.rate == rate && t.amountInPaise == amt)) {
          taxes.add(ReceiptTaxItem(name: 'CGST', rate: rate, amountInPaise: amt));
        }
      }

      for (final match in sgstRegex.allMatches(line)) {
        final rate = double.tryParse(match.group(1) ?? '');
        final amt = _parsePaise(match.group(2));
        if (amt != null && amt > 0 && !taxes.any((t) => t.name == 'SGST' && t.rate == rate && t.amountInPaise == amt)) {
          taxes.add(ReceiptTaxItem(name: 'SGST', rate: rate, amountInPaise: amt));
        }
      }

      for (final match in igstRegex.allMatches(line)) {
        final rate = double.tryParse(match.group(1) ?? '');
        final amt = _parsePaise(match.group(2));
        if (amt != null && amt > 0 && !taxes.any((t) => t.name == 'IGST' && t.rate == rate && t.amountInPaise == amt)) {
          taxes.add(ReceiptTaxItem(name: 'IGST', rate: rate, amountInPaise: amt));
        }
      }

      for (final match in utgstRegex.allMatches(line)) {
        final rate = double.tryParse(match.group(1) ?? '');
        final amt = _parsePaise(match.group(2));
        if (amt != null && amt > 0 && !taxes.any((t) => t.name == 'UTGST' && t.rate == rate && t.amountInPaise == amt)) {
          taxes.add(ReceiptTaxItem(name: 'UTGST', rate: rate, amountInPaise: amt));
        }
      }

      for (final match in vatRegex.allMatches(line)) {
        final rate = double.tryParse(match.group(1) ?? '');
        final amt = _parsePaise(match.group(2));
        if (amt != null && amt > 0 && !taxes.any((t) => t.name == 'VAT' && t.rate == rate && t.amountInPaise == amt)) {
          taxes.add(ReceiptTaxItem(name: 'VAT', rate: rate, amountInPaise: amt));
        }
      }

      // Generic tax fallback only if no structured GST/VAT was detected
      if (taxes.isEmpty) {
        final match = genericTaxRegex.firstMatch(line);
        if (match != null && !lower.contains('invoice') && !lower.contains('cgst') && !lower.contains('sgst')) {
          final rate = double.tryParse(match.group(1) ?? '');
          final amt = _parsePaise(match.group(2));
          if (amt != null && amt > 0) {
            taxes.add(ReceiptTaxItem(name: 'GST/Tax', rate: rate, amountInPaise: amt));
          }
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
      'utgst',
      'tax',
      'vat',
      'gst',
      'discount',
      'disc',
      'round off',
      'roundoff',
      'rnd off',
      'cash tendered',
      'change',
      'balance due',
      'amount paid',
      'card',
      'upi',
      'tip',
      'delivery charge',
      'service charge',
      'packaging charge',
      'fssai',
      'gstin',
      'phone',
      'tel:',
      'invoice',
      'bill no',
      'date:',
      'time:',
      'table',
      'steward',
      'order id',
      'cashier',
    ];

    // Pattern 1: Single line: Name [Qty] [Unit Price] [Line Total]
    // e.g. "Paneer Masala 2 x 150.00 300.00" or "Burger 1 120.00" or "Coffee 150.00"
    final lineItemRegex = RegExp(
      r'^(.*?)\s+(?:(\d+(?:\.\d+)?)\s*(?:x|nos|kg|qty|pc|pcs)?\s+)?(?:[₹=RsINR\s]*([0-9OoSsIl,]+(?:\.[0-9OoSsIl]{1,2})?)\s+)?([0-9OoSsIl,]+(?:\.[0-9OoSsIl]{1,2}))\s*$',
      caseSensitive: false,
    );

    // Pattern 2: Standalone Qty + Price line (for multi-line item entries)
    // e.g. "2 x 150.00 300.00" or "1 120.00"
    final priceOnlyRegex = RegExp(
      r'^(?:(\d+(?:\.\d+)?)\s*(?:x|nos|kg|qty|pc|pcs)?\s+)?(?:[₹=RsINR\s]*([0-9OoSsIl,]+(?:\.[0-9OoSsIl]{1,2})?)\s+)?([0-9OoSsIl,]+(?:\.[0-9OoSsIl]{1,2}))\s*$',
      caseSensitive: false,
    );

    for (int i = 0; i < lines.length; i++) {
      final rawLine = lines[i];
      final lower = rawLine.toLowerCase().trim();

      // Skip lines matching summary or metadata keywords
      final isSummaryLine = summaryKeywords.any((k) => lower.startsWith(k) || lower.contains('$k:'));
      final isDateOrTime = RegExp(r'\b\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}\b').hasMatch(rawLine);

      if (isSummaryLine || isDateOrTime || lower.length < 3) {
        continue;
      }

      // Filter out HSN/SAC codes from the line before matching
      final cleanedLine = _cleanLineFromHsnAndNoise(rawLine);

      final match = lineItemRegex.firstMatch(cleanedLine);
      if (match != null) {
        var nameCandidate = match.group(1)?.trim();
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

        // Avoid false positive where candidate starts with summary keyword
        final nameLower = nameCandidate.toLowerCase();
        if (summaryKeywords.any((k) => nameLower.startsWith(k))) {
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
      } else if (i > 0) {
        // Multi-line item fallback: Check if previous line had a text name and current line has price/qty
        final prevLine = lines[i - 1].trim();
        final prevLower = prevLine.toLowerCase();
        final isPrevSummary = summaryKeywords.any((k) => prevLower.startsWith(k) || prevLower.contains('$k:'));
        final isPrevPureText = RegExp(r'^[a-zA-Z\s\(\)&,-]{3,}$').hasMatch(prevLine);

        if (!isPrevSummary && isPrevPureText) {
          final priceMatch = priceOnlyRegex.firstMatch(cleanedLine);
          if (priceMatch != null) {
            final qtyStr = priceMatch.group(1);
            final unitPriceStr = priceMatch.group(2);
            final totalStr = priceMatch.group(3);

            final lineTotalPaise = _parsePaise(totalStr);
            if (lineTotalPaise != null && lineTotalPaise > 0) {
              final qty = double.tryParse(qtyStr ?? '') ?? 1.0;
              var unitPricePaise = _parsePaise(unitPriceStr);
              if (unitPricePaise == null || unitPricePaise <= 0) {
                unitPricePaise = (lineTotalPaise / (qty > 0 ? qty : 1.0)).round();
              }

              items.add(
                ReceiptItem(
                  id: _uuid.v4(),
                  name: prevLine,
                  quantity: qty,
                  unitPriceInPaise: unitPricePaise,
                  totalPriceInPaise: lineTotalPaise,
                  confidence: 0.90,
                ),
              );
            }
          }
        }
      }
    }

    return items;
  }

  /// Removes HSN/SAC numbers and internal codes from text lines.
  String _cleanLineFromHsnAndNoise(String line) {
    // 1. Remove explicit HSN/SAC prefixes and 4-8 digit codes (e.g. HSN: 996331 or SAC 210690)
    var cleaned = line.replaceAll(
      RegExp(r'\b(?:hsn(?:\/sac)?|sac)(?:\s*(?:code|no|num))?[:\s\.-]*[0-9]{4,8}\b', caseSensitive: false),
      ' ',
    );

    // 2. Remove leading 4-8 digit HSN/item codes at the start of a line (e.g. "996331 Tandoori Roti" -> "Tandoori Roti")
    cleaned = cleaned.replaceAll(RegExp(r'^[0-9]{4,8}\s+(?=[a-zA-Z])'), ' ');

    // 3. Remove standalone 6 to 8 digit HSN codes anywhere in the line
    cleaned = cleaned.replaceAll(RegExp(r'\b[0-9]{6,8}\b'), ' ');

    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // ==========================================
  // PAYMENT METHOD EXTRACTION
  // ==========================================

  ReceiptPayment _extractPaymentMethod(List<String> lines) {
    for (final line in lines.reversed) {
      final lower = line.toLowerCase();
      if (lower.contains('upi') ||
          lower.contains('gpay') ||
          lower.contains('google pay') ||
          lower.contains('phonepe') ||
          lower.contains('paytm') ||
          lower.contains('bhim') ||
          lower.contains('upi qr')) {
        return const ReceiptPayment(method: 'UPI');
      }
      if (lower.contains('credit card') ||
          lower.contains('debit card') ||
          lower.contains('visa') ||
          lower.contains('mastercard') ||
          lower.contains('rupay') ||
          lower.contains('pos sale') ||
          lower.contains('amex')) {
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
          m.contains('bazaar') ||
          m.contains('dmart') ||
          m.contains('reliance fresh') ||
          m.contains('more retail')) {
        return ExpenseCategory.groceries;
      }
      if (m.contains('petrol') ||
          m.contains('fuel') ||
          m.contains('hp ') ||
          m.contains('indian oil') ||
          m.contains('bharat petroleum') ||
          m.contains('shell') ||
          m.contains('nayara')) {
        return ExpenseCategory.transport;
      }
      if (m.contains('cinema') ||
          m.contains('theatre') ||
          m.contains('pvr') ||
          m.contains('inox') ||
          m.contains('cinepolis')) {
        return ExpenseCategory.activities;
      }
      if (m.contains('hotel') ||
          m.contains('resort') ||
          m.contains('homestay') ||
          m.contains('hostel') ||
          m.contains('inn') ||
          m.contains('lodge') ||
          m.contains('oyo') ||
          m.contains('zostel')) {
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
          m.contains('kitchen') ||
          m.contains('haldiram') ||
          m.contains('bikanervala') ||
          m.contains('mcdonalds') ||
          m.contains('dominos') ||
          m.contains('kfc') ||
          m.contains('subway') ||
          m.contains('sweets')) {
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
        text.contains('roti') ||
        text.contains('naan') ||
        text.contains('paneer') ||
        text.contains('coffee') ||
        text.contains('tea') ||
        text.contains('bar') ||
        text.contains('food') ||
        text.contains('swiggy') ||
        text.contains('zomato') ||
        text.contains('haldiram') ||
        text.contains('bikanervala')) {
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
        text.contains('bigbasket') ||
        text.contains('dmart') ||
        text.contains('vegetables') ||
        text.contains('fruits') ||
        text.contains('kirana')) {
      return ExpenseCategory.groceries;
    }

    // Transport / Fuel
    if (text.contains('petrol') ||
        text.contains('fuel') ||
        text.contains('diesel') ||
        text.contains('cng') ||
        text.contains('indian oil') ||
        text.contains('hpcl') ||
        text.contains('bpcl') ||
        text.contains('uber') ||
        text.contains('ola') ||
        text.contains('rapido') ||
        text.contains('taxi') ||
        text.contains('auto') ||
        text.contains('toll') ||
        text.contains('fastag') ||
        text.contains('parking') ||
        text.contains('metro')) {
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
        text.contains('zudio') ||
        text.contains('h&m') ||
        text.contains('decathlon') ||
        text.contains('pharmacy') ||
        text.contains('chemist') ||
        text.contains('apollo') ||
        text.contains('medplus')) {
      return ExpenseCategory.shopping;
    }

    // Entertainment / Activities
    if (text.contains('cinema') ||
        text.contains('movie') ||
        text.contains('pvr') ||
        text.contains('inox') ||
        text.contains('theatre') ||
        text.contains('cinepolis') ||
        text.contains('amusement') ||
        text.contains('tickets') ||
        text.contains('museum') ||
        text.contains('water park')) {
      return ExpenseCategory.activities;
    }

    // Stay
    if (text.contains('hotel') ||
        text.contains('resort') ||
        text.contains('homestay') ||
        text.contains('zostel') ||
        text.contains('oyo') ||
        text.contains('hostel') ||
        text.contains('check-in') ||
        text.contains('room rent')) {
      return ExpenseCategory.stay;
    }

    // General fallback
    return ExpenseCategory.predictFromTitle(merchantName ?? '');
  }

  // ==========================================
  // FIELD CONFIDENCE HEURISTIC COMPUTATION
  // ==========================================

  ReceiptFieldConfidence _computeFieldConfidence({
    required ReceiptMerchant merchant,
    required ReceiptMetadata metadata,
    required ReceiptSummary summary,
    required List<ReceiptItem> items,
    required int calculatedTotal,
    required bool isConsistent,
    required bool wasTotalInferred,
    required int diffPaise,
  }) {
    final fieldWarnings = <String>[];

    // Merchant Confidence
    final FieldVerificationStatus merchantStatus;
    if (merchant.name != null && merchant.name!.trim().length >= 3) {
      merchantStatus = FieldVerificationStatus.verified;
    } else {
      merchantStatus = FieldVerificationStatus.needsReview;
      fieldWarnings.add('Merchant name could not be identified with certainty.');
    }

    // Date Confidence
    final FieldVerificationStatus dateStatus;
    if (metadata.date != null) {
      dateStatus = FieldVerificationStatus.verified;
    } else {
      dateStatus = FieldVerificationStatus.needsReview;
      fieldWarnings.add('Receipt date was not detected.');
    }

    // Total Confidence
    final FieldVerificationStatus totalStatus;
    if (wasTotalInferred) {
      totalStatus = FieldVerificationStatus.inferred;
    } else if (summary.totalInPaise != null && summary.totalInPaise! > 0) {
      if (isConsistent) {
        totalStatus = FieldVerificationStatus.verified;
      } else {
        totalStatus = FieldVerificationStatus.needsReview;
      }
    } else {
      totalStatus = FieldVerificationStatus.needsReview;
    }

    // Tax Confidence
    final FieldVerificationStatus taxStatus;
    if (summary.taxes.isNotEmpty) {
      taxStatus = FieldVerificationStatus.verified;
    } else {
      if (diffPaise.abs() > 100 && (diffPaise / 100.0).abs() < 50.0) {
        taxStatus = FieldVerificationStatus.needsReview;
        fieldWarnings.add('Unmatched difference in total may indicate missing tax items.');
      } else {
        taxStatus = FieldVerificationStatus.verified;
      }
    }

    // Items Confidence
    final FieldVerificationStatus itemsStatus;
    if (items.isNotEmpty) {
      itemsStatus = FieldVerificationStatus.verified;
    } else {
      itemsStatus = FieldVerificationStatus.needsReview;
      fieldWarnings.add('No itemized breakdown was detected.');
    }

    return ReceiptFieldConfidence(
      merchant: merchantStatus,
      date: dateStatus,
      total: totalStatus,
      taxes: taxStatus,
      items: itemsStatus,
      fieldWarnings: fieldWarnings,
    );
  }

  // ==========================================
  // HELPER: PARSE PAISE (ZERO FLOATING ARITHMETIC)
  // Tolerant to optical OCR character confusion and signed micro-amounts
  // ==========================================

  int? _parsePaise(String? amountStr) {
    if (amountStr == null) return null;
    var cleaned = amountStr
        .replaceAll(RegExp(r'[₹$€£\s]'), '')
        .replaceAll(',', '')
        .trim();
    if (cleaned.isEmpty) return null;

    final isNegative = cleaned.startsWith('-');
    if (isNegative || cleaned.startsWith('+')) {
      cleaned = cleaned.substring(1).trim();
    }
    if (cleaned.isEmpty) return null;

    // Optical OCR confusion sanitization for price tokens:
    // e.g. 'O' or 'o' -> '0', 'I' or 'l' or '|' -> '1', 'S' or 's' -> '5', 'B' -> '8'
    if (RegExp(r'[0-9\.]').hasMatch(cleaned)) {
      cleaned = cleaned
          .replaceAll(RegExp(r'[Oo]'), '0')
          .replaceAll(RegExp(r'[Il|]'), '1')
          .replaceAll(RegExp(r'[Ss]'), '5')
          .replaceAll(RegExp(r'B'), '8');
    }

    final parts = cleaned.split('.');
    if (parts.length == 1) {
      final rupees = int.tryParse(parts[0]);
      if (rupees == null) return null;
      final total = rupees * 100;
      return isNegative ? -total : total;
    } else if (parts.length == 2) {
      final rupees = int.tryParse(parts[0]);
      var paiseStr = parts[1];
      if (paiseStr.length == 1) paiseStr += '0';
      if (paiseStr.length > 2) paiseStr = paiseStr.substring(0, 2);
      final paise = int.tryParse(paiseStr);

      if (rupees != null && paise != null) {
        final total = (rupees.abs() * 100) + paise;
        return isNegative ? -total : total;
      }
    }
    return null;
  }
}
