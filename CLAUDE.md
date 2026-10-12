# AntKingdom：给 Claude 的执行入口

这是用户指定的分工：**Codex 负责产品计划、数值设计、美术方向与验收；Claude 负责代码实现、自动化测试、iOS 工程与构建；用户负责真机试玩、开发者账号和发行决定。**

沟通、技术文档、提交说明使用中文。所有玩家可见文案、商品文案和商店宣传文案使用英文。main 保存 PRD、地图、Python 基准和制作资料，iOS 实现在 Claude 分支；按 SHA 与实际证据判断进度，不宣称未验收的客户端、美术或真机测试已完成。

## 本轮最高执行优先级（2026-10-11）

先处理 **[D-13 / Issue #11](https://github.com/qianquandong/AntKingdom/issues/11)**，要求与验收见 [交接文档](docs/reviews/2026-10-11-d13-handoff.md)。定位离线收益漏算，补原实现会稳定失败的确定性测试，通过规定回归后交付可安装的核心 AntKingdom 真机测试包。保持代码修复、签名安装、真机验收三段状态；不能以 CI 重跑成功关单，签名条件缺失写 SIGNING_BLOCKED，不假称已交付。

暂停新增玩法/商业化扩展，保留既有分支；不要重复已经有证据的 M0–M2 工作。Codex 的 [A01-01 资源包](assets/source/a01-01/README.md) 已供内部集成，D-13 测试包可先用占位资源；正式资源导入另做可追溯提交，发行门槛不放宽。

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
