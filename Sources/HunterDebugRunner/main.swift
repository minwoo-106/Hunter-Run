import Foundation
import HunterCore

struct ReplaySuiteReport: Codable {
    var schema = 1
    var engine = "RunEngine"
    var total: Int
    var passed: Int
    var results: [ReplayResult]
}

func read<T: Decodable>(_ url: URL, as type: T.Type) throws -> T {
    try JSONDecoder().decode(type, from: Data(contentsOf: url))
}
func frame(_ t: Double, _ distance: Double = 0, movement: Movement = .running, signal: Signal = .good) -> ReplayOperation {
    ReplayOperation(.frame, frame: SensorFrame(timestamp: t, speed: movement == .stationary ? 0 : 2.5,
        distance: distance, movement: movement, signal: signal, distanceDuration: distance > 8 ? distance / 2.5 : nil))
}

struct ReplayFactory {
    var rules: CombatRules
    var catalog: ProgressionCatalog
    var world: WorldContent
    var profile: Profile
    init(resources: URL) throws {
        rules = try read(resources.appendingPathComponent("combat-v3.json"), as: CombatRules.self)
        catalog = try read(resources.appendingPathComponent("progression.json"), as: ProgressionCatalog.self)
        world = try read(resources.appendingPathComponent("world.json"), as: WorldContent.self)
        guard rules.isValid, !world.bosses.isEmpty else { throw ReplayError.invalidScenario }
        try catalog.validate(); try world.validate()
        var save = SaveState(); save.profile.name = "검증용 헌터"; save.profile.xp = 4250
        var growth = save.profile.growth
        for id in ["resonance-blade","barrier-coat","trace-shoes","archive-lens"] {
            guard let item = catalog.equipment.first(where: { $0.id == id }) else { throw ReplayError.invalidScenario }
            growth.owned.insert(id); growth.equipped[item.slot.rawValue] = id
        }
        save.profile.growth = growth
        try GrowthEconomy.enable(in: &save); profile = save.profile
    }
    func session(_ eventID: String = "beast", boss: BossEncounter? = nil, briefing: Bool = false) -> (RunSession, GameContent) {
        let template = MissionTemplate(id: eventID, title: "대표 전투", kind: boss == nil ? .ambush : .boss,
            startFraction: 0.3, duration: 25, hp: 180, audio: "wolf_intro")
        let content = GameContent(schema: 1, missionTitle: "거리 전투 재생", events: [template])
        var run = RunSession(targetSeconds: 1800, simulated: false, allowPursuit: false,
            mode: boss == nil ? .contract : .gate, loadout: catalog.stats(for: profile))
        run.startedAt = Date(timeIntervalSince1970: 1000); run.activeSeconds = 180
        run.phase = .moving; run.lastTimestamp = 0; run.rulesVersion = 2
        run.combatRules = rules; run.boss = boss; run.consumed.insert(eventID)
        var event = RunEvent(template: template, hp: 180, startingHP: 180, baseline: 2.5)
        event.stage = briefing ? .briefing : .active
        run.event = event; run.missionSnapshot = content
        return (run, content)
    }
    func scenario(_ name: String, note: String, initial: (RunSession,GameContent)? = nil,
                  operations: [ReplayOperation], expected: [ReplayExpectation]) -> ReplayScenario {
        let (run, content) = initial ?? session()
        return ReplayScenario(name: name, note: note, profile: profile, session: run, content: content,
            operations: operations, expected: expected)
    }
    func suite() -> [ReplayScenario] {
        let finish = [ReplayOperation(.finish),ReplayOperation(.settle),ReplayOperation(.settle)]
        var scenarios: [ReplayScenario] = []
        scenarios.append(scenario("74m → 75m → 늑대 토벌", note: "거리 경계·오버킬·25EXP 한 번 지급", operations:
                [frame(1,74),frame(2,1),frame(3,75)] + finish,
                expected:[.init("attacks",2),.init("damage",180),.init("gainedXP",43),.init("settlements",1)]))
        scenarios.append(scenario("한 프레임에서 파수병 3회 공격", note:"225m 묶음 입력·실제 피해320으로 제한",initial:session("contract-endurance"),operations:
                [frame(1,225)] + finish,expected:[.init("attacks",3),.init("damage",320),.init("gainedXP",53)]))
        scenarios.append(scenario("일시정지와 오래된 GPS 묶음",note:"멈춘 구간의 거리를 공격으로 돌려주지 않음",operations:
                [frame(1,74),.init(.pause),frame(100),.init(.resume),frame(101),frame(102,150),frame(103,1)] + finish,
                expected:[.init("attacks",1),.init("enemyHP",21),.init("gainedXP",18)]))
        scenarios.append(scenario("GPS 불량 91초 후 복귀",note:"공격을 보류하고 현재 몬스터와74m를 보존",operations:
                [frame(1,74)] + (2...92).map { frame(Double($0),5,signal:.unavailable) } + [frame(93,1)] + finish,
                expected:[.init("attacks",1),.init("enemyHP",21),.init("gainedXP",27)]))
        scenarios.append(scenario("정지 → 자동 일시정지 → 복귀",note:"정지·복귀 확인 중 공격 없음",operations:
                [frame(1,74)] + (2...10).map { frame(Double($0),movement:.stationary) }
                + (11...15).map { frame(Double($0),1) } + [frame(16,1)] + finish,
                expected:[.init("attacks",1),.init("enemyHP",21),.init("gainedXP",18)]))
        scenarios.append(scenario("앱 복구와 안내 재확인",note:"세션을 저장·복원한 뒤 안내 완료 후 재개",operations:
                [frame(1,74),.init(.recover),frame(10000),.init(.resume),frame(10001),.init(.instructionFinished),frame(10002,1)] + finish,
                expected:[.init("attacks",1),.init("enemyHP",21),.init("gainedXP",18)]))
        scenarios.append(scenario("빠른 걷기는 전투 거리가 아님",note:"과거 제보 상황을 합성 재현한 입력이며 실제 GPS 원본은 아님",operations:
                (1...60).map { frame(Double($0),2.5,movement:.walking) } + finish,
                expected:[.init("attacks",0),.init("enemyHP",180),.init("gainedXP",24)]))
        scenarios.append(scenario("중복·역순·긴 입력 공백",note:"같은 입력과 오프라인 공백을 다시 공격으로 계산하지 않음",operations:
                [frame(1,74),frame(1,75),frame(0,75),frame(100,75),frame(101,1)] + finish,
                expected:[.init("attacks",1),.init("enemyHP",21),.init("gainedXP",18)]))
        scenarios.append(scenario("안내 중 이동과 묶음 GPS",note:"안내가 끝나기 전 이동은 공격에 반영하지 않음",initial:session(briefing:true),operations:
                [frame(1,74),.init(.instructionFinished),frame(2,75)] + (3...32).map { frame(Double($0)) } + [frame(33,75)] + finish,
                expected:[.init("attacks",1),.init("enemyHP",21),.init("gainedXP",21)]))
        let normal = session()
        scenarios.append(scenario("일반 몬스터는 다음 세션에서 초기화",note:"미완료 피해159를 다음 늑대에 이전하지 않음",operations:
            [frame(1,75),.init(.finish),.init(.settle),.init(.beginSession,session:normal.0,content:normal.1)],
            expected:[.init("enemyHP",180),.init("attacks",0),.init("gainedXP",18),.init("settlements",1)]))
        var boss = world.bosses[0]; boss.maximumHP = 2200
        let first = session("major-strike-a",boss:BossEncounter(definition:boss,state:BossState(maximumHP:2200)))
        var nextState = BossState(maximumHP:2200); nextState.remainingHP = 2066
        let next = session("major-strike-a",boss:BossEncounter(definition:boss,state:nextState))
        scenarios.append(scenario("주요 보스는 다음 세션으로 누적",note:"첫134피해 보존·다음2066피해·토벌 보상 한 번",initial:first,operations:
            [frame(1,75),.init(.finish),.init(.settle),.init(.recover),.init(.beginSession,session:next.0,content:next.1),frame(1,1200)] + finish,
            expected:[.init("enemyHP",0),.init("damage",2066),.init("gainedXP",276),.init("settlements",2)]))
        var final = session(); final.0.targetSeconds = 182
        scenarios.append(scenario("목표 완료와 마지막 공격이 같은 프레임",note:"마지막75m 처리 후 종료·종료 뒤 복귀 차단",initial:final,operations:
            [frame(1,75),frame(2,75),.init(.settle),.init(.resume),.init(.recover),frame(3,75),.init(.settle)],
            expected:[.init("finished",1),.init("attacks",2),.init("damage",180),.init("gainedXP",43),.init("settlements",1)]))
        return scenarios
    }
}

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    func argument(_ key: String) -> String? {
        guard let i = arguments.firstIndex(of:key), arguments.indices.contains(i+1) else { return nil }
        return arguments[i+1]
    }
    let base = URL(fileURLWithPath:FileManager.default.currentDirectoryPath)
    let resources = argument("--resources").map { URL(fileURLWithPath:$0) } ?? base.appendingPathComponent("Resources")
    let output = argument("--output").map { URL(fileURLWithPath:$0) } ?? base.appendingPathComponent(".build/combat-replay")
    if arguments.contains("--balance-report") {
        try BalanceReport.generate(resources: resources, output: output)
        exit(0)
    }
    let scenarios: [ReplayScenario]
    if let file = argument("--scenario") {
        let url = URL(fileURLWithPath:file)
        guard (try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0) <= 10_000_000 else { throw ReplayError.invalidScenario }
        scenarios = [try read(url,as:ReplayScenario.self)]
    } else { scenarios = try ReplayFactory(resources:resources).suite() }
    let results = try scenarios.map(DebugReplayRunner.run)
    let report = ReplaySuiteReport(total:results.count,passed:results.filter(\.passed).count,results:results)
    try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
    try encoder.encode(report).write(to:output.appendingPathComponent("replay-results.json"),options:.atomic)
    let traces = output.appendingPathComponent("scenarios")
    try FileManager.default.createDirectory(at:traces,withIntermediateDirectories:true)
    for (index,scenario) in scenarios.enumerated() {
        try encoder.encode(scenario).write(to:traces.appendingPathComponent(String(format:"%02d.json",index+1)),options:.atomic)
    }
    for result in results {
        print("\(result.passed ? "통과" : "실패") · \(result.name)")
        for check in result.checks where !check.passed { print("  \(check.metric): 기대\(check.expected),실제\(check.actual.map { String($0) } ?? "없음")") }
    }
    print("대표 시나리오 \(report.passed)/\(report.total) 통과 · 실제 저장 파일 변경 없음")
    exit(report.passed == report.total ? 0 : 1)
} catch {
    FileHandle.standardError.write(Data("재생 실행 실패: \(error.localizedDescription)\n".utf8))
    exit(2)
}
