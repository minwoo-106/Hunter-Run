"""Compile the approved season-one revision while retaining save/choice identities.

The authoring sources stay outside the app bundle. This replaces only main-story
dialogue graphs; requirements, scene IDs, reward state, and bond scenes persist.
"""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs/story-1.4-sources"
BASE = SOURCE / "narrative-1.3.11.json"
TARGET = ROOT / "Resources/narrative.json"

DOCUMENTS = {
    "M01-M10-base.md": SOURCE / "M01-M10-base.md",
    "M01-M10-revisions.md": SOURCE / "M01-M10-revisions.md",
    "M11-M16.md": SOURCE / "M11-M16.md",
    "M17-M21.md": SOURCE / "M17-M21.md",
}
REVISED = {1, 3, 4, 6, 10}
PROTECTED_CHOICES = {"M01", "M06", "M09", "M16", "M17", "M18", "M19", "M20", "M21"}
NEW_CHOICES = {
    "M10": [
        ("M10-A", "공식 관제 기록부터 비교해봐요.", "official"),
        ("M10-B", "음성 파일 자체를 확인해봐요.", "audio"),
        ("M10-C", "먼저 그대로 보존해요.", "preserve"),
    ],
    "M13": [
        ("M13-A", "확실한 내용만 적어요.", "confirmed"),
        ("M13-B", "불확실하다고 표시해요.", "uncertain"),
        ("M13-C", "현장 판단과 관제 판단을 따로 적어요.", "separate"),
    ],
}
HAESOL_LINES = {
    item["id"]: item["text"] for item in json.loads(
        (SOURCE / "haesol-voice-lines.json").read_text(encoding="utf-8")
    )["lines"]
}
assert len(HAESOL_LINES) == 16 and "H17" not in HAESOL_LINES


def document_scene(text: str, identifier: str) -> tuple[str, str]:
    heading = re.search(rf"^# {identifier}\s*[—-]\s*(.+)$", text, re.M)
    assert heading, identifier
    following = re.search(r"^# M\d\d\s*[—-]", text[heading.end():], re.M)
    end = heading.end() + following.start() if following else len(text)
    return heading.group(1).strip(), text[heading.end():end]


def sections(body: str) -> list[tuple[str, str]]:
    headings = list(re.finditer(r"^## ([^\n]+)$", body, re.M))
    return [(h.group(1).strip(), body[h.end():headings[i + 1].start() if i + 1 < len(headings) else len(body)])
            for i, h in enumerate(headings)]


def speaker_for(label: str) -> tuple[str, str | None]:
    if label in ("{operatorName}", "오퍼레이터", "O"):
        return "operator", None
    if label in ("{hunterName}", "헌터"):
        return "hunter", None
    if "강해솔" in label:
        return "report", "강해솔의 기록"
    return "report", label


def spoken_blocks(body: str) -> list[dict]:
    result: list[dict] = []
    speaker: tuple[str, str | None] | None = None
    words: list[str] = []

    def flush() -> None:
        nonlocal words
        if speaker and words:
            parts: list[str] = []
            for word in words:
                if parts and len(" ".join(parts)) + len(word) > 105:
                    result.append({"speaker": speaker[0], "speakerLabel": speaker[1], "text": "\n".join(parts)})
                    parts = []
                parts.append(word)
            if parts:
                result.append({"speaker": speaker[0], "speakerLabel": speaker[1], "text": "\n".join(parts)})
        words = []

    for raw in body.splitlines():
        line = raw.strip()
        marker = re.fullmatch(r"\*\*([^*]+)\*\*", line)
        if marker and len(marker.group(1)) < 35 and not marker.group(1).startswith("“"):
            flush()
            speaker = speaker_for(marker.group(1))
            continue
        inline_speaker = re.fullmatch(r"([^*:]{1,30}):", line)
        if inline_speaker:
            flush()
            speaker = speaker_for(inline_speaker.group(1))
            continue
        if line.startswith("---") or line.startswith("## ") or line.startswith("### "):
            flush()
            speaker = None
            continue
        quote = re.fullmatch(r"[“]([^”]+)[”]", line)
        if quote is None and speaker:
            quote = re.fullmatch(r">\s*[“]([^”]+)[”]", line)
        if quote and speaker:
            words.append(quote.group(1).strip())
    flush()
    return result


def source_for(index: int) -> str:
    name = ("M01-M10-revisions.md" if index in REVISED else "M01-M10-base.md") if index <= 10 else ("M11-M16.md" if index <= 16 else "M17-M21.md")
    return DOCUMENTS[name].read_text(encoding="utf-8")


