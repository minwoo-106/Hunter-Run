import SwiftUI

func learnedPaceText(_ speed: Double?) -> String {
    guard let speed, PaceLearning.validSpeed(speed) else { return "표본 수집 중" }
    let seconds = Int((1000 / speed).rounded())
    return String(format: "%d′%02d″ /km", seconds / 60, seconds % 60)
}
struct PaceProfileView: View {
    @EnvironmentObject var model: AppModel
    @State private var confirmReset = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                eyebrow("HUNTER / FIELD RHYTHM")
                Text("나의 활동 기준").font(.largeTitle.bold())
                VStack(alignment: .leading, spacing: 12) {
                    Text("다음 활동의 참고 페이스").font(.headline)
                    Text(learnedPaceText(model.save.profile.paceMemory?.reference)).font(.title.bold()).foregroundStyle(Theme.teal).accessibilityIdentifier("pace.reference")
                    Text("반영된 최근 활동 \(model.save.profile.paceMemory?.recent.count ?? 0)회 / 최대 5회").font(.caption)
                }.card()
                Text("이 수치는 게임 판정을 위한 참고값입니다. 오늘 관측한 페이스가 더 느리면 오늘의 값을 사용합니다. 더 빠르게 달려 맞출 필요는 없습니다.").foregroundStyle(Theme.muted)
                VStack(alignment: .leading, spacing: 12) {
                    Text("어떤 구간을 학습하나요?").font(.headline)
                    Text("GPS가 양호한 달리기 구간을 5분 이상 확보한 실제 활동만 반영합니다. 걷기·정지·차량·신호가 약한 구간, 사건 안내와 전투, 전투 직후 1분은 제외합니다.")
                    Text("목표 30분을 채우지 않고 25분에 저장해도 활동·보상은 남아요. 이 기준의 ‘최근 활동’ 횟수는 완료 횟수가 아니라 5분 이상의 학습 표본을 확보한 횟수예요.")
                    Text("표본이 부족하면 이번 활동의 임시 기준을 사용합니다. 충분히 학습되기 전에는 실제 활동의 추격을 조사로 전환합니다.")
                    Text("최근 5회 중앙값을 참고하고, 한 번에 기준 속도가 5% 넘게 변하지 않도록 제한합니다. 예전 버전 기록으로 새 페이스를 추측해 만들지는 않습니다.")
                }.font(.callout).foregroundStyle(Theme.muted).card()
                if let memory = model.save.profile.paceMemory, !memory.recent.isEmpty {
                    Text("최근 학습한 구간 페이스").font(.headline)
                    ForEach(Array(memory.recent.reversed().enumerated()), id: \.offset) { index, speed in
                        HStack { Text("최근 \(index + 1)번째"); Spacer(); Text(learnedPaceText(speed)).foregroundStyle(Theme.teal) }
                    }
                }
                Button("학습 기준 초기화") { confirmReset = true }.buttonStyle(GameButtonStyle())
                    .disabled(model.growthLocked || model.save.profile.paceMemory == nil).accessibilityIdentifier("pace.reset")
                Text("초기화하면 다음 실제 활동부터 다시 학습합니다. 활동 기록·장비·자원은 유지됩니다.").font(.caption).foregroundStyle(Theme.muted)
            }.padding(22)
        }.labyrinthScreen().navigationTitle("활동 기준").navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("학습한 페이스 기준을 초기화할까요?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("학습 기준 초기화", role: .destructive) { model.resetPaceMemory() }
            }
    }
}
struct PaceFeedbackView: View {
    let report: PaceReport
    var simulated = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("현장 관측 보고", systemImage: "waveform.path").font(.headline)
            Text("이동 중 GPS 양호 \(Int(report.goodSignalFraction * 100))% · 학습 가능 구간 \(clock(report.stableSeconds))").font(.caption).foregroundStyle(Theme.muted)
            Text("이번 안정 구간: " + learnedPaceText(report.medianSpeed)).foregroundStyle(Theme.teal)
            if simulated { Text("모의 활동이므로 학습 기준을 바꾸지 않았습니다.") }
            else if report.learned { Text("이번 관측을 다음 활동의 참고 기준에 반영했습니다."); Text("다음 참고값: " + learnedPaceText(report.referenceAfter)).foregroundStyle(Theme.teal) }
            else { Text("학습 가능한 달리기 구간이 5분 미만이라 기존 기준을 유지했습니다. 걷기와 짧은 활동도 기록과 보상에는 정상 반영됩니다.") }
            if let used = report.referenceUsed { Text("출발 때 참고한 값: " + learnedPaceText(used)).font(.caption).foregroundStyle(Theme.muted) }
        }.font(.callout).card()
    }
}
