import AntKingdomCore
import SwiftUI

/// 设置：音效、触觉、重新开始（二次确认）。关闭音效/触觉不影响任何核心状态。
///
/// 不观察 controller：它约每秒发布 10 次快照，观察它会让整张表单随之重算，分段控件在点击过程中被重设，
/// 点击被取消（CI 录像中 iOS 26 的选择块抬起后弹回 On）。开关值放在本视图的 @State，变化时发命令；
/// 设置只在这里修改，打开时从快照读一次即可。
struct SettingsView: View {
    let controller: GameController
    @State private var sound: Bool
    @State private var haptics: Bool
    @State private var confirmReset = false
    @Environment(\.dismiss) private var dismiss

    init(controller: GameController) {
        self.controller = controller
        _sound = State(initialValue: controller.snapshot.settings.sound)
        _haptics = State(initialValue: controller.snapshot.settings.haptics)
    }

    var body: some View {
        NavigationStack {
            Form {
                onOffRow("settings.sound", selection: $sound)
                onOffRow("settings.haptics", selection: $haptics)
                Section {
                    Button(role: .destructive) {
                        confirmReset = true
                    } label: {
                        Text(L10n.text(controller.resetTitleKey))
                    }
                    .accessibilityIdentifier("settings.reset")
                }
                #if DEBUG
                DebugMenu(controller: controller)
                #endif
            }
            .onChange(of: sound) { _, value in controller.send(.setSound(value)) }
            .onChange(of: haptics) { _, value in controller.send(.setHaptics(value)) }
            .navigationTitle(L10n.text("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("action.close")) { dismiss() }
                        .accessibilityIdentifier("settings.close")
                }
            }
            .confirmationDialog(L10n.text(controller.resetDialogKey), isPresented: $confirmReset,
                                titleVisibility: .visible) {
                Button(L10n.text(controller.resetTitleKey), role: .destructive) {
                    controller.resetColony()
                    dismiss()
                }
                .accessibilityIdentifier("dialog.reset.confirm")
                Button(L10n.text("action.cancel"), role: .cancel) {}
            }
        }
        .presentationDetents([.medium])
    }

    private func onOffRow(_ key: String, selection: Binding<Bool>) -> some View {
        HStack {
            Text(L10n.text(key))
            Spacer()
            Picker(L10n.text(key), selection: selection) {
                Text(L10n.text("settings.on")).tag(true)
                Text(L10n.text("settings.off")).tag(false)
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
            .accessibilityIdentifier(key)
        }
    }
}
