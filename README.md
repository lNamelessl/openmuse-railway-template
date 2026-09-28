# OpenMuse — Railway Template

[OpenMuse](https://github.com/CopilotKit/openmuse) is a personal AI agent with a browser, terminal, files, and persistent tasks — built by the CopilotKit team. This repository packages it for one-click deployment on [Railway](https://railway.app).

> **Dev-preview disclosure:** OpenMuse upstream is in Alpha and moves fast. This template builds upstream at a **pinned commit** (`34b15bc80340e582fb8c25573646cfb0bbc5184d`, 2026-09-26) plus a one-line same-origin patch, so deploys are reproducible even while upstream changes.

## What gets deployed

| Service | What it is | Notes |
|---|---|---|
| `openmuse` | Node API + web UI in one container (nginx serves the web build and proxies `/api` to the API on loopback) | Volume at `/data` (PGlite database, files, signing key). Healthcheck: `/api/health`. |
| `browser-worker` *(optional)* | Playwright/Chromium browser service | Private network only. Delete this service if you don't need the browser tool. |

The task worker runs **in-process** by default (`TASK_WORKER_ENABLED=true`). OpenMuse's embedded Postgres (PGlite) cannot be opened by multiple processes, so keep the main service at a single replica.

## The one required credential: CopilotKit Intelligence key

Every OpenMuse mode requires a server-only **CopilotKit Intelligence project key** — the deploy form will ask for it:

1. Run `npx copilotkit@latest login` and sign in (free).
2. Run `npx copilotkit@latest project select` and create/select a project.
3. Copy the **server key** and paste it as `CPK_INTELLIGENCE_API_KEY` in the Railway deploy form.

Keep the key server-only — never expose it client-side.

## Deploy

Click **Deploy on Railway** on the template listing. After deploy:

1. Open your Railway domain — the OpenMuse web UI loads (sample mode: fictional data, no LLM keys needed).
2. Chat works immediately in **sample mode** once the CopilotKit key is set.
3. **Use a real model (optional):** set `AGENT_BACKEND=model`, `MODEL=openai/gpt-4o` (or `anthropic/claude-*`, `google/gemini-*`), and the matching provider key (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, or `GOOGLE_API_KEY`). An OpenAI-compatible endpoint can be set with `OPENAI_BASE_URL`.
4. **Live Google workspace (optional):** set `WORKSPACE_MODE=live` plus `AGENT_BACKEND=model`, `OPENMUSE_ACCESS_KEY` (24+ random chars), `TOKEN_ENCRYPTION_KEY` (32 random bytes, base64), and `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET`. OAuth callback is `PUBLIC_API_URL + /api/google/callback`.

## Configuration reference

| Variable | Default in template | Purpose |
|---|---|---|
| `CPK_INTELLIGENCE_API_KEY` | **you supply** (required) | CopilotKit Intelligence server key — required in every mode |
| `WORKSPACE_MODE` | `sample` | `sample` (fictional data) or `live` (real Google workspace) |
| `AGENT_BACKEND` | `sample` | `sample`, `model`, or `agui` |
| `DATA_DIR` | `/data` | PGlite database + files (volume mount) |
| `PORT` / `HOST` | `8787` / `127.0.0.1` | API listens on loopback inside the container; nginx fronts it on 8080 |
| `PUBLIC_API_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public URL (OAuth callbacks) |
| `ALLOWED_ORIGINS` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Web UI origin allowlist |
| `TASK_WORKER_ENABLED` | `true` | In-process durable task worker |
| `WORKER_TOKEN` | shared secret (both services) | Browser-worker auth token (32+ chars) |
| `BROWSER_WORKER_URL` | `http://<browser-worker>:8790` | Private-network URL of the browser worker |
| `MODEL` + provider key | unset | Model backend (`AGENT_BACKEND=model`) |

## Security notes

- OpenMuse is a **single-owner, single-tenant** app — there is no multi-user auth. Anyone with your Railway domain can open the workspace; Railway domains are randomized HTTPS URLs, but treat them as secret.
- The API intentionally binds to loopback only (upstream enforces this in sample mode); nginx is the only public entry point.
- Sample mode uses fictional data and never calls a real LLM.
- The browser worker has **no public domain** — it is reachable only over Railway's private network.

## Browser worker

The optional `browser-worker` service builds from upstream `apps/worker/Dockerfile` (Playwright Chromium, port 8790). It stores browser profiles under `/data`. If you don't need the browser tool, delete the service and remove `BROWSER_WORKER_URL`/`WORKER_TOKEN` from the main service — everything else keeps working (`/api/health` then reports `browserConfigured: false`).

## Costs

- Main service (1 GB RAM): ~$10/month
- Browser worker (2 GB RAM): ~+$20/month — delete it if unused
- Sample mode: no LLM API costs. Model mode: your provider's usage.

## Local build

```bash
docker build -t openmuse-railway .
docker run -p 8080:8080 -e CPK_INTELLIGENCE_API_KEY=... -v openmuse-data:/data openmuse-railway
```

## Template internals

- `Dockerfile` — clones upstream at the pinned SHA, applies `patches/web-origin.patch`, builds server (`pnpm build:server`) and web (`pnpm build:web`), runs node API (loopback) + nginx (public 8080) via `entrypoint.sh`.
- `patches/web-origin.patch` — on web, the client targets `window.location.origin` (same-origin with the API through nginx) instead of a build-time-inlined URL. This is what makes random Railway deploy domains work without rebuilds.
- `railway.json` — Dockerfile builder, healthcheck `/api/health` (300s timeout), restart on failure, single replica.
- Upstream MIT license applies; see `LICENSE`.
