#if DEBUG
import AntKingdomCore

/// 仅 Debug：UI 测试用的第二章（启动参数 -ak-fixture-chapters）。
/// 这不是正式内容——第二、三章地图由 Codex A04 交付；发行配置的二进制检查确认此标记不存在。
enum DebugFixtureChapter {
    static let id = "debug_fixture"
    /// 标题不进入文案表：Debug 截图里一眼可见这是测试地图
    static let title = "Test Map (Debug)"
    static let mapText = """
    ~~~~E~~~~
    ####.####
    #S##.####
    ###QQQ###
    ###QQQ###
    #X#####XX
    ######CC#
    R#####CC#
    #####X###
    #########
    """

    static func make() throws -> ChapterDefinition {
        ChapterDefinition(id: id, titleKey: title, map: try MapDefinition(id: id, version: 1, text: mapText))
    }
}
#endif
