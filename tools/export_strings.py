"""把英文文案表导出为 iOS String Catalog。

- 核心表 docs/PRD.md 附录 A → ios/AntKingdom/Resources/Localizable.xcstrings（两个 target 都打包）
- 正式版表 docs/RELEASE_SCOPE.md 第 6 节 → ios/ReleaseTrack/Resources/Release.xcstrings（只进发行轨 target）
文案表是唯一来源；客户端不手写散落的英文字符串。
    python tools/export_strings.py          # 重新生成目录文件
    python tools/export_strings.py --check  # 目录与文案表不一致时返回非零（CI 使用）
占位符保持 {name} 写法，由客户端 L10n 层替换；不使用 printf 格式符。
"""
import argparse
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_strings  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "ios/AntKingdom/Resources/Localizable.xcstrings"
RELEASE_CATALOG = ROOT / "ios/ReleaseTrack/Resources/Release.xcstrings"


def rows(doc):
    return check_strings.core_rows(doc)


def render_rows(table):
    strings = {}
    for key, english, limit, usage in table:
        strings[key] = {
            "comment": f"max {limit} chars; {usage}",
            "extractionState": "manual",
            "localizations": {"en": {"stringUnit": {"state": "translated", "value": english}}},
        }
    catalog = {"sourceLanguage": "en", "strings": strings, "version": "1.0"}
    return json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True, separators=(",", " : ")) + "\n"


def render(doc):
    return render_rows(rows(doc))


def outputs():
    doc = check_strings.PRD.read_text(encoding="utf-8")
    release = check_strings.RELEASE.read_text(encoding="utf-8")
    errors = check_strings.validate(doc) + check_strings.validate_release(release, doc)
    return errors, [(CATALOG, render(doc), len(rows(doc))),
                    (RELEASE_CATALOG, render_rows(check_strings.release_rows(release)),
                     len(check_strings.release_rows(release)))]


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    errors, targets = outputs()
    if errors:
        print("FAILED: strings invalid: " + "; ".join(errors))
        return 1
    for path, expected, count in targets:
        if args.check:
            actual = path.read_text(encoding="utf-8") if path.exists() else ""
            if actual != expected:
                print(f"FAILED: {path.relative_to(ROOT)} is out of date; run python tools/export_strings.py")
                return 1
            print(f"OK: {path.relative_to(ROOT)} matches its string table ({count} strings)")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(expected, encoding="utf-8", newline="\n")
            print(f"wrote {path.relative_to(ROOT)} ({count} strings)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
