import SwiftUI
import Charts

struct UnlockListView: View {
    let entries: [UnlockNotice]
    var body: some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("새로 열린 가능성", systemImage: "lock.open.fill").font(.headline).foregroundStyle(Theme.teal)
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.title).font(.callout.bold())
                        Text(entry.detail).font(.caption).foregroundStyle(Theme.muted)
                    }
                }
                Text("헌터의 장비 보관함, 헌터 활동의 대상 목록, 협회 관리에서 확인할 수 있어요.").font(.caption).foregroundStyle(Theme.muted)
            }.card()
        }
    }
}

struct ActivityGrowthCard: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let run: RunSummary
    @State private var revealed = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("오늘의 성장", systemImage: "sparkles").font(.title2.bold())
            HStack { metric("획득 EXP", "+\(run.xp)"); Spacer(); metric("토벌", "\(run.records.filter { $0.defeated == true && $0.outcome != .neutral }.count)회") }
            if let report = run.growthReport {
                Text(report.levelAfter > report.levelBefore ? "레벨 업 · Lv.\(report.levelBefore) → Lv.\(report.levelAfter)" : "Lv.\(report.levelAfter) · 오늘의 활동이 성장으로 쌓였어요.")
                    .font(.headline).foregroundStyle(Theme.teal).accessibilityIdentifier("report.level")
                ForEach(Array(report.firstDefeats.enumerated()), id: \.offset) { _, name in Label("첫 토벌 · " + name, systemImage: "flag.checkered") }
                if let id = report.targetID, let item = model.progressionCatalog?.equipment.first(where: { $0.id == id }), report.targetBefore.count == 3, report.targetAfter.count == 3 {
                    Text("목표 장비 · " + item.name).font(.headline)
                    let costs = [item.crystals, item.research, item.cores]
                    ForEach(0..<3) { i in
                        let before = min(costs[i], report.targetBefore[i]), after = min(costs[i], report.targetAfter[i])
                        HStack { Text(["마정석", "조사 데이터", "코어"][i]); Spacer(); Text("\(before) → \(after) / \(costs[i])") }.font(.caption.monospacedDigit())
                    }
                    Text("종료 시점의 보유 자원이에요. 장비를 위해 따로 예약되지는 않아요.").font(.caption).foregroundStyle(Theme.muted)
                }
                UnlockListView(entries: report.unlocks)
            } else { Text("이전 활동에는 레벨 변화와 장비 목표 기록이 없어요. 기존 운동 기록과 보상은 그대로예요.").font(.caption).foregroundStyle(Theme.muted) }
        }.card().opacity(revealed ? 1 : 0).offset(y: revealed ? 0 : 14)
            .onAppear { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.5)) { revealed = true } }
            .accessibilityIdentifier("report.growth")
    }
}

struct RunInsightCard: View {
    let run: RunSummary
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("이번 운동 돌아보기", systemImage: "figure.run").font(.headline)
            if run.activityEnvironment.isIndoor {
                Text("실내 활동 · \(clock(run.seconds))")
                Text("실내 걸음 수와 활동시간을 기록했어요. 야외 거리·페이스와 섞어 비교하지 않아요.").foregroundStyle(Theme.muted)
            } else {
                if let running = run.runningSeconds {
                    HStack { metric("달리기", clock(running)); Spacer(); metric("걷기 등 이동", clock(max(0, run.seconds - running))) }
                }
                if let elapsed = run.elapsedSeconds {
                    Text("이동하지 않은 시간 · \(clock(max(0, elapsed - run.seconds)))")
                    Text("활동시간에는 신호 대기 같은 정지가 포함돼요. 최근 버전의 수동 일시정지 시간은 제외합니다.").font(.caption).foregroundStyle(Theme.muted)
                }
                if let report = run.paceReport {
                    Text("이동 중 GPS 양호 · \(Int(report.goodSignalFraction * 100))%")
                    Text(report.goodSignalFraction < 0.8 ? "GPS가 불안정했던 활동이에요. 평균 페이스 하나만으로 이전 운동보다 느려졌다고 판단하지 마세요." : "거리와 시간에 걷기·정지 구간을 함께 살펴보세요. 평균 페이스는 순수 달리기 구간의 속도와 달라요.")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
            }
        }.font(.callout).card()
    }
}

