/**
 * Supabase Edge Function: ipo-data
 *
 * Centralized Ingestion Worker & Cached Market Feed Provider for IPO Guru v2
 *
 * Architecture:
 * 1. Read Mode (Default): Serves cached database rows directly from PostgreSQL (`ipo_master` & `ipo_gmp_cache`).
 *    Clients NEVER trigger upstream external API requests.
 * 2. Ingestion Sync Mode (Cron or Admin POST /?sync=true):
 *    - Strictly requires CRON_SECRET authorization.
 *    - SUPABASE_SERVICE_ROLE_KEY is kept internal and NOT accepted as an external caller token.
 *    - If CRON_SECRET is unconfigured, sync fails closed (HTTP 401).
 *    - Unauthenticated sync requests are rejected with HTTP 401.
 *    - Strictly checks quota budget (max 10 requests / day in IST, 1 request / minute).
 *    - Calls upstream IPO Guru Developer API v2 (collection GET /api/v2/ipos).
 *    - Tracks gmp_last_valid_at; 24h preservation window does not reset on repeated null fetches.
 *    - Clears GMP immediately if incoming or current status is 'listed'.
 *    - Records audit log in `ipo_fetch_logs` and updates `ipo_api_usage`.
 */

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
};

/**
 * Extracts and normalizes GMP values across various v2 payload shapes:
 * - Nested object: { price: "35" }, { price: 0 }
 * - Direct number: 35, 0, -10
 * - Formatted strings: "₹35", "-10", "₹ -15", "0"
 * - Invalid/null: null, "N/A", "TBD", "--", undefined -> null
 */
export function extractGmp(item: any): number | null {
  if (!item) return null;

  let raw = item.gmp;
  if (raw !== null && typeof raw === "object") {
    raw = raw.price ?? raw.gmp ?? raw.current_gmp ?? null;
  }
  if (raw === undefined || raw === null) {
    raw = item.grey_market_premium ?? item.current_gmp ?? item.gmp_raw;
  }
  if (raw === undefined || raw === null) return null;

  if (typeof raw === "number") {
    return isNaN(raw) ? null : Math.round(raw);
  }

  const str = String(raw).trim();
  if (
    !str ||
    str.toLowerCase() === "null" ||
    str.toLowerCase() === "n/a" ||
    str.toLowerCase() === "tbd" ||
    str === "--" ||
    str.toLowerCase() === "[object object]"
  ) {
    return null;
  }

  const clean = str.replace(/[₹\s,]/g, "");
  const match = clean.match(/^([+-]?\d+(?:\.\d+)?)/);
  if (!match) return null;

  const parsed = parseFloat(match[1]);
  return isNaN(parsed) ? null : Math.round(parsed);
}

const MONTH_MAP: Record<string, number> = {
  jan: 1, january: 1,
  feb: 2, february: 2,
  mar: 3, march: 3,
  apr: 4, april: 4,
  may: 5,
  jun: 6, june: 6,
  jul: 7, july: 7,
  aug: 8, august: 8,
  sep: 9, sept: 9, september: 9,
  oct: 10, october: 10,
  nov: 11, november: 11,
  dec: 12, december: 12,
};

