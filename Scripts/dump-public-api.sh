#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

git_in_repo() {
    git -c "safe.directory=$ROOT" "$@"
}

echo "# SwiftWayland Public API Report"
echo
echo "Generated from tracked Swift sources."
echo

echo "## Products"
echo
"$ROOT/Scripts/swift.sh" package describe --type text \
    | awk '
        /^Products:/ { in_products = 1; next }
        /^Targets:/ { in_products = 0 }
        in_products && /Name:/ { print "- " $2 }
    '
echo

echo "## WaylandClient Public Declarations"
echo
git_in_repo ls-files 'Sources/WaylandClient/*.swift' \
    | sort \
    | while IFS= read -r file; do
        declarations="$(rg -n '^[[:space:]]*public[[:space:]]+' "$file" || true)"
        [[ -n "$declarations" ]] || continue
        echo "### \`$file\`"
        echo
        printf '%s\n' "$declarations" \
            | sed -E 's/^([0-9]+):(.*)$/- L\1: `\2`/'
        echo
    done

echo "## Non-Product Target Public Declarations"
echo
echo "These declarations are not part of a vended library product unless the package manifest changes."
echo
git_in_repo ls-files 'Sources/*.swift' 'Sources/*/*.swift' \
    | rg -v '^Sources/WaylandClient/' \
    | sort \
    | while IFS= read -r file; do
        declarations="$(rg -n '^[[:space:]]*public[[:space:]]+' "$file" || true)"
        [[ -n "$declarations" ]] || continue
        echo "### \`$file\`"
        echo
        printf '%s\n' "$declarations" \
            | sed -E 's/^([0-9]+):(.*)$/- L\1: `\2`/'
        echo
    done
