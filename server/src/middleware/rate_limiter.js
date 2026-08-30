'use strict';

/**
 * In-memory sliding-window rate limiter.
 * Tracks request counts per bucket (IP or authenticated userId).
 * Returns HTTP 429 Too Many Requests with standard Retry-After header.
 */
class RateLimiter {
  constructor({ windowMs = 60 * 1000, max = 100, name = 'default' } = {}) {
    this.windowMs = windowMs;
    this.max = max;
    this.name = name;
    this.hits = new Map(); // key -> { count, resetTime }

    // Periodic sweep every 5 minutes to avoid memory leaks
    this._cleanupInterval = setInterval(() => this._cleanup(), 5 * 60 * 1000);
    if (this._cleanupInterval && this._cleanupInterval.unref) {
      this._cleanupInterval.unref();
    }
  }

  _cleanup() {
    const now = Date.now();
    for (const [key, record] of this.hits.entries()) {
      if (now > record.resetTime) {
        this.hits.delete(key);
      }
    }
  }

  middleware() {
    return (req, res, next) => {
      // Allow bypass in test mode unless X-Test-Rate-Limit header is explicitly set
      if (process.env.NODE_ENV === 'test' && !req.headers['x-test-rate-limit']) {
        return next();
      }

      const clientKey = req.user?.id || req.ip || req.connection?.remoteAddress || 'unknown_client';
      const key = `${this.name}:${clientKey}`;
      const now = Date.now();

      let record = this.hits.get(key);
      if (!record || now > record.resetTime) {
        record = { count: 0, resetTime: now + this.windowMs };
        this.hits.set(key, record);
      }

      if (record.count >= this.max) {
        const retryAfterSec = Math.max(1, Math.ceil((record.resetTime - now) / 1000));
        res.setHeader('Retry-After', retryAfterSec);
        return res.status(429).json({
          error: {
            code: 'RATE_LIMIT_EXCEEDED',
            message: `Too many requests for ${this.name}. Please retry after ${retryAfterSec} seconds.`,
            retryAfterSeconds: retryAfterSec,
          },
        });
      }

      record.count += 1;
      next();
    };
  }

  reset() {
    this.hits.clear();
  }
}

// Configured Tiered Rate Limiters
const authLimiter = new RateLimiter({
  name: 'auth',
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 30, // 30 auth requests per 15 min
});

const mutationLimiter = new RateLimiter({
  name: 'mutation',
  windowMs: 60 * 1000, // 1 minute
  max: 180, // 180 mutations / min
});

const syncLimiter = new RateLimiter({
  name: 'sync',
  windowMs: 60 * 1000, // 1 minute
  max: 120, // 120 sync requests / min
});

const readLimiter = new RateLimiter({
  name: 'read',
  windowMs: 60 * 1000, // 1 minute
  max: 600, // 600 reads / min
});

module.exports = {
  RateLimiter,
  authLimiter: authLimiter.middleware(),
  mutationLimiter: mutationLimiter.middleware(),
  syncLimiter: syncLimiter.middleware(),
  readLimiter: readLimiter.middleware(),
  instances: { authLimiter, mutationLimiter, syncLimiter, readLimiter },
};
