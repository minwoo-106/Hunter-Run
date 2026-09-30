import SwiftUI

struct AssociationView: View {
    @State private var section = 2
    var body: some View {
        VStack(spacing: 0) {
            Picker("협회 업무", selection: $section) { Text("의뢰").tag(0); Text("주간 조사").tag(1); Text("시설").tag(2) }
                .pickerStyle(.segmented).padding(.horizontal, 20).padding(.vertical, 12).accessibilityIdentifier("association.section")
            if section == 0 { QuestBoardView() }
            else if section == 1 { WeeklySurveyView() }
            else { AssociationFacilitiesView() }
        }.background(Theme.ink).navigationTitle("협회 관리").navigationBarTitleDisplayMode(.inline)
            .environment(\.labyrinthArtwork, "TransitionAssociationHall")
    }
}
struct WeeklySurveyView: View {
    @EnvironmentObject var model: AppModel
    private let refresh = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                eyebrow("WEEKLY FIELD SURVEY")
                Text(model.weeklySurvey.title).font(.largeTitle.bold())
                Text("이번 주에 모은 발걸음이 지부의 관측등을 밝혀요. 연속 출석이 아니에요. 쉬는 날이 있어도 기록은 남아요.").foregroundStyle(Theme.muted)
                BeaconPanel()
                VStack(alignment: .leading, spacing: 18) {
                    objective("서로 다른 3일 현장 조사", detail: "하루 합산 10분 이상 야외 활동", value: Double(model.weeklySurvey.days), target: 3)
                    objective("야외 활동 60분", detail: "여러 번 나눠 진행해도 합산해요", value: model.weeklySurvey.seconds / 60, target: 60)
                    objective("조사 단서 6개", detail: "야외에서 성공한 표본 조사", value: Double(model.weeklySurvey.clues), target: 6)
                }.card().accessibilityIdentifier("weekly.progress")
                Text("완성 보상 · 기념 인장 / EXP 80 / 마정석 6 / 조사 4").font(.caption).foregroundStyle(Theme.teal)
                Button(model.weeklySurvey.claimed ? "이번 주 인장 받음" : "조사 보고 제출") { model.claimWeeklySurvey() }
                    .buttonStyle(GameButtonStyle(primary: true)).disabled(!model.weeklySurvey.complete || model.weeklySurvey.claimed || model.growthLocked).accessibilityIdentifier("weekly.claim")
                Text("한국 시간 월요일 0시에 새 조사가 시작돼요. 야외 이동 기록이 있는 활동만 합산하며, 실내 활동은 주간 조사에 포함되지 않아요.").font(.caption).foregroundStyle(Theme.muted)
                Text("수집한 주간 인장 · \(model.save.profile.expeditions?.claimedWeeks.count ?? 0)개").font(.headline)
            }.padding(22)
        }.labyrinthScreen().navigationTitle("주간 야외 조사").navigationBarTitleDisplayMode(.inline)
            .onReceive(refresh) { _ in model.objectWillChange.send() }
    }
    private func objective(_ title: String, detail: String, value: Double, target: Double) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { Text(title).font(.headline); Spacer(); Text("\(Int(min(value, target))) / \(Int(target))").font(.caption.monospacedDigit()).foregroundStyle(Theme.teal) }
            ProgressView(value: min(value, target), total: target).tint(Theme.teal)
            Text(detail).font(.caption).foregroundStyle(Theme.muted)
        }
    }
}
struct BeaconPanel: View {
    @EnvironmentObject var model: AppModel
    private var lights: [Bool] { [model.weeklySurvey.days >= 3, model.weeklySurvey.seconds >= 3600, model.weeklySurvey.clues >= 6] }
    var body: some View {
        ZStack(alignment: .bottom) {
            Image(AssociationStage.artwork(model.save.profile)).resizable().scaledToFill().frame(height: 170).clipped().overlay(.black.opacity(0.4))
            HStack(spacing: 22) {
                ForEach(0..<3) { index in
                    VStack(spacing: 6) {
                        Image(systemName: "sparkle").font(.title).foregroundStyle(lights[index] ? Theme.teal : Theme.muted.opacity(0.5))
                            .shadow(color: lights[index] ? Theme.teal.opacity(0.9) : .clear, radius: 9)
                        Text(["발걸음", "지속", "단서"][index]).font(.caption)
                    }
                }
            }.padding(18).frame(maxWidth: .infinity).background(.black.opacity(0.6))
        }.clipShape(RelicShape()).accessibilityElement(children: .ignore)
            .accessibilityLabel("이번 주 관측등 \(model.weeklySurvey.beacons)개 / 3개").accessibilityIdentifier("weekly.beacons")
    }
}
struct ReturnBriefingView: View {
    @EnvironmentObject var model: AppModel
    @State private var index = 0
    var body: some View {
        NavigationStack {
            if let report = model.save.profile.expeditions?.briefing {
                NovelStage(expression: index == 0 ? "relieved" : "smile", resetKey: String(index)) {
                    HStack { Text(model.save.profile.journey?.operatorName ?? "서윤").font(.headline); Spacer(); Text("\(min(index + 1, report.lines.count)) / \(report.lines.count)").font(.caption).foregroundStyle(Theme.muted) }
                    Text(report.lines[min(index, report.lines.count - 1)]).font(.title3).lineSpacing(7).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("return.line")
                    Button(index + 1 < report.lines.count ? "이야기 계속 듣기" : "기록 정리 고마워요") {
                        if index + 1 < report.lines.count { index += 1 } else { model.showReturnBriefing = false }
                    }.buttonStyle(GameButtonStyle(primary: true)).accessibilityIdentifier("return.next")
                }.navigationTitle("귀환 보고").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button { model.showReturnBriefing = false } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.buttonStyle(.plain).accessibilityLabel("귀환 보고 닫기") } }
            }
        }.onAppear { index = 0 }
    }
}
