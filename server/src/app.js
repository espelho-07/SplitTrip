const express = require('express');
const cors = require('cors');
const authRoutes = require('./routes/auth_routes');
const tripRoutes = require('./routes/trip_routes');
const expenseRoutes = require('./routes/expense_routes');
const { errorHandler } = require('./middleware/error_handler');

const app = express();

app.use(cors());
app.use(express.json());

// Health Check
app.get('/api/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    service: 'kith-backend',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    uptimeSeconds: Math.floor(process.uptime()),
  });
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
