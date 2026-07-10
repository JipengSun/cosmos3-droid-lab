#!/usr/bin/env python3
"""Run Cosmos3-Nano-Policy-DROID on this lab's Franka FR3 + ZED setup.

Prerequisites (workstation):
  1. NUC: Polymetis + zerorpc :4242 + gripper :50052 (FCI active in Desk)
     bash scripts/setup/openpi_start_gripper_nuc.sh
     bash scripts/setup/openpi_start_polymetis.sh && sleep 18 && bash scripts/setup/openpi_start_zerorpc.sh
  2. Cosmos3 policy server (separate terminal):
       bash ~/Desktop/cosmos3/scripts/serve_cosmos3_droid.sh

Usage:
  conda activate robot
  cd ~/Desktop/DROID
  python scripts/demo/cosmos3_droid_rollout.py
  python scripts/demo/cosmos3_droid_rollout.py --dry-run   # server + cameras only, no motion
"""

from __future__ import annotations

import contextlib
import dataclasses
import faulthandler
import signal
import sys
import time

sys.stdout = sys.stderr

import numpy as np
import tqdm
import tyro
from openpi_client import websocket_client_policy

from droid.misc.parameters import hand_camera_id, varied_camera_1_id, varied_camera_2_id
from droid.robot_env import RobotEnv

faulthandler.enable()

DROID_CONTROL_FREQUENCY = 15
DEFAULT_ACTION_CHUNK = 32


@dataclasses.dataclass
class RolloutConfig:
    left_camera_id: str = varied_camera_1_id
    right_camera_id: str = varied_camera_2_id
    wrist_camera_id: str = hand_camera_id
    max_timesteps: int = 600
    open_loop_horizon: int = 8
    remote_host: str = "127.0.0.1"
    remote_port: int = 8001
    no_reset: bool = False
    dry_run: bool = False


@contextlib.contextmanager
def prevent_keyboard_interrupt():
    interrupted = False
    original_handler = signal.getsignal(signal.SIGINT)

    def handler(signum, frame):
        nonlocal interrupted
        interrupted = True

    signal.signal(signal.SIGINT, handler)
    try:
        yield
    finally:
        signal.signal(signal.SIGINT, original_handler)
        if interrupted:
            raise KeyboardInterrupt


def _to_uint8_rgb(image: np.ndarray) -> np.ndarray:
    rgb = np.asarray(image[..., :3][..., ::-1])
    if rgb.dtype != np.uint8:
        rgb = np.clip(rgb, 0, 255).astype(np.uint8)
    return np.ascontiguousarray(rgb)


def _extract_observation(args: RolloutConfig, obs_dict, *, gripper_position=None, save_to_disk=False):
    image_observations = obs_dict["image"]
    left_image, right_image, wrist_image = None, None, None
    for key in image_observations:
        if args.left_camera_id in key and "left" in key:
            left_image = image_observations[key]
        elif args.right_camera_id in key and "left" in key:
            right_image = image_observations[key]
        elif args.wrist_camera_id in key and "left" in key:
            wrist_image = image_observations[key]

    if left_image is None or right_image is None or wrist_image is None:
        raise RuntimeError(
            "Missing camera frames. Check camera IDs and USB connections.\n"
            f"  left={args.left_camera_id} right={args.right_camera_id} wrist={args.wrist_camera_id}\n"
            f"  available keys: {list(image_observations.keys())}"
        )

    left_image = _to_uint8_rgb(left_image)
    right_image = _to_uint8_rgb(right_image)
    wrist_image = _to_uint8_rgb(wrist_image)

    robot_state = obs_dict["robot_state"]
    joint_position = np.array(robot_state["joint_positions"], dtype=np.float32)
    if gripper_position is None:
        gripper_position = np.array([robot_state["gripper_position"]], dtype=np.float32)
    else:
        gripper_position = np.array([float(gripper_position)], dtype=np.float32)

    if save_to_disk:
        from PIL import Image

        combined_image = np.concatenate([left_image, wrist_image, right_image], axis=1)
        Image.fromarray(combined_image).save("robot_camera_views.png")
        print("Saved robot_camera_views.png (left | wrist | right)")

    return {
        "left_image": left_image,
        "right_image": right_image,
        "wrist_image": wrist_image,
        "joint_position": joint_position,
        "gripper_position": gripper_position,
    }


