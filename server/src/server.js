const http = require('http');
const app = require('./app');
const env = require('./config/env');
const { realtimeHub } = require('./realtime/websocket_hub');

const server = http.createServer(app);

// Attach WebSocket Hub to HTTP server
realtimeHub.attach(server);

server.listen(env.PORT, env.HOST, () => {
  console.log(`[Kith Backend] Server listening on http://${env.HOST}:${env.PORT}`);
  console.log(`[Kith Backend] WebSocket Hub active at ws://${env.HOST}:${env.PORT}/ws`);
});

// Graceful shutdown handling
process.on('SIGTERM', () => {
  console.log('[Kith Backend] SIGTERM received, shutting down gracefully...');
  realtimeHub.close();
  server.close(() => {
    console.log('[Kith Backend] HTTP server closed.');
    process.exit(0);
  });
});

module.exports = server;
