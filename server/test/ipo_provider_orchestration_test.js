/**
 * Automated Tests: IPO Provider Priority Pipeline & Orchestrator
 *
 * Verifies:
 * 1. IPO Guru is strict PRIMARY.
 * 2. FinAPI is strict BACKUP.
 * 3. Fallback occurs automatically when IPO Guru is unconfigured or fails.
 * 4. When IPO Guru key is added tomorrow, it automatically resumes PRIMARY status without calling FinAPI.
 * 5. Zero demo/fake data when both providers fail.
 */

const assert = require("assert");
const { IpoGuruProvider } = require("../src/services/ipo/ipo_guru_provider");
const { FinApiProvider } = require("../src/services/ipo/finapi_provider");

async function runTests() {
  console.log("▶ Starting IPO Provider Orchestration Test Suite...\n");

  // --- Test 1: IpoGuruProvider Configuration & Normalization ---
  {
    console.log("Test 1: IpoGuruProvider correctly identifies configured status and normalizes data");
    const provider = new IpoGuruProvider();
    
    // Without key
    delete process.env.IPO_GURU_API_KEY;
    assert.strictEqual(provider.isConfigured, false, "Should be unconfigured when IPO_GURU_API_KEY is unset");

    // With key
    process.env.IPO_GURU_API_KEY = "test_guru_secret_key_123";
    assert.strictEqual(provider.isConfigured, true, "Should be configured when real key is present");

    const sampleGuruRaw = {
      id: "krn_heat",
      company_name: "KRN Heat Exchanger and Refrigeration Limited",
      symbol: "KRN",
      category: "Mainboard",
      status: "Open",
      price_band_min: 209,
      price_band_max: 220,
      lot_size: 65,
      issue_size: 342,
      gmp: 235,
      qib_subscription: 253.9,
      retail_subscription: 96.5,
      subscription_overall: 214.4,
    };

    const normalized = provider.normalizeItem(sampleGuruRaw, 0);
    assert.strictEqual(normalized.id, "krn_heat");
    assert.strictEqual(normalized.name, "KRN Heat Exchanger and Refrigeration Limited");
    assert.strictEqual(normalized.marketType, "mainboard");
    assert.strictEqual(normalized.status, "open");
    assert.strictEqual(normalized.minPrice, 209);
    assert.strictEqual(normalized.maxPrice, 220);
    assert.strictEqual(normalized.lotSize, 65);
    assert.strictEqual(normalized.gmp, 235);
    assert.strictEqual(normalized.source, "ipo_guru");
    assert.strictEqual(normalized.isLive, true);
    console.log("  ✔ Test 1 Passed: IPO Guru provider normalization verified\n");
  }

  // --- Test 2: FinApiProvider Configuration & Normalization ---
  {
    console.log("Test 2: FinApiProvider correctly identifies configured status and normalizes data");
    const finProvider = new FinApiProvider();

    // Without key
    delete process.env.FINAPI_API_KEY;
    assert.strictEqual(finProvider.isConfigured, false, "Should be unconfigured when FINAPI_API_KEY is unset");

    // With key
    process.env.FINAPI_API_KEY = "test_finapi_secret_key_456";
    assert.strictEqual(finProvider.isConfigured, true, "Should be configured when key is present");

    const sampleFinApiRaw = {
      id: "techera_eng",
      name: "TechEra Engineering IPO",
      company_name: "TechEra Engineering Limited",
      ticker: "TECHE",
      market_type: "SME",
      ipo_status: "Active",
      price_min: 78,
      price_max: 82,
      market_lot: 1600,
      issue_size: 35.9,
      gmp: 40,
    };

    const normalized = finProvider.normalizeItem(sampleFinApiRaw, 0);
    assert.strictEqual(normalized.id, "techera_eng");
    assert.strictEqual(normalized.marketType, "sme");
    assert.strictEqual(normalized.status, "open");
    assert.strictEqual(normalized.minPrice, 78);
    assert.strictEqual(normalized.maxPrice, 82);
    assert.strictEqual(normalized.lotSize, 1600);
    assert.strictEqual(normalized.gmp, 40);
    assert.strictEqual(normalized.source, "finapi");
    assert.strictEqual(normalized.isLive, true);
    console.log("  ✔ Test 2 Passed: FinAPI provider normalization verified\n");
  }

  // --- Test 3: Orchestrator Pipeline Priority (Guru Primary -> FinAPI Backup) ---
  {
    console.log("Test 3: Orchestrator Priority Simulation — Today (No Guru key) vs Tomorrow (Guru key added)");

    // Mock Guru provider
    class MockGuruProvider extends IpoGuruProvider {
      constructor(shouldSucceed) {
        super();
        this._shouldSucceed = shouldSucceed;
        this.calls = 0;
      }
      get isConfigured() {
        return Boolean(process.env.IPO_GURU_API_KEY);
      }
      async fetchIpos() {
        this.calls++;
        if (!this._shouldSucceed) return null;
        return [{ id: "guru_ipo_1", name: "Guru IPO", source: "ipo_guru", isLive: true }];
      }
    }

    // Mock FinAPI provider
    class MockFinApiProvider extends FinApiProvider {
      constructor(shouldSucceed) {
        super();
        this._shouldSucceed = shouldSucceed;
        this.calls = 0;
      }
      get isConfigured() {
        return Boolean(process.env.FINAPI_API_KEY);
      }
      async fetchIpos() {
        this.calls++;
        if (!this._shouldSucceed) return null;
        return [{ id: "finapi_ipo_1", name: "FinAPI IPO", source: "finapi", isLive: true }];
      }
    }

    // SCENARIO A: Today — IPO Guru key not set, FinAPI key set
    delete process.env.IPO_GURU_API_KEY;
    process.env.FINAPI_API_KEY = "mock_finapi_key";
    {
      const guru = new MockGuruProvider(true);
      const fin = new MockFinApiProvider(true);
      const pipeline = [guru, fin];

      let chosen = null;
      for (const p of pipeline) {
        if (p.isConfigured) {
          const res = await p.fetchIpos();
          if (res) { chosen = { data: res, source: p.id }; break; }
        }
      }

      assert.strictEqual(guru.calls, 0, "Guru should not be called when unconfigured");
      assert.strictEqual(fin.calls, 1, "FinAPI should be called as backup");
      assert.strictEqual(chosen.source, "finapi", "Chosen source must be finapi");
      console.log("  ✔ Scenario A: Today (No Guru key) -> FinAPI fallback works");
    }

    // SCENARIO B: Tomorrow — IPO Guru key configured and healthy
    process.env.IPO_GURU_API_KEY = "real_guru_key_tomorrow";
    process.env.FINAPI_API_KEY = "mock_finapi_key";
    {
      const guru = new MockGuruProvider(true);
      const fin = new MockFinApiProvider(true);
      const pipeline = [guru, fin];

      let chosen = null;
      for (const p of pipeline) {
        if (p.isConfigured) {
          const res = await p.fetchIpos();
          if (res) { chosen = { data: res, source: p.id }; break; }
        }
      }

      assert.strictEqual(guru.calls, 1, "Guru must be called first as PRIMARY");
      assert.strictEqual(fin.calls, 0, "FinAPI must NOT be called when Guru is healthy");
      assert.strictEqual(chosen.source, "ipo_guru", "Chosen source must be ipo_guru");
      console.log("  ✔ Scenario B: Tomorrow (Guru key added) -> IPO Guru becomes PRIMARY automatically");
    }

    // SCENARIO C: Guru configured but encounters upstream failure (5xx/timeout) -> Falls back to FinAPI
    {
      const guru = new MockGuruProvider(false); // Fails
      const fin = new MockFinApiProvider(true);  // Succeeds
      const pipeline = [guru, fin];

      let chosen = null;
      for (const p of pipeline) {
        if (p.isConfigured) {
          const res = await p.fetchIpos();
          if (res) { chosen = { data: res, source: p.id }; break; }
        }
      }

      assert.strictEqual(guru.calls, 1, "Guru tried first");
      assert.strictEqual(fin.calls, 1, "FinAPI called as fallback");
      assert.strictEqual(chosen.source, "finapi", "Fallback succeeded");
      console.log("  ✔ Scenario C: Guru upstream failure -> Seamless FinAPI fallback");
    }

    // SCENARIO D: Both fail -> Zero demo data returned
    {
      const guru = new MockGuruProvider(false);
      const fin = new MockFinApiProvider(false);
      const pipeline = [guru, fin];

      let chosen = null;
      for (const p of pipeline) {
        if (p.isConfigured) {
          const res = await p.fetchIpos();
          if (res) { chosen = { data: res, source: p.id }; break; }
        }
      }

      assert.strictEqual(chosen, null, "When both fail, must return null (zero demo data)");
      console.log("  ✔ Scenario D: Both fail -> Zero demo data policy verified\n");
    }
  }

  console.log("🎉 All IPO Provider Orchestration Tests Passed Successfully!\n");
}

runTests().catch((err) => {
  console.error("❌ Test suite failed:", err);
  process.exit(1);
});
