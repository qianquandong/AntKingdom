"""Check player-facing string IDs in docs/PRD.md (design tool).

  python tools/check_strings.py

- every `string.id` referenced in the PRD body exists in Appendix A
- no duplicate IDs in Appendix A
- the English Text column contains no Chinese characters
"""
import re
from pathlib import Path

PRD = Path(__file__).resolve().parent.parent / "docs" / "PRD.md"
ROW = re.compile(r"^\| `([a-z][a-z0-9_]*(?:\.[a-z0-9_]+)+)` \| (.*?) \| (.*?) \| (.*?) \|$", re.M)
REF = re.compile(r"`([a-z][a-z0-9_]*\.[a-z0-9_.]+)`")
CJK = re.compile(r"[㐀-鿿＀-￯]")


def main():
    doc = PRD.read_text(encoding="utf-8")
    a, b = doc.index("## 附录 A"), doc.index("## 附录 B")
    rows = ROW.findall(doc[a:b])
    ids = [r[0] for r in rows]
    body = doc[:a] + doc[b:]
    refs = {r for r in REF.findall(body) if not r.endswith(".py") and not r.startswith("save.")}
    dups = sorted({i for i in ids if ids.count(i) > 1})
    missing = sorted(refs - set(ids))
    chinese = [r[0] for r in rows if CJK.search(r[1])]
    print(f"{len(ids)} strings | duplicates: {dups} | missing: {missing} | Chinese in English column: {chinese}")
    print("OK" if not (dups or missing or chinese) else "FAILED")


if __name__ == "__main__":
    main()
