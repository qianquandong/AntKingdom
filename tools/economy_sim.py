"""Crumb Kingdom (一厘米蚂蚁王国) - MVP economy check (design tool, not game code).

Re-computes the numbers in docs/PRD.md section 6 from the same initial design values.
  python tools/economy_sim.py                 # reference growth path (engaged, good layout)
  python tools/economy_sim.py --tables        # PRD 6.3 tables
  python tools/economy_sim.py --check         # storage-vs-cost deadlock check (PRD 6.5)
  options: --layout poor | --casual | --ads | --crew 3 | --days N | --log

Model (matches PRD section 4/6):
- Hauling is route-level: each source has a route length L (tiles), a hauler
  cap, optional extra off-screen time. Trip time T = 2L / (v * m) + load + unload + extra,
  m = congestion multiplier = min(1, TILE_CAP * L / n), floored at 0.25.
- Haulers fill sources in order of shortest single-ant trip time.
- Queen lays an egg whenever a larva slot is free, food >= larva cost and
  adults + larvae < population cap. Larvae hatch after hatch_time.
- Rooms cost food up front and take a build crew for build time.
- Offline: same rules at OFFLINE_EFF hauling, no purchases, economy runs only up to
  the offline cap; build timers use wall clock.
"""
import argparse
import math

# ---------------- initial design values (keep in sync with PRD section 6) -------------
def nice(x):
    """round to 2 significant figures (used for every cost/capacity table)."""
    if x < 100:
        return int(round(x))
    p = 10 ** (len(str(int(x))) - 2)
    return int(round(x / p) * p)


def geo(base, g, n_from, n_to):
    """[cost to reach level n] for n in n_from..n_to: base * g^(n - n_from)."""
    return [nice(base * g ** (n - n_from)) for n in range(n_from, n_to + 1)]


SPEED = [2.0, 2.2, 2.4, 2.6, 2.8, 3.0, 3.2, 3.4, 3.6, 3.8]             # tiles/s, 2.0 * (1 + 0.1 (lv-1))
CARRY = [2, 3, 4, 5, 6, 7, 8, 9, 10, 12]                                # food/trip
DIG = [1, 2, 3, 4, 5, 7, 9, 11, 13, 15]                                 # damage/tap
G = 3.6                                     # shared growth per level
CARRY_COST = [0] + geo(100, G, 2, 10)       # index = current level -> cost of next level
SPEED_COST = [0] + geo(150, G, 2, 10)
DIG_COST = [0] + geo(80, G, 2, 10)
QUEEN_COST = [0] + geo(200, G, 2, 10)       # QUEEN_COST[q] = cost to go from Q(q) to Q(q+1)
QUEEN_TIME = [0, 0, 120, 900, 2 * 3600, 4 * 3600, 6 * 3600, 8 * 3600, 12 * 3600, 16 * 3600]  # [q] = Q(q)->Q(q+1)
QUEEN_REQ_ANTS = [0, 10, 18, 30, 45, 60, 80, 100, 125, 150]
# Depth/treasure milestones are approximated by a minimum of active play minutes
# (digging to the layer + finding treasures). See PRD 6.4.
QUEEN_REQ_ACTIVE_MIN = [0, 0, 12, 18, 26, 40, 60, 80, 110, 140]

PANTRY_CAP = geo(1000, 6, 1, 5)
DEN_CAP = [10, 15, 20, 25, 30]
NURSERY_SLOTS = [3, 4, 5, 6, 8]
RG = 8                                      # room growth per step
PANTRY_BUILD = geo(50, RG, 1, 5)            # n-th pantry
DEN_BUILD = geo(30, RG, 1, 6)
NURSERY_BUILD = geo(40, 10, 1, 3)
PANTRY_UP = [0] + geo(300, RG, 2, 5)        # index = current level -> cost of next level
DEN_UP = [0] + geo(200, RG, 2, 5)
NURSERY_UP = [0] + geo(200, RG, 2, 5)

MAX_COUNT = {  # index = queen level - 1
    "pantry": [1, 1, 2, 2, 3, 3, 4, 4, 5, 5],
    "den": [1, 2, 2, 3, 3, 4, 4, 5, 5, 6],
    "nursery": [1, 1, 1, 2, 2, 2, 3, 3, 3, 3],
}
BUILD_TIME_NTH = [10, 120, 1200, 3600, 3 * 3600, 6 * 3600]   # seconds, n-th room of a type
UPGRADE_TIME = [0, 60, 900, 3600, 3 * 3600]                  # index = current level

