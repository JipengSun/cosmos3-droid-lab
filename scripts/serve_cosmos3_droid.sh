#!/usr/bin/env bash
# Start Cosmos3-Nano-Policy-DROID WebSocket policy server for the DROID lab.
set -euo pipefail

export PATH="${HOME}/.local/bin:${PATH}"
export LD_LIBRARY_PATH=

COSMOS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECKPOINT="${COSMOS_CHECKPOINT:-${COSMOS_ROOT}/checkpoints/Cosmos3-Nano-Policy-DROID}"
PORT="${COSMOS_POLICY_PORT:-8001}"

if [[ ! -d "${CHECKPOINT}" ]]; then
  echo "Checkpoint not found at ${CHECKPOINT}" >&2
  echo "Download with:" >&2
  echo "  cd ${COSMOS_ROOT} && source .venv/bin/activate" >&2
  echo "  uvx hf@latest download nvidia/Cosmos3-Nano-Policy-DROID --local-dir ${CHECKPOINT}" >&2
  exit 1
fi

cd "${COSMOS_ROOT}"
source .venv/bin/activate

exec python -m cosmos_framework.scripts.action_policy_server_robolab \
  --checkpoint-path "${CHECKPOINT}" \
  --port "${PORT}" \
  "$@"
