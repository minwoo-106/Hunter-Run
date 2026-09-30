import SwiftUI

/// Actual facilities, resources and story state. No preview presets ship in the app.
struct AssociationFacilitiesView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                eyebrow("ASSOCIATION / GATE ANNEX")
                Text("우리의 지부").font(.largeTitle.bold())
                Text("협회 지하의 안정화 게이트로 연결된 시설 구역이에요. 유적의 공명 설비에 지부 장비를 연결했어요.")
                    .font(.callout).foregroundStyle(Theme.muted)
                ResourceStrip()
                FacilityMap()
                Text("시설을 눌러 안으로 들어가세요. 확장하면 설비와 내부 모습이 함께 달라져요.")
                    .font(.caption).foregroundStyle(Theme.muted)
            }.padding(.horizontal, 20).padding(.vertical, 16)
        }.background(Theme.ink).navigationTitle("협회 시설").navigationBarTitleDisplayMode(.inline)
    }
}

private struct FacilityMap: View {
    @EnvironmentObject var model: AppModel
    private var stage: HaesolSanctum.Stage { HaesolSanctum.stage(model.save.profile) }
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image("FacilityBase-1").resizable().scaledToFit().accessibilityHidden(true)
                ForEach(Department.allCases, id: \.rawValue) { department in
                    Image("FacilityBase-\(min(3, model.save.profile.growth.level(department)))")
                        .resizable().scaledToFit().clipShape(FacilityRegion(department: department))
                        .accessibilityHidden(true)
                }
                if stage == .operational || stage == .restored {
                    Image("FacilityBase-Sanctum").resizable().scaledToFit()
                        .clipShape(FacilityRegion(department: nil)).accessibilityHidden(true)
                }
                ForEach(Department.allCases, id: \.rawValue) { department in
                    let point = position(department)
                    NavigationLink { FacilityRoomView(department: department) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(department.title).font(.caption.bold())
                            Text("Lv.\(model.save.profile.growth.level(department))").font(.caption2.monospacedDigit()).foregroundStyle(Theme.teal)
                        }.frame(width: min(100, geo.size.width * 0.29), alignment: .leading).padding(8)
                            .background(Theme.ink.opacity(0.93), in: RelicShape(cut: 5))
                            .overlay(RelicShape(cut: 5).stroke(Labyrinth.gold.opacity(0.7), lineWidth: 1))
                    }.buttonStyle(.plain).position(x: geo.size.width * point.x, y: geo.size.height * point.y)
                        .accessibilityLabel(department.title + " Lv.\(model.save.profile.growth.level(department)) 내부 보기")
                        .accessibilityIdentifier("facility." + department.rawValue)
                }
                // The unbuilt terrace has no label, control, accessibility element or tap gesture.
                if stage != .hidden {
                    NavigationLink { SanctumFacilityView() } label: {
                        VStack(spacing: 3) {
                            Text("귀환 정화실").font(.caption.bold())
                            Text(stage == .buildable ? "건설 가능" : stage == .operational ? "가동 대기" : "정화 완료")
                                .font(.caption2).foregroundStyle(Theme.teal)
                        }.padding(9).background(Theme.ink.opacity(0.94), in: RelicShape(cut: 5))
                            .overlay(RelicShape(cut: 5).stroke(Labyrinth.gold, lineWidth: 1))
                    }.buttonStyle(.plain).position(x: geo.size.width * 0.5, y: geo.size.height * 0.16)
                        .accessibilityIdentifier("facility.sanctum")
                }
            }
        }.aspectRatio(2.0 / 3.0, contentMode: .fit).accessibilityIdentifier("facility.map")
    }
    private func position(_ department: Department) -> CGPoint {
        switch department {
        case .observation: return CGPoint(x: 0.24, y: 0.36)
        case .research: return CGPoint(x: 0.77, y: 0.37)
        case .equipment: return CGPoint(x: 0.23, y: 0.60)
        case .contracts: return CGPoint(x: 0.77, y: 0.62)
        }
    }
}

private struct FacilityRegion: Shape {
    let department: Department?
    func path(in rect: CGRect) -> Path {
        let points: [CGPoint]
        switch department {
        case .observation: points = [p(0,0.16),p(0.49,0.19),p(0.52,0.36),p(0.29,0.43),p(0,0.39)]
        case .research: points = [p(0.54,0.17),p(1,0.16),p(1,0.40),p(0.76,0.44),p(0.52,0.36)]
        case .equipment: points = [p(0,0.38),p(0.28,0.38),p(0.51,0.50),p(0.46,0.65),p(0.24,0.70),p(0,0.63)]
        case .contracts: points = [p(0.74,0.39),p(1,0.39),p(1,0.65),p(0.74,0.72),p(0.51,0.60),p(0.50,0.50)]
        case nil: points = [p(0.24,0.05),p(0.78,0.05),p(0.78,0.21),p(0.65,0.26),p(0.50,0.30),p(0.30,0.24),p(0.24,0.18)]
        }
        return Path { path in
            path.addLines(points.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) })
            path.closeSubpath()
        }
    }
    private func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
}

