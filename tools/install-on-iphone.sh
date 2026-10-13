#!/usr/bin/env bash
# 在你自己的 Mac 上把当前检出的 AntKingdom 核心测试包签名并装到连着的 iPhone（Debug，带生命周期诊断）。
#
# 前提（只需一次）：Xcode → Settings → Accounts 登录你的 Apple ID（个人免费账号即可）；iPhone 用线连接、已信任此 Mac、
# 设置 → 隐私与安全性 → 开发者模式已开启。凭据只在 Xcode / 钥匙串里，本脚本不读取、不保存密码或证书。
#
# 用法：
#   bash tools/install-on-iphone.sh [TEAM_ID] [BUNDLE_ID]
#   TEAM_ID 省略时从钥匙串里的 “Apple Development” 证书读取（Xcode 第一次签名后才有）；
#   BUNDLE_ID 省略时用 com.<macOS 用户名>.crumbkingdom.dev（只在本机构建时使用，不改仓库）。
#
# 注意：Claude 没有 Mac，本脚本只做过语法检查，未在真机上运行过；失败时按 docs/BUILD.md 的 Xcode 手动步骤安装，
# 并把报错原文（不含账号信息）回传。
set -euo pipefail
cd "$(dirname "$0")/.."

team="${1:-}"
if [ -z "$team" ]; then
  team="$(security find-certificate -c "Apple Development" -p 2>/dev/null \
    | openssl x509 -noout -subject 2>/dev/null | sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p' | head -1 || true)"
fi
if [ -z "$team" ]; then
  echo "找不到 Team ID：先在 Xcode 里登录 Apple ID，并用 Xcode 对任意项目 Run 一次到 iPhone，或直接传入 TEAM_ID。" >&2
  exit 2
fi
user_part="$(id -un | tr -cd 'a-zA-Z0-9' | tr 'A-Z' 'a-z')"
bundle="${2:-com.${user_part:-tester}.crumbkingdom.dev}"

device="$(xcrun devicectl list devices 2>/dev/null | awk '/iPhone/ && /(available|connected)/ {for (i = 1; i <= NF; i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F-]+$/) {print $i; exit}}')"
if [ -z "$device" ]; then
  echo "没有找到已连接的 iPhone（xcrun devicectl list devices）。请用线连接、解锁并信任此 Mac。" >&2
  exit 3
fi

sha="$(git rev-parse --short HEAD)"
tag="$(git describe --tags --exact-match 2>/dev/null || echo "（未在 tag 上）")"
echo "源码 ${sha} ${tag}；Team ${team}；Bundle ID ${bundle}；设备 ${device}"

xcodebuild -project ios/AntKingdom.xcodeproj -scheme AntKingdom -configuration Debug \
  -destination "generic/platform=iOS" -derivedDataPath build/device \
  -allowProvisioningUpdates DEVELOPMENT_TEAM="$team" CODE_SIGN_STYLE=Automatic \
  PRODUCT_BUNDLE_IDENTIFIER="$bundle" build | tail -5

app=build/device/Build/Products/Debug-iphoneos/AntKingdom.app
xcrun devicectl device install app --device "$device" "$app"
xcrun devicectl device process launch --device "$device" "$bundle" || true

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Info.plist")"
build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Info.plist")"
echo
echo "已安装：AntKingdom ${version} (${build})，源码 ${sha} ${tag}。"
echo "请回传：iPhone 型号、iOS 版本、上面这一行，以及首屏截图（能看见新蚂蚁 / 卵 / 房间）。不要回传 Team ID 以外的账号信息。"