export function normalizeDateStr(raw: any): string | null {
  if (!raw) return null;
  const str = String(raw).trim();
  if (!str || str.toLowerCase() === "null" || str.toLowerCase() === "tbd") return null;

  // 1. YYYY-MM-DD
  const ymd = str.match(/^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})/);
  if (ymd) {
    const y = ymd[1];
    const m = String(parseInt(ymd[2], 10)).padStart(2, "0");
    const d = String(parseInt(ymd[3], 10)).padStart(2, "0");
    return `${y}-${m}-${d}`;
  }

  // 2. DD-MonthName-YYYY
  const dmyAlpha = str.match(/^(\d{1,2})[- \/.]([A-Za-z]+)(?:[- \/.](\d{2,4}))?/);
  if (dmyAlpha) {
    const d = String(parseInt(dmyAlpha[1], 10)).padStart(2, "0");
    const mNum = MONTH_MAP[dmyAlpha[2].toLowerCase()] ?? 1;
    const m = String(mNum).padStart(2, "0");
    let y = new Date().getFullYear();
    if (dmyAlpha[3]) {
      const parsedYear = parseInt(dmyAlpha[3], 10);
      y = parsedYear < 100 ? (2000 + parsedYear) : parsedYear;
    }
    return `${y}-${m}-${d}`;
  }

  // 3. MonthName DD, YYYY
  const mdyAlpha = str.match(/^([A-Za-z]+)[- \/.](\d{1,2})(?:,?\s*(\d{2,4}))?/);
  if (mdyAlpha) {
    const mNum = MONTH_MAP[mdyAlpha[1].toLowerCase()] ?? 1;
    const m = String(mNum).padStart(2, "0");
    const d = String(parseInt(mdyAlpha[2], 10)).padStart(2, "0");
    let y = new Date().getFullYear();
    if (mdyAlpha[3]) {
      const parsedYear = parseInt(mdyAlpha[3], 10);
      y = parsedYear < 100 ? (2000 + parsedYear) : parsedYear;
    }
    return `${y}-${m}-${d}`;
  }

  // 4. DD-MM-YYYY or DD/MM/YYYY
  const dmy = str.match(/^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})/);
  if (dmy) {
    const d = String(parseInt(dmy[1], 10)).padStart(2, "0");
    const m = String(parseInt(dmy[2], 10)).padStart(2, "0");
    const parsedYear = parseInt(dmy[3], 10);
    const y = parsedYear < 100 ? (2000 + parsedYear) : parsedYear;
    return `${y}-${m}-${d}`;
  }

  return str;
}

