import Foundation

/// 英文文案查找。键与 PRD 附录 A 的 String ID 相同；占位符沿用 PRD 的 `{name}` 写法。
/// 目录文件由 `python tools/export_strings.py` 生成，不手工编辑：核心表在 Localizable，
/// 正式版增量（RELEASE_SCOPE 第 6 节）在 Release 表，只打进发行轨 target。
enum L10n {
    static func text(_ key: String, _ arguments: [String: String] = [:]) -> String {
        var value = lookup(key)
        for (name, replacement) in arguments {
            value = value.replacingOccurrences(of: "{\(name)}", with: replacement)
        }
        return value
    }

    /// 键是否存在（缺失时 Bundle 会原样返回键名）。
    static func has(_ key: String) -> Bool {
        lookup(key) != key
    }

    private static func lookup(_ key: String) -> String {
        let core = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
        if core != key { return core }
        return Bundle.main.localizedString(forKey: key, value: nil, table: "Release")
    }
}
