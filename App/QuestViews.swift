import SwiftUI

struct QuestBoardView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var showCompleted = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                eyebrow("ASSOCIATION ASSIGNMENTS")
                Text("함께 이어갈 의뢰").font(.largeTitle.bold())
                Text("일반 의뢰는 평소 활동과 함께 진행돼요. 추적은 화면에 표시할 목표를 고르는 기능이에요. 승급 심사만 전용 출동으로 준비해요.").foregroundStyle(Theme.muted)
                let state = model.save.profile.journey ?? JourneyState()
                Toggle("완료한 의뢰 보기", isOn: $showCompleted).font(.caption)
                ForEach(Quests.entries.filter { ($0.available(model.save.profile) || state.completedQuests.contains($0.id)) && (showCompleted || !state.claimedQuests.contains($0.id)) }) { quest in
                    let done = state.completedQuests.contains(quest.id)
                    let claimed = state.claimedQuests.contains(quest.id)
                    VStack(alignment: .leading, spacing: 12) {
                        Text(quest.title).font(.title3.bold())
                        if !done && state.selectedQuest == quest.id {
                            Label("현재 추적 중 · 활동 준비에 표시돼요", systemImage: "scope").font(.caption.bold()).foregroundStyle(Theme.teal)
                        }
                        Text(quest.detail).font(.callout).foregroundStyle(Theme.muted)
                        if let target = quest.lifetimeDefeats {
                            ProgressView("토벌 \(min(target, Quests.defeats(model.save.profile))) / \(target)", value: Double(min(target, Quests.defeats(model.save.profile))), total: Double(target))
                        } else if let boss = quest.boss {
                            let progress = BossCampaign.state(boss, profile: model.save.profile)
                            ProgressView("남은 반응 \(Int(progress.remainingHP)) / \(Int(progress.maximumHP))", value: progress.maximumHP - progress.remainingHP, total: progress.maximumHP)
                        } else {
                            let progress = quest.progress(model.save.profile)
                            ProgressView("누적 활동 \(Int(min(quest.seconds, progress.seconds) / 60)) / \(Int(quest.seconds / 60))분", value: min(quest.seconds, progress.seconds), total: max(1, quest.seconds))
                            Text("표본 \(min(quest.samples, progress.evidence.count)) / \(quest.samples)").font(.caption)
                        }
                        Text("보상 · 경험치 \(quest.xp) / 마정석 \(quest.crystals) / 조사 \(quest.research)").font(.caption).foregroundStyle(Theme.teal)
                        if claimed { Label("보상 받음", systemImage: "checkmark.seal.fill").font(.caption) }
                        else if done {
                            Button("보상 받기") { model.claimQuest(quest.id) }.buttonStyle(GameButtonStyle(primary: true)).disabled(model.growthLocked).accessibilityIdentifier("quest.claim." + quest.id)
                        } else {
                            Button(quest.promotion != nil ? "승급 심사 출동 준비" : state.selectedQuest == quest.id ? "활동 준비로 이동" : "목표 추적하기") { model.selectQuest(quest.id); dismiss() }
                                .buttonStyle(GameButtonStyle(primary: true)).disabled(model.growthLocked).accessibilityIdentifier("quest.select." + quest.id)
                        }
                    }.card()
                }
                Text("지부의 이야기를 따라 새로운 의뢰가 도착해요.").font(.caption).foregroundStyle(Theme.muted)
            }.padding(20)
        }.labyrinthScreen().navigationTitle("의뢰 게시판").navigationBarTitleDisplayMode(.inline)
    }
}
