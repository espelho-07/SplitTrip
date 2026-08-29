/// Represents a semantic version number (MAJOR.MINOR.PATCH[+BUILD]).
class SemanticVersion implements Comparable<SemanticVersion> {
  final int major;
  final int minor;
  final int patch;
  final int? buildNumber;
  final String raw;

  const SemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.buildNumber,
    required this.raw,
  });

  /// Safely parses a version string (e.g., "2.4.1", "v2.1.0+4", "1.0.0+1").
  static SemanticVersion parse(String versionStr) {
    final parsed = tryParse(versionStr);
    if (parsed != null) return parsed;
    return const SemanticVersion(major: 0, minor: 0, patch: 0, raw: '0.0.0');
  }

  /// Attempts to parse a semantic version string.
  static SemanticVersion? tryParse(String? versionStr) {
    if (versionStr == null || versionStr.trim().isEmpty) return null;

    final trimmed = versionStr.trim();
    var clean = trimmed.replaceAll(RegExp(r'^[vV]'), '');

    int? buildNum;
    final buildIdx = clean.indexOf('+');
    if (buildIdx != -1) {
      final buildStr = clean.substring(buildIdx + 1);
      buildNum = int.tryParse(buildStr);
      clean = clean.substring(0, buildIdx);
    }

    final preIdx = clean.indexOf('-');
    if (preIdx != -1) {
      clean = clean.substring(0, preIdx);
    }

    final parts = clean.split('.');
    if (parts.isEmpty) return null;

    final major = int.tryParse(parts[0]) ?? 0;
    final minor = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final patch = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;

    return SemanticVersion(
      major: major,
      minor: minor,
      patch: patch,
      buildNumber: buildNum,
      raw: trimmed,
    );
  }

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) {
      return major.compareTo(other.major);
    }
    if (minor != other.minor) {
      return minor.compareTo(other.minor);
    }
    if (patch != other.patch) {
      return patch.compareTo(other.patch);
    }
    return 0;
  }

  bool operator <(SemanticVersion other) => compareTo(other) < 0;
  bool operator <=(SemanticVersion other) => compareTo(other) <= 0;
  bool operator >(SemanticVersion other) => compareTo(other) > 0;
  bool operator >=(SemanticVersion other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SemanticVersion &&
        other.major == major &&
        other.minor == minor &&
        other.patch == patch;
  }

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch${buildNumber != null ? '+$buildNumber' : ''}';
}

/// Categorization of update urgency.
enum UpdateType {
  /// App is up to date or newer than server latest.
  none,

  /// App is between minimum supported and latest version. User can continue or update optionally.
  optional,

  /// App is below minimum supported version. Update is required to prevent data incompatibility.
  required,
}

/// Server-controlled application version configuration.
class AppVersionConfig {
  final SemanticVersion latestVersion;
  final SemanticVersion minimumSupportedVersion;
  final String releaseNotes;
  final String storeUrl;
  final String updatePriority;
  final Map<String, dynamic> featureFlags;
  final DateTime? publishedAt;

  const AppVersionConfig({
    required this.latestVersion,
    required this.minimumSupportedVersion,
    required this.releaseNotes,
    required this.storeUrl,
    this.updatePriority = 'flexible',
    this.featureFlags = const {},
    this.publishedAt,
  });

  factory AppVersionConfig.fromJson(Map<String, dynamic> json) {
    return AppVersionConfig(
      latestVersion: SemanticVersion.parse(json['latestVersion'] as String? ?? '1.0.0'),
      minimumSupportedVersion: SemanticVersion.parse(json['minimumSupportedVersion'] as String? ?? '1.0.0'),
      releaseNotes: json['releaseNotes'] as String? ?? '• Performance enhancements and stability fixes',
      storeUrl: json['storeUrl'] as String? ?? 'https://play.google.com/store/apps/details?id=com.nirniq.kith',
      updatePriority: json['updatePriority'] as String? ?? 'flexible',
      featureFlags: json['featureFlags'] is Map<String, dynamic>
          ? json['featureFlags'] as Map<String, dynamic>
          : {},
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'latestVersion': latestVersion.toString(),
    'minimumSupportedVersion': minimumSupportedVersion.toString(),
    'releaseNotes': releaseNotes,
    'storeUrl': storeUrl,
    'updatePriority': updatePriority,
    'featureFlags': featureFlags,
    'publishedAt': publishedAt?.toIso8601String(),
  };

  /// Fallback configuration used when device is completely offline and no cached config exists.
  static const AppVersionConfig fallback = AppVersionConfig(
    latestVersion: SemanticVersion(major: 1, minor: 0, patch: 0, raw: '1.0.0'),
    minimumSupportedVersion: SemanticVersion(major: 1, minor: 0, patch: 0, raw: '1.0.0'),
    releaseNotes: '• Performance and security updates',
    storeUrl: 'https://play.google.com/store/apps/details?id=com.nirniq.kith',
  );
}

/// Evaluated result of a version check against the server configuration.
class AppVersionCheckResult {
  final SemanticVersion currentVersion;
  final AppVersionConfig config;
  final UpdateType updateType;
  final bool isUpdateRequired;
  final bool isUpdateAvailable;
  final bool isDismissed;
  final int unsyncedOperationsCount;
  final bool isOffline;

  const AppVersionCheckResult({
    required this.currentVersion,
    required this.config,
    required this.updateType,
    required this.isUpdateRequired,
    required this.isUpdateAvailable,
    this.isDismissed = false,
    this.unsyncedOperationsCount = 0,
    this.isOffline = false,
  });

  /// Determines whether the non-intrusive bottom banner should be displayed.
  bool get shouldShowBanner =>
      updateType == UpdateType.optional &&
      isUpdateAvailable &&
      !isDismissed;

  /// Determines whether the blocking mandatory update screen should be displayed.
  bool get shouldBlockApp =>
      updateType == UpdateType.required &&
      isUpdateRequired;
}
