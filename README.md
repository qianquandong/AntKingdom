# 一厘米蚂蚁王国 · Crumb Kingdom

竖屏、单手的 iPhone 点击 + 放置 + 轻经营游戏：从一个小洞开始，亲手挖出不断生长、可以观察的地下蚂蚁世界。
英文名 **Crumb Kingdom** 为工作名（商标与重名检索见 PRD 未决事项 O1）。

## 文档

| 文件 | 内容 |
|---|---|
| [docs/PRD.md](docs/PRD.md) | MVP 产品需求文档（中文；玩家可见文案为英文，见附录 A） |
| [design/map_backyard.txt](design/map_backyard.txt) | 首张地图 Backyard 的字符布局（9 × 36 + 地面），图例见 PRD 5.1 |

## 设计工具

数值、地图、文案都可以复算，改 PRD 前后跑一遍：

```bash
python tools/economy_sim.py
```

```bash
python tools/economy_sim.py --tables
```

```bash
python tools/economy_sim.py --check
```

```bash
python tools/check_map.py
```

```bash
python tools/check_strings.py
```

- `economy_sim.py`：参考成长路径（PRD 6.4）、数值表（6.3）、死锁检查（6.5）；可加 `--layout poor`、`--casual`、`--ads`、`--crew 3` 对比情景。
- `check_map.py`：地图尺寸、占地、可达性与统计。
- `check_strings.py`：PRD 正文引用的 String ID 是否都在文案表中、英文列是否混入中文。

只依赖 Python 3 标准库。
