# Mac 构建与测试说明

状态：C00 起生效。本文件说明如何从干净 checkout 构建、测试并在模拟器运行 iOS 客户端。真机签名与 TestFlight 见 [App Store 手册](APP_STORE_RUNBOOK.md)，需要用户的 Apple 开发者账号，本文不涉及凭据。

## 1. 环境要求

| 项 | 要求 | 说明 |
|---|---|---|
| macOS | 能运行下列 Xcode 的版本 | 实际版本写入 `build/environment.md` |
| Xcode | 26 或更新的正式版 | App Store 上传需要 iOS 26 SDK；这是构建工具要求，**不是最低支持系统** |
| 部署目标 | iOS 17.0，仅 iPhone，竖屏 | 由 `ios/project.yml` 锁定 |
| Swift 语言模式 | 5（Swift 6 工具链编译） | 核心包 `swift-tools-version:5.10` |
| XcodeGen | 2.45.4（只在修改工程结构时需要） | 工程文件已提交，日常构建不需要安装 |
| Python | 3.11+，仅标准库 | 规则基准与文案检查 |
| 第三方依赖 | 无 | 没有 SwiftPM 远程包，因此没有 Package.resolved 锁文件；M5 引入广告/IAP SDK 时再加锁 |

## 2. 一次完整验证（仓库根目录）

```bash
python3 -m unittest discover -s tests -v
python3 tools/economy_sim.py --check
python3 tools/check_map.py
python3 tools/check_strings.py
python3 tools/export_strings.py --check
swift test --package-path Packages/AntKingdomCore
xcodebuild -list -project ios/AntKingdom.xcodeproj
xcrun simctl list devices available
```

选一台可用的 iPhone 模拟器 UUID（不要假定某个机型已安装）：

```bash
python3 ci/pick_simulator.py standard
```

把输出的 UUID 填入下面命令：

```bash
xcodebuild -project ios/AntKingdom.xcodeproj -scheme AntKingdom -destination 'platform=iOS Simulator,id=SIMULATOR_UUID' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO test
```

在模拟器运行：用 Xcode 打开 `ios/AntKingdom.xcodeproj`，选择 `AntKingdom` scheme 和一台模拟器，点 Run。

## 3. 修改工程结构

工程由 XcodeGen 从 `ios/project.yml` 生成，生成结果一起提交。新增/移动源文件或改构建设置后：

```bash
xcodegen generate --spec ios/project.yml
```

CI 会用锁定的 XcodeGen 重新生成并比对，若有差异则失败，防止直接在 Xcode 里改工程造成漂移。不要手改 `project.pbxproj`。

## 4. 配置

| 配置 | 用途 | 编译条件 |
|---|---|---|
| Debug | 开发、模拟器、调试入口（固定夹具、场景跳转） | `DEBUG` |
| TestFlight | 内部/外部测试包 | `TESTFLIGHT` |
| AppStore | 提审包（Archive 默认） | `APPSTORE` |

调试入口只编译进 Debug。Bundle ID 当前是占位值 `com.example.CrumbKingdom`，Team 为空；签名前由用户提供真实值（见 [执行看板](EXECUTION_BOARD.md) 第 3 节）。

Debug 启动参数（Xcode Scheme → Run → Arguments，或 UI 测试 `launchArguments`；Release 二进制中不存在）：

| 参数 | 作用 |
|---|---|
| `-ak-scenario <fresh\|connected\|busy\|pantry_ready\|pantry_built\|replay300\|replay600>` | 载入调试场景，使用内存存档，不碰真实存档 |
| `-ak-ephemeral` | 内存存档的新档 |
| `-ak-away <秒>` | 先在“过去”保存，再冷启动，走真实离线结算（不改系统时间） |
| `-ak-reset-save` | 启动前删除本机存档，之后照常保存（杀进程恢复测试） |
| `-ak-reduce-motion` | 强制“减少动态” |

### TestFlight 内部包（C08，签名部分待用户）

CI 已对 TestFlight 配置做无签名的真机架构编译，并用 `ci/check-release-binary.sh` 检查：版本/构建号、
最低 iOS 17.0、仅 iPhone、调试入口已剔除、未链接 StoreKit/AdSupport/AppTrackingTransparency。
用户提供 Team 与真实 Bundle ID 后，在自己的 Mac 上：

