import 'package:uuid/uuid.dart';

/// Reusable account for IPO applications (e.g. Me, Brother, Friend, Family).
/// Securely masks PAN to protect sensitive financial identity data.
class IpoAccount {
  final String id;
  final String displayName;
  final String maskedPan;
  final String? accountHolderName;
  final String? upiId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IpoAccount({
    required this.id,
    required this.displayName,
    required this.maskedPan,
    this.accountHolderName,
    this.upiId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isSelf => id == 'me' || displayName.toLowerCase() == 'me';

  static String maskPan(String rawPan) {
    final clean = rawPan.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (clean.length == 10) {
      return 'XXXXX${clean.substring(5)}';
    } else if (clean.length > 4) {
      final hiddenLen = clean.length - 4;
      return '${'X' * hiddenLen}${clean.substring(hiddenLen)}';
    }
    return clean;
  }

  factory IpoAccount.create({
    required String displayName,
    String? rawPan,
    String? accountHolderName,
    String? upiId,
  }) {
    final now = DateTime.now();
    final id = 'ipoacc_${const Uuid().v4().replaceAll('-', '').substring(0, 12)}';
    return IpoAccount(
      id: id,
      displayName: displayName.trim(),
      maskedPan: rawPan != null && rawPan.isNotEmpty ? maskPan(rawPan) : '',
      accountHolderName: accountHolderName?.trim(),
      upiId: upiId?.trim(),
      createdAt: now,
      updatedAt: now,
    );
  }

  factory IpoAccount.self() {
    final now = DateTime.now();
    return IpoAccount(
      id: 'me',
      displayName: 'Me (Primary)',
      maskedPan: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  factory IpoAccount.fromJson(Map<String, dynamic> json) {
    return IpoAccount(
      id: json['id'] as String? ?? 'me',
      displayName: json['displayName'] as String? ?? json['display_name'] as String? ?? 'Me',
      maskedPan: json['maskedPan'] as String? ?? json['masked_pan'] as String? ?? '',
      accountHolderName: json['accountHolderName'] as String? ?? json['account_holder_name'] as String?,
      upiId: json['upiId'] as String? ?? json['upi_id'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'maskedPan': maskedPan,
      if (accountHolderName != null) 'accountHolderName': accountHolderName,
      if (upiId != null) 'upiId': upiId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  IpoAccount copyWith({
    String? id,
    String? displayName,
    String? maskedPan,
    String? accountHolderName,
    String? upiId,
    DateTime? updatedAt,
  }) {
    return IpoAccount(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      maskedPan: maskedPan ?? this.maskedPan,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      upiId: upiId ?? this.upiId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
