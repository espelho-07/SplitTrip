/**
 * Automated Tests: IPO Ingestion Quota Budget & Concurrency Locking Suite
 *
 * Verifies:
 * 1. Strict Free Tier quota: 10 requests / day limit blocks further ingestion.
 * 2. 60-second cooldown blocks immediate successive fetches.
 * 3. Advisory lock (7421) prevents concurrent worker overlap.
 * 4. Distinguishes null GMP ("N/A") from 0 ("₹0 Flat").
 * 5. Single collection endpoint ingestion (zero single-slug loops).
 * 6. Audit logging into ipo_fetch_logs.
 */

const test = require("node:test");
const assert = require("node:assert");
const { IpoIngestionService, LOCK_ID } = require("../src/services/ipo/ipo_ingestion_service");
const { IpoGuruProvider } = require("../src/services/ipo/ipo_guru_provider");

test("IPO Guru v2 Provider normalizes slug, price bands, and handles GMP null vs 0", () => {
  const provider = new IpoGuruProvider();

  // Test with null GMP (unquoted)
  const itemNullGmp = {
    id: "sme_tech_ltd",
    slug: "sme-tech-ltd",
    company_name: "SME Tech Ltd",
    symbol: "SMETECH",
    category: "SME",
    status: "Upcoming",
    price_band_min: 100,
    price_band_max: 105,
    lot_size: 1200,
    gmp: null,
  };
  const normNull = provider.normalizeItem(itemNullGmp, 0);
  assert.strictEqual(normNull.id, "sme_tech_ltd");
  assert.strictEqual(normNull.slug, "sme-tech-ltd");
  assert.strictEqual(normNull.marketType, "sme");
  assert.strictEqual(normNull.gmp, null, "Null GMP must remain null, not coerced to 0");

  // Test with 0 GMP (par / flat)
  const itemZeroGmp = {
    id: "flat_ipo_ltd",
    slug: "flat-ipo-ltd",
    company_name: "Flat IPO Ltd",
    symbol: "FLAT",
    category: "Mainboard",
    status: "Open",
    price_band_min: 50,
    price_band_max: 55,
    lot_size: 250,
    gmp: 0,
  };
  const normZero = provider.normalizeItem(itemZeroGmp, 1);
  assert.strictEqual(normZero.gmp, 0, "Zero GMP must be strictly 0");

  // Test with positive GMP
  const itemPosGmp = {
    id: "premium_ipo_ltd",
    slug: "premium-ipo-ltd",
    company_name: "Premium IPO Ltd",
    symbol: "PREM",
    category: "Mainboard",
    status: "Open",
    price_band_min: 500,
    price_band_max: 520,
    lot_size: 28,
    gmp: 130,
  };
  const normPos = provider.normalizeItem(itemPosGmp, 2);
  assert.strictEqual(normPos.gmp, 130);
});

test("IpoIngestionService enforces 10 req/day quota limit refusal", async () => {
  let quotaCount = 10;
  const mockDbClient = {
    query: async (sql, params) => {
      if (sql.includes("pg_try_advisory_lock")) {
        return { rows: [{ locked: true }] };
      }
      if (sql.includes("pg_advisory_unlock")) {
        return { rows: [{ unlocked: true }] };
      }
      if (sql.includes("kith_record_ipo_api_request")) {
        return {
          rows: [{
            result: {
              allowed: false,
              reason: "DAILY_QUOTA_EXHAUSTED",
              current_count: quotaCount,
              max_requests: 10,
              date_ist: "2026-11-01",
            },
          }],
        };
      }
      return { rows: [] };
    },
  };

  let providerCalled = false;
  const mockProvider = {
    fetchIpos: async () => {
      providerCalled = true;
      return [];
    },
  };

  const service = new IpoIngestionService({ provider: mockProvider });
  const result = await service.runIngestion({ dbClient: mockDbClient });

  assert.strictEqual(result.success, false);
  assert.strictEqual(result.skipped, true);
  assert.strictEqual(result.reason, "DAILY_QUOTA_EXHAUSTED");
  assert.strictEqual(providerCalled, false, "Provider must NEVER be called when quota is exhausted");
});

