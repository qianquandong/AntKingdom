import AntKingdomCore
import SwiftUI

/// Pantry 建造/移动的摆放状态（PRD 2.2：2×2 预览、确认与取消；取消无状态变化）。
struct PantryPlacement: Equatable {
    enum Kind: Equatable { case build, move }
    var kind: Kind
    /// 预览的左上角格；nil 表示尚未选点
    var topLeft: GridPoint?
}

enum PlacementValidity: Equatable {
    case noSpot
    case invalidSpace
    case notEnoughFood
    case ok

    /// 对应的英文提示 ID；ok 时没有提示
    var messageKey: String? {
        switch self {
        case .noSpot: return "tutorial.pantry"
        case .invalidSpace: return "error.pantry_space"
        case .notEnoughFood: return "error.not_enough_food"
        case .ok: return nil
        }
    }
}

extension GameController {
    func beginBuild() {
        selection = nil
        placement = PantryPlacement(kind: .build, topLeft: TutorialGuide.suggestedPantrySpot(in: session))
    }

    func beginMove() {
        selection = nil
        placement = PantryPlacement(kind: .move, topLeft: latest.pantryCells.min(by: GridPoint.keyLess))
    }

    func cancelPlacement() {
        placement = nil
    }

    /// 摆放模式下，点击的格作为 2×2 预览的左上角。
    func movePlacement(to cell: GridPoint) {
        placement?.topLeft = cell
        feedback.play(.select, settings: latest.settings)
    }

    var placementValidity: PlacementValidity {
        guard let placement else { return .noSpot }
        guard let topLeft = placement.topLeft else { return .noSpot }
        guard session.colony.isValidPantryFootprint(topLeft: topLeft) else { return .invalidSpace }
        if placement.kind == .build, latest.food < Rules.pantryCost { return .notEnoughFood }
        return .ok
    }

    /// 确认：只有合法时才发命令；失败不扣费、保持摆放模式并给出英文提示。
    func confirmPlacement() {
        guard let placement, let topLeft = placement.topLeft, placementValidity == .ok else {
            feedback.play(.rejected, settings: latest.settings)
            return
        }
        let result = send(placement.kind == .build ? .buildPantry(topLeft: topLeft) : .movePantry(topLeft: topLeft))
        switch result {
        case .pantryBuilt, .pantryMoved:
            self.placement = nil   // 建造/移动音效与触觉由 pantryBuilt/pantryMoved 事件统一发出
        case .rejected(.notEnoughFood):
            show("error.not_enough_food", style: .warning)
        default:
            show("error.pantry_space", style: .warning)
        }
    }
}
