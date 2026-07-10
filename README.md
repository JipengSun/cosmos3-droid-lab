# Cosmos3-Nano-Policy-DROID — Lab Integration

Lab glue for running [nvidia/Cosmos3-Nano-Policy-DROID](https://huggingface.co/nvidia/Cosmos3-Nano-Policy-DROID) on the Franka FR3 + ZED DROID stack (robotman + NUC).

This repo does **not** include the 16B checkpoint (~32 GB) or a full `cosmos-framework` checkout. Those live on the workstation at:

```text
~/Desktop/cosmos3/                         # NVIDIA cosmos-framework + venv
~/Desktop/cosmos3/checkpoints/Cosmos3-Nano-Policy-DROID
~/Desktop/DROID/                           # lab DROID fork
```

## One-command demo

On robotman (lab Ethernet + Desk FCI active):

```bash
bash ~/Desktop/DROID/scripts/demo/start_cosmos3_demo.sh
bash ~/Desktop/DROID/scripts/demo/start_cosmos3_demo.sh --dry-run
```

Policy server listens on **:8001** (OpenPI keeps **:8000**).

## What's in this repo

| Path | Purpose |
|------|---------|
| `scripts/serve_cosmos3_droid.sh` | Start Cosmos3 WebSocket policy server |
| `docs/droid-lab-setup.md` | Lab setup / runbook |
| `droid/scripts/demo/start_cosmos3_demo.sh` | One-command NUC + server + rollout |
| `droid/scripts/demo/cosmos3_droid_rollout.py` | Real-robot rollout client |
| `droid/scripts/setup/require_lab_network.sh` | Fail fast if not on `192.168.1.x` |
| `droid/droid/camera_utils/...` | ZED fixes (skip phantom serial 0, VGA@15) |
| `patches/disable-guardrails-robolab-server.patch` | Lab patch: skip gated Guardrail1 |

## Apply into existing checkouts

```bash
# Policy server launcher
cp scripts/serve_cosmos3_droid.sh ~/Desktop/cosmos3/scripts/
cp docs/droid-lab-setup.md ~/Desktop/cosmos3/docs/

# DROID client + camera fixes
cp droid/scripts/demo/* ~/Desktop/DROID/scripts/demo/
cp droid/scripts/setup/* ~/Desktop/DROID/scripts/setup/
cp droid/droid/camera_utils/camera_readers/zed_camera.py \
  ~/Desktop/DROID/droid/camera_utils/camera_readers/
cp droid/droid/camera_utils/wrappers/multi_camera_wrapper.py \
  ~/Desktop/DROID/droid/camera_utils/wrappers/

# Optional: disable guardrails in cosmos-framework
cd ~/Desktop/cosmos3 && git apply ~/Desktop/cosmos3-droid-lab/patches/disable-guardrails-robolab-server.patch
```

## Prerequisites

1. Hugging Face access to `nvidia/Cosmos3-Nano-Policy-DROID`
2. `cosmos-framework` installed: `uv sync --all-extras --group=cu130-train --group=policy-server`
3. Checkpoint downloaded under `~/Desktop/cosmos3/checkpoints/`
4. robotman on lab Ethernet (`192.168.1.x`), NUC at `192.168.1.7`, Franka at `192.168.1.11`
5. All 3 ZED cameras available (hand ZED-M serial must not be `0`)

See `docs/droid-lab-setup.md` for details.
