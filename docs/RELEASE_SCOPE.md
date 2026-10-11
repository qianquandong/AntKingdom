# 正式版增量：完整内容、一个商品、一个奖励广告

状态：M4–M6 的设计规格，**尚未实现，也未通过经济/商店测试**。用户已选择免费游戏加内购或可选奖励广告。本版采用各一个产品做验证；P0 核心原型保持无商业化。

这份文件不改变 [PRD v0.2](PRD.md) 的默认数值与基准。Claude 在 M4/M5 加入扩展时需同步模型、文案和测试，保证关闭商业化后原有结果仍成立。

## 1. 从原型走向完整 1.0

正式定位：一款可逐步完成、可重玩的小型蚁群经营游戏。继续保留点挖、观察搬运和改善路线；不宣传无限世界、战斗或已经不存在的长线系统。

| 内容 | 1.0 具体要求 |
|---|---|
| 免费章节 | 三张 9×9 地下地图，顺序解锁；全部免费 |
| 地图 1 | Backyard，复用核心地图，教授接通/孵化/仓库 |
| 地图 2 | Garden Edge，Codex 设计一处可绕行瓶颈，有固定人口下可复算的旁路收益 |
| 地图 3 | Stone Corner，Codex 设计两处有用的仓库位置，强调源切换后的重新布局 |
| 地图间复用 | 相同地形类型、人口上限、源规则、仓库与资产体系，不加新货币/职业/地层 |
| 每章主目标 | 接通 Cookie、建成 Pantry、达到 24 成年蚂蚁且库存 1100；完成后解锁下一章 |
| 每章探索目标 | 接通 Sugar 与 Sap；至少一次固定人口/同源下增益≥5%的布局改变；非解锁硬门槛 |
| 完成状态 | 完成页、已获目标、下一章或自由调整；不会在库存满时给出无意义广告催促 |
| 重玩 | 本章重新开始需确认；保留已解锁章节、已完成目标和已购买外观 |
| 跨章状态 | 每章独立存档，只推进当前所选章节；切换章节先保存，非活动章节不后台产粮 |
| 离线 | 只结算离开时的活动章节一次；原 25%/1 小时规则不变 |

第二/三地图由 Codex 在 A04 交付字符布局、源/房间占地、免费完成操作回放和优化前后对照；Claude 实现数据加载与验证。内容验收前它们是待交付项，不能复制同一地图改名算作三个章节。

内容目标假设：三张图能提供约 30–60 分钟首次探索，不靠强制广告和长等待拉长。用真实试玩记录验证，并根据结果调整地图；时长不是 Apple 的审核保证。若三图仍只有机械等待，M4 不通过，先改内容。

## 2. IAP：Garden Decor Pack

| 项目 | 规格 |
|---|---|
| 类型 | 非消耗型，一次购买永久拥有 |
| 英文名 | Garden Decor Pack |
| 内容 | Queen Chamber 与 Pantry 各一款植物主题外观 |
| 数值影响 | 零；不改变速度、容量、人口、碰撞或地图解锁 |
| 商品 ID | 以最终 Bundle ID 为前缀，后缀 `.garden_decor`；M5 登记真实 ID |
| 定价 | 初始评估假设 US$2.99；用户在商品创建前确定实际价格及地区，不把假设写死到 UI |
| 入口 | 首次 Pantry 建成后可进入外观面板；支持免费预览和返回默认外观 |
| 恢复 | 设置和商品面板提供 Restore Purchases；重装/换机可恢复同一 Apple 账号权益 |

Claude 使用 StoreKit 2，价格来自实际 Product 的本地化显示。商品未加载时显示不可用/重试，不显示假价格或可点的空购买按钮。仅已验证交易给予权益；监听后续交易更新，持久化已验证权益后完成交易，重复回调不重复授予。

用户取消、待批准、网络错误、验证失败、退款/撤销分别处理；退款后移除该权益并回退默认外观，不删玩家地图。离线已拥有用户可使用最近有效权益缓存；联网后再核对，不能离线把所有商品免费解锁。无账号体系，地图重置与购买权益分离。

必须经过本地 StoreKit 配置、Apple Sandbox、TestFlight 三层验证。首次提交该非消耗型商品与新 app 版本放进同一审核提交，参见 [Apple IAP 提审说明](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase)。

## 3. 可选奖励广告：Foraging Boost

这是首个待验证奖励方案；不销售免广告包，因为游戏没有强制广告。广告存在于主动打开的奖励面板，不自动弹出、不在失败时弹出、不挡住免费下一章。

