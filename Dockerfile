FROM debian:bookworm-slim

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-color

# ============================================================================
# Stage 1: Base system setup with suid sudo for opencode
# ============================================================================

# Install base tools and development dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo \
    vim \
    jq \
    git \
    curl \
    wget \
    ca-certificates \
    gnupg \
    lsb-release \
    build-essential \
    pkg-config \
    libssl-dev \
    cairo2 \
    libudev-dev \
    libi2c-dev \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# Stage 2: Install Node.js
# ============================================================================

# Install Node.js 20.x (LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# Stage 3: Install Python
# ============================================================================

# Install Python 3.11+ and pip
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    python3-setuptools \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip and install essential Python tools
RUN python3 -m pip install --upgrade pip setuptools wheel

# ============================================================================
# Stage 4: Install Rust
# ============================================================================

# Install Rust via rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile default \
    && . "$HOME/.cargo/env"

# Add cargo bin to PATH for all users
ENV PATH="/root/.cargo/bin:${PATH}"

# ============================================================================
# Stage 5: Install GitHub CLI (gh)
# ============================================================================

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# Stage 6: Install OpenCode
# ============================================================================

# Install OpenCode globally via npm
RUN npm install -g opencode

# ============================================================================
# Stage 7: Configure persistent storage at /home/node
# ============================================================================

# Create persistent data directory
RUN mkdir -p /home/node && \
    chown -R root:root /home/node && \
    chmod 755 /home/node

# Create symbolic links for persistent node_modules and .cargo
RUN ln -sf /home/node/.npm /root/.npm \
    && ln -sf /home/node/.cache /root/.cache \
    && ln -sf /home/node/.cargo /root/.cargo \
    && mkdir -p /home/node/.npm /home/node/.cache /home/node/.cargo

# ============================================================================
# Stage 8: Configure sudoers for opencode (no password required)
# ============================================================================

# Create sudoers file for opencode to run apt-get without password
# This allows opencode to install packages once enabled, without user intervention
RUN echo "opencode ALL=(ALL) NOPASSWD: /usr/bin/apt-get *" > /etc/sudoers.d/opencode && \
    echo "opencode ALL=(ALL) NOPASSWD: /usr/bin/dpkg *" >> /etc/sudoers.d/opencode && \
    echo "opencode ALL=(ALL) NOPASSWD: /usr/bin/snap *" >> /etc/sudoers.d/opencode && \
    chmod 440 /etc/sudoers.d/opencode

# ============================================================================
# Stage 9: Configure apt for persistent packages
# ============================================================================

# Reconfigure apt to use alternative directories for persistence
# We'll configure dpkg and apt to store packages in /home/node
RUN mkdir -p /home/node/apt && \
    mkdir -p /home/node/var/cache/apt && \
    mkdir -p /home/node/var/lib/apt && \
    cp -a /var/cache/apt/archives /home/node/var/cache/apt/ 2>/dev/null || true

# Create apt configuration to use persistent directories
RUN echo "Dir::Cache \"/home/node/var/cache/apt\";" > /etc/apt/apt.conf.d/99persistent && \
    echo "Dir::State::Lists \"/home/node/var/lib/apt\";" >> /etc/apt/apt.conf.d/99persistent && \
    echo "Dir::Log \"/home/node/var/log/apt\";" >> /etc/apt/apt.conf.d/99persistent

# Add opencode user if needed (for Zeabur compatibility)
# Zeabur typically runs as root, but we create opencode user for completeness
RUN useradd -m -s /bin/bash opencode 2>/dev/null || true

# ============================================================================
# Stage 10: Environment variables
# ============================================================================

ENV OPENCODE_HOME=/home/node
ENV NPM_CONFIG_PREFIX=/home/node
ENV CARGO_HOME=/home/node/.cargo
ENV RUSTUP_HOME=/home/node/.rustup

# Ensure all users can access /home/node for persistent storage
RUN chmod 755 /home/node

# ============================================================================
# Workdir and default command
# ============================================================================

WORKDIR /workspace

# Default shell
SHELL ["/bin/bash", "-c"]

# Keep container running for SSH access
CMD ["/bin/bash", "-c", "echo 'Container ready. SSH or exec into container to install packages.' && exec /bin/bash"]