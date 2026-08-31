const { IpoProvider } = require("./ipo_provider_interface");

/**
 * Primary Provider: IPO Guru API (ipoguru.in)
 *
 * Characteristics:
 * - Free Tier: 300 req/day, 15 req/min
 * - Coverage: Mainboard + SME, Open, Upcoming, Closed, Listed
 * - Details: Price Band, Lot Size, Issue Size, Subscriptions, GMP
 * - Authentication: X-API-KEY header (read securely from server-side environment)
 */
class IpoGuruProvider extends IpoProvider {
  get id() {
    return "ipo_guru";
  }

  get apiKey() {
    return process.env.IPO_GURU_API_KEY || "";
  }

  get isConfigured() {
    const key = this.apiKey;
    return (
      Boolean(key) &&
      key !== "your_ipo_guru_api_key_here" &&
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

      const response = await fetchFn("https://www.ipoguru.in/api/v1/ipos", {
        method: "GET",
        headers: {
          "X-API-KEY": this.apiKey,
          Accept: "application/json",
          "User-Agent": "Kith-Backend-Proxy/1.0",
        },
        signal: AbortSignal.timeout(7000),
      });

      if (response.status === 429) {
        console.warn("[IpoGuruProvider] Rate limit (429) reached from upstream API");
        return null;
      }

      if (!response.ok) {
        console.warn(`[IpoGuruProvider] HTTP ${response.status}: ${response.statusText}`);
        return null;
      }

      const payload = await response.json();
      const rawList = Array.isArray(payload)
        ? payload
        : payload?.ipos ?? payload?.data ?? payload?.result ?? null;

      if (!Array.isArray(rawList) || rawList.length === 0) {
        return null;
      }

      return rawList
        .map((item, idx) => this.normalizeItem(item, idx))
        .filter((ipo) => ipo && ipo.name && ipo.name !== "Unknown IPO");
    } catch (err) {
      console.warn("[IpoGuruProvider] Fetch error:", err.message);
      return null;
    }
  }

  /**
   * Normalizes raw IPO Guru response item into canonical Kith domain structure
   */
  normalizeItem(item, index) {
    if (!item) return null;

    const rawId = item.id ?? item.symbol ?? item.slug ?? `ipo_${index}`;
    const id = String(rawId).toLowerCase().replace(/[^a-z0-9_-]/g, "_");
    const name = item.company_name ?? item.name ?? item.ipo_name ?? "Unknown IPO";
    const companyName = item.company_name ?? item.issuer_company ?? name;
    const symbol = item.symbol ?? item.bse_code ?? item.nse_code ?? "";
    const category = (item.category ?? item.type ?? "mainboard").toLowerCase();
    const marketType = category.includes("sme") ? "sme" : "mainboard";

    const statusStr = (item.status ?? item.ipo_status ?? "upcoming").toLowerCase();
    let status = "upcoming";
    if (statusStr.includes("open") || statusStr.includes("active")) {
      status = "open";
    } else if (statusStr.includes("closed")) {
      status = "closed";
    } else if (statusStr.includes("allot") || statusStr.includes("out")) {
      status = "allotmentOut";
    } else if (statusStr.includes("list") || statusStr.includes("trad")) {
      status = "listed";
    }

    const minPrice = parseFloat(item.price_band_min ?? item.min_price ?? item.floor_price ?? 0) || 0;
    const maxPrice = parseFloat(item.price_band_max ?? item.max_price ?? item.cap_price ?? minPrice) || minPrice;
    const lotSize = parseInt(item.lot_size ?? item.market_lot ?? item.shares_per_lot ?? 1, 10) || 1;

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
      openDate: item.open_date ?? item.bidding_start_date ?? item.openDate ?? null,
      closeDate: item.close_date ?? item.bidding_end_date ?? item.closeDate ?? null,
      allotmentDate: item.allotment_date ?? item.allotmentDate ?? null,
      listingDate: item.listing_date ?? item.listingDate ?? null,
      minPrice,
      maxPrice: maxPrice > 0 ? maxPrice : minPrice,
      lotSize,
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
      source: "ipo_guru",
      isLive: true,
    };
  }
}

module.exports = { IpoGuruProvider };
