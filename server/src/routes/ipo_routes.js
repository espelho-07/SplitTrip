/**
 * IPO Proxy Routes for Kith Backend
 *
 * Proxies IPO data from IPO Guru API (with server-side API key)
 * so the Flutter app never needs to embed an API key.
 *
 * Routes:
 *   GET /api/ipos         — Returns normalized IPO list (live or fallback)
 *   GET /api/ipos/:id     — Returns a single IPO by ID (from cached list)
 */

const express = require("express");
const router = express.Router();

// In-memory cache to avoid hammering the upstream API (TTL: 30 minutes)
let _cachedIpos = null;
let _cacheExpiry = 0;
const CACHE_TTL_MS = 30 * 60 * 1000; // 30 minutes

/**
 * Fetches IPO data from IPO Guru API.
 * Returns null if the API key is not configured or the request fails.
 */
async function fetchFromIpoGuru() {
  const apiKey = process.env.IPO_GURU_API_KEY;
  if (!apiKey || apiKey === "your_ipo_guru_api_key_here") {
    return null;
  }

  try {
    const { default: fetch } = await import("node-fetch").catch(() => ({ default: null }));
    const fetchFn = fetch ?? globalThis.fetch;
    if (!fetchFn) return null;

    const res = await fetchFn("https://www.ipoguru.in/api/v1/ipos", {
      headers: {
        "X-API-KEY": apiKey,
        Accept: "application/json",
      },
      signal: AbortSignal.timeout(6000),
    });

    if (!res.ok) {
      console.warn(`[IpoRoutes] IPO Guru returned ${res.status}`);
      return null;
    }

    const data = await res.json();
    const list = Array.isArray(data)
      ? data
      : data?.ipos ?? data?.data ?? data?.result ?? null;

    return list;
  } catch (e) {
    console.warn("[IpoRoutes] IPO Guru fetch error (non-fatal):", e.message);
    return null;
  }
}

/**
 * Normalizes an IPO Guru API item into the Kith app's Ipo model fields.
 * Field mapping is based on IPO Guru's documented response schema.
 */
function normalizeIpoGuruItem(item, index) {
  const id = item.id ?? item.symbol ?? `ipo_${index}`;
  const now = new Date().toISOString();
  return {
    id: String(id).toLowerCase().replace(/\s+/g, "_"),
    name: item.company_name ?? item.name ?? "Unknown IPO",
    companyName: item.company_name ?? item.name ?? "Unknown Company",
    symbol: item.symbol ?? item.bse_code ?? "",
    marketType: item.category?.toLowerCase() === "sme" ? "sme" : "mainboard",
    status: (item.status ?? "upcoming").toLowerCase(),
    openDate: item.open_date ?? item.openDate ?? null,
    closeDate: item.close_date ?? item.closeDate ?? null,
    allotmentDate: item.allotment_date ?? item.allotmentDate ?? null,
    listingDate: item.listing_date ?? item.listingDate ?? null,
    minPrice: parseFloat(item.price_band_min ?? item.min_price ?? item.minPrice ?? 0),
    maxPrice: parseFloat(item.price_band_max ?? item.max_price ?? item.maxPrice ?? 0),
    lotSize: parseInt(item.lot_size ?? item.lotSize ?? 0, 10),
    issueSizeCrores: parseFloat(item.issue_size ?? item.issueSizeCrores ?? 0),
    freshIssueCrores: parseFloat(item.fresh_issue ?? item.freshIssueCrores ?? 0),
    ofsCrores: parseFloat(item.ofs ?? item.ofsCrores ?? 0),
    gmp: parseFloat(item.gmp ?? item.grey_market_premium ?? 0),
    issuePrice: parseFloat(item.issue_price ?? item.issuePrice ?? 0) || null,
    listingPrice: parseFloat(item.listing_price ?? item.listingPrice ?? 0) || null,
    currentPrice: parseFloat(item.current_price ?? item.currentPrice ?? 0) || null,
    subscriptionOverall: parseFloat(item.subscription_overall ?? item.total_subscription ?? 0),
    subscription: {
      qib: parseFloat(item.qib_subscription ?? item.qib ?? 0),
      nii: parseFloat(item.nii_subscription ?? item.nii ?? 0),
      retail: parseFloat(item.retail_subscription ?? item.retail ?? 0),
      shareholder: parseFloat(item.shareholder_subscription ?? item.shareholder ?? 0),
      employee: parseFloat(item.employee_subscription ?? item.employee ?? 0),
      total: parseFloat(item.subscription_overall ?? item.total_subscription ?? 0),
    },
    lastUpdated: now,
    isLive: true,
  };
}

