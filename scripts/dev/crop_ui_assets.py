#!/usr/bin/env python3
"""Crop generated UI asset sheets into transparent PNG assets.

The crop order is parsed from docs/UI_ASSET_GENERATION_PROMPTS.md. Sheets whose
detected asset count does not match the documented order are skipped.
"""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import numpy as np
from PIL import Image, ImageFilter

try:
    import cv2  # type: ignore
except ImportError:  # pragma: no cover - fallback for lighter environments.
    cv2 = None


ROOT = Path(__file__).resolve().parents[2]
DOC_PATH = ROOT / "docs" / "UI_ASSET_GENERATION_PROMPTS.md"
RAW_DIR = ROOT / "assets" / "raw"
OUT_DIR = ROOT / "assets" / "ui" / "generated"

DEFAULT_THRESHOLD = 24.0
DEFAULT_ALPHA_TRANSPARENT_THRESHOLD = 30.0
DEFAULT_ALPHA_OPAQUE_THRESHOLD = 60.0
DEFAULT_ALPHA_CUTOFF = 0
DEFAULT_EDGE_BAND_RADIUS = 2
DEFAULT_PADDING = 8
INTERNAL_HOLE_THRESHOLD = 10.0
MIN_AREA_RATIO = 0.00005
MIN_BACKGROUND_COMPONENT_AREA = 48
MORPH_SIZES = (9, 15, 21, 31, 41, 51, 61, 81, 101, 121, 151, 181, 221)

CROP_ORDER_OVERRIDES = {
    "source_sheet_05_operator_card.png": [
        "frame_bottom_deploy_rail_base",
        "frame_operator_card_base",
        "frame_operator_card_selected_overlay",
        "frame_operator_card_deployed_overlay",
        "frame_operator_card_cooldown_overlay",
        "frame_operator_card_cooldown_selected_overlay",
        "frame_operator_title_strip",
        "frame_operator_portrait_backplate",
        "frame_operator_portrait_frame",
        "frame_operator_cost_badge",
        "frame_operator_stat_row",
    ],
}


@dataclass(frozen=True)
class Component:
    x1: int
    y1: int
    x2: int
    y2: int
    area: int

    @property
    def width(self) -> int:
        return self.x2 - self.x1

    @property
    def height(self) -> int:
        return self.y2 - self.y1


@dataclass(frozen=True)
class Detection:
    background: tuple[int, int, int]
    base_mask: np.ndarray
    components: list[Component]
    morph_size: int
    counts: list[tuple[int, int]]


def parse_crop_orders(doc_path: Path) -> dict[str, list[str]]:
    """Return source sheet file names mapped to documented asset keys."""
    source_re = re.compile(r"`(source_sheet_\d+_[^`]+\.png)`")
    key_re = re.compile(r"\s*\d+\.\s*`([A-Za-z0-9_]+)`\s*$")

    orders: dict[str, list[str]] = {}
    current_sheet: str | None = None
    current_keys: list[str] = []

    for line in doc_path.read_text(encoding="utf-8").splitlines():
        source_match = source_re.search(line)
        if source_match:
            if current_sheet is not None:
                orders[current_sheet] = current_keys
            current_sheet = source_match.group(1)
            current_keys = []
            continue

        if current_sheet is None:
            continue

        key_match = key_re.match(line)
        if key_match:
            current_keys.append(key_match.group(1))

    if current_sheet is not None:
        orders[current_sheet] = current_keys

    return {sheet: keys for sheet, keys in orders.items() if keys}


