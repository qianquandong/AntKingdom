"""导出 Python 基准的高精度对照数据，供 Swift 核心包逐项差分（TECHNICAL_HANDOFF 第 4 章）。

    python tools/export_reference.py          # 写 design/reference/core_reference.json
    python tools/export_reference.py --check  # 与已提交文件比对（浮点容差 1e-9），过期则返回非零

内容：三组夹具前后完整求解结果、测试中的额外运输场景、全挖地图 1–24 只人口扫描、
600 秒回放每秒状态、离线一致性场景。浮点保留原始值，不做显示舍入。
Python 3.12+ 的 sum() 使用补偿求和，与 3.11 可能差 1 ulp，因此比对使用容差而非逐位相等。
"""
import argparse
import copy
import json
import math
from pathlib import Path
import platform
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import economy_sim as sim  # noqa: E402

ROOT = sim.ROOT
OUTPUT = ROOT / "design/reference/core_reference.json"
TOLERANCE = 1e-9


def points(cells):
    return [list(p) for p in sorted(cells, key=sim.point_key)]


def plan_record(plan):
    return {
        "rate": plan.rate,
        "routes": [{"source": r.source_id, "cells": [list(p) for p in r.cells], "ants": r.ants}
                   for r in plan.routes],
        "trip_seconds": plan.trip_seconds,
        "source_rates": [[k, v] for k, v in plan.source_rates.items()],
        "loads": [[p[0], p[1], n] for p, n in sorted(plan.loads.items(), key=lambda kv: sim.point_key(kv[0]))],
        "moves": plan.moves,
        "converged": plan.converged,
        "improvements": plan.improvements,
    }


def scenario(scenario_id, walkable, sinks, demands):
    plan = sim.plan_transport(set(walkable), set(sinks), demands)
    return {"id": scenario_id, "walkable": points(walkable), "sinks": points(sinks),
            "demands": [{"id": d.id, "starts": points(d.starts), "ants": d.ants, "extra_seconds": d.extra_seconds}
                        for d in demands],
            "plan": plan_record(plan)}


def transport_scenarios():
    rows = []
    fixtures = json.loads((ROOT / "design/transport_cases.json").read_text(encoding="utf-8"))
    for case in fixtures:
        for variant in ("before", "after"):
            state = case[variant]
            rows.append(scenario(f"{case['id']}.{variant}", {tuple(p) for p in state["walkable"]},
                                 {tuple(p) for p in state["sinks"]},
                                 [sim.Demand(d["id"], {tuple(p) for p in d["starts"]}, d["ants"])
                                  for d in case["demands"]]))
    rows.append(scenario("one_cell_seven_ants", {(0, 0), (1, 0)}, {(1, 0)},
                         [sim.Demand("food", {(0, 0)}, 7)]))
    rows.append(scenario("shared_corridor_two_sources", {(0, 0), (0, 1), (1, 0), (2, 0)}, {(2, 0)},
                         [sim.Demand("a", {(0, 0)}, 8), sim.Demand("b", {(0, 1)}, 8)]))
    rows.append(scenario("disconnected_source", {(0, 0), (2, 0)}, {(2, 0)}, [sim.Demand("a", {(0, 0)}, 7)]))
    endpoints = {(1, 2), (7, 2)}
    before = endpoints | {(x, 1) for x in range(1, 8)}
    after = before | {(1, 3), (7, 3)} | {(x, 4) for x in range(1, 8)}
    rows.append(scenario("longer_bypass.before", before, {(7, 2)}, [sim.Demand("food", {(1, 2)}, 16)]))
    rows.append(scenario("longer_bypass.after", after, {(7, 2)}, [sim.Demand("food", {(1, 2)}, 16)]))
    return rows


def excavate_all(colony):
    while True:
        frontier = [p for p, ch in colony.tiles.items()
                    if ch == "#" and p not in colony.walkable
                    and any(q in colony.walkable for q in sim.neighbors(p))]
        if not frontier:
            return
        for p in frontier:
            colony.dig(p)


def population_sweep():
    colony = sim.Colony()
    excavate_all(colony)
    rows = []
    for ants in range(1, sim.POP_CAP + 1):
        colony.ants = ants
        plan = colony.plan()
        rows.append({"ants": ants, "source": plan.routes[0].source_id if plan.routes else None,
                     "rate": plan.rate, "allocations": [r.ants for r in plan.routes],
                     "route_lengths": [len(r.cells) for r in plan.routes], "moves": plan.moves})
    return {"walkable": points(colony.walkable), "rows": rows}


