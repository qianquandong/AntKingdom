import AntKingdomCore

/// 资源 ID（design/asset_manifest.json）→ 客户端运行时名称：Assets.xcassets 的 imageset 名，
/// 或 Resources/Audio 下的音频文件名（不含扩展名，接受 caf/wav/m4a）。
///
/// 这是 Claude 的导入约定：Codex 按 manifest 交付后，导入时按本表命名；某个名称缺失时客户端
/// 继续画带资源 ID 的占位。design/asset_runtime_names.json 与 `contract` 一致（AntKingdomTests 校验），
/// tools/check_assets.py 用它判断资源是否完整导入。
enum AssetNames {
    // MARK: A01 环境

    /// 土块三种无缝变化，按格坐标稳定选择（与占位的明暗变化同一公式）
    static func soil(variantFor p: GridPoint) -> String { "terrain_soil_\((p.x * 7 + p.y * 3) % 3 + 1)" }
    static let soilVariants = (1...3).map { "terrain_soil_\($0)" }

    /// 隧道遮罩：mask 为四邻相通位之和，N1 E2 S4 W8（N 为地图上方，即 y − 1）
    static func tunnel(mask: Int) -> String { "terrain_tunnel_masks_\(mask)" }
    static let tunnelMasks = (0...15).map { "terrain_tunnel_masks_\($0)" }

    static func tunnelMask(at p: GridPoint, open: Set<GridPoint>) -> Int {
        var mask = 0
        if open.contains(GridPoint(p.x, p.y - 1)) { mask |= 1 }
        if open.contains(GridPoint(p.x + 1, p.y)) { mask |= 2 }
        if open.contains(GridPoint(p.x, p.y + 1)) { mask |= 4 }
        if open.contains(GridPoint(p.x - 1, p.y)) { mask |= 8 }
        return mask
    }

    static let stone = "terrain_stone"
    static let surface = "surface_backdrop"
    static let queen = "room_queen"
    static let pantry = "room_pantry"

    /// 房间外观（正式版 A05 garden_decor_pack；运行时名称见 design/asset_runtime_names.json 的 release_names）
    static func queen(style: RoomStyle) -> String { style == .garden ? "garden_decor_pack_queen" : queen }
    static func pantry(style: RoomStyle) -> String { style == .garden ? "garden_decor_pack_pantry" : pantry }

    /// 有限源：有货/空盘两张（manifest：cookie、sugar）；Sap 只有一张
    static func source(_ id: String, empty: Bool) -> String {
        switch id {
        case "cookie", "sugar": return "source_\(id)_\(empty ? "empty" : "full")"
        default: return "source_sap"
        }
    }

    // MARK: A02 角色与效果

    enum AntPose: String, CaseIterable {
        case idle, walk, carry
        /// manifest：idle2 / walk6 / carry6
        var frameCount: Int { self == .idle ? 2 : 6 }
    }

    /// 蚂蚁帧，frame 从 1 开始；统一中心锚点，朝右
    static func ant(_ pose: AntPose, frame: Int) -> String { "ant_worker_\(pose.rawValue)_\(frame)" }
    static let cargo = "ant_cargo"
    static func egg(ready: Bool) -> String { ready ? "egg_states_ready" : "egg_states_normal" }
    /// 裂纹两级（第 1、2 次命中）与碎屑小图
    static func crack(level: Int) -> String { "dig_feedback_crack_\(min(max(level, 1), 2))" }
    static let crumb = "dig_feedback_crumb"

    enum RouteMarker: String, CaseIterable { case normal, busy, selected }
    static func routeMarker(_ kind: RouteMarker) -> String { "route_markers_\(kind.rawValue)" }

    // MARK: A03 UI 与音效

    /// 核心图标（面板与文字为原生 SwiftUI，不导入面板位图）
    static let uiIcons = ["food", "ant", "egg", "move", "settings"].map { "ui_core_\($0)" }

    static func sound(_ cue: SoundCue) -> String { "audio_core_\(cue.rawValue)" }

    /// 全部运行时名称（按资源 ID）。设计稿/商店素材类资源（art_keyframe 等）不进客户端，不在表内。
    static var contract: [String: [String]] {
        [
            "terrain_soil": soilVariants,
            "terrain_tunnel_masks": tunnelMasks,
            "terrain_stone": [stone],
            "surface_backdrop": [surface],
            "room_queen": [queen],
            "room_pantry": [pantry],
            "source_cookie": [source("cookie", empty: false), source("cookie", empty: true)],
            "source_sugar": [source("sugar", empty: false), source("sugar", empty: true)],
            "source_sap": [source("sap", empty: false)],
            "ant_worker": AntPose.allCases.flatMap { pose in (1...pose.frameCount).map { ant(pose, frame: $0) } },
            "ant_cargo": [cargo],
            "egg_states": [egg(ready: false), egg(ready: true)],
            "dig_feedback": [crack(level: 1), crack(level: 2), crumb],
            "route_markers": RouteMarker.allCases.map(routeMarker),
            "ui_core": uiIcons,
            "audio_core": SoundCue.allCases.map(sound),
        ]
    }
}
