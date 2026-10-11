# 执行看板与交付模板

更新：2026-10-11。Claude 开工先更新本表，不把任务列表当完成清单。

本轮交接：[Issue #6 修复与验收清单](https://github.com/qianquandong/AntKingdom/issues/6)；[评审记录](reviews/2026-10-11-claude-review.md)；[Codex A00 样张](../assets/source/keyframe/README.md)。本次仅同步已知概况与 Codex 美术进度，下方 Claude 任务的初始排队状态仍需由 Claude 按实际 SHA/测试证据逐项回填（R05），不能作为当前完成度。

## 1. 当前事实

| 项目 | 状态 | 证据/下一步 |
|---|---|---|
| 核心 PRD/数值基准 | DONE | 基线提交 eae0215，30 项 Python 回归及 GitHub CI 通过 |
| 全流程计划/交接 | READY | 本组文档已形成；供 Claude 执行 |
| Mac 可用 | CONFIRMED | 用户确认有 Mac，可安装 Xcode；具体版本待 C00 记录 |
| iOS 工程/客户端 | IMPLEMENTED_IN_BRANCHES / PARTIALLY_TESTED | C06 分支 2351f27 模拟器 CI 通过；评审时最新广告分支 3a6f5f9 编译失败，见 Issue #6；未合入 main、真机未验收 |
| Codex 正式美术资源 | A00_DRAFT / RUNTIME_PLANNED | 主界面预览与无文字底稿已交付；其余运行时资源仍 planned；A00 小屏/近景/方向确认待完成 |
| 核心真机/用户试玩 | NOT_RUN | M2 构建后按测试矩阵执行 |
| 正式版内容 | PLANNED | 三小地图；A04 两张新增图尚待交付 |
| 商业化方向 | CONFIRMED | 免费 + 内购/可选奖励广告；具体首版产品见增量规格 |
| Apple 开发者账号与签名 | UNKNOWN | 用户在 C00 提供账号就绪状态，不提供密码到仓库 |
| TestFlight / App Store | NOT_STARTED | 不得把计划写成已经上传/上线 |

## 2. 排队任务

| 顺序 | ID | 主责 | 初始状态 | 下一项完成动作 |
|---|---|---|---|---|
| 1 | C00 | Claude | READY | 基线检查、环境记录、可构建工程 |
| 并行 | A00 | Codex | DRAFT | 主界面样张已交付；补小屏/角色近景并完成方向确认 |
| 2 | C01–C04 | Claude | WAITING_C00 | 规则移植与可操作灰盒 |
| 并行 | A01–A03 | Codex | WAITING_A00 | 环境、角色、核心 UI/音效 |
| 3 | C05–C08 | Claude | WAITING_M1 | 核心循环、保存、集成、内部包 |
| 4 | C09 | Claude/用户/Codex | WAITING_M2 | 真机证据与观察反馈 |
| 5 | A04 / C10 | Codex / Claude | WAITING_M3 | 正式内容设计/实现 |
| 6 | A05 / C11–C13 | Codex / Claude | WAITING_M4 | 商品资源、支付、广告、隐私 |
| 7 | A06 / C14–C15 | Codex / Claude | WAITING_M5 | 发行素材、候选测试与资料包 |
| 8 | C16 | 用户/Claude | WAITING_RELEASE | 用户发行决定后的提审/上线 |

READY 表示输入足够；DONE 必须有证据。BLOCKED 写具体缺什么、谁提供、哪些独立任务仍可做。评审后直接在本表细化各 ID，不需要保留永远静态的计划状态。

## 3. C00 要填的决定记录

| 决定/资料 | 当前值 | 负责补齐 | 最晚时间 |
|---|---|---|---|
| 引擎与语言 | Swift + SpriteKit + SwiftUI | Claude 验证并记录 | M0 |
| 最低系统 | 暂定 iOS 17.0 | Claude 结合设备/SDK确认 | M0 |
| Xcode / SDK / macOS | 待测 | Claude | M0 |
| 真机列表 | 待填，不能推断用户拥有何种 iPhone | 用户 + Claude | M2 首测/M6 补齐 |
| Team/Bundle ID/开发者主体 | 待定 | 用户 | 签名/TestFlight 前 |
| 正式名称 | Crumb Kingdom 为工作名 | 用户 + Codex | App 记录与素材冻结前 |
| 首发地区 | 待定，不默认全地区 | 用户 | M5 隐私/商品配置前 |
| 商品价格/真实 ID | US$2.99 为评估假设，尚未定价 | 用户 + Claude | M5 |
| 广告账号/应用/广告单元 | 待定 | 用户 + Claude | M5 |
| 支持邮箱与隐私/支持 URL | 待定 | 用户；Claude 建页面；Codex 起草内容 | M6 |
| 提审/发布决定 | 尚未发生 | 用户 | M7 |

## 4. Claude 阶段报告模板

复制到 `docs/reports/Mx-YYYY-MM-DD.md`（未来交付路径），填写实际结果：

```text
阶段 / 任务 ID：
日期 / 执行人：
Git commit / PR：
App version / build / 资源版本：
macOS / Xcode / SDK / 最低系统：
本次完成的行为：
如何启动/复现（命令和入口）：
自动化测试（命令、通过/失败、日志位置）：
模拟器测试（机型/OS、用例 ID、结果）：
真机测试（机型/OS、用例 ID、结果、执行者；未测必须写未测）：
截图/录像/xcresult 的脱敏证据：
已知缺陷（等级、ID、复现、影响、计划）：
相对 PRD/计划的差异及原因：
需要 Codex 的资源 ID / 设计决定：
需要用户的账号/设备/发行决定：
可独立继续的任务：
建议下一步：
```

## 5. 缺陷与美术回传模板

```text
缺陷 ID / 等级 / build：
对应测试 ID / 资源 ID：
前置状态和操作步骤：
期望 / 实际：
频率与影响范围：
证据（不含私人数据）：
修复 commit / 重测结果：
```

Codex 回传资源时记录 ID、版本、尺寸、锚点、帧序、来源、文件位置、预览与验收结论。Claude 回传集成截图；状态从 approved 到 integrated 再到 verified_on_device，不跳过设备检查。

## 6. 交给 Claude 的首条消息

> 请读取仓库根目录 CLAUDE.md，并按 docs/DELIVERY_PLAN.md 执行 AntKingdom。你负责具体代码实现、自动化测试与 iOS 工程；Codex 负责计划、数值和美术，用户负责真机试玩与发行决定。Mac 已有，游戏最终免费并加入内购/可选奖励广告。现在先执行 C00，再按依赖完成 M1/M2；不要提前接商业化。保持文档和沟通中文、玩家文案英文。每个任务提交代码与实际测试证据，更新 docs/EXECUTION_BOARD.md，列出需要 Codex 提供的资源 ID。缺少账号或最终美术时继续可独立进行的工作，不把占位、模拟器或未运行的测试标成真机通过。
