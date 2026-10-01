import Foundation

public enum OperatorGift: String, Codable, CaseIterable, Identifiable {
    case flower, bookmark, warmLight, coolLight
    public var id: String { rawValue }
    public var name: String {
        switch self {
        case .flower: return "빛을 머금은 작은 꽃"
        case .bookmark: return "은빛 책갈피"
        case .warmLight: return "따뜻한 빛 조각"
        case .coolLight: return "시원한 빛 조각"
        }
    }
    public var symbol: String {
        switch self {
        case .flower: return "leaf"
        case .bookmark: return "bookmark"
        case .warmLight: return "sun.max"
        case .coolLight: return "snowflake"
        }
    }
    public var detail: String {
        switch self {
        case .flower: return "돌아오는 길에도 은은한 빛이 남아 있어요."
        case .bookmark: return "작은 문양이 새겨진, 손바닥만 한 책갈피예요."
        case .warmLight: return "손에 쥐면 온기가 느껴지는 작은 결정이에요."
        case .coolLight: return "맑은 푸른빛과 서늘한 감촉이 남은 결정이에요."
        }
    }
}
public struct OperatorGiftState: Codable, Equatable {
    public var inventory: [String: Int] = [:]
    public var explorationSeconds: Double = 0
    public var given = 0
    public init() {}
    public var isValid: Bool {
        explorationSeconds.isFinite && (0..<OperatorGifts.interval).contains(explorationSeconds)
        && (0...1_000_000).contains(given) && inventory.count <= OperatorGift.allCases.count
        && inventory.allSatisfy { OperatorGift(rawValue: $0.key) != nil && (0...99).contains($0.value) }
    }
}
public struct GiftReaction {
    public var text: String
    public var expression: String
    public var affinity: Int
}
public enum OperatorGifts {
    public static let interval: Double = 1800
    /// Called only from the idempotent real activity settlement transaction.
    static func collect(_ session: RunSession, profile: inout Profile) -> [OperatorGift] {
        guard session.phase == .finished, !session.simulated, !session.isIndoor,
              session.mode == .exploration, ActivityRecordPolicy.qualifies(session.activeSeconds),
              session.activeSeconds.isFinite, session.activeSeconds > 0 else { return [] }
        var journey = profile.journey ?? JourneyState()
        var gifts = journey.gifts ?? OperatorGiftState()
        let total = gifts.explorationSeconds + session.activeSeconds
        let discoveries = min(OperatorGift.allCases.count * 99, Int(min(total / interval, 396)))
        var found: [OperatorGift] = []
        // Stable across save retries. Does not depend on Swift's randomized Hasher.
        let seed = session.id.uuidString.utf8.reduce(0) { ($0 + Int($1)) % OperatorGift.allCases.count }
        for offset in 0..<discoveries {
            let gift = OperatorGift.allCases[(seed + offset) % OperatorGift.allCases.count]
            if gifts.inventory[gift.id, default: 0] < 99 {
                gifts.inventory[gift.id, default: 0] += 1; found.append(gift)
            }
        }
        gifts.explorationSeconds = total.truncatingRemainder(dividingBy: interval)
        journey.gifts = gifts; profile.journey = journey
        return found
    }
    /// Inventory and affinity settle together inside AppModel's atomic save write.
    public static func give(_ gift: OperatorGift, profile: inout Profile) -> GiftReaction? {
        guard var journey = profile.journey, var gifts = journey.gifts,
              gifts.inventory[gift.id, default: 0] > 0, gifts.given < 1_000_000 else { return nil }
        let first = gifts.given == 0
        gifts.inventory[gift.id, default: 0] -= 1; gifts.given += 1
        let gained = journey.gainAffinity(2)
        journey.gifts = gifts
        let text: String
        switch gift {
        case .flower:
            text = "이 작은 꽃을 저 주려고 챙겨오신 거예요?\n고마워요. 컵 옆에 두면 일하다가도 자꾸 보게 되겠네요."
        case .bookmark:
            text = "딱 필요했어요. 읽던 데를 영수증으로 표시해뒀거든요.\n이번엔 제대로 된 책갈피네요. 잘 쓸게요."
        case .warmLight:
            text = journey.memories["drink"] == "warm"
                ? "따뜻한 걸 좋아하신다고 했죠? 선물도 따뜻하네요.\n손에 쥐고 있으니까 기분이 좋아요. 고마워요."
                : "어, 손에 쥐니까 따뜻해요. 신기하네요.\n책상에 두고 손이 차가울 때 꺼내봐야겠어요. 고마워요."
        case .coolLight:
            text = journey.memories["drink"] == "cool"
                ? "시원한 걸 고르시더니 선물도 시원한 걸로 가져오셨네요.\n이 푸른빛 예뻐요. 컵 옆에 잘 놓아둘게요."
                : "빛이 정말 맑네요. 만지니까 살짝 서늘하고요.\n창가에 두면 더 예쁘겠어요. 챙겨주셔서 고마워요."
        }
        profile.journey = journey
        return GiftReaction(text: (first ? "저한테 주시는 첫 선물이네요.\n" : "") + text,
                            expression: "smile", affinity: gained)
    }
}
