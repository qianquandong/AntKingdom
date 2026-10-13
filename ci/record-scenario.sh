#!/usr/bin/env bash
# 录一段调试场景的模拟器视频：启动 App（带启动参数），录制指定秒数后结束。
# 用法：bash ci/record-scenario.sh <udid> <App 路径> <输出 .mov> <秒数> [启动参数...]
set -uo pipefail
udid="$1"; app="$2"; out="$3"; seconds="$4"; shift 4
bundle="com.example.CrumbKingdom"
mkdir -p "$(dirname "$out")"
xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b
xcrun simctl install "$udid" "$app"
xcrun simctl terminate "$udid" "$bundle" 2>/dev/null || true
log="$(mktemp)"
xcrun simctl io "$udid" recordVideo --codec h264 --force "$out" >"$log" 2>&1 &
rec=$!
# 等录像真正开始再启动 App：runner 繁忙时 recordVideo 可能晚十几秒才出帧（run 38212447159 的 eggs_two 录像
# 首帧时第一枚卵已经孵化）。最多等 30 秒
for _ in $(seq 1 60); do
  grep -q "Recording started" "$log" && break
  sleep 0.5
done
cat "$log"
sleep 1
xcrun simctl launch "$udid" "$bundle" "$@" || echo "launch failed"
sleep "$seconds"
xcrun simctl terminate "$udid" "$bundle" 2>/dev/null || true
kill -INT "$rec" 2>/dev/null || true
wait "$rec" 2>/dev/null || true
ls -la "$out"
