"""从 `xcrun simctl list devices available -j` 中挑一台 iPhone 模拟器并打印 UDID。

用法：python3 ci/pick_simulator.py [small|standard]
  standard：最新 iOS 运行时上的非 Pro/Plus/Max 标准机型（约 393×852pt）。
  small：优先 iPhone SE（375×667pt 级）；没有则退回 standard 并在 stderr 说明。
不假定 runner 装了某个具体机型；实际选择写入环境记录。
"""
import json
import re
import subprocess
import sys


def runtime_version(key):
    match = re.search(r"iOS-(\d+)-(\d+)", key)
    return (int(match.group(1)), int(match.group(2))) if match else (0, 0)


def main():
    kind = sys.argv[1] if len(sys.argv) > 1 else "standard"
    data = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"]))
    phones = []
    for runtime, devices in data["devices"].items():
        if "iOS" not in runtime:
            continue
        for device in devices:
            if device.get("isAvailable", True) and device["name"].startswith("iPhone"):
                phones.append((runtime_version(runtime), device["name"], device["udid"], runtime))
    if not phones:
        sys.exit("no available iPhone simulator")
    phones.sort(key=lambda row: row[0])
    newest = phones[-1][0]
    current = [p for p in phones if p[0] == newest]
    chosen = None
    if kind == "small":
        chosen = next((p for p in current if "SE" in p[1]), None) or next((p for p in phones if "SE" in p[1]), None)
        if chosen is None:
            print("no iPhone SE simulator; falling back to standard", file=sys.stderr)
    if chosen is None:
        plain = [p for p in current if not re.search(r"Pro|Plus|Max|Air|SE|mini|e$", p[1])]
        chosen = (plain or current)[0]
    print(f"{chosen[1]} | {chosen[3]}", file=sys.stderr)
    print(chosen[2])


if __name__ == "__main__":
    main()
