"""资源就绪检查：design/asset_manifest.json 中的资源是否已作为正式资源进入 iOS 资源目录。

    python tools/check_assets.py            # 打印报告（日常 CI：信息性，退出码 0）
    python tools/check_assets.py --strict   # 发行检查：任一核心资源缺失、不完整或未批准即失败
    python tools/check_assets.py --phase release --strict   # M4 以后连正式版资源一起检查

客户端在资源缺失时绘制带资源 ID 的占位（只在 Debug 标注 ID）；占位不能通过美术终验或进入
App Store 包（ART_DIRECTION、TECHNICAL_HANDOFF 第 6 章）。每个资源 ID 在客户端对应的运行时名称
（imageset 名 / 音频文件名）见 design/asset_runtime_names.json，与 AssetNames.swift 一致。
"""
import argparse
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "design/asset_manifest.json"
NAMES = ROOT / "design/asset_runtime_names.json"
CATALOG = ROOT / "ios/AntKingdom/Resources/Assets.xcassets"
AUDIO = ROOT / "ios/AntKingdom/Resources/Audio"
# 不需要进入客户端资源目录的正式版条目（设计稿、地图数据、商店素材）
RELEASE_NOT_RUNTIME = {"chapter_maps", "store_screenshots", "ui_release"}
READY = {"approved", "integrated", "verified_on_device"}


def load_names():
    doc = json.loads(NAMES.read_text(encoding="utf-8"))
    return doc["names"], set(doc["not_runtime"]) | RELEASE_NOT_RUNTIME, doc["audio_extensions"]


def name_present(name, audio_exts):
    if (CATALOG / f"{name}.imageset").exists() or (CATALOG / f"{name}.appiconset").exists():
        return True
    return AUDIO.exists() and any((AUDIO / f"{name}.{ext}").exists() for ext in audio_exts)


def report(phase):
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    names, not_runtime, audio_exts = load_names()
    rows, problems = [], []
    for asset in manifest["assets"]:
        if phase == "core" and asset["phase"] != "core":
            continue
        asset_id = asset["id"]
        runtime = asset_id not in not_runtime
        expected = names.get(asset_id, [])
        if runtime and asset["phase"] == "core" and not expected:
            problems.append(f"{asset_id}: 缺少运行时名称约定（design/asset_runtime_names.json）")
        found = [n for n in expected if name_present(n, audio_exts)]
        rows.append({
            "id": asset_id, "batch": asset["batch"], "status": asset["status"], "runtime": runtime,
            "expected": len(expected), "found": len(found),
            "missing": [n for n in expected if n not in found],
            "ready": asset["status"] in READY and (not runtime or (expected and len(found) == len(expected))),
            "spec": asset["spec"],
        })
    for asset_id in names:
        if asset_id not in {a["id"] for a in manifest["assets"]}:
            problems.append(f"{asset_id}: 运行时名称表中有、manifest 中没有")
    return rows, problems


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--strict", action="store_true")
    parser.add_argument("--phase", choices=["core", "release"], default="core")
    args = parser.parse_args(argv)
    rows, problems = report(args.phase)
    for problem in problems:
        print(f"ERROR: {problem}")
    missing = [row for row in rows if not row["ready"]]
    print(f"资源就绪（{args.phase}）：{len(rows) - len(missing)}/{len(rows)}；客户端当前使用占位的资源：")
    for row in missing:
        if not row["runtime"]:
            where = "设计/商店素材，不进客户端"
        elif row["found"] == 0:
            where = f"未导入（0/{row['expected']}），客户端用占位"
        elif row["found"] < row["expected"]:
            where = f"导入不完整（{row['found']}/{row['expected']}），缺 {', '.join(row['missing'][:4])}…"
        else:
            where = "已导入但 manifest 未批准"
        print(f"  {row['batch']} {row['id']}: manifest={row['status']}；{where}；规格：{row['spec']}")
    if problems:
        return 1
    if args.strict and missing:
        print("FAILED: placeholder or unapproved assets remain; not releasable")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
