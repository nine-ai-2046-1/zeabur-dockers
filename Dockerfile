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

RUN npm i -g opencode-ai

RUN mkdir -p /home/node && chown -R root:root /home/node && chmod 755 /home/node

RUN ln -sf /home/node/.npm /root/.npm \
    && ln -sf /home/node/.cache /root/.cache \
    && ln -sf /home/node/.cargo /root/.cargo \
    && mkdir -p /home/node/.npm /home/node/.cache /home/node/.cargo

RUN echo 'opencode ALL=(ALL) NOPASSWD: /usr/bin/apt-get *, /usr/bin/dpkg *' > /etc/sudoers.d/opencode && chmod 440 /etc/sudoers.d/opencode

RUN mkdir -p /home/node/apt /home/node/var/cache/apt /home/node/var/lib/apt

RUN echo 'Dir::Cache "/home/node/var/cache/apt"; Dir::State::Lists "/home/node/var/lib/apt";' > /etc/apt/apt.conf.d/99persistent

RUN useradd -m -s /bin/bash opencode 2>/dev/null || true

ENV OPENCODE_HOME=/home/node NPM_CONFIG_PREFIX=/home/node CARGO_HOME=/home/node/.cargo


RUN mkdir -p /home/node/kimaki_workplace
WORKDIR /home/node/kimaki_workplace
ENTRYPOINT ["sh", "-c"]
CMD ["KIMAKI_BOT_TOKEN=\"${KIMAKI_BOT_TOKEN}\" npx -y kimaki@latest"]
