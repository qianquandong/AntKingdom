# 新美术核心测试包 core-art-test-1（ART_DEVICE_BUILD，Issue #11 / #17）

```text
核心 PR / SHA / tag / version(build)：PR #18 claude/a02-01-art @ cbc3275998c169bc9d7aa95e4952f14c94a2ede7 / tag core-art-test-1 / 0.1.0 (3)，AntKingdom scheme
发行 PR / SHA / 包含关系：PR #8 → #9 → #10，claude/m5-ads @ 40aa730（rebase 到 cbc3275：含 D-13 / D-14 / D-15 / D-16 与 A01/A02 44 张）
资源批次：A01-01 1.0.0（9）+ A01-02 1.0.0（18）+ A02-01 1.0.0（17）= 44 张，manifest reviewed；A02-02 不在本包（PR #20，后续 build）
交付状态：CODE_TESTS_PASSED（D-13 往返见第 2 节）→ BUILD_ARTIFACT_ONLY；SIGNED_INSTALLABLE / DEVICE_SMOKE_PASSED / DEVICE_ACCEPTANCE_PASSED 均未成立
签名安装：SIGNING_BLOCKED / NOT_INSTALLED（唯一剩余依赖：你 Mac 上 Xcode 登录的 Apple ID 与一台 iPhone）
本报告是 tag 之后的文档提交；tag 内的 BUILD.md 已指向 core-art-test-1
```

## 1. 包含什么

| 项 | 内容 |
|---|---|
| D-13 | 离线起点冻结、恢复首帧 hold、帧停顿结算（PR #12，经 282994c 合入本线） |
| D-15 | 食物源格底层铺正式土层（f7cf6e9） |
| D-16 | 卵从下单到孵化固定占自己的槽（afa4181）；存档可选字段 eggSlots，旧存档按顺序分配一次 |
| 美术 | 44 张 @3x：土层 3、石块、Cookie 有货 / 空、Sugar 有货 / 空、Sap、通路遮罩 16、Queen、Pantry、工蚁 14 帧、货物、卵两态 |
| 没有 | 商店、广告、IAP（发行检查：未链接 StoreKit / AdSupport / ATT / GoogleMobileAds） |

## 2. CI（固定 cbc3275）

