"""Python 基准与 Swift 核心包的差分报告（C08）。

    python tools/diff_core.py swift.json [report.md]

swift.json 来自 `swift run --package-path Packages/AntKingdomCore ak-sim`；Python 侧现场运行
economy_sim 的同一入口。夹具流量容差 1e-5 Food/min（TECHNICAL_HANDOFF 第 4 章），整数与分配逐项相等。
任一项不一致返回非零，并把逐项对照写成 Markdown（CI 附到 artifact 与 Step Summary）。
"""
import json
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import economy_sim as sim  # noqa: E402

FLOAT_TOLERANCE = 1e-5


def compare(label, python_value, swift_value, rows):
    if isinstance(python_value, float) or isinstance(swift_value, float):
        ok = (python_value is not None and swift_value is not None
              and math.isclose(python_value, swift_value, rel_tol=0, abs_tol=FLOAT_TOLERANCE))
    else:
        ok = python_value == swift_value
    rows.append((label, python_value, swift_value, ok))


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    swift = json.loads(Path(argv[1]).read_text(encoding="utf-8"))
    python = {"cases": sim.fixture_results(), "scripted_session": sim.scripted_session()}
    rows = []
    swift_cases = {case["case"]: case for case in swift["cases"]}
    for case in python["cases"]:
        other = swift_cases.get(case["case"], {})
        for key in ("before_food_per_min", "after_food_per_min", "gain_percent", "before_max_load",
                    "after_max_load", "after_allocations", "converged"):
            compare(f"{case['case']}.{key}", case[key], other.get(key), rows)
    for key, value in python["scripted_session"].items():
        compare(f"replay.{key}", value, swift["scripted_session"].get(key), rows)
    failed = [row for row in rows if not row[3]]
    lines = ["# Python ↔ Swift 核心差分报告", "",
             f"规则基线：{swift.get('rules_baseline', '?')}；浮点容差 {FLOAT_TOLERANCE}（夹具 Food/min）。", "",
             f"结果：{len(rows) - len(failed)}/{len(rows)} 项一致。", "",
             "| 项 | Python | Swift | 结果 |", "|---|---|---|---|"]
    for label, a, b, ok in rows:
        lines.append(f"| {label} | {a} | {b} | {'PASS' if ok else 'FAIL'} |")
    report = "\n".join(lines) + "\n"
    if len(argv) > 2:
        Path(argv[2]).write_text(report, encoding="utf-8")
    print(report)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
