const { IpoProvider } = require("./ipo_provider_interface");

/**
 * Backup Provider: FinAPI (finapi.in / finapi.co)
 *
 * Characteristics:
 * - Free / Backup Tier
 * - Coverage: Indian Mainboard + SME IPOs (Open, Upcoming, Closed, Listed)
 * - Details: Price Band, Lot Size, Issue Size, Dates, Indicative GMP (where available)
 * - Authentication: FINAPI_API_KEY (Bearer token / X-API-KEY from secure server environment)
 * - Priority: BACKUP ONLY — Never called when primary (IPO Guru) is healthy & configured.
 */
class FinApiProvider extends IpoProvider {
  get id() {
    return "finapi";
  }

  get apiKey() {
    return process.env.FINAPI_API_KEY || "";
  }

  get isConfigured() {
    const key = this.apiKey;
    return (
      Boolean(key) &&
      key !== "your_finapi_api_key_here" &&
      key !== "your_api_key_here"
    );
  }

  async fetchIpos() {
    if (!this.isConfigured) {
      return null;
    }

    try {
      const { default: fetch } = await import("node-fetch").catch(() => ({
        default: null,
      }));
      const fetchFn = fetch ?? globalThis.fetch;
      if (!fetchFn) return null;

      const headers = {
        Accept: "application/json",
        "User-Agent": "Kith-Backend-Proxy/1.0",
        "X-API-Key": this.apiKey,
        "X-API-KEY": this.apiKey,
      };

      if (this.apiKey.startsWith("Bearer ")) {
        headers["Authorization"] = this.apiKey;
      } else {
        headers["Authorization"] = `Bearer ${this.apiKey}`;
      }

      // 1. Try Upvaly FinAPI primary endpoint (https://finapi.upvaly.com/api/ipo)
      let response = await fetchFn("https://finapi.upvaly.com/api/ipo", {
        method: "GET",
        headers,
        signal: AbortSignal.timeout(7000),
      }).catch(() => null);

      // Fallback endpoint if needed
      if (!response || !response.ok) {
        response = await fetchFn("https://api.finapi.in/v1/ipos", {
          method: "GET",
          headers,
          signal: AbortSignal.timeout(7000),
        }).catch(() => null);
      }

      if (!response) {
        return null;
      }

      if (response.status === 429) {
        console.warn("[FinApiProvider] Rate limit (429) reached from FinAPI");
        return null;
      }

      if (!response.ok) {
        console.warn(`[FinApiProvider] HTTP ${response.status}: ${response.statusText}`);
        return null;
      }

      const payload = await response.json();
      const rawList = Array.isArray(payload)
        ? payload
        : payload?.data ?? payload?.ipos ?? payload?.results ?? null;

      if (!Array.isArray(rawList) || rawList.length === 0) {
        return null;
      }

      return rawList
        .map((item, idx) => this.normalizeItem(item, idx))
        .filter((ipo) => ipo && ipo.name && ipo.name !== "Unknown IPO");
    } catch (err) {
      console.warn("[FinApiProvider] Fetch error:", err.message);
      return null;
    }
  }

