/// 房间外观（RELEASE_SCOPE 第 2 章 Garden Decor Pack）。只改变 Queen Chamber 与 Pantry 的外观，
/// 对速度、容量、人口、碰撞、地图解锁零影响：经济代码完全不读取它（CosmeticsTests 用 600 秒回放核对）。
public enum RoomStyle: String, Codable, CaseIterable, Sendable {
    case standard = "default"
    case garden

    /// 解锁该外观所需商品 ID 的后缀；真实 ID = 最终 Bundle ID + "." + 后缀（RELEASE_SCOPE 第 2 章）
    public var productSuffix: String? {
        switch self {
        case .standard: return nil
        case .garden: return "garden_decor"
        }
    }

    /// 由 Bundle ID 拼出商品 ID；默认外观不需要商品
    public func productId(bundleId: String) -> String? {
        productSuffix.map { "\(bundleId).\($0)" }
    }
}

extension PlayerProgress {
    public var selectedRoomStyle: RoomStyle { RoomStyle(rawValue: roomStyle) ?? .standard }

    /// 用 StoreKit 当前已验证权益更新缓存。返回 true 表示当前外观失去权益、已回退默认外观
    /// （退款/撤销后；地图与进度不动）。
    @discardableResult
    public mutating func setEntitlements(_ owned: Set<String>, bundleId: String) -> Bool {
        ownedProducts = owned.sorted()
        if let required = selectedRoomStyle.productId(bundleId: bundleId), !owned.contains(required) {
            roomStyle = RoomStyle.standard.rawValue
            return true
        }
        return false
    }

    public func owns(_ style: RoomStyle, bundleId: String) -> Bool {
        guard let required = style.productId(bundleId: bundleId) else { return true }
        return ownedProducts.contains(required)
    }

    /// 启用外观：没有权益的外观不能启用（预览在界面层完成，不写进度）。
    @discardableResult
    public mutating func select(_ style: RoomStyle, bundleId: String) -> Bool {
        guard owns(style, bundleId: bundleId) else { return false }
        roomStyle = style.rawValue
        return true
    }
}
