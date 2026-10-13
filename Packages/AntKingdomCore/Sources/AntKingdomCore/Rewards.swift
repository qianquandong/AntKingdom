import Foundation

/// 正式版可选奖励广告 Foraging Boost 的规则（RELEASE_SCOPE 第 3 章，C12），逐项对应
/// tools/economy_sim.py 的 BOOST_* 常量与 RewardLedger。修改先改规格与 Python 基准。
public enum BoostRules {
    public static let multiplier = 1.25
    /// 有效前台秒
    public static let duration = 300.0
    /// 首次建成 Pantry 后、累计有效前台达到此值才解锁（不在第一轮教学中出现）
    public static let unlockForeground = 600.0
    /// 两次成功领取之间的有效前台秒
    public static let cooldown = 600.0
    /// 每 UTC 日
    public static let dailyLimit = 3
    /// 记住的一次性请求 ID 数（去重用）
    public static let rememberedRequests = 32
}

/// 奖励广告的全局账本：只按有效前台秒推进（后台、广告展示期间不推进），保存剩余秒数；
/// 一次授予使用一次性请求 ID 去重；日期取高水位，回拨不提前清零。首版不是服务端反作弊。
/// 切换或重玩章节不重置它（全局进度）。
public struct RewardLedger: Codable, Equatable, Sendable {
    public enum Status: String, Equatable, Sendable {
        case locked, active, cooldown, dailyLimit, storageFull, unavailable, ready
    }

    public var foreground = 0.0
    public var boostRemaining = 0.0
    /// 上次成功领取时的累计前台秒
    public var lastGrantForeground: Double?
    /// 最近处理过的 UTC 日序号（高水位）
    public var dayIndex: Int?
    public var dayCount = 0
    public var processedRequests: [String] = []

    public init() {}

    public static func utcDay(_ wallSeconds: Double) -> Int {
        wallSeconds.isFinite ? Int((wallSeconds / 86_400).rounded(.down)) : 0
    }

    /// 与 Python RewardLedger.status 相同的判定顺序。
    public func status(pantryBuilt: Bool, storageFull: Bool, day: Int, adAvailable: Bool = true) -> Status {
        if !pantryBuilt || foreground < BoostRules.unlockForeground - Rules.epsilon { return .locked }
        if boostRemaining > Rules.epsilon { return .active }
        if let last = lastGrantForeground, foreground - last < BoostRules.cooldown - Rules.epsilon { return .cooldown }
        if let stored = dayIndex, max(day, stored) == stored, dayCount >= BoostRules.dailyLimit { return .dailyLimit }
        if storageFull { return .storageFull }
        if !adAvailable { return .unavailable }
        return .ready
    }

    /// 冷却还剩多少有效前台秒（无冷却为 0）
    public var cooldownRemaining: Double {
        guard let last = lastGrantForeground else { return 0 }
        return max(0, BoostRules.cooldown - (foreground - last))
    }

    /// 只在广告 SDK 的“已赚得奖励”回调里调用；同一请求重复回调返回 false，不重复授予。
    @discardableResult
    public mutating func grant(requestId: String, day: Int) -> Bool {
        guard !processedRequests.contains(requestId) else { return false }
        processedRequests.append(requestId)
        if processedRequests.count > BoostRules.rememberedRequests {
            processedRequests.removeFirst(processedRequests.count - BoostRules.rememberedRequests)
        }
        if dayIndex == nil || day > dayIndex! {
            dayIndex = day
            dayCount = 0
        }
        dayCount += 1
        boostRemaining = BoostRules.duration
        lastGrantForeground = foreground
        return true
    }

    public func validate() throws {
        let numbers = [foreground, boostRemaining] + [lastGrantForeground].compactMap { $0 }
        guard numbers.allSatisfy({ $0.isFinite && $0 >= 0 }), boostRemaining <= BoostRules.duration + 1e-9,
              dayCount >= 0, dayCount <= BoostRules.dailyLimit,
              (lastGrantForeground ?? 0) <= foreground + 1e-9 else {
            throw SaveError.unreadable("bad reward ledger")
        }
    }
}

/// 奖励广告的真实地图回放（RELEASE_SCOPE 第 5 章），与 Python boost_replay 同一动作表与策略，
/// 但经由客户端路径：GameSession 的 0.25 秒量子与 boost 到期切分。只用于回归验证，不是收益预测。
public enum BoostReplay {
    public enum Policy: String, CaseIterable, Sendable { case none, once, always }

    public static let referenceActions: [Int: [GridPoint]] = ScriptedReplay.actions
    public static let slowActions: [Int: [GridPoint]] = [
        120: [GridPoint(2, 4), GridPoint(2, 5), GridPoint(2, 6)],
        420: [GridPoint(1, 4), GridPoint(1, 5)],
        900: [GridPoint(6, 3), GridPoint(6, 2)],
        1020: [GridPoint(6, 4), GridPoint(6, 5), GridPoint(6, 6), GridPoint(7, 6)],
    ]

    public struct Result: Equatable, Sendable {
        public let firstPantry: Int?
        public let firstReady: Int?
        public let grants: [Int]
        public let completeAt: Int?
        public let ants: Int
        public let larvae: Int
        public let food: Double
        public let capacity: Double
        public let hauled: Double
        public let spent: Double
        public let refills: Int
        public let remaining: [Double?]
        public let boostRemaining: Double
        public let foreground: Double
    }

    public static func run(actions: [Int: [GridPoint]], pantryFrom: Int, seconds: Int, policy: Policy) -> Result {
        let session = GameSession()
        var ledger = RewardLedger()
        var grants: [Int] = []
        var firstPantry: Int?
        var firstReady: Int?
        var completeAt: Int?
        for second in 0..<seconds {
            for p in actions[second] ?? [] { session.apply(.debugCompleteCell(p)) }
            if second >= pantryFrom, session.colony.pantry.isEmpty, session.colony.food >= Rules.pantryCost {
                session.apply(.buildPantry(topLeft: ScriptedReplay.pantryTopLeft))
                firstPantry = second
            }
            let status = ledger.status(pantryBuilt: !session.colony.pantry.isEmpty,
                                       storageFull: session.colony.isStorageFull, day: 0)
            if status == .ready, firstReady == nil { firstReady = second }
            if status == .ready, policy == .always || (policy == .once && grants.isEmpty) {
                if ledger.grant(requestId: "req-\(second)", day: 0) { grants.append(second) }
                ledger.grant(requestId: "req-\(second)", day: 0)   // 重复回调：不得再次授予
            }
            session.boostRemaining = ledger.boostRemaining
            for _ in 0..<4 { session.tick(frameDelta: Rules.tick) }
            ledger.boostRemaining = session.boostRemaining
            ledger.foreground += session.drainForegroundSeconds()
            let c = session.colony
            if completeAt == nil, c.ants >= Rules.populationCap, c.larvae.isEmpty, !c.pantry.isEmpty, c.isStorageFull {
                completeAt = second + 1
            }
        }
        _ = session.drainEvents()
        let c = session.colony
        return Result(firstPantry: firstPantry, firstReady: firstReady, grants: grants, completeAt: completeAt,
                      ants: c.ants, larvae: c.larvae.count, food: c.food, capacity: c.capacity, hauled: c.hauled,
                      spent: c.spent, refills: c.refills, remaining: c.sources.map(\.remaining),
                      boostRemaining: ledger.boostRemaining, foreground: ledger.foreground)
    }
}
