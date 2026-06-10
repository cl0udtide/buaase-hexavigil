#!/usr/bin/env python3
"""Fit oversized UI StyleBox textures to their reference sizes.

The generated UI frame art is often larger than the Controls that draw it.
This script scans scene references, creates scaled texture/style copies, and
rewrites scene ext_resources so each known use draws from a texture that will be
stretched by Godot instead of compressed.
"""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
STYLE_ROOT = ROOT / "assets" / "ui" / "styles"
SCENE_ROOT = ROOT / "scenes"
GENERATED_ROOT = ROOT / "assets" / "ui" / "generated"
REPORT_PATH = ROOT / "tmp" / "ui_style_asset_fit_report.txt"
DESIGN_VIEWPORT_SIZE = (1920.0, 1080.0)
RES_PREFIX = "res://"
FIT_ID_PREFIX = "fit"

UNIT_DETAIL_PROGRESS_TRACK_SIZE = (210, 30)
COMBAT_CORE_FILL_MIN_SIZE = (1, 21)
UNIT_DETAIL_FILL_MIN_SIZE = (1, 30)


@dataclass(frozen=True)
class StyleUse:
    style_path: str
    scene_path: Path
    node_path: str
    slot: str
    size: tuple[float, float]


@dataclass(frozen=True)
class StyleTexture:
    style_path: str
    file_path: Path
    texture_path: str
    margins: tuple[float, float, float, float]


@dataclass(frozen=True)
class FitVariant:
    style: StyleTexture
    original_size: tuple[int, int]
    target_size: tuple[int, int]
    reference_size: tuple[int, int]
    scale: float
    suffix: str


def res_to_path(path: str) -> Path:
    if not path.startswith(RES_PREFIX):
        raise ValueError(f"not a res:// path: {path}")
    return ROOT / Path(path.removeprefix(RES_PREFIX))


def path_to_res(path: Path) -> str:
    return f"{RES_PREFIX}{path.relative_to(ROOT).as_posix()}"


def attr(line: str, name: str) -> str:
    match = re.search(rf'{re.escape(name)}="([^"]*)"', line)
    return match.group(1) if match else ""


def ext_resource_id(value: str) -> str:
    match = re.search(r'ExtResource\("([^"]+)"\)', value)
    return match.group(1) if match else ""


def vector2(value: str) -> tuple[float, float]:
    match = re.search(r"Vector2\(([^,]+),\s*([^)]+)\)", value)
    if match is None:
        return (0.0, 0.0)
    return (float(match.group(1)), float(match.group(2)))


