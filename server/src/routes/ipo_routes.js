/**
 * IPO Proxy Routes for Kith Backend
 *
 * Architecture:
 *   Mobile App -> Backend Proxy (/api/ipos) -> Upstream Free API (IPO Guru / IPOAlerts)
 *
 * Security & Quota:
 * - Provider API keys are strictly kept in server environment variables.
 * - In-memory cache protects free rate limits (300 requests/day quota).
 * - Zero hardcoded or mock IPOs in production. If unavailable, returns empty array.
 */

const express = require("express");
const router = express.Router();
const { IpoGuruProvider } = require("../services/ipo/ipo_guru_provider");
const { FinApiProvider } = require("../services/ipo/finapi_provider");
const { IpoAlertsProvider } = require("../services/ipo/ipo_alerts_provider");

// Provider Orchestrator Pipeline (Strict Priority Order: IPO Guru Primary -> FinAPI Backup -> Alerts)
const providers = [
  new IpoGuruProvider(),    // 1. PRIMARY: IPO Guru (Will activate automatically once key is added tomorrow)
  new FinApiProvider(),     // 2. BACKUP: FinAPI
  new IpoAlertsProvider(),  // 3. SECONDARY BACKUP: IPOAlerts
];

// Backend Cache state
let _cache = {
  data: null,
  expiry: 0,
  source: null,
  lastUpdated: null,
};

// In-flight refresh lock (Deduplicates simultaneous requests from multiple users)
let _inFlightFetch = null;

// Observability metrics (Never logs secrets, tokens, or PII)
const metrics = {
  totalRequests: 0,
  cacheHits: 0,
  cacheMisses: 0,
  providerCalls: 0,
  providerErrors: 0,
  lastSuccessfulSync: null,
  activeSource: "none",
};

// Cache duration: 60 minutes target refresh rate (~24 calls/day to protect free limits)
const CACHE_TTL_MS = 60 * 60 * 1000;

/**
 * Executes the provider pipeline to fetch live market IPOs.
 * Strict Rule: IPO Guru is PRIMARY. Only falls back to FinAPI if IPO Guru is unconfigured or fails.
 */
async function fetchFromPipeline() {
  if (_inFlightFetch) {
    return _inFlightFetch;
  }

  _inFlightFetch = (async () => {
    try {
      for (const provider of providers) {
        if (!provider.isConfigured) {
          continue;
        }

        try {
          metrics.providerCalls++;
          const results = await provider.fetchIpos();
          if (Array.isArray(results) && results.length > 0) {
            metrics.lastSuccessfulSync = new Date().toISOString();
            metrics.activeSource = provider.id;
            console.log(`[IpoRoutes] Successfully synced ${results.length} IPOs using provider: ${provider.id}`);
            return {
              data: results,
              source: provider.id,
              lastUpdated: metrics.lastSuccessfulSync,
            };
          }
        } catch (e) {
          metrics.providerErrors++;
          console.warn(`[IpoRoutes] Error with provider ${provider.id}:`, e.message);
        }
      }
      return null;
    } finally {
      _inFlightFetch = null;
    }
  })();

  return _inFlightFetch;
}

// GET /api/ipos — Returns real, current Indian IPOs (or cached live data)
router.get("/", async (req, res) => {
  metrics.totalRequests++;

  try {
    const now = Date.now();

    // 1. Serve from fresh cache if available
    if (_cache.data && now < _cache.expiry && _cache.data.length > 0) {
      metrics.cacheHits++;
      return res.json({
        data: _cache.data,
        source: _cache.source,
        isLive: true,
        cached: true,
        lastUpdated: _cache.lastUpdated,
      });
    }

    metrics.cacheMisses++;

    // 2. Fetch fresh data from upstream provider pipeline
    const pipelineResult = await fetchFromPipeline();
    if (pipelineResult && pipelineResult.data && pipelineResult.data.length > 0) {
      _cache = {
        data: pipelineResult.data,
        expiry: now + CACHE_TTL_MS,
        source: pipelineResult.source,
        lastUpdated: pipelineResult.lastUpdated,
      };

      return res.json({
        data: pipelineResult.data,
        source: pipelineResult.source,
        isLive: true,
        cached: false,
        lastUpdated: pipelineResult.lastUpdated,
      });
    }

    // 3. If upstream is unreachable but we have an existing expired cache, serve stale cache with warning
    if (_cache.data && _cache.data.length > 0) {
      return res.json({
        data: _cache.data,
        source: "stale_cache",
        isLive: false,
        cached: true,
        isStale: true,
        lastUpdated: _cache.lastUpdated,
        message: "Live provider currently unreachable. Displaying latest cached market data.",
      });
    }

    // 4. Zero fake data policy: return empty list if no provider configured or reachable
    return res.json({
      data: [],
      source: "none",
      isLive: false,
      cached: false,
      status: "unavailable",
      message: "IPO market data is currently unavailable. Ensure IPO_GURU_API_KEY is configured on the backend.",
    });
  } catch (err) {
    console.error("[IpoRoutes] Route handler error:", err.message);
    res.status(500).json({
      error: "Internal server error fetching IPO data",
      data: [],
    });
  }
});

