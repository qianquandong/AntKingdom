# 执行看板与交付模板

更新：2026-10-11。Claude 开工先更新本表，不把任务列表当完成清单。

**当前第一优先：Claude 修复 [D-13 / Issue #11](https://github.com/qianquandong/AntKingdom/issues/11)，完成回归后交付可安装核心真机包。** [本轮修复要求](reviews/2026-10-11-d13-handoff.md)列出复现、20 轮模拟器/10 轮真机往返及签名交付标准。未确认根因时不能以重跑通过关单。

关联：[Issue #6 原修复清单](https://github.com/qianquandong/AntKingdom/issues/6)；[首次评审记录](reviews/2026-10-11-claude-review.md)；[A00 样张](../assets/source/keyframe/README.md)；[A01-01 环境资源首批](../assets/source/a01-01/README.md)。下方历史阶段队列不是当前完成度；Claude 应合并其分支已有报告的实际证据，逐项替换历史状态，不覆盖更完整的记录。

## 1. 当前事实

| 项目 | 状态 | 证据/下一步 |
|---|---|---|
| 核心 PRD/数值基准 | DONE | 基线提交 eae0215，30 项 Python 回归及 GitHub CI 通过 |
| 全流程计划/交接 | READY | 本组文档已形成；供 Claude 执行 |
| Mac 可用 | CONFIRMED | 用户确认有 Mac，可安装 Xcode；具体版本待 C00 记录 |
| iOS 工程/客户端 | IMPLEMENTED_IN_BRANCHES / D13_OPEN | 已复核 14845d2 的修复与 CI 38175736095；最新复核分支 86a7654 含补充报告。R01–R04 已有代码/CI 修复证据，D-13 根因未确认；未合入 main、真机未验收 |
| Codex 正式美术资源 | A01_01_02_REVIEWED / NOT_INTEGRATED | 两批累计 27 PNG / 8 资源组，含 16 种通路、Queen/Pantry；[A01-02](../assets/source/a01-02/README.md) 已做方向/配对/透明与布局检视。地表、角色、UI/音频等仍 planned，A00 仍 draft |
| 核心真机/用户试玩 | NOT_RUN | M2 构建后按测试矩阵执行 |
| 正式版内容 | PLANNED | 三小地图；A04 两张新增图尚待交付 |
| 商业化方向 | CONFIRMED | 免费 + 内购/可选奖励广告；具体首版产品见增量规格 |
| Apple 开发者账号与签名 | UNKNOWN | 用户在 C00 提供账号就绪状态，不提供密码到仓库 |
| TestFlight / App Store | NOT_STARTED | 不得把计划写成已经上传/上线 |

## 2. 当前任务与历史阶段队列

| 优先级 | ID | 主责 | 当前状态 | 交付物 |
|---|---|---|---|---|
| P1，先执行 | D-13 | Claude | OPEN | 根因、稳定复现、修复、规定回归、更新 M2 与 CI 证据 |
| 紧随修复 | CORE_DEVICE_BUILD | Claude / 用户 | NOT_DELIVERED | 固定 SHA 的签名核心包或 TestFlight build、安装证据；缺签名条件则 SIGNING_BLOCKED |
| 包安装后 | DEVICE_ACCEPTANCE | 用户 / Claude | NOT_RUN | Issue #11 真机矩阵、日志与实际收益/总结对照 |
| 并行 | A01-01 | Codex | REVIEWED | 9 张环境贴图，详见交付包；尚未导入客户端 |
| 生命周期稳定后 | A01-01 集成 | Claude / Codex | READY_FOR_INTERNAL_INTEGRATION | 同名 imageset、两 target 截图、尺寸/采样/状态切换检查 |
| 本轮美术 | A01-02 | Codex | REVIEWED | 16 种通路 + Queen/Pantry，共 18 PNG；64 边方向与 128 通口配对通过，见资源包 |
| 生命周期稳定后 | A01-02 集成 | Claude / Codex | READY_FOR_INTERNAL_INTEGRATION | [Issue #13](https://github.com/qianquandong/AntKingdom/issues/13)：18 图导入、占位清理、比例/层级/移动与真机验收 |
| 后续美术 | 地表 / A02 | Codex | PLANNED | 地表背景、工蚁与反馈；未包含在本次 A01-02，不阻塞占位核心真机包 |

以下为初始阶段队列，保留作依赖参考；执行时以开发分支报告和上述当前优先级为准。

| 顺序 | ID | 主责 | 初始状态 | 下一项完成动作 |
|---|---|---|---|---|
| 1 | C00 | Claude | READY | 基线检查、环境记录、可构建工程 |
| 并行 | A00 | Codex | DRAFT | 主界面样张已交付；补小屏/角色近景并完成方向确认 |
| 2 | C01–C04 | Claude | WAITING_C00 | 规则移植与可操作灰盒 |
| 并行 | A01–A03 | Codex | A01_PARTIAL | A01-01/02 已交付；地表、角色、核心 UI/音效待制作 |
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

## 6. 现在可直接交给 Claude 的消息

> 同步最新 main 的交接资料，先读 CLAUDE.md 与 docs/reviews/2026-10-11-d13-handoff.md，优先处理 Issue #11 的 D-13。先定位根因并做原实现稳定失败的测试，再完成规定回归，交付固定 SHA 的可安装 AntKingdom 核心真机测试包和步骤；未取得签名/设备条件请准确列出阻塞，不用重跑成功或无签名编译冒充完成。保留既有分支，暂停新增玩法/商业化，更新 M2 报告和当前看板。Codex 的 assets/source/a01-01/README.md 包含 9 张正式环境资源及接入标准，生命周期修复稳定后独立导入。你负责代码、测试、构建；Codex 负责计划与美术，用户负责物理设备操作。文档中文，玩家文案英文。

本轮接入补充：

> Codex 已交付 A01-02 的 18 张正式资源，读取 assets/source/a01-02/README.md 并执行 Issue #13。在 D-13 修复基线稳定后独立接入 16 种通路、Queen Chamber 和 Pantry，清除占位边框/货架线，保持 N1/E2/S4/W8、原比例、动态卵和逻辑占地。回传两 scheme、小屏/标准屏以及物理 iPhone 的实际证据；缺少真机时标 NOT_RUN。两批已交付 27 张，但其余资源及发行验收仍未完成。
