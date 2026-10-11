# TestFlight 到 App Store 的发行手册

核对日期：2026-10-11。执行时再次检查 Apple/广告 SDK 的当前要求。此文是准备与操作清单，不代表账号已开通、资料已提交或应用已经获批。

职责：用户掌握开发者账号、真实经营资料与发行决定；Claude 负责签名/构建/技术配置/测试证据；Codex 负责商店文字、美术和产品一致性。

## 1. M0 尽早排除账号与设备阻塞

- 用户确认 Apple Developer Program 资格、Account Holder、双重认证和可用 Mac；有实体 iPhone 用于签名运行。
- 确认开发者展示主体、最终游戏名、Bundle ID、App Store Connect app 记录和 SKU。Crumb Kingdom 仍是工作名，不把名字可用性当成已验证。
- 给执行者恰当角色；账号密码、证书私钥、App Store Connect API 私钥只放钥匙串/授权密钥系统。仓库只存配置样例与非敏感 ID。
- 商业化前完成适用的付费协议、税务和银行信息；用户提供真实资料，Claude 不代编身份或财务内容。
- 记录支持邮箱、可公开访问的支持页/隐私页、广告账号、首发地区、商品 ID 和定价。缺项进入 [执行看板](EXECUTION_BOARD.md)，不需要阻塞无关的灰盒开发。

## 2. 构建与 SDK 要求