1. 在 `ios/project.yml` 写入 `PRODUCT_BUNDLE_IDENTIFIER`（三个 target 的前缀一致），`DEVELOPMENT_TEAM` 用 Xcode 账号自动签名或本机 xcconfig，不提交凭据；`xcodegen generate --spec ios/project.yml`。
2. 构建号单调递增：`xcodebuild ... CURRENT_PROJECT_VERSION=<n> archive`，`MARKETING_VERSION` 按发行计划变更。
3. Xcode Organizer → Distribute App → TestFlight & App Store（或 Internal Only），由用户确认上传。
4. 上传前 `python3 tools/check_assets.py --strict` 必须通过；占位资源不能进外部测试或提审包。

### 核心真机测试包（D-13 修复后，签名待用户）

固定版本：tag **`core-test-d13-2`** = 387ad4f，**0.1.0 (2)**。CI [38205092148](https://github.com/qianquandong/AntKingdom/actions/runs/38205092148) 全部通过（模拟器往返 20/20），资源为占位。
无签名 .app（TestFlight 与 Debug 两种配置，仅构建证据，不能直接安装）：CI artifact [antkingdom-unsigned-387ad4f…](https://github.com/qianquandong/AntKingdom/actions/runs/38205092148/artifacts/11727498357)，附 SHA-256 与 BUILD-INFO.md。
状态 **SIGNING_BLOCKED / NOT_INSTALLED**：签名需要用户自己的 Apple ID / Team，凭据只在本机钥匙串，不进仓库。
每次交付新的测试包时，把 `ios/project.yml` 的 `CURRENT_PROJECT_VERSION` 加一并打新 tag。

1. `git fetch origin --tags && git checkout core-test-d13-2 && open ios/AntKingdom.xcodeproj`
2. Xcode → Settings → Accounts 登录 Apple ID；AntKingdom target → Signing & Capabilities → Automatically manage signing，选自己的 Team，
   Bundle Identifier 改成自己的前缀（只在本机改，不提交）。个人免费账号的安装 7 天有效。
3. iPhone 连 Mac，打开 设置 → 隐私与安全性 → 开发者模式；选设备与 **Debug** 配置 Run（Debug 带生命周期诊断，
   设置 → Debug → Copy Lifecycle Log 可复制日志）。首次需在 设置 → 通用 → VPN 与设备管理 中信任开发者。
4. 按 [D-13 报告](reports/D13-2026-10-11.md) 第 7 节逐项验收并记录机型/iOS/tag/结果；无条件的项写 NOT_RUN。

## 4a. 正式资源导入约定

每个资源 ID 在客户端对应的运行时名称见 [`design/asset_runtime_names.json`](../design/asset_runtime_names.json)
（与 `ios/AntKingdom/Scene/AssetNames.swift` 一致，单元测试校验）。图片放入
`ios/AntKingdom/Resources/Assets.xcassets/<名称>.imageset`，音效放入 `ios/AntKingdom/Resources/Audio/<名称>.{caf,wav,m4a}`。

- 某资源的名称**全部**存在时客户端才整组使用正式图，缺任何一个就整组保留占位（单元测试禁止半套导入）。
- 隧道遮罩 `terrain_tunnel_masks_<0–15>`：数字为四邻相通位之和，N1 E2 S4 W8（N 为地图上方）。
- 蚂蚁帧 `ant_worker_{idle_1–2, walk_1–6, carry_1–6}`，中心锚点、朝右；`ant_cargo` 为独立叠加层。
- 有限源有货/空盘：`source_cookie_full/_empty`、`source_sugar_full/_empty`；卵 `egg_states_normal/_ready`。
- 导入后运行 `python3 tools/check_assets.py`，并把 manifest 状态从 `approved` 改为 `integrated`（真机确认后 `verified_on_device`）。

## 5. 文案

玩家可见英文只来自 PRD 附录 A。修改文案先改 PRD，再运行：

```bash
python3 tools/export_strings.py
```

生成 `ios/AntKingdom/Resources/Localizable.xcstrings`。占位符保持 `{name}`，由 `L10n` 替换。

## 6. CI

| 工作流 | 运行环境 | 内容 |
|---|---|---|
| `validate.yml` | Ubuntu，Python 3.11 / 3.14 | 规则、地图、文案、String Catalog 同步 |
| `validate.yml`（续） | 同上 | 资源就绪报告（信息性；发行前 `--strict`） |
| `ios.yml` | Ubuntu `swift:6.2` 容器 + `macos-15` runner | 核心包测试（Linux 与 macOS）、Python↔Swift 差分报告、工程漂移检查、模拟器单元/UI 测试（标准 + 小屏）、操作录像、场景与离线截图、TestFlight 配置无签名编译与二进制检查、环境记录 |

`ios.yml` 的证据（环境记录、截图、UI 附件、日志、xcresult）作为 Actions artifact 保存。它们来自 GitHub 托管 runner 与模拟器，**不是真机证据**，也不代表用户本人的 Mac 已验证。
