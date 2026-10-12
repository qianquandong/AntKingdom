# 执行看板与交付模板

更新：2026-10-12（Claude 回填 Issue #16：核心包、D-14、D-15、A01 证据；A02-01 接入 PR #18）。Claude 开工先更新本表，不把任务列表当完成清单。

**当前第一优先：按 [最新复核](reviews/2026-10-11-followup-review.md) 交付可安装核心真机包，并修发行支线 D-14 广告暂停漏洞。** D-13 原问题已有确定性修复与模拟器 20/20 证据，Issue #11 仍因签名/真机未完成保持开放。美术接入修 D-15 食物源方板并补两 scheme 与动态验收；A02 不阻塞核心包。

关联：[Issue #6 原修复清单](https://github.com/qianquandong/AntKingdom/issues/6)；[首次评审记录](reviews/2026-10-11-claude-review.md)；[A00 样张](../assets/source/keyframe/README.md)；[A01-01 环境资源首批](../assets/source/a01-01/README.md)。下方历史阶段队列不是当前完成度；Claude 应合并其分支已有报告的实际证据，逐项替换历史状态，不覆盖更完整的记录。

## 1. 当前事实

| 项目 | 状态 | 证据/下一步 |
|---|---|---|
| 核心 PRD/数值基准 | DONE | 基线提交 eae0215，30 项 Python 回归及 GitHub CI 通过 |
| 全流程计划/交接 | READY | 本组文档已形成；供 Claude 执行 |
| Mac 可用 | CONFIRMED | 用户确认有 Mac，可安装 Xcode；具体版本待 C00 记录 |
| iOS 工程/客户端 | D13_BUILD_ARTIFACT / SIGNING_BLOCKED / DEVICE_NOT_RUN；D14_FIXED_CI_SIM | 核心测试包 tag `core-test-d13-2` = 387ad4f，0.1.0 (2)，CI [38205092148](https://github.com/qianquandong/AntKingdom/actions/runs/38205092148) 全部通过（往返 20/20）并产出无签名 .app（仅构建证据）；签名安装等用户本机 Apple ID。D-14 修于 m5-ads 60691ea（[D14 报告](https://github.com/qianquandong/AntKingdom/blob/claude/m5-ads/docs/reports/D14-2026-10-12.md)）。未合并 main |
| Codex 正式美术资源 | A01_INTEGRATED_2_TARGETS / A02_INTEGRATED_PR18 / REVIEW_PENDING | A01 27 PNG：D-15 已修，核心与发行两个 target 的模拟器截图、补给录屏、遮罩检视页见 A01-02 报告；A02-01 17 PNG 在 PR #18 核心 target 接入（CI 通过，发行 target 待 rebase）；manifest 仍 reviewed，strict 门槛失败，真机未验 |
| 核心真机/用户试玩 | NOT_RUN | M2 构建后按测试矩阵执行 |
| 正式版内容 | PLANNED | 三小地图；A04 两张新增图尚待交付 |
| 商业化方向 | CONFIRMED | 免费 + 内购/可选奖励广告；具体首版产品见增量规格 |
| Apple 开发者账号与签名 | UNKNOWN | 用户在 C00 提供账号就绪状态，不提供密码到仓库 |
| TestFlight / App Store | NOT_STARTED | 不得把计划写成已经上传/上线 |

## 2. 当前任务与历史阶段队列

| 优先级 | ID | 主责 | 当前状态 | 交付物 |
|---|---|---|---|---|
| P1，先执行 | D-13 交付 | Claude / 用户 | CODE_CI_PASSED / BUILD_ARTIFACT_DELIVERED / SIGNING_BLOCKED / NOT_INSTALLED | tag `core-test-d13-2`、0.1.0 (2)、无签名 TestFlight/Debug .app 两份（SHA-256 见 [D-13 报告](https://github.com/qianquandong/AntKingdom/blob/claude/d13-lifecycle/docs/reports/D13-2026-10-11.md) 第 6 节）；签名安装与真机矩阵等用户，未安装不能关单 |
| P1，发行修复 | D-14 | Claude | CODE_FIXED / CI_SIM_PASS；真实 SDK / 真机 NOT_RUN | 有意暂停进入生命周期（e3a4b73）；Codex 两条复现改接 API + 9 条核心、4 条 CampaignModel 集成、1 条全屏假广告 UI；变异检查 10/11 失败（95≠65）；CI [38206933405](https://github.com/qianquandong/AntKingdom/actions/runs/38206933405)（60691ea）发行轨全部通过 |
| P2，美术修复 | D-15 | Claude / Codex | CODE_FIXED / CI_SIM_PASS / REVIEW_PENDING | f7cf6e9 源格铺正式土层；前后对照、Sugar / Cookie 有货→耗尽→补给录屏（Cookie 见 A02-01 报告）、两 target 两屏截图（A01-02 报告） |
| 紧随修复 | CORE_DEVICE_BUILD | 用户 / Claude | SIGNING_BLOCKED / NOT_INSTALLED | 缺：用户 Mac 上 Xcode 登录的 Apple ID（个人免费账号即可）与一台 iPhone；步骤见 BUILD.md“核心真机测试包”；装好后回传型号/iOS/build/首屏截图 |
| 包安装后 | DEVICE_ACCEPTANCE | 用户 / Claude | NOT_RUN | Issue #11 真机矩阵、日志与实际收益/总结对照 |
| 已交付 | A01-01 | Codex | REVIEWED | 9 张环境贴图，已在 PR #14 核心分支导入 |
| 修复/验收 | A01-01 集成 | Claude / Codex | INTEGRATED_2_TARGETS / REVIEW_PENDING | D-15 已修；发行 target 截图已补；采样/闪线需真机；T-05 间歇 UI 失败已记录（A01-01 报告） |
| 已交付 | A01-02 | Codex | REVIEWED | 16 种通路 + Queen/Pantry，共18 PNG；已在 PR #15 核心分支导入 |
| 修复/验收 | A01-02 集成 | Claude / Codex | INTEGRATED_2_TARGETS / REVIEW_PENDING | [Issue #13](https://github.com/qianquandong/AntKingdom/issues/13)：16 遮罩检视页（含 0 号）待 Codex 逐边复核；挖格重开、0/1/2 卵、Pantry、平移缩放录像已产出；真机 NOT_RUN |
| 本轮美术 | A02-01 | Codex | REVIEWED | 工蚁14帧、cargo、卵两态，共17 PNG；桌面尺寸/alpha/对齐及64次浏览器seek检查通过 |
| 核心安装不等待 | A02-01 集成 | Claude / Codex | INTEGRATED_CORE / CI_SIM_PASS / REVIEW_PENDING | [PR #18](https://github.com/qianquandong/AntKingdom/pull/18) 固定 7b627e0，CI [38219003690](https://github.com/qianquandong/AntKingdom/actions/runs/38219003690) 全部通过：17 张导入（SHA 对 metadata）、14 帧整组、独立货物、卵 24pt；A02-T01/T03 测试、动作与卵录像；发行 target（发行栈 rebase 到本分支）、真机待做 |
| 后续美术 | 地表 / A02反馈 | Codex | PLANNED | 地表背景、裂纹碎屑/路线状态；UI/音效及发行资源另按计划 |

以下为初始阶段队列，保留作依赖参考；执行时以开发分支报告和上述当前优先级为准。

| 顺序 | ID | 主责 | 初始状态 | 下一项完成动作 |
|---|---|---|---|---|
| 1 | C00 | Claude | READY | 基线检查、环境记录、可构建工程 |
| 并行 | A00 | Codex | DRAFT | 主界面样张已交付；补小屏/角色近景并完成方向确认 |
| 2 | C01–C04 | Claude | WAITING_C00 | 规则移植与可操作灰盒 |
| 并行 | A01–A03 | Codex | A01_A02_PARTIAL | A01-01/02、A02-01 已交付；地表、反馈、核心 UI/音效待制作 |
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

> 同步最新 main，先读 CLAUDE.md 与 docs/reviews/2026-10-11-followup-review.md，按 Issue #16 优先交付固定 SHA、version/build 的可安装 AntKingdom 核心真机包。保留已通过的 D-13 代码/模拟器证据，完成 #11 的签名安装与设备验收；发行支线修 D-14 两条复现并补真实接线的集成测试；修 D-15 食物源方板与 A01 两scheme/动态验收。签名/设备不足准确列出阻塞，不用无签名编译或CI通过冒充安装。暂停新增玩法/商业化；不等待A02再交核心包。文档中文，玩家文案英文。

本轮接入补充：

> Codex 新交付 A02-01 的17张角色资源，读取 assets/source/a02-01/README.md 并执行 Issue #17。完整导入idle2/walk6/carry6、独立cargo、卵两态，保持32pt/16pt/24pt、统一锚点、cargo局部+11pt及现有孵化规则。按A02-T01…T06回传循环/装卸/转向/0-2卵、两个scheme、小屏/标准屏和物理iPhone证据；缺少设备标NOT_RUN。A01两批27张已在核心分支导入，继续补#13剩余验收。累计制作44张/11组，其余资源与发行验收仍未完成。
