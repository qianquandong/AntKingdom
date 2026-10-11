"""Crumb Kingdom v0.2 核心验证工具；不再预测 D8 通关或付费收益。

真实格网 -> 候选路线 -> 共享路段负载 -> 确定性分流 -> 资源守恒。
仅依赖标准库。python tools/economy_sim.py --check / --tables / --json
规则、局限和单位见 docs/PRD.md 第 4、6 章。
"""
from __future__ import annotations

import argparse
from collections import Counter, deque
from dataclasses import dataclass, field
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPEED = 2.0                 # 格/秒
CARRY = 2.0                 # Food/次完整运输
HANDLING = 3.0              # 装货 2 秒 + 卸货 1 秒
LANE_CAPACITY = 8.0         # 路段服务的搬运工预算，不是瞬时物理密度
MAX_PATHS = 4
MAX_MOVES = 256
EPSILON = 1e-10
TICK = 0.25                 # 秒；经济基准积分步长
OFFLINE_EFFICIENCY = 0.25
OFFLINE_CAP = 3600.0        # 秒；生产和孵化共同封顶
BASE_STORAGE = 100.0
PANTRY_STORAGE = 1000.0
PANTRY_COST = 50.0
HATCH_COST = 20.0
HATCH_SECONDS = 30.0
POP_CAP = 24
LARVA_SLOTS = 2
REFILL_SECONDS = 60.0
Point = tuple[int, int]
PathCells = tuple[Point, ...]


def point_key(p: Point):
    return p[1], p[0]


def neighbors(p: Point):
    x, y = p
    return ((x, y - 1), (x - 1, y), (x + 1, y), (x, y + 1))


def shortest_path(walkable: set[Point], starts: set[Point], sinks: set[Point],
                  blocked: frozenset[Point] = frozenset()) -> PathCells | None:
    """四邻 BFS；起点先行后列，邻居上左右下，固定顺序消除抖动。"""
    available = walkable - blocked
    queue = deque(p for p in sorted(starts & available, key=point_key))
    parent = {p: None for p in queue}
    while queue:
        p = queue.popleft()
        if p in sinks:
            path = []
            while p is not None:
                path.append(p)
                p = parent[p]
            return tuple(reversed(path))
        for q in neighbors(p):
            if q in available and q not in parent:
                parent[q] = p
                queue.append(q)
    return None


def candidate_paths(walkable: set[Point], starts: set[Point], sinks: set[Point]):
    """主路径 + 逐一避开主路径非终点格的替代 BFS；去重保留最短四条。

    有界候选搜索，不声称找到所有路线或全局最优运输方案。
    """
    primary = shortest_path(walkable, starts, sinks)
    if primary is None:
        return ()
    found = {primary}
    for p in primary[:-1]:
        alternate = shortest_path(walkable, starts, sinks, frozenset({p}))
        if alternate is not None:
            found.add(alternate)
    ordered = sorted(found, key=lambda route: (len(route), tuple(map(point_key, route))))
    return tuple(ordered[:MAX_PATHS])


@dataclass
class Demand:
    id: str
    starts: set[Point]
    ants: int
    extra_seconds: float = 0.0


@dataclass
class Route:
    source_id: str
    cells: PathCells
    ants: int = 0
    extra_seconds: float = 0.0

    @property
    def distance(self):
        return max(1, len(self.cells) - 1)

    @property
    def transit(self):
        # 装卸在 HANDLING 中计算，不制造一格路线的伪拥堵。
        return self.cells[1:-1]


@dataclass
class Plan:
    routes: list[Route]
    loads: dict[Point, int]
    trip_seconds: list[float]
    source_rates: dict[str, float]
    moves: int
    converged: bool
    improvements: list[float] = field(default_factory=list)

    @property
    def rate(self):
        return sum(self.source_rates.values())


