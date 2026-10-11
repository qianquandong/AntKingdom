#!/usr/bin/env bash
# 检查 TestFlight/AppStore 配置编出的 .app：版本信息、最低系统、仅 iPhone，
# 调试入口已剔除，M0–M3 未链接广告/内购/追踪框架。输出 Markdown（写入 Step Summary）。
# 用法：bash ci/check-release-binary.sh path/to/AntKingdom.app [--release-track]
#   --release-track：发行轨 CrumbKingdom.app，另查 Debug 测试地图已剔除、章节数据已打包。
set -uo pipefail
app="$1"
track="${2:-}"
plist="$app/Info.plist"
binary="$app/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist")"
fail=0

value() { /usr/libexec/PlistBuddy -c "Print :$1" "$plist" 2>/dev/null; }

# 二进制中的字符串先写到文件再查。不能用 `strings | grep -q`：pipefail 下 grep 命中后提前退出，
# strings 收到 SIGPIPE（141），整条管道判为失败，命中反而被当成“没找到”（调试入口会被误报为已剔除）。
strings_file="$(mktemp)"
trap 'rm -f "$strings_file"' EXIT
strings -a "$binary" > "$strings_file"
has_string() { grep -qF -- "$1" "$strings_file"; }

echo "## Release 配置二进制检查"
echo
echo "| 项 | 值 | 结果 |"
echo "|---|---|---|"
row() { echo "| $1 | $2 | $3 |"; [ "$3" = "PASS" ] || fail=1; }

version="$(value CFBundleShortVersionString)"
build="$(value CFBundleVersion)"
minos="$(value MinimumOSVersion)"
family="$(value UIDeviceFamily | tr -d ' \n' )"
row "CFBundleShortVersionString" "$version" "$([ -n "$version" ] && echo PASS || echo FAIL)"
row "CFBundleVersion" "$build" "$([[ "$build" =~ ^[0-9]+$ ]] && echo PASS || echo FAIL)"
row "MinimumOSVersion" "$minos" "$([ "$minos" = "17.0" ] && echo PASS || echo FAIL)"
row "UIDeviceFamily" "$family" "$([ "$family" = "Array{1}" ] && echo PASS || echo FAIL)"
row "Bundle ID" "$(value CFBundleIdentifier)" "PASS"

# 调试入口（启动参数、探针、调试菜单、测试地图）只能存在于 Debug 构建
markers=("-ak-scenario" "-ak-away" "-ak-reset-save" "-ak-reduce-motion" "debug.probe" "debug.lifecycle" "-ak-gallery" "-ak-zoom" "Load scenario: ")
if [ "$track" = "--release-track" ]; then
  markers+=("-ak-fixture-chapters" "Test Map (Debug)" "debug_fixture" "-ak-store" "FakeStoreService"
            "-ak-fail-writes" "XCTestConfigurationFilePath"
            "-ak-ads" "-ak-reward-ready" "FakeRewardedAdService" "debugUnlockRewardsForTesting")
fi
for marker in "${markers[@]}"; do
  if has_string "$marker"; then
    row "无调试入口：$marker" "found" "FAIL"
  else
    row "无调试入口：$marker" "absent" "PASS"
  fi
done

