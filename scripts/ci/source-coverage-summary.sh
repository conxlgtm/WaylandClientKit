#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
coverage_json="${1:-"${repo_root}/.build/x86_64-unknown-linux-gnu/debug/codecov/SwiftWayland.json"}"

if [[ ! -f "${coverage_json}" ]]; then
  cat >&2 <<EOF
Coverage JSON was not found: ${coverage_json}
Run ./scripts/dev/swift.sh test --enable-code-coverage --disable-index-store first.
EOF
  exit 1
fi

python3 - "${repo_root}" "${coverage_json}" <<'PY'
import json
import pathlib
import sys

repo_root = pathlib.Path(sys.argv[1]).resolve()
coverage_json = pathlib.Path(sys.argv[2]).resolve()
sources_root = repo_root / "Sources"

with coverage_json.open(encoding="utf-8") as stream:
    payload = json.load(stream)

modules = {}
for data_entry in payload.get("data", []):
    for file_entry in data_entry.get("files", []):
        filename = pathlib.Path(file_entry.get("filename", "")).resolve()
        try:
            relative = filename.relative_to(sources_root)
        except ValueError:
            continue

        module = relative.parts[0]
        summary = file_entry.get("summary", {})
        lines = summary.get("lines", {})
        functions = summary.get("functions", {})
        aggregate = modules.setdefault(
            module,
            {"lines_count": 0, "lines_covered": 0, "functions_count": 0, "functions_covered": 0},
        )
        aggregate["lines_count"] += int(lines.get("count", 0))
        aggregate["lines_covered"] += int(lines.get("covered", 0))
        aggregate["functions_count"] += int(functions.get("count", 0))
        aggregate["functions_covered"] += int(functions.get("covered", 0))

def percent(covered, count):
    if count == 0:
        return "0.00"
    return f"{covered * 100.0 / count:.2f}"

print("| Module | Line coverage | Function coverage |")
print("| --- | ---: | ---: |")
total = {"lines_count": 0, "lines_covered": 0, "functions_count": 0, "functions_covered": 0}
for module in sorted(modules):
    aggregate = modules[module]
    for key, value in aggregate.items():
        total[key] += value
    print(
        f"| `{module}` | "
        f"{percent(aggregate['lines_covered'], aggregate['lines_count'])}% | "
        f"{percent(aggregate['functions_covered'], aggregate['functions_count'])}% |"
    )

print(
    f"| **Source total** | "
    f"{percent(total['lines_covered'], total['lines_count'])}% | "
    f"{percent(total['functions_covered'], total['functions_count'])}% |"
)
PY
