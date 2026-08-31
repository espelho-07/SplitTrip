enum IpoFunderType {
  self,
  person;

  static IpoFunderType fromString(String? val) {
    if (val?.toLowerCase() == 'person') return IpoFunderType.person;
    return IpoFunderType.self;
  }
}

class IpoFunding {
  final String id;
  final String applicationId;
  final IpoFunderType funderType;
  final String? personName;
  final String? personUserId;
  final int amountInPaise;
  final String? debtId; // Links to canonical PersonalDebt

  const IpoFunding({
    required this.id,
    required this.applicationId,
    required this.funderType,
    this.personName,
    this.personUserId,
    required this.amountInPaise,
    this.debtId,
  });

  bool get isSelf => funderType == IpoFunderType.self;

  String get displayName => isSelf ? 'Me' : (personName ?? 'Person');

  IpoFunding copyWith({
    String? id,
    String? applicationId,
    IpoFunderType? funderType,
    String? personName,
    String? personUserId,
    int? amountInPaise,
    String? debtId,
  }) {
    return IpoFunding(
      id: id ?? this.id,
      applicationId: applicationId ?? this.applicationId,
      funderType: funderType ?? this.funderType,
      personName: personName ?? this.personName,
      personUserId: personUserId ?? this.personUserId,
      amountInPaise: amountInPaise ?? this.amountInPaise,
      debtId: debtId ?? this.debtId,
    );
  }

  factory IpoFunding.fromJson(Map<String, dynamic> json) {
    return IpoFunding(
      id: json['id'] as String,
      applicationId: json['applicationId'] as String? ?? json['application_id'] as String? ?? '',
      funderType: IpoFunderType.fromString(json['funderType'] as String? ?? json['funder_type'] as String?),
      personName: json['personName'] as String? ?? json['person_name'] as String?,
      personUserId: json['personUserId'] as String? ?? json['person_user_id'] as String?,
      amountInPaise: (json['amountInPaise'] ?? json['amount_in_paise'] as num).toInt(),
      debtId: json['debtId'] as String? ?? json['debt_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'applicationId': applicationId,
      'funderType': funderType.name,
      'personName': personName,
      'personUserId': personUserId,
      'amountInPaise': amountInPaise,
      'debtId': debtId,
    };
  }
}

enum IpoApplicationStatus {
  applied,
  fundsBlocked,
  allotted,
  notAllotted,
  partiallyAllotted,
  refunded,
  listed;

  static IpoApplicationStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'applied':
        return IpoApplicationStatus.applied;
      case 'fundsblocked':
      case 'funds_blocked':
        return IpoApplicationStatus.fundsBlocked;
      case 'allotted':
        return IpoApplicationStatus.allotted;
      case 'notallotted':
      case 'not_allotted':
        return IpoApplicationStatus.notAllotted;
      case 'partiallyallotted':
      case 'partially_allotted':
        return IpoApplicationStatus.partiallyAllotted;
      case 'refunded':
        return IpoApplicationStatus.refunded;
      case 'listed':
        return IpoApplicationStatus.listed;
      default:
        return IpoApplicationStatus.applied;
    }
  }

  String get displayName {
    switch (this) {
      case IpoApplicationStatus.applied:
        return 'Applied';
      case IpoApplicationStatus.fundsBlocked:
        return 'Funds Blocked';
      case IpoApplicationStatus.allotted:
        return 'Allotted';
      case IpoApplicationStatus.notAllotted:
        return 'Not Allotted';
      case IpoApplicationStatus.partiallyAllotted:
        return 'Partially Allotted';
      case IpoApplicationStatus.refunded:
        return 'Refunded / Released';
      case IpoApplicationStatus.listed:
        return 'Listed';
    }
  }
}

