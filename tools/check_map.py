"""检查当前验证版地图与正式版章节清单；旧四地层地图仅存档。失败返回非零退出码。"""
from collections import Counter, deque
import json
from pathlib import Path
import sys

MAP = Path(__file__).resolve().parents[1] / "design/map_prototype.txt"
CHAPTERS = Path(__file__).resolve().parents[1] / "design/chapters.json"
ENTRANCE = (4, 0)


def flood(cells, start=ENTRANCE):
    seen, queue = {start}, deque([start])
    while queue:
        x, y = queue.popleft()
        for p in ((x, y - 1), (x - 1, y), (x + 1, y), (x, y + 1)):
            if p in cells and p not in seen:
                seen.add(p)
                queue.append(p)
    return seen


def validate(grid):
    if len(grid) != 10 or any(len(row) != 9 for row in grid):
        return ["size must be 9 columns x 10 rows"]
    errors = []
    tiles = {(x, y): ch for y, row in enumerate(grid) for x, ch in enumerate(row)}
    unknown = set(tiles.values()) - set("~E.#QCSRX")
    if unknown:
        errors.append(f"unknown symbols: {sorted(unknown)}")
    if grid[0] != "~~~~E~~~~" or any(ch in "~E" for row in grid[1:] for ch in row):
        errors.append("invalid surface/entrance")
    for symbol, (width, height) in {"Q": (3, 2), "C": (2, 2), "S": (1, 1), "R": (1, 1)}.items():
        cells = {p for p, ch in tiles.items() if ch == symbol}
        if not cells:
            errors.append(f"missing {symbol}")
            continue
        x, y = min(p[0] for p in cells), min(p[1] for p in cells)
        expected = {(x + dx, y + dy) for dx in range(width) for dy in range(height)}
        if cells != expected:
            errors.append(f"invalid {symbol} footprint")
    initial = {p for p, ch in tiles.items() if ch in ".QE"}
    if not initial <= flood(initial):
        errors.append("initial tunnels/Queen are disconnected")
    potential = {p for p, ch in tiles.items() if ch in "#.QE"}
    seen = flood(potential)
    if seen != potential:
        errors.append("some legal soil cannot be reached by digging")
    for symbol in "CSR":
        cells = {p for p, ch in tiles.items() if ch == symbol}
        if not any((x + dx, y + dy) in seen for x, y in cells
                   for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1))):
            errors.append(f"source {symbol} has no reachable loading edge")
    room_cells = {p for p in potential if tiles[p] in "#."}
    if not any({(x + dx, y + dy) for dx in (0, 1) for dy in (0, 1)} <= room_cells
               for x, y in room_cells):
        errors.append("no legal 2 x 2 Pantry space")
    return errors


def validate_chapters(path=None):
    """design/chapters.json：ID 唯一；第一章是核心地图；ready 的章节必须有通过同样检查的地图；
    未交付地图（map 为 null）不能标 ready，也不能用已有地图冒充（地图文本两两不同）。"""
    path = path or CHAPTERS
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
        entries = manifest["chapters"]
    except (OSError, ValueError, KeyError, TypeError) as error:
        return [f"chapters manifest unreadable: {error}"]
    errors, ids, texts = [], [], {}
    for entry in entries:
        cid, file, status = entry.get("id"), entry.get("map"), entry.get("status")
        ids.append(cid)
        if file is None:
            if status == "ready":
                errors.append(f"chapter {cid} is ready without a map")
            continue
        grid_path = path.parent / file
        if not grid_path.exists():
            errors.append(f"chapter {cid} map missing: {file}")
            continue
        text = grid_path.read_text(encoding="utf-8")
        for error in validate(text.splitlines()):
            errors.append(f"chapter {cid}: {error}")
        if text in texts:
            errors.append(f"chapter {cid} reuses the map of {texts[text]}")
        texts[text] = cid
    if len(set(ids)) != len(ids):
        errors.append("duplicate chapter ids")
    if not entries or entries[0].get("id") != "backyard" or entries[0].get("map") != MAP.name:
        errors.append("first chapter must be backyard on the core map")
    return errors


def main():
    grid = MAP.read_text(encoding="utf-8").splitlines()
    errors = validate(grid) + validate_chapters()
    if errors:
        print("FAILED: " + "; ".join(errors))
        return 1
    print("OK: prototype map; dimensions, footprints, connectivity, sources, Pantry space")
    ready = [e["id"] for e in json.loads(CHAPTERS.read_text(encoding="utf-8"))["chapters"] if e.get("map")]
    print(f"OK: chapters.json; playable chapters: {', '.join(ready)}")
    print("counts:", dict(sorted(Counter("".join(grid[1:])).items())))
    return 0


if __name__ == "__main__":
    sys.exit(main())
