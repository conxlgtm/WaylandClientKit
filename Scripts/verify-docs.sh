#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

required_files=(
    README.md
    CONTRIBUTING.md
    docs/architecture.md
    docs/generation.md
)

required_patterns=(
    "swift-wayland-demo"
    "swift-wayland-smoke"
    "WaylandClient"
    "WaylandRaw"
    "WaylandKeyboardInterpretation"
    "WaylandSmokeSupport"
    "CWaylandProtocols"
    "CWaylandClientSystem"
    "CXKBCommonSystem"
    "wayland-devel"
    "wayland-protocols-devel"
    "pkgconf-pkg-config"
    "libxkbcommon-devel"
    "ripgrep"
    "make check"
    "./Scripts/generate-protocols.sh"
    "./Scripts/verify-generated.sh"
)

missing=0

for file in "${required_files[@]}"; do
    if [[ ! -f "$ROOT/$file" ]]; then
        echo "Missing documentation file: $file"
        missing=1
    fi
done

for pattern in "${required_patterns[@]}"; do
    if ! grep -R --fixed-strings --quiet "$pattern" \
        "$ROOT/README.md" \
        "$ROOT/CONTRIBUTING.md" \
        "$ROOT/docs"; then
        echo "Missing documentation pattern: $pattern"
        missing=1
    fi
done

for file in "${required_files[@]}"; do
    markdown_file="$ROOT/$file"

    while IFS= read -r link_path; do
        [[ "$link_path" == http://* || "$link_path" == https://* ]] && continue
        [[ "$link_path" == \#* ]] && continue

        local_target="$ROOT/$(dirname "${markdown_file#$ROOT/}")/$link_path"
        root_target="$ROOT/$link_path"

        if [[ ! -e "$local_target" && ! -e "$root_target" ]]; then
            echo "Broken local markdown link in ${markdown_file#$ROOT/}: $link_path"
            missing=1
        fi
    done < <(grep -oE '\[[^]]+\]\(([^)]+)\)' "$markdown_file" \
        | sed -E 's/^.*\(([^)]+)\).*$/\1/')
done

exit "$missing"
