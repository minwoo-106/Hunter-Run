import SwiftUI

/// 정산은 완료된 RunSummary를 사용하고, 화면의 숫자와 등장 순서만 연출한다.
struct RewardReceiptView: View {
    let run: RunSummary
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var clock: PresentationClock?
    private var progress: Double { reduceMotion ? 1 : clock?.progress ?? 0 }
    private var count: Int {
        let t = min(1, progress / 0.8)
        return Int((Double(run.xp) * (1 - pow(1 - t, 3))).rounded())
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("활동 보상 확보", systemImage: "checkmark.seal.fill")
                .font(.headline).foregroundStyle(Theme.teal)
                .opacity(min(1, progress * 6))
            Text("EXP +\(count)").font(.system(size: 32, weight: .bold, design: .rounded)).monospacedDigit()
                .foregroundStyle(Theme.teal).contentTransition(.numericText())
                .accessibilityLabel("획득 경험치 \(run.xp)")
            HStack { Text("마정석"); Spacer(); Text("+\(run.crystals)") }
                .opacity(min(1, max(0, (progress - 0.15) * 5)))
            HStack { Text("조사 데이터"); Spacer(); Text("+\(run.research ?? 0)") }
                .opacity(min(1, max(0, (progress - 0.3) * 5)))
            HStack { Text("코어"); Spacer(); Text("+\(run.cores ?? 0)") }
                .opacity(min(1, max(0, (progress - 0.45) * 5)))
        }.font(.callout).card()
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.teal.opacity(sin(progress * .pi) * 0.55), lineWidth: 1).allowsHitTesting(false))
            .accessibilityIdentifier("report.reward.receipt")
            .onChange(of: scenePhase) { _, phase in clock?.setActive(phase == .active, at: ProcessInfo.processInfo.systemUptime) }
            .task(id: scenePhase) {
                guard !reduceMotion, scenePhase == .active else { return }
                if clock == nil { clock = PresentationClock(duration: 1.4, handoff: 1, at: ProcessInfo.processInfo.systemUptime) }
                clock?.setActive(true, at: ProcessInfo.processInfo.systemUptime)
                while !Task.isCancelled, clock?.complete == false {
                    do { try await Task.sleep(for: .milliseconds(33)) } catch { return }
                    guard !Task.isCancelled else { return }
                    clock?.advance(to: ProcessInfo.processInfo.systemUptime)
                }
            }
    }
}
