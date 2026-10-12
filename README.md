# 一厘米蚂蚁王国 · Crumb Kingdom

竖屏 iPhone 点击与放置游戏：挖出通路，看蚂蚁搬运，通过捷径、旁路和仓库位置改变效率。

`main` 提供 **v0.2 核心验证版 PRD、Python 数值工具与制作资料**；Claude 已在开发分支实现 iOS 核心客户端，尚未合入主分支或完成真机验收。文档使用中文，玩家文案使用英文。核心版聚焦一张小地图、24 只蚂蚁和一个可移动仓库。

## 从这里交给 Claude

用户已确定：**Codex 负责计划与美术，Claude 负责代码；已有 Mac；正式版免费并加入内购/可选奖励广告。** 核心验证与正式发行分阶段执行，完整流程已经写好：

| 入口 | 内容 |
|---|---|
| [CLAUDE.md](CLAUDE.md) | Claude 开工顺序、执行规则和首批任务 |
| [交付总计划](docs/DELIVERY_PLAN.md) | 分工、M0–M8 阶段、任务依赖与验收 |
| [执行看板](docs/EXECUTION_BOARD.md) | 当前状态、待定资料、报告模板、可复制给 Claude 的消息 |
| [技术交接](docs/TECHNICAL_HANDOFF.md) | Swift/SpriteKit 工程、模块、差分验证与保存契约 |
| [美术规范](docs/ART_DIRECTION.md) | 风格、尺寸、UI 状态、制作批次、商店素材 |
| [Claude 修复清单](https://github.com/qianquandong/AntKingdom/issues/6) | 编译、测试登记、购买/广告持久化和交付证据的验收条件 |
| [D-13 优先修复与真机包](docs/reviews/2026-10-11-d13-handoff.md) | Issue #11：离线收益漏算、确定性回归、模拟器与真机测试、可安装包交付 |
| [A00 主界面样张](assets/source/keyframe/README.md) | 英文主界面预览、无文字底稿、提示词与接入约束；draft |
| [A01-01 正式资源首批](assets/source/a01-01/README.md) | 9 张地形/食物源 PNG、原稿、提示词、QA 与接入标准；reviewed |
| [A01-02 通路与房间](assets/source/a01-02/README.md) | 16 种通路 + Queen/Pantry，18 PNG、连接布局检视；[Claude 接入 #13](https://github.com/qianquandong/AntKingdom/issues/13) |
| [资源清单](design/asset_manifest.json) | Codex 待制作资源 ID 与交付状态 |
| [测试计划](docs/QA_TEST_PLAN.md) | 48 条客户端用例、真机矩阵、观察试玩、发行门槛 |
| [正式版增量](docs/RELEASE_SCOPE.md) | 三个小地图、一个外观商品、一个可选奖励广告 |
| [App Store 手册](docs/APP_STORE_RUNBOOK.md) | 签名、TestFlight、隐私/IAP、商店资料、提审与上线后处理 |

Claude 下一项按 [最新复核与验收](docs/reviews/2026-10-11-followup-review.md) 执行：D-13 原问题代码/模拟器测试通过，继续 Issue #11 的签名安装与真机包交付；发行支线优先修 D-14 广告暂停收益漏洞（含两条复现测试），美术修 D-15 食物源方板并补两 scheme 验收。A01 两批 27 张已在核心分支接入，正式批准和真机验收仍未完成。A02 制作不阻塞核心安装包。

## 核心规则资料

| 文件 | 用途 |
|---|---|
| [docs/PRD.md](docs/PRD.md) | 当前唯一实现依据，包含运输、经济、验收与英文文案 |
| [docs/ROADMAP.md](docs/ROADMAP.md) | 暂缓项目与旧版历史 |
| [design/map_prototype.txt](design/map_prototype.txt) | 当前地图，9×9 地下加一行地面 |
| [design/transport_cases.json](design/transport_cases.json) | 三个独立、可手算的真实格网运输对照 |
| [tools/economy_sim.py](tools/economy_sim.py) | 共享拥堵、确定性分流、经济与离线状态推进 |
| [tests/test_economy.py](tests/test_economy.py) | 运输、建仓、刷新、容量、孵化与守恒回归 |

## 本地验证

Python 3.11+，仅使用标准库。在仓库根目录运行：

```bash
python -m unittest discover -s tests -v
python tools/economy_sim.py --check
python tools/check_map.py
python tools/check_strings.py
```

全部成功才提交。CI 重复运行同样检查；失败均返回非零退出码。

查看数值：

```bash
python tools/economy_sim.py --tables
python tools/economy_sim.py --json
```

固定对照结果：缩短路线 +28.57%，平行旁路 +63.64%，近距离卸货点 +50%。这些是冻结人口和其他变量后的机制验证，不是商业收益预测。600 秒固定地图回放达到 24 只与 1100 库存上限；当前版本只用于验证核心循环。

旧 `--ads`、`--crew`、`--casual`、`--layout` 入口已撤回；旧 [map_backyard.txt](design/map_backyard.txt) 留作路线图草案，不用于首版检查。更多背景见 [PRD 第 1、6、8 章](docs/PRD.md)。
