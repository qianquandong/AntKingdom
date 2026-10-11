/// 核心包的版本信息。规则权威是 docs/PRD.md 与 tools/economy_sim.py。
public enum CoreInfo {
    /// 当前移植所依据的规则版本（PRD 版本 + 基线提交）。
    public static let rulesBaseline = "PRD v0.2 @ eae0215"
    /// 存档 schema 版本；与 App 版本分开管理。
    public static let saveSchemaVersion = 1
}
