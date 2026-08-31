/**
 * Supabase Edge Function: ipo-data
 *
 * Secure proxy for IPO market data.
 * Architecture:
 *   1. IPO Guru (PRIMARY) — Automatically becomes active when IPO_GURU_API_KEY is configured
 *   2. FinAPI (BACKUP) — Active fallback when IPO Guru is unconfigured or unavailable
 *
 * Environment Secrets:
 * - IPO_GURU_API_KEY: Primary secret from ipoguru.in
 * - FINAPI_API_KEY: Backup secret from finapi.in
 */

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// In-memory cache per Edge worker isolate
let cachedIpos: any[] | null = null;
let cacheExpiry = 0;
let cachedSource = "none";
let cacheLastUpdated: string | null = null;

const CACHE_TTL_MS = 60 * 60 * 1000; // 60 minutes (~24 refreshes/day)

function normalizeIpo(item: any, idx: number, source: string) {
  const rawId = item.id ?? item.symbol ?? item.ticker ?? `ipo_${source}_${idx}`;
  const id = String(rawId).toLowerCase().replace(/[^a-z0-9_-]/g, "_");
  const name = item.company_name ?? item.name ?? item.ipo_name ?? "Unknown IPO";
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

  const minPrice = parseFloat(item.price_band_min ?? item.min_price ?? item.floor_price ?? 0) || 0;
  const maxPrice = parseFloat(item.price_band_max ?? item.max_price ?? item.cap_price ?? minPrice) || minPrice;
  const lotSize = parseInt(item.lot_size ?? item.market_lot ?? 1, 10) || 1;

  const issueSizeCrores = parseFloat(item.issue_size ?? item.total_issue_size_cr ?? 0) || null;
  const freshIssueCrores = parseFloat(item.fresh_issue ?? 0) || null;
  const ofsCrores = parseFloat(item.ofs ?? 0) || null;
  const gmp = parseFloat(item.gmp ?? item.grey_market_premium ?? 0) || null;

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
    gmp,
    lastUpdated: new Date().toISOString(),
    source,
    isLive: true,
  };
}

async function fetchFromIpoGuru(apiKey: string): Promise<any[] | null> {
  try {
    const res = await fetch("https://www.ipoguru.in/api/v1/ipos", {
      method: "GET",
      headers: {
        "X-API-KEY": apiKey,
        Accept: "application/json",
      },
    });
    if (!res.ok) return null;
    const json = await res.json();
    const rawList = Array.isArray(json) ? json : json?.ipos ?? json?.data ?? null;
    if (!Array.isArray(rawList) || rawList.length === 0) return null;
    return rawList.map((item: any, idx: number) => normalizeIpo(item, idx, "ipo_guru"));
  } catch {
    return null;
  }
}

async function fetchFromFinApi(apiKey: string): Promise<any[] | null> {
  try {
    const headers: Record<string, string> = { Accept: "application/json" };
    if (apiKey.startsWith("Bearer ")) {
      headers["Authorization"] = apiKey;
    } else {
      headers["Authorization"] = `Bearer ${apiKey}`;
      headers["X-API-KEY"] = apiKey;
    }

    const res = await fetch("https://api.finapi.in/v1/ipos", {
      method: "GET",
      headers,
    });
    if (!res.ok) return null;
    const json = await res.json();
    const rawList = Array.isArray(json) ? json : json?.ipos ?? json?.data ?? json?.results ?? null;
    if (!Array.isArray(rawList) || rawList.length === 0) return null;
    return rawList.map((item: any, idx: number) => normalizeIpo(item, idx, "finapi"));
  } catch {
    return null;
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const now = Date.now();

    // 1. Return fresh isolate cache if valid
    if (cachedIpos && now < cacheExpiry && cachedIpos.length > 0) {
      return new Response(
        JSON.stringify({
          data: cachedIpos,
          isLive: true,
          cached: true,
          source: cachedSource,
          lastUpdated: cacheLastUpdated,
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }

    const guruKey = Deno.env.get("IPO_GURU_API_KEY");
    const finApiKey = Deno.env.get("FINAPI_API_KEY");

    // 2. Try Primary: IPO Guru
    if (guruKey && guruKey !== "your_ipo_guru_api_key_here") {
      const guruData = await fetchFromIpoGuru(guruKey);
      if (guruData && guruData.length > 0) {
        cachedIpos = guruData;
        cacheExpiry = now + CACHE_TTL_MS;
        cachedSource = "ipo_guru";
        cacheLastUpdated = new Date().toISOString();

        return new Response(
          JSON.stringify({
            data: guruData,
            isLive: true,
            cached: false,
            source: "ipo_guru",
            lastUpdated: cacheLastUpdated,
          }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200,
          }
        );
      }
    }

    // 3. Try Backup: FinAPI
    if (finApiKey && finApiKey !== "your_finapi_api_key_here") {
      const finData = await fetchFromFinApi(finApiKey);
      if (finData && finData.length > 0) {
        cachedIpos = finData;
        cacheExpiry = now + CACHE_TTL_MS;
        cachedSource = "finapi";
        cacheLastUpdated = new Date().toISOString();

        return new Response(
          JSON.stringify({
            data: finData,
            isLive: true,
            cached: false,
            source: "finapi",
            lastUpdated: cacheLastUpdated,
          }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200,
          }
        );
      }
    }

    // 4. Stale cache fallback if available
    if (cachedIpos && cachedIpos.length > 0) {
      return new Response(
        JSON.stringify({
          data: cachedIpos,
          isLive: false,
          cached: true,
          isStale: true,
          source: cachedSource,
          lastUpdated: cacheLastUpdated,
          message: "Upstream providers temporarily unreachable. Showing latest cached market data.",
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }

    // 5. Zero fake data: return empty list if no provider configured/reachable
    return new Response(
      JSON.stringify({
        data: [],
        isLive: false,
        status: "unavailable",
        message: "IPO market data is currently unavailable.",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({
        data: cachedIpos ?? [],
        isLive: false,
        error: err.message,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});
