# OpenMuse — Your Personal AI Agent, Self-Hosted

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/pvdNW4)

OpenMuse (by the CopilotKit team) is a personal AI agent with a **browser, terminal, files, and persistent tasks** — durable task plans with approvals, inline email/browser/PDF cards, and thread persistence. This template deploys the full stack in one click: the web UI + API + durable task engine in one service, plus the Playwright/Chromium browser worker on Railway's private network.

Upstream is in active development (Alpha). This template builds from a **pinned commit** of [CopilotKit/openmuse](https://github.com/CopilotKit/openmuse) (MIT) plus a small same-origin patch, so your deploy is reproducible.

## The one credential you need

Every OpenMuse mode requires a free **CopilotKit Intelligence project key** (it powers thread persistence and replay). The deploy form asks for it as `CPK_INTELLIGENCE_API_KEY`:

1. Run `npx copilotkit@latest login` and sign in (free).
2. Run `npx copilotkit@latest project select` and create/select a project.
3. Copy the **server key** and paste it into the deploy form.

That is the only input the template asks for. The app boots in **sample mode** (fictional data, no LLM keys) so you can explore the UI, chat, tasks, files, and browser immediately.

## Post-deploy options (all optional)

- **Real model:** set `AGENT_BACKEND=model`, `MODEL=openai/gpt-4o` (or `anthropic/claude-*`, `google/gemini-*`), and the matching `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` / `GOOGLE_API_KEY` on the `openmuse` service. OpenAI-compatible endpoints work via `OPENAI_BASE_URL`.
- **Live Google workspace:** set `WORKSPACE_MODE=live` plus `AGENT_BACKEND=model`, `OPENMUSE_ACCESS_KEY` (24+ random chars), `TOKEN_ENCRYPTION_KEY` (32 random bytes, base64), and `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET`. OAuth callback: `PUBLIC_API_URL + /api/google/callback`.
- **RAM:** for heavy browsing sessions raise the `browser-worker` service to 2 GB RAM in its Railway settings.

# Deploy and Host

## About Hosting

Two services are provisioned:

- **openmuse** — the Node API (CopilotKit runtime, task engine, files, PGlite-embedded Postgres) with in-process task worker, fronted by nginx which serves the React Native web build and proxies `/api` same-origin. A Railway volume is mounted at `/data` for the database, files, and signing key; the healthcheck is `GET /api/health`; restarts are automatic on failure. Threads, tasks, and uploads persist across deploys.
- **browser-worker** — the Playwright/Chromium browser service from upstream `apps/worker`, reachable only on Railway's project-private network (no public domain), storing browser profiles under `/data`. Delete this service if you don't need the browser tool; everything else keeps working.

Security notes: OpenMuse is a single-owner app without multi-user auth — treat your Railway domain as a secret. The API binds to loopback inside the container; nginx is the only public entry point over HTTPS.

## Why Deploy

- **One click, one prompt:** the only deploy input is the CopilotKit key — domain-derived config (`PUBLIC_API_URL`, `ALLOWED_ORIGINS`, worker URL/token) is derived at runtime, so nothing else to configure.
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

- A free **CopilotKit** account for the Intelligence server key (`npx copilotkit@latest login` → `project select`) — required in every mode, supplied in the deploy form.
- A public **GitHub** connection — the template builds from `lNamelessl/openmuse-railway-template`, which pins upstream `CopilotKit/openmuse` (MIT) at commit `34b15bc80340e582fb8c25573646cfb0bbc5184d`.
- Optional: an LLM provider key (OpenAI, Anthropic, or Google) for `AGENT_BACKEND=model`; Google OAuth credentials for live workspace mode.
- Optional: raise `browser-worker` RAM to 2 GB for heavy browsing.
