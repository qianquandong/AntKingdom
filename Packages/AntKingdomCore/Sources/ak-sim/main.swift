// 命令行入口：输出与 `python tools/economy_sim.py --json` 同结构的结果，供跨语言差分报告。
//   swift run --package-path Packages/AntKingdomCore ak-sim [path/to/transport_cases.json]
// 默认读取当前目录下的 design/transport_cases.json（在仓库根目录运行）。
import AntKingdomCore
import Foundation

func rounded(_ value: Double, _ places: Int = 6) -> Double {
    let scale = pow(10.0, Double(places))
    return (value * scale).rounded() / scale
}

let path = CommandLine.arguments.dropFirst().first ?? "design/transport_cases.json"
do {
    let cases = try TransportCase.load(from: URL(fileURLWithPath: path)).map { testCase -> [String: Any] in
        let result = testCase.result()
        return [
            "case": result.caseId,
            "before_food_per_min": rounded(result.beforeFoodPerMin),
            "after_food_per_min": rounded(result.afterFoodPerMin),
            "gain_percent": rounded(result.gainPercent),
            "before_max_load": result.beforeMaxLoad,
            "after_max_load": result.afterMaxLoad,
            "after_allocations": result.afterAllocations,
            "converged": result.converged,
        ]
    }
    let (_, summary) = try ScriptedReplay.run()
    let session: [String: Any] = [
        "seconds": 600, "ants": summary.ants, "larvae": summary.larvae, "food": rounded(summary.food),
        "capacity": summary.capacity, "hauled": rounded(summary.hauled), "spent": summary.spent,
        "refills": summary.refills, "food_conservation_error": rounded(summary.conservationError, 9),
    ]
    let output: [String: Any] = ["cases": cases, "scripted_session": session, "rules_baseline": CoreInfo.rulesBaseline]
    let data = try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
    print(String(decoding: data, as: UTF8.self))
} catch {
    FileHandle.standardError.write(Data("ak-sim failed: \(error)\n".utf8))
    exit(1)
}
