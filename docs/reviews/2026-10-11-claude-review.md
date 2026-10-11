# Claude 修复与验收交接 · 2026-10-11

跟踪入口：[GitHub Issue #6](https://github.com/qianquandong/AntKingdom/issues/6)。本文件保留评审时的修复要求；进度、修复提交及验收证据回填到 issue 和执行看板。

## 目标与执行顺序

Codex 已检查代码、CI 日志和 C06 模拟器截图。请 Claude 先完成下面 R01–R05 的修复与证据回填，再继续扩展商业化功能。可以保留已有发行分支；核心 M2 测试包、美术集成与真机验证优先。

- 评审基线：`claude/m5-ads @ 3a6f5f92cd73950cdeec9d6da1d7de3f51670547`，以及 `claude/m2-save @ 2351f27` 的已通过 CI。
- 以下描述针对上述基线。如果更新的提交已修复，填入修复 SHA 和对应运行证据，勿重复改动。
- 文档/交接用中文，玩家可见文案用英文。
- 已验证：本地 Python 46/46；最新广告分支 Linux Swift 核心测试 122/122；C06 版 Python↔Swift 差分 30/30。
- 尚未验证：用户 Mac 构建、物理 iPhone 操作/性能/生命周期、Sandbox/TestFlight 真实商店/广告链路。核心测试通过不代表 iOS App 构建或真机通过。

## R01 · P1 · 修复广告版本编译失败

**证据**：[CI 38165156438](https://github.com/qianquandong/AntKingdom/actions/runs/38165156438)，发行轨构建在 [AdMobRewardedService.swift:44](https://github.com/qianquandong/AntKingdom/blob/3a6f5f92cd73950cdeec9d6da1d7de3f51670547/ios/ReleaseTrack/Ads/AdMobRewardedService.swift#L44) 报 `expression is async but is not marked with await`。

**要求**：按已锁定 SDK 的真实异步 API 修复初始化；核对初始化完成、重复调用和失败/不可请求广告的行为，免费玩法始终可继续。不通过删除广告实现、静默换空服务或放宽 CI 来消除失败。

**验收**
- [ ] 发行轨 CrumbKingdom 在提交的工程上完成 Debug 构建、单元测试、UI 测试。
- [ ] 发行轨 TestFlight 配置完成无签名真机架构编译；将它与“已签名/已上传 TestFlight”明确区分。
- [ ] 加载失败、无填充、提前关闭不授予；earned 回调才授予；广告结束恢复游戏；重复展示不重复初始化。
- [ ] 提交修复 SHA、CI run 链接及结果。暂缺账号的真实广告/隐私测试写 NOT_RUN，不能用假服务代替验收结论。

## R02 · P1 · 补齐工程登记，确保新增广告测试确实被执行

**证据**：同一次 CI 的 XcodeGen 一致性检查失败。重新生成的 diff 新增 `RewardModelTests.swift` 和 `RewardFlowUITests.swift` 的文件与 Sources 引用；当前提交的工程漏登记。

**要求**：使用仓库锁定的 XcodeGen 2.45.4 根据 `ios/project.yml` 重新生成并提交工程。保留项目生成一致性检查与测试 target。

**验收**
- [ ] 干净检出后执行 `xcodegen generate --spec ios/project.yml`，`git status --porcelain -- ios/` 为空。
- [ ] xcresult/日志中能找到并确认执行 `RewardModelTests` 与 `RewardFlowUITests`；只看到测试文件存在或整条 workflow 绿色不够。
- [ ] 两个 scheme 的适用测试和构建在同一修复提交上成功；小屏测试结果单独注明。
- [ ] 无通过排除失败测试、删除 target、continue-on-error 或只跑旧 SHA 获得的“通过”。

## R03 · P1 · 购买权益持久化失败不能完成交易并报告成功

**证据**：[StoreKitService.swift:26–29](https://github.com/qianquandong/AntKingdom/blob/3a6f5f92cd73950cdeec9d6da1d7de3f51670547/ios/ReleaseTrack/Commerce/StoreKitService.swift#L26) 在 void 的 grant 回调后无条件 `finish()`；[CampaignCoordinator.swift:239](https://github.com/qianquandong/AntKingdom/blob/3a6f5f92cd73950cdeec9d6da1d7de3f51670547/Packages/AntKingdomCore/Sources/AntKingdomCore/CampaignCoordinator.swift#L239) 忽略 `saveProgress()` 失败。交易更新监听也需要覆盖相同问题。StoreKit 仍可能恢复永久权益，但当前实现不满足“持久化成功后完成交易”的约定。

**要求**：在服务、ShopModel 与持久化层之间传递明确的成功/失败结果；成功写盘后才完成交易。写盘失败保持可恢复的待处理状态，显示英文提示并支持重试，不要求玩家重新购买。

**验收**
- [ ] 注入存储写入失败：已验证购买不会调用 finish，也不会显示完全交付成功。
- [ ] 恢复存储后重试/重启：同一交易幂等交付，权益成功写盘后仅完成一次。
- [ ] 购买返回路径与 Transaction.updates 路径均覆盖；含等待批准后更新、恢复购买、撤销/退款。
- [ ] 取消、未验证、pending 不授予；永久外观不改变经济；重置游戏不删除合法购买权益。
- [ ] 测试真实检查“持久化成功 → finish”调用次序，并覆盖失败分支，不能只在内存数组里 append 后断言成功。
- [ ] 提交 StoreKit 本地测试证据；Sandbox/真机尚未测时单列 NOT_RUN。

## R04 · P1 · 广告奖励写盘失败不能被当作可靠发放成功

**证据**：[CampaignCoordinator.swift:208–215](https://github.com/qianquandong/AntKingdom/blob/3a6f5f92cd73950cdeec9d6da1d7de3f51670547/Packages/AntKingdomCore/Sources/AntKingdomCore/CampaignCoordinator.swift#L208) 已修改奖励账本和 boost，忽略 saveProgress 结果后返回 true。

**要求**：奖励授予结果区分已持久化、待重试、重复请求等情况。相同请求 ID 的已赚得奖励不得因去重而阻断保存重试。设计清晰的授予/持久化顺序与待处理状态，失败显示英文提示；不要让玩家为了补领再次看广告。纯本地方案不能保证持续写盘失败期间强杀仍可恢复，应如实记录该边界，不能声称无条件可恢复。

**验收**
- [ ] 强制写盘失败：不返回“已可靠保存成功”，保存错误可见；同一请求可继续完成持久化。
- [ ] 恢复存储后，无需重新看广告即可重试；恢复结果含原 request ID、boost、次数、冷却。
- [ ] 成功保存后强杀重启：奖励保留；相同回调不会再次增加次数或重置 boost。
- [ ] 重复回调、提前关闭、加载失败、无填充分别测试；失败重试不额外占用每日次数或叠加奖励。
- [ ] 原规则保持：1.25 倍/300 有效前台秒、600 秒冷却、UTC 每日 3 次、首次 Pantry + 累计 600 秒解锁；切章/重玩不重置，后台/广告展示期间不耗前台时间，离线仍为 25% 且不享受 boost。
- [ ] 用可失败 SaveStore 覆盖边界，不只测始终成功的 MemorySaveStore。

## R05 · P2 · 同步进度，收敛到可交付核心测试包

**证据**：[EXECUTION_BOARD](https://github.com/qianquandong/AntKingdom/blob/3a6f5f92cd73950cdeec9d6da1d7de3f51670547/docs/EXECUTION_BOARD.md) 仍显示客户端 NOT_STARTED；评审基线未见约定的 docs/reports 阶段报告。章节清单中 Garden Edge、Stone Corner 仍为 map:null / awaiting_A04。核心资源检查 0/17 就绪，正式美术与两张地图属于 Codex 交付依赖。

**验收**
- [ ] 更新执行看板，分别记录“已实现 / CI 通过 / 模拟器通过 / 真机未测 / 等待资源”，每项对应 SHA 与证据。
- [ ] 补齐已实际完成阶段的 docs/reports 报告和可复现启动步骤；PR 中引用的报告路径必须存在。
- [ ] 给出可在用户 Mac 复现的 M2 核心分支/commit、scheme、Xcode/SDK、安装步骤与已知缺陷。
- [ ] 核心构建不包含商店/广告入口；发行分支不算 M3/M4/M5 已验收。
- [ ] 按原 QA 矩阵由用户/Claude 完成真机生命周期、存档恢复、交互与性能测试，记录机型/OS/build/实际结果；账号/设备缺失明确标注。
- [ ] Codex 交付 A00→A03、Claude 集成、真机确认后，再组织原计划 8–12 人观察试玩；两张新增地图等 A04 输入。
- [ ] 正式资源仍有占位时保留 strict 检查失败；样张不能当作游戏贴图、真实 App Store 截图或已通过设备验收的资源。

## 回传格式与关闭条件

请为 R01–R05 各填：修复/处理提交、PR、复现步骤、适用测试及结果、CI/截图/xcresult 链接、剩余阻塞及负责人。分支的最新修复提交必须有证据，旧提交的绿色结果不能代替。

Codex 负责复核规则、美术和验收证据；Claude 负责代码修复与测试；用户参与真机试玩。R01–R04 的代码检查通过后可先报告技术修复完成，R05 的真机/美术/试玩依赖继续公开记录，不把整条 issue 提前关闭。

- [ ] R01 编译及广告生命周期
- [ ] R02 工程与测试登记
- [ ] R03 内购持久化失败
- [ ] R04 奖励持久化失败
- [ ] R05 核心交付与证据回填
