const express = require('express');
const cors = require('cors');
const authRoutes = require('./routes/auth_routes');
const tripRoutes = require('./routes/trip_routes');
const expenseRoutes = require('./routes/expense_routes');
const personalRoutes = require('./routes/personal_routes');
const notificationRoutes = require('./routes/notification_routes');
const versionRoutes = require('./routes/version_routes');
const webRoutes = require('./routes/web_routes');
const ipoRoutes = require('./routes/ipo_routes');
const { errorHandler } = require('./middleware/error_handler');
const { authLimiter, mutationLimiter, syncLimiter, readLimiter } = require('./middleware/rate_limiter');
const { dbManager } = require('./db/db_manager');
const { storageRetentionService } = require('./services/storage_retention_service');
const env = require('./config/env');

const app = express();

// Fast Zero-Dependency Health Probes for Cloud Load Balancers & Render Deployments
const healthHandler = (req, res) => {
  const start = process.hrtime();
  res.status(200).json({
    status: 'healthy',
    ok: true,
    service: 'kith-backend',
    environment: env.NODE_ENV,
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    uptimeSeconds: Math.floor(process.uptime()),
  });

  if (env.NODE_ENV !== 'test') {
    const diff = process.hrtime(start);
    const ms = (diff[0] * 1e3 + diff[1] * 1e-6).toFixed(2);
    console.log(`[Health] ${req.method} ${req.path} 200 (${ms}ms)`);
  }
};

app.get('/health', healthHandler);
app.get('/healthz', healthHandler);
app.get('/api/health', healthHandler);
app.get('/api/healthz', healthHandler);
app.head('/health', healthHandler);
app.head('/healthz', healthHandler);

// Environment-aware CORS configuration
const corsOptions = {
  origin: env.NODE_ENV === 'production'
    ? (process.env.CORS_ORIGIN ? process.env.CORS_ORIGIN.split(',') : false)
    : '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'HEAD'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept', 'X-Test-Rate-Limit'],
};

app.use(cors(corsOptions));

// Explicit Request Body & Payload Protection (Prevents memory exhaustion attacks)
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

// Structured Request Logging (omitted during unit tests to keep test output clean)
if (env.NODE_ENV !== 'test') {
  app.use((req, res, next) => {
    const start = Date.now();
    res.on('finish', () => {
      const duration = Date.now() - start;
      const path = req.path;
      // Skip noisy health and ping logs in production
      const isHealthPath = path === '/health' || path === '/healthz' || path === '/api/health' || path === '/api/healthz' || path === '/';
      if (!isHealthPath) {
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

// Readiness Check (Reports application and database subsystem readiness)
app.get('/ready', async (req, res) => {
  try {
    const result = await dbManager.checkReadiness();
    if (result.status === 'ready') {
      res.status(200).json(result);
    } else {
      res.status(503).json(result);
    }
  } catch (err) {
    res.status(503).json({
      status: 'not_ready',
      service: 'kith-backend',
      error: err.message,
    });
  }
});

// Periodic Storage Retention & Compaction (Every 12 hours)
if (env.NODE_ENV !== 'test') {
  setInterval(() => {
    try {
      const summary = storageRetentionService.runRetentionCycle();
      console.log('[StorageRetention] Maintenance cycle completed:', summary);
    } catch (e) {
      console.error('[StorageRetention] Maintenance error:', e.message);
    }
  }, 12 * 60 * 60 * 1000).unref?.();
}

// Mount Routes with Tiered Rate Limiting
app.use('/', webRoutes);
app.use('/api/auth', authLimiter, authRoutes);
app.use('/api/trips', mutationLimiter, tripRoutes);
app.use('/api/trips/:tripId/expenses', mutationLimiter, expenseRoutes);
app.use('/api/personal', mutationLimiter, personalRoutes);
app.use('/api/notifications', readLimiter, notificationRoutes);
app.use('/api/ipos', readLimiter, ipoRoutes);
app.use('/api/app/version', versionRoutes);
app.use('/api/version', versionRoutes);

// GET /api/settlements/pending - User pending settlement verifications
app.get('/api/settlements/pending', require('./middleware/auth').authMiddleware, (req, res, next) => {
  try {
    const notificationService = require('./services/notification_service');
    const result = notificationService.getPendingSettlementsForUser(req.user.id);
    res.status(200).json({ data: result });
  } catch (e) {
    next(e);
  }
});

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
