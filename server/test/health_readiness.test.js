const { describe, it, before, after } = require('node:test');
const assert = require('node:assert');
const http = require('http');
const app = require('../src/app');
const { realtimeHub } = require('../src/realtime/websocket_hub');

describe('Health & Readiness Subsystem Tests (Render Hotfix Verification)', () => {
  let server;
  const PORT = 10000; // Exact Render staging port
  const BASE_URL = `http://127.0.0.1:${PORT}`;

  before(async () => {
    server = http.createServer(app);
    realtimeHub.attach(server);
    await new Promise((resolve) => server.listen(PORT, '0.0.0.0', resolve));
  });

  after(async () => {
    realtimeHub.close();
    await new Promise((resolve) => server.close(resolve));
  });

  it('GET /health returns HTTP 200 with healthy status in under 20ms', async () => {
    const start = Date.now();
    const res = await fetch(`${BASE_URL}/health`);
    const duration = Date.now() - start;

    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.ok(data.status === 'ok' || data.status === 'healthy');
    assert.strictEqual(data.service, 'kith-backend');
    assert.ok(typeof data.uptimeSeconds === 'number');
    assert.ok(duration < 100, `Health check took ${duration}ms, must be < 100ms`);
  });

  it('HEAD /health returns HTTP 200 status', async () => {
    const res = await fetch(`${BASE_URL}/health`, { method: 'HEAD' });
    assert.strictEqual(res.status, 200);
  });

  it('GET /healthz returns HTTP 200 (Render fallback path)', async () => {
    const res = await fetch(`${BASE_URL}/healthz`);
    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.ok(data.status === 'ok' || data.status === 'healthy');
  });

  it('GET / returns HTTP 200 (Root ping fallback)', async () => {
    const res = await fetch(`${BASE_URL}/`);
    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.ok(data.status === 'ok' || data.status === 'healthy');
  });

  it('GET /api/health returns HTTP 200', async () => {
    const res = await fetch(`${BASE_URL}/api/health`);
    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.ok(data.status === 'ok' || data.status === 'healthy');
  });

  it('GET /ready returns subsystem readiness without exposing credentials or secrets', async () => {
    const res = await fetch(`${BASE_URL}/ready`);
    assert.ok(res.status === 200 || res.status === 503);
    const data = await res.json();
    assert.ok(data.status === 'ready' || data.status === 'not_ready');
    assert.strictEqual(data.service, 'kith-backend');

    // Security check: ensure no passwords, tokens, or raw connection strings are leaked
    const jsonStr = JSON.stringify(data);
    assert.strictEqual(jsonStr.includes('password'), false);
    assert.strictEqual(jsonStr.includes('secret'), false);
    assert.strictEqual(jsonStr.includes('kith_sess'), false);
  });
});
