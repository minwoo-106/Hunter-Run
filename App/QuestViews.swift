import SwiftUI

struct QuestBoardView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                eyebrow("ASSOCIATION ASSIGNMENTS")
                Text("함께 이어갈 의뢰").font(.largeTitle.bold())
                Text("선택한 의뢰의 시간과 표본은 여러 활동에 걸쳐 이어져요. 활동은 평소 다니는 길에서 진행할 수 있어요.").foregroundStyle(Theme.muted)
                let state = model.save.profile.journey ?? JourneyState()
                ForEach(Quests.entries.filter { $0.available(model.save.profile) || state.completedQuests.contains($0.id) }) { quest in
                    let done = state.completedQuests.contains(quest.id)
                    let claimed = state.claimedQuests.contains(quest.id)
                    VStack(alignment: .leading, spacing: 12) {
                        Text(quest.title).font(.title3.bold())
                        Text(quest.detail).font(.callout).foregroundStyle(Theme.muted)
                        if let target = quest.lifetimeDefeats {
                            ProgressView("토벌 \(min(target, Quests.defeats(model.save.profile))) / \(target)", value: Double(min(target, Quests.defeats(model.save.profile))), total: Double(target))
                        } else if let boss = quest.boss {
                            let progress = BossCampaign.state(boss, profile: model.save.profile)
                            ProgressView("남은 반응 \(Int(progress.remainingHP)) / \(Int(progress.maximumHP))", value: progress.maximumHP - progress.remainingHP, total: progress.maximumHP)
                        } else {
                            let progress = quest.progress(model.save.profile)
                            ProgressView("의뢰 활동 \(Int(min(quest.seconds, progress.seconds) / 60)) / \(Int(quest.seconds / 60))분", value: min(quest.seconds, progress.seconds), total: max(1, quest.seconds))
                            Text("표본 \(min(quest.samples, progress.evidence.count)) / \(quest.samples)").font(.caption)
                        }
                        Text("보상 · 경험치 \(quest.xp) / 마정석 \(quest.crystals) / 조사 \(quest.research)").font(.caption).foregroundStyle(Theme.teal)
                        if claimed { Label("보상 받음", systemImage: "checkmark.seal.fill").font(.caption) }
                        else if done {
                            Button("보상 받기") { model.claimQuest(quest.id) }.buttonStyle(.borderedProminent).disabled(model.growthLocked).accessibilityIdentifier("quest.claim." + quest.id)
                        } else {
                            Button(state.selectedQuest == quest.id ? "이 의뢰로 활동 준비" : "의뢰 선택") { model.selectQuest(quest.id); dismiss() }
                                .buttonStyle(.borderedProminent).disabled(model.growthLocked).accessibilityIdentifier("quest.select." + quest.id)
                        }
                    }.card()
                }
                Text("지부의 이야기를 따라 새로운 의뢰가 도착해요.").font(.caption).foregroundStyle(Theme.muted)
            }.padding(20)
        }.background(Theme.ink).navigationTitle("의뢰 게시판").navigationBarTitleDisplayMode(.inline)
    }
}
