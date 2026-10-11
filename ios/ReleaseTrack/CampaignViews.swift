import AntKingdomCore
import SwiftUI

/// 发行轨根视图：游戏 / 单章存档不可用 / 进度来自新版本 / 内置数据损坏。
struct CampaignRootView: View {
    @ObservedObject var model: CampaignModel

    var body: some View {
        switch model.phase {
        case .running(let controller):
            // 换章节/全部重置会换新的控制器：用身份重建整棵子树，场景不会残留旧会话
            CampaignGameView(model: model, controller: controller, sheets: model.sheets)
                .id(ObjectIdentifier(controller))
        case .chapterSaveUnavailable(let chapterId):
            ChapterSaveErrorView(retry: model.launch, startOver: { model.startChapterOver(chapterId) })
        case .progressUnavailable:
            CampaignMessageView(messageKey: "error.progress_newer", retry: model.launch)
        case .catalogUnavailable:
            CampaignMessageView(messageKey: "error.save", retry: model.launch)
        }
    }
}

/// 游戏主界面 + 章节页（sheet）+ 完成卡片（浮层）。
/// 完成卡片用浮层而不是 sheet：离线总结 sheet 同时出现时不会互相抢占，关掉总结后卡片仍在。
private struct CampaignGameView: View {
    let model: CampaignModel
    let controller: GameController
    @ObservedObject var sheets: CampaignSheets

