"""Apply the approved facility setting without changing existing node/choice identities."""
import json, pathlib
root = pathlib.Path(__file__).resolve().parents[1]
path = root / "Resources/narrative.json"
data = json.loads(path.read_text(encoding="utf-8"))
scenes = {scene["id"]: scene for scene in data["scenes"]}
nodes = {node["id"]: node for node in scenes["M01"]["nodes"]}
nodes["M01.v14.005"]["text"] = "그리고 저쪽은 오래된 의료실이에요.\n아직은 쓰지 않고 있어요.\n옆에 설비를 놓을 자리도 남아 있고요."
intro = "M01.facilityAnnex"
if intro not in nodes:
    predecessor = nodes["M01.v14.006"]
    scenes["M01"]["nodes"].append(dict(
        id=intro, speaker="operator", expression="calm", next=predecessor["next"],
        text="관제실은 지상에 있고, 시설 구역은 지하의 안정화 게이트로 연결돼 있어요.\n확보한 유적에 협회 장비를 설치한 곳이에요.\n유적의 공명 설비를 쓰면 작은 지부에서도 현장 신호를 분석할 수 있거든요."
    ))
    predecessor["next"] = intro
nodes = {node["id"]: node for node in scenes["M20"]["nodes"]}
nodes["M20.v14.009"]["text"] = "오래된 의료실 옆에 비워둔 부지가 있어요.\n남아 있던 설비 도면도 찾았어요."
nodes["M20.v14.010"]["text"] = "같은 게이트에서 오염된 분들의 신호를 서로 비교해서…\n공통으로 들어온 오염만 분리하는 정화 설비예요."
nodes["M20.v14.012"]["text"] = "이제 구분할 수 있어요.\n원래 이분들께 있던 것하고…\n밖에서 들어온 것하고요.\n그 부지에 귀환 정화실을 마련해야 해요. 강해솔 헌터님과 네 분을 함께 정화할 수 있도록요."
nodes["M20.v14.013"]["text"] = "아직 정화된 건 아니에요.\n협회 시설 구역에서 정화실을 건설하고 설비를 가동해주세요.\n지금부터가 치료예요."
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("Updated facility setting and construction guidance; existing choices preserved.")
