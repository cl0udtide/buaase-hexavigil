#!/usr/bin/env python3
"""Validate project audio asset conventions.

Run from the repository root:
    python scripts/dev/check_audio_assets.py
"""

from __future__ import annotations

import configparser
import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
AUDIO_ROOT = REPO_ROOT / "assets" / "audio"
BGM_DIR = AUDIO_ROOT / "bgm"
SFX_DIR = AUDIO_ROOT / "sfx"
AUDIO_MANAGER = REPO_ROOT / "scripts" / "core" / "audio_manager.gd"

SNAKE_CASE = re.compile(r"^[a-z0-9]+(?:_[a-z0-9]+)*\.ogg$")
RAW_AUDIO_SUFFIXES = {".wav", ".mp3", ".flac", ".aiff", ".aif", ".m4a"}
MAX_SFX_BYTES = 256 * 1024
MAX_BGM_BYTES = 8 * 1024 * 1024


def main() -> int:
    failures: list[str] = []
    warnings: list[str] = []

    _check_audio_tree(failures)
    _check_no_raw_audio(failures)
    _check_audio_files(BGM_DIR, True, MAX_BGM_BYTES, failures, warnings)
    _check_audio_files(SFX_DIR, False, MAX_SFX_BYTES, failures, warnings)
    _check_audio_manager_references(failures)

    for warning in warnings:
        print(f"[WARN] {warning}")
    for failure in failures:
        print(f"[FAIL] {failure}")

    if failures:
        print(f"Audio asset check failed: {len(failures)} issue(s).")
        return 1

    print("Audio asset check passed.")
    return 0


def _check_audio_tree(failures: list[str]) -> None:
    for path in [AUDIO_ROOT, BGM_DIR, SFX_DIR]:
        if not path.is_dir():
            failures.append(f"missing directory: {_rel(path)}")


def _check_no_raw_audio(failures: list[str]) -> None:
    if not AUDIO_ROOT.exists():
        return
    for path in AUDIO_ROOT.rglob("*"):
        if path.is_file() and path.suffix.lower() in RAW_AUDIO_SUFFIXES:
            failures.append(f"raw audio source should not be committed: {_rel(path)}")


def _check_audio_files(
    directory: Path,
    should_loop: bool,
    max_bytes: int,
    failures: list[str],
    warnings: list[str],
) -> None:
    if not directory.exists():
        return
    ogg_files = sorted(directory.glob("*.ogg"))
    if not ogg_files:
        failures.append(f"no ogg files in {_rel(directory)}")
        return
    for path in ogg_files:
        if not SNAKE_CASE.match(path.name):
            failures.append(f"audio file must use lower snake_case: {_rel(path)}")
        if path.stat().st_size > max_bytes:
            warnings.append(f"large audio file: {_rel(path)} is {path.stat().st_size} bytes")
        _check_import_file(path, should_loop, failures)


def _check_import_file(path: Path, should_loop: bool, failures: list[str]) -> None:
    import_path = path.with_name(path.name + ".import")
    if not import_path.is_file():
        failures.append(f"missing Godot import file for {_rel(path)}")
        return

    parser = configparser.ConfigParser()
    parser.optionxform = str
    try:
        parser.read(import_path, encoding="utf-8")
    except configparser.Error as exc:
        failures.append(f"invalid import file {_rel(import_path)}: {exc}")
        return

    importer = parser.get("remap", "importer", fallback="").strip('"')
    audio_type = parser.get("remap", "type", fallback="").strip('"')
    source_file = parser.get("deps", "source_file", fallback="").strip('"')
    loop_value = parser.get("params", "loop", fallback="").lower()

    expected_source = "res://" + _rel(path).replace("\\", "/")
    expected_loop = "true" if should_loop else "false"
    if importer != "oggvorbisstr":
        failures.append(f"unexpected importer for {_rel(path)}: {importer}")
    if audio_type != "AudioStreamOggVorbis":
        failures.append(f"unexpected audio type for {_rel(path)}: {audio_type}")
    if source_file != expected_source:
        failures.append(f"import source mismatch for {_rel(path)}: {source_file}")
    if loop_value != expected_loop:
        failures.append(f"loop should be {expected_loop} for {_rel(path)}")


def _check_audio_manager_references(failures: list[str]) -> None:
    if not AUDIO_MANAGER.is_file():
        failures.append(f"missing AudioManager: {_rel(AUDIO_MANAGER)}")
        return
    text = AUDIO_MANAGER.read_text(encoding="utf-8")
    referenced = set(re.findall(r'"(res://assets/audio/(?:bgm|sfx)/[^"]+\.ogg)"', text))
    for ref in sorted(referenced):
        path = REPO_ROOT / ref.removeprefix("res://")
        if not path.is_file():
            failures.append(f"AudioManager references missing audio: {ref}")
        if not path.with_name(path.name + ".import").is_file():
            failures.append(f"AudioManager reference missing import file: {ref}")


def _rel(path: Path) -> str:
    return str(path.relative_to(REPO_ROOT))


if __name__ == "__main__":
    sys.exit(main())
