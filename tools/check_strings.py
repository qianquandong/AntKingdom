"""检查 PRD 英文文案、引用和占位符展开后的长度；失败返回非零退出码。"""
import re
from pathlib import Path
import sys

PRD = Path(__file__).resolve().parents[1] / "docs/PRD.md"
ROW = re.compile(r"^\| `([a-z][a-z0-9_]*(?:\.[a-z0-9_]+)+)` \| (.*?) \| (\d+) \| (.*?) \|$", re.M)
REF = re.compile(r"`([a-z][a-z0-9_]*\.[a-z0-9_.]+)`")
CJK = re.compile(r"[㐀-鿿＀-￯]")
# 首版可能显示的上限样例；大于预算的数值必须先统一缩写再渲染。
SAMPLES = {"food": "1100", "capacity": "1100", "ants": "24", "cap": "24",
           "eggs": "2", "seconds": "3600.0", "rate": "9999.9", "percent": "999.9"}


def validate(doc):
    errors = []
    if "## 附录 A" not in doc or "## 附录 B" not in doc:
        return ["missing string appendix delimiters"]
    a, b = doc.index("## 附录 A"), doc.index("## 附录 B")
    rows = ROW.findall(doc[a:b])
    if not rows:
        return ["empty string table"]
    ids = [row[0] for row in rows]
    declared = REF.findall(doc[a:b])
    if len(declared) != len(rows):
        errors.append("malformed string row")
    duplicates = sorted({i for i in ids if ids.count(i) > 1})
    if duplicates:
        errors.append(f"duplicate IDs: {duplicates}")
    refs = {r for r in REF.findall(doc[:a] + doc[b:])
            if not r.endswith((".py", ".md", ".txt", ".json"))}
    if refs - set(ids):
        errors.append(f"missing IDs: {sorted(refs - set(ids))}")
    for key, english, limit, _ in rows:
        if CJK.search(english):
            errors.append(f"Chinese in English text: {key}")
        try:
            rendered = english.format(**SAMPLES)
        except (KeyError, ValueError, IndexError) as error:
            errors.append(f"invalid placeholder in {key}: {error}")
            continue
        if len(rendered) > int(limit):
            errors.append(f"text too long: {key} {len(rendered)} > {limit}")
    return errors


def main():
    doc = PRD.read_text(encoding="utf-8")
    errors = validate(doc)
    if errors:
        print("FAILED: " + "; ".join(errors))
        return 1
    print(f"OK: {len(ROW.findall(doc))} English strings; references, IDs, placeholders, lengths")
    return 0


if __name__ == "__main__":
    sys.exit(main())
