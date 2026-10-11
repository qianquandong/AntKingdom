# 一厘米蚂蚁王国 · Crumb Kingdom

竖屏 iPhone 点击与放置游戏：挖出通路，看蚂蚁搬运，通过捷径、旁路和仓库位置改变效率。

当前仓库提供 **v0.2 核心验证版 PRD 与 Python 数值工具**，尚无 iPhone 客户端。文档使用中文，玩家文案使用英文。首版聚焦一张小地图、24 只蚂蚁和一个可移动仓库；商业化与四地层暂缓。

## 从这里交给 Claude

用户已确定：**Codex 负责计划与美术，Claude 负责代码；已有 Mac；正式版免费并加入内购/可选奖励广告。** 核心验证与正式发行分阶段执行，完整流程已经写好：

| 入口 | 内容 |
|---|---|
| [CLAUDE.md](CLAUDE.md) | Claude 开工顺序、执行规则和首批任务 |
| [交付总计划](docs/DELIVERY_PLAN.md) | 分工、M0–M8 阶段、任务依赖与验收 |
| [执行看板](docs/EXECUTION_BOARD.md) | 当前状态、待定资料、报告模板、可复制给 Claude 的消息 |
| [技术交接](docs/TECHNICAL_HANDOFF.md) | Swift/SpriteKit 工程、模块、差分验证与保存契约 |
| [美术规范](docs/ART_DIRECTION.md) | 风格、尺寸、UI 状态、制作批次、商店素材 |
| [资源清单](design/asset_manifest.json) | Codex 待制作资源 ID 与交付状态 |
| [测试计划](docs/QA_TEST_PLAN.md) | 48 条客户端用例、真机矩阵、观察试玩、发行门槛 |
| [正式版增量](docs/RELEASE_SCOPE.md) | 三个小地图、一个外观商品、一个可选奖励广告 |
| [App Store 手册](docs/APP_STORE_RUNBOOK.md) | 签名、TestFlight、隐私/IAP、商店资料、提审与上线后处理 |

当前已经交付的是规则工具与计划文档；客户端、最终美术、真实支付/广告与真机测试尚待执行。Claude 从 C00 开始即可。

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
