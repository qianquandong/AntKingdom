# Claude 更新复核：广告暂停、食物源底板与真机包交付

复核时间：2026-10-11（America/Chicago；部分 CI 时间为 10-12 UTC）。主责：Claude 修代码/测试/构建，Codex 复核与美术，用户完成本机签名授权及物理设备操作。

## 结论与执行顺序

核心 D-13 原问题已有代码和自动化修复证据；不能再写“根因未确认”。核心资源分支 `d5251f62d6ba7a3bccf8589d65e6555e5521aa5d` 本地 Swift 91/91、Python 31/31 通过；27 张 @3x PNG 与交付源逐字节一致。CI `38191008410` 的标准/小屏各 10 轮后台 65 秒记录均通过。该结论不等于广告分支、最终美术、签名安装或真机验收通过。

1. **先交可安装核心测试版**（AntKingdom，无商店/广告入口），沿用已验证 D-13 基线；签名条件具备后实际安装。A02 新美术不阻塞该包。
2. **修 D-14 广告暂停漏洞**（发行分支 PR #10），补自动化与集成时序测试，不扩展新商业化功能。
3. **修 D-15 食物源方形底板，补 A01 两 scheme 的视觉验收**（PR #14/#15、Issue #13）。
4. 核心安装/离线回归稳定后独立接入 A02-01 角色素材，资源状态按证据推进。

## D-14：广告暂停没有进入生命周期状态机

复核基线：`claude/m5-ads @ ff923935ac7bf151ec389f1754a66e0fec7b5096`。

- `CampaignModel.swift:111–118` 的 `suspend(true)` 只设置 controller.isSuspended；直到广告结束才 `restartFrameClock()`。
- `GameController.frame` 先调用 `admitFrame`，后判断 `isSuspended`。前者可以已经执行离线结算、存档、呈现总结。
- `LifecycleCoordinator.enterBackground` 用最后一个前台帧作为离开时间。当广告遮住 SpriteKit、不再出帧时，最后一帧可能在广告开始之前。

### 两条确定性复现

测试源：[D13AdInterruptionReviewTests.swift](repro/D13AdInterruptionReviewTests.swift)。原始输出：[d13-ad-repro.log](evidence/d13-ad-repro.log)。这些测试在隔离的代码副本上运行，未混入已通过的原测试数量。复现的是实际核心 API 的调用顺序；尚非 SDK/真机实测。

| 场景 | 操作顺序 | 基线结果 | 期望 |
|---|---|---|---|
| 广告期间按 Home | 前台一帧 → 广告无帧 30 秒 → enterBackground → 65 秒 → becomeActive | simulatedSeconds = **95** | 只结算真正后台的 **65** 秒，不含广告展示的 30 秒 |
| 广告关闭回调前恢复一帧 | 前台一帧 → 广告无帧 30 秒 → `admitFrame`（此时仍 suspended） | `.resumed`；Food 0→约 **12.5**，elapsed 0→30，消耗源库存 | 展示期间状态不变；不做离线结算，不出 Welcome Back |

在包含 CampaignCoordinator 的发行工作分支，将该测试复制到 `Packages/AntKingdomCore/Tests/AntKingdomCoreTests/`，执行：

```bash
swift test --package-path Packages/AntKingdomCore --filter D13AdInterruptionReviewTests
```

原用例描述当前接线顺序。修复若新增正式 pause API，应把测试接到该 API，并同时增加 GameController/CampaignModel 的集成断言；不能通过在测试里提前调用 `restartFrameClock()` 或删除断言掩盖缺少生产接线的问题。

### 修复与验收

- [ ] 生命周期能区分正常前台、主动广告暂停、真正后台；广告开始、结束、失败、提前关闭都成对、幂等处理。
- [ ] 暂停检查在所有可能的收益结算之前生效；不要只把 `guard` 提前而遗留后台起点错误。
- [ ] “广告 30 秒 + 后台 65 秒”精确按后台 65 秒的 25% 参考模拟逐字段比较；广告期间有/无 SpriteKit 帧均一致。
- [ ] “首帧先于广告关闭回调”不结算广告，不推进 Food/hauled/源/卵/人口/补给/boost/有效前台秒；关闭后正常继续。
- [ ] 覆盖广告中按 Home/锁屏、回前台但广告仍开、重复后台/active/关闭回调、完成/取消/失败、保存失败与恢复；不双发广告奖励。
- [ ] 保留 D-13 恢复首帧 hold、防保存覆盖离线起点、回拨、离线 1h cap 和短离开结算规则；原回归继续通过。
- [ ] Core 纯 Swift、Controller/Campaign 集成、两个 scheme 适用 UI 测试、规则/文案/差分、无签名编译与发行检查通过；提供固定 SHA/CI run/attempt。
- [ ] SDK/真机广告时序无条件执行的部分先用 fake service 可控回调覆盖；真实 SDK 无条件时明确 NOT_RUN，不冒称已通过。

