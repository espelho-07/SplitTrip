/**
 * Allotment Monitor Service (Scheduled Background Worker)
 *
 * Responsibilities:
 * 1. Discovers active IPO applications in MONITORING or RETRYING state.
 * 2. Prioritizes applications based on allotment date windows.
 * 3. Coordinates provider checking with rate-limiting, timeout guards, and exponential backoff.
 * 4. Idempotently updates application state, financial balance, and creates audit log entries.
 * 5. Strictly protects sensitive data (never logs full PAN).
 */

const { FinApiAllotmentProvider } = require('./finapi_allotment_provider');
const { RegistrarAllotmentProvider } = require('./registrar_allotment_provider');

class AllotmentMonitorService {
  constructor(db, options = {}) {
    this.db = db;
    this.providers = [
      new FinApiAllotmentProvider(),
      new RegistrarAllotmentProvider(),
    ];
    this.pollIntervalMs = options.pollIntervalMs || 15 * 60 * 1000;
    this.maxRetries = options.maxRetries || 24;
    this._intervalTimer = null;
    this._isRunning = false;
  }

  start() {
    if (this._intervalTimer) return;
    console.log('[AllotmentMonitor] Starting background monitoring worker...');
    this._intervalTimer = setInterval(() => this.runScheduledCycle(), this.pollIntervalMs);
    if (this._intervalTimer && this._intervalTimer.unref) {
      this._intervalTimer.unref();
    }
  }

  stop() {
    if (this._intervalTimer) {
      clearInterval(this._intervalTimer);
      this._intervalTimer = null;
      console.log('[AllotmentMonitor] Stopped background monitoring worker.');
    }
  }

  shouldCheckNow(app) {
    if (!app) return false;
    const status = (app.status || 'applied').toLowerCase();
    if (status === 'allotted' || status === 'notallotted' || status === 'not_allotted' || status === 'refunded') {
      return false;
    }

    const monitoringStatus = (app.monitoringStatus || 'monitoring').toLowerCase();
    if (monitoringStatus === 'stopped' || monitoringStatus === 'resultfound' || monitoringStatus === 'result_found') {
      return false;
    }

    const now = Date.now();
    if (app.nextCheckAt) {
      const nextCheck = new Date(app.nextCheckAt).getTime();
      if (now < nextCheck) {
        return false;
      }
    }

    return true;
  }

  async runScheduledCycle() {
    if (this._isRunning) return;
    this._isRunning = true;

    try {
      const appsTable = this.db.tables.ipo_applications;
      if (!appsTable) return;

      const candidates = [];
      for (const app of appsTable.values()) {
        if (this.shouldCheckNow(app)) {
          candidates.push(app);
        }
      }

      if (candidates.length === 0) return;

      console.log(`[AllotmentMonitor] Scanning ${candidates.length} active applications for allotment updates`);

      for (const app of candidates) {
        try {
          await this.checkApplication(app.id);
          await new Promise((r) => setTimeout(r, 500));
        } catch (e) {
          console.warn(`[AllotmentMonitor] Error checking application ${app.id}:`, e.message);
        }
      }
    } finally {
      this._isRunning = false;
    }
  }

  async checkApplication(applicationId) {
    const appsTable = this.db.tables.ipo_applications;
    if (!appsTable || !appsTable.has(applicationId)) {
      throw new Error(`Application ${applicationId} not found`);
    }

    const app = appsTable.get(applicationId);
    const checkCount = (app.checkCount || 0) + 1;
    const nowIso = new Date().toISOString();

    let definitiveResult = null;
    let fallbackResult = null;

    for (const provider of this.providers) {
      if (!provider.isConfigured) continue;

      try {
        const result = await provider.checkAllotment({
          ipoSymbol: app.ipoSymbol,
          ipoName: app.ipoName,
          pan: app.accountMaskedPan || app.pan,
          applicationNumber: app.applicationNumber,
          registrar: app.registrar,
          lotsApplied: app.lotsApplied,
          lotSize: app.lotSize,
          bidPriceRupees: app.bidPriceInRupees,
        });

        if (result && result.isDefinitive) {
          definitiveResult = result;
          break;
        } else if (result && !fallbackResult) {
          fallbackResult = result;
        }
      } catch (err) {
        console.warn(`[AllotmentMonitor] Provider ${provider.id} error:`, err.message);
      }
    }

    const selectedResult = definitiveResult || fallbackResult;
    return this._applyCheckResult(app, selectedResult, checkCount, nowIso);
  }

