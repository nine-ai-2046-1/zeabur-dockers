FROM node:22-bookworm-slim

# ---------- build args ----------
ARG OPENCODE_VERSION=1.4.3

# ---------- base env ----------
ENV DEBIAN_FRONTEND=noninteractive \
    HOME=/home/node \
    NPM_CONFIG_PREFIX=/opt/npm-global \
    PATH=/opt/npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

# ---------- OS packages (keep minimal but dev-capable) ----------
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg \
      dumb-init \
      git jq vim \
      python3 python3-venv python3-pip \
      build-essential pkg-config \
      ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# ---------- gh CLI ----------
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# ---------- npm global tools (installed once) ----------
# agent-browser install/download happens at runtime: `agent-browser install` [4](https://agent-browser.dev/installation)
# Playwright OS deps installer: `npx playwright install-deps chromium` [2](https://zeabur.com/docs/en-US/deploy/methods/custom-docker-image)[3](https://playwright.dev/docs/browsers)
RUN mkdir -p /opt/npm-global && chown -R node:node /opt/npm-global \
    && npm install -g \
        opencode-ai@${OPENCODE_VERSION} \
        agent-browser \
        playwright

# Install Playwright system dependencies now (smaller than downloading browsers)
RUN npx playwright install-deps chromium

# ---------- workspace (for Zeabur volume) ----------
RUN mkdir -p /workspace \
    && chown -R node:node /workspace

# ---------- rust toolchain (per-user) ----------
USER node
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH=/home/node/.cargo/bin:${PATH}

WORKDIR /workspace

# dumb-init as PID 1 for proper signal forwarding & zombie reaping [8](https://github.com/Yelp/dumb-init)[9](https://deepwiki.com/Yelp/dumb-init/2-usage)
ENTRYPOINT ["dumb-init", "--"]
CMD ["bash", "-lc", "sleep infinity"]
