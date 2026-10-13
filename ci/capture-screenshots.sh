#!/usr/bin/env bash
# 在已启动（或可启动）的模拟器上安装 Debug 构建并按场景截图。用法：
#   ci/capture-screenshots.sh <UDID> <App 路径> <输出目录> <名称> [启动参数...]
# 每个 simctl 调用都有超时，避免 CI 卡死；截图只证明模拟器上的界面状态，不代表真机。
set -euo pipefail
udid="$1"; app="$2"; outdir="$3"; name="$4"; shift 4
bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist")
mkdir -p "$outdir"

# 用法：with_timeout 秒数 命令...；超时返回 124
with_timeout() {
  local seconds="$1"; shift
  "$@" & local pid=$!
  ( sleep "$seconds"; kill -9 "$pid" 2>/dev/null ) & local watchdog=$!
  local status=0
  wait "$pid" || status=$?
  kill "$watchdog" 2>/dev/null || true
  wait "$watchdog" 2>/dev/null || true
  [ $status -eq 137 ] && return 124
  return $status
}

log() { echo "[$(date -u +%H:%M:%S)] $*"; }

if ! xcrun simctl list devices | grep -q "$udid) (Booted)"; then
  log "boot $udid"
  with_timeout 300 xcrun simctl boot "$udid" || true
fi
# 只看到 Booted 不够：系统服务未就绪时 simctl launch 会一直卡住（CI 曾卡满 240 秒）。
# bootstatus -b 等到启动真正完成（必要时顺带启动）。
log "bootstatus"
with_timeout 300 xcrun simctl bootstatus "$udid" -b >/dev/null || log "bootstatus timed out; continuing"
with_timeout 90 xcrun simctl status_bar "$udid" override --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3 2>/dev/null || log "status_bar override skipped"
log "install"
with_timeout 300 xcrun simctl install "$udid" "$app"
with_timeout 30 xcrun simctl terminate "$udid" "$bundle_id" 2>/dev/null || true
log "launch $*"
if ! with_timeout 120 xcrun simctl launch "$udid" "$bundle_id" "$@" >/dev/null; then
  log "launch timed out; terminate and retry once"
  with_timeout 30 xcrun simctl terminate "$udid" "$bundle_id" 2>/dev/null || true
  with_timeout 180 xcrun simctl launch "$udid" "$bundle_id" "$@" >/dev/null
fi
sleep "${SCREENSHOT_DELAY:-6}"
with_timeout 120 xcrun simctl io "$udid" screenshot "$outdir/$name.png" >/dev/null
log "screenshot: $outdir/$name.png"