def colony_state(colony):
    return {"elapsed": colony.elapsed, "food": colony.food, "ants": colony.ants, "larvae": colony.larvae,
            "hauled": colony.hauled, "spent": colony.spent, "refills": colony.refills,
            "refill_left": colony.refill_left, "next_patch": colony.next_patch,
            "remaining": [s.remaining for s in colony.sources]}


def replay():
    colony = sim.Colony()
    trace = []
    for second in range(600):
        for p in {30: [(2, 4), (2, 5), (2, 6)], 150: [(1, 4), (1, 5)],
                  300: [(6, 3), (6, 2)], 360: [(6, 4), (6, 5), (6, 6), (7, 6)]}.get(second, []):
            colony.dig(p)
        if second >= 150 and not colony.pantry and colony.food >= sim.PANTRY_COST:
            colony.place_pantry((1, 4))
        colony.advance(1)
        plan_source = colony.plan().routes[0].source_id if colony.plan().routes else None
        row = colony_state(colony)
        row.update({"second": second, "pantry_built": bool(colony.pantry), "active_source": plan_source})
        trace.append(row)
    summary = sim.scripted_session()
    # 本函数复写了 scripted_session 的动作表以便逐秒记录；终态必须与基准一致。
    final = trace[-1]
    assert (final["ants"], len(final["larvae"]), final["refills"]) == (summary["ants"], summary["larvae"], summary["refills"])
    assert math.isclose(final["food"], summary["food"], abs_tol=1e-6)
    return {"summary": summary, "trace": trace}


def offline_scenarios():
    def connected():
        colony = sim.Colony()
        for p in [(2, 4), (2, 5), (2, 6)]:
            colony.dig(p)
        return colony

    rows = []
    for seconds in (240, 3600, 7200):
        colony = connected()
        result = colony.offline(seconds)
        rows.append({"id": f"offline_{seconds}", "result": result, "state": colony_state(colony)})
    colony = connected()
    colony.advance(240, efficiency=0.25)
    rows.append({"id": "online_quarter_240", "state": colony_state(colony)})
    colony = connected()
    colony.advance(240)
    rows.append({"id": "online_full_240", "state": colony_state(colony)})
    return rows


def build():
    return {
        "generator": "tools/export_reference.py",
        "python": platform.python_version(),
        "tolerance": TOLERANCE,
        "fixtures": sim.fixture_results(),
        "transport_scenarios": transport_scenarios(),
        "population_sweep": population_sweep(),
        "replay": replay(),
        "offline": offline_scenarios(),
    }


def close(a, b, path="$"):
    """递归比较；浮点按容差，其余逐项相等。返回第一处差异描述或 None。"""
    if isinstance(a, float) or isinstance(b, float):
        if a is None or b is None or not math.isclose(a, b, rel_tol=TOLERANCE, abs_tol=TOLERANCE):
            return f"{path}: {a!r} != {b!r}"
        return None
    if isinstance(a, dict) and isinstance(b, dict):
        if set(a) != set(b):
            return f"{path}: keys {sorted(set(a) ^ set(b))}"
        for key in a:
            if key == "python":
                continue
            diff = close(a[key], b[key], f"{path}.{key}")
            if diff:
                return diff
        return None
    if isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            return f"{path}: length {len(a)} != {len(b)}"
        for index, (x, y) in enumerate(zip(a, b)):
            diff = close(x, y, f"{path}[{index}]")
            if diff:
                return diff
        return None
    return None if a == b else f"{path}: {a!r} != {b!r}"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    data = json.loads(json.dumps(build()))
    if args.check:
        if not OUTPUT.exists():
            print(f"FAILED: missing {OUTPUT.relative_to(ROOT)}")
            return 1
        diff = close(data, json.loads(OUTPUT.read_text(encoding="utf-8")))
        if diff:
            print(f"FAILED: {OUTPUT.relative_to(ROOT)} out of date: {diff}")
            return 1
        print("OK: core_reference.json matches the Python baseline")
        return 0
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8", newline="\n")
    print(f"wrote {OUTPUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
