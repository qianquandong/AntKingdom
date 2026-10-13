"""检查英文文案、引用和占位符展开后的长度；失败返回非零退出码。

两张表：核心版 docs/PRD.md 附录 A；正式版增量 docs/RELEASE_SCOPE.md 第 6 节（只进发行轨 target）。
正式版表的 ID 不得与核心表重复（不重用一个 ID 承载不同意义）。
"""
import re
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
PRD = ROOT / "docs/PRD.md"
RELEASE = ROOT / "docs/RELEASE_SCOPE.md"
RELEASE_START = "## 6. 新增英文文案登记"
ROW = re.compile(r"^\| `([a-z][a-z0-9_]*(?:\.[a-z0-9_]+)+)` \| (.*?) \| (\d+) \| (.*?) \|$", re.M)
REF = re.compile(r"`([a-z][a-z0-9_]*\.[a-z0-9_.]+)`")
CJK = re.compile(r"[㐀-鿿＀-￯]")
# 首版可能显示的上限样例；大于预算的数值必须先统一缩写再渲染。
SAMPLES = {"food": "1100", "capacity": "1100", "ants": "24", "cap": "24",
           "eggs": "2", "seconds": "3600.0", "rate": "9999.9", "percent": "999.9",
           # 正式版：本地化价格、m:ss 时长、最长的目标文案、目标计数
           "price": "CHF 12.00", "time": "59:59", "goal": "Grow to 24 ants and 1,100 Food",
           "done": "6", "total": "6"}
NOT_STRINGS = (".py", ".md", ".txt", ".json", ".xcstrings")


def check_rows(rows, errors):
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


def validate(doc):
    """核心表（PRD 附录 A）。"""
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
    refs = {r for r in REF.findall(doc[:a] + doc[b:]) if not r.endswith(NOT_STRINGS)}
    if refs - set(ids):
        errors.append(f"missing IDs: {sorted(refs - set(ids))}")
    check_rows(rows, errors)
    return errors


def core_rows(doc):
    a, b = doc.index("## 附录 A"), doc.index("## 附录 B")
    return ROW.findall(doc[a:b])


def release_rows(release_doc):
    return ROW.findall(release_doc[release_doc.index(RELEASE_START):])


def validate_release(release_doc, prd_doc):
    """正式版增量表（RELEASE_SCOPE 第 6 节）：与核心表合起来唯一，引用必须存在于两张表之一。"""
    if RELEASE_START not in release_doc:
        return ["missing release string section"]
    start = release_doc.index(RELEASE_START)
    rows = release_rows(release_doc)
    if not rows:
        return ["empty release string table"]
    errors = []
    if len(REF.findall(release_doc[start:]) ) < len(rows):
        errors.append("malformed release string row")
    ids = [row[0] for row in rows]
    duplicates = sorted({i for i in ids if ids.count(i) > 1})
    if duplicates:
        errors.append(f"duplicate release IDs: {duplicates}")
    core = {row[0] for row in core_rows(prd_doc)}
    reused = sorted(set(ids) & core)
    if reused:
        errors.append(f"release IDs reuse core IDs: {reused}")
    table_lines = "\n".join(line for line in release_doc[start:].splitlines() if not line.startswith("| `"))
    refs = {r for r in REF.findall(release_doc[:start] + table_lines) if not r.endswith(NOT_STRINGS)}
    missing = refs - set(ids) - core
    if missing:
        errors.append(f"missing release IDs: {sorted(missing)}")
    check_rows(rows, errors)
    return errors


def main():
    doc = PRD.read_text(encoding="utf-8")
    errors = validate(doc)
    if errors:
        print("FAILED: " + "; ".join(errors))
        return 1
    release = RELEASE.read_text(encoding="utf-8")
    release_errors = validate_release(release, doc)
    if release_errors:
        print("FAILED (release): " + "; ".join(release_errors))
        return 1
    print(f"OK: {len(core_rows(doc))} core + {len(release_rows(release))} release English strings; "
          "references, IDs, placeholders, lengths")
    return 0


if __name__ == "__main__":
    sys.exit(main())
