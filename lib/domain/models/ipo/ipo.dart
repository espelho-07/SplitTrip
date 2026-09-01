enum IpoMarketType {
  mainboard,
  sme;

  static IpoMarketType fromString(String? val) {
    final lower = val?.toLowerCase();
    if (lower != null && (lower.contains('sme') || lower == 'sme')) {
      return IpoMarketType.sme;
    }
    return IpoMarketType.mainboard;
  }

  String get displayName => this == IpoMarketType.sme ? 'SME' : 'Mainboard';
}

enum IpoStatus {
  open,
  upcoming,
  closed,
  allotmentOut,
  listed;

  static IpoStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'live':
      case 'open':
      case 'active':
      case 'open_now':
        return IpoStatus.open;
      case 'upcoming':
      case 'future':
        return IpoStatus.upcoming;
      case 'closed':
      case 'bidding_closed':
        return IpoStatus.closed;
      case 'allotmentout':
      case 'allotment_out':
      case 'allotment':
      case 'allotted':
        return IpoStatus.allotmentOut;
      case 'listed':
      case 'trading':
        return IpoStatus.listed;
      default:
        return IpoStatus.upcoming;
    }
  }

  String get displayName {
    switch (this) {
      case IpoStatus.open:
        return 'Open Now';
      case IpoStatus.upcoming:
        return 'Upcoming';
      case IpoStatus.closed:
        return 'Closed';
      case IpoStatus.allotmentOut:
        return 'Allotment Out';
      case IpoStatus.listed:
        return 'Listed';
    }
  }
}

/// Granular, category-wise subscription data
class IpoSubscription {
  final double? qib; // Qualified Institutional Buyers (e.g. 143.58x)
  final double? nii; // Non-Institutional / HNI (e.g. 71.23x)
  final double? retail; // Retail Individual Investors (e.g. 17.84x)
  final double? employee; // Employee reservation (e.g. 2.1x)
  final double? shareholder; // Shareholder quota (e.g. 4.5x)
  final double? total; // Overall subscription multiple (e.g. 63.6x)

  const IpoSubscription({
    this.qib,
    this.nii,
    this.retail,
    this.employee,
    this.shareholder,
    this.total,
  });

  bool get hasAnyData =>
      qib != null ||
      nii != null ||
      retail != null ||
      employee != null ||
      shareholder != null ||
      total != null;

