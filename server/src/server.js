const http = require('http');
const app = require('./app');
const env = require('./config/env');
const { dbManager } = require('./db/db_manager');
const { realtimeHub } = require('./realtime/websocket_hub');

const server = http.createServer(app);

// Attach WebSocket Hub to HTTP server
realtimeHub.attach(server);

async function startServer() {
  const port = Number(process.env.PORT) || env.PORT || 10000;
  const host = process.env.HOST || '0.0.0.0';

  // Bind and start listening immediately so Render health checks succeed without startup race conditions
  server.listen(port, host, async () => {
    console.log(`[Kith Backend] Server listening on http://${host}:${port}`);
    console.log(`[Kith Backend] WebSocket Hub active at ws://${host}:${port}/ws`);

    // Perform database initialization and migrations asynchronously
    try {
      await dbManager.init();
    } catch (err) {
      console.error('[Kith Backend] Database initialization warning:', err.message);
    }
  });

  server.on('error', (err) => {
    console.error('[Kith Backend] Fatal server error:', err);
    process.exit(1);
  });
}

// Graceful shutdown handling
process.on('SIGTERM', () => {
  console.log('[Kith Backend] SIGTERM received, shutting down gracefully...');
  realtimeHub.close();
  server.close(() => {
    console.log('[Kith Backend] HTTP server closed.');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('[Kith Backend] SIGINT received, shutting down gracefully...');
  realtimeHub.close();
  server.close(() => {
    console.log('[Kith Backend] HTTP server closed.');
    process.exit(0);
  });
});

if (require.main === module) {
  startServer();
}

module.exports = server;
