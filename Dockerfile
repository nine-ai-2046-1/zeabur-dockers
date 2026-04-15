bash -lc '
set -euo pipefail

echo "[startup] booting..."

# ---- persistent workspace layout (Zeabur Volume recommended at /workspace) ----
mkdir -p /workspace/{home,cache,logs,downloads,ms-playwright,agent-browser-profile}
chmod 700 /workspace/home /workspace/cache || true

# Make common tools write caches into the mounted volume (best-effort)
export HOME=/workspace/home
export XDG_CACHE_HOME=/workspace/cache
export XDG_CONFIG_HOME=/workspace/home/.config
export XDG_DATA_HOME=/workspace/home/.local/share

# ---- agent-browser config (persist profile/downloads; set args suitable for containers) ----
# agent-browser supports config file + env overrides and fields like profile/downloadPath/args [6](https://agent-browser.dev/configuration)
cat >/workspace/agent-browser.json <<'"'"'JSON'"'"'
{
  "profile": "/workspace/agent-browser-profile",
  "downloadPath": "/workspace/downloads",
  "args": "--no-sandbox,--disable-dev-shm-usage",
  "ignoreHttpsErrors": true
}
JSON
export AGENT_BROWSER_CONFIG=/workspace/agent-browser.json

# ---- 1) Install agent-browser Chrome for Testing (once) ----
# agent-browser install downloads Chrome (first time) [4](https://agent-browser.dev/installation)[5](https://deepwiki.com/vercel-labs/agent-browser/2.1-installation)
if [ ! -f /workspace/.agent-browser-installed ]; then
  echo "[startup] agent-browser: installing Chrome (first run only)..."
  agent-browser install
  touch /workspace/.agent-browser-installed
else
  echo "[startup] agent-browser: already installed, skip."
fi

# ---- 2) Install Playwright browsers into persistent path (once) ----
# Playwright install command is: `npx playwright install <browser>` [2](https://zeabur.com/docs/en-US/deploy/methods/custom-docker-image)[3](https://playwright.dev/docs/browsers)
# PLAYWRIGHT_BROWSERS_PATH is a commonly used env var to control browser location (community-documented) [10](https://stackoverflow.com/questions/64262622/playwright-python-advanced-setup)[11](https://github.com/microsoft/playwright/issues/22146)
export PLAYWRIGHT_BROWSERS_PATH=/workspace/ms-playwright
if [ ! -d /workspace/ms-playwright/chromium* ]; then
  echo "[startup] playwright: installing chromium (first run only)..."
  npx playwright install chromium
else
  echo "[startup] playwright: chromium already present, skip."
fi

# ---- 3) Optional background processes (user-controlled) ----
pids=()

if [ -n "${OPENCODE_BG_CMD:-}" ]; then
  echo "[startup] starting OPENCODE_BG_CMD in background..."
  bash -lc "$OPENCODE_BG_CMD" >>/workspace/logs/opencode.log 2>&1 &
  pids+=($!)
fi

if [ -n "${RUST_BG_CMD:-}" ]; then
  echo "[startup] starting RUST_BG_CMD in background..."
  bash -lc "$RUST_BG_CMD" >>/workspace/logs/rust.log 2>&1 &
  pids+=($!)
fi

# ---- 4) Keep container alive & fail fast if a bg process exits ----
if [ "${#pids[@]}" -gt 0 ]; then
  echo "[startup] background PIDs: ${pids[*]}"
  wait -n "${pids[@]}"
  echo "[startup] a background process exited; exiting container."
  exit 1
else
  echo "[startup] no background cmd configured; keeping container alive."
  tail -f /dev/null
fi
'
