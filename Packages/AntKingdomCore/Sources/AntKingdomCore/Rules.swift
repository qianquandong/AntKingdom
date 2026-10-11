/// PRD v0.2 第 4、5 章的固定数值，与 tools/economy_sim.py 顶部常量逐一对应。
/// 修改任何一项都必须先改 PRD 与 Python 基准，再改这里，并重新生成 design/reference。
public enum Rules {
    /// 格/秒
    public static let speed = 2.0
    /// Food/每只蚂蚁的完整运输周期
    public static let carry = 2.0
    /// 装货 2 秒 + 卸货 1 秒
    public static let handling = 3.0
    /// 每个中间通路格的搬运工服务预算（不是瞬时物理密度）
    public static let laneCapacity = 8.0
    public static let maxPaths = 4
    public static let maxMoves = 256
    public static let epsilon = 1e-10
    /// 经济基准积分步长（秒）
    public static let tick = 0.25
    public static let offlineEfficiency = 0.25
    /// 离线计时上限（秒）；生产、孵化与补给计时共同封顶
    public static let offlineCap = 3600.0
    public static let baseStorage = 100.0
    public static let pantryStorage = 1000.0
    public static let pantryCost = 50.0
    public static let hatchCost = 20.0
    public static let hatchSeconds = 30.0
    public static let populationCap = 24
    public static let larvaSlots = 2
    public static let refillSeconds = 60.0
    public static let cookieRefill = 600.0
    public static let sugarRefill = 150.0
    public static let initialAnts = 5
    /// 地面兜底源每周期额外搜寻秒数
    public static let surfaceExtraSeconds = 12.0

    // MARK: 点击挖掘（PRD 2.2；客户端规则，Python 基准按“完成一格”操作）
    /// 每个 Soil 格需要的有效点击次数
    public static let tapsPerSoil = 3
    /// 手动点击的逻辑上限：每秒 8 次
    public static let maxManualTapsPerSecond = 8.0
    /// 长按挖掘：每秒 5 次
    public static let holdTapsPerSecond = 5.0
}