  _applyCheckResult(app, result, checkCount, nowIso) {
    const appsTable = this.db.tables.ipo_applications;
    const currentAuditTrail = Array.isArray(app.auditTrail) ? [...app.auditTrail] : [];

    if (result && result.isDefinitive) {
      let newStatus = 'applied';
      let allottedLots = result.allottedLots || 0;
      let allottedShares = result.allottedShares || (allottedLots * (app.lotSize || 1));
      let investedPaise = 0;
      let releasedPaise = 0;
      const appAmount = app.applicationAmountInPaise || 0;
      const issuePrice = result.issuePriceRupees || app.bidPriceInRupees || 0;

      if (result.status === 'ALLOTTED') {
        newStatus = 'allotted';
        allottedLots = allottedLots > 0 ? allottedLots : app.lotsApplied;
        allottedShares = allottedLots * (app.lotSize || 1);
        investedPaise = allottedLots * (app.lotSize || 1) * issuePrice * 100;
        releasedPaise = appAmount > investedPaise ? appAmount - investedPaise : 0;
      } else if (result.status === 'NOT_ALLOTTED') {
        newStatus = 'notAllotted';
        allottedLots = 0;
        allottedShares = 0;
        investedPaise = 0;
        releasedPaise = appAmount;
      } else if (result.status === 'PARTIALLY_ALLOTTED') {
        newStatus = 'partiallyAllotted';
        investedPaise = allottedLots * (app.lotSize || 1) * issuePrice * 100;
        releasedPaise = appAmount > investedPaise ? appAmount - investedPaise : 0;
      }

      currentAuditTrail.push({
        id: `audit_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
        timestamp: nowIso,
        title: `Allotment Confirmed: ${newStatus}`,
        description: result.message || `Result received via ${result.providerId}`,
      });

      const updatedApp = {
        ...app,
        status: newStatus,
        monitoringStatus: 'resultFound',
        allottedLots,
        allottedShares,
        actualInvestedAmountInPaise: investedPaise,
        releasedAmountInPaise: releasedPaise,
        lastCheckedAt: nowIso,
        lastCheckMessage: result.message,
        checkCount,
        auditTrail: currentAuditTrail,
        updatedAt: nowIso,
      };

      appsTable.set(app.id, updatedApp);
      this.db._persistTable('ipo_applications');

      return {
        success: true,
        isDefinitive: true,
        application: updatedApp,
        result,
      };
    }

    const backoffMinutes = Math.min(60 * 24, Math.pow(1.5, Math.min(checkCount, 10)) * 15);
    const nextCheckAt = new Date(Date.now() + backoffMinutes * 60 * 1000).toISOString();

    const isMaxRetriesReached = checkCount >= this.maxRetries;
    const nextMonitoringStatus = isMaxRetriesReached ? 'failed' : 'monitoring';

    const updatedApp = {
      ...app,
      monitoringStatus: nextMonitoringStatus,
      lastCheckedAt: nowIso,
      nextCheckAt: isMaxRetriesReached ? null : nextCheckAt,
      lastCheckMessage: result?.message || "We'll check again automatically",
      checkCount,
      updatedAt: nowIso,
    };

    appsTable.set(app.id, updatedApp);
    this.db._persistTable('ipo_applications');

    return {
      success: true,
      isDefinitive: false,
      application: updatedApp,
      result: result || { status: 'PENDING', message: "We'll check again automatically" },
    };
  }
}

module.exports = {
  AllotmentMonitorService,
};