# 核心验证版（M0–M3）不接广告或内购（CLAUDE.md）：不得链接相关系统框架。
# 发行轨：必须链接 StoreKit（C11）；奖励广告用 AdMob + UMP（C12），但不弹 ATT（无 NSUserTrackingUsageDescription）。
linked="$(otool -L "$binary" | tail -n +2)"
forbidden="StoreKit AdSupport AppTrackingTransparency GoogleMobileAds"
notes=""
if [ "$track" = "--release-track" ]; then
  forbidden=""
  if grep -q "/StoreKit.framework/" <<< "$linked"; then
    row "已链接 StoreKit（外观商品）" "linked" "PASS"
  else
    row "已链接 StoreKit（外观商品）" "not linked" "FAIL"
  fi
  if grep -q "GADMobileAds\|GoogleMobileAds" "$strings_file"; then
    row "包含 AdMob SDK（奖励广告）" "present" "PASS"
  else
    row "包含 AdMob SDK（奖励广告）" "absent" "FAIL"
  fi
  if [ -z "$(value NSUserTrackingUsageDescription)" ]; then
    row "不请求 ATT（无 NSUserTrackingUsageDescription）" "absent" "PASS"
  else
    row "不请求 ATT（无 NSUserTrackingUsageDescription）" "present" "FAIL"
  fi
  gad="$(value GADApplicationIdentifier)"
  unit="$(value AKRewardedAdUnitID)"
  row "GADApplicationIdentifier 已配置" "$gad" "$([ -n "$gad" ] && echo PASS || echo FAIL)"
  row "AKRewardedAdUnitID 已配置" "$unit" "$([ -n "$unit" ] && echo PASS || echo FAIL)"
  if [[ "$gad" == ca-app-pub-3940256099942544* ]]; then
    notes="注意：AdMob App ID 与广告单元仍是 Google 测试 ID；AppStore 提交前必须换成用户 AdMob 账号的真实 ID（M5 BLOCKED）。"
  fi
  for framework in AdSupport AppTrackingTransparency; do
    if grep -q "/$framework.framework/" <<< "$linked"; then
      notes="$notes 链接了 $framework（AdMob SDK 依赖；不弹 ATT、不读取 IDFA 前须用户授权）。"
    fi
  done
fi
for framework in $forbidden; do
  if grep -q "/$framework.framework/" <<< "$linked"; then
    row "未链接 $framework" "linked" "FAIL"
  else
    row "未链接 $framework" "not linked" "PASS"
  fi
done

if [ "$track" = "--release-track" ]; then
  for resource in chapters.json map_prototype.txt Release.strings; do
    found=$(find "$app" -name "$resource" -print -quit)
    if [ -n "$found" ]; then row "已打包 $resource" "${found#$app/}" "PASS"; else row "已打包 $resource" "missing" "FAIL"; fi
  done
  # 本地 StoreKit 测试配置只用于开发/测试，不进发行包
  found=$(find "$app" -name "*.storekit" -print -quit)
  if [ -z "$found" ]; then row "未打包 StoreKit 测试配置" "absent" "PASS"; else row "未打包 StoreKit 测试配置" "${found#$app/}" "FAIL"; fi
fi

# 隐私清单（C13）：App 自身只用 systemUptime 计前台时长（SystemBootTime / 35F9.1），不跟踪、不收集。
# 第三方 SDK（AdMob/UMP）自带各自的清单；App Store 隐私标签按最终 SDK 实际行为由用户填写。
manifest="$app/PrivacyInfo.xcprivacy"
if [ -f "$manifest" ]; then
  row "PrivacyInfo.xcprivacy 已打包" "present" "PASS"
  reasons="$(/usr/libexec/PlistBuddy -c 'Print :NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPITypeReasons:0' "$manifest" 2>/dev/null)"
  row "声明 SystemBootTime 原因 35F9.1" "$reasons" "$([ "$reasons" = "35F9.1" ] && echo PASS || echo FAIL)"
  tracking="$(/usr/libexec/PlistBuddy -c 'Print :NSPrivacyTracking' "$manifest" 2>/dev/null)"
  row "App 自身不跟踪（NSPrivacyTracking）" "$tracking" "$([ "$tracking" = "false" ] && echo PASS || echo FAIL)"
else
  row "PrivacyInfo.xcprivacy 已打包" "missing" "FAIL"
fi

echo
[ -n "$notes" ] && echo "$notes" && echo
if [ $fail -ne 0 ]; then
  echo "**FAILED**"
  exit 1
fi
echo "**PASS**（未签名；签名与上传需要用户的 Team / Bundle ID，见 docs/BUILD.md）"