  factory IpoSubscription.fromJson(Map<String, dynamic> json) {
    return IpoSubscription(
      qib: (json['qib'] as num?)?.toDouble() ?? (json['qib_x'] as num?)?.toDouble(),
      nii: (json['nii'] as num?)?.toDouble() ?? (json['hni_x'] as num?)?.toDouble() ?? (json['nii_x'] as num?)?.toDouble(),
      retail: (json['retail'] as num?)?.toDouble() ?? (json['rii_x'] as num?)?.toDouble() ?? (json['retail_x'] as num?)?.toDouble(),
      employee: (json['employee'] as num?)?.toDouble() ?? (json['emp_x'] as num?)?.toDouble(),
      shareholder: (json['shareholder'] as num?)?.toDouble() ?? (json['sh_x'] as num?)?.toDouble(),
      total: (json['total'] as num?)?.toDouble() ?? (json['overall'] as num?)?.toDouble() ?? (json['total_x'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (qib != null) 'qib': qib,
      if (nii != null) 'nii': nii,
      if (retail != null) 'retail': retail,
      if (employee != null) 'employee': employee,
      if (shareholder != null) 'shareholder': shareholder,
      if (total != null) 'total': total,
    };
  }
}

class Ipo {
  final String id;
  final String name;
  final String companyName;
  final String symbol;
  final IpoMarketType marketType;
  final IpoStatus status;
  final DateTime openDate;
  final DateTime closeDate;
  final DateTime? allotmentDate;
  final DateTime? listingDate;
  final int minPrice; // In Rupees (e.g. 450)
  final int maxPrice; // In Rupees (e.g. 475)
  final int lotSize; // Shares per lot (e.g. 30)
  final double? issueSizeCrores; // e.g. 6560.0 Cr
  final double? freshIssueCrores;
  final double? ofsCrores;
  final IpoSubscription? subscription;
  final double? subscriptionOverall; // e.g. 63.6x
  final int? gmp; // Unofficial GMP in Rupees (e.g. 75)
  final int? issuePrice; // Final issue/cutoff price in Rupees (e.g. 475)
  final int? listingPrice; // Listing day opening price in Rupees
  final int? currentPrice; // Current trading market price in Rupees
  final DateTime lastUpdated;
  final bool isTracked;

  const Ipo({
    required this.id,
    required this.name,
    required this.companyName,
    required this.symbol,
    required this.marketType,
    required this.status,
    required this.openDate,
    required this.closeDate,
    this.allotmentDate,
    this.listingDate,
    required this.minPrice,
    required this.maxPrice,
    required this.lotSize,
    this.issueSizeCrores,
    this.freshIssueCrores,
    this.ofsCrores,
    this.subscription,
    this.subscriptionOverall,
    this.gmp,
    this.issuePrice,
    this.listingPrice,
    this.currentPrice,
    required this.lastUpdated,
    this.isTracked = false,
  });

  /// Minimum investment in Rupees for 1 lot at cutoff (max price)
  int get minInvestmentRupees => lotSize * (maxPrice > 0 ? maxPrice : minPrice);

  /// Price band formatted string e.g. "₹450 – ₹475" or "₹475"
  String get priceBandFormatted {
    if (minPrice == maxPrice || minPrice <= 0) {
      return '₹$maxPrice';
    }
    return '₹$minPrice – ₹$maxPrice';
  }

  /// Evaluates real-time dynamic status based on calendar dates to avoid stale cached "Open" states
  IpoStatus get dynamicStatus {
    if (status == IpoStatus.listed) return IpoStatus.listed;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final open = DateTime(openDate.year, openDate.month, openDate.day);
    final close = DateTime(closeDate.year, closeDate.month, closeDate.day);

    if (listingDate != null) {
      final list = DateTime(listingDate!.year, listingDate!.month, listingDate!.day);
      if (!today.isBefore(list)) {
        return IpoStatus.listed;
      }
    }

    if (allotmentDate != null) {
      final allot = DateTime(allotmentDate!.year, allotmentDate!.month, allotmentDate!.day);
      if (!today.isBefore(allot) && today.isAfter(close)) {
        return IpoStatus.allotmentOut;
      }
    }

    if (today.isBefore(open)) {
      return IpoStatus.upcoming;
    }

    if (!today.isBefore(open) && !today.isAfter(close)) {
      return IpoStatus.open;
    }

    if (today.isAfter(close)) {
      return IpoStatus.closed;
    }

    return status;
  }

  /// True if bidding is active today
  bool get isBiddingActive {
    return dynamicStatus == IpoStatus.open;
  }

  /// Timezone-safe calendar date parser (preserves exact day without UTC shifting)
  static DateTime parseIpoDate(dynamic value, [DateTime? fallback]) {
    if (value == null) return fallback ?? DateTime.now();
    if (value is DateTime) return DateTime(value.year, value.month, value.day);
    final str = value.toString().trim();
    if (str.isEmpty) return fallback ?? DateTime.now();

    // Format: YYYY-MM-DD
    final ymdMatch = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(str);
    if (ymdMatch != null) {
      final year = int.parse(ymdMatch.group(1)!);
      final month = int.parse(ymdMatch.group(2)!);
      final day = int.parse(ymdMatch.group(3)!);
      return DateTime(year, month, day);
    }

    // Format: DD-MM-YYYY or DD/MM/YYYY
    final dmyMatch = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})').firstMatch(str);
    if (dmyMatch != null) {
      final day = int.parse(dmyMatch.group(1)!);
      final month = int.parse(dmyMatch.group(2)!);
      final year = int.parse(dmyMatch.group(3)!);
      return DateTime(year, month, day);
    }

    try {
      final parsed = DateTime.parse(str);
      return DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {
      return fallback ?? DateTime.now();
    }
  }

  static DateTime? parseOptionalIpoDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return DateTime(value.year, value.month, value.day);
    final str = value.toString().trim();
    if (str.isEmpty || str.toLowerCase() == 'null' || str.toLowerCase() == 'tbd') return null;
    return parseIpoDate(value);
  }

