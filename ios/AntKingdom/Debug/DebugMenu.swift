#if DEBUG
import AntKingdomCore
import SwiftUI

/// 开发调试入口（只编译进 Debug）：载入调试场景、查看三组固定夹具的求解结果。
/// 文字是开发者用的英文/ID，不属于玩家文案，不进入 TestFlight/AppStore 构建。
struct DebugMenu: View {
    /// 只发命令，不需要随快照刷新（理由同 SettingsView）
    let controller: GameController
    @State private var fixtures: [FixtureResult] = []

    var body: some View {
        Section("Debug") {
            ForEach(DebugScenario.allCases, id: \.self) { scenario in
                Button("Load scenario: \(scenario.rawValue)") {
                    controller.loadDebugScenario(scenario)
                }
                .accessibilityIdentifier("debug.scenario.\(scenario.rawValue)")
            }
            ForEach(fixtures, id: \.caseId) { result in
                VStack(alignment: .leading) {
                    Text(result.caseId).font(.caption.monospaced())
                    Text(String(format: "%.6f → %.6f Food/min (+%.4f%%) alloc %@",
                                locale: Locale(identifier: "en_US_POSIX"),
                                result.beforeFoodPerMin, result.afterFoodPerMin, result.gainPercent,
                                result.afterAllocations.map(String.init).joined(separator: "+")))
                        .font(.caption2.monospaced())
                }
                .accessibilityIdentifier("debug.fixture.\(result.caseId)")
            }
        }
        .onAppear(perform: loadFixtures)
    }

    private func loadFixtures() {
        guard fixtures.isEmpty, let url = Bundle.main.url(forResource: "transport_cases", withExtension: "json"),
              let cases = try? TransportCase.load(from: url) else { return }
        fixtures = cases.map { $0.result() }
    }
}

extension GameController {
    func loadDebugScenario(_ scenario: DebugScenario) {
        selection = nil
        try? scenario.apply(to: session)
        _ = session.drainEvents()
        onReset?()
        send(.setHatching(session.colony.hatching))
    }
}
#endif
