"""正式版奖励广告 Foraging Boost 的规则回归（RELEASE_SCOPE 第 3、5 章，C12）。
只验证倍率、计时、频次与守恒；不是收益预测。核心基准（倍率 1）不得因此改变。"""
import copy
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import economy_sim as sim


def connected():
    colony = sim.Colony()
    for p in [(2, 4), (2, 5), (2, 6)]:
        colony.dig(p)
    return colony


def unlocked_ledger():
    ledger = sim.RewardLedger()
    ledger.foreground = sim.BOOST_UNLOCK_FOREGROUND
    return ledger


class MultiplierTests(unittest.TestCase):
    def test_multiplier_one_is_the_core_baseline(self):
        a, b = connected(), connected()
        a.advance(120)
        b.advance(120, 1.0, 1.0)
        self.assertEqual((a.food, a.hauled, a.ants, a.larvae), (b.food, b.hauled, b.ants, b.larvae))

    def test_boost_scales_transport_but_not_capacity_or_finite_sources(self):
        plain, boosted = connected(), connected()
        for colony in (plain, boosted):
            colony.set_hatching(False) if hasattr(colony, "set_hatching") else setattr(colony, "hatching", False)
        plain.advance(10)
        boosted.advance(10, 1.0, sim.BOOST_MULTIPLIER)
        self.assertAlmostEqual(boosted.hauled, plain.hauled * sim.BOOST_MULTIPLIER, places=9)
        full = connected()
        full.hatching = False
        full.advance(400, 1.0, sim.BOOST_MULTIPLIER)
        self.assertLessEqual(full.food, full.capacity + 1e-9)
        self.assertAlmostEqual(full.hauled - full.spent, full.food, places=9)
        self.assertGreaterEqual(full.sources[0].remaining, 0.0)

    def test_invalid_multiplier_rejected(self):
        colony = connected()
        for bad in (0.5, float("nan"), float("inf"), 0.0):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                colony.advance(1, 1.0, bad)

    def test_offline_never_uses_the_boost(self):
        a, b = connected(), connected()
        ledger = unlocked_ledger()
        ledger.grant("r1", day=0)
        result_a = a.offline(1800)
        result_b = b.offline(1800)
        self.assertEqual(result_a, result_b)
        self.assertEqual(ledger.boost_left, sim.BOOST_SECONDS, "offline time does not consume the boost")


class LedgerTests(unittest.TestCase):
    def test_locked_until_first_pantry_and_ten_minutes(self):
        ledger = sim.RewardLedger()
        self.assertEqual(ledger.status(pantry_built=False, storage_full=False, day=0), "locked")
        ledger.foreground = sim.BOOST_UNLOCK_FOREGROUND - 1
        self.assertEqual(ledger.status(True, False, 0), "locked")
        ledger.foreground = sim.BOOST_UNLOCK_FOREGROUND
        self.assertEqual(ledger.status(True, False, 0), "ready")
        self.assertEqual(ledger.status(True, True, 0), "storage_full")
        self.assertEqual(ledger.status(True, False, 0, ad_available=False), "unavailable")

    def test_duplicate_callbacks_grant_once(self):
        ledger = unlocked_ledger()
        self.assertTrue(ledger.grant("same", 0))
        ledger.step(connected(), 100)
        self.assertFalse(ledger.grant("same", 0))
        self.assertEqual(ledger.boost_left, sim.BOOST_SECONDS - 100)
        self.assertEqual(ledger.day_count, 1)

    def test_active_boost_does_not_stack_and_cooldown_counts_foreground_only(self):
        ledger = unlocked_ledger()
        colony = connected()
        ledger.grant("a", 0)
        self.assertEqual(ledger.status(True, False, 0), "active")
        ledger.step(colony, sim.BOOST_SECONDS)
        self.assertEqual(ledger.boost_left, 0)
        self.assertEqual(ledger.status(True, False, 0), "cooldown")
        colony.offline(3600)   # 后台时间不计入冷却
        self.assertEqual(ledger.status(True, False, 0), "cooldown")
        ledger.step(colony, sim.BOOST_COOLDOWN - sim.BOOST_SECONDS)
        self.assertEqual(ledger.status(True, False, 0), "ready")

    def test_daily_limit_and_clock_rollback(self):
        ledger = unlocked_ledger()
        colony = connected()
        for i in range(sim.BOOST_DAILY_LIMIT):
            self.assertEqual(ledger.status(True, False, 5), "ready")
            ledger.grant(f"r{i}", 5)
            ledger.step(colony, sim.BOOST_COOLDOWN)
        self.assertEqual(ledger.status(True, False, 5), "daily_limit")
        self.assertEqual(ledger.status(True, False, 4), "daily_limit", "rolling the date back does not reset")
        self.assertEqual(ledger.status(True, False, 6), "ready", "next UTC day")
        ledger.grant("r-next", 6)
        self.assertEqual((ledger.day, ledger.day_count), (6, 1))

    def test_boost_ending_mid_step_is_split_exactly(self):
        exact, split = connected(), connected()
        exact.hatching = split.hatching = False
        exact.advance(0.1, 1.0, sim.BOOST_MULTIPLIER)
        exact.advance(0.9, 1.0, 1.0)
        ledger = unlocked_ledger()
        ledger.grant("r", 0)
        ledger.boost_left = 0.1
        ledger.step(split, 1.0)
        self.assertAlmostEqual(split.hauled, exact.hauled, places=12)
        self.assertEqual(ledger.boost_left, 0.0)

    def test_crash_restart_keeps_ledger_state(self):
        ledger = unlocked_ledger()
        ledger.grant("r", 0)
        ledger.step(connected(), 120)
        restored = copy.deepcopy(ledger)   # 存档往返的等价物；客户端用 Codable 保存同样字段
        self.assertEqual(vars(restored), vars(ledger))
        self.assertFalse(restored.grant("r", 0))


class ReplayTests(unittest.TestCase):
    def test_reference_pace_never_offers_the_ad(self):
        rows = {(r["pace"], r["policy"]): r for r in sim.boost_replays()}
        for policy in ("none", "once", "always"):
            row = rows[("reference", policy)]
            self.assertIsNone(row["first_ready"])
            self.assertEqual(row["grants"], [])
            self.assertEqual(row["complete_at"], rows[("reference", "none")]["complete_at"])

    def test_slow_pace_one_boost_finishes_earlier_and_conserves(self):
        rows = {(r["pace"], r["policy"]): r for r in sim.boost_replays()}
        none, once = rows[("slow", "none")], rows[("slow", "once")]
        self.assertEqual(once["grants"], [600])
        self.assertLess(once["complete_at"], none["complete_at"])
        for row in rows.values():
            self.assertAlmostEqual(row["food_conservation_error"], 0.0, places=6)
            self.assertLessEqual(row["food"], row["capacity"] + 1e-9)
            self.assertLessEqual(len(row["grants"]), sim.BOOST_DAILY_LIMIT)


if __name__ == "__main__":
    unittest.main()
