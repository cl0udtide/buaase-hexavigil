#!/usr/bin/env python3
"""Scale the visible subject in sprite frames to match a reference sequence.

The canvas size stays unchanged. The script uses the alpha channel to find the
visible subject, resizes that cropped subject, and places it back on a
transparent canvas. This is useful when an action sequence was generated at the
right frame resolution but the character appears smaller than the idle sequence.
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path

import cv2
import numpy as np


NATURAL_SPLIT_RE = re.compile(r"(\d+)")


def natural_key(path: Path) -> list[object]:
    return [int(part) if part.isdigit() else part.lower() for part in NATURAL_SPLIT_RE.split(path.name)]


def read_image(path: Path) -> np.ndarray:
    image = cv2.imdecode(np.fromfile(str(path), dtype=np.uint8), cv2.IMREAD_UNCHANGED)
    if image is None:
        raise RuntimeError(f"failed to read {path}")
    if image.ndim != 3 or image.shape[2] != 4:
        raise RuntimeError(f"{path} must be an RGBA/BGRA image")
    return image


def write_image(path: Path, image: np.ndarray) -> None:
    success, encoded = cv2.imencode(path.suffix, image)
    if not success:
        raise RuntimeError(f"failed to encode {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    encoded.tofile(str(path))


def subject_bbox(image: np.ndarray, alpha_threshold: int) -> tuple[int, int, int, int] | None:
    alpha = image[:, :, 3]
    ys, xs = np.where(alpha > alpha_threshold)
    if len(xs) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def collect_pngs(path: Path, pattern: str) -> list[Path]:
    return sorted((item for item in path.glob(pattern) if item.is_file()), key=natural_key)


def median_reference_metrics(paths: list[Path], alpha_threshold: int) -> dict[str, float]:
    widths: list[int] = []
    heights: list[int] = []
    centers_x: list[float] = []
    bottoms: list[float] = []
    for path in paths:
        image = read_image(path)
        bbox = subject_bbox(image, alpha_threshold)
        if bbox is None:
            continue
        x1, y1, x2, y2 = bbox
        widths.append(x2 - x1)
        heights.append(y2 - y1)
        centers_x.append((x1 + x2) * 0.5)
        bottoms.append(float(y2))
    if not heights:
        raise RuntimeError("reference frames have no visible alpha subject")
    return {
        "width": float(np.median(widths)),
        "height": float(np.median(heights)),
        "center_x": float(np.median(centers_x)),
        "bottom": float(np.median(bottoms)),
    }


def scale_subject(
    image: np.ndarray,
    ref_metrics: dict[str, float],
    alpha_threshold: int,
    max_scale: float,
    height_multiplier: float,
) -> np.ndarray:
    bbox = subject_bbox(image, alpha_threshold)
    if bbox is None:
        return image.copy()

    x1, y1, x2, y2 = bbox
    subject = image[y1:y2, x1:x2]
    subject_height = max(y2 - y1, 1)
    scale = min((ref_metrics["height"] * height_multiplier) / float(subject_height), max_scale)
    new_width = max(1, int(round(subject.shape[1] * scale)))
    new_height = max(1, int(round(subject.shape[0] * scale)))
    resized = cv2.resize(subject, (new_width, new_height), interpolation=cv2.INTER_LANCZOS4)

    canvas = np.zeros_like(image)
    canvas_h, canvas_w = canvas.shape[:2]
    target_center_x = ref_metrics["center_x"]
    target_bottom = ref_metrics["bottom"]
    dst_x1 = int(round(target_center_x - new_width * 0.5))
    dst_y1 = int(round(target_bottom - new_height))
    dst_x2 = dst_x1 + new_width
    dst_y2 = dst_y1 + new_height

    src_x1 = max(0, -dst_x1)
    src_y1 = max(0, -dst_y1)
    src_x2 = new_width - max(0, dst_x2 - canvas_w)
    src_y2 = new_height - max(0, dst_y2 - canvas_h)
    dst_x1 = max(0, dst_x1)
    dst_y1 = max(0, dst_y1)
    dst_x2 = min(canvas_w, dst_x2)
    dst_y2 = min(canvas_h, dst_y2)

    if src_x1 >= src_x2 or src_y1 >= src_y2 or dst_x1 >= dst_x2 or dst_y1 >= dst_y2:
        return canvas
    canvas[dst_y1:dst_y2, dst_x1:dst_x2] = resized[src_y1:src_y2, src_x1:src_x2]
    return canvas


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Scale visible sprite subjects to match a reference sequence.")
    parser.add_argument("reference_dir", type=Path, help="Reference sequence directory, for example idle.")
    parser.add_argument("target_dir", type=Path, help="Target sequence directory to rewrite.")
    parser.add_argument("--reference-pattern", default="*.png", help="Reference glob pattern. Default: *.png")
    parser.add_argument("--target-pattern", default="*.png", help="Target glob pattern. Default: *.png")
    parser.add_argument("--alpha-threshold", type=int, default=8, help="Alpha threshold for subject bbox. Default: 8")
    parser.add_argument("--max-scale", type=float, default=1.6, help="Maximum subject scale factor. Default: 1.6")
    parser.add_argument("--height-multiplier", type=float, default=1.0, help="Multiply reference subject height. Default: 1.0")
    parser.add_argument("--backup-dir", type=Path, help="Directory for original target frames before overwriting.")
    parser.add_argument("--dry-run", action="store_true", help="Print planned changes without writing files.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    reference_dir = args.reference_dir.resolve()
    target_dir = args.target_dir.resolve()
    if not reference_dir.is_dir() or not target_dir.is_dir():
        print("error: reference_dir and target_dir must both exist", file=sys.stderr)
        return 2

    reference_frames = collect_pngs(reference_dir, args.reference_pattern)
    target_frames = collect_pngs(target_dir, args.target_pattern)
    if not reference_frames:
        print(f"error: no reference frames found in {reference_dir}", file=sys.stderr)
        return 1
    if not target_frames:
        print(f"error: no target frames found in {target_dir}", file=sys.stderr)
        return 1

    ref_metrics = median_reference_metrics(reference_frames, args.alpha_threshold)
    print(
        "reference subject: "
        f"{ref_metrics['width']:.1f}x{ref_metrics['height']:.1f}, "
        f"center_x={ref_metrics['center_x']:.1f}, bottom={ref_metrics['bottom']:.1f}"
    )
    print(f"target frames: {len(target_frames)}")

    if args.backup_dir is not None and not args.dry_run:
        backup_dir = args.backup_dir.resolve()
        backup_dir.mkdir(parents=True, exist_ok=True)
        for frame in target_frames:
            shutil.copy2(frame, backup_dir / frame.name)
            import_path = frame.with_suffix(frame.suffix + ".import")
            if import_path.exists():
                shutil.copy2(import_path, backup_dir / import_path.name)
        print(f"backup: {backup_dir}")

    for frame in target_frames:
        image = read_image(frame)
        bbox = subject_bbox(image, args.alpha_threshold)
        if bbox is None:
            print(f"skip empty: {frame.name}")
            continue
        x1, y1, x2, y2 = bbox
        scale = min((ref_metrics["height"] * args.height_multiplier) / float(max(y2 - y1, 1)), args.max_scale)
        print(f"{frame.name}: bbox={x2 - x1}x{y2 - y1}, scale={scale:.3f}")
        if args.dry_run:
            continue
        write_image(frame, scale_subject(image, ref_metrics, args.alpha_threshold, args.max_scale, args.height_multiplier))

    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
