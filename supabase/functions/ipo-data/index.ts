/**
 * Supabase Edge Function: ipo-data
 *
 * Secure proxy for IPO market data (IPO Guru API).
 * Runs on Deno / Supabase Edge Network.
 *
 * Environment Secrets:
 * - IPO_GURU_API_KEY: Secret key provided by ipoguru.in
 */

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// In-memory cache per Edge worker isolate
let cachedIpos: any[] | null = null;
let cacheExpiry = 0;
const CACHE_TTL_MS = 15 * 60 * 1000; // 15 minutes

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const now = Date.now();

    // 1. Serve from isolate memory cache if fresh
    if (cachedIpos && now < cacheExpiry) {
      return new Response(
        JSON.stringify({
          data: cachedIpos,
          isLive: true,
          cached: true,
          source: "edge_cache",
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }

    const apiKey = Deno.env.get("IPO_GURU_API_KEY");
    if (!apiKey || apiKey === "your_ipo_guru_api_key_here") {
      return new Response(
        JSON.stringify({
          data: cachedIpos ?? [],
          isLive: false,
          status: "unavailable",
          message: "IPO_GURU_API_KEY secret is not configured in Supabase.",
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }

    // 2. Fetch from IPO Guru
    const response = await fetch("https://www.ipoguru.in/api/v1/ipos", {
      method: "GET",
      headers: {
        "X-API-KEY": apiKey,
        Accept: "application/json",
      },
    });

    if (!response.ok) {
      return new Response(
        JSON.stringify({
          data: cachedIpos ?? [],
          isLive: false,
          status: "error",
          message: `Upstream returned status ${response.status}`,
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }

    const payload = await response.json();
    const rawList = Array.isArray(payload) ? payload : payload?.ipos ?? payload?.data ?? [];

    const normalized = rawList.map((item: any, idx: number) => {
      const minPrice = parseFloat(item.price_band_min ?? item.min_price ?? 0) || 0;
      const maxPrice = parseFloat(item.price_band_max ?? item.max_price ?? minPrice) || minPrice;
      const category = (item.category ?? item.type ?? "mainboard").toLowerCase();

      return {
        id: String(item.id ?? item.symbol ?? `ipo_${idx}`).toLowerCase().replace(/[^a-z0-9_-]/g, "_"),
        name: item.company_name ?? item.name ?? "Unknown IPO",
        companyName: item.company_name ?? item.name ?? "Unknown Company",
        symbol: item.symbol ?? "",
        marketType: category.includes("sme") ? "sme" : "mainboard",
        status: (item.status ?? "upcoming").toLowerCase(),
        openDate: item.open_date ?? null,
        closeDate: item.close_date ?? null,
        allotmentDate: item.allotment_date ?? null,
        listingDate: item.listing_date ?? null,
        minPrice,
        maxPrice: maxPrice > 0 ? maxPrice : minPrice,
        lotSize: parseInt(item.lot_size ?? 1, 10) || 1,
        issueSizeCrores: parseFloat(item.issue_size ?? 0) || null,
        freshIssueCrores: parseFloat(item.fresh_issue ?? 0) || null,
        ofsCrores: parseFloat(item.ofs ?? 0) || null,
        gmp: parseFloat(item.gmp ?? 0) || null,
        lastUpdated: new Date().toISOString(),
        isLive: true,
      };
    });

    cachedIpos = normalized;
    cacheExpiry = now + CACHE_TTL_MS;

    return new Response(
      JSON.stringify({
        data: normalized,
        isLive: true,
        cached: false,
        source: "ipo_guru",
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
