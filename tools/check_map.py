"""Validate design/map_backyard.txt against PRD 4.2 / 5.1 (design tool).

  python tools/check_map.py

Checks: 9 columns x 37 rows (surface + 36), 2x2 / 3x2 footprints are complete,
every non-rock tile is reachable from the entrance, the Heart Geode is reachable
without digging roots, and prints the per-symbol counts used in the PRD legend.
"""
from collections import Counter, deque
from pathlib import Path

MAP = Path(__file__).resolve().parent.parent / "design" / "map_backyard.txt"
FOOTPRINTS = {"C": (2, 2), "A": (2, 2), "B": (2, 2), "K": (2, 2), "Q": (3, 2)}
ENTRANCE = (4, 0)


def reachable(grid, blocked):
    seen, queue = {ENTRANCE}, deque([ENTRANCE])
    while queue:
        x, y = queue.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < 9 and 1 <= ny < len(grid) and (nx, ny) not in seen and grid[ny][nx] not in blocked:
                seen.add((nx, ny))
                queue.append((nx, ny))
    return seen


def main():
    grid = [r for r in MAP.read_text(encoding="utf-8").splitlines() if r]
    ok = True
    if len(grid) != 37 or {len(r) for r in grid} != {9}:
        print(f"FAIL size: {len(grid)} rows, widths {set(len(r) for r in grid)}")
        ok = False
    for ch, (w, h) in FOOTPRINTS.items():
        seen = set()
        for y, row in enumerate(grid):
            for x, c in enumerate(row):
                if c != ch or (x, y) in seen:
                    continue
                cells = [(x + dx, y + dy) for dy in range(h) for dx in range(w)]
                if not all(cx < 9 and cy < len(grid) and grid[cy][cx] == ch for cx, cy in cells):
                    print(f"FAIL footprint {ch} at ({x},{y})")
                    ok = False
                seen.update(cells)
    seen = reachable(grid, "X")
    lost = [(x, y) for y in range(1, len(grid)) for x in range(9) if grid[y][x] != "X" and (x, y) not in seen]
    if lost:
        print("FAIL unreachable:", lost)
        ok = False
    geode = next((x, y) for y, r in enumerate(grid) for x, c in enumerate(r) if c == "G")
    if geode not in reachable(grid, "Xr"):
        print("FAIL Heart Geode needs roots dug")
        ok = False
    print("counts:", dict(sorted(Counter("".join(grid[1:])).items())))
    print("OK" if ok else "FAILED")


if __name__ == "__main__":
    main()
