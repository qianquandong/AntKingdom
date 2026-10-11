# Claude 技术交接：从基准到 iPhone

状态：实现规格，尚未有客户端。核心权威为 [PRD](PRD.md) 和 [Python 基准](../tools/economy_sim.py)；正式版增量见 [RELEASE_SCOPE](RELEASE_SCOPE.md)。

## 1. 技术路线与工程交付

默认 Swift + SpriteKit 绘制地图和蚂蚁，SwiftUI 承担 HUD、面板、设置及商店；Foundation 纯逻辑包负责规则。选型是针对单平台、小地图、2D 表现作出的项目决定，SpriteKit 能力参考 [Apple 文档](https://developer.apple.com/documentation/spritekit)。不要加入 WebView 游戏层、自建后端或重型引擎来完成此首版。

M0 要记录实际 Xcode/SDK 版本、依赖锁文件与支持的最低系统。暂定部署 iOS 17.0、iPhone 竖屏；若选用 SDK 不支持，先说明差异再调整。发布所需 SDK 与部署系统是两件事，上传版本以 [上架手册](APP_STORE_RUNBOOK.md) 为准。

约定由 Claude 创建以下结构（现在这些是预期路径，并非已有文件）：

```text
ios/AntKingdom.xcodeproj                 shared scheme: AntKingdom
ios/AntKingdom/App/                      启动、生命周期、依赖组装
ios/AntKingdom/Presentation/             HUD、面板、引导、设置
ios/AntKingdom/Scene/                    渲染、镜头、手势、动画
ios/AntKingdom/Services/                 保存、时钟、音效；M5 再加支付/广告
ios/AntKingdom/Resources/                英文 String Catalog、资源、地图
ios/AntKingdomTests/                     平台服务集成测试
ios/AntKingdomUITests/                   UI 冒烟与无障碍标识
Packages/AntKingdomCore/                 纯逻辑、地图、状态、命令、求解器
Packages/AntKingdomCore/Tests/           规则与差分回归
docs/reports/                           阶段报告，不能提交私人测试者信息
```

M0 在 Mac 创建并验证 Xcode 工程，提交 shared scheme。若使用工程生成器，必须锁版本、提交配置，并给出一条生成命令；不能只有一堆 Swift 文件却没有可构建工程。缺真实账号时先跑模拟器，不伪造 Team ID。

交付后至少可执行以下命令；Claude 应用实际可用模拟器 UUID 替换 `SIMULATOR_UUID` 并记录，不能假定某个机型已安装：

```bash
swift test --package-path Packages/AntKingdomCore
xcodebuild -list -project ios/AntKingdom.xcodeproj
xcrun simctl list devices available
xcodebuild -project ios/AntKingdom.xcodeproj -scheme AntKingdom \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UUID' test
```

## 2. 模块和接口契约

| 模块 | 输入/职责 | 输出/约束 |
|---|---|---|
| MapDefinition | 符号、坐标、占地、初始通路、源 | 有版本和稳定 ID；启动校验；不把房间贴图当碰撞数据 |
| GameState | 地图、库存、蚂蚁/卵、仓库、源、刷新与设置 | 可序列化的唯一逻辑事实；渲染不能私改 |
| GameCommand | 挖格、建仓、移仓、暂停孵化、重置 | 校验后原子生效；失败不部分扣费 |
| TransportPlanner | 格网、卸货点、源需求、参数 | 路径/分配/共享负载/Trip/流量；稳定排序 |
| EconomyStepper | GameState + 已验证时长/模式 | 固定步推进；收入、支出、有限源变动可对账 |
| ClockAdapter | 前台单调时钟、后台保存的墙钟 | 钳制负离线时长；同一次恢复只结算一次 |
| SaveRepository | 状态、schema、备份 | 原子写入/迁移/损坏恢复；能注入假存储测试 |
| ScenePresenter | 只读快照、逻辑事件、资源 ID | 节点/动画更新；到达粒子不发钱 |
| StoreService（M5） | 商品加载、购买、交易更新/恢复 | 已验证权益；UI 按本地化价格显示 |
| AdsService（M5） | 同意状态、用户主动请求、SDK 事件 | 发奖事件幂等；失败回到可玩的游戏 |

GameState 由单一执行上下文顺序修改。渲染和 SDK 回调转成命令排队，避免后台返回/广告回调/保存同时修改余额。规则层不导入 SpriteKit、SwiftUI 或广告 SDK。

## 3. 数值移植不能改变的细节

- 坐标 x 向右、y 向下；SpriteKit 坐标转换只在表现层做，地图数据不反转。
- BFS 起点按 y、x 排序，邻居上/左/右/下，候选最多 4 条。Swift Set/Dictionary 的枚举顺序不可作为决策顺序。
- 单程长度下限 1；装卸两端不计拥堵；共享中间格累加全部需求；每次试分流重算全体流量。
- 一次分流一只，严格改善 1e-10，最多 256 次；未收敛报开发错误，记录触发状态，不用随机数“修好”。
- 金额/时长使用 Double，显示时格式化，逻辑不反复取整。Trip 是完整往返周期。
- 0.25 秒步进；帧率 30/60/120 不改变收益。使用累积器和事件边界；UI 每帧读取快照，不按帧数发钱。保存未用完的累积时间或先按明确边界结算，避免重复/丢失时间。
- 完整复现 PRD 的步内顺序、源优先级和空补给计时；不能为了动画效果多给一笔 Food。
- 孵化/资源/地图动作在同一输入时刻保持一致顺序。600 秒回放按现有脚本的行动先后执行。
- 缓存键包含地图、卸货点、源和人口；建仓/移仓/源变化之后不得继续用旧路线。

## 4. 差分测试与检查命令

Claude 把 [transport_cases.json](../design/transport_cases.json) 作为双方共享输入。生成 Python `--json` 输出为对照，Swift 对每个场景比较流量、最大负载、路线分配与收敛状态；流量绝对误差不超过 1e-5 Food/min。原始高精度输出与显示舍入分开。

再重放真实地图 600 秒：24 只、0 卵、库存 1100、搬入 1530、支出 430、刷新 2 次；验证整个过程的容量、人口与资源守恒，不只硬编码最终数字。

移植 [现有测试](../tests/test_economy.py) 的有意义行为；增加存档往返、更新迁移、帧率/分段推进、浮点尾差、重复生命周期通知。若分段推进与基准不同，明确时钟边界并修模型/双方测试，不能擅改 golden 数字。

保留现有 Python CI。C08 新增 Mac CI：纯 Swift 测试、模拟器构建/冒烟、差分报告；不在普通 PR 上使用发行签名或生产广告。Mac runner/Xcode 版本在 CI 明确固定或记录，运行环境变更可追溯。

## 5. 保存、离线、重置与迁移

schema 版本与应用版本分开。存档包含 PRD 字段及事件去重所需字段；不保存可信 IAP 凭据作为唯一权益证据。写入临时文件、完成后原子替换，保留最近有效备份。损坏不能直接清空玩家进度而无提示。

恢复一次后台区间使用一次消费标记/已结算时间，避免 scenePhase 与通知重复触发离线。前台用单调时钟；墙钟只用于后台差值和持久化；负时差归零。跨版本测试先复制存档，严禁用用户真实存档做破坏性实验。

重置核心地图须二次确认。正式版分开“重玩本章”和“重置本地进度”；购买的永久外观权益不被地图重玩清除。全本地进度重置后也能从 StoreKit 恢复商品。

## 6. 资源、文案与构建隔离

资源遵守 [美术规范](ART_DIRECTION.md)，ID 与 [manifest](../design/asset_manifest.json) 对应；缺图在 debug 显示明确占位，在 release 验证中失败。任何图片不得包含作为 UI 使用的烘焙文字。

使用英文 String Catalog，避免散落硬编码；P0 ID 以 PRD 附录 A 为准。M4/M5 新文案在 [正式版增量](RELEASE_SCOPE.md) 登记后纳入检查；Apple/广告系统 UI 的语言由系统和 SDK 控制，不伪造系统弹窗。

至少隔离 Debug、TestFlight、AppStore 的配置。调试地图加载/加资源入口只在 Debug；测试广告用于开发与测试；正式包检查真实广告配置、IAP 产品、支持 URL 和隐私 URL，无占位、无测试 UI、无明文密钥。

提交代码和小型源资源；构建产物、DerivedData、签名、个人设备标识、私人测试录像不入公开仓库。报告放摘要和脱敏路径/受控证据链接。

## 7. Claude 每阶段的工程交付

工程可构建；操作说明可复现；测试命令与实际结果；存档 schema 变更；资源版本；新依赖清单；截图/录像；已知缺陷与下一步。没有证据的项标明未运行，不能把未来任务写成已通过。