CI [38335724699](https://github.com/qianquandong/AntKingdom/actions/runs/38335724699)：

| job | attempt | 结果 |
|---|---|---|
| 核心包（Linux swift:6.2） | 1 | 104/104 |
| Xcode 构建与模拟器测试 | 1 | **全部通过**：核心（macOS）104/104；单元 23/23；UI iPhone 17 / iOS 26.2 与 iPhone SE (3rd generation) / iOS 18.5 各 21/21 + 1 跳过（跳过的是需 `AK_ROUNDS` 的往返用例）；TestFlight 配置无签名编译 + 发行检查 PASS；无签名产物打包上传；录像（Pantry、A02 动作、卵 E01/E02 两机型、四向路线、A01 补给、平移缩放）与截图 |
| D-13 往返（标准 / 小屏各 10 × 65 秒） | 1 | 小屏 10/10 PASS；标准 9/10，第 10 轮 FAIL（见下） |
| D-13 往返 | 2（只重跑该 job，为补数据，不用来替代 attempt 1） | 小屏 10/10 PASS；标准第 1 轮结算正确（66.86 秒、弹 Welcome Back），之后点击 OK 遇 XCUITest “Timed out while synthesizing event”，测试中止，第 2–10 轮未执行 |

**attempt 1 标准第 10 轮**：
- 结果：离开 66.10 秒，结算 71.57 秒，多算 5.47 秒，超出 ±3 秒判定。
- 生命周期日志：离开时刻取最后一帧（比后台回调早 0.9 秒，正常）。回来时 App 先进入 `inactive`（墙钟 471.60），5.58 秒后才 `active`（477.18），这段没有任何帧；结算在 `.active` 时进行，所以多出的正是这 5.58 秒。
- 测试侧的“离开时长”在 `app.activate()` 返回时就截止了。
- 性质：不是 D-13 原问题（少算）；按现有规则，不出帧的时间都算离开（宁可多给离线收益，也不漏算）。同一份 App 代码在 a20e37b 上曾 20/20 通过。
- 回来时 `inactive → active` 的耗时：两次运行 30 个完整轮次中，29 轮在 0.27–1.35 秒，只有这一轮 5.58 秒，是孤立值，不是新美术带来的系统性变慢。
- 处理：不放宽测试判定、不改规则，失败如实保留；是否把 `inactive → active` 的系统耗时排除在离线之外，请 Codex 决定。
- 合计：在 cbc3275 上执行的 21 个往返轮次中，20 轮结算与离开时长相符，1 轮多算 5.47 秒（上述原因）。标准机型没有凑满一组完整的 10/10；没有再重跑凑数。

## 3. 下载 / 校验

| 文件（CI artifact [antkingdom-unsigned-cbc3275…](https://github.com/qianquandong/AntKingdom/actions/runs/38335724699/artifacts/11785561931)，保留到 2027-01-11） | 大小 | SHA-256 |
|---|---|---|
| AntKingdom-0.1.0-3-TestFlight-iphoneos-unsigned.zip | 1,538,002 B | `ed21bcbb201c9e8d0603b4544d9267c488e4fcbba5e0da71a06d7a2677992856` |
| AntKingdom-0.1.0-3-Debug-iphoneos-unsigned.zip（带生命周期诊断） | 1,855,662 B | `39ab230e157cda05b5f1454328bf4301ec43ef461b8d80ac1528603b31532dc4` |

本地下载复核：
- 两份 SHA-256 与 BUILD-INFO 一致。
- Info.plist：0.1.0 / 3 / com.example.CrumbKingdom / MinimumOSVersion 17.0 / iphoneos26.2；均无 `_CodeSignature`。
- `Assets.car` 1,117,464 B；包内没有任何 PNG（原稿 / QA 图未打入）。
- TestFlight 二进制不含 `-ak-scenario`、`debug.lifecycle`、`-ak-zoom`、`eggs=`；Debug 包的诊断在 `AntKingdom.debug.dylib`。

**bundle 增量**（对比旧包 0.1.0 (2)，占位美术）：

| 配置 | zip | 解压后 .app |
|---|---|---|
| TestFlight | 451,183 → 1,538,002 B（+1,086,819） | 1,641,069 → 2,817,557 B（+1,176,488） |
| Debug | 731,460 → 1,855,662 B（+1,124,202） | 2,721,189 → 4,047,509 B（+1,326,320） |

**资源核对**：
- 源文件：`import_art.py --check` 确认 44 张与交付文件逐字节一致，SHA-256 与像素与各批 metadata.json 一致。
- 运行时：AntKingdomTests 两条加载测试（A01 27 张、A02 17 张按 @3x 正确 pt 尺寸）；发行 target 另由 ReleaseArtAssetTests 从 CrumbKingdom.app 加载 44 张。

## 4. 安装（你在自己的 Mac 上）

[BUILD.md“核心真机测试包”](../BUILD.md)：Xcode 登录 Apple ID、iPhone 连线并开启开发者模式后，在仓库根目录运行：

```bash
git fetch origin --tags && git checkout core-art-test-1 && bash tools/install-on-iphone.sh
```

- 脚本做的事：本机自动签名（本机 Bundle ID）→ devicectl 安装并启动 → 打印 version / build / SHA。
- 脚本未在 Mac 上运行过，失败时用 BUILD.md 的 Xcode 手动步骤。
- 凭据只在 Xcode / 钥匙串；不要把密码、证书或描述文件贴到 GitHub。

## 5. 设备证据与验收（全部 NOT_RUN，等安装）

| 项 | 状态 |
|---|---|
| 物理 iPhone 安装启动（型号 / iOS / 0.1.0 (3) / SHA / 首屏截图含新蚂蚁、卵、房间） | NOT_RUN |
| E01 卵孵化、挖掘 / 运输 / 移仓、后台 65 秒回来总结、存档 / 杀进程恢复短视频 | NOT_RUN |
| #11 设备矩阵（10×65 秒、30 秒 / 1 小时 / 2 小时、冷启动、20 次锁屏、T24） | NOT_RUN |
| T29 24 只、全挖、频繁选择 / 移仓 30 分钟（平均 fps、p95 帧时间、内存 / 温度） | NOT_RUN（模拟器帧率不算） |
| 真实 AdMob / UMP / StoreKit | NOT_RUN（本包无广告 / IAP，不阻塞内部美术测试包；仍阻塞发行终验） |

## 6. 剩余与下一步

- 你：按第 4 节安装并回传设备信息与首屏截图，然后按 #11 / #17 的设备项逐项跑。
- Codex：
  - 复核 D-16 录像（A02-01 报告）与 D-13 第 10 轮的处理方式。
  - 复核 A02 动作录像与 A02-02 接入（PR #20）。
- Claude：A02-02 在 PR #20 走下一个 build（0.1.0 (4)），不改本 tag。
