FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/home/node
ENV USER=node
ENV KIMAKI_DIR=/home/node/kimaki_workplace
ENV OPENCODE_CONFIG_DIR=/home/node/.config/opencode
# 安裝基本套件（含 wget/tini）
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget gnupg lsb-release \
    build-essential pkg-config libssl-dev \
    python3 python3-pip python3-venv \
    vim sudo jq git bash procps unzip tini \
  && rm -rf /var/lib/apt/lists/*
# 安裝 gh CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
  && apt-get update && apt-get install -y --no-install-recommends gh \
  && rm -rf /var/lib/apt/lists/*
# Node.js install (Node 20 LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && rm -rf /var/lib/apt/lists/*
# 建 non-root user 及目錄
RUN useradd -m -s /bin/bash ${USER} \
  && mkdir -p ${OPENCODE_CONFIG_DIR} ${KIMAKI_DIR} \
  && chown -R ${USER}:${USER} /home/${USER}
# 下載來源 URL（預設指向你 repo main 的 raw URL；可用 --build-arg 覆蓋）
ARG OPENCODE_JSON_URL=https://raw.githubusercontent.com/nine-ai-2046-1/zeabur-dockers/main/opencode.json
ARG ENTRYPOINT_URL=https://raw.githubusercontent.com/nine-ai-2046-1/zeabur-dockers/main/entrypoint.sh
# build-time 下載 opencode.json 與 entrypoint.sh（無 checksum）
RUN set -eux; \
    mkdir -p /tmp/buildfiles; \
    wget -qO /tmp/buildfiles/opencode.json "${OPENCODE_JSON_URL}"; \
    mv /tmp/buildfiles/opencode.json ${OPENCODE_CONFIG_DIR}/opencode.json; \
    chown ${USER}:${USER} ${OPENCODE_CONFIG_DIR}/opencode.json; \
    wget -qO /tmp/buildfiles/entrypoint.sh "${ENTRYPOINT_URL}"; \
    mv /tmp/buildfiles/entrypoint.sh /usr/local/bin/entrypoint.sh; \
    chmod +x /usr/local/bin/entrypoint.sh; \
    chown ${USER}:${USER} /usr/local/bin/entrypoint.sh; \
    rm -rf /tmp/buildfiles
# install opencode globally
RUN npm install -g opencode-ai@latest --unsafe-perm=true --no-audit --no-fund --retry 3
# optional: 安裝 rustup 到 node home（如需 Rust dev env）
USER ${USER}
ENV PATH="${HOME}/.cargo/bin:${PATH}"
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y || true
# 設工作目錄、使用 node user
WORKDIR ${KIMAKI_DIR}
USER ${USER}
# entrypoint via tini (entrypoint.sh 由你 repo 提供)
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["start"]