def evaluate(routes: list[Route], speed=SPEED, carry=CARRY):
    if speed <= 0 or carry <= 0:
        raise ValueError("speed and carry must be positive")
    loads = Counter()
    for route in routes:
        for p in route.transit:
            loads[p] += route.ants
    trips, rates = [], {}
    for route in routes:
        extra = sum(max(0.0, loads[p] / LANE_CAPACITY - 1.0) for p in route.transit)
        trip = 2.0 * (route.distance + extra) / speed + HANDLING + route.extra_seconds
        trips.append(trip)
        rates[route.source_id] = rates.get(route.source_id, 0.0) + route.ants * carry / trip
    return dict(loads), trips, rates


def plan_transport(walkable: set[Point], sinks: set[Point], demands: list[Demand],
                   speed=SPEED, carry=CARRY) -> Plan:
    """逐只改道，严格增加全体 Food/s；比较改道后的全部共享负载。

    不使用 15% 门槛。同状态从主路径重算得到同一结果，避免逐秒翻转。
    """
    routes = []
    for demand in sorted(demands, key=lambda d: d.id):
        if demand.ants < 0:
            raise ValueError("negative haulers")
        for index, path in enumerate(candidate_paths(walkable, demand.starts, sinks)):
            routes.append(Route(demand.id, path, demand.ants if index == 0 else 0,
                                demand.extra_seconds))
    score = sum(evaluate(routes, speed, carry)[2].values())
    improvements = [score]
    moves, converged = 0, False
    while moves < MAX_MOVES:
        best_score, best = score, None
        for i, origin in enumerate(routes):
            if origin.ants == 0:
                continue
            for j, target in enumerate(routes):
                if i == j or origin.source_id != target.source_id:
                    continue
                origin.ants -= 1
                target.ants += 1
                candidate = sum(evaluate(routes, speed, carry)[2].values())
                origin.ants += 1
                target.ants -= 1
                if candidate > best_score + EPSILON:
                    best_score, best = candidate, (i, j)
        if best is None:
            converged = True
            break
        routes[best[0]].ants -= 1
        routes[best[1]].ants += 1
        score = best_score
        improvements.append(score)
        moves += 1
    loads, trips, rates = evaluate(routes, speed, carry)
    return Plan(routes, loads, trips, rates, moves, converged, improvements)


@dataclass
class Source:
    id: str
    cells: set[Point]
    remaining: float | None
    priority: int
    extra_seconds: float = 0.0


