FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    sudo vim jq git curl wget ca-certificates gnupg build-essential pkg-config libssl-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y \
    python3 python3-pip python3-venv python3-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --break-system-packages --upgrade pip

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
ENV PATH="/root/.cargo/bin:${PATH}"

RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y gh \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# --- FIX: set up a proper npm prefix BEFORE any npm install ---
ENV OPENCODE_HOME=/home/node \
    NPM_CONFIG_PREFIX=/home/node/.npm-global \
    CARGO_HOME=/home/node/.cargo \
    PATH=/home/node/.npm-global/bin:/root/.cargo/bin:${PATH}

RUN mkdir -p /home/node/.npm-global/lib \
             /home/node/.npm-global/bin \
             /home/node/.npm \
             /home/node/.cache \
             /home/node/.cargo \
             /home/node/kimaki_workplace

# Now this install lands in /home/node/.npm-global/{lib,bin}
RUN npm i -g opencode-ai

# apt persistence dirs (need the partial/ subdirs or apt-get update fails)
RUN mkdir -p /home/node/var/cache/apt/archives/partial \
             /home/node/var/lib/apt/lists/partial \
    && echo 'Dir::Cache "/home/node/var/cache/apt"; Dir::State::Lists "/home/node/var/lib/apt/lists";' \
        > /etc/apt/apt.conf.d/99persistent

RUN useradd -m -s /bin/bash -d /home/node opencode 2>/dev/null || true \
    && chown -R opencode:opencode /home/node

RUN echo 'opencode ALL=(ALL) NOPASSWD: /usr/bin/apt-get *, /usr/bin/dpkg *' \
        > /etc/sudoers.d/opencode \
    && chmod 440 /etc/sudoers.d/opencode

WORKDIR /home/node/kimaki_workplace

# KIMAKI_BOT_TOKEN is already in env via `-e KIMAKI_BOT_TOKEN=...`
ENTRYPOINT ["npx", "-y", "kimaki@latest"]