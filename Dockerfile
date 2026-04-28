FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-color

RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo vim jq git curl wget ca-certificates gnupg build-essential pkg-config libssl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv python3-dev python3-setuptools \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --upgrade pip setuptools wheel

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile default
ENV PATH="/root/.cargo/bin:${PATH}"

RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g opencode

RUN mkdir -p /home/node && chown -R root:root /home/node && chmod 755 /home/node

RUN ln -sf /home/node/.npm /root/.npm \
    && ln -sf /home/node/.cache /root/.cache \
    && ln -sf /home/node/.cargo /root/.cargo \
    && mkdir -p /home/node/.npm /home/node/.cache /home/node/.cargo

RUN echo "opencode ALL=(ALL) NOPASSWD: /usr/bin/apt-get *, /usr/bin/dpkg *, /usr/bin/snap *" > /etc/sudoers.d/opencode && chmod 440 /etc/sudoers.d/opencode

RUN mkdir -p /home/node/apt /home/node/var/cache/apt /home/node/var/lib/apt

RUN echo 'Dir::Cache "/home/node/var/cache/apt"; Dir::State::Lists "/home/node/var/lib/apt";' > /etc/apt/apt.conf.d/99persistent

RUN useradd -m -s /bin/bash opencode 2>/dev/null || true

ENV OPENCODE_HOME=/home/node NPM_CONFIG_PREFIX=/home/node CARGO_HOME=/home/node/.cargo RUSTUP_HOME=/home/node/.rustup

RUN chmod 755 /home/node

WORKDIR /workspace

CMD ["/bin/bash", "-c", "echo 'Container ready.' && exec /bin/bash"]