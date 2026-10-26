import SwiftUI

struct CombatFocusView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let run: RunSession
    let battle: DistanceBattle
    let movement: Movement
    let signal: Signal
    @State private var struck = false
    private var status: EnduranceGuidance { EnduranceGuidance.state(for: run, movement: movement, signal: signal) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 18) {
                ZStack {
                    Circle().stroke(.white.opacity(0.1), lineWidth: 4)
                    Circle().trim(from: 0, to: min(1, battle.remainder / 75)).stroke(status == .counting ? Theme.teal : Theme.muted, style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))
                    Image("Monster-" + battle.monster.id).resizable().scaledToFill().frame(width: 74, height: 74).clipShape(Circle())
                        .scaleEffect(struck ? 0.94 : 1)
                    if struck { Text("−\(Int(DistanceBattle.damagePerAttack(attack: run.loadout?.attack ?? 1, defense: battle.monster.defense)))").font(.headline.bold()).foregroundStyle(.white).shadow(color: .black, radius: 4).offset(y: -28) }
                }.frame(width: 88, height: 88)
                VStack(alignment: .leading, spacing: 8) {
                    Text("적 체력").font(.caption).foregroundStyle(Theme.muted)
                    Text("\(Int(battle.remainingHP)) / \(Int(battle.monster.maximumHP))").font(.title3.bold().monospacedDigit())
                    ProgressView(value: max(0, battle.remainingHP / battle.monster.maximumHP)).tint(Theme.teal)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: battle.remainingHP)
                    Text("다음 공격까지 유효 거리 \(Int(ceil(75 - battle.remainder)))m").font(.caption)
                }
            }
            HStack {
                Text("전체 이동 \(Int(run.distance))m")
                Spacer()
                Text("이번 교전 \(Int(Double(battle.attacks) * 75 + battle.remainder))m")
            }.font(.caption.monospacedDigit()).foregroundStyle(Theme.muted)
            Text("원형 = 다음 공격까지 · 가로 막대 = 남은 적 체력").font(.caption2).foregroundStyle(Theme.muted)
        }.accessibilityElement(children: .contain).accessibilityIdentifier("combat.focus")
            .task(id: battle.attacks) {
                guard battle.attacks > 0, !reduceMotion else { return }
                withAnimation(.easeOut(duration: 0.12)) { struck = true }
                do { try await Task.sleep(for: .milliseconds(320)) } catch { struck = false; return }
                withAnimation(.easeOut(duration: 0.15)) { struck = false }
            }
    }
}
