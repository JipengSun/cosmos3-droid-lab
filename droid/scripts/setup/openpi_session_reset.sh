#!/usr/bin/env bash
# Full clean slate before a new OpenPI rollout session (workstation + NUC).
set +e
exec 1>&2

echo "[openpi_session_reset] starting"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAILED=0

bash "$ROOT/scripts/setup/openpi_kill_workstation.sh" || FAILED=1
echo ""
if bash "$ROOT/scripts/setup/require_lab_network.sh" && bash "$ROOT/scripts/setup/openpi_kill_nuc.sh"; then
  :
else
  echo ""
  echo "ERROR: NUC cleanup failed."
  if ! ping -c 1 -W 2 192.168.1.7 >/dev/null 2>&1; then
    echo "  Lab Ethernet appears down — plug eno1/eno2 into the robot switch, then:"
    echo "    ping -c 2 192.168.1.7"
  else
    echo "  Run: ssh -o ConnectTimeout=5 nuc echo ok"
  fi
  FAILED=1
fi
echo ""
if [[ "$FAILED" -eq 0 ]]; then
  echo "Clean slate ready -> Step 0 (Desk FCI) -> Step 1 (openpi_nuc_status.sh) -> Steps 2a-7."
else
  echo "Cleanup incomplete -- fix errors above before continuing."
  exit 1
fi
