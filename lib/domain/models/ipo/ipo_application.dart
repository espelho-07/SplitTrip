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
  draft,
  planned,
  submitted,
  applied, // Backward-compat alias for submitted
  mandatePending,
  mandateApproved,
  mandateFailed,
  fundsBlocked, // Backward-compat alias for mandateApproved
  allotted,
  partiallyAllotted,
  notAllotted,
  refundPending,
  refundInitiated,
  refundCredited,
  refunded, // Backward-compat alias for refundCredited
  rejected,
  cancelled,
  listed;

  static IpoApplicationStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'draft':
        return IpoApplicationStatus.draft;
      case 'planned':
        return IpoApplicationStatus.planned;
      case 'submitted':
        return IpoApplicationStatus.submitted;
      case 'applied':
        return IpoApplicationStatus.applied;
      case 'mandatepending':
      case 'mandate_pending':
        return IpoApplicationStatus.mandatePending;
      case 'mandateapproved':
      case 'mandate_approved':
        return IpoApplicationStatus.mandateApproved;
      case 'mandatefailed':
      case 'mandate_failed':
        return IpoApplicationStatus.mandateFailed;
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
      case 'refundpending':
      case 'refund_pending':
        return IpoApplicationStatus.refundPending;
      case 'refundinitiated':
      case 'refund_initiated':
        return IpoApplicationStatus.refundInitiated;
      case 'refundcredited':
      case 'refund_credited':
        return IpoApplicationStatus.refundCredited;
      case 'refunded':
        return IpoApplicationStatus.refunded;
      case 'rejected':
        return IpoApplicationStatus.rejected;
      case 'cancelled':
      case 'canceled':
        return IpoApplicationStatus.cancelled;
      case 'listed':
        return IpoApplicationStatus.listed;
      default:
        return IpoApplicationStatus.applied;
    }
  }

  String get displayName {
    switch (this) {
      case IpoApplicationStatus.draft:
        return 'Draft';
      case IpoApplicationStatus.planned:
        return 'Planned';
      case IpoApplicationStatus.submitted:
      case IpoApplicationStatus.applied:
        return 'Submitted';
      case IpoApplicationStatus.mandatePending:
        return 'Mandate Pending';
      case IpoApplicationStatus.mandateApproved:
      case IpoApplicationStatus.fundsBlocked:
        return 'Mandate Approved (Blocked)';
      case IpoApplicationStatus.mandateFailed:
        return 'Mandate Failed';
      case IpoApplicationStatus.allotted:
        return 'Allotted';
      case IpoApplicationStatus.notAllotted:
        return 'Not Allotted';
      case IpoApplicationStatus.partiallyAllotted:
        return 'Partially Allotted';
      case IpoApplicationStatus.refundPending:
        return 'Refund Pending';
      case IpoApplicationStatus.refundInitiated:
        return 'Refund Initiated';
      case IpoApplicationStatus.refundCredited:
      case IpoApplicationStatus.refunded:
        return 'Refund Credited / Released';
      case IpoApplicationStatus.rejected:
        return 'Rejected';
      case IpoApplicationStatus.cancelled:
        return 'Cancelled';
      case IpoApplicationStatus.listed:
        return 'Listed';
    }
  }

  bool get isCompleted =>
      this == IpoApplicationStatus.allotted ||
      this == IpoApplicationStatus.notAllotted ||
      this == IpoApplicationStatus.refundCredited ||
      this == IpoApplicationStatus.refunded ||
      this == IpoApplicationStatus.rejected ||
      this == IpoApplicationStatus.cancelled ||
      this == IpoApplicationStatus.listed;
}

enum IpoMonitoringStatus {
  notMonitored,
  monitoring,
  checking,
  resultFound,
  retrying,
  failed,
  stopped;

