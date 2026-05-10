#!/usr/bin/env python3
"""Resize an image sequence to one fixed resolution.

This is meant for sprite-frame directories where every frame must share the
same canvas size before being loaded by Godot or converted into a preview
video. It writes resized copies to an output directory by default.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import cv2
import numpy as np


IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tga"}
NATURAL_SPLIT_RE = re.compile(r"(\d+)")
INTERPOLATION = {
    "nearest": cv2.INTER_NEAREST,
    "linear": cv2.INTER_LINEAR,
    "cubic": cv2.INTER_CUBIC,
    "area": cv2.INTER_AREA,
    "lanczos": cv2.INTER_LANCZOS4,
}


def natural_key(path: Path) -> list[object]:
    return [int(part) if part.isdigit() else part.lower() for part in NATURAL_SPLIT_RE.split(path.name)]


def parse_resolution(value: str) -> tuple[int, int]:
    match = re.fullmatch(r"(\d+)x(\d+)", value.strip().lower())
    if not match:
        raise argparse.ArgumentTypeError("resolution must look like 512x512")
    width = int(match.group(1))
    height = int(match.group(2))
    if width <= 0 or height <= 0:
        raise argparse.ArgumentTypeError("resolution dimensions must be positive")
    return width, height


def collect_frames(input_dir: Path, pattern: str | None) -> list[Path]:
    if pattern:
        frames = [path for path in input_dir.glob(pattern) if path.is_file()]
    else:
        frames = [path for path in input_dir.iterdir() if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS]
    return sorted((path for path in frames if not path.name.endswith(".import")), key=natural_key)


def resolve_output_path(input_dir: Path, output_dir: Path, frame_path: Path) -> Path:
    try:
        relative = frame_path.relative_to(input_dir)
    except ValueError:
        relative = Path(frame_path.name)
    return output_dir / relative


def read_image(path: Path) -> np.ndarray:
    data = np.fromfile(str(path), dtype=np.uint8)
    image = cv2.imdecode(data, cv2.IMREAD_UNCHANGED)
    if image is None:
        raise RuntimeError(f"failed to read {path}")
    return image


def write_image(path: Path, image: np.ndarray) -> None:
    success, encoded = cv2.imencode(path.suffix, image)
    if not success:
        raise RuntimeError(f"failed to encode {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    encoded.tofile(str(path))


def resize_frame(frame_path: Path, output_path: Path, size: tuple[int, int], interpolation: int, overwrite: bool) -> None:
	if output_path.exists() and not overwrite:
		raise RuntimeError(f"{output_path} already exists; pass --overwrite to replace it")

	image = read_image(frame_path)

	width, height = size
	resized = cv2.resize(image, (width, height), interpolation=interpolation)

	write_image(output_path, resized)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Resize all frames in a directory to one fixed resolution.")
    parser.add_argument("input_dir", type=Path, help="Directory containing source image frames.")
    parser.add_argument("resolution", type=parse_resolution, help="Target resolution, for example 512x512.")
    parser.add_argument("-o", "--output-dir", type=Path, help="Directory for resized frames.")
    parser.add_argument("--pattern", help="Input glob pattern, for example skadi_*.png. Default: common image files.")
    parser.add_argument(
        "--interpolation",
        choices=sorted(INTERPOLATION),
        default="area",
        help="Resize filter. Default: area, good for downscaling.",
    )
    parser.add_argument("--overwrite", action="store_true", help="Allow replacing existing output files.")
    parser.add_argument(
        "--in-place",
        action="store_true",
        help="Resize files in the input directory. Requires --overwrite and cannot be combined with --output-dir.",
    )
    parser.add_argument("--dry-run", action="store_true", help="Print planned writes without changing files.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    input_dir = args.input_dir.resolve()
    if not input_dir.is_dir():
        print(f"error: input directory does not exist: {input_dir}", file=sys.stderr)
        return 2

    if args.in_place:
        if args.output_dir is not None:
            print("error: --in-place cannot be combined with --output-dir", file=sys.stderr)
            return 2
        if not args.overwrite:
            print("error: --in-place requires --overwrite", file=sys.stderr)
            return 2
        output_dir = input_dir
    else:
        if args.output_dir is None:
            print("error: pass --output-dir, or use --in-place --overwrite", file=sys.stderr)
            return 2
        output_dir = args.output_dir.resolve()
        if output_dir == input_dir and not args.overwrite:
            print("error: output directory is the input directory; pass --overwrite or use --in-place", file=sys.stderr)
            return 2

    frames = collect_frames(input_dir, args.pattern)
    if not frames:
        print(f"error: no frames found in {input_dir}", file=sys.stderr)
        return 1

    print(f"frames: {len(frames)}")
    print(f"target: {args.resolution[0]}x{args.resolution[1]}")
    print(f"output: {output_dir}")

    interpolation = INTERPOLATION[args.interpolation]
    for frame_path in frames:
        output_path = frame_path if args.in_place else resolve_output_path(input_dir, output_dir, frame_path)
        if args.dry_run:
            print(f"{frame_path} -> {output_path}")
            continue
        resize_frame(frame_path, output_path, args.resolution, interpolation, args.overwrite)

    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