def _build_policy_request(obs: dict, prompt: str) -> dict:
    return {
        "observation/wrist_image_left": obs["wrist_image"],
        "observation/exterior_image_1_left": obs["left_image"],
        "observation/exterior_image_2_left": obs["right_image"],
        "observation/joint_position": obs["joint_position"],
        "observation/gripper_position": obs["gripper_position"],
        "prompt": prompt,
    }


def _extract_action_chunk(response: dict) -> np.ndarray:
    if "action" in response:
        chunk = np.asarray(response["action"], dtype=np.float32)
    elif "actions" in response:
        chunk = np.asarray(response["actions"], dtype=np.float32)
    else:
        raise KeyError(f"Policy response missing action chunk keys: {list(response.keys())}")
    if chunk.ndim != 2 or chunk.shape[1] != 8:
        raise ValueError(f"Expected action chunk shape (N, 8), got {chunk.shape}")
    return chunk


def main(args: RolloutConfig):
    def log(msg):
        print(msg, flush=True)

    log("Lab camera IDs:")
    log(f"  left={args.left_camera_id}  right={args.right_camera_id}  wrist={args.wrist_camera_id}")
    log(f"  policy server: ws://{args.remote_host}:{args.remote_port}")

    log("Connecting to Cosmos3 policy server...")
    policy_client = websocket_client_policy.WebsocketClientPolicy(args.remote_host, args.remote_port)
    log("Connected to policy server: " + str(policy_client.get_server_metadata()))

    log("Starting RobotEnv (ZED cameras + NUC arm/gripper; may take 30-60s)...")
    env = RobotEnv(
        action_space="joint_position",
        gripper_action_space="position",
        do_reset=not args.no_reset,
    )
    log("DROID RobotEnv ready (arm + gripper via NUC zerorpc).")

    obs = _extract_observation(args, env.get_observation(), save_to_disk=True)
    with prevent_keyboard_interrupt():
        pred = _extract_action_chunk(
            policy_client.infer(_build_policy_request(obs, "pick up the block"))
        )
    log(f"Policy inference OK — action chunk shape {pred.shape} (Cosmos3 default horizon is {DEFAULT_ACTION_CHUNK})")

    if args.dry_run:
        print("Dry run complete (no robot motion). Remove --dry-run to execute rollouts.")
        return

    while True:
        instruction = input("Enter instruction (or Ctrl+C to quit): ").strip()
        if not instruction:
            log("Empty instruction, skipping.")
            continue

        actions_from_chunk_completed = 0
        pred_action_chunk = None
        bar = tqdm.tqdm(range(args.max_timesteps))
        print("Running rollout... press Ctrl+C to stop early.")
        for t_step in bar:
            start_time = time.time()
            try:
                gripper_pos = float(env.get_state()[0]["gripper_position"])
                curr_obs = _extract_observation(
                    args, env.get_observation(), gripper_position=gripper_pos
                )
                if actions_from_chunk_completed == 0 or actions_from_chunk_completed >= args.open_loop_horizon:
                    actions_from_chunk_completed = 0
                    request_data = _build_policy_request(curr_obs, instruction)
                    with prevent_keyboard_interrupt():
                        pred_action_chunk = _extract_action_chunk(policy_client.infer(request_data))

                action = pred_action_chunk[actions_from_chunk_completed]
                actions_from_chunk_completed += 1
                env.step(action)

                elapsed_time = time.time() - start_time
                if elapsed_time < 1 / DROID_CONTROL_FREQUENCY:
                    time.sleep(1 / DROID_CONTROL_FREQUENCY - elapsed_time)
            except KeyboardInterrupt:
                break

        if input("Do one more eval? (y/n) ").lower() != "y":
            break


if __name__ == "__main__":
    main(tyro.cli(RolloutConfig))