class Colony:
    """P0 小地图经济状态；食物必须真的挖通，没有广告或付费推算。"""

    def __init__(self, map_path: Path | None = None):
        self.grid = (map_path or ROOT / "design/map_prototype.txt").read_text(encoding="utf-8").splitlines()
        if len(self.grid) != 10 or any(len(row) != 9 for row in self.grid):
            raise ValueError("prototype map must be 9 x (surface + 9)")
        self.tiles = {(x, y): c for y, row in enumerate(self.grid) for x, c in enumerate(row)}
        self.walkable = {p for p, c in self.tiles.items() if c in ".QE"}
        self.queen = {p for p, c in self.tiles.items() if c == "Q"}
        self.pantry: set[Point] = set()
        self.sources = [
            Source("cookie", {p for p, c in self.tiles.items() if c == "C"}, 600.0, 0),
            Source("sugar", {p for p, c in self.tiles.items() if c == "S"}, 0.0, 0),
            Source("sap", {p for p, c in self.tiles.items() if c == "R"}, None, 1),
            Source("surface", {(4, 0)}, None, 2, 12.0),
        ]
        self.food = 0.0
        self.ants = 5
        self.larvae: list[float] = []
        self.hatching = True
        self.elapsed = 0.0
        self.refill_left = REFILL_SECONDS
        self.next_patch = 1       # Cookie -> Sugar -> Cookie
        self.refills = 0
        self.hauled = 0.0
        self.spent = 0.0
        self._cached_key = None
        self._cached_plan = None

    @property
    def capacity(self):
        return BASE_STORAGE + (PANTRY_STORAGE if self.pantry else 0)

    @property
    def sinks(self):
        return self.queen | self.pantry

    def dig(self, p: Point):
        # 基准工具按“完成一格”操作；客户端先累计三次有效点击。
        if self.tiles.get(p) != "#" or p in self.walkable:
            raise ValueError("not undug soil")
        if not any(q in self.walkable for q in neighbors(p)):
            raise ValueError("not frontier")
        self.walkable.add(p)

    def place_pantry(self, top_left: Point):
        x, y = top_left
        cells = {(x + dx, y + dy) for dx in (0, 1) for dy in (0, 1)}
        if not cells <= self.walkable or cells & self.queen or (4, 0) in cells:
            raise ValueError("invalid Pantry footprint")
        if not self.pantry:
            if self.food < PANTRY_COST:
                raise ValueError("not enough Food")
            self.food -= PANTRY_COST
            self.spent += PANTRY_COST
        self.pantry = cells

    def plan(self):
        active = []
        for source in self.sources:
            if source.remaining is not None and source.remaining <= EPSILON:
                continue
            starts = ({(4, 0)} if source.id == "surface" else
                      {q for p in source.cells for q in neighbors(p) if q in self.walkable})
            route = shortest_path(self.walkable, starts, self.sinks)
            if route is not None:
                free_trip = 2 * max(1, len(route) - 1) / SPEED + HANDLING + source.extra_seconds
                active.append((source.priority, free_trip, source.id, starts, source.extra_seconds))
        active.sort(key=lambda row: row[:3])
        # P0 全员服务一个源：已连通补给 > 树液根 > 地面兜底。
        # 多源共享负载仍有独立测试，扩展版不能退回各算各的。
        demands = [] if not active else [Demand(active[0][2], active[0][3], self.ants, active[0][4])]
        key = (frozenset(self.walkable), frozenset(self.sinks),
               tuple((d.id, frozenset(d.starts), d.ants, d.extra_seconds) for d in demands))
        if key != self._cached_key:
            self._cached_plan = plan_transport(self.walkable, self.sinks, demands)
            if not self._cached_plan.converged:
                raise RuntimeError("transport solver exceeded move budget")
            self._cached_key = key
        return self._cached_plan

    def harvest(self, seconds: float, efficiency: float):
        """仅按实际入库量扣有限源；满仓时源和库存均不变。"""
        available = max(0.0, self.capacity - self.food)
        if available <= EPSILON:
            return 0.0
        rates = self.plan().source_rates
        desired = []
        for source in self.sources:
            amount = rates.get(source.id, 0.0) * seconds * efficiency
            if source.remaining is not None:
                amount = min(amount, source.remaining)
            desired.append((source, amount))
        total = sum(amount for _, amount in desired)
        scale = min(1.0, available / total) if total > 0 else 0.0
        credited = 0.0
        for source, amount in desired:
            amount *= scale
            if source.remaining is not None:
                source.remaining = max(0.0, source.remaining - amount)
            credited += amount
        self.food = min(self.capacity, self.food + credited)
        self.hauled += credited
        return credited

    def advance(self, seconds: float, efficiency=1.0):
        if not math.isfinite(seconds) or seconds < 0 or not 0 <= efficiency <= 1:
            raise ValueError("invalid duration or efficiency")
        end = self.elapsed + seconds
        while self.elapsed < end - EPSILON:
            dt = min(TICK, end - self.elapsed)
            if self.larvae:
                dt = min(dt, min(self.larvae))
            patches_empty = all(s.remaining <= EPSILON for s in self.sources[:2])
            if patches_empty:
                dt = min(dt, self.refill_left)
            self.harvest(dt, efficiency)
            self.larvae = [remaining - dt for remaining in self.larvae]
            self.ants += sum(remaining <= EPSILON for remaining in self.larvae)
            self.larvae = [remaining for remaining in self.larvae if remaining > EPSILON]
            if self.hatching:
                while (len(self.larvae) < LARVA_SLOTS and self.ants + len(self.larvae) < POP_CAP
                       and self.food >= HATCH_COST):
                    self.food -= HATCH_COST
                    self.spent += HATCH_COST
                    self.larvae.append(HATCH_SECONDS)
            if patches_empty:
                self.refill_left -= dt
                if self.refill_left <= EPSILON:
                    self.sources[self.next_patch].remaining = 600.0 if self.next_patch == 0 else 150.0
                    self.next_patch = 1 - self.next_patch
                    self.refills += 1
                    self.refill_left = REFILL_SECONDS
            self.elapsed += dt

    def offline(self, seconds: float):
        if not math.isfinite(seconds) or seconds < 0:
            raise ValueError("invalid offline duration")
        before, hauled_before = self.food, self.hauled
        self.advance(min(seconds, OFFLINE_CAP), OFFLINE_EFFICIENCY)
        return {"net_food": self.food - before, "hauled_food": self.hauled - hauled_before,
                "simulated_seconds": min(seconds, OFFLINE_CAP)}


