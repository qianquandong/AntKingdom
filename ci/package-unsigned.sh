#!/usr/bin/env bash
# 把无签名的 .app 打成可下载的压缩包，附版本、构建号、提交、SHA-256 与说明。
# 用法：bash ci/package-unsigned.sh <输出目录> <App 路径> <配置名> [<App 路径> <配置名> ...]
# 产物只是构建证据：没有签名，不能直接装到 iPhone；安装需用户自己的 Apple ID/Team 签名（docs/BUILD.md）。
set -euo pipefail
out="$1"; shift
mkdir -p "$out"
plist_value() { /usr/libexec/PlistBuddy -c "Print :$2" "$1/Info.plist"; }
commit="${GITHUB_SHA:-$(git rev-parse HEAD)}"
{
  echo "## 无签名构建产物（仅构建证据）"
  echo
  echo "提交：\`${commit}\`；Xcode：$(xcodebuild -version | tr '\n' ' ')；SDK：$(xcrun --sdk iphoneos --show-sdk-version)"
  echo
  echo "| 文件 | 配置 | 版本 (构建号) | Bundle ID | 最低 iOS | 大小 | SHA-256 |"
  echo "|---|---|---|---|---|---|---|"
} > "$out/BUILD-INFO.md"
while [ $# -ge 2 ]; do
  app="$1"; config="$2"; shift 2
  version="$(plist_value "$app" CFBundleShortVersionString)"
  build="$(plist_value "$app" CFBundleVersion)"
  bundle="$(plist_value "$app" CFBundleIdentifier)"
  minos="$(plist_value "$app" MinimumOSVersion)"
  if codesign -dv "$app" >/dev/null 2>&1; then signed="已签名（意外）"; else signed="未签名"; fi
  zip="AntKingdom-${version}-${build}-${config}-iphoneos-unsigned.zip"
  ditto -c -k --keepParent "$app" "$out/$zip"
  sum="$(shasum -a 256 "$out/$zip" | cut -d' ' -f1)"
  size="$(stat -f %z "$out/$zip")"
  echo "| ${zip} | ${config}（${signed}） | ${version} (${build}) | ${bundle} | ${minos} | ${size} | \`${sum}\` |" >> "$out/BUILD-INFO.md"
done
{
  echo
  echo "这些 .app 没有签名，不能直接安装到 iPhone。安装请在自己的 Mac 上用 Xcode 打开同一提交的源码，"
  echo "选自己的 Apple ID/Team 签名后 Run（步骤见 docs/BUILD.md“核心真机测试包”）。Debug 包带生命周期诊断；"
  echo "TestFlight 配置不含诊断与调试入口（发行检查见 release-check.md）。"
} >> "$out/BUILD-INFO.md"
cat "$out/BUILD-INFO.md"