| 项目 | 规格 |
|---|---|
| 奖励 | 300 秒有效前台游玩时间内运输流量×1.25 |
| 解锁 | 首次 Pantry 已建成，且累计有效前台游玩达到 600 秒 |
| 可领取条件 | 无生效中的 boost、仓库未满、冷却结束、当日未达上限、广告可用 |
| 频率 | 两次成功领取间隔至少 600 秒有效前台时间，每 UTC 日最多 3 次 |
| 叠加 | 不叠加；生效中不能再次播放领取 |
| 时间 | 游戏前台正常运行时消耗；应用后台和全屏广告展示时暂停 boost 计时 |
| 离线 | 不放大离线产量，剩余 boost 时间保存到下次前台使用 |
| 无广告/拒绝隐私授权 | 正常免费游玩；入口展示不可用或返回，无资源惩罚 |

M5 给模型增加独立 `transport_multiplier`，不能把原本仅为 0…1 的离线效率参数粗暴改作广告倍率：

```text
前台：effective_rate = base_route_rate × (boost_active ? 1.25 : 1.0)
离线：effective_rate = base_route_rate × 0.25
credited_food = min(effective_rate × dt, source_remaining, free_storage)
```

吞吐能力与 UI 同步，带星点/轻微光晕表示辅助状态，不制造新的真实蚂蚁、不改人口；动画不能另发收入。Trip 仍代表基础运输周期，boost 明确单独显示，不能把它伪装成纯路线优化。route_improved 统计冻结倍率，只测布局。

奖励时钟保存剩余秒数，重启不能重领/重置；一次 grant 使用一次性请求 ID，在同一持久化事务中记录去重与奖励。跨日计数与最近已处理日期持久化，日期回拨不提前清零；首版不把它当服务端反作弊。

累计前台时间、首次建仓成就、boost、冷却、日次数与交易去重属于全局进度；切换或重玩章节不重置它们。boost 作用于当前活动章节，剩余时长随全局进度保存；章节重玩不能刷新的奖励次数。

广告关闭不是发奖条件。只响应 SDK 已赚得奖励回调；成功回调后即使关闭/应用恢复通知重复，也只授予一次。提前关闭或播放失败无奖励，无扣资源。广告展示期间暂停当前前台步进；应用实际转后台时仍使用正常离线规则，不能同时算前台和离线。奖励回调到达后立即保存，再恢复游戏。

