const { describe, it, before, after, beforeEach } = require('node:test');
const assert = require('node:assert');
const http = require('http');
const app = require('../src/app');
const versionService = require('../src/services/version_service');

describe('VersionService & Version Routes', () => {
  let server;
  const PORT = 10042;
  const BASE_URL = `http://127.0.0.1:${PORT}`;

  before(async () => {
    server = http.createServer(app);
    await new Promise((resolve) => server.listen(PORT, '0.0.0.0', resolve));
  });

  after(async () => {
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  beforeEach(() => {
    versionService.updateConfig({
      latestVersion: '2.4.1',
      minimumSupportedVersion: '2.1.0',
      releaseNotes: '• Major update notes',
      storeUrl: 'https://play.google.com/store/apps/details?id=com.nirniq.kith',
      updatePriority: 'flexible',
      featureFlags: {
        new_settlement_flow: true,
        new_trip_invite: true,
      },
    });
  });

  describe('SemVer Parsing & Comparison', () => {
    it('parses standard semver strings accurately', () => {
      const p = versionService.parseSemVer('2.4.1');
      assert.strictEqual(p.major, 2);
      assert.strictEqual(p.minor, 4);
      assert.strictEqual(p.patch, 1);
    });

    it('handles build suffixes like +1 or v prefixes', () => {
      const p1 = versionService.parseSemVer('v2.1.0+4');
      assert.strictEqual(p1.major, 2);
      assert.strictEqual(p1.minor, 1);
      assert.strictEqual(p1.patch, 0);

      const p2 = versionService.parseSemVer('1.0.0-beta.1');
      assert.strictEqual(p2.major, 1);
      assert.strictEqual(p2.minor, 0);
      assert.strictEqual(p2.patch, 0);
    });

    it('compares semver versions correctly across major, minor, and patch', () => {
      assert.strictEqual(versionService.compareSemVer('2.1.0', '2.1.0'), 0);
      assert.strictEqual(versionService.compareSemVer('2.1.0', '2.1.1'), -1);
      assert.strictEqual(versionService.compareSemVer('2.2.0', '2.1.9'), 1);
      assert.strictEqual(versionService.compareSemVer('3.0.0', '2.9.9'), 1);
      assert.strictEqual(versionService.compareSemVer('1.9.9', '2.0.0'), -1);
    });
  });

  describe('checkVersion evaluation logic', () => {
    it('returns "required" update for versions below minimum supported version', () => {
      const res = versionService.checkVersion('2.0.5');
      assert.strictEqual(res.updateType, 'required');
      assert.strictEqual(res.isUpdateRequired, true);
      assert.strictEqual(res.isUpdateAvailable, true);
      assert.strictEqual(res.updatePriority, 'immediate');
    });

    it('returns "optional" update for versions >= minSupported but < latest', () => {
      const res = versionService.checkVersion('2.3.0');
      assert.strictEqual(res.updateType, 'optional');
      assert.strictEqual(res.isUpdateRequired, false);
      assert.strictEqual(res.isUpdateAvailable, true);
      assert.strictEqual(res.updatePriority, 'flexible');
    });

    it('returns "none" update for versions matching latest or newer', () => {
      const res = versionService.checkVersion('2.4.1');
      assert.strictEqual(res.updateType, 'none');
      assert.strictEqual(res.isUpdateRequired, false);
      assert.strictEqual(res.isUpdateAvailable, false);

      const newer = versionService.checkVersion('2.5.0');
      assert.strictEqual(newer.updateType, 'none');
      assert.strictEqual(newer.isUpdateRequired, false);
    });
  });

  describe('HTTP Endpoints /api/app/version and /api/version', () => {
    it('GET /api/app/version?clientVersion=2.0.0 returns required update status', async () => {
      const response = await fetch(`${BASE_URL}/api/app/version?clientVersion=2.0.0`);
      assert.strictEqual(response.status, 200);
      const body = await response.json();
      assert.ok(body.data);
      assert.strictEqual(body.data.updateType, 'required');
      assert.strictEqual(body.data.isUpdateRequired, true);
      assert.strictEqual(body.data.minimumSupportedVersion, '2.1.0');
    });

    it('GET /api/version?clientVersion=2.2.0 returns optional update status', async () => {
      const response = await fetch(`${BASE_URL}/api/version?clientVersion=2.2.0`);
      assert.strictEqual(response.status, 200);
      const body = await response.json();
      assert.ok(body.data);
      assert.strictEqual(body.data.updateType, 'optional');
      assert.strictEqual(body.data.isUpdateRequired, false);
      assert.strictEqual(body.data.isUpdateAvailable, true);
    });

    it('POST /api/app/version updates server configuration dynamically', async () => {
      const updateRes = await fetch(`${BASE_URL}/api/app/version`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          latestVersion: '3.0.0',
          minimumSupportedVersion: '3.0.0',
        }),
      });
      assert.strictEqual(updateRes.status, 200);

      const checkRes = await fetch(`${BASE_URL}/api/app/version?clientVersion=2.4.1`);
      const checkBody = await checkRes.json();
      assert.strictEqual(checkBody.data.updateType, 'required');
      assert.strictEqual(checkBody.data.minimumSupportedVersion, '3.0.0');
    });
  });
});
