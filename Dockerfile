FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Base tools
RUN apt-get update && apt-get install -y \
    sudo vim jq git curl wget ca-certificates gnupg \
    build-essential pkg-config libssl-dev \
    python3 python3-pip python3-venv python3-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Node.js 20
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y gh \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --break-system-packages --upgrade pip

# Create user FIRST so subsequent installs land in the right place
RUN useradd -m -s /bin/bash -d /home/node opencode

# Sudoers for opencode
RUN echo 'opencode ALL=(ALL) NOPASSWD: /usr/bin/apt-get *, /usr/bin/dpkg *' \
        > /etc/sudoers.d/opencode \
    && chmod 440 /etc/sudoers.d/opencode

# Persistent apt dirs (with the partial subdirs apt requires)
RUN mkdir -p /home/node/var/cache/apt/archives/partial \
             /home/node/var/lib/apt/lists/partial \
    && echo 'Dir::Cache "/home/node/var/cache/apt";' \
            'Dir::State::Lists "/home/node/var/lib/apt/lists";' \
        > /etc/apt/apt.conf.d/99persistent

# Env for the opencode user
ENV OPENCODE_HOME=/home/node \
    NPM_CONFIG_PREFIX=/home/node/.npm-global \
    CARGO_HOME=/home/node/.cargo \
    RUSTUP_HOME=/home/node/.rustup \
    PATH=/home/node/.npm-global/bin:/home/node/.cargo/bin:${PATH}

# Rust as opencode (so it installs straight into /home/node/.cargo)
USER opencode
RUN mkdir -p /home/node/.npm-global /home/node/.cargo /home/node/.rustup \
             /home/node/.cache /home/node/kimaki_workplace \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --default-toolchain stable --no-modify-path

# Global npm install as opencode into NPM_CONFIG_PREFIX
RUN npm i -g opencode-ai

# Fix ownership of everything under /home/node
USER root
RUN chown -R opencode:opencode /home/node

USER opencode
WORKDIR /home/node/kimaki_workplace

# KIMAKI_BOT_TOKEN is expected to be passed via `docker run -e`
ENTRYPOINT ["npx", "-y", "kimaki@latest"]