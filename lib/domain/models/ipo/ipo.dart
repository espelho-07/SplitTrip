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
  final DateTime? refundDate;
  final int minPrice; // In Rupees (e.g. 450)
  final int maxPrice; // In Rupees (e.g. 475)
  final int lotSize; // Shares per lot (e.g. 30)
  final double? issueSizeCrores; // e.g. 6560.0 Cr
  final double? freshIssueCrores;
  final double? ofsCrores;
  final IpoSubscription? subscription;
  final double? subscriptionOverall; // e.g. 63.6x
  final int? gmp; // Unofficial GMP in Rupees (e.g. 75)
  final DateTime? gmpLastValidAt; // Timestamp when GMP was last received from upstream API
  final DateTime? fetchedAt; // Timestamp when record was fetched from upstream API
  final int? issuePrice; // Final issue/cutoff price in Rupees (e.g. 475)
  final int? listingPrice; // Listing day opening price in Rupees
  final int? currentPrice; // Current trading market price in Rupees
  final DateTime lastUpdated;
  final bool isTracked;
  final String? slug;
  final DateTime? sourceUpdatedAt;
  final bool isStale;

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
    this.refundDate,
    required this.minPrice,
    required this.maxPrice,
    required this.lotSize,
    this.issueSizeCrores,
    this.freshIssueCrores,
    this.ofsCrores,
    this.subscription,
    this.subscriptionOverall,
    this.gmp,
    this.gmpLastValidAt,
    this.fetchedAt,
    this.issuePrice,
    this.listingPrice,
    this.currentPrice,
    required this.lastUpdated,
    this.isTracked = false,
    this.slug,
    this.sourceUpdatedAt,
    this.isStale = false,
  });

  /// Max allowable clock skew into the future for upstream timestamps (5 minutes).
  static const Duration maxFutureClockSkew = Duration(minutes: 5);

  /// Maximum validity duration for a Grey Market Premium quote (24 hours).
  static const Duration gmpValidityDuration = Duration(hours: 24);

  /// Whether the GMP quote is expired, untrusted, or inapplicable.
  ///
  /// Criteria for expiration / invalidity:
  /// 1. Listed: Once an IPO is listed on stock exchanges, pre-listing GMP is void.
  /// 2. Missing timestamp (Legacy Policy): If [gmpLastValidAt] is missing/null, freshness
  ///    cannot be established. In accordance with user protection policy, unverified
  ///    legacy quotes are never presented as current quotes.
  /// 3. Future timestamps: Timestamps more than [maxFutureClockSkew] in the future are
  ///    deemed corrupt/untrusted and expired.
  /// 4. Age: Quotes older than [gmpValidityDuration] (24 hours) from [gmpLastValidAt] are expired.
  ///
  /// Returns `false` if [gmp] is `null` (unquoted, not expired).
  bool get isGmpExpired {
    if (gmp == null) return false;

    // 1. Listed IPOs have no active GMP
    if (status == IpoStatus.listed || dynamicStatus == IpoStatus.listed) {
      return true;
    }

    // 2. Authoritative timestamp check (Legacy Record Policy)
    // If gmpLastValidAt is null, freshness cannot be established.
    // sourceUpdatedAt is explicitly NOT trusted as proof of fresh GMP.
    if (gmpLastValidAt == null) {
      return true;
    }

    final validTimestamp = gmpLastValidAt!.toUtc();
    final nowUtc = DateTime.now().toUtc();

    // 3. Safety check for invalid/corrupt dates (e.g. year before 2020 or epoch 0)
    if (validTimestamp.year < 2020 || validTimestamp.millisecondsSinceEpoch <= 0) {
      return true;
    }

    // 4. Handle future timestamps (clock skew protection)
    final diff = nowUtc.difference(validTimestamp);
    if (diff.isNegative) {
      // Future timestamp: if skew exceeds tolerance, treat as untrusted/expired
      if (diff.abs() > maxFutureClockSkew) {
        return true;
      }
      return false; // Within minor clock skew tolerance, consider fresh
    }

    // 5. Normal age check: must not exceed 24 hours
    return diff > gmpValidityDuration;
  }

  /// Current valid GMP. Returns `null` if GMP is absent or expired (>24h / listed).
  /// Preserves valid 0 (flat/par).
  int? get currentGmp => isGmpExpired ? null : gmp;

  /// Estimated listing price based on cutoff price + current valid GMP.
  /// Returns null if GMP is expired (>24h / listed) or missing.
  int? get estimatedListingPrice {
    final validGmp = currentGmp;
    if (validGmp == null) return null;
    final basePrice = maxPrice > 0 ? maxPrice : minPrice;
    if (basePrice <= 0) return null;
    return basePrice + validGmp;
  }

  /// Estimated listing gain percentage based on current valid GMP.
  /// Returns null if GMP is expired (>24h / listed) or missing.
  double? get estimatedGainPercentage {
    final validGmp = currentGmp;
    if (validGmp == null) return null;
    final basePrice = maxPrice > 0 ? maxPrice : minPrice;
    if (basePrice <= 0) return null;
    return (validGmp / basePrice) * 100.0;
  }

  /// Minimum investment in Rupees for 1 lot at cutoff (max price)
  int get minInvestmentRupees => lotSize * (maxPrice > 0 ? maxPrice : minPrice);

  /// Price band formatted string e.g. "₹450 – ₹475" or "₹475"
  String get priceBandFormatted {
    if (minPrice == maxPrice || minPrice <= 0) {
      return '₹$maxPrice';
    }
    return '₹$minPrice – ₹$maxPrice';
  }

  /// Evaluates real-time dynamic status based on calendar dates in Indian Standard Time (IST)
  /// Strict Invariant: Upcoming IPOs (openDate > today) NEVER appear in Open Now.
  IpoStatus get dynamicStatus {
    if (status == IpoStatus.listed) return IpoStatus.listed;

    final today = todayIst;
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

    // 1. If today is before openDate -> strictly UPCOMING
    if (today.isBefore(open)) {
      return IpoStatus.upcoming;
    }

    // 2. If today is after closeDate -> strictly CLOSED
    if (today.isAfter(close)) {
      return IpoStatus.closed;
    }

    // 3. If openDate <= today <= closeDate -> OPEN NOW
    return IpoStatus.open;
  }

  /// True if bidding is active today in IST
  bool get isBiddingActive {
    return dynamicStatus == IpoStatus.open;
  }

  /// Indian Standard Time (IST, UTC+5:30) today calendar date
  static DateTime get todayIst {
    final utc = DateTime.now().toUtc();
    final ist = utc.add(const Duration(hours: 5, minutes: 30));
    return DateTime(ist.year, ist.month, ist.day);
  }

  static const Map<String, int> _monthMap = {
    'jan': 1, 'january': 1,
    'feb': 2, 'february': 2,
    'mar': 3, 'march': 3,
    'apr': 4, 'april': 4,
    'may': 5,
    'jun': 6, 'june': 6,
    'jul': 7, 'july': 7,
    'aug': 8, 'august': 8,
    'sep': 9, 'sept': 9, 'september': 9,
    'oct': 10, 'october': 10,
    'nov': 11, 'november': 11,
    'dec': 12, 'december': 12,
  };

  /// Timezone-safe calendar date parser supporting ISO, DD-MM-YYYY, and month name strings
  /// Prevents false fallbacks to today that cause upcoming IPOs to appear as Open.
  static DateTime parseIpoDate(dynamic value, [DateTime? fallback]) {
    if (value == null) return fallback ?? todayIst;
    if (value is DateTime) return DateTime(value.year, value.month, value.day);
    final str = value.toString().trim();
    if (str.isEmpty || str.toLowerCase() == 'null' || str.toLowerCase() == 'tbd') {
      return fallback ?? todayIst;
    }

    // 1. Format: YYYY-MM-DD
    final ymdMatch = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})').firstMatch(str);
    if (ymdMatch != null) {
      final year = int.parse(ymdMatch.group(1)!);
      final month = int.parse(ymdMatch.group(2)!);
      final day = int.parse(ymdMatch.group(3)!);
      return DateTime(year, month, day);
    }

    // 2. Format: DD-MonthName-YYYY (e.g. "28-Aug-2026", "28 Aug 2026", "01-September-2026")
    final dMonthYMatch = RegExp(r'^(\d{1,2})[- \/.]([A-Za-z]+)(?:[- \/.](\d{2,4}))?').firstMatch(str);
    if (dMonthYMatch != null) {
      final day = int.parse(dMonthYMatch.group(1)!);
      final monthName = dMonthYMatch.group(2)!.toLowerCase();
      final yearStr = dMonthYMatch.group(3);
      final month = _monthMap[monthName] ?? 1;
      int year = todayIst.year;
      if (yearStr != null && yearStr.isNotEmpty) {
        final parsedYear = int.parse(yearStr);
        year = parsedYear < 100 ? (2000 + parsedYear) : parsedYear;
      }
      return DateTime(year, month, day);
    }

    // 3. Format: MonthName DD, YYYY (e.g. "Aug 28, 2026", "August 28 2026")
    final monthDYMatch = RegExp(r'^([A-Za-z]+)[- \/.](\d{1,2})(?:,?\s*(\d{2,4}))?').firstMatch(str);
    if (monthDYMatch != null) {
      final monthName = monthDYMatch.group(1)!.toLowerCase();
      final day = int.parse(monthDYMatch.group(2)!);
      final yearStr = monthDYMatch.group(3);
      final month = _monthMap[monthName] ?? 1;
      int year = todayIst.year;
      if (yearStr != null && yearStr.isNotEmpty) {
        final parsedYear = int.parse(yearStr);
        year = parsedYear < 100 ? (2000 + parsedYear) : parsedYear;
      }
      return DateTime(year, month, day);
    }

    // 4. Format: DD-MM-YYYY or DD/MM/YYYY
    final dmyMatch = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})').firstMatch(str);
    if (dmyMatch != null) {
      final day = int.parse(dmyMatch.group(1)!);
      final month = int.parse(dmyMatch.group(2)!);
      final parsedYear = int.parse(dmyMatch.group(3)!);
      final year = parsedYear < 100 ? (2000 + parsedYear) : parsedYear;
      return DateTime(year, month, day);
    }

    try {
      final parsed = DateTime.parse(str);
      return DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {
      return fallback ?? todayIst;
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
    DateTime? refundDate,
    int? minPrice,
    int? maxPrice,
    int? lotSize,
    double? issueSizeCrores,
    double? freshIssueCrores,
    double? ofsCrores,
    IpoSubscription? subscription,
    double? subscriptionOverall,
    int? gmp,
    DateTime? gmpLastValidAt,
    DateTime? fetchedAt,
    int? issuePrice,
    int? listingPrice,
    int? currentPrice,
    DateTime? lastUpdated,
    bool? isTracked,
    String? slug,
    DateTime? sourceUpdatedAt,
    bool? isStale,
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
      refundDate: refundDate ?? this.refundDate,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      lotSize: lotSize ?? this.lotSize,
      issueSizeCrores: issueSizeCrores ?? this.issueSizeCrores,
      freshIssueCrores: freshIssueCrores ?? this.freshIssueCrores,
      ofsCrores: ofsCrores ?? this.ofsCrores,
      subscription: subscription ?? this.subscription,
      subscriptionOverall: subscriptionOverall ?? this.subscriptionOverall,
      gmp: gmp ?? this.gmp,
      gmpLastValidAt: gmpLastValidAt ?? this.gmpLastValidAt,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      issuePrice: issuePrice ?? this.issuePrice,
      listingPrice: listingPrice ?? this.listingPrice,
      currentPrice: currentPrice ?? this.currentPrice,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isTracked: isTracked ?? this.isTracked,
      slug: slug ?? this.slug,
      sourceUpdatedAt: sourceUpdatedAt ?? this.sourceUpdatedAt,
      isStale: isStale ?? this.isStale,
    );
  }

  static DateTime? _extractGmpLastValidAt(Map<String, dynamic> json) {
    if (json['ipo_gmp_cache'] is List && (json['ipo_gmp_cache'] as List).isNotEmpty) {
      final first = (json['ipo_gmp_cache'] as List).first;
      if (first is Map<String, dynamic> && first['gmp_last_valid_at'] != null) {
        return DateTime.tryParse(first['gmp_last_valid_at'].toString());
      }
    } else if (json['ipo_gmp_cache'] is Map<String, dynamic>) {
      final map = json['ipo_gmp_cache'] as Map<String, dynamic>;
      if (map['gmp_last_valid_at'] != null) {
        return DateTime.tryParse(map['gmp_last_valid_at'].toString());
      }
    }
    final raw = json['gmp_last_valid_at'] ?? json['gmpLastValidAt'];
    if (raw != null) {
      return DateTime.tryParse(raw.toString());
    }
    return null;
  }

  static DateTime? _extractFetchedAt(Map<String, dynamic> json) {
    final raw = json['fetched_at'] ?? json['fetchedAt'];
    if (raw != null) {
      return DateTime.tryParse(raw.toString());
    }
    return null;
  }

  static int? _extractGmp(Map<String, dynamic> json) {
    if (json['ipo_gmp_cache'] is List && (json['ipo_gmp_cache'] as List).isNotEmpty) {
      final first = (json['ipo_gmp_cache'] as List).first;
      if (first is Map<String, dynamic> && first.containsKey('gmp_raw')) {
        return (first['gmp_raw'] as num?)?.toInt();
      }
    } else if (json['ipo_gmp_cache'] is Map<String, dynamic>) {
      final map = json['ipo_gmp_cache'] as Map<String, dynamic>;
      if (map.containsKey('gmp_raw')) {
        return (map['gmp_raw'] as num?)?.toInt();
      }
    }
    return (json['gmp'] ?? json['grey_market_premium'] as num?)?.toInt();
  }

  factory Ipo.fromJson(Map<String, dynamic> json) {
    // 1. Nested schedule dates support (FinAPI style) or flat keys
    final schedule = json['schedule'] is Map<String, dynamic> ? json['schedule'] as Map<String, dynamic> : null;
    final openDateRaw = schedule?['startDate'] ?? json['openDate'] ?? json['open_date'] ?? json['bidding_start_date'] ?? json['startDate'];
    final closeDateRaw = schedule?['endDate'] ?? json['closeDate'] ?? json['close_date'] ?? json['bidding_end_date'] ?? json['endDate'];
    final allotmentDateRaw = schedule?['allotmentFinalization'] ?? schedule?['allotmentDate'] ?? json['allotmentDate'] ?? json['allotment_date'];
    final listingDateRaw = schedule?['listingDate'] ?? json['listingDate'] ?? json['listing_date'];
    final refundDateRaw = schedule?['refundDate'] ?? json['refundDate'] ?? json['refund_date'];

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
      refundDate: parseOptionalIpoDate(refundDateRaw),
      minPrice: minP,
      maxPrice: maxP > 0 ? maxP : minP,
      lotSize: parsedLot > 0 ? parsedLot : 1,
      issueSizeCrores: (json['issueSizeCrores'] ?? json['issue_size_crores'] ?? json['issue_size'] as num?)?.toDouble(),
      freshIssueCrores: (json['freshIssueCrores'] ?? json['fresh_issue_crores'] ?? json['fresh_issue'] as num?)?.toDouble(),
      ofsCrores: (json['ofsCrores'] ?? json['ofs_crores'] ?? json['ofs'] as num?)?.toDouble(),
      subscription: sub,
      subscriptionOverall: totalSub,
      gmp: _extractGmp(json),
      gmpLastValidAt: _extractGmpLastValidAt(json),
      fetchedAt: _extractFetchedAt(json),
      slug: json['slug'] as String?,
      sourceUpdatedAt: json['source_updated_at'] != null ? DateTime.tryParse(json['source_updated_at'] as String) : null,
      isStale: json['is_stale'] as bool? ?? false,
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
      'refundDate': refundDate?.toIso8601String(),
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'lotSize': lotSize,
      'issueSizeCrores': issueSizeCrores,
      'freshIssueCrores': freshIssueCrores,
      'ofsCrores': ofsCrores,
      'subscription': subscription?.toJson(),
      'subscriptionOverall': subscriptionOverall,
      'gmp': gmp,
      'gmp_last_valid_at': gmpLastValidAt?.toIso8601String(),
      'fetched_at': fetchedAt?.toIso8601String(),
      'issuePrice': issuePrice,
      'listingPrice': listingPrice,
      'currentPrice': currentPrice,
      'lastUpdated': lastUpdated.toIso8601String(),
      'isTracked': isTracked,
      'slug': slug,
      'sourceUpdatedAt': sourceUpdatedAt?.toIso8601String(),
      'isStale': isStale,
    };
  }
}
