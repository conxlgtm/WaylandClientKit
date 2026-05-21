#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ $# -gt 1 ]]; then
  cat >&2 <<'EOF'
usage: scripts/ci/source-coverage-summary.sh [coverage-json]
EOF
  exit 2
fi

if [[ $# -eq 1 ]]; then
  coverage_json="$1"
else
  coverage_json="$(
    python3 - "${repo_root}" <<'PY'
import pathlib
import sys

repo_root = pathlib.Path(sys.argv[1])
candidates = sorted(
    (repo_root / ".build").glob("*/debug/codecov/SwiftWayland.json"),
    key=lambda path: path.stat().st_mtime,
    reverse=True,
)
if candidates:
    print(candidates[0])
PY
  )"
fi

if [[ ! -f "${coverage_json}" ]]; then
  cat >&2 <<EOF
Coverage JSON was not found: ${coverage_json:-${repo_root}/.build/*/debug/codecov/SwiftWayland.json}
Run ./scripts/dev/swift.sh test --enable-code-coverage --disable-index-store first.
Pass an explicit coverage JSON path if multiple build triples are present.
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
