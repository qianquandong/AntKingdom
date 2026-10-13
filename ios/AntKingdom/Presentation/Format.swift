import AntKingdomCore
import Foundation

/// 显示格式（PRD 5.1）：库存向下取整；预计产量、Trip、改善百分比保留一位小数。
/// 逻辑层保持 Double，不在这里反写任何状态。
enum Format {
    static func food(_ value: Double) -> String {
        String(Int(max(0, value).rounded(.down)))
    }

    static func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    static func seconds(_ value: Double) -> String {
        String(Int(max(0, value).rounded(.up)))
    }

    /// 剩余时间 m:ss（向上取整到秒），用于奖励 boost 与冷却
    static func clock(_ value: Double) -> String {
        let total = Int(max(0, value).rounded(.up))
        return String(format: "%d:%02d", locale: Locale(identifier: "en_US_POSIX"), total / 60, total % 60)
    }

    static func sourceNameKey(_ id: String) -> String {
        switch id {
        case "cookie": return "source.cookie"
        case "sugar": return "source.sugar"
        case "sap": return "source.sap"
        default: return "source.surface"
        }
    }
}