def estimate_background(rgb: np.ndarray) -> np.ndarray:
    """Estimate the solid sheet background from four corner samples."""
    height, width, _ = rgb.shape
    sample_size = max(8, min(32, height // 20, width // 20))
    samples = np.concatenate(
        (
            rgb[:sample_size, :sample_size].reshape(-1, 3),
            rgb[:sample_size, width - sample_size :].reshape(-1, 3),
            rgb[height - sample_size :, :sample_size].reshape(-1, 3),
            rgb[height - sample_size :, width - sample_size :].reshape(-1, 3),
        ),
        axis=0,
    )
    return np.median(samples, axis=0)


def apply_crop_order_overrides(orders: dict[str, list[str]]) -> dict[str, list[str]]:
    merged = {sheet: list(keys) for sheet, keys in orders.items()}
    for sheet, keys in CROP_ORDER_OVERRIDES.items():
        merged[sheet] = list(keys)
    return merged


def background_distance(image: Image.Image) -> tuple[np.ndarray, np.ndarray, tuple[int, int, int]]:
    rgba = np.array(image.convert("RGBA"))
    rgb = rgba[:, :, :3].astype(np.int16)
    background = estimate_background(rgb)
    distance = np.sqrt(((rgb - background) ** 2).sum(axis=2))
    return rgba, distance, tuple(int(round(channel)) for channel in background)


def make_base_mask(
    image: Image.Image, threshold: float
) -> tuple[np.ndarray, np.ndarray, np.ndarray, tuple[int, int, int]]:
    rgba, distance, background = background_distance(image)
    mask = (distance > threshold) & (rgba[:, :, 3] > 0)
    return mask, rgba, distance, background


def smoothstep(value: np.ndarray) -> np.ndarray:
    clipped = np.clip(value, 0.0, 1.0)
    return clipped * clipped * (3.0 - 2.0 * clipped)


def remove_small_background_components(background_candidate: np.ndarray) -> np.ndarray:
    if cv2 is None:
        return background_candidate

    labels_count, labels, stats, _centroids = cv2.connectedComponentsWithStats(
        background_candidate.astype(np.uint8), connectivity=8
    )
    cleaned = np.zeros_like(background_candidate, dtype=bool)
    for label in range(1, labels_count):
        if int(stats[label, cv2.CC_STAT_AREA]) >= MIN_BACKGROUND_COMPONENT_AREA:
            cleaned[labels == label] = True
    return cleaned


def connected_to_image_border(mask: np.ndarray) -> np.ndarray:
    if cv2 is None:
        return connected_to_image_border_fallback(mask)

    labels_count, labels, _stats, _centroids = cv2.connectedComponentsWithStats(
        mask.astype(np.uint8), connectivity=8
    )
    if labels_count <= 1:
        return np.zeros_like(mask, dtype=bool)

    border_labels = set(np.unique(labels[0, :]))
    border_labels.update(np.unique(labels[-1, :]))
    border_labels.update(np.unique(labels[:, 0]))
    border_labels.update(np.unique(labels[:, -1]))
    border_labels.discard(0)

    if not border_labels:
        return np.zeros_like(mask, dtype=bool)
    return np.isin(labels, list(border_labels))


def connected_to_image_border_fallback(mask: np.ndarray) -> np.ndarray:
    height, width = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    stack: list[tuple[int, int]] = []

    for x in range(width):
        if mask[0, x]:
            stack.append((x, 0))
        if mask[height - 1, x]:
            stack.append((x, height - 1))
    for y in range(height):
        if mask[y, 0]:
            stack.append((0, y))
        if mask[y, width - 1]:
            stack.append((width - 1, y))

    while stack:
        x, y = stack.pop()
        if seen[y, x] or not mask[y, x]:
            continue
        seen[y, x] = True
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < width and 0 <= ny < height and not seen[ny, nx] and mask[ny, nx]:
                stack.append((nx, ny))

    return seen


def dilate_mask(mask: np.ndarray, radius: int) -> np.ndarray:
    if radius <= 0:
        return mask

    mask_u8 = mask.astype(np.uint8) * 255
    kernel_size = radius * 2 + 1
    if cv2 is not None:
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (kernel_size, kernel_size))
        return cv2.dilate(mask_u8, kernel) > 0

    return np.array(Image.fromarray(mask_u8).filter(ImageFilter.MaxFilter(kernel_size))) > 0


def make_alpha_matte(
    rgba: np.ndarray,
    distance: np.ndarray,
    transparent_threshold: float,
    opaque_threshold: float,
    alpha_cutoff: int,
) -> np.ndarray:
    if opaque_threshold <= transparent_threshold:
        raise ValueError("opaque alpha threshold must be greater than transparent threshold")

    edge_connected_background = connected_to_image_border(distance <= transparent_threshold)
    strict_background = remove_small_background_components(distance <= INTERNAL_HOLE_THRESHOLD)
    internal_holes = strict_background & ~connected_to_image_border(strict_background)
    background_core = edge_connected_background | internal_holes
    edge_band = dilate_mask(background_core, DEFAULT_EDGE_BAND_RADIUS) & ~background_core

    alpha_u8 = np.full(distance.shape, 255, dtype=np.uint8)
    alpha_u8[background_core] = 0

    edge_alpha = smoothstep(
        (distance[edge_band] - transparent_threshold) / (opaque_threshold - transparent_threshold)
    )
    edge_alpha_u8 = np.clip(edge_alpha * 255.0, 0.0, 255.0).astype(np.uint8)

    if alpha_cutoff > 0:
        cutoff = np.clip(alpha_cutoff, 0, 254)
        kept = edge_alpha_u8 >= cutoff
        remapped = np.zeros_like(edge_alpha_u8, dtype=np.float32)
        remapped[kept] = (edge_alpha_u8[kept].astype(np.float32) - cutoff) / (255.0 - cutoff)
        edge_alpha_u8 = np.clip(smoothstep(remapped) * 255.0, 0.0, 255.0).astype(np.uint8)

    alpha_u8[edge_band] = edge_alpha_u8
    alpha_u8 = np.minimum(alpha_u8, rgba[:, :, 3])

    return alpha_u8


def remove_tiny_alpha_components(alpha: np.ndarray) -> np.ndarray:
    if cv2 is None:
        return alpha

    support = alpha > 0
    labels_count, labels, stats, _centroids = cv2.connectedComponentsWithStats(
        support.astype(np.uint8), connectivity=8
    )
    min_area = max(3, min(24, int(alpha.shape[0] * alpha.shape[1] * 0.00001)))
    cleaned = alpha.copy()
    for label in range(1, labels_count):
        if int(stats[label, cv2.CC_STAT_AREA]) < min_area:
            cleaned[labels == label] = 0
    return cleaned


def close_mask(mask: np.ndarray, kernel_size: int) -> np.ndarray:
    if kernel_size <= 1:
        return mask

    mask_u8 = mask.astype(np.uint8) * 255
    if cv2 is not None:
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (kernel_size, kernel_size))
        closed = cv2.morphologyEx(mask_u8, cv2.MORPH_CLOSE, kernel)
        return closed > 0

    closed_image = Image.fromarray(mask_u8).filter(ImageFilter.MaxFilter(kernel_size))
    closed_image = closed_image.filter(ImageFilter.MinFilter(kernel_size))
    return np.array(closed_image) > 0


