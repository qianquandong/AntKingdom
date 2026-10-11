import Foundation

/// 英文文案查找。键与 PRD 附录 A 的 String ID 相同；占位符沿用 PRD 的 `{name}` 写法。
/// 目录文件由 `python tools/export_strings.py` 从 PRD 生成，不手工编辑。
enum L10n {
    static func text(_ key: String, _ arguments: [String: String] = [:]) -> String {
        var value = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
        for (name, replacement) in arguments {
            value = value.replacingOccurrences(of: "{\(name)}", with: replacement)
        }
        return value
    }

    /// 键是否存在（缺失时 Bundle 会原样返回键名）。
    static func has(_ key: String) -> Bool {
        Bundle.main.localizedString(forKey: key, value: nil, table: nil) != key
    }
}
