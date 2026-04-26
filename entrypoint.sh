#!/usr/bin/env bash
set -euo pipefail
# 這支 script 會：
# - source nvm if present（如果你改用 nvm）
# - 確保 kimaki directory 存在並把權限設正確
# - 若傳入 "start" 則啟動 npx kimaki 並把 log 送到 stdout
# - 使用 exec 來讓 tini 轉發 signals，讓 kimaki 可 graceful stop
HOME="/home/node"
KIMAKI_DIR="${HOME}/kimaki_workplace"
DATA_DIR="${KIMAKI_DIR}/.kimaki"
NPM_BIN="$(which npm 2>/dev/null || true)"
NPX_BIN="$(which npx 2>/dev/null || true)"
# If nvm exists, source it so that npx from nvm is available (optional)
if [ -s "${HOME}/.nvm/nvm.sh" ]; then
  # shellcheck disable=SC1090
  . "${HOME}/.nvm/nvm.sh"
fi
# Ensure dirs and ownership
mkdir -p "${KIMAKI_DIR}" "${DATA_DIR}"
chown -R node:node "${HOME}"
# handle commands
case "${1:-start}" in
  start)
    cd "${KIMAKI_DIR}"
    echo "Starting kimaki in ${KIMAKI_DIR} (data dir: ${DATA_DIR})"
    # Use npx to run kimaki; use -y to auto confirm
    # exec so process replaces shell (signal handling)
    exec npx -y kimaki@latest --data-dir "${DATA_DIR}" --auto-restart
    ;;
  bash|sh)
    exec /bin/bash
    ;;
  *)
    exec "$@"
    ;;
esac
