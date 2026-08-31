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
const { IpoAlertsProvider } = require("../services/ipo/ipo_alerts_provider");

const providers = [
  new IpoGuruProvider(),
  new IpoAlertsProvider(),
];

// Backend Cache state
let _cache = {
  data: null,
  expiry: 0,
  source: null,
  lastUpdated: null,
};

// Observability metrics (Never logs secrets, tokens, or PII)
const metrics = {
  totalRequests: 0,
  cacheHits: 0,
  cacheMisses: 0,
  providerCalls: 0,
  providerErrors: 0,
  lastSuccessfulSync: null,
};

const CACHE_TTL_MS = 15 * 60 * 1000; // 15 minutes cache

/**
 * Executes the provider pipeline to fetch live market IPOs
 */
async function fetchFromPipeline() {
  for (const provider of providers) {
    if (!provider.isConfigured) {
      continue;
    }

    try {
      metrics.providerCalls++;
      const results = await provider.fetchIpos();
      if (Array.isArray(results) && results.length > 0) {
        metrics.lastSuccessfulSync = new Date().toISOString();
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

module.exports = router;
