#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASELINE="$ROOT/docs/public-api-baseline.md"

usage() {
    cat <<'EOF'
Usage: scripts/ci/verify-public-api-audit.sh [--update]

Checks the WaylandClient public API baseline against the current tracked Swift
sources. Pass --update after reviewing docs/public-api-audit.md for the API
contract change.
EOF
}

mode="${1:-}"
case "$mode" in
    "" | "--update")
        ;;
    "-h" | "--help")
        usage
        exit 0
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac

tmp_baseline="$(mktemp)"
trap 'rm -f "$tmp_baseline"' EXIT

report="$("$ROOT/scripts/ci/dump-public-api.sh")"

{
    cat <<'EOF'
# WaylandClient Public API Baseline

This baseline records the public declarations exported by the `WaylandClient`
library product. It is intentionally limited to the user-facing product and
excludes package-internal targets that use `public` for cross-target builds.

Run `./scripts/ci/verify-public-api-audit.sh --update` only after reviewing and
updating `docs/public-api-audit.md` for the API contract change.

EOF

    awk '
        /^## WaylandClient Public Declarations$/ {
            in_section = 1
            print
            next
        }

        /^## Non-Product Target Public Declarations$/ {
            in_section = 0
        }

        in_section {
            print
        }
    ' <<<"$report"
} >"$tmp_baseline"

if [[ "$mode" == "--update" ]]; then
    cp "$tmp_baseline" "$BASELINE"
    exit 0
fi

if [[ ! -f "$BASELINE" ]]; then
    echo "Missing public API baseline: docs/public-api-baseline.md" >&2
    echo "Run ./scripts/ci/verify-public-api-audit.sh --update after audit review." >&2
    exit 1
fi

if ! diff -u "$BASELINE" "$tmp_baseline"; then
    echo >&2
    echo "WaylandClient public API changed." >&2
    echo "Review docs/public-api-audit.md, then update docs/public-api-baseline.md." >&2
    exit 1
fi
