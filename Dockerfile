FROM node:18-alpine

# Install Lua51 (lebih compatible daripada LuaJIT untuk beberapa kasus)
# Atau gunakan LuaJIT - keduanya bisa
RUN apk add --no-cache \
    lua5.1 \
    luajit \
    git \
    && rm -rf /var/cache/apk/*

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

# Clone Prometheus
RUN git clone --depth 1 https://github.com/levno-710/Prometheus.git prometheus

COPY server.js ./

# Environment - gunakan lua5.1 atau luajit
ENV PORT=3000
ENV LUA_PATH=/usr/bin/lua5.1
# ATAU: ENV LUA_PATH=/usr/bin/luajit

ENV NODE_ENV=production

EXPOSE 3000

RUN adduser -D appuser && chown -R appuser:appuser /app
USER appuser

CMD ["node", "server.js"]
