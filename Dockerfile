FROM ubuntu:24.04

# =========================
# Base environment
# =========================
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# =========================
# Build arguments
# =========================
ARG USERNAME=dev
ARG UID=1000
ARG GID=1000

ARG INSTALL_BRAVE=1
ARG INSTALL_TAILSCALE=1
ARG INSTALL_AGENT_BROWSER=1
ARG INSTALL_PLAYWRIGHT=1
ARG DOWNLOAD_BROWSERS=0

# =========================
# Base packages
# =========================
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    tzdata \
    sudo \
    git \
    vim \
    jq \
    ffmpeg \
    python3 \
    python3-pip \
    python3-venv \
    pipx \
    && rm -rf /var/lib/apt/lists/*

# =========================
# GitHub CLI (gh)
# =========================
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# =========================
# Node.js LTS
# =========================
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# =========================
# Google Workspace CLI
# =========================
RUN npm install -g @googleworkspace/cli

# =========================
# yt-dlp
# =========================
RUN curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
      -o /usr/local/bin/yt-dlp && \
    chmod a+rx /usr/local/bin/yt-dlp

# =========================
# OPTIONAL: Brave
# =========================
RUN if [ "$INSTALL_BRAVE" = "1" ]; then \
      curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
        https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg && \
      curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources \
        https://brave-browser-apt-release.s3.brave.com/brave-browser.sources && \
      apt-get update && apt-get install -y brave-browser && \
      rm -rf /var/lib/apt/lists/* ; \
    fi

# =========================
# OPTIONAL: Tailscale (install only)
# =========================
RUN if [ "$INSTALL_TAILSCALE" = "1" ]; then \
      curl -fsSL https://tailscale.com/install.sh | sh ; \
    fi

# =========================
# agent-browser (no browser download)
# =========================
RUN if [ "$INSTALL_AGENT_BROWSER" = "1" ]; then \
      npm install -g agent-browser ; \
      if [ "$DOWNLOAD_BROWSERS" = "1" ]; then \
        agent-browser install --with-deps ; \
      fi ; \
    fi

# =========================
# Playwright (CLI only)
# =========================
RUN if [ "$INSTALL_PLAYWRIGHT" = "1" ]; then \
      npm install -g playwright ; \
      if [ "$DOWNLOAD_BROWSERS" = "1" ]; then \
        npx playwright install-deps && npx playwright install ; \
      fi ; \
    fi

# =========================
# ✅ SAFE USER CREATION (FIXES GID 1000 ERROR)
# =========================
RUN set -eux; \
    if ! getent group "${GID}" >/dev/null; then \
        groupadd --gid "${GID}" "${USERNAME}"; \
    else \
        echo "Group with GID ${GID} already exists"; \
    fi; \
    if ! id -u "${USERNAME}" >/dev/null 2>&1; then \
        useradd --uid "${UID}" --gid "${GID}" -m -s /bin/bash "${USERNAME}"; \
    fi; \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME}; \
    chmod 0440 /etc/sudoers.d/${USERNAME}

# =========================
# Rust (per-user)
# =========================
USER ${USERNAME}
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y

ENV PATH="/home/${USERNAME}/.cargo/bin:${PATH}"
WORKDIR /home/${USERNAME}

CMD ["/bin/bash"]
