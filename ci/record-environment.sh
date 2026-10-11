#!/usr/bin/env bash
# 把 CI Mac 的构建环境写成 Markdown，作为 C00 的“环境记录”证据之一。
# 这是 GitHub 托管 runner 的环境，不等于用户自己的 Mac；用户 Mac 需本地运行同一脚本补记。
set -euo pipefail
out="${1:-build/environment.md}"
mkdir -p "$(dirname "$out")"
{
  echo "# 构建环境记录"
  echo
  echo "- 生成时间（UTC）：$(date -u '+%Y-%m-%d %H:%M:%S')"
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "- 来源：GitHub Actions 托管 runner（镜像 ${ImageOS:-unknown} ${ImageVersion:-unknown}，run ${GITHUB_RUN_ID:-?}）"
  else
    echo "- 来源：本地 Mac（$(scutil --get ComputerName 2>/dev/null | sed 's/./*/g' || echo unknown)，名称已脱敏）"
  fi
  echo "- commit：$(git rev-parse --short HEAD)"
  echo
  echo '## macOS'
  echo '```'
  sw_vers
  uname -m
  echo '```'
  echo '## Xcode 与 SDK'
  echo '```'
  xcodebuild -version
  xcrun --sdk iphonesimulator --show-sdk-version | sed 's/^/iphonesimulator SDK: /'
  xcrun --sdk iphoneos --show-sdk-version | sed 's/^/iphoneos SDK: /'
  swift --version 2>&1 | head -n 2
  if command -v xcodegen >/dev/null; then echo "xcodegen $(xcodegen --version | tail -n 1)"; fi
  echo '```'
  echo '## 可用 iPhone 模拟器（运行时：机型）'
  echo '```'
  xcrun simctl list devices available | awk '/^-- iOS/{rt=$0} /iPhone/{print rt, $0}' | sed -E 's/\(([0-9A-F-]{36})\).*/(\1)/'
  echo '```'
  echo '## 实体设备'
  echo
  echo 'CI runner 没有连接实体 iPhone；真机列表由用户在自己的 Mac 上补记。'
} >"$out"
echo "wrote $out"
