#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

git_in_repo() {
    git -c "safe.directory=$ROOT" "$@"
}

public_declarations() {
    awk '
        function update_enum_depth(line, position, character) {
            for (position = 1; position <= length(line); position += 1) {
                character = substr(line, position, 1)
                if (character == "{") {
                    enum_depth += 1
                    enum_seen_body = 1
                } else if (character == "}") {
                    enum_depth -= 1
                }
            }

            if (enum_seen_body && enum_depth <= 0) {
                in_public_enum = 0
            }
        }

        /^[[:space:]]*public[[:space:]]+/ {
            print FNR ":" $0
        }

        {
            starts_public_enum = $0 ~ /^[[:space:]]*public[[:space:]]+(indirect[[:space:]]+)?enum[[:space:]]+/
            if (starts_public_enum) {
                in_public_enum = 1
                enum_depth = 0
                enum_seen_body = 0
            } else if (in_public_enum && enum_seen_body && enum_depth == 1 && $0 ~ /^[[:space:]]*case[[:space:]]+/) {
                print FNR ":" $0
            }

            if (in_public_enum) {
                update_enum_depth($0)
            }
        }
    ' "$1"
}

echo "# SwiftWayland Public API Report"
echo
echo "Generated from tracked Swift sources."
echo

echo "## Products"
echo
"$ROOT/scripts/dev/swift.sh" package describe --type text \
    | awk '
        /^Products:/ { in_products = 1; next }
        /^Targets:/ { in_products = 0 }
        in_products && /Name:/ { print "- " $2 }
    '
echo

echo "## WaylandClient Public Declarations"
echo
git_in_repo ls-files \
    | rg '^Sources/WaylandClient/.*\.swift$' \
    | sort \
    | while IFS= read -r file; do
        [[ -f "$file" ]] || continue
        declarations="$(public_declarations "$file")"
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
git_in_repo ls-files \
    | rg '^Sources/.*\.swift$' \
    | rg -v '^Sources/WaylandClient/' \
    | sort \
    | while IFS= read -r file; do
        [[ -f "$file" ]] || continue
        declarations="$(public_declarations "$file")"
        [[ -n "$declarations" ]] || continue
        echo "### \`$file\`"
        echo
        printf '%s\n' "$declarations" \
            | sed -E 's/^([0-9]+):(.*)$/- L\1: `\2`/'
        echo
    done
