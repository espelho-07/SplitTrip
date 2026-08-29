/**
 * Version Management Service
 *
 * Implements semantic version parsing, comparison, and dynamic release configuration.
 */

class VersionService {
  constructor() {
    this._config = {
      latestVersion: process.env.LATEST_APP_VERSION || '1.0.0',
      minimumSupportedVersion: process.env.MIN_SUPPORTED_APP_VERSION || '1.0.0',
      releaseNotes: '• Enhanced offline synchronization and data safety\n• Instant QR code scanning & invite links\n• Precision multi-currency split calculations\n• Real-time group balances and UPI settlement resolution',
      storeUrl: process.env.KITH_STORE_URL || 'https://play.google.com/store/apps/details?id=com.nirniq.kith',
      updatePriority: 'flexible', // 'flexible' (optional) | 'immediate' (required)
      publishedAt: new Date().toISOString(),
      featureFlags: {
        new_settlement_flow: true,
        new_trip_invite: true,
        new_sync_engine: true,
        offline_first_v2: true,
      },
    };
  }

  /**
   * Parses a semantic version string into [major, minor, patch] components.
   * Handles build numbers, e.g. "1.2.3+4" or "v1.2.3".
   */
  parseSemVer(versionStr) {
    if (!versionStr || typeof versionStr !== 'string') {
      return { major: 0, minor: 0, patch: 0, raw: '0.0.0' };
    }

    // Clean version string (remove leading 'v' or 'V', strip build suffix e.g. +1)
    let clean = versionStr.trim().replace(/^[vV]/, '');
    const buildIdx = clean.indexOf('+');
    if (buildIdx !== -1) {
      clean = clean.substring(0, buildIdx);
    }
    const preIdx = clean.indexOf('-');
    if (preIdx !== -1) {
      clean = clean.substring(0, preIdx);
    }

    const parts = clean.split('.').map(p => parseInt(p, 10));
    return {
      major: isNaN(parts[0]) ? 0 : parts[0],
      minor: isNaN(parts[1]) ? 0 : parts[1],
      patch: isNaN(parts[2]) ? 0 : parts[2],
      raw: versionStr.trim(),
    };
  }

  /**
   * Compares two semantic version strings.
   * Returns:
   *  -1 if v1 < v2
   *   0 if v1 == v2
   *   1 if v1 > v2
   */
  compareSemVer(v1, v2) {
    const p1 = this.parseSemVer(v1);
    const p2 = this.parseSemVer(v2);

    if (p1.major !== p2.major) {
      return p1.major > p2.major ? 1 : -1;
    }
    if (p1.minor !== p2.minor) {
      return p1.minor > p2.minor ? 1 : -1;
    }
    if (p1.patch !== p2.patch) {
      return p1.patch > p2.patch ? 1 : -1;
    }
    return 0;
  }

  /**
   * Evaluates the update status for a given client version.
   */
  checkVersion(clientVersion) {
    const minVer = this._config.minimumSupportedVersion;
    const latestVer = this._config.latestVersion;

    let updateType = 'none'; // 'none' | 'optional' | 'required'
    let isUpdateRequired = false;
    let isUpdateAvailable = false;

    if (clientVersion) {
      // 1. Is client version below minimum supported version?
      if (this.compareSemVer(clientVersion, minVer) < 0) {
        updateType = 'required';
        isUpdateRequired = true;
        isUpdateAvailable = true;
      }
      // 2. Is client version >= minVer, but below latest version?
      else if (this.compareSemVer(clientVersion, latestVer) < 0) {
        updateType = 'optional';
        isUpdateRequired = false;
        isUpdateAvailable = true;
      }
      // 3. Client version is up-to-date or newer
      else {
        updateType = 'none';
        isUpdateRequired = false;
        isUpdateAvailable = false;
      }
    }

    return {
      clientVersion: clientVersion || null,
      latestVersion: latestVer,
      minimumSupportedVersion: minVer,
      updateType,
      isUpdateRequired,
      isUpdateAvailable,
      releaseNotes: this._config.releaseNotes,
      storeUrl: this._config.storeUrl,
      updatePriority: isUpdateRequired ? 'immediate' : this._config.updatePriority,
      publishedAt: this._config.publishedAt,
      featureFlags: this._config.featureFlags,
    };
  }

  /**
   * Updates dynamic server version configuration at runtime.
   */
  updateConfig(updates = {}) {
    if (updates.latestVersion && typeof updates.latestVersion === 'string') {
      this._config.latestVersion = updates.latestVersion.trim();
    }
    if (updates.minimumSupportedVersion && typeof updates.minimumSupportedVersion === 'string') {
      this._config.minimumSupportedVersion = updates.minimumSupportedVersion.trim();
    }
    if (updates.releaseNotes && typeof updates.releaseNotes === 'string') {
      this._config.releaseNotes = updates.releaseNotes.trim();
    }
    if (updates.storeUrl && typeof updates.storeUrl === 'string') {
      this._config.storeUrl = updates.storeUrl.trim();
    }
    if (updates.updatePriority && typeof updates.updatePriority === 'string') {
      this._config.updatePriority = updates.updatePriority.trim();
    }
    if (updates.featureFlags && typeof updates.featureFlags === 'object') {
      this._config.featureFlags = {
        ...this._config.featureFlags,
        ...updates.featureFlags,
      };
    }
    this._config.publishedAt = new Date().toISOString();
    return this.getConfig();
  }

  getConfig() {
    return { ...this._config };
  }
}

const versionService = new VersionService();
module.exports = versionService;
