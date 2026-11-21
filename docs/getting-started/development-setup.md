# Development Setup

This document explains how to configure local environment variables, start the local backend server, and run Kith on Android emulators and physical devices.

---

## 1. Backend Server Setup

Kith includes a Node.js backend (`server/`) that provides:
- REST API for user sessions, trip sharing, and cloud expense synchronization.
- Real-time WebSocket hub for instant live multi-device updates.
- In-memory / JSON persistence for zero-configuration local development.
- Push notification mock dispatcher and Indian IPO schedule sync.

### Starting the Server
```bash
cd server
npm start
```
The server will start on port `3000`:
- HTTP API: `http://localhost:3000/api`
- Health check: `http://localhost:3000/health`
- WebSocket server: `ws://localhost:3000`

---

## 2. Connecting Client to Backend

### Android Emulator
Android emulators access the host machine's localhost via `10.0.2.2`:
* Base API URL: `http://10.0.2.2:3000/api`
* WebSocket URL: `ws://10.0.2.2:3000`

### Physical Android Device
When testing on a physical phone:
1. Ensure both your computer and phone are connected to the same Wi-Fi network.
2. Find your computer's local IP address (`ipconfig` on Windows or `ifconfig` on macOS/Linux).
3. The app automatically attempts LAN autodiscovery, or you can configure `http://<your-local-ip>:3000/api` in your debug configuration.

---

## 3. Running Kith on Android

1. List available devices:
   ```bash
   flutter devices
   ```
2. Run on your selected device:
   ```bash
   flutter run -d <device-id>
   ```

### Hot Reload & Hot Restart
- Press `r` in the terminal for Hot Reload (instant stateful UI update).
- Press `R` for Hot Restart (full app restart preserving local database).
- Press `q` to terminate the session.