  static IpoMonitoringStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'notmonitored':
      case 'not_monitored':
        return IpoMonitoringStatus.notMonitored;
      case 'monitoring':
        return IpoMonitoringStatus.monitoring;
      case 'checking':
        return IpoMonitoringStatus.checking;
      case 'resultfound':
      case 'result_found':
        return IpoMonitoringStatus.resultFound;
      case 'retrying':
        return IpoMonitoringStatus.retrying;
      case 'failed':
        return IpoMonitoringStatus.failed;
      case 'stopped':
        return IpoMonitoringStatus.stopped;
      default:
        return IpoMonitoringStatus.monitoring;
    }
  }

  String get displayName {
    switch (this) {
      case IpoMonitoringStatus.notMonitored:
        return 'Not Monitored';
      case IpoMonitoringStatus.monitoring:
        return 'Checking automatically';
      case IpoMonitoringStatus.checking:
        return 'Checking allotment…';
      case IpoMonitoringStatus.resultFound:
        return 'Allotment confirmed';
      case IpoMonitoringStatus.retrying:
        return "We'll check again automatically";
      case IpoMonitoringStatus.failed:
        return 'Verification required';
      case IpoMonitoringStatus.stopped:
        return 'Monitoring stopped';
    }
  }
}

class IpoAuditEntry {
  final String id;
  final DateTime timestamp;
  final String title;
  final String description;

  const IpoAuditEntry({
    required this.id,
    required this.timestamp,
    required this.title,
    required this.description,
  });

  factory IpoAuditEntry.fromJson(Map<String, dynamic> json) {
    return IpoAuditEntry(
      id: json['id'] as String? ?? 'audit_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp'] as String) : DateTime.now(),
      title: json['title'] as String? ?? 'Event',
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'title': title,
      'description': description,
    };
  }
}