struct ActivityReportView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedDay: Date?
    @State private var chartRevealed = false
    private var report: ActivityInsights { ActivityInsights(profile: model.save.profile) }
    var body: some View {
        let report = self.report
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                eyebrow("RUNNING / GROWTH REPORT")
                Text("나의 활동 리포트").font(.largeTitle.bold())
                Text("오늘을 포함한 최근 7일").foregroundStyle(Theme.muted)
                HStack { metric("야외 거리", String(format: "%.2f km", report.outdoorDistance / 1000)); Spacer(); metric("활동한 날", "\(report.activeDays)일") }.card()
                HStack { metric("야외 활동시간", clock(report.outdoorSeconds)); Spacer(); metric("실내·방어전", clock(report.indoorSeconds)) }.card()
                VStack(alignment: .leading, spacing: 12) {
                    Text("하루씩 쌓인 거리").font(.headline)
                    Chart(report.days) { day in
                        BarMark(x: .value("날짜", day.date, unit: .day), y: .value("거리(km)", chartRevealed ? day.distance / 1000 : 0))
                            .foregroundStyle(Theme.teal.gradient).cornerRadius(4)
                            .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
                            .accessibilityValue(String(format: "%.2f km", day.distance / 1000))
                    }.chartYScale(domain: 0...max(1, (report.days.map(\.distance).max() ?? 0) / 1000 * 1.15))
                        .chartYAxisLabel("km").frame(height: 170).accessibilityIdentifier("report.distance.chart")
                        .onAppear { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.65)) { chartRevealed = true } }
                    HStack {
                        ForEach(report.days) { day in
                            Button { selectedDay = day.date } label: {
                                Text(day.date, format: .dateTime.weekday(.narrow)).font(.caption).frame(maxWidth: .infinity).frame(minHeight: 44)
                                    .background(selectedDay == day.date ? Theme.teal.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 8))
                            }.buttonStyle(.plain).accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted) + " 활동 보기")
                        }
                    }
                    if let day = report.days.first(where: { $0.date == selectedDay }) {
                        Text(String(format: "야외 %.2f km · 이동 %@ · 실내·방어전 %@", day.distance / 1000, clock(day.seconds), clock(day.indoorSeconds))).font(.caption)
                    } else { Text("날짜를 눌러 하루의 기록을 확인하세요.").font(.caption).foregroundStyle(Theme.muted) }
                    Text(String(format: "직전 7일 %.2f km → 이번 7일 %.2f km", report.previousDistance / 1000, report.outdoorDistance / 1000)).font(.callout)
                    Text("비교용 기록이며 달성해야 할 목표가 아니에요. 쉬는 날은 미달성으로 처리하지 않아요.").font(.caption).foregroundStyle(Theme.muted)
                }.card()
                VStack(alignment: .leading, spacing: 12) {
                    Text("운동과 게임에서 남긴 것").font(.headline)
                    Text("활동 \(report.activityCount)회 · 토벌 \(report.defeats)회")
                    Text("야외·실내 러닝 EXP +\(report.experience)").foregroundStyle(Theme.teal)
                    if let gps = report.gpsFraction { Text("기록이 있는 활동의 GPS 양호 비율 · 약 \(Int(gps * 100))%").font(.caption) }
                    Text("방어전은 운동 시간·횟수에 포함하고, 러닝 거리와 EXP 집계에는 합치지 않아요. GPS 비율은 기록이 있는 활동의 이동시간으로 가중한 값이에요.").font(.caption).foregroundStyle(Theme.muted)
                    if let pace = report.averagePaceSeconds {
                        Text("야외 전체 평균 · \(clock(pace)) /km")
                        Text("걷기와 정지가 섞인 평균이에요. 코스·날씨·운동 방식이 달라 속도 향상을 판정하지 않아요.").font(.caption).foregroundStyle(Theme.muted)
                    }
                }.card()
                let levels = model.save.profile.runs.filter { $0.growthReport != nil }.sorted { $0.date < $1.date }
                if !levels.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("활동 레벨의 발자취").font(.headline)
                        Chart(Array(levels.suffix(30))) { run in
                            LineMark(x: .value("날짜", run.date), y: .value("레벨", run.growthReport?.levelAfter ?? 1)).foregroundStyle(Theme.teal)
                            PointMark(x: .value("날짜", run.date), y: .value("레벨", run.growthReport?.levelAfter ?? 1)).foregroundStyle(Theme.teal)
                        }.frame(height: 130)
                        Text("성장 리포트가 있는 최근 30회 활동 종료 시점만 표시해요. 등급은 레벨과 별도로 진행해요.").font(.caption).foregroundStyle(Theme.muted)
                    }.card()
                }
                EquipmentGoalCard()
                Text(report.activityCount == 0 ? "첫 기록이 생기면 여기에 운동과 성장의 흐름을 모아드릴게요." : "기록을 남긴 하루도, 쉬어 간 하루도 다음 활동으로 이어집니다.")
                    .font(.callout).foregroundStyle(Theme.muted)
            }.padding(22)
        }.labyrinthScreen().navigationTitle("활동 리포트").navigationBarTitleDisplayMode(.inline)
    }
}
