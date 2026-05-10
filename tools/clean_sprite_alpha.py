#!/usr/bin/env python3
"""Clean halo artifacts from transparent PNG sprite sequences.

The script is designed for AI/video-generated frames that already have an
alpha channel but still contain white fringe, low-alpha shadows, or dirty
transparent pixels. It writes cleaned copies to a new directory by default.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import cv2
import numpy as np


NATURAL_SPLIT_RE = re.compile(r"(\d+)")


def natural_key(path: Path) -> list[object]:
    return [int(part) if part.isdigit() else part.lower() for part in NATURAL_SPLIT_RE.split(path.name)]


def collect_pngs(input_dir: Path, pattern: str) -> list[Path]:
    return sorted((path for path in input_dir.glob(pattern) if path.is_file()), key=natural_key)


def clean_alpha(alpha: np.ndarray, cutoff: int, erode: int, blur: int) -> np.ndarray:
    cleaned = alpha.copy()
    if cutoff > 0:
        cleaned = np.where(cleaned >= cutoff, cleaned, 0).astype(np.uint8)
    if erode > 0:
        kernel = np.ones((erode, erode), np.uint8)
        cleaned = cv2.erode(cleaned, kernel, iterations=1)
    if blur > 0:
        kernel_size = blur if blur % 2 == 1 else blur + 1
        cleaned = cv2.GaussianBlur(cleaned, (kernel_size, kernel_size), 0)
        if cutoff > 0:
            cleaned = np.where(cleaned >= cutoff, cleaned, 0).astype(np.uint8)
    return cleaned


def despill_white(bgr: np.ndarray, alpha: np.ndarray, amount: float, edge_alpha: int) -> np.ndarray:
    if amount <= 0.0:
        return bgr
    rgb = bgr.astype(np.float32)
    a = alpha.astype(np.float32)
    edge = np.clip((edge_alpha - a) / max(edge_alpha, 1), 0.0, 1.0)[:, :, None]
    whiteness = np.min(rgb, axis=2, keepdims=True) / 255.0
    correction = 255.0 * edge * whiteness * amount
    return np.clip(rgb - correction, 0.0, 255.0).astype(np.uint8)


def premultiply_edge(bgr: np.ndarray, alpha: np.ndarray, background: tuple[int, int, int], amount: float) -> np.ndarray:
    if amount <= 0.0:
        return bgr
    rgb = bgr.astype(np.float32)
    a = (alpha.astype(np.float32) / 255.0)[:, :, None]
    bg = np.array(background[::-1], dtype=np.float32).reshape(1, 1, 3)
    unmatte = np.where(a > 0.01, (rgb - bg * (1.0 - a) * amount) / np.maximum(a, 0.01), rgb)
    return np.clip(unmatte, 0.0, 255.0).astype(np.uint8)


def remove_small_components(alpha: np.ndarray, min_area: int) -> np.ndarray:
    if min_area <= 0:
        return alpha
    mask = (alpha > 0).astype(np.uint8)
    count, labels, stats, _centroids = cv2.connectedComponentsWithStats(mask, 8)
    if count <= 1:
        return alpha
    kept = np.zeros_like(alpha)
    for label in range(1, count):
        if int(stats[label, cv2.CC_STAT_AREA]) >= min_area:
            kept[labels == label] = alpha[labels == label]
    return kept


def process_image(path: Path, output_path: Path, args: argparse.Namespace) -> None:
    image = cv2.imread(str(path), cv2.IMREAD_UNCHANGED)
    if image is None:
        raise RuntimeError(f"failed to read {path}")
    if image.ndim != 3:
        raise RuntimeError(f"{path} is not a color image")

    if image.shape[2] == 3:
        bgr = image
        alpha = np.full(image.shape[:2], 255, dtype=np.uint8)
    elif image.shape[2] == 4:
        bgr = image[:, :, :3]
        alpha = image[:, :, 3]
    else:
        raise RuntimeError(f"{path} has unsupported channel count: {image.shape[2]}")

    cleaned_alpha = clean_alpha(alpha, args.alpha_cutoff, args.alpha_erode, args.alpha_blur)
    cleaned_alpha = remove_small_components(cleaned_alpha, args.min_area)

    cleaned_bgr = bgr.copy()
    if args.unmatte_white > 0.0:
        cleaned_bgr = premultiply_edge(cleaned_bgr, cleaned_alpha, (255, 255, 255), args.unmatte_white)
    cleaned_bgr = despill_white(cleaned_bgr, cleaned_alpha, args.despill_white, args.edge_alpha)

    transparent = cleaned_alpha == 0
    cleaned_bgr[transparent] = 0

    output_path.parent.mkdir(parents=True, exist_ok=True)
    out = np.dstack([cleaned_bgr, cleaned_alpha])
    if not cv2.imwrite(str(output_path), out):
        raise RuntimeError(f"failed to write {output_path}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Clean white halos and low-alpha artifacts from PNG sprite frames.")
    parser.add_argument("input_dir", type=Path, help="Directory containing PNG frames.")
    parser.add_argument("-o", "--output-dir", type=Path, required=True, help="Directory for cleaned PNG frames.")
    parser.add_argument("--pattern", default="*.png", help="Input glob pattern. Default: *.png")
    parser.add_argument("--alpha-cutoff", type=int, default=24, help="Set alpha below this value to 0. Default: 24")
    parser.add_argument("--alpha-erode", type=int, default=1, help="Shrink alpha mask by this kernel size. Default: 1")
    parser.add_argument("--alpha-blur", type=int, default=0, help="Optional alpha blur kernel. Default: 0")
    parser.add_argument("--despill-white", type=float, default=0.45, help="Reduce white fringe on transparent edges. Default: 0.45")
    parser.add_argument("--unmatte-white", type=float, default=0.0, help="Try to undo white background premultiplication. Default: 0")
    parser.add_argument("--edge-alpha", type=int, default=180, help="Alpha below this is treated as edge. Default: 180")
    parser.add_argument("--min-area", type=int, default=0, help="Remove alpha islands smaller than this pixel area. Default: 0")
    parser.add_argument("--overwrite", action="store_true", help="Allow overwriting files in output-dir.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.input_dir.exists() or not args.input_dir.is_dir():
        print(f"input directory does not exist: {args.input_dir}", file=sys.stderr)
        return 2

    frames = collect_pngs(args.input_dir, args.pattern)
    if not frames:
        print(f"no frames matched {args.pattern} in {args.input_dir}", file=sys.stderr)
        return 2

    if args.output_dir.resolve() == args.input_dir.resolve() and not args.overwrite:
        print("refusing to write into input-dir without --overwrite", file=sys.stderr)
        return 2

    written = 0
    for frame in frames:
        output_path = args.output_dir / frame.name
        if output_path.exists() and not args.overwrite:
            print(f"output exists, use --overwrite: {output_path}", file=sys.stderr)
            return 2
        process_image(frame, output_path, args)
        written += 1

    print(f"cleaned {written} frame(s) -> {args.output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