def scene_beats(index: int) -> tuple[str, list[dict], dict[str, list[dict]], list[dict]]:
    identifier = f"M{index:02}"
    title, body = document_scene(source_for(index), identifier)
    parts = sections(body)
    actual = next(i for i, (h, _) in enumerate(parts) if h.startswith("실제"))
    pre = spoken_blocks(parts[actual][1])
    choice_at = next((i for i in range(actual + 1, len(parts)) if "선택" in parts[i][0]
                      and "선택 이후" not in parts[i][0] and "선택 기억" not in parts[i][0]), None)
    branches: dict[str, list[dict]] = {}
    post: list[dict] = []
    if choice_at is not None:
        head, branch_body = parts[choice_at]
        matches = list(re.finditer(rf"^### ({identifier}-[A-Z])\s*$", branch_body, re.M))
        for i, match in enumerate(matches):
            end = matches[i + 1].start() if i + 1 < len(matches) else len(branch_body)
            branch_text = branch_body[match.end():end]
            branch_text = re.split(r"^기존 선택값이 없는 저장|^기존 저장에서 값이 없으면", branch_text, maxsplit=1, flags=re.M)[0]
            branches[match.group(1)] = spoken_blocks(branch_text)
        for head, content in parts[choice_at + 1:]:
            if head.startswith("다음") or head.startswith("저장") or head.startswith("기존 저장"):
                break
            if "선택 기억" in head or "상태" in head or "표현 허용" in head:
                continue
            # Role-specific memory shards require a runtime branch; do not show all four.
            if index == 18 and any(role in head for role in ("전사", "마법사", "궁수", "성직자")):
                continue
            post.extend(spoken_blocks(content))
    else:
        for head, content in parts[actual + 1:]:
            if head.startswith("다음"):
                break
            if "선택" not in head and "저장" not in head:
                post.extend(spoken_blocks(content))
    return title, pre, branches, post


def node(identifier: str, index: int, beat: dict, expression: str = "calm") -> dict:
    output = {"id": f"{identifier}.v14.{index:03}", "speaker": beat["speaker"],
              "text": beat["text"], "expression": expression}
    if beat.get("speakerLabel"):
        output["speakerLabel"] = beat["speakerLabel"]
    if beat.get("voiceKey"):
        output["voiceKey"] = beat["voiceKey"]
    if beat.get("variants"):
        output["variants"] = beat["variants"]
    return output


def append_linear(nodes: list[dict], identifier: str, beats: list[dict]) -> None:
    for beat in beats:
        item = node(identifier, len(nodes) + 1, beat,
                    "smile" if beat["speaker"] == "operator" and identifier in ("M06", "M16", "M21") else "calm")
        if nodes and "choices" not in nodes[-1]:
            nodes[-1]["next"] = item["id"]
        nodes.append(item)


def haesol(key: str) -> dict:
    return {"speaker": "report", "speakerLabel": "강해솔의 기록", "text": HAESOL_LINES[key],
            "voiceKey": "haesol_" + key.lower()}