/**
 * Returns the static curated fallback catalog when live data is unavailable.
 * All dates are fixed (not relative) to prevent showing stale data as current.
 */
function getStaticFallbackCatalog() {
  const staleDataDate = "2025-08-31T00:00:00.000Z";
  return [
    // Listed IPOs (real, verified)
    {
      id: "ipo_bajaj_housing",
      name: "Bajaj Housing Finance IPO",
      companyName: "Bajaj Housing Finance Limited",
      symbol: "BAJAJHFL",
      marketType: "mainboard",
      status: "listed",
      openDate: "2024-09-09T00:00:00.000Z",
      closeDate: "2024-09-11T00:00:00.000Z",
      allotmentDate: "2024-09-12T00:00:00.000Z",
      listingDate: "2024-09-16T00:00:00.000Z",
      minPrice: 66,
      maxPrice: 70,
      lotSize: 214,
      issueSizeCrores: 6560.0,
      freshIssueCrores: 3560.0,
      ofsCrores: 3000.0,
      issuePrice: 70,
      listingPrice: 150,
      currentPrice: 115,
      subscriptionOverall: 63.6,
      subscription: { qib: 143.58, nii: 71.23, retail: 17.84, shareholder: 18.5, total: 63.6 },
      gmp: 0,
      lastUpdated: staleDataDate,
      isLive: false,
    },
    {
      id: "ipo_hyundai_motor",
      name: "Hyundai Motor India IPO",
      companyName: "Hyundai Motor India Limited",
      symbol: "HYUNDAI",
      marketType: "mainboard",
      status: "listed",
      openDate: "2024-10-15T00:00:00.000Z",
      closeDate: "2024-10-17T00:00:00.000Z",
      allotmentDate: "2024-10-18T00:00:00.000Z",
      listingDate: "2024-10-22T00:00:00.000Z",
      minPrice: 1865,
      maxPrice: 1960,
      lotSize: 7,
      issueSizeCrores: 27870.0,
      freshIssueCrores: 0.0,
      ofsCrores: 27870.0,
      issuePrice: 1960,
      listingPrice: 1934,
      currentPrice: 1750,
      subscriptionOverall: 2.37,
      subscription: { qib: 6.97, nii: 0.6, retail: 0.5, total: 2.37 },
      gmp: 0,
      lastUpdated: staleDataDate,
      isLive: false,
    },
    {
      id: "ipo_swiggy",
      name: "Swiggy Limited IPO",
      companyName: "Swiggy Limited",
      symbol: "SWIGGY",
      marketType: "mainboard",
      status: "listed",
      openDate: "2024-11-06T00:00:00.000Z",
      closeDate: "2024-11-08T00:00:00.000Z",
      allotmentDate: "2024-11-11T00:00:00.000Z",
      listingDate: "2024-11-13T00:00:00.000Z",
      minPrice: 371,
      maxPrice: 390,
      lotSize: 38,
      issueSizeCrores: 11327.0,
      freshIssueCrores: 4499.0,
      ofsCrores: 6828.0,
      issuePrice: 390,
      listingPrice: 420,
      currentPrice: 495,
      subscriptionOverall: 3.59,
      subscription: { qib: 6.02, nii: 1.71, retail: 1.14, total: 3.59 },
      gmp: 0,
      lastUpdated: staleDataDate,
      isLive: false,
    },
    {
      id: "ipo_premier_energies",
      name: "Premier Energies IPO",
      companyName: "Premier Energies Limited",
      symbol: "PREMIERENE",
      marketType: "mainboard",
      status: "listed",
      openDate: "2024-08-27T00:00:00.000Z",
      closeDate: "2024-08-29T00:00:00.000Z",
      allotmentDate: "2024-09-02T00:00:00.000Z",
      listingDate: "2024-09-03T00:00:00.000Z",
      minPrice: 427,
      maxPrice: 450,
      lotSize: 33,
      issueSizeCrores: 2830.4,
      issuePrice: 450,
      listingPrice: 991,
      currentPrice: 950,
      subscriptionOverall: 75.0,
      subscription: { qib: 216.7, nii: 50.0, retail: 7.7, employee: 11.4, total: 75.0 },
      gmp: 0,
      lastUpdated: staleDataDate,
      isLive: false,
    },
    {
      id: "ipo_ntpc_green",
      name: "NTPC Green Energy IPO",
      companyName: "NTPC Green Energy Limited",
      symbol: "NTPCGREEN",
      marketType: "mainboard",
      status: "listed",
      openDate: "2024-11-19T00:00:00.000Z",
      closeDate: "2024-11-22T00:00:00.000Z",
      allotmentDate: "2024-11-25T00:00:00.000Z",
      listingDate: "2024-11-27T00:00:00.000Z",
      minPrice: 102,
      maxPrice: 108,
      lotSize: 138,
      issueSizeCrores: 10000.0,
      freshIssueCrores: 10000.0,
      ofsCrores: 0,
      issuePrice: 108,
      listingPrice: 111,
      currentPrice: 102,
      subscriptionOverall: 2.55,
      subscription: { qib: 4.6, nii: 1.4, retail: 1.2, total: 2.55 },
      gmp: 0,
      lastUpdated: staleDataDate,
      isLive: false,
    },
  ];
}

