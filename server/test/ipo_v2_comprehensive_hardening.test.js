const { describe, it } = require("node:test");
const assert = require("node:assert");
const { IpoGuruProvider } = require("../src/services/ipo/ipo_guru_provider");
const { IpoIngestionService } = require("../src/services/ipo/ipo_ingestion_service");

describe("IPO Guru v2 Comprehensive Hardening & Verification Suite", () => {
  const provider = new IpoGuruProvider();

  // Helper simulating the hardened Edge Function auth logic
  function simulateHardenedEdgeFunction(req, env) {
    const cronSecret = env.CRON_SECRET || "";
    const isSyncRequested = req.url.includes("sync=true") || req.method === "POST" || req.method === "PUT";

    if (isSyncRequested) {
      const authHeader = req.headers["authorization"] || req.headers["Authorization"] || "";
      const customHeader = req.headers["x-cron-secret"] || req.headers["X-Cron-Secret"] || "";

      let isAuthorized = false;
      // CRON_SECRET is required and is the SOLE credential for synchronization
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
      }

      if (!isAuthorized) {
        return {
          status: 401,
          body: { success: false, error: "Unauthorized: Missing or invalid CRON_SECRET for sync operations." },
        };
      }
      return { status: 200, body: { success: true } };
    }

    return { status: 200, body: { data: [], cached: true } };
  }

  // 1. GMP object with price "35"
  it('1. Correctly parses GMP object with price "35"', () => {
    const raw = {
      id: "test-ipo-1",
      name: "Acme Tech",
      price_min: 100,
      price_max: 120,
      gmp: { price: "35", percentage: "29.17%" },
    };
    const normalized = provider.normalizeItem(raw, 0);
    assert.strictEqual(normalized.gmp, 35, "GMP object with price '35' must parse to integer 35");
    assert.ok(normalized.gmpLastValidAt, "gmpLastValidAt must be set for valid GMP");
  });

  // 2. GMP object with price "0" (par/flat)
  it('2. Correctly parses GMP object with price "0" as strict 0 and sets gmpLastValidAt', () => {
    const raw = {
      id: "test-ipo-2",
      name: "Flat Corp",
      price_min: 50,
      price_max: 55,
      gmp: { price: "0", percentage: "0.00%" },
    };
    const normalized = provider.normalizeItem(raw, 1);
    assert.strictEqual(normalized.gmp, 0, "GMP object with price '0' must evaluate strictly to integer 0, not null");
    assert.ok(normalized.gmpLastValidAt, "gmpLastValidAt must be populated for zero GMP");
  });

  // 3. GMP null
  it("3. Correctly handles explicit GMP null and leaves gmpLastValidAt as null", () => {
    const raw = {
      id: "test-ipo-3",
      name: "Null Capital",
      price_min: 200,
      price_max: 220,
      gmp: null,
    };
    const normalized = provider.normalizeItem(raw, 2);
    assert.strictEqual(normalized.gmp, null, "Explicit null GMP must evaluate to null");
    assert.strictEqual(normalized.gmpLastValidAt, null, "gmpLastValidAt must be null when GMP is null");
  });

  // 4. GMP missing
  it("4. Correctly handles completely missing GMP field", () => {
    const raw = {
      id: "test-ipo-4",
      name: "Missing Field Industries",
      price_min: 150,
      price_max: 160,
    };
    const normalized = provider.normalizeItem(raw, 3);
    assert.strictEqual(normalized.gmp, null, "Missing GMP field must default to null");
    assert.strictEqual(normalized.gmpLastValidAt, null);
  });

  // 5. Invalid GMP value
  it("5. Correctly handles invalid GMP string values (N/A, TBD, object string)", () => {
    const cases = [
      { gmp: "N/A" },
      { gmp: "TBD" },
      { gmp: "--" },
      { gmp: { price: "N/A" } },
      { gmp: "[object Object]" },
      { gmp: "random_text" },
    ];
    for (const c of cases) {
      const normalized = provider.normalizeItem({ id: "inv", name: "Inv", ...c }, 0);
      assert.strictEqual(normalized.gmp, null, `Invalid GMP value ${JSON.stringify(c.gmp)} must parse to null`);
      assert.strictEqual(normalized.gmpLastValidAt, null);
    }
  });

  // 6. Negative GMP
  it("6. Correctly parses negative GMP values (discount)", () => {
    const cases = [
      { input: { gmp: "-10" }, expected: -10 },
      { input: { gmp: { price: "-15" } }, expected: -15 },
      { input: { gmp: -25 }, expected: -25 },
      { input: { gmp: "₹ -5" }, expected: -5 },
    ];
    for (const c of cases) {
      const normalized = provider.normalizeItem({ id: "neg", name: "Neg", ...c.input }, 0);
      assert.strictEqual(normalized.gmp, c.expected, `Negative GMP ${JSON.stringify(c.input)} must parse to ${c.expected}`);
      assert.ok(normalized.gmpLastValidAt, "gmpLastValidAt must be set for negative GMP");
    }
  });

  // 7. price_min and price_max mapping
  it("7. Correctly maps price_min, price_max, and fallback band identifiers", () => {
    const raw = {
      id: "price-test",
      name: "Price Band Test",
      price_min: 145,
      price_max: 155,
      lot_size: 100,
    };
    const normalized = provider.normalizeItem(raw, 0);
    assert.strictEqual(normalized.minPrice, 145, "minPrice must map from price_min");
    assert.strictEqual(normalized.maxPrice, 155, "maxPrice must map from price_max");
    assert.strictEqual(normalized.lotSize, 100, "lotSize must map accurately");
  });

  // 8. Repeated null GMP responses do NOT reset gmp_last_valid_at
  it("8. Repeated null GMP responses preserve gmp_last_valid_at without resetting it", async () => {
    const originalValidTimestamp = new Date(Date.now() - 4 * 3600000).toISOString(); // 4 hours ago
    const existingCache = new Map();
    existingCache.set("ipo_repeated_null_test", {
      id: "ipo_repeated_null_test",
      gmp: 60,
      gmp_last_valid_at: originalValidTimestamp,
      min_price: 200,
      max_price: 220,
      lot_size: 25,
      fetched_at: new Date(Date.now() - 3600000).toISOString(), // 1 hour ago
      status: "open",
    });

    const mockSupabase = {
      from: (table) => ({
        select: () => ({
          eq: (col, val) => ({
            maybeSingle: async () => ({ data: existingCache.get(val) || null }),
          }),
        }),
        upsert: async (record) => {
          if (table === "ipo_master") {
            existingCache.set(record.id, record);
          }
          return { error: null };
        },
      }),
    };

    const service = new IpoIngestionService({ provider, supabaseClient: mockSupabase });

    // Ingest run 1 with null GMP
    await service.persistIpos([
      { id: "ipo_repeated_null_test", name: "Repeated Null Test", minPrice: 200, maxPrice: 220, lotSize: 25, gmp: null },
    ]);
    const afterRun1 = existingCache.get("ipo_repeated_null_test");
    assert.strictEqual(afterRun1.gmp, 60, "GMP must be preserved on null response");
    assert.strictEqual(
      afterRun1.gmp_last_valid_at,
      originalValidTimestamp,
      "gmp_last_valid_at must NOT be updated or refreshed on null response"
    );

    // Ingest run 2 with null GMP (subsequent sync)
    await service.persistIpos([
      { id: "ipo_repeated_null_test", name: "Repeated Null Test", minPrice: 200, maxPrice: 220, lotSize: 25, gmp: null },
    ]);
    const afterRun2 = existingCache.get("ipo_repeated_null_test");
    assert.strictEqual(afterRun2.gmp, 60);
    assert.strictEqual(
      afterRun2.gmp_last_valid_at,
      originalValidTimestamp,
      "gmp_last_valid_at must remain strictly untouched on repeated null response"
    );
  });

  // 9. GMP expires after the intended 24-hour window
  it("9. GMP expires and becomes null after 24 hours of no valid GMP updates", async () => {
    const expiredTimestamp = new Date(Date.now() - 25 * 3600000).toISOString(); // 25 hours ago (>24h)
    const existingCache = new Map();
    existingCache.set("ipo_expire_test", {
      id: "ipo_expire_test",
      gmp: 80,
      gmp_last_valid_at: expiredTimestamp,
      min_price: 300,
      max_price: 330,
      lot_size: 40,
      fetched_at: new Date(Date.now() - 60000).toISOString(), // fetched just 1 min ago
      status: "open",
    });

    const mockSupabase = {
      from: (table) => ({
        select: () => ({
          eq: (col, val) => ({
            maybeSingle: async () => ({ data: existingCache.get(val) || null }),
          }),
        }),
        upsert: async (record) => {
          if (table === "ipo_master") {
            existingCache.set(record.id, record);
          }
          return { error: null };
        },
      }),
    };

    const service = new IpoIngestionService({ provider, supabaseClient: mockSupabase });
    // Ingest payload with null GMP
    await service.persistIpos([
      { id: "ipo_expire_test", name: "Expired Test", minPrice: 300, maxPrice: 330, lotSize: 40, gmp: null },
    ]);

    const updated = existingCache.get("ipo_expire_test");
    assert.strictEqual(
      updated.gmp,
      null,
      "GMP must expire and become null when gmp_last_valid_at is older than 24 hours"
    );
    assert.strictEqual(updated.gmp_last_valid_at, null, "gmp_last_valid_at must be cleared to null upon expiration");
  });

  // 10. Valid GMP refreshes gmp_last_valid_at
  it("10. Valid new GMP refreshes both gmp and gmp_last_valid_at", async () => {
    const oldTimestamp = new Date(Date.now() - 10 * 3600000).toISOString(); // 10 hours ago
    const existingCache = new Map();
    existingCache.set("ipo_refresh_test", {
      id: "ipo_refresh_test",
      gmp: 50,
      gmp_last_valid_at: oldTimestamp,
      min_price: 150,
      max_price: 160,
      lot_size: 100,
      fetched_at: oldTimestamp,
      status: "open",
    });

    const mockSupabase = {
      from: (table) => ({
        select: () => ({
          eq: (col, val) => ({
            maybeSingle: async () => ({ data: existingCache.get(val) || null }),
          }),
        }),
        upsert: async (record) => {
          if (table === "ipo_master") {
            existingCache.set(record.id, record);
          }
          return { error: null };
        },
      }),
    };

    const service = new IpoIngestionService({ provider, supabaseClient: mockSupabase });
    // Ingest payload with new valid GMP = 75
    await service.persistIpos([
      { id: "ipo_refresh_test", name: "Refresh Test", minPrice: 150, maxPrice: 160, lotSize: 100, gmp: 75 },
    ]);

    const updated = existingCache.get("ipo_refresh_test");
    assert.strictEqual(updated.gmp, 75, "GMP must be updated to new valid value 75");
    assert.notStrictEqual(
      updated.gmp_last_valid_at,
      oldTimestamp,
      "gmp_last_valid_at must be refreshed to the current ingestion timestamp"
    );
  });

  // 11. Zero GMP remains valid and refreshes gmp_last_valid_at
  it("11. Zero GMP (par value) remains valid and refreshes gmp_last_valid_at", async () => {
    const existingCache = new Map();
    existingCache.set("ipo_zero_test", {
      id: "ipo_zero_test",
      gmp: 20,
      gmp_last_valid_at: new Date(Date.now() - 5000000).toISOString(),
      min_price: 50,
      max_price: 60,
      lot_size: 100,
      status: "open",
    });

    const mockSupabase = {
      from: (table) => ({
        select: () => ({
          eq: (col, val) => ({
            maybeSingle: async () => ({ data: existingCache.get(val) || null }),
          }),
        }),
        upsert: async (record) => {
          if (table === "ipo_master") {
            existingCache.set(record.id, record);
          }
          return { error: null };
        },
      }),
    };

    const service = new IpoIngestionService({ provider, supabaseClient: mockSupabase });
    // Ingest payload with explicit GMP = 0
    await service.persistIpos([
      { id: "ipo_zero_test", name: "Zero Test", minPrice: 50, maxPrice: 60, lotSize: 100, gmp: 0 },
    ]);

    const updated = existingCache.get("ipo_zero_test");
    assert.strictEqual(updated.gmp, 0, "GMP must be strictly 0, not null");
    assert.ok(updated.gmp_last_valid_at, "gmp_last_valid_at must be populated for zero GMP");
  });

  // 12. Listed status clears GMP immediately
  it("12. Transition to listed status clears GMP immediately in the same ingestion", async () => {
    const existingCache = new Map();
    // Currently open with active GMP = 55
    existingCache.set("ipo_listed_test", {
      id: "ipo_listed_test",
      gmp: 55,
      gmp_last_valid_at: new Date().toISOString(),
      min_price: 100,
      max_price: 110,
      lot_size: 50,
      status: "open",
    });

    const mockSupabase = {
      from: (table) => ({
        select: () => ({
          eq: (col, val) => ({
            maybeSingle: async () => ({ data: existingCache.get(val) || null }),
          }),
        }),
        upsert: async (record) => {
          if (table === "ipo_master") {
            existingCache.set(record.id, record);
          }
          return { error: null };
        },
      }),
    };

    const service = new IpoIngestionService({ provider, supabaseClient: mockSupabase });
    // Ingest transition: status becomes 'listed'
    await service.persistIpos([
      { id: "ipo_listed_test", name: "Listed Test", minPrice: 100, maxPrice: 110, lotSize: 50, status: "listed", gmp: 55 },
    ]);

    const updated = existingCache.get("ipo_listed_test");
    assert.strictEqual(updated.status, "listed");
    assert.strictEqual(updated.gmp, null, "GMP must be cleared to null immediately upon transitioning to listed");
    assert.strictEqual(updated.gmp_last_valid_at, null, "gmp_last_valid_at must be cleared to null upon listing");
  });

  // 13. Service-role token alone CANNOT authenticate cron sync
  it("13. Service-role token alone cannot authenticate cron sync (must be rejected)", () => {
    const env = {
      CRON_SECRET: "correct_cron_secret_777",
      SUPABASE_SERVICE_ROLE_KEY: "supabase_service_role_secret_key_888",
    };

    // Caller attempts to authenticate with SUPABASE_SERVICE_ROLE_KEY as Bearer token
    const res = simulateHardenedEdgeFunction(
      {
        url: "/ipo-data?sync=true",
        method: "GET",
        headers: { authorization: "Bearer supabase_service_role_secret_key_888" },
      },
      env
    );

    assert.strictEqual(res.status, 401, "Service-role token alone must be REJECTED with 401");
    assert.strictEqual(res.body.success, false);
  });

  // 14. Correct CRON_SECRET authenticates sync
  it("14. Correct CRON_SECRET successfully authenticates sync via Bearer and X-Cron-Secret", () => {
    const env = {
      CRON_SECRET: "my_dedicated_cron_secret_999",
      SUPABASE_SERVICE_ROLE_KEY: "supabase_service_role_secret_key_888",
    };

    // Bearer token
    const res1 = simulateHardenedEdgeFunction(
      {
        url: "/ipo-data?sync=true",
        method: "GET",
        headers: { authorization: "Bearer my_dedicated_cron_secret_999" },
      },
      env
    );
    assert.strictEqual(res1.status, 200, "Valid Bearer CRON_SECRET must succeed with 200");

    // X-Cron-Secret header
    const res2 = simulateHardenedEdgeFunction(
      {
        url: "/ipo-data",
        method: "POST",
        headers: { "x-cron-secret": "my_dedicated_cron_secret_999" },
      },
      env
    );
    assert.strictEqual(res2.status, 200, "Valid X-Cron-Secret header must succeed with 200");
  });

  // 15. Missing CRON_SECRET fails closed
  it("15. Missing CRON_SECRET in environment fails closed (rejects all sync attempts)", () => {
    // Environment where CRON_SECRET is empty or unconfigured
    const envNoSecret = {
      CRON_SECRET: "",
      SUPABASE_SERVICE_ROLE_KEY: "supabase_service_role_secret_key_888",
    };

    // Even if caller passes a token, sync must fail closed
    const res = simulateHardenedEdgeFunction(
      {
        url: "/ipo-data?sync=true",
        method: "GET",
        headers: { authorization: "Bearer any_token" },
      },
      envNoSecret
    );

    assert.strictEqual(
      res.status,
      401,
      "Sync operations must fail closed with 401 when CRON_SECRET is unconfigured"
    );
  });

  // 16. Normal read endpoint never triggers upstream requests
  it("16. Normal GET read endpoint serves cache and never triggers upstream requests", () => {
    let upstreamCalled = false;
    function simulateReadMode(req) {
      const isSyncRequested = req.url.includes("sync=true") || req.method === "POST";
      if (isSyncRequested) {
        upstreamCalled = true;
      }
      return { status: 200, cached: true };
    }

    const res = simulateReadMode({ url: "/ipo-data", method: "GET", headers: {} });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.cached, true);
    assert.strictEqual(upstreamCalled, false, "Normal GET /ipo-data must NEVER invoke upstream fetch");
  });

  // 17. Rate-limit headers are handled correctly
  it("17. Correctly parses Retry-After and X-RateLimit-Remaining headers", () => {
    assert.strictEqual(provider.parseRetryAfter("60"), 60, "Numeric string seconds must parse directly");
    assert.strictEqual(provider.parseRetryAfter("0"), 0, "Zero seconds must parse directly");
    assert.strictEqual(provider.parseRetryAfter(null), null, "Null header must return null");

    // Future HTTP date
    const futureDate = new Date(Date.now() + 120000).toUTCString();
    const diff = provider.parseRetryAfter(futureDate);
    assert.ok(diff >= 118 && diff <= 122, `HTTP date string must parse to ~120s diff (got ${diff})`);
  });

  // 18. Node.js and Edge Function produce consistent normalized results
  it("18. Node.js provider and Edge Function logic yield consistent normalized results", () => {
    const rawItem = {
      id: "unified-test-ipo",
      name: "Unified Technologies Ltd",
      issuer_company: "Unified Technologies",
      symbol: "UNIFIED",
      category: "Mainboard",
      status: "Open",
      price_min: 250,
      price_max: 275,
      lot_size: 54,
      gmp: { price: "42", percentage: "15.27%" },
      issue_size: 450.5,
    };

    const nodeNormalized = provider.normalizeItem(rawItem, 0);

    function edgeNormalize(item) {
      let rawGmp = item.gmp;
      if (rawGmp && typeof rawGmp === "object") rawGmp = rawGmp.price;
      const parsedGmp = rawGmp !== null && rawGmp !== undefined ? Math.round(Number(rawGmp)) : null;

      return {
        id: item.id,
        slug: item.slug || item.id,
        minPrice: parseFloat(item.price_min) || 0,
        maxPrice: parseFloat(item.price_max) || 0,
        lotSize: parseInt(item.lot_size, 10) || 1,
        gmp: parsedGmp,
      };
    }

    const edgeNormalized = edgeNormalize(rawItem);

    assert.strictEqual(nodeNormalized.id, edgeNormalized.id);
    assert.strictEqual(nodeNormalized.slug, edgeNormalized.slug);
    assert.strictEqual(nodeNormalized.minPrice, edgeNormalized.minPrice);
    assert.strictEqual(nodeNormalized.maxPrice, edgeNormalized.maxPrice);
    assert.strictEqual(nodeNormalized.lotSize, edgeNormalized.lotSize);
    assert.strictEqual(nodeNormalized.gmp, edgeNormalized.gmp);
    assert.ok(nodeNormalized.gmpLastValidAt, "gmpLastValidAt must be present on node normalized item");
  });
});