private struct FacilityRoomView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false
    let department: Department
    private var level: Int { min(3, max(1, model.save.profile.growth.level(department))) }
    private var next: DepartmentUpgrade? {
        model.progressionCatalog?.upgrades.first { $0.department == department && $0.level == level + 1 }
    }
    private var canUpgrade: Bool {
        guard let next else { return false }
        return !model.growthLocked && next.available(to: model.save.profile)
            && model.save.profile.crystals >= next.crystals && model.save.profile.research >= next.research
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FacilityHero(artwork: "Facility-\(department.rawValue)-\(level)", title: department.title, status: "Lv.\(level)")
                    .id(level).transition(.opacity)
                VStack(alignment: .leading, spacing: 18) {
                    HStack { Text(headline).font(.title2.bold()); Spacer(); Text("가동 중").font(.caption2).foregroundStyle(Theme.teal) }
                    Text(detail).font(.callout).foregroundStyle(Theme.muted)
                    ResourceStrip()
                    NavigationLink { destination } label: { Label(action, systemImage: department.symbol) }
                        .buttonStyle(GameButtonStyle(primary: true)).accessibilityIdentifier("facility.work")
                    if department == .observation && level >= 3 {
                        NavigationLink { BossBoardView() } label: { Label("주요 게이트 관측", systemImage: "shield.lefthalf.filled") }
                            .buttonStyle(GameButtonStyle())
                    }
                    if let next {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("다음 확장 · Lv.\(next.level)").font(.headline)
                            Text(next.playerHint).font(.callout).foregroundStyle(Theme.muted)
                            Text("마정석 \(next.crystals) · 조사 데이터 \(next.research)").font(.caption.monospacedDigit())
                            if let rank = next.requiredRank { Text("\(rank)급부터 확장할 수 있어요.").font(.caption).foregroundStyle(Labyrinth.gold) }
                            Button("시설 확장") {
                                let old = level
                                model.upgrade(department)
                                if level > old && !reduceMotion {
                                    withAnimation(.easeInOut(duration: 0.65)) { expanded = true }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { withAnimation { expanded = false } }
                                }
                            }.buttonStyle(GameButtonStyle(primary: true)).disabled(!canUpgrade)
                                .accessibilityIdentifier("facility.upgrade")
                            if model.growthLocked { Text("진행 중인 활동을 마친 뒤 확장할 수 있어요.").font(.caption).foregroundStyle(Theme.muted) }
                        }.card()
                    } else { Label("전문 시설 확장 완료", systemImage: "checkmark.seal").foregroundStyle(Theme.teal).card() }
                }.padding(.horizontal, 20).padding(.bottom, 24)
            }
        }.background(Theme.ink).overlay(expanded ? Labyrinth.gold.opacity(0.12) : .clear)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.65), value: level)
            .navigationTitle(department.title).navigationBarTitleDisplayMode(.inline)
            .environment(\.labyrinthStyle, true)
    }
    private var headline: String {
        switch department { case .observation: return "경계 너머를 살피는 곳"; case .research: return "흔적을 해답으로"; case .equipment: return "다음 출발을 준비해요"; case .contracts: return "현장과 지부를 잇는 곳" }
    }
    private var detail: String {
        if level == 1 {
            switch department { case .observation: return "작은 관측 장비로 현장의 반응을 모으고 있어요."; case .research: return "현장에서 가져온 표본과 기록을 차근차근 정리해요."; case .equipment: return "기본 장비를 마련하고 출발 전에 정비해요."; case .contracts: return "지부에 도착한 의뢰를 정리하고 다음 활동을 준비해요." }
        }
        return model.progressionCatalog?.upgrades.first { $0.department == department && $0.level == level }?.reveal ?? "시설을 가동하고 있어요."
    }
    private var action: String {
        switch department { case .observation: return level == 1 ? "현장 관측 기록" : level == 2 ? "주요 게이트 관측" : "엘리트 출현 정보"; case .research: return level == 1 ? "표본 기록" : level == 2 ? "전투 기록 분석" : "상세 전술 분석"; case .equipment: return "장비 제작·보관"; case .contracts: return "의뢰 확인" }
    }
    @ViewBuilder private var destination: some View {
        switch department {
        case .observation:
            if level == 1 { FieldArchiveView() } else if level == 2 { BossBoardView() } else { EncounterBoardView() }
        case .research: FacilityResearchView()
        case .equipment: EquipmentView()
        case .contracts: QuestBoardView()
        }
    }
}

