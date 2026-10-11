"""资源就绪检查：design/asset_manifest.json 中的资源是否已作为正式资源进入 iOS 资源目录。

    python tools/check_assets.py            # 打印报告（日常 CI：信息性，退出码 0）
    python tools/check_assets.py --strict   # 发行检查：任一核心资源缺失或仍为占位即失败
    python tools/check_assets.py --phase release --strict   # M4 以后连正式版资源一起检查

客户端在资源缺失时绘制带资源 ID 的占位（只在 Debug 标注 ID）；占位不能通过美术终验或进入
App Store 包（ART_DIRECTION、TECHNICAL_HANDOFF 第 6 章）。资源以 manifest 的 id 作为
Assets.xcassets 中的 imageset 名或 Resources/Audio 下的文件名前缀。
"""
import argparse
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "design/asset_manifest.json"
CATALOG = ROOT / "ios/AntKingdom/Resources/Assets.xcassets"
AUDIO = ROOT / "ios/AntKingdom/Resources/Audio"
# 不需要进入客户端资源目录的条目（设计稿、地图数据、商店素材）
NOT_RUNTIME = {"art_keyframe", "chapter_maps", "store_screenshots", "ui_release"}
READY = {"approved", "integrated", "verified_on_device"}


def present(asset_id):
    if (CATALOG / f"{asset_id}.imageset").exists() or (CATALOG / f"{asset_id}.appiconset").exists():
        return True
    if any((CATALOG).glob(f"{asset_id}_*.imageset")):
        return True
    return AUDIO.exists() and any(AUDIO.glob(f"{asset_id}*"))


def report(phase):
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    rows = []
    for asset in manifest["assets"]:
        if phase == "core" and asset["phase"] != "core":
            continue
        runtime = asset["id"] not in NOT_RUNTIME
        rows.append({
            "id": asset["id"], "batch": asset["batch"], "status": asset["status"],
            "runtime": runtime, "in_app": present(asset["id"]) if runtime else None,
            "ready": asset["status"] in READY and (present(asset["id"]) or not runtime),
            "spec": asset["spec"],
        })
    return rows


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--strict", action="store_true")
    parser.add_argument("--phase", choices=["core", "release"], default="core")
    args = parser.parse_args(argv)
    rows = report(args.phase)
    missing = [row for row in rows if not row["ready"]]
    print(f"资源就绪（{args.phase}）：{len(rows) - len(missing)}/{len(rows)}；客户端当前使用占位的资源：")
    for row in missing:
        where = "设计/商店素材" if not row["runtime"] else ("已导入但未批准" if row["in_app"] else "未导入，客户端用占位")
        print(f"  {row['batch']} {row['id']}: manifest={row['status']}；{where}；规格：{row['spec']}")
    if args.strict and missing:
        print("FAILED: placeholder or unapproved assets remain; not releasable")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
