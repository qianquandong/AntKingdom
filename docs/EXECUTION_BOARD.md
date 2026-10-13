# 执行看板与交付模板

更新：2026-10-13（Claude 回填：D-16、发行 A02、新美术测试包 core-art-test-1、A02-02 接入 PR #20）。Claude 开工先更新本表，不把任务列表当完成清单。

**当前第一优先：按 [10-12交接](reviews/2026-10-12-art-device-handoff.md) 修 D-16 卵跳位、发行 A02 接入与剩余验收，交付带44张新美术的真机测试版。** D-13/D-14/D-15代码与CI已有修复证据；旧包 unsigned、占位美术、未安装。签名安装和设备验收分开回填，后续美术不拖延新美术首包。

关联：[Issue #6 原修复清单](https://github.com/qianquandong/AntKingdom/issues/6)；[首次评审记录](reviews/2026-10-11-claude-review.md)；[A00 样张](../assets/source/keyframe/README.md)；[A01-01 环境资源首批](../assets/source/a01-01/README.md)。下方历史阶段队列不是当前完成度；Claude 应合并其分支已有报告的实际证据，逐项替换历史状态，不覆盖更完整的记录。

## 1. 当前事实

| 项目 | 状态 | 证据/下一步 |
|---|---|---|
| 核心 PRD/数值基准 | DONE | 基线提交 eae0215，30 项 Python 回归及 GitHub CI 通过 |
| 全流程计划/交接 | READY | 本组文档已形成；供 Claude 执行 |
| Mac 可用 | CONFIRMED | 用户确认有 Mac，可安装 Xcode；具体版本待 C00 记录 |
| iOS 工程/客户端 | D13_D14_D15_D16_CODE_CI_PASSED / BUILD_ARTIFACT_ONLY | 新美术候选 cbc3275（tag core-art-test-1，0.1.0 (3)）：核心 104/104、单元 23/23、UI 两机型 21+1 skip；D-13 往返在该 SHA 21 轮 20 轮相符 1 轮多算 5.47 s（见[包报告](https://github.com/qianquandong/AntKingdom/blob/claude/a02-01-art/docs/reports/ART-DEVICE-BUILD-2026-10-12.md)）。发行 40aa730：核心 168/168、发行单元 38/38、UI 21/21。未合并 main、设备未验 |
| Codex 正式美术资源 | 48_REVIEWED / 44_IN_BOTH_TARGETS / A02-02_PR20 | 前三批 44 张两个 target 实际加载（核心 / 发行测试）；A02-02 4 张在 [PR #20](https://github.com/qianquandong/AntKingdom/pull/20) 接入（下一 build）；manifest 仍 reviewed，真机未验 |
| 核心真机/用户试玩 | NOT_RUN | M2 构建后按测试矩阵执行 |
| 正式版内容 | PLANNED | 三小地图；A04 两张新增图尚待交付 |
| 商业化方向 | CONFIRMED | 免费 + 内购/可选奖励广告；具体首版产品见增量规格 |
| Apple 开发者账号与签名 | SIGNING_BLOCKED | 有Mac不等于已提供签名Team；旧包unsigned，用户本机完成账号授权，不提交凭据 |
| TestFlight / App Store | NOT_STARTED | 不得把计划写成已经上传/上线 |

## 2. 当前任务与历史阶段队列

| 优先级 | ID | 主责 | 当前状态 | 交付物 |
|---|---|---|---|---|
| P1，交付 | D-13 设备 | Claude / 用户 | CODE_CI_PASSED / NOT_INSTALLED | 新候选 cbc3275 已重跑：小屏 20/20；标准 attempt 1 9/10（第 10 轮回来时 inactive→active 5.58 s 致多算 5.47 s，其余 29 轮 0.27–1.35 s），attempt 2 第 1 轮正确后 XCUITest 点击超时中止；真机矩阵 NOT_RUN |
| P1，整合回归 | D-14 | Claude | CODE_CI_PASSED / SDK_DEVICE_NOT_RUN | 整合 A02/D-16 后 40aa730、CI 38335894011 全部通过（D14 报告第 7 节）；真实 SDK / 设备 NOT_RUN |
| P2，整合回归 | D-15 | Claude | CODE_SIM_VISUAL_PASSED / DEVICE_NOT_RUN | 新候选与发行截图保持无浅色方板；Cookie / Sugar 补给循环录屏齐 |
| P1，先修 | D-16 | Claude / Codex | CODE_CI_PASSED / REVIEW_PENDING / DEVICE_NOT_RUN | afa4181：卵槽进核心模型（可选存档字段，旧档分配一次）；E01–E06 核心 + 节点 + 两 scheme UI 测试通过，变异 6/10 失败；两机型 E01/E02 录像（A02-01 报告） |
| P1，新美术包 | ART_DEVICE_BUILD | Claude / 用户 | BUILD_ARTIFACT_ONLY / SIGNING_BLOCKED | tag core-art-test-1 = cbc3275，0.1.0 (3)，44 张；无签名 TestFlight / Debug .app 与 SHA-256 见[包报告](https://github.com/qianquandong/AntKingdom/blob/claude/a02-01-art/docs/reports/ART-DEVICE-BUILD-2026-10-12.md)；一条命令安装脚本 tools/install-on-iphone.sh（未在 Mac 跑过）；缺你的 Apple ID + iPhone |
| 包安装后 | DEVICE_ACCEPTANCE | 用户 / Claude | NOT_RUN | Issue #11 真机矩阵、日志与实际收益/总结对照 |
| 已交付 | A01-01 | Codex | REVIEWED | 9 张环境贴图，已在 PR #14 核心分支导入 |
| 修复/验收 | A01-01 集成 | Claude / Codex | IMPORTED / DEVICE_NOT_RUN | D-15与源循环已有模拟器证据；整合后双轨与设备复核 |
| 已交付 | A01-02 | Codex | REVIEWED | 16 种通路 + Queen/Pantry，共18 PNG；已在 PR #15 核心分支导入 |
| 修复/验收 | A01-02 集成 | Claude / Codex | CORE_IMPORTED / REVIEW_PENDING | [Issue #13](https://github.com/qianquandong/AntKingdom/issues/13)：双scheme、比例/层级/移动/缩放与真机验收 |
| 本轮美术 | A02-01 | Codex | REVIEWED | 工蚁14帧、cargo、卵两态，共17 PNG；桌面尺寸/alpha/对齐及64次浏览器seek检查通过 |
| P1，修复/验收 | A02-01 集成 | Claude / Codex | BOTH_TARGETS / REVIEW_PENDING / DEVICE_NOT_RUN | 核心 PR #18 + 发行 PR #10（40aa730）；A02-T03 四向 / 改路 / 满仓确定性测试与路线录像；T29 30 分钟性能 NOT_RUN |
| 新交付/接入中 | A02-02 | Codex / Claude | INTEGRATED_CORE_PR20 / CI_PENDING | [PR #20](https://github.com/qianquandong/AntKingdom/pull/20)：地表等比裁切 (0,0.25,1,0.5)、第 2 次命中土屑事件、fx= 探针、三击与 50 次操作 UI 测试；不进 core-art-test-1，下一 build；发行 target 待 rebase |

以下为初始阶段队列，保留作依赖参考；执行时以开发分支报告和上述当前优先级为准。

| 顺序 | ID | 主责 | 初始状态 | 下一项完成动作 |
|---|---|---|---|---|
| 1 | C00 | Claude | READY | 基线检查、环境记录、可构建工程 |
| 并行 | A00 | Codex | DRAFT | 主界面样张已交付；补小屏/角色近景并完成方向确认 |
| 2 | C01–C04 | Claude | WAITING_C00 | 规则移植与可操作灰盒 |
| 并行 | A01–A03 | Codex | A01_A02_PARTIAL | 四批48张已制作；路线反馈、核心UI/音效待制作 |
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

> 同步最新main，先读CLAUDE.md与docs/reviews/2026-10-12-art-device-handoff.md。优先修#17的D-16卵跳位：每枚卵保留固定槽位，补E01–E06；把A02-01同步到发行CrumbKingdom，保留D-13/D-14/D-15修复，补四向/改路/动态和双scheme验收。交付至少含前三批44张美术的新SHA/tag/build>2测试版，完成#11签名安装和物理iPhone证据；缺签名准确列SIGNING_BLOCKED，unsigned编译不算交付完成。后续资源不拖延首包，不扩玩法/商业化。文档中文，玩家文案英文。

> Codex新增A02-02地表/挖掘反馈4张，读取assets/source/a02-02/README.md独立接入：地表等比裁中间一行，不压扁；两级裂纹保持位置；土屑36px/12pt；三击与Reduce Motion按事件驱动。累计48张/13组reviewed，发行门槛仍严格，缺设备写NOT_RUN。
