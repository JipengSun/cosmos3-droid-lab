#!/usr/bin/env bash
# Fail fast with a clear message when robotman is not on the lab robot LAN.
set -euo pipefail

NUC_IP="${DROID_NUC_IP:-192.168.1.7}"
ROBOT_IP="${DROID_ROBOT_IP:-192.168.1.11}"

if ping -c 1 -W 2 "${NUC_IP}" >/dev/null 2>&1; then
  exit 0
fi

echo "ERROR: Cannot reach lab robot network (${NUC_IP})."
echo ""
echo "robotman is not on 192.168.1.x — demos need Ethernet to the robot lab switch."
echo ""
ip -4 addr show scope global 2>/dev/null | grep -E 'inet ' || true
ip link show 2>/dev/null | grep -E '^[0-9]+: en' || true
echo ""
echo "Fix:"
echo "  1. Plug Ethernet from robotman (eno1 or eno2) into the lab robot switch."
echo "  2. Verify: ping -c 2 ${NUC_IP} && ping -c 2 ${ROBOT_IP}"
echo "  3. Re-run your demo command."
echo ""
echo "Wi-Fi alone is not enough for NUC SSH or Franka FCI."
exit 1
