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
OUT_DIR = ROOT / "tmp" / "ui_generated"
SHEET_PREFIX = "source" + "_sheet"

DEFAULT_THRESHOLD = 24.0
DEFAULT_PADDING = 8
MIN_AREA_RATIO = 0.00005
MORPH_SIZES = (9, 15, 21, 31, 41, 51, 61, 81, 101, 121, 151, 181, 221)
DEFAULT_EDGE_SMOOTH_MIN_NEIGHBORS = 3
DEFAULT_EDGE_PEEL_MAX_PASSES = 32
DEFAULT_EDGE_FLATTEN_PASSES = 5
EDGE_REPAIR_MAX_COMPONENT_AREA = 3

NEIGHBOR_DIRECTIONS = (
    (-1, -1),
    (-1, 0),
    (-1, 1),
    (0, -1),
    (0, 1),
    (1, -1),
    (1, 0),
    (1, 1),
)

CROP_ORDER_OVERRIDES = {
    f"{SHEET_PREFIX}_05_operator_card.png": [
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
    source_re = re.compile(r"`(" + SHEET_PREFIX + r"_\d+_[^`]+\.png)`")
    key_re = re.compile(r"\s*\d+\.\s*`([A-Za-z0-9_]+)`(?:\s*[:：].*)?\s*$")

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


def magenta_score_map(rgb: np.ndarray) -> np.ndarray:
    rgb_float = rgb.astype(np.float32)
    red = rgb_float[:, :, 0]
    green = rgb_float[:, :, 1]
    blue = rgb_float[:, :, 2]
    return np.minimum(red, blue) - green


def count_neighbor_support(mask: np.ndarray) -> np.ndarray:
    if cv2 is not None:
        kernel = np.ones((3, 3), dtype=np.uint8)
        support = cv2.filter2D(mask.astype(np.uint8), -1, kernel, borderType=cv2.BORDER_CONSTANT)
        return support.astype(np.int16)

    padded = np.pad(mask.astype(np.int16), 1, mode="constant")
    support = np.zeros(mask.shape, dtype=np.int16)
    for dy in range(3):
        for dx in range(3):
            support += padded[dy : dy + mask.shape[0], dx : dx + mask.shape[1]]
    return support


def transparent_edge(alpha: np.ndarray) -> np.ndarray:
    nonzero = alpha > 0
    if not np.any(nonzero):
        return np.zeros_like(nonzero, dtype=bool)
    return nonzero & (count_neighbor_support(alpha == 0) > 0)


def magenta_contamination_masks(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    rgb_float = rgb.astype(np.float32)
    red = rgb_float[:, :, 0]
    green = rgb_float[:, :, 1]
    blue = rgb_float[:, :, 2]
    magenta_score = np.minimum(red, blue) - green
    purple_score = blue - green
    red_purple_score = red - green

    bright = (
        (red >= 150.0)
        & (blue >= 135.0)
        & (green <= 115.0)
        & (magenta_score >= 45.0)
    )
    strict = bright | (
        (red >= 42.0)
        & (blue >= 38.0)
        & (green <= 92.0)
        & (magenta_score >= 10.0)
    ) | (
        (red >= 24.0)
        & (blue >= 24.0)
        & (green <= 48.0)
        & (magenta_score >= 12.0)
    ) | (
        (red >= 38.0)
        & (blue >= 20.0)
        & (green <= 64.0)
        & ((red - green) >= 18.0)
        & ((blue - green) >= 4.0)
    ) | (
        (red >= 32.0)
        & (blue >= 44.0)
        & (green <= 88.0)
        & (purple_score >= 12.0)
        & (red_purple_score >= -10.0)
    )
    soft = bright | (
        (red >= 32.0)
        & (blue >= 28.0)
        & (green <= 104.0)
        & (magenta_score >= 5.0)
    ) | (
        (red >= 24.0)
        & (blue >= 34.0)
        & (green <= 112.0)
        & (purple_score >= 7.0)
        & (red_purple_score >= -18.0)
    )
    return bright, strict, soft


def components_touching_seed(mask: np.ndarray, seed: np.ndarray) -> np.ndarray:
    if not np.any(mask) or not np.any(seed):
        return np.zeros_like(mask, dtype=bool)

    if cv2 is not None:
        labels_count, labels, _stats, _centroids = cv2.connectedComponentsWithStats(
            mask.astype(np.uint8), connectivity=8
        )
        if labels_count <= 1:
            return np.zeros_like(mask, dtype=bool)
        touched = np.unique(labels[seed & mask])
        touched = touched[touched != 0]
        if len(touched) == 0:
            return np.zeros_like(mask, dtype=bool)
        return np.isin(labels, touched)

    height, width = mask.shape
    kept = np.zeros_like(mask, dtype=bool)
    seen = np.zeros_like(mask, dtype=bool)
    ys, xs = np.nonzero(mask)
    for start_y, start_x in zip(ys.tolist(), xs.tolist()):
        if seen[start_y, start_x]:
            continue
        stack = [(start_x, start_y)]
        component: list[tuple[int, int]] = []
        touches_seed = False
        seen[start_y, start_x] = True
        while stack:
            x, y = stack.pop()
            component.append((x, y))
            touches_seed = touches_seed or bool(seed[y, x])
            for ny in range(y - 1, y + 2):
                for nx in range(x - 1, x + 2):
                    if nx == x and ny == y:
                        continue
                    if 0 <= nx < width and 0 <= ny < height and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((nx, ny))
        if touches_seed:
            for x, y in component:
                kept[y, x] = True
    return kept


def remove_small_components(mask: np.ndarray, max_area: int) -> np.ndarray:
    if max_area <= 0 or not np.any(mask):
        return np.zeros_like(mask, dtype=bool)

    if cv2 is not None:
        labels_count, labels, stats, _centroids = cv2.connectedComponentsWithStats(
            mask.astype(np.uint8), connectivity=8
        )
        cleaned = np.zeros_like(mask, dtype=bool)
        for label in range(1, labels_count):
            if int(stats[label, cv2.CC_STAT_AREA]) <= max_area:
                cleaned[labels == label] = True
        return cleaned

    height, width = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    cleaned = np.zeros_like(mask, dtype=bool)
    ys, xs = np.nonzero(mask)
    for start_y, start_x in zip(ys.tolist(), xs.tolist()):
        if seen[start_y, start_x]:
            continue
        stack = [(start_x, start_y)]
        component: list[tuple[int, int]] = []
        seen[start_y, start_x] = True
        while stack:
            x, y = stack.pop()
            component.append((x, y))
            for ny in range(y - 1, y + 2):
                for nx in range(x - 1, x + 2):
                    if nx == x and ny == y:
                        continue
                    if 0 <= nx < width and 0 <= ny < height and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((nx, ny))
        if len(component) <= max_area:
            for x, y in component:
                cleaned[y, x] = True
    return cleaned


def shift_mask(mask: np.ndarray, dy: int, dx: int) -> np.ndarray:
    shifted = np.zeros_like(mask, dtype=bool)
    height, width = mask.shape
    src_y1 = max(0, -dy)
    src_y2 = min(height, height - dy)
    src_x1 = max(0, -dx)
    src_x2 = min(width, width - dx)
    dst_y1 = max(0, dy)
    dst_y2 = min(height, height + dy)
    dst_x1 = max(0, dx)
    dst_x2 = min(width, width + dx)
    if src_y1 < src_y2 and src_x1 < src_x2:
        shifted[dst_y1:dst_y2, dst_x1:dst_x2] = mask[src_y1:src_y2, src_x1:src_x2]
    return shifted


def shift_values(values: np.ndarray, dy: int, dx: int) -> np.ndarray:
    shifted = np.zeros_like(values)
    height, width = values.shape
    src_y1 = max(0, -dy)
    src_y2 = min(height, height - dy)
    src_x1 = max(0, -dx)
    src_x2 = min(width, width - dx)
    dst_y1 = max(0, dy)
    dst_y2 = min(height, height + dy)
    dst_x1 = max(0, dx)
    dst_x2 = min(width, width + dx)
    if src_y1 < src_y2 and src_x1 < src_x2:
        shifted[dst_y1:dst_y2, dst_x1:dst_x2] = values[src_y1:src_y2, src_x1:src_x2]
    return shifted


def shift_rgb(rgb: np.ndarray, dy: int, dx: int) -> np.ndarray:
    shifted = np.zeros_like(rgb, dtype=rgb.dtype)
    height, width, _channels = rgb.shape
    src_y1 = max(0, -dy)
    src_y2 = min(height, height - dy)
    src_x1 = max(0, -dx)
    src_x2 = min(width, width - dx)
    dst_y1 = max(0, dy)
    dst_y2 = min(height, height + dy)
    dst_x1 = max(0, dx)
    dst_x2 = min(width, width + dx)
    if src_y1 < src_y2 and src_x1 < src_x2:
        shifted[dst_y1:dst_y2, dst_x1:dst_x2] = rgb[src_y1:src_y2, src_x1:src_x2]
    return shifted


def opposite_neighbor_support(mask: np.ndarray) -> np.ndarray:
    support = np.zeros_like(mask, dtype=bool)
    for dy, dx in ((0, 1), (1, 0), (1, 1), (1, -1)):
        support |= shift_mask(mask, dy, dx) & shift_mask(mask, -dy, -dx)
    return support


def neighbor_average(
    rgb: np.ndarray,
    source_mask: np.ndarray,
) -> tuple[np.ndarray, np.ndarray]:
    rgb_float = rgb.astype(np.float32)
    rgb_sum = np.zeros_like(rgb_float)
    count = np.zeros(rgb.shape[:2], dtype=np.float32)
    for dy, dx in NEIGHBOR_DIRECTIONS:
        shifted_source = shift_mask(source_mask, dy, dx)
        shifted_rgb = shift_rgb(rgb_float, dy, dx)
        rgb_sum += shifted_rgb * shifted_source[:, :, None]
        count += shifted_source.astype(np.float32)
    return rgb_sum, count


def paint_from_neighbor_average(
    crop: np.ndarray,
    target: np.ndarray,
    source_mask: np.ndarray,
    min_sources: int,
) -> bool:
    if not np.any(target):
        return False

    rgb_sum, count = neighbor_average(crop[:, :, :3], source_mask)
    paintable = target & (count >= float(min_sources))
    if not np.any(paintable):
        return False

    crop[paintable, :3] = np.clip(
        rgb_sum[paintable] / count[paintable, None],
        0.0,
        255.0,
    ).astype(np.uint8)
    crop[paintable, 3] = 255
    return True


def edge_inner_magenta_score(edge: np.ndarray, visible: np.ndarray, rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    inner_source = visible & ~edge
    score = magenta_score_map(rgb)
    score_sum = np.zeros(edge.shape, dtype=np.float32)
    count = np.zeros(edge.shape, dtype=np.float32)
    for dy, dx in NEIGHBOR_DIRECTIONS:
        shifted_source = shift_mask(inner_source, dy, dx)
        shifted_score = shift_values(score, dy, dx)
        score_sum += shifted_score * shifted_source.astype(np.float32)
        count += shifted_source.astype(np.float32)

    mean = np.zeros(edge.shape, dtype=np.float32)
    np.divide(score_sum, count, out=mean, where=count > 0.0)
    return mean, count


def edge_magenta_removal_masks(crop: np.ndarray, edge: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    alpha = crop[:, :, 3]
    rgb = crop[:, :, :3]
    visible = alpha > 0
    bright, strict, soft = magenta_contamination_masks(rgb)
    score = magenta_score_map(rgb)
    inner_score, inner_count = edge_inner_magenta_score(edge, visible, rgb)

    clearly_more_magenta = score >= (inner_score + 6.0)
    strong_without_reference = (inner_count == 0.0) & (score >= 14.0)
    seed = edge & strict & (bright | clearly_more_magenta | strong_without_reference | (score >= 18.0))
    candidate = edge & soft & (bright | clearly_more_magenta | strong_without_reference | (score >= 12.0))
    return seed, candidate


def repair_tiny_edge_contamination(crop: np.ndarray) -> bool:
    alpha = crop[:, :, 3]
    edge = transparent_edge(alpha)
    if not np.any(edge):
        return False

    visible = alpha > 0
    _bright, strict, soft = magenta_contamination_masks(crop[:, :, :3])
    tiny = remove_small_components(edge & strict, EDGE_REPAIR_MAX_COMPONENT_AREA)
    if not np.any(tiny):
        return False

    support8 = count_neighbor_support(visible) - 1
    embedded = tiny & ((support8 >= 4) | opposite_neighbor_support(visible))
    clean_neighbors = visible & ~soft
    return paint_from_neighbor_average(crop, embedded, clean_neighbors, min_sources=2)


def remove_large_bright_magenta(crop: np.ndarray) -> None:
    alpha = crop[:, :, 3]
    bright, _strict, _soft = magenta_contamination_masks(crop[:, :, :3])
    visible = alpha > 0
    bright_visible = bright & visible
    tiny_embedded = remove_small_components(bright_visible, EDGE_REPAIR_MAX_COMPONENT_AREA) & (
        (count_neighbor_support(visible) - 1 >= 4) | opposite_neighbor_support(visible)
    )
    removable = bright_visible & ~tiny_embedded
    if not np.any(removable):
        return

    alpha[removable] = 0
    crop[removable, :3] = 0


def peel_magenta_edge_layers(crop: np.ndarray, max_passes: int) -> None:
    alpha = crop[:, :, 3]
    for _ in range(max_passes):
        edge = transparent_edge(alpha)
        if not np.any(edge):
            break

        seed, candidate = edge_magenta_removal_masks(crop, edge)
        if not np.any(seed):
            break

        layer = components_touching_seed(candidate, seed)
        if not np.any(layer):
            layer = seed

        alpha[layer] = 0
        crop[layer, :3] = 0


def flatten_transparent_edge(crop: np.ndarray, passes: int, min_neighbors: int) -> None:
    alpha = crop[:, :, 3]
    for _ in range(passes):
        nonzero = alpha > 0
        if not np.any(nonzero):
            break

        edge = transparent_edge(alpha)
        support8 = count_neighbor_support(nonzero) - 1
        removable_spurs = edge & (support8 <= min_neighbors)
        if not np.any(removable_spurs):
            break

        alpha[removable_spurs] = 0
        crop[removable_spurs, :3] = 0


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
    source_mask: np.ndarray,
    box: Component,
    edge_smooth_min_neighbors: int,
) -> Image.Image:
    crop = rgba[box.y1 : box.y2, box.x1 : box.x2].copy()
    mask = source_mask[box.y1 : box.y2, box.x1 : box.x2]
    alpha = remove_tiny_alpha_components((mask.astype(np.uint8) * 255))
    crop[:, :, 3] = alpha
    remove_large_bright_magenta(crop)
    peel_magenta_edge_layers(crop, DEFAULT_EDGE_PEEL_MAX_PASSES)
    flatten_transparent_edge(crop, DEFAULT_EDGE_FLATTEN_PASSES, edge_smooth_min_neighbors)

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
    padding: int,
    edge_smooth_min_neighbors: int,
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

    if not dry_run:
        output_dir.mkdir(parents=True, exist_ok=True)
        for key, component in zip(keys, tight_components):
            crop = make_transparent_crop(
                rgba,
                base_mask,
                component,
                edge_smooth_min_neighbors,
            )
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
    parser.add_argument("--raw-dir", type=Path, default=RAW_DIR, help="Directory containing generated sheet PNGs.")
    parser.add_argument("--output-dir", type=Path, default=OUT_DIR, help="Directory for generated PNG assets.")
    parser.add_argument("--threshold", type=float, default=DEFAULT_THRESHOLD, help="RGB background distance threshold.")
    parser.add_argument("--padding", type=int, default=DEFAULT_PADDING, help="Transparent crop padding in pixels.")
    parser.add_argument(
        "--edge-smooth-min-neighbors",
        type=int,
        default=DEFAULT_EDGE_SMOOTH_MIN_NEIGHBORS,
        help="Remove transparent-edge pixels with fewer neighboring opaque pixels than this.",
    )
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

    raw_sheets = sorted(args.raw_dir.glob(f"{SHEET_PREFIX}_*.png"))
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
            padding=args.padding,
            edge_smooth_min_neighbors=args.edge_smooth_min_neighbors,
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