  /**
   * Normalizes raw FinAPI response item into canonical Kith domain structure
   */
  normalizeItem(item, index) {
    if (!item) return null;

    const rawId = item.id ?? item.symbol ?? item.ticker ?? `ipo_fin_${index}`;
    const id = String(rawId).toLowerCase().replace(/[^a-z0-9_-]/g, "_");
    const name = item.name ?? item.company_name ?? item.ipo_name ?? "Unknown IPO";
    const companyName = item.company_name ?? item.issuer ?? name;
    const symbol = item.symbol ?? item.ticker ?? item.nse_code ?? item.bse_code ?? "";
    const category = (item.category ?? item.market_type ?? item.type ?? "mainboard").toLowerCase();
    const marketType = category.includes("sme") ? "sme" : "mainboard";

    const statusStr = (item.status ?? item.ipo_status ?? "upcoming").toLowerCase();
    let status = "upcoming";
    if (statusStr.includes("open") || statusStr.includes("active") || statusStr.includes("live")) {
      status = "open";
    } else if (statusStr.includes("closed") || statusStr.includes("ended")) {
      status = "closed";
    } else if (statusStr.includes("allot") || statusStr.includes("basis")) {
      status = "allotmentOut";
    } else if (statusStr.includes("list") || statusStr.includes("trad")) {
      status = "listed";
    }

    // Schedule extraction (FinAPI puts dates inside schedule object)
    const schedule = (item.schedule && typeof item.schedule === "object") ? item.schedule : {};
    const openDate = schedule.startDate ?? schedule.biddingStartDate ?? item.open_date ?? item.bidding_start_date ?? item.openDate ?? null;
    const closeDate = schedule.endDate ?? schedule.biddingEndDate ?? item.close_date ?? item.bidding_end_date ?? item.closeDate ?? null;
    const allotmentDate = schedule.allotmentFinalization ?? schedule.allotmentDate ?? item.allotment_date ?? item.allotmentDate ?? null;
    const listingDate = schedule.listingDate ?? item.listing_date ?? item.listingDate ?? null;

    // Price range parsing (handles "₹408 – ₹429", "₹59", "450 - 475" strings or direct numbers)
    let minPrice = parseFloat(item.price_band_min ?? item.min_price ?? item.price_min ?? item.floor_price ?? 0) || 0;
    let maxPrice = parseFloat(item.price_band_max ?? item.max_price ?? item.price_max ?? item.cap_price ?? minPrice) || minPrice;

    const priceRangeStr = item.priceRange ?? item.price_range ?? item.priceBand ?? item.price_band ?? null;
    if (priceRangeStr && minPrice === 0 && maxPrice === 0) {
      const numbers = (String(priceRangeStr).match(/\d+/g) || []).map(Number);
      if (numbers.length >= 2) {
        minPrice = numbers[0];
        maxPrice = numbers[1];
      } else if (numbers.length === 1) {
        minPrice = numbers[0];
        maxPrice = numbers[0];
      }
    }

    // Lot size parsing (handles String "34" or num 34)
    let lotSize = 1;
    const rawLot = item.lotSize ?? item.lot_size ?? item.market_lot ?? item.shares_per_lot;
    if (typeof rawLot === "number") {
      lotSize = rawLot;
    } else if (typeof rawLot === "string") {
      const digits = rawLot.replace(/[^0-9]/g, "");
      lotSize = parseInt(digits, 10) || 1;
    }

    const issueSizeCrores = parseFloat(item.issue_size ?? item.total_issue_size_cr ?? item.issue_size_crores ?? 0) || null;
    const freshIssueCrores = parseFloat(item.fresh_issue ?? item.fresh_issue_cr ?? 0) || null;
    const ofsCrores = parseFloat(item.ofs ?? item.offer_for_sale_cr ?? 0) || null;

    const gmp = parseFloat(item.gmp ?? item.grey_market_premium ?? item.current_gmp ?? 0) || null;

    const subQib = parseFloat(item.qib_subscription ?? item.qib ?? 0) || null;
    const subNii = parseFloat(item.nii_subscription ?? item.nii ?? item.hni ?? 0) || null;
    const subRetail = parseFloat(item.retail_subscription ?? item.retail ?? item.rii ?? 0) || null;
    const subEmp = parseFloat(item.employee_subscription ?? item.employee ?? item.emp ?? 0) || null;
    const subSh = parseFloat(item.shareholder_subscription ?? item.shareholder ?? 0) || null;
    const subOverall = parseFloat(item.subscription_overall ?? item.total_subscription ?? item.overall ?? 0) || null;

    const subscription = (subQib || subNii || subRetail || subEmp || subSh || subOverall) ? {
      qib: subQib,
      nii: subNii,
      retail: subRetail,
      employee: subEmp,
      shareholder: subSh,
      total: subOverall,
    } : null;

    return {
      id,
      name,
      companyName,
      symbol,
      marketType,
      status,
      openDate,
      closeDate,
      allotmentDate,
      listingDate,
      minPrice,
      maxPrice: maxPrice > 0 ? maxPrice : minPrice,
      lotSize: lotSize > 0 ? lotSize : 1,
      issueSizeCrores,
      freshIssueCrores,
      ofsCrores,
      subscription,
      subscriptionOverall: subOverall,
      gmp,
      issuePrice: parseFloat(item.issue_price ?? item.cutoff_price ?? 0) || null,
      listingPrice: parseFloat(item.listing_price ?? 0) || null,
      currentPrice: parseFloat(item.current_price ?? 0) || null,
      lastUpdated: new Date().toISOString(),
      source: "finapi",
      isLive: true,
    };
  }
}

module.exports = { FinApiProvider };
