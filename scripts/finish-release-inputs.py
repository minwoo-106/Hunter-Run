from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
def edit(name, pairs):
    p=root/name
    s=p.read_text(encoding="utf-8")
    for before,after in pairs:
        if before in s: s=s.replace(before,after)
        elif after not in s: raise ValueError((name,before))
    p.write_text(s,encoding="utf-8")
edit("scripts/expand-release-content.py", [("'pursuit',10,125,'C',True", "'boss',10,125,'C',True")])
edit("Tests/HunterCoreTests/ProgressionTests.swift", [
    ("catalog.equipment.count, 20", "catalog.equipment.count, 32"),
    ('XCTAssertTrue(catalog.unlocked("analysis", profile: save.profile))', 'XCTAssertTrue(catalog.unlocked("analysis", profile: save.profile))\n        XCTAssertThrowsError(try Progression.upgrade(.research, save: &save, catalog: catalog))\n        var qualified = save.profile.growth; qualified.rank = "C"; save.profile.growth = qualified'),
    ('XCTAssertFalse(Progression.allows(.gate, profile: save.profile, catalog: catalog))', 'var entryRank = save.profile.growth; entryRank.rank = "E"; save.profile.growth = entryRank\n        XCTAssertFalse(Progression.allows(.gate, profile: save.profile, catalog: catalog))')
])
edit("Tests/HunterCoreTests/WorldContentTests.swift",[("world.monsters.count, 11","world.monsters.count, 17")])
edit("Tests/HunterCoreTests/FieldExpansionTests.swift", [
    ('g.rank = "D"', 'g.rank = "B"'),
    ('p.growth = g; return p', 'p.growth = g; var journey = JourneyState(); journey.unlocked = Set((1...16).map { String(format: "M%02d", $0) }); p.journey = journey; return p'),
    ('XCTAssertEqual(c.encounters.filter { $0.available(to: p, catalog: g) }.map(\\.id), ["dark-elf-scout"])', 'XCTAssertTrue(c.encounters.filter { $0.available(to: p, catalog: g) }.isEmpty)'),
    ('.count, 4)', '.count, 10)'),
    ('for cycle in 0..<3', 'for cycle in 0..<12'),
    ('save.profile.crystals = 1000; save.profile.research = 1000', 'save.profile = unlocked(); var entry = save.profile.growth; entry.departments = [:]; save.profile.growth = entry\n        save.profile.crystals = 1000; save.profile.research = 1000')
])
edit("App/HunterRunApp.swift", [
    ("자유 활동은 승급의 목표 완료 횟수에는 포함되지 않습니다.", "자유 활동 시간도 승급 심사 자격에 포함돼요."),
    ("음성 · 음악 혼합 테스트", "안내 음성 미리 듣기"),
    ("안내 음성 테스트", "안내 음성 미리 듣기"),
    ("새 음색으로 미리 제작한 한국어 합성 안내 80개가 적용되어 있습니다.", "상황별 한국어 안내가 오프라인으로 재생돼요.")
])
edit("scripts/validate.py", [
    ('== len(keys) == 80','== len(keys) == 113'),
    ('Validated 80 designed','Validated 113 designed'),
    ("== 20","== 32"),
    ("Validated 20 equipment","Validated 32 equipment"),
    ("twenty individual","thirty-two individual"),
    ("len(world['monsters']) == 11","len(world['monsters']) == 17"),
    ("len(narration['encounters']) == 11","len(narration['encounters']) == 17"),
    ("len(encounters['encounters']) == 4","len(encounters['encounters']) == 10"),
    ("'AssociationOperational', 'AssociationAdvanced'","'AssociationOperational', 'AssociationAdvanced', 'AssociationResearch', 'AssociationBeacon'"),
    ("eleven monster illustrations, three association stages","seventeen monster illustrations, five association stages"),
    ("four encounter pools","ten encounter pools")
])
print("Release input expectations and player copy updated.")