截至核对日，Apple 已公开生效的最低上传要求为 Xcode 26 或更高及 iOS 26 SDK 或更高，自 2026-04-28 生效。提交当天重新检查 [SDK 最低要求](https://developer.apple.com/news/upcoming-requirements/?id=04282026a) 与 [提交入口](https://developer.apple.com/app-store/submitting/)。不能把此 SDK 要求理解为用户必须运行 iOS 26；最低部署系统是本项目另行验证的选择。

Claude 在候选报告记录：macOS、Xcode 完整版本、SDK、部署目标、Git commit、资源版本、依赖锁文件、app version、递增 build number、签名 Team、Bundle ID 与架构。生产 Archive 在受信任 Mac 上构建并验证，保存 archive/dSYM 和校验摘要用于崩溃定位。

构建前确认：Release 配置、正式图标、所有资源已集成、没有测试商店 UI/调试入口/占位域名/模拟发奖/生产日志中的私人数据。实际资源验证与构建检查通过后，才上传 App Store Connect。参考 [Apple 构建与分发流程](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)。

## 3. TestFlight 流程

1. Claude 先在模拟器及实体设备跑对应阶段用例，创建 commit/build 对应报告。
2. 用户授权使用其账号后，Archive → Validate → Upload；等待构建处理，解决符号、SDK、隐私清单和加密声明提示。
3. Core 0.1.x 先给内部测试组；填写英文测试描述、测试重点与真实反馈邮箱。
4. 外部测试补齐 Beta App Review 信息，首次外部分发按 Apple 流程送审；批准后再邀请普通测试者，不能为了绕过外部审核给陌生人团队权限。
5. M3 用 8–12 人观察核心；M6 用 20–30 人对候选版作至少 7 天测试。测试者邀请由用户执行或明确授权后执行。
6. 每次修复递增 build，保留上一版结果并指明哪些测试重跑。TestFlight 构建通常最多可测试 90 天，临近过期要换包。

步骤与限制依据 [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)。TestFlight 通过不等于正式 App Review 通过；当前原型不能只换版本号就上架。

## 4. 隐私、权限与地区资料

| 项目 | Claude 准备什么 | 用户/最终核对 |
|---|---|---|
| SDK 清单 | 版本、用途、收集/传输数据、跟踪行为、许可证、隐私清单 | 与实际最终二进制一致 |
| App Privacy | 应用及第三方实际数据用途、关联身份/跟踪情况 | 用户在 Connect 提交真实答案 |
| PrivacyInfo.xcprivacy | Required Reason API 的实际使用与合法理由，所需 SDK 清单/签名检查 | 不复制不适用的理由代码 |
| ATT | 跟踪/IDFA 需要时才按官方流程请求，拒绝路径可正常玩 | 不奖励授权、不指纹追踪 |
| UMP | 启动更新同意、按需表单、隐私选项入口、可请求广告检查 | 不把它当 ATT 替代品 |
| 隐私页/支持页 | 英文可访问页面，联系渠道、数据用途、第三方、选择/删除说明等与事实一致 | 用户确认主体与真实联系方式 |
| 年龄分级 | 按实际内容、广告和互动能力回答新版问卷 | 不因画风可爱直接选 Kids Category 或自封分级 |
| 加密出口声明 | 核对系统与第三方 SDK 使用的加密，准备适用答案/材料 | 不习惯性把所有字段填 No |
| 无障碍声明 | 按真机已验证能力填写当前 Connect 相关字段 | 不宣称未实现的 VoiceOver 等能力 |
| 地区可用性 | 逐项检查选择地区要求，记录适用资料和状态 | 不默认全世界勾选 |

隐私填写参考 [Apple App Privacy](https://developer.apple.com/app-store/app-privacy-details/)；API 理由参考 [Required Reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)；跟踪参考 [Apple 用户隐私](https://developer.apple.com/app-store/user-privacy-and-data-use/)；UMP 参考 [Google 文档](https://developers.google.com/admob/ios/privacy)。

如选择欧盟发行，核对 [DSA trader 信息](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements)；如选择中国大陆，先核对 [对应发行资质要求](https://developer.apple.com/help/app-store-connect/manage-compliance-information/view-china-mainland-compliance-information)。地区尚未确定时标待定，不凭中文沟通推断发行地区。可访问声明参考 [Apple Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels)。

## 5. 内购与广告上线前清单

- 用户创建真实非消耗型商品，类型/ID/地区/定价与 [正式版规格](RELEASE_SCOPE.md) 一致；填写英文名称、说明、审核截图和备注。
- Claude 用 StoreKit 本地配置、Sandbox、TestFlight 验证购买成功/取消/待批准/恢复/撤销/离线；不能用假弹窗代替系统支付。完整报告绑定商品 ID 和候选构建。
- 首个该类型 IAP 与 app 版本放入同一次审核提交；参见 [Apple 商品提审](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase)。
- AdMob/UMP 完成账号与应用配置，广告 app ID 与 ad unit ID 分清；生产包使用真实配置。开发/反复测试用测试广告；正式广告进行配置和加载验证，不点击广告制造测试收入。
- 检查广告 app 审核/可投放状态、对应网站和适用 app-ads.txt 要求；未具备供给时按“不可用”安全降级，不伪造广告填充。无广告仍应能完成免费游戏。
- 同意/拒绝/受限用户分别检查网络行为。无强制插屏，无假倒计时，无付费暗示才能继续的设计。

## 6. 商店资料包

Codex 准备文案/版式，Claude 从真正的候选构建导出截图；用户确认工作名、描述、地区、支持主体和价格。需要填写的真实字段不能用 `TODO` 或示例域名上传。

| 字段 | 首版准备 |
|---|---|
| 名称 | Crumb Kingdom（工作名，需确认可用）；不超过 30 字符 |
| 副标题 | Dig, Build, Watch Ants（英文草案，不超过 30 字符） |
| 分类 | Games；子类按最终体验选择 Simulation/Strategy 等实际适合项 |
| 描述 | 说明点挖、搬运优化、三张免费地图、永久外观 IAP 与可选奖励广告；不含未实现功能 |
| Promotional Text | 可留空；需要时不超过 170 字符 |
| 关键词 | 英文相关词，最多 100 字节；不堆竞品名 |
| 截图 | 计划 5 张实际画面，按支持设备对应尺寸上传 |
| App Preview | 首发可不做，不能用宣传片替代真实玩法展示 |
| 图标 | 使用实际 AppIcon 资源，遵守当前 Xcode/Connect 校验 |
| 支持/隐私 URL | 公开可访问、内容完整；游戏设置中也可打开 |
| Review Information | 真实联系信息、操作步骤、商品/广告入口、必要说明；当前无登录，不编测试账号 |
| Version/Build/版权 | 与候选工程一致，版权主体由用户确定 |

字段限制依据 [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information) 与 [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)。截图尺寸依据 [Apple 规格](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)；不要把跨设备拉伸图当真实效果。

可用英文描述草案，**仅在以下内容全部实现和验收后才能上传**：

> Build a tiny world, one tunnel at a time.
>
> Tap to dig through soft soil, connect food to your colony, and watch your ants get to work. Open a shortcut, clear a second path, or move your Pantry closer to make every trip count.
>
> Explore three compact colonies, grow your ant family, and return to your favorite layouts. Every colony can be completed for free.
>
> Optional room decorations are available through an in-app purchase. You can also choose to watch rewarded ads for a temporary transport boost. No account is required.

审核备注的英文骨架（由 Claude 用实际入口名称和条件核对后填写）：

> No sign-in is required. Follow the opening guide to connect the Cookie Crumb. You can pause hatching from the Queen Chamber to save 50 Food and build a Pantry. The Decorate panel becomes available after the first Pantry is built. The Garden Decor Pack is a non-consumable purchase; Restore Purchases is available in Settings and the decoration panel. Optional rewarded ads become available after the first Pantry and 10 minutes of active play. Ads are never required to complete a colony. Privacy and support links are available in Settings.

补上实际审查路径、当前权限行为与必要演示附件。不要为了审核隐藏功能、偷偷解锁不同经济或添加未说明的后门。

## 7. Release Candidate 与提审动作

提审前资料包必须含：

- 对应 commit/tag、app version/build、Archive/dSYM、资源清单。
- M6 测试报告、所有发行阻断缺陷关闭证据、设备矩阵。
- 已验证的商店英文资料、截图、支持/隐私页。
- IAP 商品配置/恢复测试、广告/同意测试、SDK 隐私清单。
- 真实首发地区、价格、账号主体、联系人、发布方式。

用户检查这一份具体包，决定是否提审。Claude 随后在 Connect 选择准确 build，补齐 required fields，关联首个 IAP，Add for Review 后完成 Submit for Review；仅点击 Add for Review 不等于已送出。依据 [Apple Submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app)。

首发默认采用用户控制的手动发布：审核通过后再确认商店素材和可用性，再发布。记录审核状态、问题与回复；功能修复上传新 build，元数据问题按实际情况修订。拒审按所列问题逐项回应，不靠反复原样提交。依据 [发布选项](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/select-an-app-store-version-release-option)。

## 8. 发布当天与事故处理

发布前确认技术支持有人响应、签名/账号有效、商品可售、隐私页在线。用户发出针对该候选版的发布决定后执行；本计划本身不是未来所有版本的自动发行许可。

发布后从目标地区 App Store 真正安装，记录版本，检查首次启动、存档/离线、免费章节、商品加载/已购恢复、支持链接。不要为了验证真实扣款自动购买；生产购买测试涉及实际花费，由用户决定。

前 24 小时关注启动崩溃、清档、购买权益、广告卡死；第 2–7 天看支持问题、章节卡点、可用统计口径下的返回行为与商业化体验。Codex 决定产品/素材优先级，Claude 出修复和回归证据。

出现 SEV0/SEV1：停止扩大分发/推广，保存证据，定位并出更高版本 hotfix，必要时用户决定暂停可用性。**App Store 不是一键退回旧二进制**；Git 回退不等于用户端回滚。首版没有远程开关服务，不能把“远程关广告”写成已有救援能力。

后续更新可以考虑 Apple 的 7 天分阶段自动更新，但这不是首次发布的灰度机制，也不能阻止任何人手动下载；参见 [分阶段更新](https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases/)。

## 9. 上线完成的定义

商店页面可访问，目标地区能实际安装，下载到的版本与验收版本一致，支持渠道有人接收，首日关键路径通过，七天问题清单与下一版本计划已记录。仅“提交审核”或“审核通过”都不能写成全流程完成。
