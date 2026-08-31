enum PersonLedgerType {
  lent,
  borrowed,
  repaymentReceived,
  repaymentPaid,
  tripSplitOwedToYou, // You paid, this person owes you
  tripSplitYouOwe,    // This person paid, you owe them
  tripSettlementPaid, // You paid this person on a trip
  tripSettlementReceived, // This person paid you on a trip
}

class PersonLedgerItem {
  final String id;
  final String personName;
  final String? personUserId;
  final String? personMemberId;
  final PersonLedgerType type;
  final int amountInPaise;
  final DateTime date;
  final String title;
  final String? note;
  final String? tripId;
  final String? tripName;
  final String? ipoId;
  final String? ipoName;
  final String? ipoApplicationId;
  final bool isSettled;
  final String? referenceId;

  const PersonLedgerItem({
    required this.id,
    required this.personName,
    this.personUserId,
    this.personMemberId,
    required this.type,
    required this.amountInPaise,
    required this.date,
    required this.title,
    this.note,
    this.tripId,
    this.tripName,
    this.ipoId,
    this.ipoName,
    this.ipoApplicationId,
    this.isSettled = false,
    this.referenceId,
  });

  bool get isIpoFunding => ipoId != null || (title.toLowerCase().contains('ipo') || (note?.toLowerCase().contains('ipo') ?? false));

  /// True if this transaction represents money going out from you / owed to you
  bool get isCreditToUser {
    switch (type) {
      case PersonLedgerType.lent:
      case PersonLedgerType.tripSplitOwedToYou:
      case PersonLedgerType.tripSettlementPaid:
      case PersonLedgerType.repaymentPaid:
        return true;
      case PersonLedgerType.borrowed:
      case PersonLedgerType.tripSplitYouOwe:
      case PersonLedgerType.tripSettlementReceived:
      case PersonLedgerType.repaymentReceived:
        return false;
    }
  }

  String get directionLabel {
    switch (type) {
      case PersonLedgerType.lent:
        return 'You lent';
      case PersonLedgerType.borrowed:
        return 'You borrowed';
      case PersonLedgerType.repaymentReceived:
        return 'Repayment received';
      case PersonLedgerType.repaymentPaid:
        return 'You paid back';
      case PersonLedgerType.tripSplitOwedToYou:
        return 'You paid for them';
      case PersonLedgerType.tripSplitYouOwe:
        return 'They paid for you';
      case PersonLedgerType.tripSettlementPaid:
        return 'Settlement sent';
      case PersonLedgerType.tripSettlementReceived:
        return 'Settlement received';
    }
  }
}
