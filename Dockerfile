# syntax=docker/dockerfile:1
# OpenMuse Railway template — builds the upstream pnpm monorepo at a pinned commit.
# Upstream: https://github.com/CopilotKit/openmuse (MIT)
ARG UPSTREAM_SHA=34b15bc80340e582fb8c25573646cfb0bbc5184d

# ---------- build stage: server (tsc) + web (expo export) ----------
FROM node:24-slim AS build
ARG UPSTREAM_SHA
ENV CI=1 EXPO_NO_TELEMETRY=1 DO_NOT_TRACK=1
RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/CopilotKit/openmuse.git /src \
 && cd /src && git checkout --detach "${UPSTREAM_SHA}" \
 && git config user.email "template@railway.local" && git config user.name "Railway Template"

# Same-origin patch: on web, the client targets window.location.origin
# (nginx serves the static bundle and proxies /api to the loopback API).
COPY patches /patches
RUN cd /src && git apply --whitespace=nowarn /patches/*.patch

RUN corepack enable \
 && (corepack prepare pnpm@11.19.0 --activate || npm install -g pnpm@11.19.0)

WORKDIR /src
RUN pnpm install --frozen-lockfile
RUN pnpm build:server
RUN pnpm build:web
# Keep the runtime image lean: no git history needed after patching.
RUN rm -rf /src/.git /patches

# ---------- runtime stage: node API on loopback + nginx on 8080 ----------
FROM node:24-slim AS runtime
RUN apt-get update \
 && apt-get install -y --no-install-recommends nginx \
 && rm -rf /var/lib/apt/lists/* \
 && rm -f /etc/nginx/sites-enabled/default
COPY nginx.conf /etc/nginx/nginx.conf
COPY entrypoint.sh /app/entrypoint.sh
COPY --from=build /src /src

ENV NODE_ENV=production \
    DO_NOT_TRACK=1 \
    COPILOTKIT_TELEMETRY_DISABLED=true \
    DATA_DIR=/data \
    PORT=8787 \
    HOST=127.0.0.1

RUN chmod +x /app/entrypoint.sh && mkdir -p /data
WORKDIR /src
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=5s --start-period=60s --retries=5 \
  CMD node -e "fetch('http://127.0.0.1:8080/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
ENTRYPOINT ["/app/entrypoint.sh"]
