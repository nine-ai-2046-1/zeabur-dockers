FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# ---- build toggles (default: install all, but skip heavy browser downloads) ----
ARG USERNAME=dev
ARG UID=1000
ARG GID=1000

# whether to install optional components
ARG INSTALL_BRAVE=1
ARG INSTALL_TAILSCALE=1
ARG INSTALL_AGENT_BROWSER=1
ARG INSTALL_PLAYWRIGHT=1
ARG DOWNLOAD_BROWSERS=0   # 0 = do NOT download chromium/playwright browsers during build

# ---- base packages (keep apt usable) ----
RUN apt-get update && apt-get install -y \
    ca-certificates curl gnupg lsb-release tzdata \
    sudo git vim jq \
    ffmpeg \
    python3 python3-pip python3-venv pipx \
    && rm -rf /var/lib/apt/lists/*

# ---- GitHub CLI (gh) via official repo (as in your earlier requirement) ----
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update && apt-get install -y gh \
 && rm -rf /var/lib/apt/lists/*

# ---- Node.js (needed for gws + agent-browser + playwright) ----
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
 && apt-get install -y nodejs \
 && rm -rf /var/lib/apt/lists/*

# ---- gws: Google Workspace CLI (npm global) ----
# npm method bundles native binaries; official npm install command:
# npm install -g @googleworkspace/cli  [6](https://www.npmjs.com/package/@googleworkspace/cli)
RUN npm install -g @googleworkspace/cli

# ---- yt-dlp: install release binary into PATH ----
# Official wiki shows curl download latest release binary and chmod. [5](https://github.com/yt-dlp/yt-dlp/wiki/Installation)
RUN curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp \
 && chmod a+rx /usr/local/bin/yt-dlp

# ---- Brave (optional) ----
# Brave official Ubuntu/Debian steps: keyring + .sources + apt install brave-browser [1](https://brave.com/linux/)
RUN if [ "$INSTALL_BRAVE" = "1" ]; then \
      apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/* ; \
      curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
        https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg ; \
      curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources \
        https://brave-browser-apt-release.s3.brave.com/brave-browser.sources ; \
      apt-get update && apt-get install -y brave-browser && rm -rf /var/lib/apt/lists/* ; \
    fi

# ---- Tailscale (optional) ----
# Official: curl -fsSL https://tailscale.com/install.sh | sh [4](https://tailscale.com/docs/install/linux)
RUN if [ "$INSTALL_TAILSCALE" = "1" ]; then \
      curl -fsSL https://tailscale.com/install.sh | sh ; \
    fi

# ---- agent-browser (optional) ----
# Official: npm install -g agent-browser && agent-browser install
# Linux deps: agent-browser install --with-deps [3](https://agent-browser.dev/installation)
RUN if [ "$INSTALL_AGENT_BROWSER" = "1" ]; then \
      npm install -g agent-browser ; \
      if [ "$DOWNLOAD_BROWSERS" = "1" ]; then \
        agent-browser install --with-deps ; \
      fi ; \
    fi

# ---- Playwright (optional) ----
# Official docs describe install via npm/yarn/pnpm, and it downloads browsers. [2](https://playwright.dev/docs/intro)
# Linux deps helper: sudo npx playwright install-deps [7](https://bing.com/search?q=Playwright+Linux+dependencies+Ubuntu+24.04+install+playwright+browsers)
RUN if [ "$INSTALL_PLAYWRIGHT" = "1" ]; then \
      npm install -g playwright ; \
      if [ "$DOWNLOAD_BROWSERS" = "1" ]; then \
        npx playwright install-deps ; \
        npx playwright install ; \
      fi ; \
    fi

# ---- create non-root user with sudo ----
RUN groupadd --gid ${GID} ${USERNAME} \
 && useradd --uid ${UID} --gid ${GID} -m -s /bin/bash ${USERNAME} \
 && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
 && chmod 0440 /etc/sudoers.d/${USERNAME}

# ---- Rust (per-user via rustup) ----
USER ${USERNAME}
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/home/${USERNAME}/.cargo/bin:${PATH}"

WORKDIR /home/${USERNAME}
CMD ["/bin/bash"]