data = json.loads(BASE.read_text(encoding="utf-8"))
for scene in data["scenes"]:
    if scene["kind"] != "main":
        continue
    identifier = scene["id"]
    index = int(identifier[1:])
    old = scene["nodes"]
    title, pre, branches, post = scene_beats(index)
    if index == 1:
        pre = [dict(beat, text=beat["text"].replace(
            "저쪽 사진에 있는 분은 강해솔 헌터님이에요.\n현재 협회 랭킹 1위.",
            "협회 1위로 알려진 강해솔 헌터님이에요.")) for beat in pre]
    if index == 11:
        pre.append({"speaker": "operator", "text": "군주가 사라졌다고 잘린 회선까지 다시 이어지는 건 아니네요.\n끊어진 경계는 그대로 닫혀 있어요."})
    if index == 6:
        pre.insert(2, {"speaker": "operator", "text": "강해솔 헌터님 첫 승급 때 남은 축하 기록도 같이 있네요.\n지금은 {hunterName}님 사진이 그 옆이고요."})
        branches["M06-A"] = [{"speaker": "operator", "text": "네.\n돌아오신 것까지 제대로 확인했으니까…\n이제 통신 꺼도 괜찮아요.\n오늘은 승급한 것만 생각해도 되겠네요."}]
    if index == 14:
        pre.append({"speaker": "operator", "text": "잠깐… 새 신호가 아니에요.\n이 반응, 자료 안에 이미 들어 있었어요."})
    if index == 16:
        post = [beat for beat in post if "주황 테이프" not in beat["text"]]
        post.append({"speaker": "operator", "text": "이건 이번 사건 기록이 아니네요. 훨씬 예전 센서예요.\n별도 사건으로 넘겨둘게요. 오늘은 여기까지예요."})
    if index == 19:
        pre.extend([haesol("H01"), haesol("H02")])
    if index == 18:
        # The first recovered scout depends on the player's actual encounter order.
        # Keep the fragment incomplete here; all four meanings resolve in M19.
        post.insert(0, {"speaker": "report", "speakerLabel": "선발대의 기억 조각",
                        "text": "깨진 화면 너머에서 누군가 말해요. ‘이번엔 우리 말 좀 들어요.’",
                        "variants": [
                            {"key": "firstVanguardRole", "value": "warrior", "text": "검게 끊기는 화면. 강해솔이 ‘안 돼요’라고 말하자 전사가 답해요. ‘이번엔 우리 말 좀 들어요.’"},
                            {"key": "firstVanguardRole", "value": "mage", "text": "공간에 다섯 신호가 떠요. 마법사의 목소리. ‘네 개는 움직여요. 하나는 그대로고.’"},
                            {"key": "firstVanguardRole", "value": "archer", "text": "궁수가 뒤쪽으로 활을 겨누지만 쏘지 않아요. ‘뒤는 잡혀 있어. 앞만 보면 돼.’"},
                            {"key": "firstVanguardRole", "value": "cleric", "text": "깨진 관측 화면을 가리키며 성직자가 말해요. ‘제가 계산했어요. 한 명이면 된다고.’"},
                        ]})
    if index == 20:
        pre.append({"speaker": "operator", "text": "정화된 건 아니에요. 이제 지부로 데려가야 해요.",
                    "voiceKey": "operator_o20"})
        post = [haesol("H11") if beat["speaker"] == "report" and "네 명은" in beat["text"] else beat for beat in post]
        post = [dict(beat, text="다섯 분 전부 들어왔어요.", voiceKey="operator_o21")
                if beat["speaker"] == "operator" and "다섯 분" in beat["text"] and "들어왔" in beat["text"] else beat
                for beat in post]
    if index == 21:
        pre[0] = {"speaker": "operator", "text": "됐어요. 다섯 분 모두 안정됐어요. 이번엔 정말로요.",
                  "voiceKey": "operator_o22"}
        pre.extend([
            {"speaker": "report", "speakerLabel": "성직자", "text": "그때 계산한 건… 저였어요. 미안해요."},
            haesol("H12"), haesol("H13"), haesol("H14"),
            {"speaker": "operator", "text": "그건 그대로예요."}, haesol("H15"),
        ])
        post = [dict(beat, text="모르는 건 남겨둘게요. 나중에 함께 확인하면 돼요.", voiceKey="operator_o23")
                if beat["speaker"] == "operator" and "모르는 건" in beat["text"] else beat for beat in post]
        post.append(haesol("H16"))
    nodes: list[dict] = []
    append_linear(nodes, identifier, pre)
    original_choice = next((n for n in old if n.get("choices")), None)
    if original_choice is None and identifier in NEW_CHOICES:
        original_choice = {"choices": [
            {"id": key, "text": text, "next": "", "memory": {
                "m10EvidencePath" if identifier == "M10" else "m13ReportMethod": value
            }} for key, text, value in NEW_CHOICES[identifier]
        ]}
    if original_choice:
        choice = node(identifier, len(nodes) + 1, {"speaker": "hunter", "text": "어떻게 답할까요?"})
        if nodes:
            nodes[-1]["next"] = choice["id"]
        nodes.append(choice)
        choice["choices"] = []
        response_ends: list[dict] = []
        for original in original_choice["choices"]:
            key = original["id"]
            response = branches.get(key) or [{"speaker": "operator", "text": next(
                (n["text"] for n in old if n["id"] == original["next"]), "확인하고 계속 진행할게요.")}]
            first_index = len(nodes) + 1
            branch_nodes = []
            append_linear(branch_nodes, identifier, [])
            for beat in response:
                item = node(identifier, len(nodes) + 1, beat, "smile")
                if branch_nodes:
                    branch_nodes[-1]["next"] = item["id"]
                nodes.append(item)
                branch_nodes.append(item)
            response_ends.append(branch_nodes[-1])
            item = {"id": key, "text": original["text"], "next": nodes[first_index - 1]["id"]}
            for field in ("memory", "requiresMemory"):
                if field in original:
                    item[field] = original[field]
            choice["choices"].append(item)
        if not post:
            post = [{"speaker": "operator", "text": "확인한 내용을 기록해둘게요."}]
        continuation = node(identifier, len(nodes) + 1, post[0])
        for end in response_ends:
            end["next"] = continuation["id"]
        nodes.append(continuation)
        append_linear(nodes, identifier, post[1:])
    else:
        append_linear(nodes, identifier, post)
    if not nodes:
        raise ValueError(f"No dialogue: {identifier}")
    scene["title"] = title
    callback_id = {"M19": "M19.search", "M20": "M20.vanguard", "M21": "M21.firstOffice"}.get(identifier)
    if callback_id:
        callback = next(n for n in old if n["id"] == callback_id).copy()
        callback.pop("next", None)
        callback.pop("choices", None)
        if identifier == "M21":
            # Place the callback before Haesol's last line, not after the ending.
            final = nodes[-1]
            predecessor = next(n for n in nodes if n.get("next") == final["id"])
            predecessor["next"] = callback["id"]
            callback["next"] = final["id"]
            nodes.insert(-1, callback)
        else:
            nodes[-1]["next"] = callback["id"]
            nodes.append(callback)
    scene["start"] = nodes[0]["id"]
    scene["nodes"] = nodes
    if identifier == "M21":
        scene["artwork"] = "PurificationRoom"

TARGET.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("Built 1.4 main narrative:", [(s["id"], len(s["nodes"])) for s in data["scenes"] if s["kind"] == "main"])
