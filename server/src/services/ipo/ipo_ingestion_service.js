/**
 * IPO Central Ingestion Service & Quota Governor
 *
 * Responsibilities:
 * 1. Enforces strict Free Tier quota (max 10 requests / day in IST, 1 request / minute).
 * 2. Acquires PostgreSQL advisory lock (7421) to prevent concurrent execution.
 * 3. Fetches external IPO data from IPO Guru Developer API v2 (collection query only, NO slug loops).
 * 4. Normalizes and atomically upserts records into PostgreSQL `ipo_master` and `ipo_gmp_cache`.
 *    - Preserves existing valid cache fields when upstream temporarily omits or returns null.
 *    - Tracks gmp_last_valid_at so 24h preservation window does not reset on repeated null fetches.
 *    - Clears GMP immediately if incoming or current status is 'listed'.
 * 5. Logs all fetch attempts, rate limits, and errors into `ipo_fetch_logs`.
 */

const LOCK_ID = 7421;

class IpoIngestionService {
  constructor({ provider, supabaseClient, pool }) {
    this.provider = provider;
    this.supabaseClient = supabaseClient;
    this.pool = pool; // Optional direct pg Pool for advisory locks
  }

  /**
   * Acquire PostgreSQL advisory lock
   */
  async acquireLock(client) {
    if (!client) return true;
    const res = await client.query("SELECT pg_try_advisory_lock($1) AS locked", [LOCK_ID]);
    return Boolean(res.rows[0]?.locked);
  }

  /**
   * Release PostgreSQL advisory lock
   */
  async releaseLock(client) {
    if (!client) return true;
    const res = await client.query("SELECT pg_advisory_unlock($1) AS unlocked", [LOCK_ID]);
    return Boolean(res.rows[0]?.unlocked);
  }

  /**
   * Evaluate and record API request budget against PostgreSQL function
   */
  async evaluateQuota(clientOrSupabase) {
    if (clientOrSupabase && typeof clientOrSupabase.query === "function") {
      const res = await clientOrSupabase.query("SELECT kith_record_ipo_api_request() AS result");
      return res.rows[0]?.result;
    } else if (this.supabaseClient) {
      const { data, error } = await this.supabaseClient.rpc("kith_record_ipo_api_request");
      if (error) throw error;
      return data;
    }
    throw new Error("No database client available for quota evaluation");
  }

  /**
   * Main Ingestion Execution Routine
   */
  async runIngestion({ dbClient, force = false } = {}) {
    const startTime = Date.now();
    let lockAcquired = false;
    let quotaDecision = null;

    try {
      // 1. Concurrency Protection via Advisory Lock
      if (dbClient) {
        lockAcquired = await this.acquireLock(dbClient);
        if (!lockAcquired) {
          return {
            success: false,
            skipped: true,
            reason: "CONCURRENT_WORKER_ACTIVE",
            message: "Another ingestion process holds advisory lock 7421.",
          };
        }
      }

      // 2. Budget & Rate Limit Governance
      quotaDecision = await this.evaluateQuota(dbClient || this.supabaseClient);
      if (!quotaDecision.allowed && !force) {
        return {
          success: false,
          skipped: true,
          reason: quotaDecision.reason,
          quota: quotaDecision,
          message: `Ingestion aborted: ${quotaDecision.reason}.`,
        };
      }

      // 3. Upstream Fetch (Single Collection Call - No loops!)
      const items = await this.provider.fetchIpos();
      const durationMs = Date.now() - startTime;
      const rateLimitInfo = this.provider.lastRateLimit || {};

      let errorMsg = null;
      if (rateLimitInfo.retryAfter !== null) {
        errorMsg = `[Retry-After: ${rateLimitInfo.retryAfter}s]`;
      }
      if (rateLimitInfo.remaining !== null) {
        errorMsg = (errorMsg ? `${errorMsg} ` : "") + `[Remaining: ${rateLimitInfo.remaining}]`;
      }

      if (!items || !Array.isArray(items) || items.length === 0) {
        const fullErrMsg = (errorMsg ? `${errorMsg} - ` : "") +
          (items === null ? "Upstream provider returned error or null" : "Empty list returned");

        await this.logFetch({
          endpoint: "/api/v2/ipos",
          httpStatus: items === null ? 502 : 204,
          recordCount: 0,
          errorMessage: fullErrMsg,
          durationMs,
          dbClient,
        });

        return {
          success: false,
          recordCount: 0,
          durationMs,
          quota: quotaDecision,
          rateLimit: rateLimitInfo,
          message: "Upstream returned no items to ingest.",
        };
      }

      // 4. Persistence into ipo_master and ipo_gmp_cache with field preservation
      const upsertedCount = await this.persistIpos(items, dbClient);

      // 5. Audit Log Success
      await this.logFetch({
        endpoint: "/api/v2/ipos",
        httpStatus: 200,
        recordCount: upsertedCount,
        errorMessage: errorMsg,
        durationMs,
        dbClient,
      });

      return {
        success: true,
        recordCount: upsertedCount,
        durationMs,
        quota: quotaDecision,
        rateLimit: rateLimitInfo,
        source: "ipo_guru_v2",
      };
    } catch (err) {
      const durationMs = Date.now() - startTime;
      await this.logFetch({
        endpoint: "/api/v2/ipos",
        httpStatus: 500,
        recordCount: 0,
        errorMessage: err.message,
        durationMs,
        dbClient,
      }).catch(() => {});

      throw err;
    } finally {
      if (lockAcquired && dbClient) {
        await this.releaseLock(dbClient).catch(() => {});
      }
    }
  }

