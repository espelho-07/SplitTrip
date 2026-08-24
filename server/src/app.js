const express = require('express');
const cors = require('cors');
const fs = require('fs');
const authRoutes = require('./routes/auth_routes');
const tripRoutes = require('./routes/trip_routes');
const expenseRoutes = require('./routes/expense_routes');
const { errorHandler } = require('./middleware/error_handler');
const env = require('./config/env');

const app = express();

// Environment-aware CORS configuration
const corsOptions = {
  origin: env.NODE_ENV === 'production'
    ? (process.env.CORS_ORIGIN ? process.env.CORS_ORIGIN.split(',') : false)
    : '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept'],
};

app.use(cors(corsOptions));
app.use(express.json());

// Structured Request Logging (omitted during unit tests to keep test output clean)
if (env.NODE_ENV !== 'test') {
  app.use((req, res, next) => {
    const start = Date.now();
    res.on('finish', () => {
      const duration = Date.now() - start;
      // Skip noisy health logs in production
      if (req.path !== '/health' && req.path !== '/api/health') {
        const logEntry = {
          timestamp: new Date().toISOString(),
          method: req.method,
          path: req.originalUrl,
          statusCode: res.statusCode,
          durationMs: duration,
        };
        process.stdout.write(`${JSON.stringify(logEntry)}\n`);
      }
    });
    next();
  });
}

// Liveness & Health Check
const healthHandler = (req, res) => {
  res.status(200).json({
    status: 'healthy',
    service: 'kith-backend',
    environment: env.NODE_ENV,
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    uptimeSeconds: Math.floor(process.uptime()),
  });
};

app.get('/health', healthHandler);
app.get('/api/health', healthHandler);

// Readiness Check
app.get('/ready', (req, res) => {
  try {
    // Verify storage directory readiness
    if (fs.existsSync(env.DATA_DIR)) {
      res.status(200).json({
        status: 'ready',
        service: 'kith-backend',
        storage: 'accessible',
        timestamp: new Date().toISOString(),
      });
    } else {
      res.status(503).json({
        status: 'not_ready',
        error: 'Storage directory inaccessible',
      });
    }
  } catch (err) {
    res.status(503).json({
      status: 'not_ready',
      error: err.message,
    });
  }
});

// Mount Routes
app.use('/api/auth', authRoutes);
app.use('/api/trips', tripRoutes);
app.use('/api/trips/:tripId/expenses', expenseRoutes);

// Fallback 404 for unhandled API routes
app.use('/api/*', (req, res) => {
  res.status(404).json({
    error: {
      code: 'ROUTE_NOT_FOUND',
      message: `The requested path ${req.originalUrl} was not found on this server.`,
    },
  });
});

// Central Error Handler
app.use(errorHandler);

module.exports = app;
