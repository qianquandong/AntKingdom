#!/usr/bin/env bash
# 运行 xcodebuild，完整日志保存为文件；失败时把编译/签名错误转成 GitHub 注解，
# 这样不下载日志也能在 run 摘要（及 API）里看到原因。
set -uo pipefail
mkdir -p build/logs
log="build/logs/xcodebuild-$(date +%s).log"
xcodebuild "$@" >"$log" 2>&1
status=$?
if [ $status -ne 0 ]; then
  echo "xcodebuild 失败（${status}），最后 80 行："
  tail -n 80 "$log"
  grep -E "error:|error -|Error Domain|Testing failed|failed \(|XCTAssert" "$log" \
    | sed -E 's/^[[:space:]]+//' | awk '!seen[$0]++' | head -n 15 \
    | while IFS= read -r line; do echo "::error::${line}"; done
else
  grep -E "\*\* (BUILD|TEST|ARCHIVE) SUCCEEDED \*\*|Executed [0-9]+ tests?, with|Test Suite '.*' (passed|failed)" "$log" | tail -n 20 || true
fi
exit $status
