// OpenMuse Railway template setup server.
// Served when CPK_INTELLIGENCE_API_KEY is missing (see entrypoint.sh): the real
// API refuses to boot without the key, so this page replaces it on the public
// port and walks the deployer through getting one. /api/health answers 200 with
// a JSON body describing the state: the deployment is intentionally considered
// healthy while waiting for the key — a failed healthcheck would get the
// deployment killed minutes after deploy, making this page unreachable exactly
// when it is needed, and a keyless deploy should not count as a broken deploy.
// Setting the variable redeploys the service into normal mode and this server
// never runs again.
const http = require("node:http");

const port = Number(process.env.PORT || 8080);
const host = process.env.SETUP_HOST || "0.0.0.0";

const page = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>OpenMuse — setup: CopilotKit key required</title>
<style>
  :root { color-scheme: dark; }
  body { margin: 0; min-height: 100vh; display: grid; place-items: center;
         background: #0b0d12; color: #e8eaf0;
         font-family: ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
  main { max-width: 46rem; padding: 3rem 2rem; line-height: 1.6; }
  h1 { font-size: 1.6rem; margin: .75rem 0 .25rem; }
  p.sub { color: #9aa3b2; margin-top: 0; }
  code, pre { background: #161a23; border: 1px solid #2a3140; border-radius: 8px; }
  code { padding: .15rem .4rem; font-size: .95em; }
  ol { padding-left: 1.4rem; }
  ol li { margin: .8rem 0; }
  .badge { display: inline-block; background: #3b2a1d; color: #ffd9a8; border: 1px solid #6b4a27;
           border-radius: 999px; padding: .2rem .8rem; font-size: .8rem; letter-spacing: .04em;
           text-transform: uppercase; }
  .note { color: #9aa3b2; font-size: .9rem; }
  a { color: #8ab4ff; }
</style>
</head>
<body>
<main>
  <span class="badge">one step left</span>
  <h1>OpenMuse needs a CopilotKit Intelligence key</h1>
  <p class="sub"><code>CPK_INTELLIGENCE_API_KEY</code> is not set on this service. OpenMuse
  requires this free key in every mode (including sample mode) — it powers thread persistence
  and replay, server-side only.</p>
  <ol>
    <li>On your machine, run <code>npx copilotkit@latest login</code> and sign in (free).</li>
    <li>Run <code>npx copilotkit@latest project select</code> and create or select a project.</li>
    <li>Copy the <strong>server key</strong> it prints (server-only — never expose it client-side).</li>
    <li>In Railway, open this service &rarr; <strong>Variables</strong> &rarr; set
      <code>CPK_INTELLIGENCE_API_KEY</code> to the server key. The service redeploys
      automatically and this page disappears.</li>
  </ol>
  <p class="note">Until the key is set, OpenMuse itself stays stopped and this page stands in
  for it — the deploy logs carry the same instructions. Docs:
  <a href="https://docs.copilotkit.ai/intelligence/connect-your-runtime">CopilotKit Intelligence — connect your runtime</a>.</p>
</main>
</body>
</html>`;

http
  .createServer((req, res) => {
    const url = (req.url || "/").split("?")[0];
    if (url === "/api/health") {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(
        JSON.stringify({
          ok: true,
          setup: true,
          message:
            "CPK_INTELLIGENCE_API_KEY is not set — OpenMuse is not running yet. Open this domain in a browser for setup instructions.",
        }),
      );
      return;
    }
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    res.end(page);
  })
  .listen(port, host, () => {
    console.log(`[openmuse] setup mode: serving setup instructions on port ${port}`);
  });
