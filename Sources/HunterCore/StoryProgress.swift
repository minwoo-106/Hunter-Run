import Foundation

public struct StoryEntry: Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let artwork: String
    public let requirement: String
    public let paragraphs: [String]
}

/// Dispatches use settled, real activity records. Reading is never a source of rewards.
public enum StoryProgress {
    public static let entries: [StoryEntry] = [
        StoryEntry(id: "arrival", title: "01 · 다시 켜진 관제실", subtitle: "임시 지부 / 신규 통신", artwork: "AssociationOffice", requirement: "처음부터 열림", paragraphs: [
            "협회 건물의 불이 하나씩 켜졌습니다. 오랫동안 비어 있던 관제실에서, 누군가 당신의 호출 부호를 확인합니다.",
            "“연결됐네요. 저는 이 지부의 현장 관제를 맡고 있어요. 오늘부터 당신의 이동 기록을 함께 살펴보겠습니다.”",
            "폐쇄 구역 가장자리에서 같은 신호가 반복되고 있습니다. 아직 정체는 모릅니다. 우선 평소 다니던 길에서 흔적부터 모아보기로 합니다. 서두를 필요는 없습니다."
        ]),
        StoryEntry(id: "signal", title: "02 · 발걸음 사이의 신호", subtitle: "첫 현장 보고", artwork: "AssociationOffice", requirement: "실제 활동 한 번에서 활동시간 5분 확보 후 저장", paragraphs: [
            "당신이 돌아온 뒤에도 관제실의 작은 표시등은 깜빡이고 있었습니다. 오퍼레이터가 이번 이동 기록을 이전 관측값 옆에 놓습니다.",
            "“잡음인 줄 알았는데, 간격이 일정해요. 누군가 대답을 기다리는 것처럼요.”",
            "신호는 특정 좌표를 가리키지 않습니다. 협회는 위험한 곳으로 접근하는 대신, 평소 활동에서 얻는 기록을 더 비교하기로 했습니다. 첫 보고가 서류함에 꽂힙니다."
        ]),
        StoryEntry(id: "pattern", title: "03 · 두 번째 관측", subtitle: "비교 기록 / 패턴 확인", artwork: "AssociationOffice", requirement: "시간 또는 거리 목표를 달성한 실제 활동 2회", paragraphs: [
            "두 번째 보고가 들어오자, 불규칙하던 파형의 일부가 겹쳤습니다. 장소는 달랐지만 반응은 닮아 있었습니다.",
            "“이제 하나의 우연이라고 보기는 어렵겠어요. 관측 장비를 확장하면 숨어 있는 층을 더 볼 수 있겠습니다.”",
            "협회는 당신을 임시 지부의 현장 담당으로 기록했습니다. 관측과 연구, 장비와 의뢰. 어느 부서부터 키울지는 이제 함께 결정할 수 있습니다."
        ]),
        StoryEntry(id: "branch", title: "04 · 지부의 이름", subtitle: "두 부서 확장 / 정식 관측 지부", artwork: "AssociationOperational", requirement: "협회 부서 2개를 Lv.2로 확장", paragraphs: [
            "비어 있던 책상에 관측 장비가 놓였습니다. 벽면 지도에는 현장 보고를 묶어 읽을 수 있는 표시가 생겼습니다.",
            "“오늘부로 정식 관측 지부예요. 종이에 적힌 이름 하나지만, 우리가 할 수 있는 일이 달라졌습니다.”",
            "새 장비는 강한 마력 반응을 분리해냈습니다. 오퍼레이터는 그것을 경계의 군주라고 부릅니다. 한 번의 활동으로 끝내려 하지 않아도 됩니다. 모든 보고가 다음 토벌로 이어집니다."
        ]),
        StoryEntry(id: "boundary", title: "05 · 경계 너머의 답신", subtitle: "경계의 군주 토벌 보고", artwork: "AssociationOperational", requirement: "경계의 군주 실제 토벌 1회", paragraphs: [
            "경계의 군주가 남긴 반응이 잦아들자, 그 뒤에 겹쳐 있던 약한 신호가 모습을 드러냈습니다.",
            "“끝난 게 아니라, 가려져 있던 기록이 열린 것 같아요. 누군가 이 모든 관측을 먼저 남겨두었어요.”",
            "협회는 새로운 반응에 공허의 사서라는 이름을 붙였습니다. 다음 활동을 서두르라는 호출은 없습니다. 오퍼레이터는 오늘 보고를 닫고 조용히 말합니다. “수고하셨어요. 나머지는 다음에 이어가죠.”"
        ]),
        StoryEntry(id: "network", title: "06 · 서로의 불빛", subtitle: "광역 작전 지부 / 첫 장의 끝", artwork: "AssociationAdvanced", requirement: "네 부서를 모두 Lv.2로 확장", paragraphs: [
            "관제실을 채운 장비들이 같은 리듬으로 움직입니다. 작은 임시 지부에서 시작한 보고들이 하나의 관측망이 됐습니다.",
            "“처음 켰던 표시등, 기억하세요? 이제는 돌아올 곳을 알려주는 불빛 같아요.”",
            "이 지부의 첫 번째 기록은 여기까지입니다. 아직 밝혀지지 않은 개체와 공허의 사서의 기록은 남아 있습니다. 당신이 다시 움직이는 날, 오퍼레이터도 다음 보고서를 펼칠 것입니다."
        ])
    ]
    private static func eligible(_ index: Int, profile: Profile) -> Bool {
        switch index {
        case 0: return true
        case 1: return profile.runs.contains { $0.seconds >= 300 }
        case 2: return profile.runs.filter(\.completedGoal).count >= 2
        case 3: return AssociationStage.upgrades(profile) >= 2
        case 4: return (profile.bosses?["boundary-lord"]?.clears ?? 0) > 0 || profile.runs.contains { $0.majorBoss?.bossID == "boundary-lord" && $0.majorBoss?.cleared == true }
        case 5: return AssociationStage.upgrades(profile) == 4
        default: return false
        }
    }
    public static func available(_ entry: StoryEntry, profile: Profile) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return false }
        return (0...index).allSatisfy { eligible($0, profile: profile) }
    }
    public static func nextRequirement(_ profile: Profile) -> String? {
        entries.indices.first(where: { !eligible($0, profile: profile) }).map { entries[$0].requirement }
    }
    public static func unread(_ profile: Profile) -> [StoryEntry] {
        entries.filter { available($0, profile: profile) && !(profile.readStories ?? []).contains($0.id) }
    }
    @discardableResult public static func markRead(_ id: String, profile: inout Profile) -> Bool {
        guard let entry = entries.first(where: { $0.id == id }), available(entry, profile: profile) else { return false }
        var read = profile.readStories ?? []; read.insert(id); profile.readStories = read
        return true
    }
}
