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
JPEG_SIZE_MARKERS = {
    0xC0,
    0xC1,
    0xC2,
    0xC3,
    0xC5,
    0xC6,
    0xC7,
    0xC9,
    0xCA,
    0xCB,
    0xCD,
    0xCE,
    0xCF,
}


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


def probe_image_size(path: Path) -> tuple[int, int] | None:
    """Read image dimensions from the file header without adding extra dependencies."""
    try:
        suffix = path.suffix.lower()
        if suffix == ".png":
            return probe_png_size(path)
        if suffix in {".jpg", ".jpeg"}:
            return probe_jpeg_size(path)
        if suffix == ".webp":
            return probe_webp_size(path)
        if suffix == ".bmp":
            return probe_bmp_size(path)
        if suffix == ".tga":
            return probe_tga_size(path)
    except (OSError, ValueError):
        return None
    return None


def probe_png_size(path: Path) -> tuple[int, int] | None:
    with path.open("rb") as file:
        data = file.read(24)
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        return None
    return int.from_bytes(data[16:20], "big"), int.from_bytes(data[20:24], "big")


def probe_jpeg_size(path: Path) -> tuple[int, int] | None:
    with path.open("rb") as file:
        if file.read(2) != b"\xff\xd8":
            return None
        while True:
            marker_prefix = file.read(1)
            if not marker_prefix:
                return None
            if marker_prefix != b"\xff":
                continue
            marker_byte = file.read(1)
            while marker_byte == b"\xff":
                marker_byte = file.read(1)
            if not marker_byte:
                return None
            marker = marker_byte[0]
            if marker == 0xD9:
                return None
            if marker == 0x01 or 0xD0 <= marker <= 0xD8:
                continue
            segment_length_data = file.read(2)
            if len(segment_length_data) < 2:
                return None
            segment_length = int.from_bytes(segment_length_data, "big")
            if segment_length < 2:
                return None
            if marker in JPEG_SIZE_MARKERS:
                segment = file.read(segment_length - 2)
                if len(segment) < 5:
                    return None
                height = int.from_bytes(segment[1:3], "big")
                width = int.from_bytes(segment[3:5], "big")
                return width, height
            file.seek(segment_length - 2, 1)


def probe_webp_size(path: Path) -> tuple[int, int] | None:
    with path.open("rb") as file:
        header = file.read(12)
        if len(header) < 12 or header[:4] != b"RIFF" or header[8:12] != b"WEBP":
            return None
        while True:
            chunk_header = file.read(8)
            if len(chunk_header) < 8:
                return None
            chunk_type = chunk_header[:4]
            chunk_size = int.from_bytes(chunk_header[4:8], "little")
            chunk = file.read(chunk_size)
            if len(chunk) < chunk_size:
                return None
            if chunk_type == b"VP8X" and len(chunk) >= 10:
                width = 1 + int.from_bytes(chunk[4:7], "little")
                height = 1 + int.from_bytes(chunk[7:10], "little")
                return width, height
            if chunk_type == b"VP8L" and len(chunk) >= 5 and chunk[0] == 0x2F:
                width = 1 + (chunk[1] | ((chunk[2] & 0x3F) << 8))
                height = 1 + (
                    ((chunk[2] & 0xC0) >> 6) | (chunk[3] << 2) | ((chunk[4] & 0x0F) << 10)
                )
                return width, height
            if chunk_type == b"VP8 " and len(chunk) >= 10 and chunk[3:6] == b"\x9d\x01\x2a":
                width = int.from_bytes(chunk[6:8], "little") & 0x3FFF
                height = int.from_bytes(chunk[8:10], "little") & 0x3FFF
                return width, height
            if chunk_size % 2 == 1:
                file.seek(1, 1)


def probe_bmp_size(path: Path) -> tuple[int, int] | None:
    with path.open("rb") as file:
        data = file.read(26)
    if len(data) < 26 or data[:2] != b"BM":
        return None
    width = int.from_bytes(data[18:22], "little", signed=True)
    height = int.from_bytes(data[22:26], "little", signed=True)
    return abs(width), abs(height)


def probe_tga_size(path: Path) -> tuple[int, int] | None:
    with path.open("rb") as file:
        data = file.read(18)
    if len(data) < 18:
        return None
    width = int.from_bytes(data[12:14], "little")
    height = int.from_bytes(data[14:16], "little")
    if width <= 0 or height <= 0:
        return None
    return width, height


def make_even_size(width: int, height: int) -> tuple[int, int]:
    return width + (width % 2), height + (height % 2)


def resolve_auto_even_scale(
    args: argparse.Namespace, first_frame_size: tuple[int, int] | None
) -> tuple[tuple[int, int], tuple[int, int]] | None:
    if args.scale:
        source_size = args.scale
    else:
        if first_frame_size is None:
            return None
        source_size = first_frame_size

    even_size = make_even_size(*source_size)
    if even_size == source_size:
        return None
    return source_size, even_size


def write_concat_list(frames: list[Path], frame_duration: float, list_path: Path) -> None:
    lines: list[str] = []
    for frame in frames:
        escaped = frame.resolve().as_posix().replace("'", "'\\''")
        lines.append(f"file '{escaped}'")
        lines.append(f"duration {frame_duration:.10f}")
    escaped_last = frames[-1].resolve().as_posix().replace("'", "'\\''")
    lines.append(f"file '{escaped_last}'")
    list_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def build_filter(args: argparse.Namespace, auto_even_size: tuple[int, int] | None, fallback_dynamic_even: bool) -> str:
    filters: list[str] = []
    if args.scale:
        width, height = args.scale
        filters.append(
            f"scale={width}:{height}:force_original_aspect_ratio=decrease,"
            f"pad={width}:{height}:(ow-iw)/2:(oh-ih)/2"
        )
    if auto_even_size:
        width, height = auto_even_size
        filters.append(f"scale={width}:{height}")
    elif fallback_dynamic_even:
        filters.append("scale=ceil(iw/2)*2:ceil(ih/2)*2")
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

    first_frame_size = None if args.scale else probe_image_size(frames[0])
    auto_even_scale = resolve_auto_even_scale(args, first_frame_size)
    auto_even_size = auto_even_scale[1] if auto_even_scale else None
    fallback_dynamic_even = auto_even_scale is None and not args.scale and first_frame_size is None
    if auto_even_scale:
        source_width, source_height = auto_even_scale[0]
        even_width, even_height = auto_even_scale[1]
        print(
            "Auto-scaling odd frame size to even video size: "
            f"{source_width}x{source_height} -> {even_width}x{even_height}"
        )
    elif fallback_dynamic_even:
        print("Could not probe the first frame size; ffmpeg will auto-round output dimensions up to even values.")

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
        build_filter(args, auto_even_size, fallback_dynamic_even),
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