test("IpoIngestionService enforces 60-second cooldown refusal", async () => {
  const mockDbClient = {
    query: async (sql, params) => {
      if (sql.includes("pg_try_advisory_lock")) {
        return { rows: [{ locked: true }] };
      }
      if (sql.includes("pg_advisory_unlock")) {
        return { rows: [{ unlocked: true }] };
      }
      if (sql.includes("kith_record_ipo_api_request")) {
        return {
          rows: [{
            result: {
              allowed: false,
              reason: "COOLDOWN_ACTIVE",
              current_count: 3,
              max_requests: 10,
              date_ist: "2026-11-01",
            },
          }],
        };
      }
      return { rows: [] };
    },
  };

  let providerCalled = false;
  const mockProvider = {
    fetchIpos: async () => {
      providerCalled = true;
      return [];
    },
  };

  const service = new IpoIngestionService({ provider: mockProvider });
  const result = await service.runIngestion({ dbClient: mockDbClient });

  assert.strictEqual(result.success, false);
  assert.strictEqual(result.skipped, true);
  assert.strictEqual(result.reason, "COOLDOWN_ACTIVE");
  assert.strictEqual(providerCalled, false, "Provider must NEVER be called when cooldown is active");
});

test("IpoIngestionService prevents concurrent execution via advisory lock", async () => {
  const mockDbClient = {
    query: async (sql, params) => {
      if (sql.includes("pg_try_advisory_lock")) {
        assert.strictEqual(params[0], LOCK_ID);
        return { rows: [{ locked: false }] }; // Simulate lock already held by another session
      }
      return { rows: [] };
    },
  };

  let providerCalled = false;
  const mockProvider = {
    fetchIpos: async () => {
      providerCalled = true;
      return [];
    },
  };

  const service = new IpoIngestionService({ provider: mockProvider });
  const result = await service.runIngestion({ dbClient: mockDbClient });

  assert.strictEqual(result.success, false);
  assert.strictEqual(result.skipped, true);
  assert.strictEqual(result.reason, "CONCURRENT_WORKER_ACTIVE");
  assert.strictEqual(providerCalled, false, "Provider must NEVER be called if advisory lock is already held");
});

test("IpoIngestionService ingests single collection payload and upserts to database", async () => {
  const executedQueries = [];
  const mockDbClient = {
    query: async (sql, params) => {
      executedQueries.push({ sql, params });
      if (sql.includes("pg_try_advisory_lock")) {
        return { rows: [{ locked: true }] };
      }
      if (sql.includes("pg_advisory_unlock")) {
        return { rows: [{ unlocked: true }] };
      }
      if (sql.includes("kith_record_ipo_api_request")) {
        return {
          rows: [{
            result: {
              allowed: true,
              reason: "ALLOWED",
              current_count: 1,
              max_requests: 10,
              date_ist: "2026-11-01",
            },
          }],
        };
      }
      return { rows: [] };
    },
  };

  const mockProvider = {
    fetchIpos: async () => [
      {
        id: "acme_corp",
        slug: "acme-corp",
        name: "Acme Corp Ltd",
        companyName: "Acme Corp Ltd",
        symbol: "ACME",
        marketType: "mainboard",
        status: "open",
        openDate: "2026-11-01T00:00:00Z",
        closeDate: "2026-11-03T00:00:00Z",
        minPrice: 100,
        maxPrice: 110,
        lotSize: 100,
        gmp: 25,
      },
    ],
  };

  const service = new IpoIngestionService({ provider: mockProvider });
  const result = await service.runIngestion({ dbClient: mockDbClient });

  assert.strictEqual(result.success, true);
  assert.strictEqual(result.recordCount, 1);

  // Verify ipo_master and ipo_gmp_cache were updated
  const masterUpsert = executedQueries.find((q) => q.sql.includes("INSERT INTO ipo_master"));
  assert.ok(masterUpsert, "Must execute upsert on ipo_master");
  assert.strictEqual(masterUpsert.params[0], "acme_corp");
  assert.strictEqual(masterUpsert.params[14], 25, "GMP must be passed");

  const gmpUpsert = executedQueries.find((q) => q.sql.includes("INSERT INTO ipo_gmp_cache"));
  assert.ok(gmpUpsert, "Must execute upsert on ipo_gmp_cache");
  assert.strictEqual(gmpUpsert.params[2], "acme-corp");
  assert.strictEqual(gmpUpsert.params[6], 25, "GMP raw must be 25");
  assert.ok(gmpUpsert.params[7], "gmp_last_valid_at must be populated");
  assert.strictEqual(gmpUpsert.params[8], 135, "Estimated listing price must be 110 + 25 = 135");

  const logInsert = executedQueries.find((q) => q.sql.includes("INSERT INTO ipo_fetch_logs"));
  assert.ok(logInsert, "Must execute log insert on ipo_fetch_logs");
  assert.strictEqual(logInsert.params[1], 200, "Log status must be 200");
  assert.strictEqual(logInsert.params[2], 1, "Log record count must be 1");

  const unlockQuery = executedQueries.find((q) => q.sql.includes("pg_advisory_unlock"));
  assert.ok(unlockQuery, "Must release advisory lock upon completion");
});
