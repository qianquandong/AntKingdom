#!/usr/bin/env bash
# 在指定模拟器上安装 Debug 构建并截图。用法：
#   ci/capture-screenshots.sh <UDID> <App 路径> <输出目录> <名称> [启动参数...]
# 截图来自模拟器，只能证明界面状态，不代表真机效果。
set -euo pipefail
udid="$1"; app="$2"; outdir="$3"; name="$4"; shift 4
bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist")
mkdir -p "$outdir"
xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b >/dev/null
# 统一状态栏，便于对比截图
xcrun simctl status_bar "$udid" override --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3 2>/dev/null || true
xcrun simctl install "$udid" "$app"
xcrun simctl terminate "$udid" "$bundle_id" 2>/dev/null || true
xcrun simctl launch "$udid" "$bundle_id" "$@" >/dev/null
sleep "${SCREENSHOT_DELAY:-6}"
xcrun simctl io "$udid" screenshot "$outdir/$name.png" >/dev/null
echo "screenshot: $outdir/$name.png"