class IpoApplication {
  final String id;
  final String ipoId;
  final String ipoName;
  final String userId;
  final DateTime applicationDate;
  final int lotsApplied;
  final int lotSize;
  final int bidPriceInRupees;
  final int applicationAmountInPaise;
  final List<IpoFunding> fundings;
  final IpoApplicationStatus status;
  final int? allottedLots;
  final int? allottedShares;
  final int? actualInvestedAmountInPaise;
  final int? releasedAmountInPaise;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IpoApplication({
    required this.id,
    required this.ipoId,
    required this.ipoName,
    required this.userId,
    required this.applicationDate,
    required this.lotsApplied,
    required this.lotSize,
    required this.bidPriceInRupees,
    required this.applicationAmountInPaise,
    required this.fundings,
    this.status = IpoApplicationStatus.applied,
    this.allottedLots,
    this.allottedShares,
    this.actualInvestedAmountInPaise,
    this.releasedAmountInPaise,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Total shares applied
  int get totalSharesApplied => lotsApplied * lotSize;

  /// Total funding allocated in paise
  int get totalFundingAllocatedPaise {
    return fundings.fold<int>(0, (sum, f) => sum + f.amountInPaise);
  }

  /// True if funding allocation exactly matches the application amount
  bool get isFundingAllocationExact => totalFundingAllocatedPaise == applicationAmountInPaise;

  /// Remaining amount in paise needed to allocate (if positive) or over-allocated (if negative)
  int get fundingDifferencePaise => applicationAmountInPaise - totalFundingAllocatedPaise;

  /// Deterministic calculation helper for application amount
  static int calculateApplicationAmountPaise({
    required int lots,
    required int lotSize,
    required int bidPriceRupees,
  }) {
    return lots * lotSize * bidPriceRupees * 100;
  }

  /// Calculates invested and released amounts upon allotment
  static Map<String, int> calculateAllotmentAmounts({
    required int applicationAmountPaise,
    required int allottedLots,
    required int lotSize,
    required int issuePriceRupees,
  }) {
    if (allottedLots <= 0) {
      return {
        'investedPaise': 0,
        'releasedPaise': applicationAmountPaise,
      };
    }
    final investedPaise = allottedLots * lotSize * issuePriceRupees * 100;
    final releasedPaise = applicationAmountPaise > investedPaise ? applicationAmountPaise - investedPaise : 0;
    return {
      'investedPaise': investedPaise,
      'releasedPaise': releasedPaise,
    };
  }

  IpoApplication copyWith({
    String? id,
    String? ipoId,
    String? ipoName,
    String? userId,
    DateTime? applicationDate,
    int? lotsApplied,
    int? lotSize,
    int? bidPriceInRupees,
    int? applicationAmountInPaise,
    List<IpoFunding>? fundings,
    IpoApplicationStatus? status,
    int? allottedLots,
    int? allottedShares,
    int? actualInvestedAmountInPaise,
    int? releasedAmountInPaise,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return IpoApplication(
      id: id ?? this.id,
      ipoId: ipoId ?? this.ipoId,
      ipoName: ipoName ?? this.ipoName,
      userId: userId ?? this.userId,
      applicationDate: applicationDate ?? this.applicationDate,
      lotsApplied: lotsApplied ?? this.lotsApplied,
      lotSize: lotSize ?? this.lotSize,
      bidPriceInRupees: bidPriceInRupees ?? this.bidPriceInRupees,
      applicationAmountInPaise: applicationAmountInPaise ?? this.applicationAmountInPaise,
      fundings: fundings ?? this.fundings,
      status: status ?? this.status,
      allottedLots: allottedLots ?? this.allottedLots,
      allottedShares: allottedShares ?? this.allottedShares,
      actualInvestedAmountInPaise: actualInvestedAmountInPaise ?? this.actualInvestedAmountInPaise,
      releasedAmountInPaise: releasedAmountInPaise ?? this.releasedAmountInPaise,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory IpoApplication.fromJson(Map<String, dynamic> json) {
    return IpoApplication(
      id: json['id'] as String,
      ipoId: json['ipoId'] as String? ?? json['ipo_id'] as String? ?? '',
      ipoName: json['ipoName'] as String? ?? json['ipo_name'] as String? ?? '',
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      applicationDate: json['applicationDate'] != null
          ? DateTime.parse(json['applicationDate'] as String)
          : DateTime.now(),
      lotsApplied: (json['lotsApplied'] ?? json['lots_applied'] as num?)?.toInt() ?? 1,
      lotSize: (json['lotSize'] ?? json['lot_size'] as num?)?.toInt() ?? 1,
      bidPriceInRupees: (json['bidPriceInRupees'] ?? json['bid_price_in_rupees'] as num?)?.toInt() ?? 0,
      applicationAmountInPaise: (json['applicationAmountInPaise'] ?? json['application_amount_in_paise'] as num).toInt(),
      fundings: (json['fundings'] as List<dynamic>?)
              ?.map((f) => IpoFunding.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
      status: IpoApplicationStatus.fromString(json['status'] as String?),
      allottedLots: (json['allottedLots'] ?? json['allotted_lots'] as num?)?.toInt(),
      allottedShares: (json['allottedShares'] ?? json['allotted_shares'] as num?)?.toInt(),
      actualInvestedAmountInPaise: (json['actualInvestedAmountInPaise'] ?? json['actual_invested_amount_in_paise'] as num?)?.toInt(),
      releasedAmountInPaise: (json['releasedAmountInPaise'] ?? json['released_amount_in_paise'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ipoId': ipoId,
      'ipoName': ipoName,
      'userId': userId,
      'applicationDate': applicationDate.toIso8601String(),
      'lotsApplied': lotsApplied,
      'lotSize': lotSize,
      'bidPriceInRupees': bidPriceInRupees,
      'applicationAmountInPaise': applicationAmountInPaise,
      'fundings': fundings.map((f) => f.toJson()).toList(),
      'status': status.name,
      'allottedLots': allottedLots,
      'allottedShares': allottedShares,
      'actualInvestedAmountInPaise': actualInvestedAmountInPaise,
      'releasedAmountInPaise': releasedAmountInPaise,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
