#!/usr/bin/env python3
"""Convert an image sequence into a preview video.

This wrapper intentionally keeps all heavy lifting in ffmpeg so it works with
common PNG/JPG/WebP frame dumps and can optionally use ffmpeg's motion
interpolation filter for smoother preview videos.
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tga"}
NATURAL_SPLIT_RE = re.compile(r"(\d+)")


def natural_key(path: Path) -> list[object]:
    return [int(part) if part.isdigit() else part.lower() for part in NATURAL_SPLIT_RE.split(path.name)]


def parse_resolution(value: str) -> tuple[int, int]:
    match = re.fullmatch(r"(\d+)x(\d+)", value.strip().lower())
    if not match:
        raise argparse.ArgumentTypeError("resolution must look like 1280x720")
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
    return sorted(frames, key=natural_key)


def write_concat_list(frames: list[Path], frame_duration: float, list_path: Path) -> None:
    lines: list[str] = []
    for frame in frames:
        escaped = frame.resolve().as_posix().replace("'", "'\\''")
        lines.append(f"file '{escaped}'")
        lines.append(f"duration {frame_duration:.10f}")
    escaped_last = frames[-1].resolve().as_posix().replace("'", "'\\''")
    lines.append(f"file '{escaped_last}'")
    list_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def build_filter(args: argparse.Namespace) -> str:
    filters: list[str] = []
    if args.scale:
        width, height = args.scale
        filters.append(
            f"scale={width}:{height}:force_original_aspect_ratio=decrease,"
            f"pad={width}:{height}:(ow-iw)/2:(oh-ih)/2"
        )
    if args.interpolate:
        filters.append(
            f"minterpolate=fps={args.out_fps}:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1"
        )
    elif args.out_fps:
        filters.append(f"fps={args.out_fps}")
    filters.append("format=yuv420p")
    return ",".join(filters)


def run_ffmpeg(args: argparse.Namespace, frames: list[Path], work_dir: Path) -> None:
    concat_list = work_dir / "frames_to_video_list.txt"
    write_concat_list(frames, 1.0 / args.fps, concat_list)

    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)

    command = [
        "ffmpeg",
        "-y" if args.overwrite else "-n",
        "-hide_banner",
        "-f",
        "concat",
        "-safe",
        "0",
        "-i",
        str(concat_list),
        "-vf",
        build_filter(args),
        "-c:v",
        args.codec,
        "-crf",
        str(args.crf),
        "-preset",
        args.preset,
        "-movflags",
        "+faststart",
        str(output),
    ]

    if args.dry_run:
        print(" ".join(command))
        return

    subprocess.run(command, check=True)
    print(f"Wrote {output}")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert a directory of sequential image frames to an MP4 preview video."
    )
    parser.add_argument("input_dir", type=Path, help="Directory containing sequence frames.")
    parser.add_argument("-o", "--output", type=Path, default=Path("preview.mp4"), help="Output video path.")
    parser.add_argument("--pattern", help="Optional glob such as '*.png' or 'run_*.jpg'.")
    parser.add_argument("--fps", type=float, default=12.0, help="Input sequence frame rate.")
    parser.add_argument("--out-fps", type=float, default=30.0, help="Output frame rate.")
    parser.add_argument("--interpolate", action="store_true", help="Use ffmpeg minterpolate motion interpolation.")
    parser.add_argument("--scale", type=parse_resolution, help="Letterbox output to resolution such as 1280x720.")
    parser.add_argument("--codec", default="libx264", help="ffmpeg video codec, default: libx264.")
    parser.add_argument("--crf", type=int, default=18, help="Quality for libx264; lower is higher quality.")
    parser.add_argument("--preset", default="medium", help="ffmpeg encoder preset.")
    parser.add_argument("--overwrite", action="store_true", help="Overwrite output if it already exists.")
    parser.add_argument("--dry-run", action="store_true", help="Print ffmpeg command without running it.")
    args = parser.parse_args(argv)

    if args.fps <= 0:
        parser.error("--fps must be positive")
    if args.out_fps <= 0:
        parser.error("--out-fps must be positive")
    if not args.input_dir.is_dir():
        parser.error(f"input directory does not exist: {args.input_dir}")
    return args


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    if shutil.which("ffmpeg") is None:
        print("ffmpeg was not found in PATH. Install ffmpeg first, then rerun this tool.", file=sys.stderr)
        return 2

    frames = collect_frames(args.input_dir, args.pattern)
    if not frames:
        print("No image frames found. Use --pattern if your files use an unusual extension.", file=sys.stderr)
        return 1

    try:
        run_ffmpeg(args, frames, args.input_dir)
    except subprocess.CalledProcessError as exc:
        return exc.returncode
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
