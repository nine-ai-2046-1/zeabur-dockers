FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /workspace

RUN apt-get update && apt-get install -y \
    bash \
    curl \
    git \
    ca-certificates \
    build-essential \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Keep container alive for Zeabur exec
CMD ["bash", "-c", "sleep infinity"]
