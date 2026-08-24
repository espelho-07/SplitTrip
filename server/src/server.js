const http = require('http');
const app = require('./app');
const env = require('./config/env');
const { dbManager } = require('./db/db_manager');
const { realtimeHub } = require('./realtime/websocket_hub');

console.log('[Kith] Starting server...');

const server = http.createServer(app);

// Attach WebSocket Hub to HTTP server (does not block HTTP health probes)
realtimeHub.attach(server);

async function startServer() {
  const port = Number(process.env.PORT) || env.PORT || 10000;
  const host = process.env.HOST || '0.0.0.0';

  // Bind and start listening immediately so Render health checks succeed without startup race conditions
  server.listen(port, host, async () => {
    console.log(`[Kith] HTTP server listening on http://${host}:${port}`);
    console.log(`[Kith] Health endpoint available at /health`);
    console.log(`[Kith] WebSocket Hub active at ws://${host}:${port}/ws`);

    // Perform database initialization and migrations asynchronously with timeout protection
    try {
      await dbManager.init();
      console.log('[Kith] Application ready');
    } catch (err) {
      console.error('[Kith] Database initialization warning:', err.message);
    }
  });

  server.on('error', (err) => {
    console.error('[Kith] Fatal server error:', err);
    process.exit(1);
  });
}

// Global process exception safety handlers
process.on('unhandledRejection', (reason, promise) => {
  console.error('[Kith] Unhandled Rejection at:', promise, 'reason:', reason);
});

process.on('uncaughtException', (err) => {
  console.error('[Kith] Uncaught Exception thrown:', err);
});

// Graceful shutdown handling
process.on('SIGTERM', () => {
  console.log('[Kith] SIGTERM received, shutting down gracefully...');
  realtimeHub.close();
  server.close(() => {
    console.log('[Kith] HTTP server closed.');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('[Kith] SIGINT received, shutting down gracefully...');
  realtimeHub.close();
  server.close(() => {
    console.log('[Kith] HTTP server closed.');
    process.exit(0);
  });
});

if (require.main === module) {
  startServer();
}

module.exports = server;
