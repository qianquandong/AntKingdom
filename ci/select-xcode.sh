#!/usr/bin/env bash
# 选择 runner 上最新的正式版 Xcode 26+（上传 App Store 需要 iOS 26 SDK；
# 这是构建工具要求，不是最低支持系统，部署目标仍为 iOS 17.0）。
# 可用 XCODE_APP=/Applications/Xcode_26.0.app 强制指定，便于复现。
set -euo pipefail
if [ -n "${XCODE_APP:-}" ]; then
  xcode="$XCODE_APP"
else
  candidates=$(ls -d /Applications/Xcode_2[6-9]*.app 2>/dev/null | grep -v -i beta | sort -V || true)
  if [ -z "$candidates" ]; then
    echo "::error::runner 上没有 Xcode 26+。已安装：$(ls -d /Applications/Xcode*.app | xargs -n1 basename | tr '\n' ' ')"
    exit 1
  fi
  xcode=$(echo "$candidates" | tail -n 1)
fi
sudo xcode-select -s "$xcode/Contents/Developer"
echo "::notice::使用 $(basename "$xcode")：$(xcodebuild -version | tr '\n' ' ')"