QUEEN_STORE = 100
BASE_POP = 10
QUEEN_SLOTS = 2
START_ANTS = 5
LOAD, UNLOAD = 2.0, 1.0
TILE_CAP = 4
OFFLINE_EFF = 0.25
OFFLINE_CAP_H = [2, 2, 2, 2, 3, 3, 3, 4, 4, 4]
GOLDEN_BONUS_ACTIVE = 0.12      # Golden Crumb: 20 s of income every ~120 s, 70% tapped -> +11.7%
# Treasure bonuses, applied from the queen level by which the reference player has found them:
# Bottle Cap  Q2 pantry +10% | Lost Button Q4 speed +5% | Tin Soldier Q4 Golden Crumb +50%
# Glass Marble Q6 hatch -10% | Old Coin Q8 offline x1.2 | Amber Drop Q8 carry +10%
TREASURE_FROM = {"pantry": 2, "speed": 4, "golden": 4, "hatch": 6, "offline": 8, "carry": 8}
DOUBLE_IT_PER_DAY = 3
# Scripted tutorial (PRD 3): earliest second at which each action is offered in session 1.
TUTORIAL_UNLOCK_S = {"pantry": 150, "nursery": 210, "den": 300, "queen": 510, "upgrades": 540}
NURSE_PER_LARVAE = 3
BUILDERS_PER_CREW = 2
DIGGERS_FROM_Q3 = 2
DROP_EVERY_S = 30 * 60
DROP_AMOUNT = [nice(300 * 2 ** (q - 1)) for q in range(1, 11)]   # Falling Treat size by queen level


