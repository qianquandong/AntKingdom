# A02-01 动作预览

HyperFrames composition，6 秒，英文标注。用 `npx hyperframes preview` 在本目录查看、暂停和拖动时间线。

同一套 PNG 在放大视图及 32pt 视图播放：idle 4fps、walk/carry 10fps；cargo 相对父节点 +11pt，独立图层。卵 0–2s normal / 2–4s ready / 4–6s normal。不是实机截图，不含经济或路由逻辑。

GSAP 3.14.2 在 vendor 下以便离线 seek；仅 QA 页使用，不进游戏包。保留原版权头与条款链接，见 GSAP-NOTICE.txt。未导出视频。

自动检查用 [check.cjs](check.cjs)。安装 Playwright 与匹配的 Chromium 后，在本目录运行 `node check.cjs`；如使用系统 Edge，可设 `A02_BROWSER_CHANNEL=msedge`（本次桌面检查所用）。64 次取样包含所有帧、状态边界后的时刻及反向 seek，检查图片解码、每种尺寸只显示一帧和正确卵态；结果写到上级 preview-qa.json，并生成 motion-proof.png。脚本只驱动本地检视页，不执行游戏逻辑。

工具检查版本为 HyperFrames 0.8.149。lint 有2条已审阅提示：同一图片在放大/原尺寸视图重复使用，以及单页内容没有拆成子场景。所有图已给独立ID，validate/inspect均通过；详见上级 preview-tool-checks.json。直接用浏览器打开 index.html 会停在初始帧，播放/拖动时间线使用 HyperFrames Studio。
