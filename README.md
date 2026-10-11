# 一厘米蚂蚁王国 · Crumb Kingdom

竖屏 iPhone 点击与放置游戏：挖出通路，看蚂蚁搬运，通过捷径、旁路和仓库位置改变效率。

当前仓库提供 **v0.2 核心验证版 PRD 与 Python 数值工具**，尚无 iPhone 客户端。文档使用中文，玩家文案使用英文。首版聚焦一张小地图、24 只蚂蚁和一个可移动仓库；商业化与四地层暂缓。

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
