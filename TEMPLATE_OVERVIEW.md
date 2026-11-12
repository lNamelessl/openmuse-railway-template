# OpenMuse — Your Personal AI Agent, Self-Hosted

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/openmuse-template)

OpenMuse (by the CopilotKit team) is a personal AI agent with a **browser, terminal, files, and persistent tasks** — durable task plans with approvals, inline email/browser/PDF cards, and thread persistence. This template deploys the full stack in one click: the web UI + API + durable task engine in one service, plus the Playwright/Chromium browser worker on Railway's private network.

Upstream is in active development (Alpha). This template builds from a **pinned commit** of [CopilotKit/openmuse](https://github.com/CopilotKit/openmuse) (MIT) plus a small same-origin patch, so your deploy is reproducible.

## The one credential you need — before you click Deploy

Every OpenMuse mode requires a free **CopilotKit Intelligence project key** (it powers thread persistence and replay). Get it **before deploying** — the deploy form requires it and OpenMuse will not start without it, even in sample mode:

1. On your machine, run `npx copilotkit@latest login` and sign in (free; creates a CopilotKit account if you don't have one).
2. Run `npx copilotkit@latest project select` and create or select a project.
3. Copy the **server key** it prints — make sure it is the *server* key, not the public key.
4. Paste it into the Railway deploy form's `CPK_INTELLIGENCE_API_KEY` field when you click **Deploy on Railway**.

That is the only input the template asks for. The app boots in **sample mode** (fictional data, no LLM keys) so you can explore the UI, chat, tasks, files, and browser immediately.

**Deployed without the key?** The domain serves a setup page with the four steps above, and the deploy logs print the same instructions in a loud banner — the deployment stays up until the key is set. Fix: open the `openmuse` service → **Variables** → set `CPK_INTELLIGENCE_API_KEY` → the service redeploys into normal mode automatically.

## Post-deploy options (all optional)

- **Real model:** set `AGENT_BACKEND=model`, `MODEL=openai/gpt-4o` (or `anthropic/claude-*`, `google/gemini-*`), and the matching `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` / `GOOGLE_API_KEY` on the `openmuse` service. OpenAI-compatible endpoints work via `OPENAI_BASE_URL`.
- **Live Google workspace:** set `WORKSPACE_MODE=live` plus `AGENT_BACKEND=model`, `OPENMUSE_ACCESS_KEY` (24+ random chars), `TOKEN_ENCRYPTION_KEY` (32 random bytes, base64), and `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET`. OAuth callback: `PUBLIC_API_URL + /api/google/callback`.
- **RAM:** both services run on Railway's default elastic compute — memory scales with actual usage. The browser worker idles at roughly 100-200 MB; Chromium draws extra only while a browsing session runs. No manual RAM setup needed; cap it lower in the worker's settings only if you want a hard limit.
- **No browser tool?** Delete the `browser-worker` service — the app keeps working (`/api/health` then reports `browserConfigured: false`). To re-add it later: **New Service → GitHub Repo → `lNamelessl/openmuse-railway-template`** (branch `main`), then set its **Root Directory / Settings → Builder → Root Directory** to `apps/worker`, and set the shared `WORKER_TOKEN` variable to the same value as on `openmuse` (or leave unset — both images carry an identical default).

# Deploy and Host

## About Hosting

Two services are provisioned:

- **openmuse** — the Node API (CopilotKit runtime, task engine, files, PGlite-embedded Postgres) with in-process task worker, fronted by nginx which serves the React Native web build and proxies `/api` same-origin. A Railway volume is mounted at `/data` for the database, files, and signing key; the healthcheck is `GET /api/health`; restarts are automatic on failure. Threads, tasks, and uploads persist across deploys.
- **browser-worker** — the Playwright/Chromium browser service from upstream `apps/worker`, reachable only on Railway's project-private network (no public domain), storing browser profiles under `/data`. Delete this service if you don't need the browser tool; everything else keeps working.

Security notes: OpenMuse is a single-owner app without multi-user auth — treat your Railway domain as a secret. The API binds to loopback inside the container; nginx is the only public entry point over HTTPS.

## Why Deploy

- **One click, one prompt:** the only deploy input is the CopilotKit key — domain-derived config (`PUBLIC_API_URL`, `ALLOWED_ORIGINS`, worker URL/token) is derived at runtime, so nothing else to configure.
- **Deployed without the key? You're guided, not stranded:** the domain serves a setup page and the logs print the fix; set the variable and the service redeploys into normal mode on its own.
- **Random-domain safe:** the web build targets its own origin, so Railway's generated domains work without rebuilds.
- **Reproducible alpha tracking:** builds pin an upstream commit, so redoes are identical; bump the pin when you want updates.
- **Private browser worker:** Chromium runs isolated on the private network — verified working on Railway.
- **Persistent by default:** PGlite + files live on a Railway volume; threads, tasks, and history survive restarts and redeploys.

## Common Use Cases

- **Personal research agent** — browse, read, and summarize the web with a persistent Chromium profile and durable task plans you can approve.
- **File workflows** — upload PDFs, fill forms, and draft documents inline; files persist on the volume.
- **Email and calendar copilot** — switch to live mode with Google OAuth to draft mail and manage events with approvals.
- **Self-hosted CopilotKit playground** — a full AG-UI/CopilotKit runtime to develop and test your own agents against.
- **Team demo** — show stakeholders a working agent product in minutes without touching Docker locally.

## Dependencies for

### Deployment Dependencies

- A free **CopilotKit** account for the Intelligence server key — obtain it **before deploying**: `npx copilotkit@latest login` → `npx copilotkit@latest project select` → copy the **server key** → paste into the deploy form's `CPK_INTELLIGENCE_API_KEY` field. Required in every mode (sample included). If you deploy without it, the domain serves a setup page with these steps (and the deploy logs print them too).
- A public **GitHub** connection — the template builds from `lNamelessl/openmuse-railway-template`, which pins upstream `CopilotKit/openmuse` (MIT) at commit `a4944f4c471d3dc93b8bfc060b5da309b5216ab2` (2026-10-26).
- Optional: an LLM provider key (OpenAI, Anthropic, or Google) for `AGENT_BACKEND=model`; Google OAuth credentials for live workspace mode.
- Optional: the `browser-worker` service — delete it if you don't need the browser tool (re-add steps under "Post-deploy options").
