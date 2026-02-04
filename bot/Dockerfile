# ============================================================
# Prometheus Discord Bot - Docker Image
# ============================================================

FROM node:18-alpine

RUN apk add --no-cache \
    lua5.1 \
    git \
    && rm -rf /var/cache/apk/*

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Clone Prometheus
RUN git clone --depth 1 "https://github.com/prometheus-lua/Prometheus.git" prometheus

COPY bot.js ./

ENV PROMETHEUS_PATH=/app/prometheus
ENV LUA_PATH=/usr/bin/lua5.1
ENV NODE_ENV=production

RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup && \
    chown -R appuser:appgroup /app

USER appuser

CMD ["node", "bot.js"]
