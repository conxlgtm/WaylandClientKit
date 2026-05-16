#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

required_files=(
    README.md
    CONTRIBUTING.md
    docs/architecture.md
    docs/generation.md
    docs/live-wayland-testing.md
    docs/public-api-audit.md
    docs/public-api-baseline.md
    docs/release.md
    docs/strict-memory-safety-audit.md
)

required_executables=(
    scripts/dev/bootstrap-linux.sh
    scripts/protocols/generate.sh
    scripts/protocols/verify-generated.sh
    scripts/ci/verify-public-api-audit.sh
    scripts/shims/verify-shims.sh
)

required_patterns=(
    "SwiftWaylandDemo"
    "swift-wayland-smoke"
    "WaylandClient"
    "WaylandDisplay"
    "WaylandRaw"
    "WaylandKeyboard"
    "WaylandCursor"
    "WaylandGPUPreview"
    "WaylandSmokeSupport"
    "CWaylandProtocols"
    "CWaylandClientSystem"
    "CWaylandCursorShims"
    "CWaylandCursorSystem"
    "CEGLSystem"
    "CGLESv2System"
    "CXKBCommonSystem"
    "egl"
    "gbm"
    "glesv2"
    "libdrm"
    "wayland-cursor"
    "wayland-client"
    "wayland-protocols"
    "xkbcommon"
    "pkg-config"
    "bootstrap-linux.sh"
    "ripgrep"
    "make check"
    "make wayland-headless"
    "./scripts/protocols/generate.sh"
    "./scripts/protocols/verify-generated.sh"
    "./scripts/ci/verify-public-api-audit.sh"
    "./scripts/shims/verify-shims.sh"
)

missing=0

for file in "${required_files[@]}"; do
    if [[ ! -f "$ROOT/$file" ]]; then
        echo "Missing documentation file: $file"
        missing=1
    fi
done

for file in "${required_executables[@]}"; do
    if [[ ! -x "$ROOT/$file" ]]; then
        echo "Missing executable script: $file"
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

api_report="$("$ROOT/scripts/ci/dump-public-api.sh")"
if grep --fixed-strings --quiet "## Library Products" <<<"$api_report"; then
    echo "Public API report labels all products as library products"
    missing=1
fi

if ! grep --fixed-strings --quiet "## Products" <<<"$api_report"; then
    echo "Public API report missing Products section"
    missing=1
fi

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