    var body: some View {
        ZStack {
            RunningGameView(controller: controller)
            if let completion = sheets.completion {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                ChapterCompleteCard(model: model, completion: completion)
                    .padding(20)
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $sheets.showChapters) {
            ChapterSelectView(model: model)
        }
    }
}

/// 一组目标及是否达成（勾号 + 文字，不只靠颜色）。
private struct GoalList: View {
    let titleKey: String
    let goals: [ChapterGoal]
    let achieved: Set<ChapterGoal>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text(titleKey))
                .font(.system(.subheadline, design: .rounded).weight(.bold))
            ForEach(goals, id: \.self) { goal in
                HStack(spacing: 8) {
                    Image(systemName: achieved.contains(goal) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(achieved.contains(goal) ? Theme.connected : Theme.ink.opacity(0.4))
                    Text(L10n.text(goal.stringKey))
                        .font(.system(.subheadline, design: .rounded))
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("goal.\(goal.rawValue).\(achieved.contains(goal) ? "done" : "open")")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 本章完成：已获目标、下一章、留在本章、重玩本章（二次确认）。不推销任何商品或广告。
private struct ChapterCompleteCard: View {
    let model: CampaignModel
    let completion: ChapterCompletion
    @State private var confirmReplay = false

    private var chapterTitle: String {
        model.catalog?.chapter(completion.chapterId).map { L10n.text($0.titleKey) } ?? ""
    }

    var body: some View {
        let achieved = model.achievedGoals(completion.chapterId)
        VStack(spacing: 14) {
            Text(L10n.text("chapter.complete"))
                .font(.system(.title2, design: .rounded).weight(.bold))
                .accessibilityIdentifier("chapter.complete")
            Text(chapterTitle)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.75))
            GoalList(titleKey: "chapter.main_goals", goals: ChapterGoal.main, achieved: achieved)
            GoalList(titleKey: "chapter.extra_goals", goals: ChapterGoal.exploration, achieved: achieved)
            if let next = completion.next {
                Button {
                    model.open(next)
                } label: {
                    Text(L10n.text("chapter.next")).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.connected)
                .accessibilityIdentifier("chapter.next")
            }
            Button {
                model.dismissCompletion()
            } label: {
                Text(L10n.text("chapter.keep_building")).frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("chapter.keep_building")
            Button(role: .destructive) {
                confirmReplay = true
            } label: {
                Text(L10n.text("chapter.replay")).frame(maxWidth: .infinity, minHeight: 44)
            }
            .accessibilityIdentifier("chapter.replay")
        }
        .padding(22)
        .foregroundStyle(Theme.ink)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        .confirmationDialog(L10n.text("chapter.replay_confirm"), isPresented: $confirmReplay,
                            titleVisibility: .visible) {
            Button(L10n.text("chapter.replay"), role: .destructive) { model.replayActiveChapter() }
                .accessibilityIdentifier("chapter.replay.confirm")
            Button(L10n.text("action.cancel"), role: .cancel) {}
        }
    }
}

/// 章节页：顺序列出可玩章节；锁定章节显示解锁条件且不可打开；当前章节可重玩（二次确认）。
private struct ChapterSelectView: View {
    let model: CampaignModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReplay = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.catalog?.chapters ?? [], id: \.id) { chapter in
                    row(chapter)
                }
                Section {
                    Button(role: .destructive) {
                        confirmReplay = true
                    } label: {
                        Text(L10n.text("chapter.replay"))
                    }
                    .accessibilityIdentifier("chapters.replay")
                }
            }
            .navigationTitle(L10n.text("chapter.select"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("action.close")) { dismiss() }
                        .accessibilityIdentifier("chapters.close")
                }
            }
            .confirmationDialog(L10n.text("chapter.replay_confirm"), isPresented: $confirmReplay,
                                titleVisibility: .visible) {
                Button(L10n.text("chapter.replay"), role: .destructive) { model.replayActiveChapter() }
                    .accessibilityIdentifier("chapters.replay.confirm")
                Button(L10n.text("action.cancel"), role: .cancel) {}
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func row(_ chapter: ChapterDefinition) -> some View {
        let status = model.status(of: chapter)
        let active = chapter.id == model.activeChapterId
        Button {
            if status.unlocked { model.open(chapter.id) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: !status.unlocked ? "lock.fill"
                      : status.completed ? "checkmark.seal.fill" : "leaf.fill")
                    .foregroundStyle(status.unlocked ? Theme.connected : Theme.ink.opacity(0.4))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text(chapter.titleKey))
                        .font(.system(.body, design: .rounded).weight(.semibold))
                    Text(statusText(status, active: active))
                        .font(.footnote)
                        .foregroundStyle(Theme.ink.opacity(0.7))
                        .accessibilityIdentifier("chapter.status.\(chapter.id)")
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .foregroundStyle(Theme.ink)
        .disabled(!status.unlocked)
        .accessibilityIdentifier("chapter.row.\(chapter.id)")
    }

    private func statusText(_ status: (unlocked: Bool, completed: Bool, goals: Int), active: Bool) -> String {
        guard status.unlocked else { return L10n.text("chapter.locked") }
        let count = L10n.text("chapter.goal_count", ["done": String(status.goals),
                                                       "total": String(ChapterGoal.allCases.count)])
        if active { return L10n.text("chapter.playing") + " · " + count }
        if status.completed { return L10n.text("chapter.completed") + " · " + count }
        return count
    }
}

/// 单章存档不可用：说明 + 重试 + 重开本章（二次确认）。其他章节与解锁不受影响。
private struct ChapterSaveErrorView: View {
    let retry: () -> Void
    let startOver: () -> Void
    @State private var confirm = false

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.busy)
                Text(L10n.text("error.chapter_save"))
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("error.chapter_save")
                Button(action: retry) {
                    Text(L10n.text("action.retry")).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.connected)
                Button(role: .destructive) {
                    confirm = true
                } label: {
                    Text(L10n.text("chapter.replay")).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
            .padding(32)
            .foregroundStyle(Theme.ink)
        }
        .confirmationDialog(L10n.text("chapter.replay_confirm"), isPresented: $confirm, titleVisibility: .visible) {
            Button(L10n.text("chapter.replay"), role: .destructive, action: startOver)
            Button(L10n.text("action.cancel"), role: .cancel) {}
        }
    }
}

/// 无法继续时的说明 + 重试（不清档）。
private struct CampaignMessageView: View {
    let messageKey: String
    let retry: () -> Void

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.busy)
                Text(L10n.text(messageKey))
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier(messageKey)
                Button(action: retry) {
                    Text(L10n.text("action.retry")).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.connected)
            }
            .padding(32)
            .foregroundStyle(Theme.ink)
        }
    }
}
