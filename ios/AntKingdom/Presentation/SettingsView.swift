import AntKingdomCore
import SwiftUI

/// 设置：音效、触觉、重新开始（二次确认）。关闭音效/触觉不影响任何核心状态。
struct SettingsView: View {
    @ObservedObject var controller: GameController
    @State private var confirmReset = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                onOffRow("settings.sound", isOn: controller.snapshot.settings.sound) { controller.send(.setSound($0)) }
                onOffRow("settings.haptics", isOn: controller.snapshot.settings.haptics) { controller.send(.setHaptics($0)) }
                Section {
                    Button(role: .destructive) {
                        confirmReset = true
                    } label: {
                        Text(L10n.text("action.reset"))
                    }
                    .accessibilityIdentifier("settings.reset")
                }
                #if DEBUG
                DebugMenu(controller: controller)
                #endif
            }
            .navigationTitle(L10n.text("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("action.close")) { dismiss() }
                        .accessibilityIdentifier("settings.close")
                }
            }
            .confirmationDialog(L10n.text("dialog.reset"), isPresented: $confirmReset, titleVisibility: .visible) {
                Button(L10n.text("action.reset"), role: .destructive) {
                    controller.resetColony()
                    dismiss()
                }
                .accessibilityIdentifier("dialog.reset.confirm")
                Button(L10n.text("action.cancel"), role: .cancel) {}
            }
        }
        .presentationDetents([.medium])
    }

    private func onOffRow(_ key: String, isOn: Bool, set: @escaping (Bool) -> Void) -> some View {
        HStack {
            Text(L10n.text(key))
            Spacer()
            Picker(L10n.text(key), selection: Binding(get: { isOn }, set: set)) {
                Text(L10n.text("settings.on")).tag(true)
                Text(L10n.text("settings.off")).tag(false)
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
            .accessibilityIdentifier(key)
        }
    }
}
