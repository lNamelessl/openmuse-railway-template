# syntax=docker/dockerfile:1
# OpenMuse browser-worker for Railway — mirrors upstream apps/worker/Dockerfile
# (https://github.com/CopilotKit/openmuse, MIT) but sources the worker files from
# the same pinned upstream commit the main service builds from.
ARG UPSTREAM_SHA=34b15bc80340e582fb8c25573646cfb0bbc5184d

FROM mcr.microsoft.com/playwright:v1.62.1-noble
ARG UPSTREAM_SHA
ENV CI=1 DO_NOT_TRACK=1
USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*
RUN git clone https://github.com/CopilotKit/openmuse.git /upstream \
 && cd /upstream && git checkout --detach "${UPSTREAM_SHA}"
WORKDIR /app
RUN cp -r /upstream/apps/worker/package.json /upstream/apps/worker/package-lock.json \
      /upstream/apps/worker/src ./ \
 && npm ci --omit=dev --ignore-scripts \
 && mkdir /data && chown pwuser:pwuser /data /app \
 && rm -rf /upstream /var/lib/apt/lists/*
USER pwuser
ENV NODE_ENV=production WORKER_DATA_DIR=/data WORKER_HOST=0.0.0.0
EXPOSE 8790
ENV WORKER_TOKEN=9bd2fae8eee175848850209147dd6e04ecdce1914e5c0b0940ef9a71d78debf4
CMD ["node", "--experimental-strip-types", "src/index.ts"]
