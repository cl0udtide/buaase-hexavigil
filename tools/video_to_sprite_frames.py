#!/usr/bin/env python3
"""Convert an MP4 animation into Godot-ready transparent PNG sprite frames.

The tool is intentionally conservative: it never overwrites existing frames
unless --overwrite is passed, and watermark removal is opt-in because it is
usually content-specific.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import cv2
import numpy as np


def parse_color(value: str) -> tuple[int, int, int]:
    raw = value.strip()
    if raw.startswith("#"):
        raw = raw[1:]
    if len(raw) == 6:
        return int(raw[0:2], 16), int(raw[2:4], 16), int(raw[4:6], 16)
    parts = [part.strip() for part in value.split(",")]
    if len(parts) != 3:
        raise argparse.ArgumentTypeError("color must be #RRGGBB or R,G,B")
    color = tuple(int(part) for part in parts)
    if any(channel < 0 or channel > 255 for channel in color):
        raise argparse.ArgumentTypeError("color channels must be in 0..255")
    return color  # type: ignore[return-value]


def parse_rect(value: str) -> tuple[int, int, int, int]:
    parts = [part.strip() for part in value.split(",")]
    if len(parts) != 4:
        raise argparse.ArgumentTypeError("rect must be x,y,w,h")
    rect = tuple(int(part) for part in parts)
    if rect[2] <= 0 or rect[3] <= 0:
        raise argparse.ArgumentTypeError("rect width and height must be positive")
    return rect  # type: ignore[return-value]


def parse_size(value: str) -> tuple[int, int]:
    parts = value.lower().split("x")
    if len(parts) != 2:
        raise argparse.ArgumentTypeError("size must look like 128x128")
    size = int(parts[0]), int(parts[1])
    if size[0] <= 0 or size[1] <= 0:
        raise argparse.ArgumentTypeError("size values must be positive")
    return size


def clamp_rect(rect: tuple[int, int, int, int], width: int, height: int) -> tuple[int, int, int, int] | None:
    x, y, w, h = rect
    x1 = max(x, 0)
    y1 = max(y, 0)
    x2 = min(x + w, width)
    y2 = min(y + h, height)
    if x1 >= x2 or y1 >= y2:
        return None
    return x1, y1, x2 - x1, y2 - y1


def sample_corner_color(frame_bgr: np.ndarray, sample_size: int) -> np.ndarray:
    height, width = frame_bgr.shape[:2]
    size = max(1, min(sample_size, height, width))
    corners = [
        frame_bgr[0:size, 0:size],
        frame_bgr[0:size, width - size : width],
        frame_bgr[height - size : height, 0:size],
        frame_bgr[height - size : height, width - size : width],
    ]
    samples = np.concatenate([corner.reshape(-1, 3) for corner in corners], axis=0)
    return np.median(samples, axis=0).astype(np.float32)


def make_alpha_from_background(
    frame_bgr: np.ndarray,
    bg_bgr: np.ndarray,
    threshold: float,
    softness: float,
    denoise: int,
) -> np.ndarray:
    diff = frame_bgr.astype(np.float32) - bg_bgr.reshape(1, 1, 3)
    distance = np.linalg.norm(diff, axis=2)
    alpha = ((distance - threshold) / max(softness, 1.0) * 255.0).clip(0, 255).astype(np.uint8)
    if denoise > 0:
        kernel = np.ones((denoise, denoise), np.uint8)
        alpha = cv2.morphologyEx(alpha, cv2.MORPH_OPEN, kernel)
        alpha = cv2.morphologyEx(alpha, cv2.MORPH_CLOSE, kernel)
    return alpha


def refine_alpha(alpha: np.ndarray, erode: int, blur: int, cutoff: int) -> np.ndarray:
    refined = alpha
    if erode > 0:
        kernel = np.ones((erode, erode), np.uint8)
        refined = cv2.erode(refined, kernel, iterations=1)
    if blur > 0:
        kernel_size = blur if blur % 2 == 1 else blur + 1
        refined = cv2.GaussianBlur(refined, (kernel_size, kernel_size), 0)
    if cutoff > 0:
        refined = np.where(refined >= cutoff, refined, 0).astype(np.uint8)
    return refined


def despill_background_color(frame_bgr: np.ndarray, alpha: np.ndarray, bg_bgr: np.ndarray, amount: float) -> np.ndarray:
    if amount <= 0.0:
        return frame_bgr
    rgb = frame_bgr.astype(np.float32)
    bg = bg_bgr.reshape(1, 1, 3).astype(np.float32)
    edge_strength = (1.0 - (alpha.astype(np.float32) / 255.0))[:, :, None]
    correction = bg * edge_strength * amount
    return np.clip(rgb - correction, 0, 255).astype(np.uint8)


def keep_largest_alpha_component(alpha: np.ndarray) -> np.ndarray:
    mask = (alpha > 0).astype(np.uint8)
    count, labels, stats, _centroids = cv2.connectedComponentsWithStats(mask, 8)
    if count <= 1:
        return alpha
    largest_label = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    kept = np.where(labels == largest_label, alpha, 0).astype(np.uint8)
    return kept


def apply_watermark_rects(
    frame_bgr: np.ndarray,
    alpha: np.ndarray | None,
    rects: list[tuple[int, int, int, int]],
    mode: str,
) -> tuple[np.ndarray, np.ndarray | None]:
    if not rects:
        return frame_bgr, alpha
    height, width = frame_bgr.shape[:2]
    if mode == "transparent":
        if alpha is None:
            alpha = np.full((height, width), 255, dtype=np.uint8)
        for rect in rects:
            clipped = clamp_rect(rect, width, height)
            if clipped is None:
                continue
            x, y, w, h = clipped
            alpha[y : y + h, x : x + w] = 0
        return frame_bgr, alpha

    mask = np.zeros((height, width), dtype=np.uint8)
    for rect in rects:
        clipped = clamp_rect(rect, width, height)
        if clipped is None:
            continue
        x, y, w, h = clipped
        mask[y : y + h, x : x + w] = 255
    if np.any(mask):
        frame_bgr = cv2.inpaint(frame_bgr, mask, 3, cv2.INPAINT_TELEA)
    return frame_bgr, alpha


def alpha_bbox(alpha: np.ndarray, margin: int) -> tuple[int, int, int, int] | None:
    ys, xs = np.where(alpha > 0)
    if len(xs) == 0 or len(ys) == 0:
        return None
    x1 = max(int(xs.min()) - margin, 0)
    y1 = max(int(ys.min()) - margin, 0)
    x2 = min(int(xs.max()) + 1 + margin, alpha.shape[1])
    y2 = min(int(ys.max()) + 1 + margin, alpha.shape[0])
    return x1, y1, x2 - x1, y2 - y1


def resize_into_canvas(rgba: np.ndarray, size: tuple[int, int], scale: float) -> np.ndarray:
    target_w, target_h = size
    src_h, src_w = rgba.shape[:2]
    if src_w <= 0 or src_h <= 0:
        return np.zeros((target_h, target_w, 4), dtype=np.uint8)

    fit = min(target_w / src_w, target_h / src_h) * scale
    out_w = max(1, min(target_w, int(round(src_w * fit))))
    out_h = max(1, min(target_h, int(round(src_h * fit))))
    resized = cv2.resize(rgba, (out_w, out_h), interpolation=cv2.INTER_AREA if fit < 1 else cv2.INTER_CUBIC)
    canvas = np.zeros((target_h, target_w, 4), dtype=np.uint8)
    x = (target_w - out_w) // 2
    y = target_h - out_h
    canvas[y : y + out_h, x : x + out_w] = resized
    return canvas


def crop_frame(
    frame_bgr: np.ndarray,
    alpha: np.ndarray | None,
    args: argparse.Namespace,
) -> tuple[np.ndarray, np.ndarray | None]:
    height, width = frame_bgr.shape[:2]
    crop_rect: tuple[int, int, int, int] | None = None
    if args.crop:
        crop_rect = clamp_rect(args.crop, width, height)
    elif args.trim and alpha is not None:
        crop_rect = alpha_bbox(alpha, args.trim_margin)

    if crop_rect is None:
        return frame_bgr, alpha
    x, y, w, h = crop_rect
    cropped_bgr = frame_bgr[y : y + h, x : x + w]
    cropped_alpha = alpha[y : y + h, x : x + w] if alpha is not None else None
    return cropped_bgr, cropped_alpha


def convert_frame(frame_bgr: np.ndarray, args: argparse.Namespace, fixed_bg_bgr: np.ndarray | None) -> np.ndarray:
    alpha: np.ndarray | None = None
    bg_bgr_for_despill: np.ndarray | None = None
    if args.bg_mode != "none":
        if fixed_bg_bgr is not None:
            bg_bgr = fixed_bg_bgr
        elif args.bg_mode == "color":
            bg_bgr = np.array(args.bg_color[::-1], dtype=np.float32)
        else:
            bg_bgr = sample_corner_color(frame_bgr, args.corner_sample)
        bg_bgr_for_despill = bg_bgr
        alpha = make_alpha_from_background(frame_bgr, bg_bgr, args.threshold, args.softness, args.denoise)
        if args.keep_largest:
            alpha = keep_largest_alpha_component(alpha)
        alpha = refine_alpha(alpha, args.alpha_erode, args.alpha_blur, args.alpha_cutoff)
        frame_bgr = despill_background_color(frame_bgr, alpha, bg_bgr_for_despill, args.despill)

    frame_bgr, alpha = apply_watermark_rects(frame_bgr, alpha, args.watermark_rect, args.watermark_mode)
    frame_bgr, alpha = crop_frame(frame_bgr, alpha, args)

    if alpha is None:
        alpha = np.full(frame_bgr.shape[:2], 255, dtype=np.uint8)
    rgba = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGBA)
    rgba[:, :, 3] = alpha
    return resize_into_canvas(rgba, args.size, args.scale)


def should_take_frame(index: int, source_fps: float, target_fps: float | None) -> bool:
    if target_fps is None or target_fps <= 0 or source_fps <= 0:
        return True
    source_time = index / source_fps
    previous_slot = math.floor(((index - 1) / source_fps) * target_fps) if index > 0 else -1
    current_slot = math.floor(source_time * target_fps)
    return current_slot > previous_slot


def write_frame(path: Path, rgba: np.ndarray, overwrite: bool) -> None:
    if path.exists() and not overwrite:
        raise FileExistsError(f"Refusing to overwrite existing frame: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    bgra = cv2.cvtColor(rgba, cv2.COLOR_RGBA2BGRA)
    if not cv2.imwrite(str(path), bgra):
        raise OSError(f"Failed to write frame: {path}")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert MP4/video into transparent PNG frames ready for Godot sprite folders."
    )
    parser.add_argument("input", type=Path, help="Input video, for example idle.mp4.")
    parser.add_argument("-o", "--output-dir", type=Path, required=True, help="Directory to write PNG frames.")
    parser.add_argument("--prefix", required=True, help="Output filename prefix, for example guard_t1_idle.")
    parser.add_argument("--size", type=parse_size, default=(128, 128), help="Output canvas size, default 128x128.")
    parser.add_argument("--fps", type=float, help="Sample output frames at this fps. Omit to keep all video frames.")
    parser.add_argument("--max-frames", type=int, help="Stop after writing this many frames.")
    parser.add_argument("--start-index", type=int, default=0, help="Starting output frame number.")
    parser.add_argument("--overwrite", action="store_true", help="Overwrite existing PNG frames.")

    parser.add_argument("--bg-mode", choices=["corner", "color", "none"], default="corner")
    parser.add_argument("--bg-color", type=parse_color, default=(0, 255, 0), help="Background color for --bg-mode color.")
    parser.add_argument("--fixed-bg", action="store_true", help="Use first frame background color for the whole video.")
    parser.add_argument("--corner-sample", type=int, default=12, help="Corner sample size for background color.")
    parser.add_argument("--threshold", type=float, default=32.0, help="Background color distance threshold.")
    parser.add_argument("--softness", type=float, default=28.0, help="Alpha feather range after threshold.")
    parser.add_argument("--denoise", type=int, default=2, help="Morphological cleanup kernel size; 0 disables.")
    parser.add_argument("--keep-largest", action="store_true", help="Keep only largest foreground blob.")
    parser.add_argument("--alpha-erode", type=int, default=0, help="Shrink alpha edge by this kernel size; useful for halos.")
    parser.add_argument("--alpha-blur", type=int, default=0, help="Soften alpha after erosion with this blur size.")
    parser.add_argument("--alpha-cutoff", type=int, default=0, help="Drop alpha values below this threshold.")
    parser.add_argument("--despill", type=float, default=0.0, help="Subtract background color from transparent edges, 0..1.")

    parser.add_argument("--trim", action="store_true", help="Trim to alpha bounds before fitting into output canvas.")
    parser.add_argument("--trim-margin", type=int, default=6)
    parser.add_argument("--crop", type=parse_rect, help="Manual crop rectangle before fitting: x,y,w,h.")
    parser.add_argument("--scale", type=float, default=0.92, help="Scale after fitting into output canvas.")

    parser.add_argument(
        "--watermark-rect",
        type=parse_rect,
        action="append",
        default=[],
        help="Optional watermark rectangle x,y,w,h. Can be passed multiple times.",
    )
    parser.add_argument("--watermark-mode", choices=["inpaint", "transparent"], default="inpaint")
    args = parser.parse_args(argv)

    if not args.input.is_file():
        parser.error(f"input video does not exist: {args.input}")
    if args.fps is not None and args.fps <= 0:
        parser.error("--fps must be positive")
    if args.max_frames is not None and args.max_frames <= 0:
        parser.error("--max-frames must be positive")
    if args.threshold < 0:
        parser.error("--threshold must be non-negative")
    if args.softness <= 0:
        parser.error("--softness must be positive")
    if args.scale <= 0:
        parser.error("--scale must be positive")
    if args.alpha_erode < 0 or args.alpha_blur < 0:
        parser.error("--alpha-erode and --alpha-blur must be non-negative")
    if args.alpha_cutoff < 0 or args.alpha_cutoff > 255:
        parser.error("--alpha-cutoff must be in 0..255")
    if args.despill < 0.0 or args.despill > 1.0:
        parser.error("--despill must be in 0..1")
    return args


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    capture = cv2.VideoCapture(str(args.input))
    if not capture.isOpened():
        print(f"Failed to open video: {args.input}", file=sys.stderr)
        return 1

    source_fps = float(capture.get(cv2.CAP_PROP_FPS) or 0.0)
    fixed_bg_bgr: np.ndarray | None = None
    written = 0
    index = 0

    try:
        while True:
            ok, frame_bgr = capture.read()
            if not ok:
                break
            if not should_take_frame(index, source_fps, args.fps):
                index += 1
                continue
            if fixed_bg_bgr is None and args.fixed_bg and args.bg_mode == "corner":
                fixed_bg_bgr = sample_corner_color(frame_bgr, args.corner_sample)
            rgba = convert_frame(frame_bgr, args, fixed_bg_bgr)
            output_index = args.start_index + written
            output_path = args.output_dir / f"{args.prefix}_{output_index:03d}.png"
            write_frame(output_path, rgba, args.overwrite)
            written += 1
            index += 1
            if args.max_frames is not None and written >= args.max_frames:
                break
    except (FileExistsError, OSError) as exc:
        print(str(exc), file=sys.stderr)
        return 2
    finally:
        capture.release()

    if written == 0:
        print("No frames were written. Check --fps/--max-frames and input video.", file=sys.stderr)
        return 1
    print(f"Wrote {written} frame(s) to {args.output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