def connected_components(mask: np.ndarray, min_area: int) -> list[Component]:
    if cv2 is not None:
        labels_count, _labels, stats, _centroids = cv2.connectedComponentsWithStats(
            mask.astype(np.uint8), connectivity=8
        )
        components: list[Component] = []
        for label in range(1, labels_count):
            area = int(stats[label, cv2.CC_STAT_AREA])
            if area < min_area:
                continue
            x = int(stats[label, cv2.CC_STAT_LEFT])
            y = int(stats[label, cv2.CC_STAT_TOP])
            width = int(stats[label, cv2.CC_STAT_WIDTH])
            height = int(stats[label, cv2.CC_STAT_HEIGHT])
            components.append(Component(x, y, x + width, y + height, area))
        return components

    return connected_components_fallback(mask, min_area)


def connected_components_fallback(mask: np.ndarray, min_area: int) -> list[Component]:
    height, width = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    components: list[Component] = []
    ys, xs = np.nonzero(mask)

    for index in np.lexsort((xs, ys)):
        y = int(ys[index])
        x = int(xs[index])
        if seen[y, x] or not mask[y, x]:
            continue

        stack = [(x, y)]
        seen[y, x] = True
        area = 0
        min_x = max_x = x
        min_y = max_y = y

        while stack:
            cx, cy = stack.pop()
            area += 1
            min_x = min(min_x, cx)
            max_x = max(max_x, cx)
            min_y = min(min_y, cy)
            max_y = max(max_y, cy)

            for nx in (cx - 1, cx, cx + 1):
                for ny in (cy - 1, cy, cy + 1):
                    if nx == cx and ny == cy:
                        continue
                    if 0 <= nx < width and 0 <= ny < height and not seen[ny, nx] and mask[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((nx, ny))

        if area >= min_area:
            components.append(Component(min_x, min_y, max_x + 1, max_y + 1, area))

    return components


def sort_visual_order(components: Iterable[Component]) -> list[Component]:
    """Sort by visual rows using top edges, then left-to-right within each row."""
    components = list(components)
    if not components:
        return []

    heights = [component.height for component in components]
    row_tolerance = max(24, int(np.median(heights) * 0.30))
    rows: list[dict[str, object]] = []

    for component in sorted(components, key=lambda item: (item.y1, item.x1)):
        best_row: dict[str, object] | None = None
        best_delta: float | None = None

        for row in rows:
            delta = abs(component.y1 - float(row["top"]))
            if delta <= row_tolerance and (best_delta is None or delta < best_delta):
                best_row = row
                best_delta = delta

        if best_row is None:
            rows.append({"top": float(component.y1), "components": [component]})
        else:
            row_components = best_row["components"]
            assert isinstance(row_components, list)
            row_components.append(component)
            best_row["top"] = float(np.median([item.y1 for item in row_components]))

    ordered: list[Component] = []
    for row in sorted(rows, key=lambda item: float(item["top"])):
        row_components = row["components"]
        assert isinstance(row_components, list)
        ordered.extend(sorted(row_components, key=lambda item: item.x1))
    return ordered


def detect_components(mask: np.ndarray, expected_count: int) -> tuple[list[Component], int, list[tuple[int, int]]]:
    min_area = max(8, int(mask.shape[0] * mask.shape[1] * MIN_AREA_RATIO))
    counts: list[tuple[int, int]] = []

    for morph_size in MORPH_SIZES:
        closed = close_mask(mask, morph_size)
        components = sort_visual_order(connected_components(closed, min_area))
        counts.append((morph_size, len(components)))
        if len(components) == expected_count:
            return components, morph_size, counts

    return [], -1, counts


def tighten_to_source_mask(component: Component, source_mask: np.ndarray, padding: int) -> Component:
    roi = source_mask[component.y1 : component.y2, component.x1 : component.x2]
    ys, xs = np.nonzero(roi)
    if len(xs) == 0:
        return component

    image_height, image_width = source_mask.shape
    x1 = max(0, component.x1 + int(xs.min()) - padding)
    y1 = max(0, component.y1 + int(ys.min()) - padding)
    x2 = min(image_width, component.x1 + int(xs.max()) + 1 + padding)
    y2 = min(image_height, component.y1 + int(ys.max()) + 1 + padding)
    return Component(x1, y1, x2, y2, int(len(xs)))


def make_transparent_crop(
    rgba: np.ndarray,
    matte_alpha: np.ndarray,
    background: tuple[int, int, int],
    box: Component,
) -> Image.Image:
    crop = rgba[box.y1 : box.y2, box.x1 : box.x2].copy()
    alpha = remove_tiny_alpha_components(matte_alpha[box.y1 : box.y2, box.x1 : box.x2])
    crop[:, :, 3] = alpha

    # Source sheets are rendered against a solid green matte. Reconstruct edge
    # colors for partial-alpha pixels so the transparent PNG does not keep a
    # green halo when composited in-game.
    alpha_float = alpha.astype(np.float32) / 255.0
    edge = (alpha > 0) & (alpha < 255)
    if np.any(edge):
        rgb = crop[:, :, :3].astype(np.float32)
        bg = np.array(background, dtype=np.float32)
        safe_alpha = np.maximum(alpha_float[:, :, None], 1.0 / 255.0)
        unmatted = (rgb - bg * (1.0 - alpha_float[:, :, None])) / safe_alpha
        rgb[edge] = np.clip(unmatted[edge], 0.0, 255.0)
        crop[:, :, :3] = rgb.astype(np.uint8)

    crop[crop[:, :, 3] == 0, :3] = 0
    return Image.fromarray(crop)


def clean_output_dir(output_dir: Path) -> None:
    if not output_dir.exists():
        return
    for path in output_dir.glob("*.png"):
        path.unlink()


def process_sheet(
    sheet_path: Path,
    keys: list[str],
    output_dir: Path,
    threshold: float,
    alpha_transparent_threshold: float,
    alpha_opaque_threshold: float,
    alpha_cutoff: int,
    padding: int,
    dry_run: bool,
) -> tuple[bool, str, int]:
    image = Image.open(sheet_path).convert("RGBA")
    base_mask, rgba, distance, background = make_base_mask(image, threshold)
    components, morph_size, counts = detect_components(base_mask, len(keys))

    if len(components) != len(keys):
        count_text = ", ".join(f"{size}:{count}" for size, count in counts)
        return (
            False,
            f"{sheet_path.name}: expected {len(keys)}, found no matching count "
            f"(bg #{background[0]:02X}{background[1]:02X}{background[2]:02X}, counts {count_text})",
            0,
        )

    tight_components = [
        tighten_to_source_mask(component, base_mask, padding) for component in components
    ]
    matte_alpha = make_alpha_matte(
        rgba, distance, alpha_transparent_threshold, alpha_opaque_threshold, alpha_cutoff
    )

    if not dry_run:
        output_dir.mkdir(parents=True, exist_ok=True)
        for key, component in zip(keys, tight_components):
            crop = make_transparent_crop(rgba, matte_alpha, background, component)
            crop.save(output_dir / f"{key}.png")

    action = "detected" if dry_run else "wrote"
    return (
        True,
        f"{sheet_path.name}: {action} {len(keys)} assets "
        f"(bg #{background[0]:02X}{background[1]:02X}{background[2]:02X}, morph {morph_size})",
        len(keys),
    )


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--doc", type=Path, default=DOC_PATH, help="Prompt markdown file.")
    parser.add_argument("--raw-dir", type=Path, default=RAW_DIR, help="Directory containing source_sheet_*.png.")
    parser.add_argument("--output-dir", type=Path, default=OUT_DIR, help="Directory for generated PNG assets.")
    parser.add_argument("--threshold", type=float, default=DEFAULT_THRESHOLD, help="RGB background distance threshold.")
    parser.add_argument(
        "--alpha-transparent-threshold",
        type=float,
        default=DEFAULT_ALPHA_TRANSPARENT_THRESHOLD,
        help="Distance at or below which output alpha becomes transparent.",
    )
    parser.add_argument(
        "--alpha-opaque-threshold",
        type=float,
        default=DEFAULT_ALPHA_OPAQUE_THRESHOLD,
        help="Distance at or above which output alpha becomes opaque.",
    )
    parser.add_argument(
        "--alpha-cutoff",
        type=int,
        default=DEFAULT_ALPHA_CUTOFF,
        help="Drop output alpha below this value and remap the remaining alpha range.",
    )
    parser.add_argument("--padding", type=int, default=DEFAULT_PADDING, help="Transparent crop padding in pixels.")
    parser.add_argument(
        "--sheet",
        action="append",
        help="Only process this source sheet file name. Can be passed more than once.",
    )
    parser.add_argument("--dry-run", action="store_true", help="Report detections without writing PNG files.")
    parser.add_argument("--clean", action="store_true", help="Remove existing generated PNGs before writing.")
    return parser


def main() -> int:
    args = build_arg_parser().parse_args()
    crop_orders = apply_crop_order_overrides(parse_crop_orders(args.doc))
    requested_sheets = set(args.sheet or [])

    if args.clean and not args.dry_run:
        clean_output_dir(args.output_dir)

    processed_sheets = 0
    skipped_sheets = 0
    written_assets = 0

    raw_sheets = sorted(args.raw_dir.glob("source_sheet_*.png"))
    if requested_sheets:
        raw_sheets = [path for path in raw_sheets if path.name in requested_sheets]

    seen_raw = {path.name for path in raw_sheets}
    for sheet_name in sorted(requested_sheets - seen_raw):
        print(f"WARN {sheet_name}: requested source sheet is missing")
        skipped_sheets += 1

    for sheet_path in raw_sheets:
        keys = crop_orders.get(sheet_path.name)
        if keys is None:
            print(f"SKIP {sheet_path.name}: no crop order in {args.doc}")
            skipped_sheets += 1
            continue

        ok, message, count = process_sheet(
            sheet_path=sheet_path,
            keys=keys,
            output_dir=args.output_dir,
            threshold=args.threshold,
            alpha_transparent_threshold=args.alpha_transparent_threshold,
            alpha_opaque_threshold=args.alpha_opaque_threshold,
            alpha_cutoff=args.alpha_cutoff,
            padding=args.padding,
            dry_run=args.dry_run,
        )
        if ok:
            print(f"OK   {message}")
            processed_sheets += 1
            written_assets += count
        else:
            print(f"WARN {message}")
            skipped_sheets += 1

    if not requested_sheets:
        missing_raw = sorted(set(crop_orders) - {path.name for path in raw_sheets})
        for sheet_name in missing_raw:
            print(f"WARN {sheet_name}: crop order exists, but source sheet is missing")
            skipped_sheets += 1

    mode = "would write" if args.dry_run else "wrote"
    print(
        f"SUMMARY parsed {len(crop_orders)} crop orders, processed {processed_sheets} sheets, "
        f"skipped {skipped_sheets} sheets, {mode} {written_assets} assets."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