def fixture_results():
    data = json.loads((ROOT / "design/transport_cases.json").read_text(encoding="utf-8"))
    results = []
    for case in data:
        plans = []
        for variant in ("before", "after"):
            state = case[variant]
            plans.append(plan_transport({tuple(p) for p in state["walkable"]},
                         {tuple(p) for p in state["sinks"]},
                         [Demand(d["id"], {tuple(p) for p in d["starts"]}, d["ants"])
                          for d in case["demands"]]))
        before, after = plans
        results.append({"case": case["id"], "before_food_per_min": round(before.rate * 60, 6),
                        "after_food_per_min": round(after.rate * 60, 6),
                        "gain_percent": round((after.rate / before.rate - 1) * 100, 6),
                        "before_max_load": max(before.loads.values(), default=0),
                        "after_max_load": max(after.loads.values(), default=0),
                        "after_allocations": [r.ants for r in after.routes],
                        "converged": before.converged and after.converged})
    return results


def scripted_session():
    """600秒固定操作回放，仅用于回归验证，绝不是玩家行为预测。"""
    colony = Colony()
    actions = {30: [(2, 4), (2, 5), (2, 6)], 150: [(1, 4), (1, 5)],
               300: [(6, 3), (6, 2)], 360: [(6, 4), (6, 5), (6, 6), (7, 6)]}
    for second in range(600):
        for p in actions.get(second, []):
            colony.dig(p)
        if second >= 150 and not colony.pantry and colony.food >= PANTRY_COST:
            colony.place_pantry((1, 4))
        colony.advance(1)
    return {"seconds": 600, "ants": colony.ants, "larvae": len(colony.larvae),
            "food": round(colony.food, 6), "capacity": colony.capacity,
            "hauled": round(colony.hauled, 6), "spent": colony.spent,
            "refills": colony.refills,
            "food_conservation_error": round(colony.hauled - colony.spent - colony.food, 9)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="验证夹具预期值和资源守恒")
    parser.add_argument("--tables", action="store_true", help="打印 PRD 对照场景")
    parser.add_argument("--json", action="store_true", help="机器可读结果")
    args = parser.parse_args()
    cases, session = fixture_results(), scripted_session()
    if args.check:
        fixtures = json.loads((ROOT / "design/transport_cases.json").read_text(encoding="utf-8"))
        for actual, fixture in zip(cases, fixtures):
            for key, expected in fixture["expected"].items():
                if not math.isclose(actual[key], expected, rel_tol=1e-6, abs_tol=1e-6):
                    raise SystemExit(f"FAILED: {fixture['id']} {key}: {actual[key]} != {expected}")
            if not actual["converged"] or actual["gain_percent"] <= 0:
                raise SystemExit(f"FAILED: {fixture['id']} did not converge/improve")
        if abs(session["food_conservation_error"]) > 1e-6 or session["food"] > session["capacity"]:
            raise SystemExit("FAILED: food conservation/capacity")
        print("OK: 3 actual-grid transport cases; 600s replay conserves Food")
    elif args.json:
        print(json.dumps({"cases": cases, "scripted_session": session}, ensure_ascii=False, indent=2))
    else:
        print("真实格网运输对照（Food/min；假设验证，非玩家留存/付费预测）")
        for row in cases:
            print(f"{row['case']}: {row['before_food_per_min']:.3f} -> "
                  f"{row['after_food_per_min']:.3f}; +{row['gain_percent']:.2f}%; "
                  f"分流={row['after_allocations']}")
        if not args.tables:
            print("固定600秒操作回放：", session)


if __name__ == "__main__":
    main()
