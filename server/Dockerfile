# ==============================================================================
# Kith Production Backend Dockerfile
# Optimized multi-stage build, non-root execution, automated health checks
# ==============================================================================

FROM node:20-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev

FROM node:20-alpine AS runner

WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000

# Create non-root system user
RUN addgroup -S kith && adduser -S kith -G kith

# Copy node modules and source code
COPY --from=builder /app/node_modules ./node_modules
COPY package*.json ./
COPY src/ ./src/
COPY migrations/ ./migrations/
COPY public/ ./public/

# Ensure storage directory exists and has proper permissions
RUN mkdir -p data_storage && chown -R kith:kith /app

USER kith

EXPOSE 3000

HEALTHCHECK --interval=15s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["node", "src/server.js"]
