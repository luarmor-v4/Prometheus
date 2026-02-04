FROM node:18-alpine

# Install dependencies
RUN apk add --no-cache \
    lua5.1 \
    git \
    && rm -rf /var/cache/apk/*

WORKDIR /app

# Install npm packages
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Clone Prometheus (will have src/cli.lua structure)
RUN git clone --depth 1 "https://github.com/prometheus-lua/Prometheus.git" prometheus

# Verify CLI exists
RUN test -f prometheus/src/cli.lua || (echo "ERROR: CLI not found at prometheus/src/cli.lua" && exit 1)

# Copy bot code
COPY bot.js ./

# Environment
ENV PROMETHEUS_PATH=/app/prometheus
ENV LUA_PATH=/usr/bin/lua5.1
ENV NODE_ENV=production

# Security
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup && \
    chown -R appuser:appgroup /app

USER appuser

# Health check (optional)
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD test -f /app/prometheus/src/cli.lua || exit 1

CMD ["node", "bot.js"]