class IpoApplication {
  final String id;
  final String ipoId;
  final String ipoName;
  final String userId;
  final String? applicationAccountId;
  final String? accountDisplayName;
  final String? accountMaskedPan;
  final String? applicationNumber;
  final String? registrar;
  final DateTime applicationDate;
  final int lotsApplied;
  final int lotSize;
  final int bidPriceInRupees;
  final int applicationAmountInPaise;
  final int? paidAmountInPaise;
  final int? remainingAmountInPaise;
  final List<IpoFunding> fundings;
  final IpoApplicationStatus status;
  final String? upiMandateStatus; // 'pending', 'approved', 'failed'
  final String? bidPriceType; // 'cutoff', 'upper', 'lower', 'custom'
  final int? mandateAmountInPaise;
  final int? actualSubmittedAmountInPaise;
  final int? refundInitiatedAmountInPaise;
  final DateTime? refundInitiatedDate;
  final DateTime? refundCreditedDate;
  final IpoMonitoringStatus monitoringStatus;
  final int? allottedLots;
  final int? allottedShares;
  final int? actualInvestedAmountInPaise;
  final int? releasedAmountInPaise;
  final DateTime? lastCheckedAt;
  final DateTime? nextCheckAt;
  final int checkCount;
  final String? lastCheckMessage;
  final List<IpoAuditEntry> auditTrail;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IpoApplication({
    required this.id,
    required this.ipoId,
    required this.ipoName,
    required this.userId,
    this.applicationAccountId,
    this.accountDisplayName,
    this.accountMaskedPan,
    this.applicationNumber,
    this.registrar,
    required this.applicationDate,
    required this.lotsApplied,
    required this.lotSize,
    required this.bidPriceInRupees,
    required this.applicationAmountInPaise,
    this.paidAmountInPaise,
    this.remainingAmountInPaise,
    required this.fundings,
    this.status = IpoApplicationStatus.applied,
    this.upiMandateStatus,
    this.bidPriceType,
    this.mandateAmountInPaise,
    this.actualSubmittedAmountInPaise,
    this.refundInitiatedAmountInPaise,
    this.refundInitiatedDate,
    this.refundCreditedDate,
    this.monitoringStatus = IpoMonitoringStatus.monitoring,
    this.allottedLots,
    this.allottedShares,
    this.actualInvestedAmountInPaise,
    this.releasedAmountInPaise,
    this.lastCheckedAt,
    this.nextCheckAt,
    this.checkCount = 0,
    this.lastCheckMessage,
    this.auditTrail = const [],
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Account name to display
  String get accountName => accountDisplayName ?? 'Me';

  /// Masked application number for safe UI display
  String get maskedApplicationNumber {
    if (applicationNumber == null || applicationNumber!.isEmpty) return '';
    if (applicationNumber!.length <= 4) return applicationNumber!;
    return '••••${applicationNumber!.substring(applicationNumber!.length - 4)}';
  }

  /// Total shares applied
  int get totalSharesApplied => lotsApplied * lotSize;

  /// Whether funds are currently blocked via active approved mandate
  bool get isFundsBlocked =>
      status == IpoApplicationStatus.fundsBlocked ||
      status == IpoApplicationStatus.mandateApproved ||
      (status == IpoApplicationStatus.applied && (upiMandateStatus == 'approved' || upiMandateStatus == null));

  /// Amount currently blocked in bank account via mandate
  int get currentBlockedAmountInPaise {
    if (!isFundsBlocked) return 0;
    if (status.isCompleted) return 0;
    return mandateAmountInPaise ?? actualSubmittedAmountInPaise ?? applicationAmountInPaise;
  }

  /// Expected refundable amount based on allotment outcome
  int get expectedRefundInPaise {
    if (status == IpoApplicationStatus.notAllotted || status == IpoApplicationStatus.rejected) {
      return actualSubmittedAmountInPaise ?? applicationAmountInPaise;
    }
    if (status == IpoApplicationStatus.partiallyAllotted) {
      final total = actualSubmittedAmountInPaise ?? applicationAmountInPaise;
      final invested = actualInvestedAmountInPaise ?? 0;
      return (total - invested).clamp(0, total);
    }
    if (status == IpoApplicationStatus.allotted) {
      return 0;
    }
    return 0;
  }

  /// Outstanding refund: Expected refund minus already confirmed/credited refund
  int get outstandingRefundInPaise {
    final expected = expectedRefundInPaise;
    final credited = releasedAmountInPaise ?? 0;
    return (expected - credited).clamp(0, expected);
  }

  /// True if shares have been allotted either fully or partially
  bool get isAllotted => status == IpoApplicationStatus.allotted || status == IpoApplicationStatus.partiallyAllotted;

  /// True if application has reached its terminal settlement status
  bool get isTerminalState =>
      status == IpoApplicationStatus.allotted ||
      status == IpoApplicationStatus.notAllotted ||
      status == IpoApplicationStatus.refundCredited ||
      status == IpoApplicationStatus.rejected ||
      status == IpoApplicationStatus.cancelled;

  /// Alias for actual invested / allotted amount in paise
  int get actualAllottedAmountInPaise => actualInvestedAmountInPaise ?? (isAllotted ? (mandateAmountInPaise ?? applicationAmountInPaise) : 0);

  /// Alias for confirmed refund / released amount in paise
  int get refundCreditedAmountInPaise => releasedAmountInPaise ?? 0;

  /// Total funding allocated in paise
  int get totalFundingAllocatedPaise {
    return fundings.fold<int>(0, (sum, f) => sum + f.amountInPaise);
  }

  /// True if funding allocation exactly matches the application amount
  bool get isFundingAllocationExact => totalFundingAllocatedPaise == applicationAmountInPaise;

  /// Remaining amount in paise needed to allocate (if positive) or over-allocated (if negative)
  int get fundingDifferencePaise => applicationAmountInPaise - totalFundingAllocatedPaise;

  /// Effective amount paid for this IPO
  int get effectivePaidPaise => paidAmountInPaise ?? totalFundingAllocatedPaise;

  /// Effective remaining amount required for this IPO
  int get effectiveRemainingPaise => (remainingAmountInPaise ?? (applicationAmountInPaise - effectivePaidPaise)).clamp(0, applicationAmountInPaise);

  /// Deterministic calculation helper for application amount
  static int calculateApplicationAmountPaise({
    required int lots,
    required int lotSize,
    required int bidPriceRupees,
  }) {
    return lots * lotSize * bidPriceRupees * 100;
  }

  /// Calculates additional amount required given available unutilized balance
  static int calculateAdditionalRequiredPaise({
    required int applicationAmountPaise,
    required int availableReleasedBalancePaise,
  }) {
    if (availableReleasedBalancePaise >= applicationAmountPaise) return 0;
    return applicationAmountPaise - availableReleasedBalancePaise;
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
    String? applicationAccountId,
    String? accountDisplayName,
    String? accountMaskedPan,
    String? applicationNumber,
    String? registrar,
    DateTime? applicationDate,
    int? lotsApplied,
    int? lotSize,
    int? bidPriceInRupees,
    int? applicationAmountInPaise,
    int? paidAmountInPaise,
    int? remainingAmountInPaise,
    List<IpoFunding>? fundings,
    IpoApplicationStatus? status,
    String? upiMandateStatus,
    String? bidPriceType,
    int? mandateAmountInPaise,
    int? actualSubmittedAmountInPaise,
    int? refundInitiatedAmountInPaise,
    DateTime? refundInitiatedDate,
    DateTime? refundCreditedDate,
    IpoMonitoringStatus? monitoringStatus,
    int? allottedLots,
    int? allottedShares,
    int? actualInvestedAmountInPaise,
    int? releasedAmountInPaise,
    int? refundCreditedAmountInPaise,
    DateTime? lastCheckedAt,
    DateTime? nextCheckAt,
    int? checkCount,
    String? lastCheckMessage,
    List<IpoAuditEntry>? auditTrail,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return IpoApplication(
      id: id ?? this.id,
      ipoId: ipoId ?? this.ipoId,
      ipoName: ipoName ?? this.ipoName,
      userId: userId ?? this.userId,
      applicationAccountId: applicationAccountId ?? this.applicationAccountId,
      accountDisplayName: accountDisplayName ?? this.accountDisplayName,
      accountMaskedPan: accountMaskedPan ?? this.accountMaskedPan,
      applicationNumber: applicationNumber ?? this.applicationNumber,
      registrar: registrar ?? this.registrar,
      applicationDate: applicationDate ?? this.applicationDate,
      lotsApplied: lotsApplied ?? this.lotsApplied,
      lotSize: lotSize ?? this.lotSize,
      bidPriceInRupees: bidPriceInRupees ?? this.bidPriceInRupees,
      applicationAmountInPaise: applicationAmountInPaise ?? this.applicationAmountInPaise,
      paidAmountInPaise: paidAmountInPaise ?? this.paidAmountInPaise,
      remainingAmountInPaise: remainingAmountInPaise ?? this.remainingAmountInPaise,
      fundings: fundings ?? this.fundings,
      status: status ?? this.status,
      upiMandateStatus: upiMandateStatus ?? this.upiMandateStatus,
      bidPriceType: bidPriceType ?? this.bidPriceType,
      mandateAmountInPaise: mandateAmountInPaise ?? this.mandateAmountInPaise,
      actualSubmittedAmountInPaise: actualSubmittedAmountInPaise ?? this.actualSubmittedAmountInPaise,
      refundInitiatedAmountInPaise: refundInitiatedAmountInPaise ?? this.refundInitiatedAmountInPaise,
      refundInitiatedDate: refundInitiatedDate ?? this.refundInitiatedDate,
      refundCreditedDate: refundCreditedDate ?? this.refundCreditedDate,
      monitoringStatus: monitoringStatus ?? this.monitoringStatus,
      allottedLots: allottedLots ?? this.allottedLots,
      allottedShares: allottedShares ?? this.allottedShares,
      actualInvestedAmountInPaise: actualInvestedAmountInPaise ?? this.actualInvestedAmountInPaise,
      releasedAmountInPaise: refundCreditedAmountInPaise ?? releasedAmountInPaise ?? this.releasedAmountInPaise,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      nextCheckAt: nextCheckAt ?? this.nextCheckAt,
      checkCount: checkCount ?? this.checkCount,
      lastCheckMessage: lastCheckMessage ?? this.lastCheckMessage,
      auditTrail: auditTrail ?? this.auditTrail,
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
      applicationAccountId: json['applicationAccountId'] as String? ?? json['application_account_id'] as String?,
      accountDisplayName: json['accountDisplayName'] as String? ?? json['account_display_name'] as String?,
      accountMaskedPan: json['accountMaskedPan'] as String? ?? json['account_masked_pan'] as String?,
      applicationNumber: json['applicationNumber'] as String? ?? json['application_number'] as String?,
      registrar: json['registrar'] as String?,
      applicationDate: json['applicationDate'] != null
          ? DateTime.parse(json['applicationDate'] as String)
          : DateTime.now(),
      lotsApplied: (json['lotsApplied'] ?? json['lots_applied'] as num?)?.toInt() ?? 1,
      lotSize: (json['lotSize'] ?? json['lot_size'] as num?)?.toInt() ?? 1,
      bidPriceInRupees: (json['bidPriceInRupees'] ?? json['bid_price_in_rupees'] as num?)?.toInt() ?? 0,
      applicationAmountInPaise: (json['applicationAmountInPaise'] ?? json['application_amount_in_paise'] as num).toInt(),
      paidAmountInPaise: (json['paidAmountInPaise'] ?? json['paid_amount_in_paise'] as num?)?.toInt(),
      remainingAmountInPaise: (json['remainingAmountInPaise'] ?? json['remaining_amount_in_paise'] as num?)?.toInt(),
      fundings: (json['fundings'] as List<dynamic>?)
              ?.map((f) => IpoFunding.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
      status: IpoApplicationStatus.fromString(json['status'] as String?),
      monitoringStatus: IpoMonitoringStatus.fromString(json['monitoringStatus'] as String? ?? json['monitoring_status'] as String?),
      allottedLots: (json['allottedLots'] ?? json['allotted_lots'] as num?)?.toInt(),
      allottedShares: (json['allottedShares'] ?? json['allotted_shares'] as num?)?.toInt(),
      actualInvestedAmountInPaise: (json['actualInvestedAmountInPaise'] ?? json['actual_invested_amount_in_paise'] as num?)?.toInt(),
      releasedAmountInPaise: (json['releasedAmountInPaise'] ?? json['released_amount_in_paise'] as num?)?.toInt(),
      lastCheckedAt: json['lastCheckedAt'] != null
          ? DateTime.parse(json['lastCheckedAt'] as String)
          : (json['last_checked_at'] != null ? DateTime.parse(json['last_checked_at'] as String) : null),
      nextCheckAt: json['nextCheckAt'] != null
          ? DateTime.parse(json['nextCheckAt'] as String)
          : (json['next_check_at'] != null ? DateTime.parse(json['next_check_at'] as String) : null),
      checkCount: (json['checkCount'] ?? json['check_count'] as num?)?.toInt() ?? 0,
      lastCheckMessage: json['lastCheckMessage'] as String? ?? json['last_check_message'] as String?,
      auditTrail: (json['auditTrail'] as List<dynamic>?)
              ?.map((a) => IpoAuditEntry.fromJson(a as Map<String, dynamic>))
              .toList() ??
          (json['audit_trail'] as List<dynamic>?)
              ?.map((a) => IpoAuditEntry.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
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
      if (applicationAccountId != null) 'applicationAccountId': applicationAccountId,
      if (accountDisplayName != null) 'accountDisplayName': accountDisplayName,
      if (accountMaskedPan != null) 'accountMaskedPan': accountMaskedPan,
      if (applicationNumber != null) 'applicationNumber': applicationNumber,
      if (registrar != null) 'registrar': registrar,
      'applicationDate': applicationDate.toIso8601String(),
      'lotsApplied': lotsApplied,
      'lotSize': lotSize,
      'bidPriceInRupees': bidPriceInRupees,
      'applicationAmountInPaise': applicationAmountInPaise,
      if (paidAmountInPaise != null) 'paidAmountInPaise': paidAmountInPaise,
      if (remainingAmountInPaise != null) 'remainingAmountInPaise': remainingAmountInPaise,
      'fundings': fundings.map((f) => f.toJson()).toList(),
      'status': status.name,
      if (upiMandateStatus != null) 'upiMandateStatus': upiMandateStatus,
      if (bidPriceType != null) 'bidPriceType': bidPriceType,
      if (mandateAmountInPaise != null) 'mandateAmountInPaise': mandateAmountInPaise,
      if (actualSubmittedAmountInPaise != null) 'actualSubmittedAmountInPaise': actualSubmittedAmountInPaise,
      if (refundInitiatedAmountInPaise != null) 'refundInitiatedAmountInPaise': refundInitiatedAmountInPaise,
      if (refundInitiatedDate != null) 'refundInitiatedDate': refundInitiatedDate!.toIso8601String(),
      if (refundCreditedDate != null) 'refundCreditedDate': refundCreditedDate!.toIso8601String(),
      'monitoringStatus': monitoringStatus.name,
      'allottedLots': allottedLots,
      'allottedShares': allottedShares,
      'actualInvestedAmountInPaise': actualInvestedAmountInPaise,
      'releasedAmountInPaise': releasedAmountInPaise,
      if (lastCheckedAt != null) 'lastCheckedAt': lastCheckedAt!.toIso8601String(),
      if (nextCheckAt != null) 'nextCheckAt': nextCheckAt!.toIso8601String(),
      'checkCount': checkCount,
      if (lastCheckMessage != null) 'lastCheckMessage': lastCheckMessage,
      'auditTrail': auditTrail.map((a) => a.toJson()).toList(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

