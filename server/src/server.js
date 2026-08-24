const http = require('http');
const app = require('./app');
const env = require('./config/env');
const { dbManager } = require('./db/db_manager');
const { realtimeHub } = require('./realtime/websocket_hub');

const server = http.createServer(app);

// Attach WebSocket Hub to HTTP server
realtimeHub.attach(server);

async function startServer() {
  try {
    await dbManager.init();

    server.listen(env.PORT, env.HOST, () => {
      console.log(`[Kith Backend] Server listening on http://${env.HOST}:${env.PORT}`);
      console.log(`[Kith Backend] WebSocket Hub active at ws://${env.HOST}:${env.PORT}/ws`);
    });
  } catch (err) {
    console.error('[Kith Backend] Failed to start server:', err);
    process.exit(1);
  }
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

if (require.main === module) {
  startServer();
}

module.exports = server;