def room_max_level(q):
    return min(5, 1 + q // 2)


def larva_cost(adults):
    return 10 + round(0.4 * adults)


def hatch_time(adults, q):
    return 45 * (1 + adults / 20) * (1 - 0.04 * (q - 1))


# Sources on map 1 "Backyard" with a reasonable (good) layout.
# (name, queen level when the player typically connects it, L, hauler cap, amount or None, extra s)
SOURCES = [
    ("Surface Forage", 1, 2, 10, None, 12),
    ("Giant Cookie", 1, 3, 8, 600, 0),
    ("Sugar Cube r2", 1, 3, 4, 150, 0),
    ("Seed Piles x3", 1, 5, 3, 180, 0),
    ("Sap Root (topsoil)", 1, 5, 8, None, 0),
    ("Sugar Cube r9", 2, 6, 4, 150, 0),
    ("Apple Core", 2, 5, 10, 1500, 0),
    ("Sap Root (clay) A", 2, 6, 12, None, 0),
    ("Sap Root (clay) B", 3, 6, 12, None, 0),
    ("Sugar Cubes clay x2", 3, 6, 8, 300, 0),
    ("Bread Crust A", 5, 6, 10, 4000, 0),
    ("Sap Root (gravel) A", 5, 7, 20, None, 0),
    ("Sap Root (gravel) B", 6, 7, 20, None, 0),
    ("Bread Crust B", 6, 7, 10, 4000, 0),
    ("Sap Root (gravel) C", 6, 8, 20, None, 0),
    ("Candy Bar A", 7, 7, 12, 12000, 0),
    ("Sap Root (deep) A", 7, 8, 36, None, 0),
    ("Candy Bar B", 8, 8, 12, 12000, 0),
    ("Sap Root (deep) B", 8, 9, 36, None, 0),
]


class Sim:
    def __init__(self, layout="good", crews_iap=False, ads=False, verbose=False):
        self.lmul = 1.0 if layout == "good" else 1.5
        self.crews_iap = crews_iap
        self.ads = ads
        self.verbose = verbose
        self.t = 0.0
        self.food = 0.0
        self.adults = START_ANTS
        self.larvae = []                # remaining seconds, larvae in Queen's Chamber first
        self.q = 1
        self.lv = {"speed": 1, "carry": 1, "dig": 1}
        self.rooms = {"pantry": [], "den": [], "nursery": []}  # list of levels (built)
        self.builds = []                # [finish_time, kind, idx or None (new), level]
        self.queen_done = None          # finish time of Royal Growth
        self.sources = []
        self.connected = set()
        self.drop_next = DROP_EVERY_S
        self.active_s = 0.0
        self.ads_used = {}
        self.log = []
        self.offline_lost = 0.0
        self.offline_total = 0.0
        self.idle_peak = 0
        self.spent = {}
        self.refresh_sources()

    # ---------- derived ----------
    def has(self, t):
        return self.q >= TREASURE_FROM[t]

    def store_cap(self):
        mult = 1.1 if self.has("pantry") else 1.0
        return QUEEN_STORE + int(sum(PANTRY_CAP[l - 1] for l in self.rooms["pantry"]) * mult)

    def pop_cap(self):
        return BASE_POP + sum(DEN_CAP[l - 1] for l in self.rooms["den"])

    def larva_slots(self):
        return QUEEN_SLOTS + sum(NURSERY_SLOTS[l - 1] for l in self.rooms["nursery"])

    def crews(self):
        return 1 + (1 if self.q >= 4 else 0) + (1 if self.crews_iap else 0)

    def refresh_sources(self):
        for s in SOURCES:
            if s[0] not in self.connected and s[1] <= self.q:
                self.connected.add(s[0])
                self.sources.append({"name": s[0], "L": s[2] * self.lmul, "cap": s[3],
                                     "left": s[4], "extra": s[5]})

    def haul_rate(self):
        """food per second from current assignment."""
        nurses = math.ceil(max(0, len(self.larvae) - QUEEN_SLOTS) / NURSE_PER_LARVAE)
        builders = BUILDERS_PER_CREW * len(self.builds)
        diggers = DIGGERS_FROM_Q3 if self.q >= 3 else 0
        haulers = max(0, self.adults - nurses - builders - diggers)
        v = SPEED[self.lv["speed"] - 1] * (1.05 if self.has("speed") else 1.0)
        c = CARRY[self.lv["carry"] - 1] * (1.1 if self.has("carry") else 1.0)
        live = [s for s in self.sources if s["left"] is None or s["left"] > 0]
        live.sort(key=lambda s: 2 * s["L"] / v + s["extra"])
        rate, per = 0.0, []
        for s in live:
            n = min(s["cap"], haulers)
            haulers -= n
            if n <= 0:
                per.append((s, 0.0))
                continue
            m = max(0.25, min(1.0, TILE_CAP * s["L"] / n))
            trip = 2 * s["L"] / (v * m) + LOAD + UNLOAD + s["extra"]
            r = n * c / trip
            per.append((s, r))
            rate += r
        self.idle_peak = max(self.idle_peak, haulers)
        return rate, per, haulers

    # ---------- simulation step ----------
    def step(self, dt, online, eff=1.0):
        # builds (wall clock handled by caller for offline)
        self.finish_builds()
        rate, per, idle = self.haul_rate()
        golden = GOLDEN_BONUS_ACTIVE * (1.5 if self.has("golden") else 1.0)
        mult = (1 + golden) if online else eff * (1.2 if self.has("offline") else 1.0)
        cap = self.store_cap()
        for s, r in per:
            got = r * mult * dt
            if s["left"] is not None:
                got = min(got, s["left"])
                s["left"] -= got
            room = cap - self.food
            if got > room:
                if not online:
                    self.offline_lost += got - room
                got = max(0.0, room)
            if not online:
                self.offline_total += got
            self.food += got
        # larvae
        self.larvae = [x - dt for x in self.larvae]
        hatched = sum(1 for x in self.larvae if x <= 0)
        self.larvae = [x for x in self.larvae if x > 0]
        self.adults += hatched
        while (len(self.larvae) < self.larva_slots()
               and self.adults + len(self.larvae) < self.pop_cap()
               and self.food >= larva_cost(self.adults)):
            self.food -= larva_cost(self.adults)
            self.spend("larvae", larva_cost(self.adults))
            self.larvae.append(hatch_time(self.adults, self.q) * (0.9 if self.has("hatch") else 1.0))
        self.t += dt

    def finish_builds(self):
        if self.queen_done is not None and self.queen_done <= self.t:
            self.queen_done = None
            self.q += 1
            self.note(f"QUEEN -> Q{self.q}")
            self.refresh_sources()
        done = [b for b in self.builds if b[0] <= self.t]
        for b in done:
            _, kind, idx, level = b
            if idx is None:
                self.rooms[kind].append(1)
            else:
                self.rooms[kind][idx] = level
        self.builds = [b for b in self.builds if b[0] > self.t]

    def spend(self, k, v):
        self.spent[k] = self.spent.get(k, 0) + v

    # ---------- player policy (active only) ----------
    def room_actions(self, kind):
        """possible actions for a room type: (cost, label, fn)."""
        acts = []
        busy = {(b[1], b[2]) for b in self.builds}
        n_built = len(self.rooms[kind]) + sum(1 for b in self.builds if b[1] == kind and b[2] is None)
        tables = {"pantry": (PANTRY_BUILD, PANTRY_UP), "den": (DEN_BUILD, DEN_UP),
                  "nursery": (NURSERY_BUILD, NURSERY_UP)}
        build, up = tables[kind]
        if self.t < TUTORIAL_UNLOCK_S[kind]:
            return acts
        if n_built < MAX_COUNT[kind][self.q - 1]:
            cost = build[n_built]
            acts.append((cost, f"build {kind} #{n_built + 1}", (kind, None, 1, BUILD_TIME_NTH[n_built])))
        for i, l in enumerate(self.rooms[kind]):
            if l < room_max_level(self.q) and (kind, i) not in busy:
                acts.append((up[l], f"upgrade {kind} #{i + 1} to Lv{l + 1}", (kind, i, l + 1, UPGRADE_TIME[l])))
        acts.sort(key=lambda a: a[0])
        return acts

    def do_room(self, act):
        cost, label, (kind, idx, level, bt) = act
        self.food -= cost
        self.spend("rooms", cost)
        self.builds.append([self.t + bt, kind, idx, level])
        self.note(label)

    def queen_ready(self):
        return (self.q < 10 and self.queen_done is None and self.adults >= QUEEN_REQ_ANTS[self.q]
                and self.active_s >= QUEEN_REQ_ACTIVE_MIN[self.q] * 60)

    def act(self):
        for _ in range(6):
            if not self.act_once():
                break

    def act_once(self):
        qcost = QUEEN_COST[self.q] if self.q < 10 else None
        if self.queen_ready() and self.food >= qcost and self.t >= TUTORIAL_UNLOCK_S["queen"]:
            self.food -= qcost
            self.spend("queen", qcost)
            self.queen_done = self.t + QUEEN_TIME[self.q]
            self.note(f"Royal Growth to Q{self.q + 1} started")
            self.finish_builds()
            return True
        free_crew = len(self.builds) < self.crews()
        saving = self.queen_ready() and qcost is not None and qcost <= self.store_cap()
        budget = self.food if not saving else max(0.0, self.food - qcost)
        if free_crew:
            # storage first when the next queen cost does not fit
            if qcost is not None and self.store_cap() < qcost * 1.1:
                for a in self.room_actions("pantry"):
                    if a[0] <= self.food:
                        self.do_room(a)
                        return True
                    break
            if self.adults + len(self.larvae) >= self.pop_cap() - 2:
                for a in self.room_actions("den"):
                    if a[0] <= budget:
                        self.do_room(a)
                        return True
                    break
            for kind in ("nursery", "den", "pantry"):
                for a in self.room_actions(kind):
                    if a[0] <= budget * 0.5:
                        self.do_room(a)
                        return True
                    break
        # colony upgrades: cheapest first, capped at queen level
        opts = []
        if self.t < TUTORIAL_UNLOCK_S["upgrades"]:
            return False
        for k, table in (("carry", CARRY_COST), ("speed", SPEED_COST), ("dig", DIG_COST)):
            l = self.lv[k]
            if l < 10 and l < self.q:
                opts.append((table[l], k))
        opts.sort()
        for cost, k in opts:
            if cost <= budget:
                self.food -= cost
                self.spend("upgrades", cost)
                self.lv[k] += 1
                self.note(f"{k} -> Lv{self.lv[k]}")
                return True
            break
        return False

    def note(self, msg):
        if self.verbose:
            self.log.append(f"{fmt_t(self.t)}  {msg}")

    # ---------- drivers ----------
    def online(self, seconds):
        end = self.t + seconds
        while self.t < end:
            if self.t >= self.drop_next:
                self.drop_next += DROP_EVERY_S
                self.add_drop()
            self.act()
            self.step(1.0, True)
            self.active_s += 1

    def offline(self, seconds):
        cap = OFFLINE_CAP_H[self.q - 1] * 3600
        sim_s = min(seconds, cap)
        start_food = self.food
        start = self.t
        self.offline_total = 0.0
        self.offline_lost = 0.0
        step = 10.0
        while self.t < start + sim_s:
            self.step(step, False, OFFLINE_EFF)
        # beyond cap: only wall-clock build timers advance
        self.t = start + seconds
        self.finish_builds()
        pending = False
        while self.drop_next <= self.t:      # at most one pending drop is kept
            self.drop_next += DROP_EVERY_S
            pending = True
        gained = self.food - start_food
        day = int(self.t // 86400)
        used = self.ads_used.get(day, 0)
        if self.ads and gained > 0 and seconds >= 600 and used < DOUBLE_IT_PER_DAY:
            self.ads_used[day] = used + 1
            bonus = min(self.offline_total, self.store_cap() - self.food)
            self.food += max(0.0, bonus)
        if pending:
            self.add_drop()
        return gained

    def add_drop(self):
        self.sources.append({"name": f"Falling Treat Q{self.q}", "L": 7 * self.lmul, "cap": 12,
                             "left": DROP_AMOUNT[self.q - 1], "extra": 0})


def check_caps():
    """Deadlock check: every cost unlocked at queen level q must fit in the max storage
    reachable at q (all allowed pantries at the max allowed level, no treasure bonus)."""
    problems = []
    for q in range(1, 11):
        store = QUEEN_STORE + MAX_COUNT["pantry"][q - 1] * PANTRY_CAP[room_max_level(q) - 1]
        costs = []
        if q < 10:
            costs.append(("Queen to Q%d" % (q + 1), QUEEN_COST[q]))
        for name, table in (("Carry", CARRY_COST), ("Speed", SPEED_COST), ("Dig", DIG_COST)):
            if q >= 2:
                costs.append((f"{name} Lv{q}", table[q - 1]))
        for kind, build, up in (("Pantry", PANTRY_BUILD, PANTRY_UP), ("Den", DEN_BUILD, DEN_UP),
                                ("Nursery", NURSERY_BUILD, NURSERY_UP)):
            n = MAX_COUNT[kind.lower()][q - 1]
            costs.append((f"{kind} #{n}", build[n - 1]))
            ml = room_max_level(q)
            if ml >= 2:
                costs.append((f"{kind} Lv{ml}", up[ml - 1]))
        worst = max(costs, key=lambda c: c[1])
        ok = worst[1] <= store
        problems.append((q, store, worst, ok))
    return problems


def trip(L, v, c, extra=0.0):
    t = 2 * L / v + LOAD + UNLOAD + extra
    return t, c / t


def print_tables():
    print("Lv | Carry | cost | Speed | cost | Dig | cost | needs Queen")
    for i in range(10):
        print(f"{i + 1:>2} | {CARRY[i]:>5} | {CARRY_COST[i]:>9,} | {SPEED[i]:.1f} | {SPEED_COST[i]:>9,} | "
              f"{DIG[i]:>3} | {DIG_COST[i]:>9,} | Q{i + 1}")
    print("\nQueen | cost to next | ants | royal growth s | offline cap h | max pantry/den/nursery | room max lv")
    for q in range(1, 11):
        print(f"Q{q:<2} | {QUEEN_COST[q] if q < 10 else '-':>10} | {QUEEN_REQ_ANTS[q] if q < 10 else '-':>4} | "
              f"{QUEEN_TIME[q] if q < 10 else '-':>6} | {OFFLINE_CAP_H[q - 1]} | "
              f"{MAX_COUNT['pantry'][q - 1]}/{MAX_COUNT['den'][q - 1]}/{MAX_COUNT['nursery'][q - 1]} | {room_max_level(q)}")
    print("\nRoom tables")
    print("pantry cap", PANTRY_CAP, "build", PANTRY_BUILD, "up", PANTRY_UP[1:])
    print("den cap", DEN_CAP, "build", DEN_BUILD, "up", DEN_UP[1:])
    print("nursery slots", NURSERY_SLOTS, "build", NURSERY_BUILD, "up", NURSERY_UP[1:])
    print("build time nth", BUILD_TIME_NTH, "upgrade time", UPGRADE_TIME[1:])
    print("\nants | larva cost | hatch s (Q1) | hatch s (Q5) | hatch s (Q10)")
    for a in (5, 10, 20, 40, 60, 100, 150, 190):
        print(f"{a:>4} | {larva_cost(a):>3} | {hatch_time(a, 1):6.0f} | {hatch_time(a, 5):6.0f} | {hatch_time(a, 10):6.0f}")
    print("\nhaul: L | lv | trip s | food/s per ant")
    for L in (3, 6, 10):
        for lv in (1, 3, 5, 7, 10):
            t, r = trip(L, SPEED[lv - 1], CARRY[lv - 1])
            print(f"L={L:<2} | Lv{lv:<2} | {t:5.2f} | {r:.3f}")
    print("drop", DROP_AMOUNT)


START_HOUR = 9   # first launch at D1 09:00 local (PRD 6.4)


def fmt_t(t):
    """local clock label, e.g. D8 14:00, assuming first launch at D1 09:00."""
    t = t + START_HOUR * 3600
    d = int(t // 86400)
    h = int(t % 86400 // 3600)
    m = int(t % 3600 // 60)
    return f"D{d + 1} {h:02d}:{m:02d}"


def schedule(days, casual=False):
    """list of (kind, seconds). t=0 is D1 09:00.
    engaged: D1 tutorial 10 min + 4 x 4 min; D2+ 5 x 4 min at 08:00, 11:00, 14:00, 18:00, 22:00.
    casual:  D1 tutorial 10 min + 2 x 4 min; D2+ 3 x 4 min at 08:00, 13:00, 21:00."""
    plan = []
    t = 0
    if casual:
        d1 = [(0, 600), (4 * 3600, 240), (12 * 3600, 240)]
        later = [(23 * 3600, 240), (28 * 3600, 240), (36 * 3600, 240)]
    else:
        d1 = [(0, 600), (2 * 3600, 240), (4.5 * 3600, 240), (8 * 3600, 240), (12 * 3600, 240)]
        later = [(23 * 3600, 240), (26 * 3600, 240), (29 * 3600, 240), (33 * 3600, 240), (37 * 3600, 240)]
    sessions = list(d1)
    for d in range(days - 1):
        sessions += [(s + d * 86400, l) for s, l in later]
    for start, length in sessions:
        if start > t:
            plan.append(("off", start - t))
            t = start
        plan.append(("on", length))
        t += length
    return plan


def run(layout="good", crews_iap=False, ads=False, days=16, verbose=False, casual=False):
    sim = Sim(layout, crews_iap, ads, verbose)
    active = 0
    rows = []
    last_q = 1
    for kind, sec in schedule(days, casual):
        if kind == "on":
            sim.online(sec)
            active += sec
        else:
            sim.offline(sec)
        if sim.q != last_q:
            rate, _, idle = sim.haul_rate()
            rows.append((sim.q, fmt_t(sim.t), active / 60, sim.adults, rate, sim.store_cap(),
                         dict(sim.lv), idle))
            last_q = sim.q
    return sim, rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--layout", default="good", choices=["good", "poor"])
    ap.add_argument("--crew", type=int, default=2, help="3 = with Extra Build Crew IAP")
    ap.add_argument("--ads", action="store_true", help="watch Double It after every return")
    ap.add_argument("--days", type=int, default=16)
    ap.add_argument("--log", action="store_true")
    ap.add_argument("--casual", action="store_true", help="3 sessions/day instead of 5")
    ap.add_argument("--check", action="store_true", help="print storage-vs-cost deadlock check")
    ap.add_argument("--tables", action="store_true", help="print the PRD section 6 tables")
    a = ap.parse_args()
    if a.tables:
        print_tables()
        return
    if a.check:
        for q, store, worst, ok in check_caps():
            print(f"Q{q:<2} max storage {store:>9,} | biggest cost {worst[0]:<14} {worst[1]:>9,} "
                  f"| {worst[1] / store:5.0%} {'OK' if ok else 'DEADLOCK'}")
        return
    sim, rows = run(a.layout, a.crew >= 3, a.ads, a.days, a.log, a.casual)
    if a.log:
        print("\n".join(sim.log))
    print(f"layout={a.layout} crew_iap={a.crew >= 3} ads={a.ads} casual={a.casual}")
    print("Q  | reached (local) | active min | ants | food/s | storage | carry/speed/dig | idle")
    for q, when, act, ants, rate, cap, lv, idle in rows:
        print(f"Q{q:<2}| {when} | {act:10.1f} | {ants:4d} | {rate:6.1f} | {cap:7d} | "
              f"{lv['carry']}/{lv['speed']}/{lv['dig']} | {idle}")
    print("spent:", {k: round(v) for k, v in sim.spent.items()})
    print("final:", fmt_t(sim.t), "Q", sim.q, "ants", sim.adults, "food", round(sim.food),
          "rooms", sim.rooms, "idle peak", sim.idle_peak)


if __name__ == "__main__":
    main()
