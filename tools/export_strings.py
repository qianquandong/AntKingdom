"""把 PRD 附录 A 的英文文案导出为 iOS String Catalog（Localizable.xcstrings）。

PRD 附录 A 是唯一来源；客户端不手写散落的英文字符串。
    python tools/export_strings.py          # 重新生成目录文件
    python tools/export_strings.py --check  # 目录与 PRD 不一致时返回非零（CI 使用）
占位符保持 PRD 的 {name} 写法，由客户端 L10n 层替换；不使用 printf 格式符。
"""
import argparse
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_strings  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "ios/AntKingdom/Resources/Localizable.xcstrings"


def rows(doc):
    a, b = doc.index("## 附录 A"), doc.index("## 附录 B")
    return check_strings.ROW.findall(doc[a:b])


def render(doc):
    strings = {}
    for key, english, limit, usage in rows(doc):
        strings[key] = {
            "comment": f"max {limit} chars; {usage}",
            "extractionState": "manual",
            "localizations": {"en": {"stringUnit": {"state": "translated", "value": english}}},
        }
    catalog = {"sourceLanguage": "en", "strings": strings, "version": "1.0"}
    return json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True, separators=(",", " : ")) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    doc = check_strings.PRD.read_text(encoding="utf-8")
    errors = check_strings.validate(doc)
    if errors:
        print("FAILED: PRD strings invalid: " + "; ".join(errors))
        return 1
    expected = render(doc)
    if args.check:
        actual = CATALOG.read_text(encoding="utf-8") if CATALOG.exists() else ""
        if actual != expected:
            print(f"FAILED: {CATALOG.relative_to(ROOT)} is out of date; run python tools/export_strings.py")
            return 1
        print(f"OK: String Catalog matches PRD appendix A ({len(rows(doc))} strings)")
        return 0
    CATALOG.parent.mkdir(parents=True, exist_ok=True)
    CATALOG.write_text(expected, encoding="utf-8", newline="\n")
    print(f"wrote {CATALOG.relative_to(ROOT)} ({len(rows(doc))} strings)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