## D-15：透明食物源底下仍露出浅色方板

基线：`d5251f6`；[实际模拟器截图](evidence/A01-02-core-tunnel-pantry.png)。Cookie、Sugar（以及同一绘制路径的 Sap）透明 padding 内露出浅色矩形。

`roomNode` 已清除源节点的填色/描边，但底层 `tileNodes` 的 `baseColor` 对非土/石/地表默认返回 tunnel 色；不可通行的 source 格在 `applyTileTexture` 中没有正式底纹，矩形仍在。不要裁透明 padding、扩大食物覆盖方板或重画资源绕开底层问题。

- [ ] source 格使用符合场景的正式土层底纹；透明区域自然露出土层，食物外缘无浅色方板、双重边框或灰边。
- [ ] Cookie 96pt，Sugar/Sap 48pt，中心锚点不变；源格始终不可通行（包含 empty），不修改路线/碰撞/经济。
- [ ] Cookie 与 Sugar 有货→耗尽→补给连续录屏，轮廓、位置、大小稳定；Sap 单态正常。选择描边独立可见。
- [ ] 标准与小屏、原尺寸/总览/最大缩放截图；D-15 修复前后同场景对照。

## A01 剩余验收

- [ ] AntKingdom 与 CrumbKingdom 使用同一已确认资源/渲染修复，均编译并回传截图；“共享目录”不是发行 target 已验证。
- [ ] 16 通路遮罩/64 条边可逐项核对；0 号可用独立展示 fixture；不以游戏中不可达为由漏检资源。
- [ ] 连续挖格、保存重开无旧边；Pantry 建造/移动后无旧贴图、重复节点、占位货架线。
- [ ] Queen 0/1/2 卵、暂停孵化/完成；蚂蚁、食物、选中和摆放反馈不被房间覆盖。
- [ ] 原尺寸/总览/放大与慢速平移观察接缝和闪线；模拟器可先做录像，真机另列，不能把全部检查都推给用户。
- [ ] 不将 `reviewed` 批量改 `approved`；strict 资源门槛保持，缺项明确列出。

## D-13 核心真机包的交付与关闭标准

原 Issue #11 保持开放，代码修复状态与安装/真机状态分开。旧 tag `core-test-d13-1` 是源码定位，不是已交付安装包；当前 CI 只上传日志、截图/录像、xcresult，未提供可安装产物。

- [ ] 固定 commit/tag + **已填写的** version/build + AntKingdom scheme/configuration + Xcode/SDK + 资源版本 + 已知限制。不要让构建号停留“安装时填写”。
- [ ] 先独立完成无签名构建、日志及校验；提供可下载的 unsigned `.app` 压缩包/归档（注明仅构建证据、不能直接安装），避免只有日志。Debug 诊断包与发行配置检查分开。
- [ ] 使用用户 Mac 已配置的 Apple ID/Team/Bundle ID/设备，完成 Xcode Run、签名导出或 TestFlight 中一种实际安装路径；不索要或提交密码/私钥。需要用户操作时只列必须的步骤与准确阻塞。
- [ ] 最终交付可安装的签名产物或可访问 TestFlight build，或固定源码版本经 Xcode 成功安装的设备记录；记录版本/build、SHA、机型、iOS、安装成功截图和启动截图。没有安装证据保持 SIGNING_BLOCKED / NOT_INSTALLED。
- [ ] 真机 10×65 秒往返、30秒/1h/2h、冷启动、20次锁屏、T24 回拨（不可执行注明 NOT_RUN），逐项导出日志；复用原 D-13 交接表。
- [ ] iOS 17.x 没有设备/runtime 时写 NOT_RUN；不把最低版本编译当运行验证。未测试不能标 verified_on_device。
- [ ] 更新当前执行看板和交付报告，保留历史失败；核心包交付不等待 A02/发行商业化支线。

## 证据索引

- [D-13 CI 20 轮](https://github.com/qianquandong/AntKingdom/actions/runs/38191008410)，基线 f930e13。
- [A01-02 CI](https://github.com/qianquandong/AntKingdom/actions/runs/38199223850)，e563b12；后续 d5251f6 仅文档/证据更新。
- [复核核心 Swift 91/91 日志](evidence/a01-core-swift.log)。本地 Linux Swift 6.2.4；未替代 Xcode/设备验收。
- [原 D-13 交接](2026-10-11-d13-handoff.md)、Issue #11、Issue #13、PR #10/#12/#14/#15。