  Ipo copyWith({
    String? id,
    String? name,
    String? companyName,
    String? symbol,
    IpoMarketType? marketType,
    IpoStatus? status,
    DateTime? openDate,
    DateTime? closeDate,
    DateTime? allotmentDate,
    DateTime? listingDate,
    int? minPrice,
    int? maxPrice,
    int? lotSize,
    double? issueSizeCrores,
    double? freshIssueCrores,
    double? ofsCrores,
    IpoSubscription? subscription,
    double? subscriptionOverall,
    int? gmp,
    int? issuePrice,
    int? listingPrice,
    int? currentPrice,
    DateTime? lastUpdated,
    bool? isTracked,
  }) {
    return Ipo(
      id: id ?? this.id,
      name: name ?? this.name,
      companyName: companyName ?? this.companyName,
      symbol: symbol ?? this.symbol,
      marketType: marketType ?? this.marketType,
      status: status ?? this.status,
      openDate: openDate ?? this.openDate,
      closeDate: closeDate ?? this.closeDate,
      allotmentDate: allotmentDate ?? this.allotmentDate,
      listingDate: listingDate ?? this.listingDate,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      lotSize: lotSize ?? this.lotSize,
      issueSizeCrores: issueSizeCrores ?? this.issueSizeCrores,
      freshIssueCrores: freshIssueCrores ?? this.freshIssueCrores,
      ofsCrores: ofsCrores ?? this.ofsCrores,
      subscription: subscription ?? this.subscription,
      subscriptionOverall: subscriptionOverall ?? this.subscriptionOverall,
      gmp: gmp ?? this.gmp,
      issuePrice: issuePrice ?? this.issuePrice,
      listingPrice: listingPrice ?? this.listingPrice,
      currentPrice: currentPrice ?? this.currentPrice,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isTracked: isTracked ?? this.isTracked,
    );
  }

