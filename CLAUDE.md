# AntKingdom：给 Claude 的执行入口

这是用户指定的分工：**Codex 负责产品计划、数值设计、美术方向与验收；Claude 负责代码实现、自动化测试、iOS 工程与构建；用户负责真机试玩、开发者账号和发行决定。**

沟通、技术文档、提交说明使用中文。所有玩家可见文案、商品文案和商店宣传文案使用英文。main 保存 PRD、地图、Python 基准和制作资料，iOS 实现在 Claude 分支；按 SHA 与实际证据判断进度，不宣称未验收的客户端、美术或真机测试已完成。

## 本轮最高执行优先级（2026-10-12）

先读 [新美术真机包修复交接](docs/reviews/2026-10-12-art-device-handoff.md)。D-13、D-14、D-15 已有代码/CI修复证据，不重复列为根因未知。**现在优先修 D-16 卵槽位跳动、把 A02-01 同步到发行 CrumbKingdom，并交付带 A01/A02 共44张新美术的实际可安装真机包。** 这更新此前“占位包先交”的顺序；后续美术不拖延首次新美术包交付。

1. [Issue #17](https://github.com/qianquandong/AntKingdom/issues/17)：卵从创建到孵化保留固定槽位；补 E01–E06、四向转弯/装卸/改路、两 scheme、小屏及动态验收。A02 已在 PR #18 核心分支导入，不再写“未接入”；发行仍缺 A02。
2. [Issue #16](https://github.com/qianquandong/AntKingdom/issues/16)：保留 D-14/D-15 修复，整合后重跑适用回归，真实 SDK / 设备项独立记录。
3. [Issue #11](https://github.com/qianquandong/AntKingdom/issues/11)：交付新固定 SHA/tag、递增 build、签名安装或可访问 TestFlight 入口、至少一台物理 iPhone 新美术证据。旧 0.1.0(2) 是 unsigned 占位包，不是可安装/TestFlight交付。签名条件缺失准确标 SIGNING_BLOCKED，并交齐已验证工程与 Mac 步骤。

Codex 已交 [A01-01](assets/source/a01-01/README.md)、[A01-02](assets/source/a01-02/README.md)、[A02-01](assets/source/a02-01/README.md) 三批44张 / 11组，状态 reviewed，设备终验未完成。新增 [A02-02地表/挖掘反馈](assets/source/a02-02/README.md) 4张已reviewed，累计48张/13组；Claude 独立接入两scheme并遵守等比裁切，首包至少包含前三批44张。Claude 继续代码与构建；不扩大玩法或商业化范围。下方初始 M0–M3 流程仅供依赖参考，不要重做已有证据的任务。

## 开始阅读

按顺序阅读：

1. [交付总计划](docs/DELIVERY_PLAN.md)：分工、阶段、状态、先后顺序。
2. [核心 PRD](docs/PRD.md)：M0–M3 的玩法权威；Python 是可执行基准。
3. [技术交接](docs/TECHNICAL_HANDOFF.md)：工程结构、模块边界、数值一致性。
4. [美术规范](docs/ART_DIRECTION.md) 和 [资源清单](design/asset_manifest.json)。
5. [完整测试计划](docs/QA_TEST_PLAN.md)：模拟器、真机、用户观察、商业化测试。
6. [正式版增量](docs/RELEASE_SCOPE.md)：M4 以后才加入的完整内容和商业化。
7. [App Store 流程](docs/APP_STORE_RUNBOOK.md)：TestFlight、隐私、商品、提审、上线。
8. [当前看板与交付模板](docs/EXECUTION_BOARD.md)。

## 现在执行的第一批任务

用户已有 Mac，可安装 Xcode。默认技术路线为 Swift + SpriteKit + SwiftUI，纯 Swift 核心包，iPhone 竖屏；部署目标暂定 iOS 17.0，M0 验证 SDK 兼容性与测试设备后记录。不要把上传要求的 SDK 版本误当最低支持系统版本。

1. 同步仓库，检查未提交改动，运行现有四个检查命令，保存结果。
2. 执行 M0：记录 macOS/Xcode/SDK/模拟器/实体设备，创建可复现构建工程和纯核心包，补充 Mac 构建说明与 CI。
3. 执行 M1：逐条移植 PRD 与 Python 规则，用共享夹具做差分测试；再接上占位地图、点击挖掘和 HUD。
4. 证据通过后执行 M2：完整核心循环、仓库、补给、生命周期、存档与离线。每个任务独立提交。
5. M3 配合 Codex 接入已通过验收的正式资源；请用户完成真机/观察试玩。在结果文件中记录实际证据。

现有检查：

```bash
python3 -m unittest discover -s tests -v
python3 tools/economy_sim.py --check
python3 tools/check_map.py
python3 tools/check_strings.py
```

## 执行约定

- 先做能运行的一小段，再补齐；每项任务有代码、验证、复现步骤和已知问题。PR 描述引用任务 ID。
- 使用 `claude/m0-bootstrap`、`claude/m1-core` 等功能分支与小 PR；不能用改测试预期掩盖错误。先检查现有分支，避免重复工程。
- 例行实现选择由 Claude 决定；规则变化、引擎变化、新 SDK、玩法扩张在交付记录中写明原因和影响，交给 Codex/用户确认后再改变已锁定范围。
- 没有正式图片时可以用带资源 ID 的占位图推进代码；占位资源不能通过美术终验或进 App Store 包。不要自行改风格、生成未经交接的最终资源。
- M0–M3 不接广告或 IAP。用户已选正式版免费 + 内购/可选奖励广告；M4–M5 按正式版增量实现，不能把收费提前塞进核心验证。
- 不写“真机已测”除非确有设备、系统、build、步骤和结果；无法运行的项目标 `BLOCKED` 或 `NOT_RUN`，继续其他可独立的任务。
- 新增英文文案登记到对应版本文案表，再扩展文案检查；不要把中文错误、调试信息、内部任务名放入玩家界面。
- 凭据保存在本机钥匙串或受控 CI secrets，不进入仓库/截图/测试报告。签名与上传必须使用用户拥有且已授权的账号。
- 用户这次要求的是计划与交接，不是立即对外提审/发布。准备完整可审查的包后，由用户按发行流程决定提审、地区、价格与正式发布。
- Codex 的美术与设计评审由用户转交或本仓库 PR/报告承接；不存在自动唤醒 Codex 或替用户发消息的约定。

## 每次交付必须回答

本次完成的任务 ID；commit/PR；可运行方式；测试环境与通过/失败数；真机证据；剩余问题；下一项任务；需要 Codex 提供的具体资源 ID 或设计结论。按 [模板](docs/EXECUTION_BOARD.md) 写报告，不能只回复“已完成”。
