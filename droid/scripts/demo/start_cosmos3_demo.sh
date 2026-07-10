#!/usr/bin/env bash
# Fresh-start Cosmos3-Nano-Policy-DROID demo (language → arm + gripper via NUC).
#
# Prerequisite: Desk → Unlock brakes → Activate FCI
#
# Usage:
#   bash scripts/demo/start_cosmos3_demo.sh
#   bash scripts/demo/start_cosmos3_demo.sh --dry-run
#
set -euo pipefail
exec 1>&2

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
COSMOS="${COSMOS_ROOT:-${HOME}/Desktop/cosmos3}"
POLICY_PORT="${COSMOS_POLICY_PORT:-8001}"
SKIP_STACK=false
ROLLOUT_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-stack) SKIP_STACK=true; shift ;;
    *) ROLLOUT_ARGS+=("$1"); shift ;;
  esac
done

cd "$ROOT"

source "${HOME}/anaconda3/etc/profile.d/conda.sh" 2>/dev/null || source ~/miniconda3/etc/profile.d/conda.sh
conda activate robot
export PATH="${HOME}/.local/bin:${PATH}"
export PYTHONUNBUFFERED=1
export LD_LIBRARY_PATH="/usr/local/zed/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

STEP=1
if [[ "${SKIP_STACK}" != true ]]; then
  echo "=== [${STEP}/6] Clean slate ==="
  bash scripts/setup/openpi_session_reset.sh
  ((STEP++))

  echo ""
  echo "=== [${STEP}/6] FCI check (Desk must be active) ==="
  if ! nc -zv -w 3 192.168.1.11 1337 2>&1; then
    echo "ERROR: FCI not active. Open https://192.168.1.11/desk/ → Activate FCI, then re-run."
    exit 1
  fi
  ((STEP++))

  echo ""
  echo "=== [${STEP}/6] Start NUC stack (gripper + Polymetis + zerorpc) ==="
  bash scripts/setup/openpi_start_nuc_stack.sh
  ((STEP++))

  echo ""
  echo "=== [${STEP}/6] Arm smoke test ==="
  python scripts/demo/arm_smoke_test.py
  echo ""
  echo "=== [${STEP}/6] ZED camera preflight (3 required) ==="
  python scripts/setup/list_zed_cameras.py
  python - <<'PY'
import sys
import pyzed.sl as sl
from droid.misc.parameters import hand_camera_id, varied_camera_1_id, varied_camera_2_id

required = [hand_camera_id, varied_camera_1_id, varied_camera_2_id]
devices = {str(d.serial_number): d for d in sl.Camera.get_device_list()}
missing = []
for cid in required:
    dev = devices.get(cid)
    if dev is None:
        missing.append(f"{cid} (not detected)")
        continue
    state = str(getattr(dev, "camera_state", ""))
    if cid == "0" or "NOT AVAILABLE" in state.upper():
        missing.append(f"{cid} ({state or 'unavailable'})")
if missing:
    print("ERROR: ZED preflight failed.")
    for item in missing:
        print(f"  - {item}")
    print("Replug the hand ZED-M USB cable, then re-run.")
    sys.exit(1)
print("ZED preflight OK:", ", ".join(required))
PY
  ((STEP++))
fi

echo ""
echo "=== [${STEP}/6] Start Cosmos3 policy server (background) ==="
if [[ ! -f "${COSMOS}/scripts/serve_cosmos3_droid.sh" ]]; then
  echo "ERROR: Cosmos3 not found at ${COSMOS}"
  exit 1
fi

if command -v fuser >/dev/null 2>&1; then
  fuser -k "${POLICY_PORT}/tcp" 2>/dev/null || true
fi
sleep 1

POLICY_LOG="/tmp/cosmos3_policy_server.log"
nohup bash "${COSMOS}/scripts/serve_cosmos3_droid.sh" >>"${POLICY_LOG}" 2>&1 &
POLICY_PID=$!
echo "Policy server PID ${POLICY_PID}, log: ${POLICY_LOG}"

echo -n "Waiting for :${POLICY_PORT} (model load may take 2-3 min)"
for _ in $(seq 1 180); do
  if curl -sf "http://127.0.0.1:${POLICY_PORT}/healthz" >/dev/null 2>&1; then
    echo " OK"
    break
  fi
  if ! kill -0 "${POLICY_PID}" 2>/dev/null; then
    echo ""
    echo "ERROR: policy server exited. Last log lines:"
    tail -30 "${POLICY_LOG}" || true
    exit 1
  fi
  echo -n "."
  sleep 2
done

if ! curl -sf "http://127.0.0.1:${POLICY_PORT}/healthz" >/dev/null 2>&1; then
  echo ""
  echo "ERROR: policy server did not become healthy on :${POLICY_PORT} within 360s"
  tail -30 "${POLICY_LOG}" || true
  exit 1
fi

echo ""
echo "=== Start rollout client ==="
DEFAULT_ARGS=(--no-reset --remote-port "${POLICY_PORT}")
if [[ ${#ROLLOUT_ARGS[@]} -eq 0 ]]; then
  ROLLOUT_ARGS=("${DEFAULT_ARGS[@]}")
else
  ROLLOUT_ARGS=(--remote-port "${POLICY_PORT}" "${ROLLOUT_ARGS[@]}")
fi

echo "Policy server: ws://127.0.0.1:${POLICY_PORT}"
echo "Rollout: python scripts/demo/cosmos3_droid_rollout.py ${ROLLOUT_ARGS[*]}"
echo ""

exec python scripts/demo/cosmos3_droid_rollout.py "${ROLLOUT_ARGS[@]}"
