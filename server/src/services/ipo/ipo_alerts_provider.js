const { IpoProvider } = require("./ipo_provider_interface");

/**
 * Secondary Backup Provider: IPOAlerts API (api.ipoalerts.in)
 *
 * Characteristics:
 * - Free Tier: 25 req/day, 6 req/min
 * - Coverage: Open IPOs (Free tier limited to active bidding)
 * - Authentication: X-API-KEY header / query token
 */
class IpoAlertsProvider extends IpoProvider {
  get id() {
    return "ipo_alerts";
  }

  get apiKey() {
    return process.env.IPO_ALERTS_API_KEY || "";
  }

  get isConfigured() {
    const key = this.apiKey;
    return Boolean(key) && key !== "your_api_key_here";
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

      const response = await fetchFn("https://api.ipoalerts.in/ipos", {
        method: "GET",
        headers: {
          "X-API-KEY": this.apiKey,
          Accept: "application/json",
          "User-Agent": "Kith-Backend-Proxy/1.0",
        },
        signal: AbortSignal.timeout(6000),
      });

      if (!response.ok) {
        console.warn(`[IpoAlertsProvider] HTTP ${response.status}: ${response.statusText}`);
        return null;
      }

      const data = await response.json();
      const rawList = Array.isArray(data)
        ? data
        : data?.ipos ?? data?.data ?? null;

      if (!Array.isArray(rawList) || rawList.length === 0) {
        return null;
      }

      return rawList
        .map((item, idx) => this.normalizeItem(item, idx))
        .filter((ipo) => ipo && ipo.name);
    } catch (err) {
      console.warn("[IpoAlertsProvider] Fetch error:", err.message);
      return null;
    }
  }

  normalizeItem(item, index) {
    if (!item) return null;

    const rawId = item.id ?? item.symbol ?? `ipo_alt_${index}`;
    const id = String(rawId).toLowerCase().replace(/[^a-z0-9_-]/g, "_");
    const name = item.name ?? item.companyName ?? "Unknown IPO";
    const symbol = item.symbol ?? "";
    const marketType = (item.marketType ?? item.category ?? "").toLowerCase() === "sme" ? "sme" : "mainboard";

    const statusStr = (item.status ?? "open").toLowerCase();
    let status = "open";
    if (statusStr.includes("upcom")) status = "upcoming";
    else if (statusStr.includes("close")) status = "closed";
    else if (statusStr.includes("list")) status = "listed";

    const minPrice = parseFloat(item.minPrice ?? item.priceMin ?? 0) || 0;
    const maxPrice = parseFloat(item.maxPrice ?? item.priceMax ?? minPrice) || minPrice;
    const lotSize = parseInt(item.lotSize ?? 1, 10) || 1;

    return {
      id,
      name,
      companyName: item.companyName ?? name,
      symbol,
      marketType,
      status,
      openDate: item.openDate ?? null,
      closeDate: item.closeDate ?? null,
      allotmentDate: item.allotmentDate ?? null,
      listingDate: item.listingDate ?? null,
      minPrice,
      maxPrice: maxPrice > 0 ? maxPrice : minPrice,
      lotSize,
      issueSizeCrores: parseFloat(item.issueSize ?? 0) || null,
      freshIssueCrores: null,
      ofsCrores: null,
      subscription: null,
      subscriptionOverall: parseFloat(item.subscription ?? 0) || null,
      gmp: parseFloat(item.gmp ?? 0) || null,
      issuePrice: null,
      listingPrice: null,
      currentPrice: null,
      lastUpdated: new Date().toISOString(),
      source: "ipo_alerts",
      isLive: true,
    };
  }
}

module.exports = { IpoAlertsProvider };
