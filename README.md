# OpenMuse — Railway Template

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/openmuse-template)

[OpenMuse](https://github.com/CopilotKit/openmuse) is a personal AI agent with a browser, terminal, files, and persistent tasks — built by the CopilotKit team. This repository packages it for one-click deployment on [Railway](https://railway.app).

> **Dev-preview disclosure:** OpenMuse upstream is in Alpha and moves fast. This template builds upstream at a **pinned commit** (`a4944f4c471d3dc93b8bfc060b5da309b5216ab2`, 2026-10-26) plus a one-line same-origin patch, so deploys are reproducible even while upstream changes.

## What gets deployed

| Service | What it is | Notes |
|---|---|---|
| `openmuse` | Node API + web UI in one container (nginx serves the web build and proxies `/api` to the API on loopback) | Volume at `/data` (PGlite database, files, signing key). Healthcheck: `/api/health`. |
| `browser-worker` *(optional)* | Playwright/Chromium browser service | Private network only. Delete this service if you don't need the browser tool. |

The task worker runs **in-process** by default (`TASK_WORKER_ENABLED=true`). OpenMuse's embedded Postgres (PGlite) cannot be opened by multiple processes, so keep the main service at a single replica.

## The one required credential: CopilotKit Intelligence key

Every OpenMuse mode requires a server-only **CopilotKit Intelligence project key** — the deploy form will ask for it. Get it **before** you deploy (takes ~2 minutes, free):

1. On your machine, run `npx copilotkit@latest login` and sign in (free; creates a CopilotKit account if you don't have one).
2. Run `npx copilotkit@latest project select` and create or select a project.
3. Copy the **server key** it prints and paste it as `CPK_INTELLIGENCE_API_KEY` in the Railway deploy form.

Keep the key server-only — never expose it client-side.

**What if you deploy without the key?** OpenMuse cannot start without it — even in sample mode. The container enters **setup mode**: the domain serves a step-by-step page with the exact instructions above, and the deploy logs print the same instructions in a loud banner. The deployment stays up (a setup page is not a broken deploy) until you set the variable — then it redeploys into normal mode automatically.

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
- The browser worker has **no public domain** — it is reachable only over Railway's project-private network. The template ships a default `WORKER_TOKEN` baked identically into both images (Railway private networking is project-scoped, so this is defense-in-depth). To harden, set your own random `WORKER_TOKEN` (32+ chars) on **both** services post-deploy.

## Browser worker

The `browser-worker` service builds from `apps/worker/Dockerfile` in this repo (mirrors upstream `apps/worker/Dockerfile`: Playwright Chromium, port 8790, profiles under `/data`) and is reachable only on Railway's private network. It runs on Railway's default elastic compute — Chromium draws only what a browsing session needs, and the idle worker sits at roughly 100-200 MB.

- **Don't need the browser tool?** Delete the `browser-worker` service — everything else keeps working (`/api/health` then reports `browserConfigured: false`).
- **Need it back later?** Add a service from this repo (`lNamelessl/openmuse-railway-template`, branch `main`) and set its **Root Directory** to `apps/worker`; then set the shared `WORKER_TOKEN` variable on it to the same value as on `openmuse` (or leave unset — both images carry an identical default).

## Costs

- Main service: ~$10/month at typical 1 GB usage (elastic)
- Browser worker: a few $/month idle (~100-200 MB); more only while browsing sessions run — delete it if unused
- Sample mode: no LLM API costs. Model mode: your provider's usage.

## Local build

```bash
docker build -t openmuse-railway .
docker run -p 8080:8080 -e CPK_INTELLIGENCE_API_KEY=... -v openmuse-data:/data openmuse-railway
```

## Template internals

- `Dockerfile` — clones upstream at the pinned SHA, applies `patches/web-origin.patch`, builds server (`pnpm build:server`) and web (`pnpm build:web`), runs node API (loopback) + nginx (public 8080) via `entrypoint.sh`.
- `apps/worker/Dockerfile` — the browser worker: same pinned upstream commit, Playwright base image, port 8790, `/data` profiles.
- `patches/web-origin.patch` — on web, the client targets `window.location.origin` (same-origin with the API through nginx) instead of a build-time-inlined URL. This is what makes random Railway deploy domains work without rebuilds.
- `entrypoint.sh` — derives `PUBLIC_API_URL`, `ALLOWED_ORIGINS`, and `BROWSER_WORKER_URL` from Railway's runtime environment (no domain variables needed in the template), forces the API onto loopback 8787, and runs a watchdog so an API crash takes the container down.
- Service settings (healthcheck `/api/health`, restart policy, worker root directory) are configured on the Railway services themselves.
