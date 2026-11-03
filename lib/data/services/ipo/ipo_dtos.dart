/// Data Transfer Objects (DTOs) for incoming IPO feeds.
/// Decouples external API schema variations (e.g. IPO Guru API) from internal domain entities.
class IpoDto {
  final String id;
  final String name;
  final String? companyName;
  final String? symbol;
  final String? marketType;
  final String? status;
  final String? openDate;
  final String? closeDate;
  final String? allotmentDate;
  final String? refundDate;
  final String? listingDate;
  final num? minPrice;
  final num? maxPrice;
  final int? lotSize;
  final num? issueSizeCrores;
  final num? freshIssueCrores;
  final num? ofsCrores;
  final int? gmp;
  final num? gmpUpdatedTime;
  final String? gmpLastValidAt;
  final String? fetchedAt;
  final num? issuePrice;
  final num? listingPrice;
  final num? currentPrice;
  final IpoSubscriptionDto? subscription;
  final Map<String, dynamic> rawAttributes;

  const IpoDto({
    required this.id,
    required this.name,
    this.companyName,
    this.symbol,
    this.marketType,
    this.status,
    this.openDate,
    this.closeDate,
    this.allotmentDate,
    this.refundDate,
    this.listingDate,
    this.minPrice,
    this.maxPrice,
    this.lotSize,
    this.issueSizeCrores,
    this.freshIssueCrores,
    this.ofsCrores,
    this.gmp,
    this.gmpUpdatedTime,
    this.gmpLastValidAt,
    this.fetchedAt,
    this.issuePrice,
    this.listingPrice,
    this.currentPrice,
    this.subscription,
    this.rawAttributes = const {},
  });

  factory IpoDto.fromJson(Map<String, dynamic> json) {
    return IpoDto(
      id: (json['id'] ?? json['ipo_id'] ?? json['symbol'] ?? '').toString(),
      name: (json['name'] ?? json['company_name'] ?? json['title'] ?? '').toString(),
      companyName: json['company_name']?.toString() ?? json['name']?.toString(),
      symbol: json['symbol']?.toString(),
      marketType: json['market_type']?.toString() ?? json['category']?.toString(),
      status: json['status']?.toString(),
      openDate: json['open_date']?.toString() ?? json['startDate']?.toString(),
      closeDate: json['close_date']?.toString() ?? json['endDate']?.toString(),
      allotmentDate: json['allotment_date']?.toString() ?? json['allotmentDate']?.toString(),
      refundDate: json['refund_date']?.toString() ?? json['refundDate']?.toString(),
      listingDate: json['listing_date']?.toString() ?? json['listingDate']?.toString(),
      minPrice: json['min_price'] as num? ?? json['price_band_min'] as num?,
      maxPrice: json['max_price'] as num? ?? json['price_band_max'] as num? ?? json['price'] as num?,
      lotSize: (json['lot_size'] as num? ?? json['lotSize'] as num?)?.toInt(),
      issueSizeCrores: json['issue_size_crores'] as num? ?? json['issueSize'] as num?,
      freshIssueCrores: json['fresh_issue_crores'] as num?,
      ofsCrores: json['ofs_crores'] as num?,
      gmp: (json['gmp'] as num?)?.toInt(),
      gmpUpdatedTime: json['gmp_updated_time'] as num?,
      gmpLastValidAt: json['gmp_last_valid_at']?.toString() ?? json['gmpLastValidAt']?.toString(),
      fetchedAt: json['fetched_at']?.toString() ?? json['fetchedAt']?.toString(),
      issuePrice: json['issue_price'] as num?,
      listingPrice: json['listing_price'] as num?,
      currentPrice: json['current_price'] as num?,
      subscription: json['subscription'] is Map<String, dynamic>
          ? IpoSubscriptionDto.fromJson(json['subscription'] as Map<String, dynamic>)
          : null,
      rawAttributes: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'company_name': companyName,
      'symbol': symbol,
      'market_type': marketType,
      'status': status,
      'open_date': openDate,
      'close_date': closeDate,
      'allotment_date': allotmentDate,
      'refund_date': refundDate,
      'listing_date': listingDate,
      'min_price': minPrice,
      'max_price': maxPrice,
      'lot_size': lotSize,
      'issue_size_crores': issueSizeCrores,
      'fresh_issue_crores': freshIssueCrores,
      'ofs_crores': ofsCrores,
      'gmp': gmp,
      'gmp_updated_time': gmpUpdatedTime,
      'gmp_last_valid_at': gmpLastValidAt,
      'fetched_at': fetchedAt,
      'issue_price': issuePrice,
      'listing_price': listingPrice,
    };
  }
}

class IpoSubscriptionDto {
  final double? qib;
  final double? nii;
  final double? retail;
  final double? employee;
  final double? shareholder;
  final double? total;

  const IpoSubscriptionDto({
    this.qib,
    this.nii,
    this.retail,
    this.employee,
    this.shareholder,
    this.total,
  });

  factory IpoSubscriptionDto.fromJson(Map<String, dynamic> json) {
    return IpoSubscriptionDto(
      qib: (json['qib'] as num?)?.toDouble() ?? (json['qib_x'] as num?)?.toDouble(),
      nii: (json['nii'] as num?)?.toDouble() ?? (json['nii_x'] as num?)?.toDouble(),
      retail: (json['retail'] as num?)?.toDouble() ?? (json['retail_x'] as num?)?.toDouble(),
      employee: (json['employee'] as num?)?.toDouble() ?? (json['emp_x'] as num?)?.toDouble(),
      shareholder: (json['shareholder'] as num?)?.toDouble() ?? (json['sh_x'] as num?)?.toDouble(),
      total: (json['total'] as num?)?.toDouble() ?? (json['total_x'] as num?)?.toDouble(),
    );
  }
}

class IpoGmpHistoryDto {
  final DateTime date;
  final int gmpValue;
  final int? estimatedListingPrice;
  final double? estimatedGainPercentage;

  const IpoGmpHistoryDto({
    required this.date,
    required this.gmpValue,
    this.estimatedListingPrice,
    this.estimatedGainPercentage,
  });

  factory IpoGmpHistoryDto.fromJson(Map<String, dynamic> json) {
    return IpoGmpHistoryDto(
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : DateTime.now(),
      gmpValue: (json['gmp'] as num? ?? 0).toInt(),
      estimatedListingPrice: (json['estimated_listing_price'] as num?)?.toInt(),
      estimatedGainPercentage: (json['estimated_gain_percentage'] as num?)?.toDouble(),
    );
  }
}
