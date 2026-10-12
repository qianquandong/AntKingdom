#!/usr/bin/env python3
"""把 Codex 已交付（reviewed 及以上）的运行时 PNG 导入 iOS 资源目录 Assets.xcassets（A01-01 起）。

- 来源只取 design/asset_manifest.json 中状态为 reviewed / approved / integrated / verified_on_device、
  且列出了 `outputs` 的资源；原稿（assets/source/**）、接触表、提示词不进 App。
- 每张 PNG 作为同名 imageset 的 @3x 单份资源（144 px → 48 pt；288 px → 96 pt），不改像素。
- 资源组必须整组交付才导入（与客户端“缺一个就整组保留占位”的约定一致）。

用法：
  python3 tools/import_art.py          # 生成/更新 ios/AntKingdom/Resources/Assets.xcassets
  python3 tools/import_art.py --check  # 只检查：imageset 与交付文件逐字节一致、没有多余或缺失
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "design" / "asset_manifest.json"
RUNTIME_NAMES = ROOT / "design" / "asset_runtime_names.json"
CATALOG = ROOT / "ios" / "AntKingdom" / "Resources" / "Assets.xcassets"
DELIVERED = {"reviewed", "approved", "integrated", "verified_on_device"}
ROOT_CONTENTS = {"info": {"author": "xcode", "version": 1}}


def imageset_contents(name: str) -> dict:
    return {
        "images": [{"filename": f"{name}@3x.png", "idiom": "universal", "scale": "3x"}],
        "info": {"author": "xcode", "version": 1},
    }


def png_size(path: Path) -> tuple[int, int]:
    data = path.read_bytes()[:24]
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"not a PNG: {path}")
    return int.from_bytes(data[16:20], "big"), int.from_bytes(data[20:24], "big")


def planned() -> dict[str, Path]:
    """运行时名称 → 交付文件。"""
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    runtime = json.loads(RUNTIME_NAMES.read_text(encoding="utf-8"))
    names_by_id = runtime.get("names", runtime)
    result: dict[str, Path] = {}
    for asset in manifest["assets"]:
        if asset.get("status") not in DELIVERED or not asset.get("outputs"):
            continue
        files = {Path(p).stem: ROOT / p for p in asset["outputs"]}
        expected = names_by_id.get(asset["id"])
        if expected is None:
            raise SystemExit(f"{asset['id']}: no runtime names in {RUNTIME_NAMES.name}")
        missing = sorted(set(expected) - set(files))
        extra = sorted(set(files) - set(expected))
        if missing or extra:
            raise SystemExit(f"{asset['id']}: group incomplete (missing {missing}, unexpected {extra})")
        for name, path in files.items():
            if not path.is_file():
                raise SystemExit(f"{asset['id']}: {path.relative_to(ROOT)} not found")
            width, height = png_size(path)
            if width % 3 or height % 3:
                raise SystemExit(f"{name}: {width}x{height} px is not an @3x size")
            result[name] = path
    return result


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check(plan: dict[str, Path]) -> list[str]:
    problems: list[str] = []
    if not plan:
        return problems if not CATALOG.exists() else [f"{CATALOG} exists but nothing is delivered"]
    if json.loads((CATALOG / "Contents.json").read_text(encoding="utf-8")) != ROOT_CONTENTS:
        problems.append("Assets.xcassets/Contents.json differs")
    present = {p.name[: -len(".imageset")] for p in CATALOG.glob("*.imageset")}
    for name in sorted(present - set(plan)):
        problems.append(f"{name}: imageset has no delivered source (remove it; no empty or placeholder imagesets)")
    for name, source in sorted(plan.items()):
        folder = CATALOG / f"{name}.imageset"
        image = folder / f"{name}@3x.png"
        if not image.is_file():
            problems.append(f"{name}: missing imageset")
            continue
        if sha(image) != sha(source):
            problems.append(f"{name}: imageset PNG differs from {source.relative_to(ROOT)}")
        contents = json.loads((folder / "Contents.json").read_text(encoding="utf-8"))
        if contents != imageset_contents(name):
            problems.append(f"{name}: Contents.json differs")
        extra = sorted(p.name for p in folder.iterdir() if p.name not in {"Contents.json", image.name})
        if extra:
            problems.append(f"{name}: unexpected files {extra}")
    return problems


def write(plan: dict[str, Path]) -> None:
    CATALOG.mkdir(parents=True, exist_ok=True)
    (CATALOG / "Contents.json").write_text(json.dumps(ROOT_CONTENTS, indent=2) + "\n", encoding="utf-8", newline="\n")
    for folder in CATALOG.glob("*.imageset"):
        if folder.name[: -len(".imageset")] not in plan:
            shutil.rmtree(folder)
    for name, source in sorted(plan.items()):
        folder = CATALOG / f"{name}.imageset"
        folder.mkdir(exist_ok=True)
        for old in folder.iterdir():
            old.unlink()
        shutil.copyfile(source, folder / f"{name}@3x.png")
        (folder / "Contents.json").write_text(json.dumps(imageset_contents(name), indent=2) + "\n", encoding="utf-8", newline="\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    plan = planned()
    if args.check:
        problems = check(plan)
        for line in problems:
            print("FAIL:", line)
        if problems:
            return 1
        print(f"OK: {len(plan)} delivered runtime PNGs match Assets.xcassets (@3x, byte-identical)")
        return 0
    write(plan)
    total = sum(p.stat().st_size for p in plan.values())
    print(f"wrote {len(plan)} imagesets to {CATALOG.relative_to(ROOT)} ({total} bytes of PNG)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
