# Cosmos3-Nano-Policy-DROID — DROID Lab Setup

This machine (`robotman`) runs **Cosmos3-Nano-Policy-DROID** alongside the existing DROID stack (NUC arm/gripper + 3× ZED cameras).

## Layout

| Path | Purpose |
|------|---------|
| `~/Desktop/cosmos3` | cosmos-framework clone + venv |
| `~/Desktop/cosmos3/checkpoints/Cosmos3-Nano-Policy-DROID` | 16B HF checkpoint (~32 GB) |
| `~/Desktop/DROID/scripts/demo/cosmos3_droid_rollout.py` | Real-robot rollout client |

Cosmos3 uses **port 8001** so OpenPI π₀.5 can keep **8000**.

## One-time setup (done)

```bash
cd ~/Desktop/cosmos3
git clone https://github.com/NVIDIA/cosmos-framework.git .   # already cloned
uv sync --all-extras --group=cu130-train --group=policy-server
uvx hf@latest auth login   # HF token with Cosmos3 model access
uvx hf@latest download nvidia/Cosmos3-Nano-Policy-DROID \
  --local-dir checkpoints/Cosmos3-Nano-Policy-DROID
```

Guardrails are **disabled** in the lab server launcher (no access to gated `nvidia/Cosmos-Guardrail1` required).

## Run a rollout

**One command** (NUC stack + policy server + rollout):

```bash
conda activate robot   # optional if not already active
cd ~/Desktop/DROID
bash scripts/demo/start_cosmos3_demo.sh
bash scripts/demo/start_cosmos3_demo.sh --dry-run
```

Or manually across terminals:

```bash
bash ~/Desktop/DROID/scripts/setup/openpi_start_gripper_nuc.sh
bash ~/Desktop/DROID/scripts/setup/openpi_start_polymetis.sh
sleep 18 && bash ~/Desktop/DROID/scripts/setup/openpi_start_zerorpc.sh
```

Desk → Activate FCI on the workstation browser first.

**Terminal 2 — Cosmos3 policy server**:

```bash
bash ~/Desktop/cosmos3/scripts/serve_cosmos3_droid.sh
```

First start loads the 16B model into GPU memory (~30–60 s on RTX PRO 6000).

**Terminal 3 — rollout client**:

```bash
conda activate robot
cd ~/Desktop/DROID
python scripts/demo/cosmos3_droid_rollout.py --dry-run   # cameras + inference, no motion
python scripts/demo/cosmos3_droid_rollout.py             # live rollout
```

## Observation / action contract

Cosmos3 expects all **three** camera views (wrist + both externals) at full RGB resolution. The server composes them into the concat view used at training time.

- **Input keys**: `observation/wrist_image_left`, `observation/exterior_image_1_left`, `observation/exterior_image_2_left`, `observation/joint_position`, `observation/gripper_position`, `prompt`
- **Output**: `action` tensor shape `(32, 8)` — absolute joint positions (7) + gripper (0=open, 1=closed)
- **Control**: `joint_position` @ 15 Hz; re-query every 8 steps (`--open-loop-horizon`)

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `Access denied` for Guardrail | Guardrails disabled in lab server; restart with `serve_cosmos3_droid.sh` |
| `Connection refused :8001` | Start policy server terminal first |
| Missing camera frames | Check ZED USB + IDs in `droid/misc/parameters.py` |
| GPU OOM | Stop OpenPI server on `:8000` before starting Cosmos3 |
| `import pyzed` fails | `conda activate robot`, `newgrp zed` |