private struct FacilityResearchView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(model.unlocked("tactical-analysis") ? "기록과 전술을 함께 읽어요." : model.unlocked("analysis") ? "실제 전투 기록을 분석해요." : "현장에서 모은 표본이에요.")
                    .foregroundStyle(Theme.muted)
                let known = model.world?.monsters.filter { $0.isKnown(in: model.save.profile) } ?? []
                if known.isEmpty { Text("현장에서 흔적을 확보하면 이곳에 기록이 쌓여요.").card() }
                ForEach(known) { monster in
                    NavigationLink { MonsterDetailView(monster: monster) } label: { Label(monster.name, systemImage: "doc.text.magnifyingglass") }
                        .buttonStyle(GameButtonStyle())
                }
            }.padding(20)
        }.labyrinthScreen(artwork: "Facility-research-\(min(3, model.save.profile.growth.level(.research)))").navigationTitle("연구 기록")
    }
}

private struct FacilityHero: View {
    let artwork: String
    let title: String
    let status: String
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                Image(artwork).resizable().scaledToFill().frame(width: geo.size.width, height: geo.size.height).clipped()
                    .accessibilityHidden(true)
                LinearGradient(colors: [.clear, Theme.ink], startPoint: .center, endPoint: .bottom)
                FacilityDust().allowsHitTesting(false).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text("헌터 협회 / 게이트 시설").font(.caption2).tracking(2).foregroundStyle(Theme.teal)
                    HStack { Text(title).font(.title.bold()); Spacer(); Text(status).font(.headline.monospacedDigit()).foregroundStyle(Labyrinth.gold) }
                }.padding(20)
            }
        }.frame(height: 350).clipped().accessibilityIdentifier("facility.hero")
    }
}

private struct FacilityDust: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion || scenePhase != .active)) { context in
            Canvas { canvas, size in
                guard !reduceMotion else { return }
                let time = context.date.timeIntervalSinceReferenceDate
                for index in 0..<10 {
                    let phase = (time / (12 + Double(index)) + Double(index) * 0.173).truncatingRemainder(dividingBy: 1)
                    let x = size.width * CGFloat((Double(index) + 0.5) / 10) + CGFloat(sin(time * 0.25 + Double(index)) * 5)
                    let y = size.height * CGFloat(1 - phase)
                    let opacity = sin(phase * .pi) * 0.28
                    canvas.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.8, height: 1.8)), with: .color(Labyrinth.parchment.opacity(opacity)))
                }
            }
        }
    }
}

private struct SanctumFacilityView: View {
    @EnvironmentObject var model: AppModel
    private var stage: HaesolSanctum.Stage { HaesolSanctum.stage(model.save.profile) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if stage != .hidden {
                    FacilityHero(artwork: stage == .buildable ? "FacilityBase-1" : "PurificationRoom",
                                 title: "귀환 정화실", status: stage == .buildable ? "건설 가능" : stage == .restored ? "정화 완료" : "가동 대기")
                    VStack(alignment: .leading, spacing: 16) {
                        if stage == .buildable {
                            Text("확보한 부지에 정화 설비를 마련해요. 건설 비용이나 레벨 확장은 없어요.").foregroundStyle(Theme.muted)
                            Button("정화실 건설") { model.buildSanctum() }.buttonStyle(GameButtonStyle(primary: true))
                                .disabled(model.growthLocked).accessibilityIdentifier("association.sanctum.build")
                        } else if stage == .operational {
                            Text("설비 준비를 마쳤어요. 귀환한 분들의 정화 절차를 시작할 수 있어요.").foregroundStyle(Theme.muted)
                            Button("정화실 가동") { model.restoreHaesol() }.buttonStyle(GameButtonStyle(primary: true))
                                .disabled(model.growthLocked).accessibilityIdentifier("association.sanctum.restore")
                        } else {
                            Text("정화 절차를 마쳤어요. 마지막 이야기를 스토리에서 확인해요.").foregroundStyle(Theme.muted)
                            if model.save.profile.journey?.completed.contains("M21") == true {
                                NavigationLink("강해솔의 일상 보기") { HaesolMomentsView() }.buttonStyle(GameButtonStyle())
                                    .accessibilityIdentifier("association.haesol.moments")
                            }
                        }
                    }.padding(20)
                }
            }
        }.background(Theme.ink).navigationTitle("귀환 정화실").navigationBarTitleDisplayMode(.inline)
            .environment(\.labyrinthStyle, true)
    }
}