// GET /api/ipos/metrics — Safe observability metrics
router.get("/metrics", (req, res) => {
  res.json({
    metrics: {
      ...metrics,
      cacheActive: Boolean(_cache.data && Date.now() < _cache.expiry),
      cachedItemsCount: _cache.data ? _cache.data.length : 0,
      activeProvider: providers.find((p) => p.isConfigured)?.id ?? "none",
    },
  });
});

// GET /api/ipos/:id — Single IPO by ID
router.get("/:id", async (req, res) => {
  const { id } = req.params;

  if (_cache.data) {
    const found = _cache.data.find((ipo) => ipo.id === id);
    if (found) {
      return res.json({ data: found });
    }
  }

  res.status(404).json({ error: "IPO not found in current market catalog" });
});

// ==========================================
// IPO Allotment Monitoring Endpoints
// ==========================================

const { db } = require("../db/database");
const { AllotmentMonitorService } = require("../services/ipo/allotment/allotment_monitor_service");

const monitorService = new AllotmentMonitorService(db);
if (process.env.NODE_ENV !== "test") {
  monitorService.start();
}

/**
 * POST /api/ipos/applications/register
 * Registers an IPO application for backend automatic allotment monitoring.
 */
router.post("/applications/register", async (req, res) => {
  try {
    const payload = req.body;
    if (!payload || !payload.id || !payload.ipoId) {
      return res.status(400).json({ error: "Missing required application parameters" });
    }

    const appsTable = db.tables.ipo_applications;
    const nowIso = new Date().toISOString();

    const existing = appsTable ? appsTable.get(payload.id) : null;
    const application = {
      ...payload,
      monitoringStatus: payload.monitoringStatus || existing?.monitoringStatus || "monitoring",
      checkCount: existing?.checkCount || 0,
      lastCheckedAt: existing?.lastCheckedAt || null,
      lastCheckMessage: existing?.lastCheckMessage || "Registered for automatic allotment monitoring",
      auditTrail: existing?.auditTrail || [
        {
          id: `audit_${Date.now()}_init`,
          timestamp: nowIso,
          title: "Application Registered",
          description: `Applied for ${payload.lotsApplied || 1} lots (${payload.accountDisplayName || "Account"})`,
        },
      ],
      createdAt: existing?.createdAt || payload.createdAt || nowIso,
      updatedAt: nowIso,
    };

    if (appsTable) {
      appsTable.set(application.id, application);
      db._persistTable("ipo_applications");
    }

    res.status(200).json({
      success: true,
      message: "Application registered for automatic allotment monitoring",
      data: application,
    });
  } catch (err) {
    console.error("[IpoRoutes] Error registering application:", err.message);
    res.status(500).json({ error: err.message });
  }
});

/**
 * POST /api/ipos/applications/:id/check-now
 * Manual on-demand allotment check fallback for a single application.
 */
router.post("/applications/:id/check-now", async (req, res) => {
  try {
    const { id } = req.params;
    const result = await monitorService.checkApplication(id);
    res.status(200).json({
      success: true,
      data: result.application,
      result: result.result,
    });
  } catch (err) {
    console.error(`[IpoRoutes] Error in check-now for ${req.params.id}:`, err.message);
    res.status(500).json({ error: err.message });
  }
});

/**
 * GET /api/ipos/applications/:id/status
 * Queries current monitoring status and audit history for an application.
 */
router.get("/applications/:id/status", (req, res) => {
  try {
    const { id } = req.params;
    const appsTable = db.tables.ipo_applications;
    const app = appsTable ? appsTable.get(id) : null;

    if (!app) {
      return res.status(404).json({ error: "Application not found" });
    }

    res.status(200).json({
      success: true,
      data: app,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * GET /api/ipos/user/:userId/allotments
 * Retrieves all tracked application allotment records for a user.
 */
router.get("/user/:userId/allotments", (req, res) => {
  try {
    const { userId } = req.params;
    const appsTable = db.tables.ipo_applications;
    const results = [];

    if (appsTable) {
      for (const app of appsTable.values()) {
        if (app.userId === userId) {
          results.push(app);
        }
      }
    }

    res.status(200).json({
      success: true,
      data: results,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

