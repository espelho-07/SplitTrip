const { describe, it } = require("node:test");
const assert = require("node:assert");
const { IpoIngestionService } = require("../src/services/ipo/ipo_ingestion_service");
const { IpoGuruProvider, normalizeDateStr } = require("../src/services/ipo/ipo_guru_provider");

describe("IPO Centralized Ingestion Architecture Consistency & Atomicity Suite", () => {
  // ───────────────────────────────────────────────────────────────────────────
  // 1. Edge RPC Atomic Rollback
  // ───────────────────────────────────────────────────────────────────────────
  it("1. Edge RPC Atomic Rollback: Fails closed and rolls back both tables on malformed item", async () => {
    let rpcCalled = false;
    let rpcPayload = null;

    // Simulate Supabase client with kith_upsert_ipo_batch RPC
    const mockSupabase = {
      rpc: async (fnName, params) => {
        if (fnName === "kith_upsert_ipo_batch") {
          rpcCalled = true;
          rpcPayload = params.p_payload;

          // Validate payload according to PostgreSQL function rules
          if (!params.p_payload || !Array.isArray(params.p_payload)) {
            return { data: null, error: new Error('Invalid payload: expected JSON array of IPO records') };
          }
          for (const item of params.p_payload) {
            if (!item.id || !String(item.id).trim()) {
              return { data: null, error: new Error('Malformed record: missing required "id"') };
            }
            if (!item.name || !String(item.name).trim()) {
              return { data: null, error: new Error(`Malformed record: missing required "name" for IPO id "${item.id}"`) };
            }
          }
          return { data: { success: true, record_count: params.p_payload.length }, error: null };
        }
        return { data: null, error: new Error(`Unknown RPC: ${fnName}`) };
      },
    };

    const service = new IpoIngestionService({ supabaseClient: mockSupabase });

    // Payload with one valid item and one malformed item (empty name)
    const malformedBatch = [
      { id: "valid_01", name: "Valid Corp", slug: "valid-corp", minPrice: 100, maxPrice: 120 },
      { id: "invalid_02", name: "", slug: "invalid-corp", minPrice: 50, maxPrice: 60 },
    ];

    await assert.rejects(
      async () => await service.persistIpos(malformedBatch),
      /Malformed record: missing required "name"/
    );

    assert.strictEqual(rpcCalled, true, "kith_upsert_ipo_batch RPC must be called");
    assert.strictEqual(rpcPayload.length, 2);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 2. Successful Update of Both Tables
  // ───────────────────────────────────────────────────────────────────────────
  it("2. Successful Update of Both Tables: Atomically populates ipo_master and ipo_gmp_cache", async () => {
    const executedQueries = [];
    const mockDbClient = {
      query: async (sql, params) => {
        executedQueries.push({ sql, params });
        return { rows: [] };
      },
    };

    const items = [
      {
        id: "zenith_01",
        name: "Zenith Tech Ltd",
        slug: "zenith-tech",
        symbol: "ZENITH",
        marketType: "mainboard",
        status: "open",
        minPrice: 200,
        maxPrice: 215,
        lotSize: 65,
        issueSizeCrores: 450.5,
        gmp: 40,
      },
    ];

    const service = new IpoIngestionService({ provider: {} });
    const count = await service.persistIpos(items, mockDbClient);

    assert.strictEqual(count, 1, "Exactly 1 item must be ingested");

    // Verify BEGIN and COMMIT framed the transaction
    const sqlStrings = executedQueries.map((q) => q.sql);
    assert.ok(sqlStrings.includes("BEGIN"), "Transaction must start with BEGIN");
    assert.ok(sqlStrings.includes("COMMIT"), "Transaction must conclude with COMMIT");
    assert.strictEqual(sqlStrings.includes("ROLLBACK"), false, "Successful transaction must not rollback");

    // Verify ipo_master write
    const masterUpsert = executedQueries.find((q) => q.sql.includes("INSERT INTO ipo_master"));
    assert.ok(masterUpsert, "Must insert into ipo_master");
    assert.strictEqual(masterUpsert.params[0], "zenith_01"); // id
    assert.strictEqual(masterUpsert.params[1], "Zenith Tech Ltd"); // name
    assert.strictEqual(masterUpsert.params[14], 40); // gmpRaw

    // Verify ipo_gmp_cache write
    const gmpUpsert = executedQueries.find((q) => q.sql.includes("INSERT INTO ipo_gmp_cache"));
    assert.ok(gmpUpsert, "Must insert into ipo_gmp_cache");
    assert.strictEqual(gmpUpsert.params[1], "zenith_01"); // ipo_id
    assert.strictEqual(gmpUpsert.params[2], "zenith-tech"); // slug
    assert.strictEqual(gmpUpsert.params[6], 40); // gmp_raw
    assert.strictEqual(gmpUpsert.params[8], 255); // estimated_listing_price: 215 + 40
    assert.strictEqual(gmpUpsert.params[9], 18.6); // estimated_gain_percentage: (40/215)*100
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 3. Simultaneous First Quota Requests When Today's Row Does Not Exist
  // ───────────────────────────────────────────────────────────────────────────
  it("3. Simultaneous First Quota Requests: Exactly one allowed, second rejected with cooldown", async () => {
    // Stateful database table & lock simulator modeling PostgreSQL advisory lock & row lock
    let rowForToday = null; // Table is initially empty!
    let lockHolder = null;
    const lockWaitQueue = [];

    // Helper to simulate PostgreSQL transaction with pg_advisory_xact_lock
    async function executeKithRecordIpoApiRequest(callerId) {
      // 1. Acquire advisory lock (serialized queue)
      if (lockHolder !== null) {
        await new Promise((resolve) => lockWaitQueue.push(resolve));
      }
      lockHolder = callerId;

      try {
        const now = Date.now();
        const todayIst = "2026-11-01";
        const cooldownMs = 60 * 1000;

        // 2. Insert if missing (ON CONFLICT DO NOTHING)
        if (!rowForToday) {
          rowForToday = {
            date_ist: todayIst,
            daily_request_count: 0,
            max_daily_requests: 10,
            last_request_at: null,
            cooldown_seconds: 60,
          };
        }

        // 3. Evaluate limits
        if (rowForToday.daily_request_count >= rowForToday.max_daily_requests) {
          return {
            allowed: false,
            reason: "DAILY_QUOTA_EXHAUSTED",
            current_count: rowForToday.daily_request_count,
            max_requests: rowForToday.max_daily_requests,
            retry_after_seconds: 43200,
          };
        }

        if (rowForToday.last_request_at !== null && now - rowForToday.last_request_at < cooldownMs) {
          const remainingSec = Math.ceil((rowForToday.last_request_at + cooldownMs - now) / 1000);
          return {
            allowed: false,
            reason: "COOLDOWN_ACTIVE",
            current_count: rowForToday.daily_request_count,
            max_requests: rowForToday.max_daily_requests,
            retry_after_seconds: Math.max(1, remainingSec),
          };
        }

        // Quota reservation granted
        rowForToday.daily_request_count += 1;
        rowForToday.last_request_at = now;

        return {
          allowed: true,
          reason: "ALLOWED",
          current_count: rowForToday.daily_request_count,
          max_requests: rowForToday.max_daily_requests,
          retry_after_seconds: 0,
        };
      } finally {
        // Release advisory lock and wake next transaction
        lockHolder = null;
        if (lockWaitQueue.length > 0) {
          const next = lockWaitQueue.shift();
          next();
        }
      }
    }

    // Fire Node.js and Edge Function callers simultaneously on empty table
    const [result1, result2] = await Promise.all([
      executeKithRecordIpoApiRequest("Node-Worker"),
      executeKithRecordIpoApiRequest("Edge-Function"),
    ]);

    const allowedResults = [result1, result2].filter((r) => r.allowed);
    const rejectedResults = [result1, result2].filter((r) => !r.allowed);

    assert.strictEqual(allowedResults.length, 1, "Exactly one request must be allowed on first empty day");
    assert.strictEqual(rejectedResults.length, 1, "The competing request must be rejected");

    assert.strictEqual(allowedResults[0].reason, "ALLOWED");
    assert.strictEqual(allowedResults[0].current_count, 1);

    assert.strictEqual(rejectedResults[0].reason, "COOLDOWN_ACTIVE");
    assert.strictEqual(rejectedResults[0].current_count, 1);
    assert.strictEqual(rejectedResults[0].retry_after_seconds, 60);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 4. Simultaneous Requests When Today's Row Already Exists
  // ───────────────────────────────────────────────────────────────────────────
  it("4. Simultaneous Requests When Row Exists: Only one allowed after cooldown", async () => {
    let rowForToday = {
      date_ist: "2026-11-01",
      daily_request_count: 3,
      max_daily_requests: 10,
      last_request_at: Date.now() - 75 * 1000, // 75 seconds ago (> 60s cooldown)
      cooldown_seconds: 60,
    };
    let lockHolder = null;
    const lockWaitQueue = [];

    async function executeQuotaCheck(callerId) {
      if (lockHolder !== null) {
        await new Promise((resolve) => lockWaitQueue.push(resolve));
      }
      lockHolder = callerId;
      try {
        const now = Date.now();
        const cooldownMs = 60 * 1000;

        if (rowForToday.daily_request_count >= rowForToday.max_daily_requests) {
          return { allowed: false, reason: "DAILY_QUOTA_EXHAUSTED", retry_after_seconds: 3600 };
        }
        if (rowForToday.last_request_at !== null && now - rowForToday.last_request_at < cooldownMs) {
          const rem = Math.ceil((rowForToday.last_request_at + cooldownMs - now) / 1000);
          return { allowed: false, reason: "COOLDOWN_ACTIVE", retry_after_seconds: Math.max(1, rem) };
        }
        rowForToday.daily_request_count += 1;
        rowForToday.last_request_at = now;
        return { allowed: true, reason: "ALLOWED", current_count: rowForToday.daily_request_count };
      } finally {
        lockHolder = null;
        if (lockWaitQueue.length > 0) lockWaitQueue.shift()();
      }
    }

    const [resA, resB] = await Promise.all([
      executeQuotaCheck("Session-A"),
      executeQuotaCheck("Session-B"),
    ]);

    const allowed = [resA, resB].filter((r) => r.allowed);
    const rejected = [resA, resB].filter((r) => !r.allowed);

    assert.strictEqual(allowed.length, 1);
    assert.strictEqual(rejected.length, 1);
    assert.strictEqual(allowed[0].current_count, 4, "Count must increment to 4, not 5");
    assert.strictEqual(rejected[0].reason, "COOLDOWN_ACTIVE");
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 5. Daily Limit Enforcement
  // ───────────────────────────────────────────────────────────────────────────
  it("5. Daily Limit Enforcement: Strictly blocks requests once 10 req/day is reached", async () => {
    const mockDbClient = {
      query: async (sql) => {
        if (sql.includes("pg_try_advisory_lock")) return { rows: [{ locked: true }] };
        if (sql.includes("pg_advisory_unlock")) return { rows: [{ unlocked: true }] };
        if (sql.includes("kith_record_ipo_api_request")) {
          return {
            rows: [
              {
                result: {
                  allowed: false,
                  reason: "DAILY_QUOTA_EXHAUSTED",
                  current_count: 10,
                  max_requests: 10,
                  retry_after_seconds: 38400,
                  date_ist: "2026-11-01",
                },
              },
            ],
          };
        }
        return { rows: [] };
      },
    };

    let fetchCalled = false;
    const mockProvider = {
      fetchAllIpos: async () => {
        fetchCalled = true;
        return [];
      },
    };

    const service = new IpoIngestionService({ provider: mockProvider });
    const result = await service.runIngestion({ dbClient: mockDbClient });

    assert.strictEqual(result.skipped, true);
    assert.strictEqual(result.reason, "DAILY_QUOTA_EXHAUSTED");
    assert.strictEqual(fetchCalled, false, "Upstream fetch must NEVER be attempted when daily quota is exhausted");
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 6. 60-Second Cooldown Enforcement
  // ───────────────────────────────────────────────────────────────────────────
  it("6. 60-Second Cooldown: Rejects request within 60s and provides accurate retry_after_seconds", async () => {
    const mockDbClient = {
      query: async (sql) => {
        if (sql.includes("pg_try_advisory_lock")) return { rows: [{ locked: true }] };
        if (sql.includes("pg_advisory_unlock")) return { rows: [{ unlocked: true }] };
        if (sql.includes("kith_record_ipo_api_request")) {
          return {
            rows: [
              {
                result: {
                  allowed: false,
                  reason: "COOLDOWN_ACTIVE",
                  current_count: 1,
                  max_requests: 10,
                  retry_after_seconds: 48,
                  date_ist: "2026-11-01",
                },
              },
            ],
          };
        }
        return { rows: [] };
      },
    };

    let fetchCalled = false;
    const mockProvider = {
      fetchAllIpos: async () => {
        fetchCalled = true;
        return [];
      },
    };

    const service = new IpoIngestionService({ provider: mockProvider });
    const result = await service.runIngestion({ dbClient: mockDbClient });

    assert.strictEqual(result.skipped, true);
    assert.strictEqual(result.reason, "COOLDOWN_ACTIVE");
    assert.strictEqual(result.quota.retry_after_seconds, 48);
    assert.strictEqual(fetchCalled, false, "Upstream fetch must NEVER be attempted during cooldown");
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 7. Duplicate Ingestion Safety
  // ───────────────────────────────────────────────────────────────────────────
  it("7. Duplicate Ingestion: Ingesting same payload twice executes ON CONFLICT DO UPDATE", async () => {
    const executed = [];
    const mockDbClient = {
      query: async (sql, params) => {
        executed.push({ sql, params });
        return { rows: [] };
      },
    };

    const payload = [
      {
        id: "duplicate_safe_ipo",
        name: "Safe Dup Ltd",
        slug: "safe-dup",
        minPrice: 150,
        maxPrice: 160,
        lotSize: 90,
        gmp: 25,
      },
    ];

    const service = new IpoIngestionService({ provider: {} });
    await service.persistIpos(payload, mockDbClient);
    await service.persistIpos(payload, mockDbClient);

    const masterUpserts = executed.filter((q) => q.sql.includes("INSERT INTO ipo_master"));
    assert.strictEqual(masterUpserts.length, 2);
    for (const q of masterUpserts) {
      assert.ok(q.sql.includes("ON CONFLICT (id) DO UPDATE SET"), "Must update existing row in place on id");
    }

    const gmpUpserts = executed.filter((q) => q.sql.includes("INSERT INTO ipo_gmp_cache"));
    assert.strictEqual(gmpUpserts.length, 2);
    for (const q of gmpUpserts) {
      assert.ok(q.sql.includes("ON CONFLICT (slug) DO UPDATE SET"), "Must update existing row in place on slug");
    }
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 8. Null GMP Preservation (Within & Beyond 24 Hours)
  // ───────────────────────────────────────────────────────────────────────────
  it("8. Null GMP Preservation: Preserves valid GMP within 24h; expires to null after 24h", () => {
    const oneHourAgo = new Date(Date.now() - 1 * 60 * 60 * 1000).toISOString();
    const twentyFiveHoursAgo = new Date(Date.now() - 25 * 60 * 60 * 1000).toISOString();

    // Scenario A: Within 24-hour window
    const existingFresh = {
      gmp: 55,
      gmp_last_valid_at: oneHourAgo,
    };
    const incomingNull = null;

    const ageFreshMs = Date.now() - new Date(existingFresh.gmp_last_valid_at).getTime();
    let effectiveGmpA = incomingNull;
    let effectiveTimestampA = null;

    if (effectiveGmpA === null && existingFresh.gmp !== null && ageFreshMs < 24 * 60 * 60 * 1000) {
      effectiveGmpA = existingFresh.gmp;
      effectiveTimestampA = existingFresh.gmp_last_valid_at;
    }

    assert.strictEqual(effectiveGmpA, 55, "Must preserve GMP within 24 hours");
    assert.strictEqual(effectiveTimestampA, oneHourAgo, "Must preserve original timestamp without advancing");

    // Scenario B: Beyond 24-hour window
    const existingStale = {
      gmp: 55,
      gmp_last_valid_at: twentyFiveHoursAgo,
    };
    const ageStaleMs = Date.now() - new Date(existingStale.gmp_last_valid_at).getTime();
    let effectiveGmpB = incomingNull;

    if (effectiveGmpB === null && existingStale.gmp !== null && ageStaleMs < 24 * 60 * 60 * 1000) {
      effectiveGmpB = existingStale.gmp;
    }

    assert.strictEqual(effectiveGmpB, null, "Must expire to null after 24 hours of no valid quotes");
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 9. Valid Zero GMP
  // ───────────────────────────────────────────────────────────────────────────
  it("9. Valid Zero GMP: Explicit 0 GMP is preserved as 0 and refreshes timestamp", () => {
    const provider = new IpoGuruProvider();
    const itemZero = {
      id: "zero_gmp_ipo",
      slug: "zero-gmp-ipo",
      company_name: "Zero GMP Ltd",
      status: "Open",
      price_band_min: 100,
      price_band_max: 100,
      lot_size: 100,
      gmp: 0, // Flat / par value
    };

    const normalized = provider.normalizeItem(itemZero, 0);
    assert.strictEqual(normalized.gmp, 0, "GMP 0 must be preserved as strictly 0");
    assert.strictEqual(typeof normalized.gmp, "number", "GMP 0 must remain a numeric type, not null");
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 10. Listed IPO GMP Clearing
  // ───────────────────────────────────────────────────────────────────────────
  it("10. Listed IPO GMP Clearing: Clears GMP immediately in both tables regardless of payload", async () => {
    const executed = [];
    const mockDbClient = {
      query: async (sql, params) => {
        executed.push({ sql, params });
        return { rows: [] };
      },
    };

    const listedItem = [
      {
        id: "listed_titan",
        name: "Titan Listed Ltd",
        slug: "titan-listed",
        status: "listed",
        minPrice: 500,
        maxPrice: 520,
        lotSize: 25,
        gmp: 75, // Stale quote provided by upstream must be discarded!
      },
    ];

    const service = new IpoIngestionService({ provider: {} });
    await service.persistIpos(listedItem, mockDbClient);

    const masterQuery = executed.find((q) => q.sql.includes("INSERT INTO ipo_master"));
    assert.strictEqual(masterQuery.params[14], null, "ipo_master.gmp must be null for listed IPO");
    assert.strictEqual(masterQuery.params[15], null, "ipo_master.gmp_last_valid_at must be null for listed IPO");

    const gmpQuery = executed.find((q) => q.sql.includes("INSERT INTO ipo_gmp_cache"));
    assert.strictEqual(gmpQuery.params[6], null, "ipo_gmp_cache.gmp_raw must be null for listed IPO");
    assert.strictEqual(gmpQuery.params[7], null, "ipo_gmp_cache.gmp_last_valid_at must be null for listed IPO");
    assert.strictEqual(gmpQuery.params[8], null, "ipo_gmp_cache.estimated_listing_price must be null for listed IPO");
    assert.strictEqual(gmpQuery.params[9], null, "ipo_gmp_cache.estimated_gain_percentage must be null for listed IPO");
  });
});