开发/测试使用专用测试广告，不反复点击生产广告。采用单一 AdMob + UMP 集成，不在首版加入中介网络；实际依赖版本由 Claude 接入时核对并锁定。参见 [Google 奖励广告指南](https://developers.google.com/admob/ios/rewarded) 和 [测试广告说明](https://developers.google.com/admob/ios/test-ads)。

## 4. 隐私与数据边界

Core 阶段只记录本地调试事件；正式版默认不再加独立第三方行为分析 SDK。可先用 App Store Connect/广告后台的可用聚合报告、TestFlight 崩溃和人工访谈评估；说明数据覆盖范围，不能把未授权样本当全体。

M5 必须盘点最终 SDK 的真实网络和数据行为，更新 App Privacy、隐私政策及 PrivacyInfo.xcprivacy。加入广告后不能沿用原型的“未收集数据”假设。是否要求 ATT 依据是否发生跟踪/访问 IDFA，而不是仅看“有没有广告”；拒绝跟踪后不能换另一个 ID 跟踪，也不能以奖励换取跟踪同意。依据 [Apple 用户隐私说明](https://developer.apple.com/app-store/user-privacy-and-data-use/)。

UMP 在每次启动更新同意状态，按需显示表单；广告请求前检查 SDK 的 canRequestAds，设置页按要求提供 Privacy Choices；它不替代 ATT。实际地区与 SDK 版本需要在接入时复核。依据 [Google UMP 文档](https://developers.google.com/admob/ios/privacy)。

## 5. 商业化必须补充的验证

无广告、一次 boost、达到频次上限三条实际地图回放；比较首次 Pantry/完成一章的时刻、有限粮扣减、容量、孵化、付费点触达。至少覆盖 boost 剩 0.1 秒、跨后台/跨日、满仓、有限源耗尽、双回调和崩溃重启。不能只把最终 Food 乘 1.25，然后称为付费收益预测。

IAP 对经济的影响必须为零。确认拒绝广告不影响免费完成，广告入口不在第一轮教学中弹出。收益记录区分购买总额、平台结算口径和广告报告；小样本不外推一亿元营收。

## 6. 新增英文文案登记

这是正式版新增表；由 `tools/export_strings.py` 导出为 `ios/ReleaseTrack/Resources/Release.xcstrings`（只打进发行轨 target），`tools/check_strings.py` 校验 ID 唯一、与核心表不重复、无中文、占位符与长度。标注 C10 的行由 Claude 在实现章节时登记。核心 55 条继续使用；不要重用一个 ID 承载不同意义。

| String ID | English Text | 最大字符数 | 说明 |
|---|---|---:|---|
| `chapter.select` | Choose a Colony | 24 | 章节页 |
| `chapter.garden_edge` | Garden Edge | 20 | 第二章 |
| `chapter.stone_corner` | Stone Corner | 20 | 第三章 |
| `chapter.locked` | Complete the previous colony to unlock. | 48 | 解锁条件 |
| `chapter.complete` | Colony Ready! | 24 | 正式完成页 |
| `chapter.next` | Next Colony | 20 | 下一章 |
| `chapter.replay` | Start This Colony Again | 28 | 重玩 |
| `chapter.replay_confirm` | Restart this colony? Your unlocks and purchases will stay. | 80 | 确认 |
| `chapter.keep_building` | Keep Building | 20 | 留在本章 |
| `shop.title` | Decorate | 20 | 外观页 |
| `shop.garden_pack` | Garden Decor Pack | 28 | 商品 |
| `shop.garden_description` | Two cozy room styles. Yours to keep. | 64 | 商品内容 |
| `shop.preview` | Preview | 16 | 预览 |
| `shop.buy` | Buy for {price} | 24 | 本地化价格 |
| `shop.owned` | Owned | 16 | 已拥有 |
| `shop.equip` | Use This Style | 24 | 启用 |
| `shop.default` | Use Default Style | 24 | 恢复默认 |
| `shop.restore` | Restore Purchases | 24 | 恢复入口 |
| `shop.restored` | Purchases restored. | 40 | 成功 |
| `shop.restore_empty` | No purchases found for this account. | 48 | 无权益 |
| `shop.pending` | Your purchase is awaiting approval. | 48 | 待批准 |
| `shop.unavailable` | The shop is unavailable. Please try again later. | 64 | 网络/商品异常 |
| `shop.failed` | Purchase not completed. Please try again. | 64 | 失败 |
| `shop.loading` | Loading... | 16 | 商品/购买进行中（转圈的无障碍标签，C11） |
| `shop.preview_end` | End Preview | 16 | 结束免费预览（C11） |
| `shop.save_failed` | Purchase received but not saved yet. Tap Try Again. You won't be charged twice. | 88 | 已验证购买写盘失败：交易未完成，重试写盘不重新购买（R03） |
| `reward.title` | Foraging Boost | 24 | 奖励名 |
| `reward.description` | Watch an ad for 25% more transport for 5 minutes of active play. | 80 | 明确交换内容 |
| `reward.watch` | Watch Ad | 16 | 主动播放 |
| `reward.not_now` | Not Now | 16 | 返回 |
| `reward.loading` | Loading Ad... | 24 | 加载 |
| `reward.unavailable` | No ad available. You can keep playing. | 48 | 无填充/离线 |
| `reward.active` | Boost: {time} remaining | 32 | 剩余时间 |
| `reward.daily_limit` | More boosts tomorrow. | 32 | 日上限 |
| `reward.cooldown` | Boost ready in {time} of active play. | 48 | 冷却 |
| `settings.privacy` | Privacy Policy | 24 | 页面链接 |
| `settings.privacy_choices` | Privacy Choices | 24 | UMP 入口 |
| `settings.support` | Help & Support | 24 | 支持 |
| `goal.connect_cookie` | Connect the Cookie Crumb | 40 | 章节主目标 1（C10） |
| `goal.build_pantry` | Build a Pantry | 40 | 章节主目标 2（C10） |
| `goal.full_colony` | Grow to 24 ants and 1,100 Food | 40 | 章节主目标 3（C10） |
| `goal.connect_sugar` | Connect the Sugar Drop | 40 | 探索目标（C10） |
| `goal.connect_sap` | Connect the Sap Root | 40 | 探索目标（C10） |
| `goal.better_route` | Make a route 5% faster | 40 | 探索目标：冻结人口与源下布局改善 ≥5%（C10） |
| `goal.done` | Goal complete: {goal} | 60 | 达成提示，{goal} 为上面六条之一（C10） |
| `chapter.main_goals` | Main Goals | 24 | 完成页/章节页小标题（C10） |
| `chapter.extra_goals` | Extra Goals | 24 | 完成页/章节页小标题（C10） |
| `chapter.completed` | Completed | 16 | 章节状态（C10） |
| `chapter.playing` | Playing | 16 | 当前章节（C10） |
| `chapter.goal_count` | {done}/{total} goals | 24 | 章节页进度（C10） |
| `settings.reset_all` | Reset All Progress | 24 | 正式版设置：重置全部本地进度（C10） |
| `dialog.reset_all` | Reset every colony? Unlocks and goals will be lost. Purchases stay. | 80 | 二次确认（C10） |
| `error.chapter_save` | This colony's save can't be loaded. Start this colony again? | 72 | 单章存档不可用（C10） |
| `error.progress_newer` | This progress was saved by a newer version. Please update the game. | 80 | 全局进度来自更新版本（C10） |

系统购买弹窗、ATT 和 UMP 文案按系统/SDK 正规流程处理；不把假系统界面当本游戏美术。正式版移除或替换 `goal.prototype_complete`，文案检查应区分核心测试构建与发行目标。
