"""실제 Swift 재생 결과를 외부 연결 없는 감상 화면으로 묶는다."""
import argparse
import json
from pathlib import Path


def build(directory: Path) -> Path:
    report = json.loads((directory / "replay-results.json").read_text(encoding="utf-8"))
    scenarios = [json.loads(p.read_text(encoding="utf-8")) for p in sorted((directory / "scenarios").glob("*.json"))]
    if report["schema"] != 1 or len(scenarios) != report["total"]:
        raise ValueError("결과와 입력 시나리오 수가 일치하지 않습니다.")
    data = json.dumps({"report": report, "scenarios": scenarios}, ensure_ascii=False).replace("<", "\\u003c")
    template = Path(__file__).with_name("combat-replay-review.html").read_text(encoding="utf-8")
    output = directory / "index.html"
    output.write_text(template.replace("__REPLAY_DATA__", data), encoding="utf-8")
    return output


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="전투 검증 결과 화면 생성")
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    print(build(args.directory))
