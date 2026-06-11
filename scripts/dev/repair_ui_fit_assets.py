#!/usr/bin/env python3
"""Repair fit-pipeline artifacts and build composite UI assets.

One-shot but rerunnable fixes for issues the generic fit pipeline cannot
express (see docs in each step):

1. bar fills: the pipeline's uniform min-scale collapsed 1372x86 gradient
   strips into 1x1 pixels; rebuild them as true 1xH vertical strips.
2. frame_button_base fit family: erase the bottom/top center "tongue"
   ornament that nine-patch squashes into a floating grey blob.
3. frame_button_primary_base: composite base plate + primary overlay into a
   solid primary-button texture (overlay art must never be used as a base).
4. width-fit panel variants for relic/blessing panels: uniform scale to the
   target width so nine-patch only stretches vertically and the top/bottom
   band crests keep their aspect (the dialog-box precedent, inverted).
5. small convenience fit variants (status chip 264x82, action button 272x40,
   settings button 36x32) for scene-side rewires.
"""

from __future__ import annotations

import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
GEN = ROOT / "assets" / "ui" / "generated"
STYLES = ROOT / "assets" / "ui" / "styles"


def save(img: Image.Image, name: str) -> None:
    img.save(GEN / name)
    print(f"  wrote {name} {img.size[0]}x{img.size[1]}")


def write_tres(name: str, texture_png: str, margins: tuple[float, float, float, float],
               content: tuple[float, float, float, float] | None = None) -> None:
    lines = [
        '[gd_resource type="StyleBoxTexture" load_steps=2 format=3]',
        "",
        f'[ext_resource type="Texture2D" path="res://assets/ui/generated/{texture_png}" id="1_texture"]',
        "",
        "[resource]",
        'texture = ExtResource("1_texture")',
        f"texture_margin_left = {margins[0]:.2f}",
        f"texture_margin_top = {margins[1]:.2f}",
        f"texture_margin_right = {margins[2]:.2f}",
        f"texture_margin_bottom = {margins[3]:.2f}",
    ]
    if content is not None:
        lines += [
            f"content_margin_left = {content[0]:.1f}",
            f"content_margin_top = {content[1]:.1f}",
            f"content_margin_right = {content[2]:.1f}",
            f"content_margin_bottom = {content[3]:.1f}",
        ]
    lines.append("draw_center = true")
    (STYLES / name).write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"  wrote styles/{name}")


def vertical_strip(source: str, height: int, gain: float = 1.0) -> Image.Image:
    """Resample a wide gradient bar into a true 1xH vertical strip."""
    with Image.open(GEN / source).convert("RGBA") as img:
        strip = img.resize((1, height), Image.Resampling.LANCZOS)
    px = strip.load()
    for y in range(height):
        r, g, b, _a = px[0, y]
        px[0, y] = (min(255, round(r * gain)), min(255, round(g * gain)),
                    min(255, round(b * gain)), 255)
    return strip


def fix_bar_fills() -> None:
    print("[1] bar fills: 1x1 -> true vertical gradient strips")
    for key, height, gain in (("core", 21, 1.0), ("hp", 30, 1.6), ("sp", 30, 1.4)):
        strip = vertical_strip(f"bar_progress_fill_{key}.png", height, gain)
        save(strip, f"bar_progress_fill_{key}_fit_1x{height}.png")
        save(strip, f"bar_progress_fill_{key}_fit_refs.png")


def erase_center_tongue(img: Image.Image) -> Image.Image:
    """Clear narrow center-only ornaments protruding past the plate body."""
    width, height = img.size
    px = img.load()

    def row_span(y: int) -> tuple[int, int] | None:
        xs = [x for x in range(width) if px[x, y][3] > 8]
        if not xs:
            return None
        return (xs[0], xs[-1])

    def sweep(rows) -> None:
        for y in rows:
            span = row_span(y)
            if span is None:
                continue
            span_w = span[1] - span[0] + 1
            # plate body reached: the row is wide
            if span_w > 0.5 * width:
                break
            # narrow central cluster -> tongue remnant, clear it
            if span[0] > 0.2 * width and span[1] < 0.8 * width:
                for x in range(span[0], span[1] + 1):
                    px[x, y] = (0, 0, 0, 0)
            else:
                break

    sweep(range(height))
    sweep(range(height - 1, -1, -1))
    return img