  /**
   * Persist normalized items into database with strict preservation rules
   */
  async persistIpos(items, dbClient) {
    if (!items || items.length === 0) return 0;
    const nowIso = new Date().toISOString();
    const expiryIso = new Date(Date.now() + 6 * 60 * 60 * 1000).toISOString(); // 6h TTL

    let count = 0;

    if (dbClient) {
      await dbClient.query("BEGIN");
      try {
        for (const item of items) {
          if (!item.id || !item.name) continue;

          const slug = String(item.slug || item.id).trim();
          const isListed = item.status === "listed";
          let gmpRaw = (item.gmp !== undefined && item.gmp !== null) ? Math.round(Number(item.gmp)) : null;
          if (isListed) {
            gmpRaw = null;
          }
          const gmpLastValidAt = gmpRaw !== null ? nowIso : null;

          // Direct PostgreSQL query with explicit field-specific preservation & gmp_last_valid_at
          await dbClient.query(`
            INSERT INTO ipo_master (
              id, name, company_name, symbol, market_type, status,
              open_date, close_date, allotment_date, listing_date,
              min_price, max_price, lot_size, issue_size_crores,
              gmp, gmp_last_valid_at, slug, source_updated_at, fetched_at, is_stale, last_updated
            ) VALUES (
              $1, $2, $3, $4, $5, $6,
              $7, $8, $9, $10,
              $11, $12, $13, $14,
              $15, $16, $17, $18, $19, false, $19
            )
            ON CONFLICT (id) DO UPDATE SET
              name = COALESCE(NULLIF(EXCLUDED.name, ''), ipo_master.name),
              company_name = COALESCE(NULLIF(EXCLUDED.company_name, ''), ipo_master.company_name),
              symbol = COALESCE(NULLIF(EXCLUDED.symbol, ''), ipo_master.symbol),
              market_type = COALESCE(NULLIF(EXCLUDED.market_type, ''), ipo_master.market_type),
              status = EXCLUDED.status,
              open_date = COALESCE(EXCLUDED.open_date, ipo_master.open_date),
              close_date = COALESCE(EXCLUDED.close_date, ipo_master.close_date),
              allotment_date = COALESCE(EXCLUDED.allotment_date, ipo_master.allotment_date),
              listing_date = COALESCE(EXCLUDED.listing_date, ipo_master.listing_date),
              min_price = CASE WHEN EXCLUDED.min_price > 0 THEN EXCLUDED.min_price ELSE ipo_master.min_price END,
              max_price = CASE WHEN EXCLUDED.max_price > 0 THEN EXCLUDED.max_price ELSE ipo_master.max_price END,
              lot_size = CASE WHEN EXCLUDED.lot_size > 0 THEN EXCLUDED.lot_size ELSE ipo_master.lot_size END,
              issue_size_crores = COALESCE(EXCLUDED.issue_size_crores, ipo_master.issue_size_crores),
              gmp = CASE 
                WHEN EXCLUDED.status = 'listed' OR ipo_master.status = 'listed' THEN NULL
                WHEN EXCLUDED.gmp IS NOT NULL THEN EXCLUDED.gmp
                WHEN ipo_master.gmp_last_valid_at IS NOT NULL AND ipo_master.gmp_last_valid_at > (NOW() - INTERVAL '24 hours') THEN ipo_master.gmp
                ELSE NULL
              END,
              gmp_last_valid_at = CASE
                WHEN EXCLUDED.status = 'listed' OR ipo_master.status = 'listed' THEN NULL
                WHEN EXCLUDED.gmp IS NOT NULL THEN EXCLUDED.gmp_last_valid_at
                WHEN ipo_master.gmp_last_valid_at IS NOT NULL AND ipo_master.gmp_last_valid_at > (NOW() - INTERVAL '24 hours') THEN ipo_master.gmp_last_valid_at
                ELSE NULL
              END,
              slug = COALESCE(NULLIF(EXCLUDED.slug, ''), ipo_master.slug),
              source_updated_at = COALESCE(EXCLUDED.source_updated_at, ipo_master.source_updated_at),
              fetched_at = EXCLUDED.fetched_at,
              is_stale = false,
              last_updated = EXCLUDED.last_updated;
          `, [
            item.id,
            item.name,
            item.companyName || item.name,
            item.symbol || "",
            item.marketType || "mainboard",
            item.status || "upcoming",
            item.openDate || null,
            item.closeDate || null,
            item.allotmentDate || null,
            item.listingDate || null,
            item.minPrice || 0,
            item.maxPrice || 0,
            item.lotSize || 1,
            item.issueSizeCrores || null,
            gmpRaw,
            gmpLastValidAt,
            slug,
            item.lastUpdated || nowIso,
            nowIso,
          ]);

          // Upsert into ipo_gmp_cache with preservation
          await dbClient.query(`
            INSERT INTO ipo_gmp_cache (
              id, ipo_id, slug, ipo_name,
              price_band_min, price_band_max, gmp_raw, gmp_last_valid_at,
              estimated_listing_price, estimated_gain_percentage,
              source_updated_at, fetched_at, expires_at, is_stale, updated_at
            ) VALUES (
              $1, $2, $3, $4,
              $5, $6, $7, $8,
              $9, $10,
              $11, $12, $13, false, $12
            )
            ON CONFLICT (slug) DO UPDATE SET
              ipo_name = COALESCE(NULLIF(EXCLUDED.ipo_name, ''), ipo_gmp_cache.ipo_name),
              price_band_min = CASE WHEN EXCLUDED.price_band_min > 0 THEN EXCLUDED.price_band_min ELSE ipo_gmp_cache.price_band_min END,
              price_band_max = CASE WHEN EXCLUDED.price_band_max > 0 THEN EXCLUDED.price_band_max ELSE ipo_gmp_cache.price_band_max END,
              gmp_raw = CASE 
                WHEN $14 = true OR EXISTS (SELECT 1 FROM ipo_master m WHERE m.id = EXCLUDED.ipo_id AND m.status = 'listed') THEN NULL
                WHEN EXCLUDED.gmp_raw IS NOT NULL THEN EXCLUDED.gmp_raw
                WHEN ipo_gmp_cache.gmp_last_valid_at IS NOT NULL AND ipo_gmp_cache.gmp_last_valid_at > (NOW() - INTERVAL '24 hours') THEN ipo_gmp_cache.gmp_raw
                ELSE NULL
              END,
              gmp_last_valid_at = CASE
                WHEN $14 = true OR EXISTS (SELECT 1 FROM ipo_master m WHERE m.id = EXCLUDED.ipo_id AND m.status = 'listed') THEN NULL
                WHEN EXCLUDED.gmp_raw IS NOT NULL THEN EXCLUDED.gmp_last_valid_at
                WHEN ipo_gmp_cache.gmp_last_valid_at IS NOT NULL AND ipo_gmp_cache.gmp_last_valid_at > (NOW() - INTERVAL '24 hours') THEN ipo_gmp_cache.gmp_last_valid_at
                ELSE NULL
              END,
              estimated_listing_price = CASE
                WHEN $14 = true OR EXISTS (SELECT 1 FROM ipo_master m WHERE m.id = EXCLUDED.ipo_id AND m.status = 'listed') THEN NULL
                WHEN EXCLUDED.gmp_raw IS NOT NULL AND EXCLUDED.price_band_max > 0 THEN (EXCLUDED.price_band_max + EXCLUDED.gmp_raw)
                WHEN ipo_gmp_cache.gmp_last_valid_at IS NOT NULL AND ipo_gmp_cache.gmp_last_valid_at > (NOW() - INTERVAL '24 hours') THEN ipo_gmp_cache.estimated_listing_price
                ELSE NULL
              END,
              estimated_gain_percentage = CASE
                WHEN $14 = true OR EXISTS (SELECT 1 FROM ipo_master m WHERE m.id = EXCLUDED.ipo_id AND m.status = 'listed') THEN NULL
                WHEN EXCLUDED.gmp_raw IS NOT NULL AND EXCLUDED.price_band_max > 0 THEN ROUND(((EXCLUDED.gmp_raw::NUMERIC / EXCLUDED.price_band_max::NUMERIC) * 100), 2)
                WHEN ipo_gmp_cache.gmp_last_valid_at IS NOT NULL AND ipo_gmp_cache.gmp_last_valid_at > (NOW() - INTERVAL '24 hours') THEN ipo_gmp_cache.estimated_gain_percentage
                ELSE NULL
              END,
              source_updated_at = COALESCE(EXCLUDED.source_updated_at, ipo_gmp_cache.source_updated_at),
              fetched_at = EXCLUDED.fetched_at,
              expires_at = EXCLUDED.expires_at,
              is_stale = false,
              updated_at = EXCLUDED.updated_at;
          `, [
            `gmp_${slug}`,
            item.id,
            slug,
            item.name,
            item.minPrice || 0,
            item.maxPrice || 0,
            gmpRaw,
            gmpLastValidAt,
            (gmpRaw !== null && item.maxPrice > 0) ? (item.maxPrice + gmpRaw) : null,
            (gmpRaw !== null && item.maxPrice > 0) ? Number(((gmpRaw / item.maxPrice) * 100).toFixed(2)) : null,
            item.lastUpdated || nowIso,
            nowIso,
            expiryIso,
            isListed,
          ]);

          count++;
        }
        await dbClient.query("COMMIT");
      } catch (txErr) {
        await dbClient.query("ROLLBACK").catch(() => {});
        throw txErr;
      }
    } else if (this.supabaseClient) {
      // 1. Execute atomic PostgreSQL batch upsert RPC if supported
      if (typeof this.supabaseClient.rpc === "function") {
        const { data: batchResult, error: batchErr } = await this.supabaseClient.rpc("kith_upsert_ipo_batch", {
          p_payload: items,
        });
        if (batchErr) {
          throw batchErr;
        }
        return batchResult?.record_count ?? items.length;
      }

      // 2. Sequential fallback if RPC is not available on legacy mock client
      for (const item of items) {
        if (!item.id || !item.name) continue;

        const slug = String(item.slug || item.id).trim();
        const isListed = item.status === "listed";
        let gmpRaw = (item.gmp !== undefined && item.gmp !== null) ? Math.round(Number(item.gmp)) : null;
        if (isListed) {
          gmpRaw = null;
        }

        // Fetch existing to preserve fields
        const { data: existing } = await this.supabaseClient
          .from("ipo_master")
          .select("id, gmp, gmp_last_valid_at, min_price, max_price, lot_size, issue_size_crores, allotment_date, listing_date, fetched_at, status")
          .eq("id", item.id)
          .maybeSingle();

        let effectiveGmp = gmpRaw;
        let effectiveGmpValidAt = gmpRaw !== null ? nowIso : null;

        if (isListed || existing?.status === "listed") {
          // Listed IPOs immediately clear GMP
          effectiveGmp = null;
          effectiveGmpValidAt = null;
        } else if (effectiveGmp === null && existing && existing.gmp !== null && existing.gmp_last_valid_at) {
          // Calculate 24h preservation strictly against gmp_last_valid_at, NOT fetched_at
          const ageMs = Date.now() - new Date(existing.gmp_last_valid_at).getTime();
          if (ageMs < 24 * 60 * 60 * 1000) {
            effectiveGmp = existing.gmp;
            effectiveGmpValidAt = existing.gmp_last_valid_at; // PRESERVE ORIGINAL TIMESTAMP (DO NOT REFRESH!)
          }
        }

        const minP = item.minPrice > 0 ? item.minPrice : (existing?.min_price || 0);
        const maxP = item.maxPrice > 0 ? item.maxPrice : (existing?.max_price || 0);
        const lot = item.lotSize > 0 ? item.lotSize : (existing?.lot_size || 1);

        await this.supabaseClient.from("ipo_master").upsert({
          id: item.id,
          name: item.name,
          company_name: item.companyName || item.name,
          symbol: item.symbol || "",
          market_type: item.marketType || "mainboard",
          status: item.status || "upcoming",
          open_date: item.openDate || existing?.open_date || nowIso,
          close_date: item.closeDate || existing?.close_date || nowIso,
          allotment_date: item.allotmentDate || existing?.allotment_date || null,
          listing_date: item.listingDate || existing?.listing_date || null,
          min_price: minP,
          max_price: maxP,
          lot_size: lot,
          issue_size_crores: item.issueSizeCrores || existing?.issue_size_crores || null,
          gmp: effectiveGmp,
          gmp_last_valid_at: effectiveGmpValidAt,
          slug,
          source_updated_at: item.lastUpdated || nowIso,
          fetched_at: nowIso,
          is_stale: false,
          last_updated: nowIso,
        });

        await this.supabaseClient.from("ipo_gmp_cache").upsert({
          id: `gmp_${slug}`,
          ipo_id: item.id,
          slug,
          ipo_name: item.name,
          price_band_min: minP,
          price_band_max: maxP,
          gmp_raw: effectiveGmp,
          gmp_last_valid_at: effectiveGmpValidAt,
          estimated_listing_price: (effectiveGmp !== null && maxP > 0) ? (maxP + effectiveGmp) : null,
          estimated_gain_percentage: (effectiveGmp !== null && maxP > 0) ? Number(((effectiveGmp / maxP) * 100).toFixed(2)) : null,
          source_updated_at: item.lastUpdated || nowIso,
          fetched_at: nowIso,
          expires_at: expiryIso,
          is_stale: false,
          updated_at: nowIso,
        });

        count++;
      }
    }

    return count;
  }

  /**
   * Log fetch attempt to ipo_fetch_logs
   */
  async logFetch({ endpoint, httpStatus, recordCount = 0, errorMessage = null, durationMs = 0, dbClient }) {
    if (dbClient) {
      await dbClient.query(`
        INSERT INTO ipo_fetch_logs (endpoint, http_status, record_count, error_message, duration_ms)
        VALUES ($1, $2, $3, $4, $5);
      `, [endpoint, httpStatus, recordCount, errorMessage, durationMs]);
    } else if (this.supabaseClient) {
      await this.supabaseClient.from("ipo_fetch_logs").insert({
        endpoint,
        http_status: httpStatus,
        record_count: recordCount,
        error_message: errorMessage,
        duration_ms: durationMs,
      });
    }
  }
}

module.exports = { IpoIngestionService, LOCK_ID };
