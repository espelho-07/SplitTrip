enum IpoMarketType {
  mainboard,
  sme;

  static IpoMarketType fromString(String? val) {
    if (val?.toLowerCase() == 'sme') return IpoMarketType.sme;
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
      case 'open':
        return IpoStatus.open;
      case 'upcoming':
        return IpoStatus.upcoming;
      case 'closed':
        return IpoStatus.closed;
      case 'allotmentout':
      case 'allotment_out':
      case 'allotment':
        return IpoStatus.allotmentOut;
      case 'listed':
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
    this.subscriptionOverall,
    this.gmp,
    this.issuePrice,
    this.listingPrice,
    this.currentPrice,
    required this.lastUpdated,
    this.isTracked = false,
  });

  /// Minimum investment in Rupees for 1 lot at cutoff (max price)
  int get minInvestmentRupees => lotSize * maxPrice;

  /// Price band formatted string e.g. "₹450 – ₹475" or "₹475"
  String get priceBandFormatted {
    if (minPrice == maxPrice || minPrice <= 0) {
      return '₹$maxPrice';
    }
    return '₹$minPrice – ₹$maxPrice';
  }

  /// True if bidding is active today
  bool get isBiddingActive {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final open = DateTime(openDate.year, openDate.month, openDate.day);
    final close = DateTime(closeDate.year, closeDate.month, closeDate.day, 23, 59, 59);
    return !today.isBefore(open) && !now.isAfter(close);
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
    return Ipo(
      id: json['id'] as String,
      name: json['name'] as String,
      companyName: json['companyName'] as String? ?? json['name'] as String,
      symbol: json['symbol'] as String? ?? '',
      marketType: IpoMarketType.fromString(json['marketType'] as String?),
      status: IpoStatus.fromString(json['status'] as String?),
      openDate: json['openDate'] != null ? DateTime.parse(json['openDate'] as String) : DateTime.now(),
      closeDate: json['closeDate'] != null ? DateTime.parse(json['closeDate'] as String) : DateTime.now(),
      allotmentDate: json['allotmentDate'] != null ? DateTime.tryParse(json['allotmentDate'] as String) : null,
      listingDate: json['listingDate'] != null ? DateTime.tryParse(json['listingDate'] as String) : null,
      minPrice: (json['minPrice'] as num?)?.toInt() ?? 0,
      maxPrice: (json['maxPrice'] as num?)?.toInt() ?? 0,
      lotSize: (json['lotSize'] as num?)?.toInt() ?? 1,
      issueSizeCrores: (json['issueSizeCrores'] as num?)?.toDouble(),
      freshIssueCrores: (json['freshIssueCrores'] as num?)?.toDouble(),
      ofsCrores: (json['ofsCrores'] as num?)?.toDouble(),
      subscriptionOverall: (json['subscriptionOverall'] as num?)?.toDouble(),
      gmp: (json['gmp'] as num?)?.toInt(),
      issuePrice: (json['issuePrice'] as num?)?.toInt(),
      listingPrice: (json['listingPrice'] as num?)?.toInt(),
      currentPrice: (json['currentPrice'] as num?)?.toInt(),
      lastUpdated: json['lastUpdated'] != null ? DateTime.parse(json['lastUpdated'] as String) : DateTime.now(),
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
