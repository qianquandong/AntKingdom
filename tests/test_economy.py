"""运输行为、边界与资源守恒回归；不把模拟结果当市场预测。"""
import copy
import json
import math
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import economy_sim as sim


def connect_cookie(colony):
    for p in [(2, 4), (2, 5), (2, 6)]:
        colony.dig(p)


def excavate_all(colony):
    while True:
        frontier = [p for p, ch in colony.tiles.items()
                    if ch == "#" and p not in colony.walkable
                    and any(q in colony.walkable for q in sim.neighbors(p))]
        if not frontier:
            return
        for p in frontier:
            colony.dig(p)


class TransportTests(unittest.TestCase):
    def test_three_hand_calculated_cases(self):
        fixtures = json.loads((sim.ROOT / "design/transport_cases.json").read_text(encoding="utf-8"))
        actual = sim.fixture_results()
        self.assertEqual(len(actual), 3)
        for expected, result in zip(fixtures, actual):
            with self.subTest(case=expected["id"]):
                self.assertTrue(result["converged"])
                for key, value in expected["expected"].items():
                    self.assertAlmostEqual(result[key], value, places=5)
        self.assertEqual(actual[1]["after_allocations"], [8, 8])

    def test_one_cell_seven_ants_has_no_self_congestion(self):
        result = sim.plan_transport({(0, 0), (1, 0)}, {(1, 0)},
                                    [sim.Demand("food", {(0, 0)}, 7)])
        self.assertEqual(result.trip_seconds, [4.0])
        self.assertAlmostEqual(result.rate * 60, 210)
        self.assertFalse(result.loads)

    def test_multiple_sources_share_corridor_capacity(self):
        # 两个装货口共用中间一格：8 + 8 只，必须按 16 只计拥堵。
        cells = {(0, 0), (0, 1), (1, 0), (2, 0)}
        plan = sim.plan_transport(cells, {(2, 0)},
                                 [sim.Demand("a", {(0, 0)}, 8), sim.Demand("b", {(0, 1)}, 8)])
        self.assertEqual(plan.loads[(1, 0)], 16)
        self.assertEqual(plan.trip_seconds, [6.0, 7.0])
        self.assertAlmostEqual(plan.rate, 16 / 6 + 16 / 7)

    def test_disconnected_source_does_not_generate_income(self):
        plan = sim.plan_transport({(0, 0), (2, 0)}, {(2, 0)}, [sim.Demand("a", {(0, 0)}, 7)])
        self.assertEqual(plan.rate, 0)
        self.assertTrue(plan.converged)

    def test_deterministic_bounded_monotonic_rerouting(self):
        fixture = json.loads((sim.ROOT / "design/transport_cases.json").read_text(encoding="utf-8"))[1]
        state = fixture["after"]
        cells, sinks = {tuple(p) for p in state["walkable"]}, {tuple(p) for p in state["sinks"]}
        first = sim.plan_transport(cells, sinks, [sim.Demand("a", {(1, 2)}, 16)])
        second = sim.plan_transport(set(reversed(sorted(cells))), sinks, [sim.Demand("a", {(1, 2)}, 16)])
        self.assertEqual(first, second)
        self.assertLess(first.moves, sim.MAX_MOVES)
        self.assertTrue(all(b > a for a, b in zip(first.improvements, first.improvements[1:])))
        self.assertEqual(sum(r.ants for r in first.routes), 16)

    def test_fixed_geometry_population_sweep(self):
        colony = sim.Colony()
        excavate_all(colony)
        for ants in range(1, sim.POP_CAP + 1):
            colony.ants = ants
            with self.subTest(ants=ants):
                plan = colony.plan()
                self.assertTrue(plan.converged)
                self.assertGreater(plan.rate, 0)
                self.assertEqual(sum(r.ants for r in plan.routes), ants)

    def test_longer_bypass_can_relieve_congestion(self):
        # 旁路比主路长两格；应按实际拥堵后的总产量判断，而非只选最短路。
        endpoints = {(1, 2), (7, 2)}
        before_cells = endpoints | {(x, 1) for x in range(1, 8)}
        after_cells = before_cells | {(1, 3), (7, 3)} | {(x, 4) for x in range(1, 8)}
        demands = [sim.Demand("food", {(1, 2)}, 16)]
        before = sim.plan_transport(before_cells, {(7, 2)}, demands)
        after = sim.plan_transport(after_cells, {(7, 2)}, demands)
        self.assertTrue(after.converged)
        self.assertTrue(any(r.distance > 8 and r.ants > 0 for r in after.routes))
        self.assertGreater(after.rate, before.rate)
        self.assertEqual(sum(r.ants for r in after.routes), 16)