def numeric(value: object, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def style_name(style_path: str) -> str:
    return Path(style_path).stem


def style_textures() -> dict[str, StyleTexture]:
    styles: dict[str, StyleTexture] = {}
    for file_path in sorted(STYLE_ROOT.glob("*.tres")):
        if "_fit_" in file_path.stem:
            continue
        text = file_path.read_text(encoding="utf-8")
        texture_match = re.search(
            r'path="(res://assets/ui/generated/[^"]+\.png)"',
            text,
        )
        if texture_match is None:
            continue
        margins: list[float] = []
        for name in ("left", "top", "right", "bottom"):
            margin_match = re.search(rf"texture_margin_{name}\s*=\s*([0-9.]+)", text)
            margins.append(float(margin_match.group(1)) if margin_match else 0.0)
        style_path = path_to_res(file_path)
        styles[style_path] = StyleTexture(
            style_path=style_path,
            file_path=file_path,
            texture_path=texture_match.group(1),
            margins=tuple(margins),  # type: ignore[arg-type]
        )
    return styles


def scan_scene(scene_path: Path) -> list[StyleUse]:
    text = scene_path.read_text(encoding="utf-8")
    ext_resources: dict[str, str] = {}
    nodes: dict[str, dict[str, object]] = {}
    children_by_parent: dict[str, list[str]] = {}
    current: dict[str, object] | None = None

    def store_current() -> None:
        nonlocal current
        if current is None:
            return
        name = str(current["name"])
        parent = str(current["parent"])
        if parent == "":
            full_path = "."
        elif parent == ".":
            full_path = name
        else:
            full_path = f"{parent}/{name}"
        current["path"] = full_path
        nodes[full_path] = current
        if parent:
            parent_key = "." if parent == "." else parent
            children_by_parent.setdefault(parent_key, []).append(full_path)

    for raw_line in text.splitlines():
        line = raw_line.strip()
        if line.startswith("[ext_resource"):
            resource_path = attr(line, "path")
            resource_id = attr(line, "id")
            if resource_path.startswith("res://assets/ui/styles") and resource_path.endswith(".tres"):
                ext_resources[resource_id] = resource_path
        elif line.startswith("[node"):
            store_current()
            current = {
                "name": attr(line, "name"),
                "type": attr(line, "type"),
                "parent": attr(line, "parent"),
                "props": {},
                "refs": [],
            }
        elif line.startswith("["):
            store_current()
            current = None
        elif current is not None and "=" in line:
            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip()
            props = current["props"]
            assert isinstance(props, dict)
            props[key] = value
            if key.startswith("theme_override_styles/"):
                resource_id = ext_resource_id(value)
                if resource_id in ext_resources:
                    refs = current["refs"]
                    assert isinstance(refs, list)
                    refs.append((key.removeprefix("theme_override_styles/"), ext_resources[resource_id]))
    store_current()

    cache: dict[str, tuple[float, float]] = {}

    def estimate_size(node_path: str) -> tuple[float, float]:
        if node_path in cache:
            return cache[node_path]
        if node_path not in nodes:
            return (0.0, 0.0)

        node = nodes[node_path]
        props = node["props"]
        assert isinstance(props, dict)
        raw_parent = str(node["parent"])
        parent_path = "." if raw_parent == "." else raw_parent
        parent_size = DESIGN_VIEWPORT_SIZE
        if parent_path and parent_path in nodes:
            parent_size = estimate_size(parent_path)

        custom_min = vector2(str(props.get("custom_minimum_size", "")))
        anchor_left = numeric(props.get("anchor_left", 0.0))
        anchor_top = numeric(props.get("anchor_top", 0.0))
        anchor_right = numeric(props.get("anchor_right", 0.0))
        anchor_bottom = numeric(props.get("anchor_bottom", 0.0))
        offset_left = numeric(props.get("offset_left", 0.0))
        offset_top = numeric(props.get("offset_top", 0.0))
        offset_right = numeric(props.get("offset_right", 0.0))
        offset_bottom = numeric(props.get("offset_bottom", 0.0))

        width = (anchor_right - anchor_left) * parent_size[0] + offset_right - offset_left
        height = (anchor_bottom - anchor_top) * parent_size[1] + offset_bottom - offset_top

        if parent_path and parent_path in nodes:
            parent_node = nodes[parent_path]
            parent_type = str(parent_node["type"])
            parent_props = parent_node["props"]
            assert isinstance(parent_props, dict)
            if parent_type == "MarginContainer":
                inner_width = parent_size[0] - numeric(parent_props.get("theme_override_constants/margin_left", 0.0)) - numeric(parent_props.get("theme_override_constants/margin_right", 0.0))
                inner_height = parent_size[1] - numeric(parent_props.get("theme_override_constants/margin_top", 0.0)) - numeric(parent_props.get("theme_override_constants/margin_bottom", 0.0))
                width = inner_width if width <= 0.0 else width
                height = inner_height if height <= 0.0 else height
            elif parent_type == "HBoxContainer":
                width = custom_min[0] if width <= 0.0 else width
                height = parent_size[1] if height <= 0.0 else height
            elif parent_type == "VBoxContainer":
                width = parent_size[0] if width <= 0.0 else width
                height = custom_min[1] if height <= 0.0 else height
            elif parent_type == "CenterContainer":
                width = custom_min[0] if width <= 0.0 else width
                height = custom_min[1] if height <= 0.0 else height

        width = max(width, custom_min[0])
        height = max(height, custom_min[1])
        if node_path == "." and width <= 0.0 and height <= 0.0:
            width, height = DESIGN_VIEWPORT_SIZE
        cache[node_path] = (max(0.0, width), max(0.0, height))
        return cache[node_path]

    uses: list[StyleUse] = []
    for node_path, node in nodes.items():
        refs = node["refs"]
        assert isinstance(refs, list)
        for slot, style_path in refs:
            uses.append(
                StyleUse(
                    style_path=str(style_path),
                    scene_path=scene_path,
                    node_path=node_path,
                    slot=str(slot),
                    size=estimate_size(node_path),
                )
            )
    return uses


def scene_style_uses() -> dict[str, list[StyleUse]]:
    uses_by_style: dict[str, list[StyleUse]] = {}
    for scene_path in sorted(SCENE_ROOT.rglob("*.tscn")):
        for use in scan_scene(scene_path):
            uses_by_style.setdefault(use.style_path, []).append(use)
    for use in special_style_uses():
        uses_by_style.setdefault(use.style_path, []).append(use)
    return uses_by_style


def special_style_uses() -> list[StyleUse]:
    return [
        StyleUse(
            style_path="res://assets/ui/styles/bar_progress_fill_core.tres",
            scene_path=SCENE_ROOT / "ui" / "combat" / "CombatHud.tscn",
            node_path="HudChromeLayer/TopHudSlot/TopBar/TopContent/TopContentRow/LeftStatusGroup/CoreChip/CoreFill",
            slot="panel",
            size=COMBAT_CORE_FILL_MIN_SIZE,
        ),
        StyleUse(
            style_path="res://assets/ui/styles/bar_progress_track.tres",
            scene_path=SCENE_ROOT / "ui" / "combat" / "UnitDetailPanel.tscn",
            node_path="ContentMargin/MainVBox/VitalsSection/VitalsMargin/VitalsRow/VitalsColumn/HpBar/HpTrack",
            slot="panel",
            size=UNIT_DETAIL_PROGRESS_TRACK_SIZE,
        ),
        StyleUse(
            style_path="res://assets/ui/styles/bar_progress_fill_hp.tres",
            scene_path=SCENE_ROOT / "ui" / "combat" / "UnitDetailPanel.tscn",
            node_path="ContentMargin/MainVBox/VitalsSection/VitalsMargin/VitalsRow/VitalsColumn/HpBar/HpFill",
            slot="panel",
            size=UNIT_DETAIL_FILL_MIN_SIZE,
        ),
        StyleUse(
            style_path="res://assets/ui/styles/bar_progress_track.tres",
            scene_path=SCENE_ROOT / "ui" / "combat" / "UnitDetailPanel.tscn",
            node_path="ContentMargin/MainVBox/VitalsSection/VitalsMargin/VitalsRow/VitalsColumn/SpBar/SpTrack",
            slot="panel",
            size=UNIT_DETAIL_PROGRESS_TRACK_SIZE,
        ),
        StyleUse(
            style_path="res://assets/ui/styles/bar_progress_fill_sp.tres",
            scene_path=SCENE_ROOT / "ui" / "combat" / "UnitDetailPanel.tscn",
            node_path="ContentMargin/MainVBox/VitalsSection/VitalsMargin/VitalsRow/VitalsColumn/SpBar/SpFill",
            slot="panel",
            size=UNIT_DETAIL_FILL_MIN_SIZE,
        ),
    ]


def original_size(style: StyleTexture) -> tuple[int, int] | None:
    texture_file = res_to_path(style.texture_path)
    if not texture_file.exists():
        return None
    with Image.open(texture_file) as image:
        return image.size


def variant_for_reference(style: StyleTexture, original: tuple[int, int], reference_size: tuple[int, int], suffix: str) -> FitVariant | None:
    width, height = reference_size
    if width <= 0 or height <= 0:
        return None
    scale = min(1.0, width / original[0], height / original[1])
    if scale >= 0.999:
        return None
    return FitVariant(
        style=style,
        original_size=original,
        target_size=(max(1, round(original[0] * scale)), max(1, round(original[1] * scale))),
        reference_size=reference_size,
        scale=scale,
        suffix=suffix,
    )


def build_variants(styles: dict[str, StyleTexture], uses_by_style: dict[str, list[StyleUse]]) -> tuple[dict[str, FitVariant], dict[tuple[str, int, int], FitVariant]]:
    default_variants: dict[str, FitVariant] = {}
    exact_variants: dict[tuple[str, int, int], FitVariant] = {}
    for style in styles.values():
        original = original_size(style)
        if original is None:
            continue
        uses = [use for use in uses_by_style.get(style.style_path, []) if use.size[0] > 0.0 and use.size[1] > 0.0]
        if not uses:
            continue
        min_ref = (round(min(use.size[0] for use in uses)), round(min(use.size[1] for use in uses)))
        default_variant = variant_for_reference(style, original, min_ref, "fit_refs")
        if default_variant is not None:
            default_variants[style.style_path] = default_variant
        for use in uses:
            ref = (round(use.size[0]), round(use.size[1]))
            variant = variant_for_reference(style, original, ref, f"fit_{ref[0]}x{ref[1]}")
            if variant is not None:
                exact_variants[(style.style_path, ref[0], ref[1])] = variant
    return default_variants, exact_variants


def variant_texture_path(variant: FitVariant) -> Path:
    return GENERATED_ROOT / f"{style_name(variant.style.style_path)}_{variant.suffix}.png"


def variant_style_path(variant: FitVariant) -> Path:
    return STYLE_ROOT / f"{style_name(variant.style.style_path)}_{variant.suffix}.tres"


def scaled_margin(value: float, scale: float, target_limit: int) -> float:
    if value <= 0.0:
        return 0.0
    if target_limit < 3:
        return 0.0
    limit = max(0.0, target_limit / 2.0 - 1.0)
    if limit < 1.0:
        return 0.0
    return max(1.0, min(round(value * scale, 2), limit))


def style_text_for_variant(variant: FitVariant, base_text: str, texture_path: Path) -> str:
    text = re.sub(r'\suid="uid://[^"]+"', "", base_text, count=1)
    text = re.sub(r'\suid="uid://[^"]+"(?=\s+path=)', "", text, count=1)
    text = re.sub(
        r'path="res://assets/ui/generated/[^"]+\.png"',
        f'path="{path_to_res(texture_path)}"',
        text,
        count=1,
    )
    margin_values = {
        "left": scaled_margin(variant.style.margins[0], variant.scale, variant.target_size[0]),
        "top": scaled_margin(variant.style.margins[1], variant.scale, variant.target_size[1]),
        "right": scaled_margin(variant.style.margins[2], variant.scale, variant.target_size[0]),
        "bottom": scaled_margin(variant.style.margins[3], variant.scale, variant.target_size[1]),
    }
    for name, value in margin_values.items():
        text = re.sub(
            rf"(texture_margin_{name}\s*=\s*)[0-9.]+",
            rf"\g<1>{value:.2f}",
            text,
            count=1,
        )
    return text


def write_variant(variant: FitVariant) -> None:
    source = res_to_path(variant.style.texture_path)
    texture_target = variant_texture_path(variant)
    with Image.open(source).convert("RGBA") as image:
        resized = image.resize(variant.target_size, Image.Resampling.LANCZOS)
        texture_target.parent.mkdir(parents=True, exist_ok=True)
        resized.save(texture_target)

    base_text = variant.style.file_path.read_text(encoding="utf-8")
    style_target = variant_style_path(variant)
    style_target.write_text(style_text_for_variant(variant, base_text, texture_target), encoding="utf-8")


def rewrite_base_style(default_variant: FitVariant) -> None:
    base_text = default_variant.style.file_path.read_text(encoding="utf-8")
    default_variant.style.file_path.write_text(
        style_text_for_variant(default_variant, base_text, variant_texture_path(default_variant)),
        encoding="utf-8",
    )


def next_resource_id(existing_ids: set[str], style_path: str, width: int, height: int) -> str:
    base = f"{FIT_ID_PREFIX}_{style_name(style_path)}_{width}x{height}"
    candidate = base
    index = 2
    while candidate in existing_ids:
        candidate = f"{base}_{index}"
        index += 1
    existing_ids.add(candidate)
    return candidate


def rewrite_scenes(exact_variants: dict[tuple[str, int, int], FitVariant]) -> int:
    changed = 0
    special_uses_by_scene: dict[Path, list[StyleUse]] = {}
    for use in special_style_uses():
        special_uses_by_scene.setdefault(use.scene_path, []).append(use)
    for scene_path in sorted(SCENE_ROOT.rglob("*.tscn")):
        uses = scan_scene(scene_path) + special_uses_by_scene.get(scene_path, [])
        replacement_for_line: dict[tuple[str, str], FitVariant] = {}
        for use in uses:
            ref = (round(use.size[0]), round(use.size[1]))
            variant = exact_variants.get((use.style_path, ref[0], ref[1]))
            if variant is not None:
                replacement_for_line[(use.node_path, use.slot)] = variant
        if not replacement_for_line:
            continue

        lines = scene_path.read_text(encoding="utf-8").splitlines()
        existing_ids: set[str] = set()
        existing_id_by_path: dict[str, str] = {}
        for line in lines:
            stripped = line.strip()
            if not stripped.startswith("[ext_resource"):
                continue
            resource_id = attr(stripped, "id")
            resource_path = attr(stripped, "path")
            existing_ids.add(resource_id)
            if resource_path:
                existing_id_by_path[resource_path] = resource_id
        ext_lines: list[str] = []
        id_by_variant: dict[Path, str] = {}
        for variant in sorted(set(replacement_for_line.values()), key=lambda item: path_to_res(variant_style_path(item))):
            variant_path = variant_style_path(variant)
            variant_res_path = path_to_res(variant_path)
            resource_id = existing_id_by_path.get(variant_res_path, "")
            if not resource_id:
                resource_id = next_resource_id(existing_ids, variant.style.style_path, variant.reference_size[0], variant.reference_size[1])
                ext_lines.append(f'[ext_resource type="StyleBoxTexture" path="{variant_res_path}" id="{resource_id}"]')
            id_by_variant[variant_path] = resource_id

        insert_at = 0
        for index, line in enumerate(lines):
            if line.strip().startswith("[ext_resource"):
                insert_at = index + 1
        if ext_lines:
            lines[insert_at:insert_at] = ext_lines

        current_node = ""
        new_lines: list[str] = []
        for line in lines:
            stripped = line.strip()
            if stripped.startswith("[node"):
                name = attr(stripped, "name")
                parent = attr(stripped, "parent")
                if parent == "":
                    current_node = "."
                elif parent == ".":
                    current_node = name
                else:
                    current_node = f"{parent}/{name}"
            if stripped.startswith("theme_override_styles/") and "=" in stripped:
                key = stripped.split("=", 1)[0].strip()
                slot = key.removeprefix("theme_override_styles/")
                variant = replacement_for_line.get((current_node, slot))
                if variant is not None:
                    resource_id = id_by_variant[variant_style_path(variant)]
                    line = re.sub(r'ExtResource\("[^"]+"\)', f'ExtResource("{resource_id}")', line, count=1)
            new_lines.append(line)

        scene_path.write_text("\n".join(new_lines) + "\n", encoding="utf-8")
        changed += 1
    return changed


def write_report(default_variants: dict[str, FitVariant], exact_variants: dict[tuple[str, int, int], FitVariant], uses_by_style: dict[str, list[StyleUse]]) -> None:
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        f"default styles fitted: {len(default_variants)}",
        f"scene-specific style variants: {len(exact_variants)}",
    ]
    for style_path, variant in sorted(default_variants.items()):
        uses = uses_by_style.get(style_path, [])
        lines.append("")
        lines.append(
            f"{style_path} {variant.original_size[0]}x{variant.original_size[1]} "
            f"-> default {variant.target_size[0]}x{variant.target_size[1]} "
            f"scale={variant.scale:.4f} min_ref={variant.reference_size[0]}x{variant.reference_size[1]}"
        )
        for use in sorted(uses, key=lambda item: (item.scene_path.as_posix(), item.node_path, item.slot)):
            ref = (round(use.size[0]), round(use.size[1]))
            exact = exact_variants.get((style_path, ref[0], ref[1]))
            exact_text = ""
            if exact is not None:
                exact_text = f" exact={exact.target_size[0]}x{exact.target_size[1]}"
            lines.append(
                f"  {use.scene_path.relative_to(ROOT).as_posix()} "
                f"{use.node_path} {use.slot} {use.size[0]:.0f}x{use.size[1]:.0f}{exact_text}"
            )
    REPORT_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="Only write the report.")
    return parser


def main() -> int:
    args = build_arg_parser().parse_args()
    styles = style_textures()
    uses_by_style = scene_style_uses()
    default_variants, exact_variants = build_variants(styles, uses_by_style)
    write_report(default_variants, exact_variants, uses_by_style)
    changed_scenes = 0
    if not args.dry_run:
        for variant in {*(default_variants.values()), *(exact_variants.values())}:
            write_variant(variant)
        for variant in default_variants.values():
            rewrite_base_style(variant)
        changed_scenes = rewrite_scenes(exact_variants)
    print(f"default styles fitted: {len(default_variants)}")
    print(f"scene-specific style variants: {len(exact_variants)}")
    print(f"changed scenes: {changed_scenes}")
    print(f"report: {REPORT_PATH.relative_to(ROOT).as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