  factory Ipo.fromJson(Map<String, dynamic> json) {
    // 1. Nested schedule dates support (FinAPI style) or flat keys
    final schedule = json['schedule'] is Map<String, dynamic> ? json['schedule'] as Map<String, dynamic> : null;
    final openDateRaw = schedule?['startDate'] ?? json['openDate'] ?? json['open_date'] ?? json['bidding_start_date'] ?? json['startDate'];
    final closeDateRaw = schedule?['endDate'] ?? json['closeDate'] ?? json['close_date'] ?? json['bidding_end_date'] ?? json['endDate'];
    final allotmentDateRaw = schedule?['allotmentFinalization'] ?? schedule?['allotmentDate'] ?? json['allotmentDate'] ?? json['allotment_date'];
    final listingDateRaw = schedule?['listingDate'] ?? json['listingDate'] ?? json['listing_date'];

    // 2. Robust Price parsing (handles "₹408 – ₹429", "₹59", "450 - 475" strings or direct numbers)
    int minP = 0;
    int maxP = 0;

    final rawMin = json['minPrice'] ?? json['min_price'] ?? json['price_band_min'];
    if (rawMin is num) {
      minP = rawMin.toInt();
    }
    final rawMax = json['maxPrice'] ?? json['max_price'] ?? json['price_band_max'] ?? json['issuePrice'] ?? json['issue_price'];
    if (rawMax is num) {
      maxP = rawMax.toInt();
    }

    final priceStr = json['priceRange'] as String? ??
        json['price_range'] as String? ??
        json['priceBand'] as String? ??
        json['price_band'] as String?;

    if (priceStr != null && (minP == 0 && maxP == 0)) {
      final numbers = RegExp(r'(\d+)').allMatches(priceStr).map((m) => int.parse(m.group(0)!)).toList();
      if (numbers.length >= 2) {
        minP = numbers[0];
        maxP = numbers[1];
      } else if (numbers.length == 1) {
        minP = numbers[0];
        maxP = numbers[0];
      }
    }

    // 3. Robust Lot size parsing (handles String "34" or num 34)
    int parsedLot = 1;
    final rawLot = json['lotSize'] ?? json['lot_size'] ?? json['market_lot'];
    if (rawLot is num) {
      parsedLot = rawLot.toInt();
    } else if (rawLot is String) {
      final digits = rawLot.replaceAll(RegExp(r'[^0-9]'), '');
      parsedLot = int.tryParse(digits) ?? 1;
    }

    final rawSub = json['subscription'];
    IpoSubscription? sub;
    if (rawSub is Map<String, dynamic>) {
      sub = IpoSubscription.fromJson(rawSub);
    } else if (json['qib'] != null || json['nii'] != null || json['retail'] != null) {
      sub = IpoSubscription.fromJson(json);
    }

    final totalSub = (json['subscriptionOverall'] ?? json['subscription_overall'] ?? json['total_subscription'] ?? sub?.total as num?)?.toDouble();
    final sym = json['symbol'] as String? ?? json['ticker'] as String? ?? '';
    final nameStr = json['name'] as String? ?? json['companyName'] as String? ?? json['company_name'] as String? ?? json['ipoName'] as String? ?? 'IPO';

    return Ipo(
      id: json['id'] as String? ?? (sym.isNotEmpty ? 'ipo_${sym.toLowerCase()}' : 'ipo_${nameStr.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}'),
      name: nameStr,
      companyName: json['companyName'] as String? ?? json['company_name'] as String? ?? nameStr,
      symbol: sym,
      marketType: IpoMarketType.fromString(json['type'] as String? ?? json['marketType'] as String? ?? json['market_type'] as String? ?? json['category'] as String?),
      status: IpoStatus.fromString(json['status'] as String? ?? json['ipo_status'] as String?),
      openDate: parseIpoDate(openDateRaw),
      closeDate: parseIpoDate(closeDateRaw, parseIpoDate(openDateRaw).add(const Duration(days: 3))),
      allotmentDate: parseOptionalIpoDate(allotmentDateRaw),
      listingDate: parseOptionalIpoDate(listingDateRaw),
      minPrice: minP,
      maxPrice: maxP > 0 ? maxP : minP,
      lotSize: parsedLot > 0 ? parsedLot : 1,
      issueSizeCrores: (json['issueSizeCrores'] ?? json['issue_size_crores'] ?? json['issue_size'] as num?)?.toDouble(),
      freshIssueCrores: (json['freshIssueCrores'] ?? json['fresh_issue_crores'] ?? json['fresh_issue'] as num?)?.toDouble(),
      ofsCrores: (json['ofsCrores'] ?? json['ofs_crores'] ?? json['ofs'] as num?)?.toDouble(),
      subscription: sub,
      subscriptionOverall: totalSub,
      gmp: (json['gmp'] ?? json['grey_market_premium'] as num?)?.toInt(),
      issuePrice: (json['issuePrice'] ?? json['issue_price'] as num?)?.toInt(),
      listingPrice: (json['listingPrice'] ?? json['listing_price'] as num?)?.toInt(),
      currentPrice: (json['currentPrice'] ?? json['current_price'] as num?)?.toInt(),
      lastUpdated: json['lastUpdated'] != null ? DateTime.tryParse(json['lastUpdated'] as String) ?? DateTime.now() : DateTime.now(),
      isTracked: json['isTracked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'companyName': companyName,
      'symbol': symbol,
      'marketType': marketType.name,
      'status': status.name,
      'openDate': openDate.toIso8601String(),
      'closeDate': closeDate.toIso8601String(),
      'allotmentDate': allotmentDate?.toIso8601String(),
      'listingDate': listingDate?.toIso8601String(),
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'lotSize': lotSize,
      'issueSizeCrores': issueSizeCrores,
      'freshIssueCrores': freshIssueCrores,
      'ofsCrores': ofsCrores,
      'subscription': subscription?.toJson(),
      'subscriptionOverall': subscriptionOverall,
      'gmp': gmp,
      'issuePrice': issuePrice,
      'listingPrice': listingPrice,
      'currentPrice': currentPrice,
      'lastUpdated': lastUpdated.toIso8601String(),
      'isTracked': isTracked,
    };
  }
}