// GET /api/ipos — Live or cached IPO list
router.get("/", async (req, res) => {
  try {
    // Serve from memory cache if fresh
    if (_cachedIpos && Date.now() < _cacheExpiry) {
      return res.json({ data: _cachedIpos, source: "cache", isLive: true });
    }

    // Try live API
    const liveList = await fetchFromIpoGuru();
    if (liveList && liveList.length > 0) {
      const normalized = liveList
        .map((item, i) => normalizeIpoGuruItem(item, i))
        .filter((ipo) => ipo.name !== "Unknown IPO");

      _cachedIpos = normalized;
      _cacheExpiry = Date.now() + CACHE_TTL_MS;

      return res.json({ data: normalized, source: "live", isLive: true });
    }

    // Fallback to static catalog
    const fallback = getStaticFallbackCatalog();
    return res.json({
      data: fallback,
      source: "fallback",
      isLive: false,
      message: "Live data unavailable. Showing curated historical IPOs.",
      dataAsOf: "2025-08-31",
    });
  } catch (err) {
    console.error("[IpoRoutes] Error:", err.message);
    res.status(500).json({ error: "Failed to fetch IPO data" });
  }
});

// GET /api/ipos/:id — Single IPO by ID
router.get("/:id", async (req, res) => {
  const { id } = req.params;

  // Check memory cache first
  if (_cachedIpos) {
    const found = _cachedIpos.find((ipo) => ipo.id === id);
    if (found) return res.json({ data: found });
  }

  // Check fallback catalog
  const fallback = getStaticFallbackCatalog();
  const fallbackFound = fallback.find((ipo) => ipo.id === id);
  if (fallbackFound) return res.json({ data: fallbackFound });

  res.status(404).json({ error: "IPO not found" });
});

module.exports = router;
