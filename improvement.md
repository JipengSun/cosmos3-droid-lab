# Agent improvement notes

## 2026-07-20 — robot_entries runbooks

- Lab how-to docs for operators live in `/home/pci/Desktop/robot_entries/` (outside this repo); match existing style (`pi05_demo.md`, `vr_teleop_demo.md`).
- When the user asks for “one line command at the top,” put the copy-paste bash one-liner immediately under the title before background prose.
- Cosmos3 demo one-liner: `conda activate robot && cd ~/Desktop/DROID && bash scripts/demo/start_cosmos3_demo.sh` (port **8001**, needs all 3 ZEDs, stop OpenPI first for VRAM).
- ZED-M `serial=0` / `NOT AVAILABLE` with `10163006 (not detected)` is **not** a `parameters.py` mismatch — HID still reports `10163006`, but the USB3 **video** interface is missing. Fix: unplug/replug ZED-M on a USB3 port; do not change serials.

## 2026-07-09 — Cosmos3 DROID lab setup

- Clone to `~/Desktop/cosmos3`; install with `uv sync --all-extras --group=cu130-train --group=policy-server`.
- HF token required for initial checkpoint download; accept model license on huggingface.co first.
- `nvidia/Cosmos-Guardrail1` is gated separately — disable guardrails for lab server (`guardrails=False` in `_build_setup_args`) if access denied.
- Serve on port **8001** to avoid conflict with OpenPI on **8000**.
- 16B model uses ~32 GB VRAM on RTX PRO 6000; stop other GPU policy servers before starting Cosmos3.
- Rollout lives in `~/Desktop/DROID/scripts/demo/cosmos3_droid_rollout.py` (not in this repo).