function getTodayIstString(): string {
  const now = new Date();
  const utc = now.getTime() + (now.getTimezoneOffset() * 60000);
  const ist = new Date(utc + (330 * 60000));
  const y = ist.getFullYear();
  const m = String(ist.getMonth() + 1).padStart(2, "0");
  const d = String(ist.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

/**
 * Normalizes an IPO Guru v2 response item into canonical database representation.
 */
export function normalizeIpo(item: any, idx: number) {
  const rawId = (item.id && String(item.id).trim()) || (item.slug && String(item.slug).trim()) || (item.symbol && String(item.symbol).trim()) || `ipo_${idx}`;
  const id = String(rawId).toLowerCase().replace(/[^a-z0-9_-]/g, "_");
  const slug = (item.slug && String(item.slug).trim()) ? String(item.slug).trim() : id;
  const name = item.name ?? item.company_name ?? item.ipo_name ?? "Unknown IPO";
  const companyName = item.company_name ?? item.issuer ?? name;
  const symbol = item.symbol ?? item.ticker ?? item.nse_code ?? item.bse_code ?? "";
  const category = (item.category ?? item.market_type ?? item.type ?? "mainboard").toLowerCase();
  const marketType = category.includes("sme") ? "sme" : "mainboard";

  const openDate = normalizeDateStr(item.open_date ?? item.openDate ?? null);
  const closeDate = normalizeDateStr(item.close_date ?? item.closeDate ?? null);
  const allotmentDate = normalizeDateStr(item.allotment_date ?? item.allotmentDate ?? null);
  const listingDate = normalizeDateStr(item.listing_date ?? item.listingDate ?? null);

  const todayIst = getTodayIstString();
  const statusStr = (item.status ?? item.ipo_status ?? "upcoming").toLowerCase();
  let status = "upcoming";
  if (statusStr.includes("list") || statusStr.includes("trad")) {
    status = "listed";
  } else if (listingDate && todayIst >= listingDate) {
    status = "listed";
  } else if (statusStr.includes("allot") || statusStr.includes("out") || statusStr.includes("basis")) {
    status = "allotmentOut";
  } else if (allotmentDate && closeDate && todayIst >= allotmentDate && todayIst > closeDate) {
    status = "allotmentOut";
  } else if (closeDate && todayIst > closeDate) {
    status = "closed";
  } else if (openDate && todayIst < openDate) {
    status = "upcoming";
  } else if (openDate && closeDate && todayIst >= openDate && todayIst <= closeDate) {
    status = "open";
  } else if (statusStr.includes("open") || statusStr.includes("active") || statusStr.includes("live")) {
    status = "open";
  } else if (statusStr.includes("closed") || statusStr.includes("ended")) {
    status = "closed";
  }

  const minPrice =
    parseFloat(item.price_min ?? item.price_band_min ?? item.min_price ?? item.floor_price ?? 0) || 0;
  const maxPrice =
    parseFloat(item.price_max ?? item.price_band_max ?? item.max_price ?? item.cap_price ?? minPrice) ||
    minPrice;

  let lotSize = 1;
  const rawLot = item.lot_size ?? item.lotSize ?? item.market_lot;
  if (typeof rawLot === "number") {
    lotSize = rawLot;
  } else if (typeof rawLot === "string") {
    const digits = rawLot.replace(/[^0-9]/g, "");
    lotSize = parseInt(digits, 10) || 1;
  }

  const issueSizeCrores = parseFloat(item.issue_size ?? item.total_issue_size_cr ?? 0) || null;
  const freshIssueCrores = parseFloat(item.fresh_issue ?? item.fresh_issue_cr ?? 0) || null;
  const ofsCrores = parseFloat(item.ofs ?? item.offer_for_sale_cr ?? 0) || null;

  const gmpRaw = extractGmp(item);
  const nowIso = new Date().toISOString();
  const sourceUpdatedAt =
    item.updated_at ?? item.source_updated_at ?? item.last_updated ?? item.gmp?.updated_at_label ?? nowIso;
  const gmpLastValidAt = gmpRaw !== null ? nowIso : null;

  return {
    id,
    slug,
    name,
    company_name: companyName,
    symbol,
    market_type: marketType,
    status,
    open_date: openDate,
    close_date: closeDate,
    allotment_date: allotmentDate,
    listing_date: listingDate,
    min_price: minPrice,
    max_price: maxPrice > 0 ? maxPrice : minPrice,
    lot_size: lotSize > 0 ? lotSize : 1,
    issue_size_crores: issueSizeCrores,
    fresh_issue_crores: freshIssueCrores,
    ofs_crores: ofsCrores,
    gmp: gmpRaw,
    gmp_last_valid_at: gmpLastValidAt,
    source_updated_at: sourceUpdatedAt,
    fetched_at: nowIso,
    is_stale: false,
    last_updated: nowIso,
  };
}

async function performUpstreamIngestion(supabase: any, apiKey: string) {
  const startTime = Date.now();

  // 1. Quota Check via atomic database RPC function
  const { data: quota, error: quotaErr } = await supabase.rpc("kith_record_ipo_api_request");
  if (quotaErr) {
    throw new Error(`Quota evaluation failed: ${quotaErr.message}`);
  }

  if (!quota?.allowed) {
    return {
      success: false,
      skipped: true,
      reason: quota?.reason,
      quota,
      message: `Ingestion skipped by rate limiter: ${quota?.reason}.`,
    };
  }

  // 2. Fetch from IPO Guru Developer API v2 (collection query only - ZERO loops!)
  let rawList: any[] = [];
  let httpStatus = 200;
  let fetchError: string | null = null;
  let retryAfterSecs: number | null = null;
  let rateLimitRemaining: number | null = null;

  try {
    const res = await fetch("https://www.ipoguru.in/api/v2/ipos", {
      method: "GET",
      headers: {
        "X-API-KEY": apiKey,
        Accept: "application/json",
        "User-Agent": "Kith-Ingestion-Worker/2.0",
      },
    });

    httpStatus = res.status;

    // Parse rate limit headers
    const retryHeader = res.headers.get("retry-after") || res.headers.get("Retry-After");
    if (retryHeader) {
      const parsedSec = parseInt(retryHeader, 10);
      if (!isNaN(parsedSec)) {
        retryAfterSecs = parsedSec;
      } else {
        const dateMs = Date.parse(retryHeader);
        if (!isNaN(dateMs)) {
          retryAfterSecs = Math.max(0, Math.ceil((dateMs - Date.now()) / 1000));
        }
      }
    }

    const remainingHeader =
      res.headers.get("x-ratelimit-remaining") || res.headers.get("X-RateLimit-Remaining");
    if (remainingHeader) {
      const parsedRem = parseInt(remainingHeader, 10);
      if (!isNaN(parsedRem)) {
        rateLimitRemaining = parsedRem;
      }
    }

    if (!res.ok) {
      throw new Error(`HTTP ${res.status}: ${res.statusText}`);
    }

    const json = await res.json();
    rawList = Array.isArray(json) ? json : json?.ipos ?? json?.data ?? [];
  } catch (err: any) {
    fetchError = err.message;
  }

  const durationMs = Date.now() - startTime;

  // Log fetch audit
  const errorLogMsg = fetchError
    ? `${fetchError}${retryAfterSecs !== null ? ` [Retry-After: ${retryAfterSecs}s]` : ""}${
        rateLimitRemaining !== null ? ` [Remaining: ${rateLimitRemaining}]` : ""
      }`
    : null;

  await supabase.from("ipo_fetch_logs").insert({
    endpoint: "/api/v2/ipos",
    http_status: httpStatus,
    record_count: rawList.length,
    error_message: errorLogMsg,
    duration_ms: durationMs,
  });

  if (fetchError || rawList.length === 0) {
    return {
      success: false,
      error: fetchError || "Empty list returned from upstream API",
      quota,
      durationMs,
      retryAfterSecs,
      rateLimitRemaining,
    };
  }

  // 3. Atomic Dual-Table Batch Upsert via PostgreSQL RPC (kith_upsert_ipo_batch)
  const normalized = rawList.map((item: any, idx: number) => normalizeIpo(item, idx));
  const { data: batchResult, error: batchErr } = await supabase.rpc("kith_upsert_ipo_batch", {
    p_payload: normalized,
  });
  if (batchErr) {
    throw new Error(`Failed to atomically upsert IPO batch: ${batchErr.message}`);
  }

  return {
    success: true,
    recordCount: batchResult?.record_count ?? normalized.length,
    quota,
    durationMs,
    retryAfterSecs,
    rateLimitRemaining,
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  const cronSecret = Deno.env.get("CRON_SECRET") || "";
  const apiKey = Deno.env.get("IPO_GURU_API_KEY") || "";

  const supabase = createClient(supabaseUrl, serviceKey);
  const url = new URL(req.url);
  const isSyncRequested = url.searchParams.get("sync") === "true" || req.method === "POST" || req.method === "PUT";

  try {
    // 1. SYNC MODE: Privileged ingestion worker. STRICTLY gated by CRON_SECRET exclusively.
    // SUPABASE_SERVICE_ROLE_KEY is NEVER accepted as an external caller credential.
    if (isSyncRequested) {
      const authHeader = req.headers.get("authorization") || req.headers.get("Authorization") || "";
      const customHeader = req.headers.get("x-cron-secret") || req.headers.get("X-Cron-Secret") || "";

      let isAuthorized = false;
      if (cronSecret) {
        if (authHeader.startsWith("Bearer ")) {
          const token = authHeader.slice(7).trim();
          if (token === cronSecret) {
            isAuthorized = true;
          }
        }
        if (customHeader && customHeader === cronSecret) {
          isAuthorized = true;
        }
      } else {
        // Missing CRON_SECRET in environment fails closed!
        console.error("[ipo-data] CRON_SECRET is not configured in environment. Failing closed.");
      }

      if (!isAuthorized) {
        return new Response(
          JSON.stringify({
            success: false,
            error: "Unauthorized: Missing or invalid CRON_SECRET for sync operations.",
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 401 }
        );
      }

      if (!apiKey || apiKey === "your_ipo_guru_api_key_here") {
        return new Response(
          JSON.stringify({
            success: false,
            error: "IPO_GURU_API_KEY is not configured in Supabase secrets.",
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 503 }
        );
      }

      const syncResult = await performUpstreamIngestion(supabase, apiKey);
      return new Response(
        JSON.stringify(syncResult),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    // 2. READ MODE: Serve cached database rows directly to public clients (ZERO external calls)
    const { data: ipoRows, error: dbErr } = await supabase
      .from("ipo_master")
      .select("*, ipo_gmp_cache(*)")
      .order("open_date", { ascending: false });

    if (dbErr) {
      console.error("[ipo-data] Cache read error:", dbErr.message);
      return new Response(
        JSON.stringify({ error: "Failed to read cached IPO data.", data: [] }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
      );
    }

    return new Response(
      JSON.stringify({
        data: ipoRows || [],
        source: "ipo_guru_v2_cache",
        attribution: {
          text: "Data by IPO Guru",
          url: "https://www.ipoguru.in/",
          disclaimer:
            "Grey Market Premium (GMP) is indicative, unofficial, and intended solely for tracking. Not financial advice.",
        },
        cached: true,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
    );
  } catch (err: any) {
    console.error("[ipo-data] Unhandled execution error:", err.message);
    return new Response(
      JSON.stringify({ error: "An unexpected error occurred while processing the market data.", data: [] }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
    );
  }
});