def fix_button_base_family() -> None:
    print("[2] frame_button_base fit family: erase squashed tongue ornament")
    for name in ("frame_button_base_fit_refs.png", "frame_button_base_fit_272x36.png",
                 "frame_button_base_fit_30x28.png", "frame_button_base_fit_344x44.png"):
        path = GEN / name
        with Image.open(path).convert("RGBA") as img:
            cleaned = erase_center_tongue(img.copy())
        save(cleaned, name)


def build_primary_button() -> None:
    print("[3] frame_button_primary_base: base plate + primary overlay composite")
    target = (380, 56)
    with Image.open(GEN / "frame_button_base.png").convert("RGBA") as base_src:
        base = base_src.crop(base_src.getbbox())
        base = erase_center_tongue(base)
        base = base.resize(target, Image.Resampling.LANCZOS)
    with Image.open(GEN / "frame_button_primary_overlay.png").convert("RGBA") as over_src:
        over = over_src.crop(over_src.getbbox())
        over = over.resize(target, Image.Resampling.LANCZOS)
    combined = Image.alpha_composite(base, over)
    save(combined, "frame_button_primary_base.png")
    write_tres("frame_button_primary_base.tres", "frame_button_primary_base.png",
               (12.0, 10.0, 12.0, 10.0), (10.0, 6.0, 10.0, 6.0))


def width_fit_panel(source: str, ref_w: int, ref_h: int, base_margin: float,
                    content: tuple[float, float, float, float] | None = None) -> None:
    """Scale uniformly to the target width; nine-patch then only stretches
    vertically, keeping top/bottom band crests pixel-true."""
    with Image.open(GEN / f"{source}.png").convert("RGBA") as img:
        scale = ref_w / img.size[0]
        out = img.resize((ref_w, max(1, round(img.size[1] * scale))), Image.Resampling.LANCZOS)
    name = f"{source}_fit_{ref_w}x{ref_h}"
    save(out, f"{name}.png")
    margin = max(1.0, round(base_margin * scale, 2))
    write_tres(f"{name}.tres", f"{name}.png", (margin, margin, margin, margin), content)


def fix_panels() -> None:
    print("[4] relic/blessing panel width-fit variants (crest-preserving)")
    width_fit_panel("frame_relic_panel_base", 900, 640, 18.0)
    width_fit_panel("frame_blessing_panel_base", 600, 380, 18.0)


def small_fit(source: str, ref_w: int, ref_h: int, base_margins: tuple[float, float, float, float]) -> None:
    with Image.open(GEN / f"{source}.png").convert("RGBA") as img:
        scale = min(1.0, ref_w / img.size[0], ref_h / img.size[1])
        out = img.resize((max(1, round(img.size[0] * scale)), max(1, round(img.size[1] * scale))),
                         Image.Resampling.LANCZOS)
    name = f"{source}_fit_{ref_w}x{ref_h}"
    save(out, f"{name}.png")
    margins = tuple(max(1.0, round(m * scale, 2)) for m in base_margins)
    write_tres(f"{name}.tres", f"{name}.png", margins)  # type: ignore[arg-type]


def build_small_variants() -> None:
    print("[5] convenience fit variants for scene-side rewires")
    chip_src = GEN / "frame_top_status_chip_base_fit_220x82.png"
    with Image.open(chip_src).convert("RGBA") as img:
        save(img.copy(), "frame_top_status_chip_base_fit_264x82.png")
    base_tres = (STYLES / "frame_top_status_chip_base_fit_220x82.tres").read_text(encoding="utf-8")
    margins = [float(re.search(rf"texture_margin_{side}\s*=\s*([0-9.]+)", base_tres).group(1))
               for side in ("left", "top", "right", "bottom")]
    write_tres("frame_top_status_chip_base_fit_264x82.tres",
               "frame_top_status_chip_base_fit_264x82.png", tuple(margins))  # type: ignore[arg-type]
    small_fit("frame_action_button_base", 272, 40, (24.0, 24.0, 24.0, 24.0))
    small_fit("frame_settings_button_base", 36, 32, (18.0, 18.0, 18.0, 18.0))


def main() -> int:
    for step in (fix_bar_fills, fix_button_base_family, build_primary_button,
                 fix_panels, build_small_variants):
        step()
    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
