FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/home/node
ENV NVM_DIR=/home/node/.nvm

# Create persistent home
RUN mkdir -p /home/node

# ---- Base system packages ----
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    git \
    ca-certificates \
    jq \
    vim \
    build-essential \
    pkg-config \
    libssl-dev \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# ---- Node.js via nvm (persists in /home/node) ----
RUN curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash \
 && . "$NVM_DIR/nvm.sh" \
 && nvm install --lts \
 && nvm alias default lts/* \
 && nvm use default

ENV PATH="$NVM_DIR/versions/node/$(ls $NVM_DIR/versions/node)/bin:$PATH"

# ---- Rust via rustup (persists in /home/node) ----
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/home/node/.cargo/bin:${PATH}"

# ---- Set working directory to persistent volume ----
WORKDIR /home/node

# ---- Keep container alive for Zeabur Exec ----
CMD ["sleep", "infinity"]