class EconomyTests(unittest.TestCase):
    def setUp(self):
        self.colony = sim.Colony()

    def test_no_auto_connection_and_infinite_fallback(self):
        self.assertEqual(set(self.colony.plan().source_rates), {"surface"})
        self.colony.advance(10)
        self.assertGreater(self.colony.food, 0)
        self.assertEqual(self.colony.sources[0].remaining, 600)

    def test_actual_dig_connects_finite_source(self):
        connect_cookie(self.colony)
        self.assertEqual(set(self.colony.plan().source_rates), {"cookie"})
        before = self.colony.sources[0].remaining
        self.colony.advance(10)
        self.assertLess(self.colony.sources[0].remaining, before)

    def test_full_storage_does_not_deplete_source(self):
        connect_cookie(self.colony)
        self.colony.hatching = False
        self.colony.food = self.colony.capacity
        self.colony.advance(120)
        self.assertEqual(self.colony.sources[0].remaining, 600)
        self.assertEqual(self.colony.hauled, 0)

    def test_partial_storage_only_deducts_credited_food(self):
        connect_cookie(self.colony)
        self.colony.hatching = False
        self.colony.food = self.colony.capacity - 0.5
        self.colony.harvest(60, 1)
        self.assertEqual(self.colony.food, self.colony.capacity)
        self.assertEqual(self.colony.sources[0].remaining, 599.5)
        self.assertEqual(self.colony.hauled, 0.5)

    def test_source_cannot_go_negative(self):
        connect_cookie(self.colony)
        self.colony.hatching = False
        self.colony.sources[0].remaining = 0.125
        self.colony.harvest(60, 1)
        self.assertEqual(self.colony.food, 0.125)
        self.assertEqual(self.colony.sources[0].remaining, 0)

    def test_repeated_refill_after_all_legal_soil_is_dug(self):
        excavate_all(self.colony)
        self.colony.hatching = False
        original_walkable = self.colony.walkable.copy()
        for expected_id, expected_amount in [("sugar", 150), ("cookie", 600), ("sugar", 150)]:
            self.colony.sources[0].remaining = self.colony.sources[1].remaining = 0
            self.colony.advance(60)
            source = next(s for s in self.colony.sources if s.id == expected_id)
            self.assertEqual(source.remaining, expected_amount)
            self.assertEqual(self.colony.walkable, original_walkable)
        self.assertEqual(self.colony.refills, 3)

    def test_unconnected_refill_remains_available(self):
        self.colony.sources[0].remaining = 0
        self.colony.advance(120)
        self.assertEqual(self.colony.sources[1].remaining, 150)
        self.assertEqual(set(self.colony.plan().source_rates), {"surface"})

    def test_pantry_cost_movement_and_route_gain(self):
        connect_cookie(self.colony)
        for p in [(1, 4), (1, 5), (2, 3), (1, 3), (2, 2), (1, 2)]:
            self.colony.dig(p)
        self.colony.ants = 7
        self.colony.food = 80
        self.colony.place_pantry((1, 2))
        before = self.colony.plan().rate
        self.assertEqual(self.colony.food, 30)
        self.assertEqual(self.colony.capacity, 1100)
        self.colony.place_pantry((1, 4))
        self.assertGreater(self.colony.plan().rate, before)
        self.assertEqual(self.colony.food, 30)
        self.assertEqual(self.colony.spent, 50)
        self.assertTrue({(1, 3), (2, 3)} <= self.colony.walkable)

    def test_reject_illegal_dig(self):
        for p in [(0, 9), (4, 3), (7, 5), (0, 6), (20, 20)]:
            with self.subTest(p=p), self.assertRaises(ValueError):
                self.colony.dig(p)

    def test_reject_illegal_or_unaffordable_pantry(self):
        for p in [(0, 9), (3, 3), (4, 0)]:
            with self.subTest(p=p), self.assertRaises(ValueError):
                self.colony.place_pantry(p)
        connect_cookie(self.colony)
        self.colony.dig((1, 4))
        self.colony.dig((1, 5))
        with self.assertRaises(ValueError):
            self.colony.place_pantry((1, 4))

    def test_offline_matches_same_efficiency_online(self):
        connect_cookie(self.colony)
        other = copy.deepcopy(self.colony)
        result = self.colony.offline(240)
        other.advance(240, efficiency=0.25)
        self.assertEqual(self.colony.food, other.food)
        self.assertEqual(self.colony.ants, other.ants)
        self.assertEqual(self.colony.larvae, other.larvae)
        self.assertEqual(self.colony.sources, other.sources)
        self.assertAlmostEqual(result["hauled_food"], self.colony.hauled)

    def test_offline_is_not_quarter_of_full_efficiency_simulation(self):
        connect_cookie(self.colony)
        other = copy.deepcopy(self.colony)
        self.colony.offline(240)
        other.advance(240)
        # 孵化和容量是非线性的：在线完整运行结果不能事后乘 25%。
        self.assertNotAlmostEqual(self.colony.hauled, other.hauled * 0.25, places=2)

    def test_offline_cap_applies_to_all_clocks(self):
        connect_cookie(self.colony)
        other = copy.deepcopy(self.colony)
        result = self.colony.offline(7200)
        other.offline(3600)
        self.assertEqual(result["simulated_seconds"], 3600)
        self.assertEqual(self.colony.elapsed, 3600)
        self.assertEqual(self.colony.food, other.food)
        self.assertEqual(self.colony.ants, other.ants)
        self.assertEqual(self.colony.refills, other.refills)

    def test_population_slots_and_conservation(self):
        connect_cookie(self.colony)
        for _ in range(600):
            self.colony.advance(1)
            self.assertLessEqual(len(self.colony.larvae), 2)
            self.assertLessEqual(self.colony.ants + len(self.colony.larvae), 24)
            self.assertGreaterEqual(self.colony.food, 0)
            self.assertLessEqual(self.colony.food, self.colony.capacity)
            self.assertAlmostEqual(self.colony.hauled, self.colony.food + self.colony.spent)

    def test_pause_hatching_allows_saving_for_pantry(self):
        connect_cookie(self.colony)
        self.colony.hatching = False
        self.colony.advance(60)
        self.assertGreaterEqual(self.colony.food, sim.PANTRY_COST)
        self.assertEqual(self.colony.ants, 5)
        self.assertFalse(self.colony.larvae)

    def test_invalid_time_inputs(self):
        for duration in [-1, math.inf, math.nan]:
            with self.subTest(duration=duration), self.assertRaises(ValueError):
                self.colony.offline(duration)
        for duration, efficiency in [(-1, 1), (math.inf, 1), (1, -1), (1, 1.1), (1, math.nan)]:
            with self.subTest(duration=duration, efficiency=efficiency), self.assertRaises(ValueError):
                self.colony.advance(duration, efficiency)

    def test_fixed_replay_resources_balance(self):
        result = sim.scripted_session()
        self.assertEqual(result, {"seconds": 600, "ants": 24, "larvae": 0,
                                 "food": 1100.0, "capacity": 1100.0, "hauled": 1530.0,
                                 "spent": 430.0, "refills": 2, "food_conservation_error": 0.0})


if __name__ == "__main__":
    unittest.main()
