# Agent improvement notes

## 2026-07-09 — Cosmos3 DROID lab setup

- Clone to `~/Desktop/cosmos3`; install with `uv sync --all-extras --group=cu130-train --group=policy-server`.
- HF token required for initial checkpoint download; accept model license on huggingface.co first.
- `nvidia/Cosmos-Guardrail1` is gated separately — disable guardrails for lab server (`guardrails=False` in `_build_setup_args`) if access denied.
- Serve on port **8001** to avoid conflict with OpenPI on **8000**.
- 16B model uses ~32 GB VRAM on RTX PRO 6000; stop other GPU policy servers before starting Cosmos3.
- Rollout lives in `~/Desktop/DROID/scripts/demo/cosmos3_droid_rollout.py` (not in this repo).
