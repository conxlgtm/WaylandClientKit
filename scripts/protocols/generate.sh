#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROTO_DIR="$ROOT/protocols/upstream"
OUT_DIR="$ROOT/Sources/CWaylandProtocols"
GEN_INC="$OUT_DIR/include/generated"
GEN_SRC="$OUT_DIR/generated"

command -v wayland-scanner >/dev/null 2>&1 || {
    echo "wayland-scanner not found on PATH"
    exit 1
}

[[ -f "$PROTO_DIR/core/wayland.xml" ]] || {
    echo "Missing vendored protocol: $PROTO_DIR/core/wayland.xml"
    exit 1
}

[[ -f "$PROTO_DIR/stable/xdg-shell/xdg-shell.xml" ]] || {
    echo "Missing vendored protocol: $PROTO_DIR/stable/xdg-shell/xdg-shell.xml"
    exit 1
}

[[ -f "$PROTO_DIR/legacy-unstable/xdg-decoration/xdg-decoration-unstable-v1.xml" ]] || {
    echo "Missing vendored protocol: $PROTO_DIR/legacy-unstable/xdg-decoration/xdg-decoration-unstable-v1.xml"
    exit 1
}

[[ -f "$PROTO_DIR/legacy-unstable/xdg-output/xdg-output-unstable-v1.xml" ]] || {
    echo "Missing vendored protocol: $PROTO_DIR/legacy-unstable/xdg-output/xdg-output-unstable-v1.xml"
    exit 1
}

[[ -f "$PROTO_DIR/stable/viewporter/viewporter.xml" ]] || {
    echo "Missing vendored protocol: $PROTO_DIR/stable/viewporter/viewporter.xml"
    exit 1
}

[[ -f "$PROTO_DIR/stable/presentation-time/presentation-time.xml" ]] || {
    echo "Missing vendored protocol: $PROTO_DIR/stable/presentation-time/presentation-time.xml"
    exit 1
}

[[ -f "$PROTO_DIR/stable/tablet/tablet-v2.xml" ]] || {
    echo "Missing vendored protocol: $PROTO_DIR/stable/tablet/tablet-v2.xml"
    exit 1
}

[[ -f "$PROTO_DIR/staging/fractional-scale/fractional-scale-v1.xml" ]] || {
    echo "Missing vendored protocol: $PROTO_DIR/staging/fractional-scale/fractional-scale-v1.xml"
    exit 1
}

[[ -f "$PROTO_DIR/staging/cursor-shape/cursor-shape-v1.xml" ]] || {
    echo "Missing vendored protocol: $PROTO_DIR/staging/cursor-shape/cursor-shape-v1.xml"
    exit 1
}

[[ -f "$PROTO_DIR/staging/xdg-activation/xdg-activation-v1.xml" ]] || {
    echo "Missing vendored protocol: $PROTO_DIR/staging/xdg-activation/xdg-activation-v1.xml"
    exit 1
}

[[ -f "$PROTO_DIR/staging/xdg-toplevel-icon/xdg-toplevel-icon-v1.xml" ]] || {
    echo "Missing vendored protocol: $PROTO_DIR/staging/xdg-toplevel-icon/xdg-toplevel-icon-v1.xml"
    exit 1
}

[[ -f "$PROTO_DIR/staging/xdg-system-bell/xdg-system-bell-v1.xml" ]] || {
    echo "Missing vendored protocol: $PROTO_DIR/staging/xdg-system-bell/xdg-system-bell-v1.xml"
    exit 1
}

[[ -f "$PROTO_DIR/staging/linux-drm-syncobj/linux-drm-syncobj-v1.xml" ]] || {
    echo "Missing vendored protocol: $PROTO_DIR/staging/linux-drm-syncobj/linux-drm-syncobj-v1.xml"
    exit 1
}

[[ -f "$PROTO_DIR/staging/fifo/fifo-v1.xml" ]] || {
    echo "Missing vendored protocol: $PROTO_DIR/staging/fifo/fifo-v1.xml"
    exit 1
}

[[ -f "$PROTO_DIR/staging/commit-timing/commit-timing-v1.xml" ]] || {
    echo "Missing vendored protocol: $PROTO_DIR/staging/commit-timing/commit-timing-v1.xml"
    exit 1
}

[[ -f "$PROTO_DIR/staging/content-type/content-type-v1.xml" ]] || {
    echo "Missing vendored protocol: $PROTO_DIR/staging/content-type/content-type-v1.xml"
    exit 1
}

[[ -f "$PROTO_DIR/staging/alpha-modifier/alpha-modifier-v1.xml" ]] || {
    echo "Missing vendored protocol: $PROTO_DIR/staging/alpha-modifier/alpha-modifier-v1.xml"
    exit 1
}

[[ -f "$PROTO_DIR/staging/tearing-control/tearing-control-v1.xml" ]] || {
    echo "Missing vendored protocol: $PROTO_DIR/staging/tearing-control/tearing-control-v1.xml"
    exit 1
}

[[ -f "$PROTO_DIR/staging/color-representation/color-representation-v1.xml" ]] || {
    echo "Missing vendored protocol: "
    echo "$PROTO_DIR/staging/color-representation/color-representation-v1.xml"
    exit 1
}

[[ -f "$PROTO_DIR/staging/color-management/color-management-v1.xml" ]] || {
    echo "Missing vendored protocol: $PROTO_DIR/staging/color-management/color-management-v1.xml"
    exit 1
}

[[ -f "$PROTO_DIR/legacy-unstable/primary-selection/primary-selection-unstable-v1.xml" ]] || {
    echo "Missing vendored protocol: $PROTO_DIR/legacy-unstable/primary-selection/primary-selection-unstable-v1.xml"
    exit 1
}

[[ -f "$PROTO_DIR/legacy-unstable/idle-inhibit/idle-inhibit-unstable-v1.xml" ]] || {
    echo "Missing vendored protocol: $PROTO_DIR/legacy-unstable/idle-inhibit/idle-inhibit-unstable-v1.xml"
    exit 1
}

[[ -f "$PROTO_DIR/legacy-unstable/text-input/text-input-unstable-v3.xml" ]] || {
    echo "Missing vendored protocol: $PROTO_DIR/legacy-unstable/text-input/text-input-unstable-v3.xml"
    exit 1
}

[[ -f "$PROTO_DIR/legacy-unstable/linux-dmabuf/linux-dmabuf-unstable-v1.xml" ]] || {
    echo "Missing vendored protocol: $PROTO_DIR/legacy-unstable/linux-dmabuf/linux-dmabuf-unstable-v1.xml"
    exit 1
}

[[ -f "$PROTO_DIR/legacy-unstable/relative-pointer/relative-pointer-unstable-v1.xml" ]] || {
    echo "Missing vendored protocol: $PROTO_DIR/legacy-unstable/relative-pointer/relative-pointer-unstable-v1.xml"
    exit 1
}

[[ -f "$PROTO_DIR/legacy-unstable/pointer-constraints/pointer-constraints-unstable-v1.xml" ]] || {
    echo "Missing vendored protocol: $PROTO_DIR/legacy-unstable/pointer-constraints/pointer-constraints-unstable-v1.xml"
    exit 1
}

rm -rf "$GEN_INC" "$GEN_SRC"
mkdir -p \
    "$GEN_INC/core" \
    "$GEN_INC/stable/xdg-shell" \
    "$GEN_INC/stable/viewporter" \
    "$GEN_INC/stable/presentation-time" \
    "$GEN_INC/stable/tablet" \
    "$GEN_INC/staging/fractional-scale" \
    "$GEN_INC/staging/cursor-shape" \
    "$GEN_INC/staging/xdg-activation" \
    "$GEN_INC/staging/xdg-toplevel-icon" \
    "$GEN_INC/staging/xdg-system-bell" \
    "$GEN_INC/staging/linux-drm-syncobj" \
    "$GEN_INC/staging/fifo" \
    "$GEN_INC/staging/commit-timing" \
    "$GEN_INC/staging/content-type" \
    "$GEN_INC/staging/alpha-modifier" \
    "$GEN_INC/staging/tearing-control" \
    "$GEN_INC/staging/color-representation" \
    "$GEN_INC/staging/color-management" \
    "$GEN_INC/legacy-unstable/xdg-decoration" \
    "$GEN_INC/legacy-unstable/xdg-output" \
    "$GEN_INC/legacy-unstable/primary-selection" \
    "$GEN_INC/legacy-unstable/idle-inhibit" \
    "$GEN_INC/legacy-unstable/text-input" \
    "$GEN_INC/legacy-unstable/linux-dmabuf" \
    "$GEN_INC/legacy-unstable/relative-pointer" \
    "$GEN_INC/legacy-unstable/pointer-constraints" \
    "$GEN_SRC/core" \
    "$GEN_SRC/stable/xdg-shell" \
    "$GEN_SRC/stable/viewporter" \
    "$GEN_SRC/stable/presentation-time" \
    "$GEN_SRC/stable/tablet" \
    "$GEN_SRC/staging/fractional-scale" \
    "$GEN_SRC/staging/cursor-shape" \
    "$GEN_SRC/staging/xdg-activation" \
    "$GEN_SRC/staging/xdg-toplevel-icon" \
    "$GEN_SRC/staging/xdg-system-bell" \
    "$GEN_SRC/staging/linux-drm-syncobj" \
    "$GEN_SRC/staging/fifo" \
    "$GEN_SRC/staging/commit-timing" \
    "$GEN_SRC/staging/content-type" \
    "$GEN_SRC/staging/alpha-modifier" \
    "$GEN_SRC/staging/tearing-control" \
    "$GEN_SRC/staging/color-representation" \
    "$GEN_SRC/staging/color-management" \
    "$GEN_SRC/legacy-unstable/xdg-decoration" \
    "$GEN_SRC/legacy-unstable/xdg-output" \
    "$GEN_SRC/legacy-unstable/primary-selection" \
    "$GEN_SRC/legacy-unstable/idle-inhibit" \
    "$GEN_SRC/legacy-unstable/text-input" \
    "$GEN_SRC/legacy-unstable/linux-dmabuf" \
    "$GEN_SRC/legacy-unstable/relative-pointer" \
    "$GEN_SRC/legacy-unstable/pointer-constraints" \
    "$OUT_DIR/shims"

normalize_generated_file() {
    local generated_file="$1"

    sed -i -E \
        -e 's/[[:space:]]+$//' \
        -e '1s@/\* Generated by wayland-scanner [^*]+ \*/@/* Generated by wayland-scanner */@' \
        -e '/^#include <stdbool\.h>$/d' \
        -e '/^[[:space:]]+\* @deprecated Deprecated since version [0-9]+$/d' \
        "$generated_file"

    awk '
        { lines[NR] = $0 }
        END {
            last = NR
            while (last > 0 && lines[last] == "") {
                last--
            }
            for (line = 1; line <= last; line++) {
                print lines[line]
            }
        }
    ' "$generated_file" >"$generated_file.tmp"
    mv "$generated_file.tmp" "$generated_file"
}

wayland-scanner client-header \
    "$PROTO_DIR/core/wayland.xml" \
    "$GEN_INC/core/wayland-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/core/wayland.xml" \
    "$GEN_SRC/core/wayland-protocol.c"

wayland-scanner client-header \
    "$PROTO_DIR/stable/xdg-shell/xdg-shell.xml" \
    "$GEN_INC/stable/xdg-shell/xdg-shell-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/stable/xdg-shell/xdg-shell.xml" \
    "$GEN_SRC/stable/xdg-shell/xdg-shell-protocol.c"

wayland-scanner client-header \
    "$PROTO_DIR/legacy-unstable/xdg-decoration/xdg-decoration-unstable-v1.xml" \
    "$GEN_INC/legacy-unstable/xdg-decoration/xdg-decoration-unstable-v1-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/legacy-unstable/xdg-decoration/xdg-decoration-unstable-v1.xml" \
    "$GEN_SRC/legacy-unstable/xdg-decoration/xdg-decoration-unstable-v1-protocol.c"

wayland-scanner client-header \
    "$PROTO_DIR/legacy-unstable/xdg-output/xdg-output-unstable-v1.xml" \
    "$GEN_INC/legacy-unstable/xdg-output/xdg-output-unstable-v1-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/legacy-unstable/xdg-output/xdg-output-unstable-v1.xml" \
    "$GEN_SRC/legacy-unstable/xdg-output/xdg-output-unstable-v1-protocol.c"

wayland-scanner client-header \
    "$PROTO_DIR/stable/viewporter/viewporter.xml" \
    "$GEN_INC/stable/viewporter/viewporter-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/stable/viewporter/viewporter.xml" \
    "$GEN_SRC/stable/viewporter/viewporter-protocol.c"

wayland-scanner client-header \
    "$PROTO_DIR/stable/presentation-time/presentation-time.xml" \
    "$GEN_INC/stable/presentation-time/presentation-time-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/stable/presentation-time/presentation-time.xml" \
    "$GEN_SRC/stable/presentation-time/presentation-time-protocol.c"

wayland-scanner client-header \
    "$PROTO_DIR/stable/tablet/tablet-v2.xml" \
    "$GEN_INC/stable/tablet/tablet-v2-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/stable/tablet/tablet-v2.xml" \
    "$GEN_SRC/stable/tablet/tablet-v2-protocol.c"

wayland-scanner client-header \
    "$PROTO_DIR/staging/fractional-scale/fractional-scale-v1.xml" \
    "$GEN_INC/staging/fractional-scale/fractional-scale-v1-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/staging/fractional-scale/fractional-scale-v1.xml" \
    "$GEN_SRC/staging/fractional-scale/fractional-scale-v1-protocol.c"

wayland-scanner client-header \
    "$PROTO_DIR/staging/cursor-shape/cursor-shape-v1.xml" \
    "$GEN_INC/staging/cursor-shape/cursor-shape-v1-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/staging/cursor-shape/cursor-shape-v1.xml" \
    "$GEN_SRC/staging/cursor-shape/cursor-shape-v1-protocol.c"

wayland-scanner client-header \
    "$PROTO_DIR/staging/xdg-activation/xdg-activation-v1.xml" \
    "$GEN_INC/staging/xdg-activation/xdg-activation-v1-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/staging/xdg-activation/xdg-activation-v1.xml" \
    "$GEN_SRC/staging/xdg-activation/xdg-activation-v1-protocol.c"

wayland-scanner client-header \
    "$PROTO_DIR/staging/xdg-toplevel-icon/xdg-toplevel-icon-v1.xml" \
    "$GEN_INC/staging/xdg-toplevel-icon/xdg-toplevel-icon-v1-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/staging/xdg-toplevel-icon/xdg-toplevel-icon-v1.xml" \
    "$GEN_SRC/staging/xdg-toplevel-icon/xdg-toplevel-icon-v1-protocol.c"

wayland-scanner client-header \
    "$PROTO_DIR/staging/xdg-system-bell/xdg-system-bell-v1.xml" \
    "$GEN_INC/staging/xdg-system-bell/xdg-system-bell-v1-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/staging/xdg-system-bell/xdg-system-bell-v1.xml" \
    "$GEN_SRC/staging/xdg-system-bell/xdg-system-bell-v1-protocol.c"

wayland-scanner client-header \
    "$PROTO_DIR/staging/linux-drm-syncobj/linux-drm-syncobj-v1.xml" \
    "$GEN_INC/staging/linux-drm-syncobj/linux-drm-syncobj-v1-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/staging/linux-drm-syncobj/linux-drm-syncobj-v1.xml" \
    "$GEN_SRC/staging/linux-drm-syncobj/linux-drm-syncobj-v1-protocol.c"

wayland-scanner client-header \
    "$PROTO_DIR/staging/fifo/fifo-v1.xml" \
    "$GEN_INC/staging/fifo/fifo-v1-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/staging/fifo/fifo-v1.xml" \
    "$GEN_SRC/staging/fifo/fifo-v1-protocol.c"

wayland-scanner client-header \
    "$PROTO_DIR/staging/commit-timing/commit-timing-v1.xml" \
    "$GEN_INC/staging/commit-timing/commit-timing-v1-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/staging/commit-timing/commit-timing-v1.xml" \
    "$GEN_SRC/staging/commit-timing/commit-timing-v1-protocol.c"

wayland-scanner client-header \
    "$PROTO_DIR/staging/content-type/content-type-v1.xml" \
    "$GEN_INC/staging/content-type/content-type-v1-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/staging/content-type/content-type-v1.xml" \
    "$GEN_SRC/staging/content-type/content-type-v1-protocol.c"

wayland-scanner client-header \
    "$PROTO_DIR/staging/alpha-modifier/alpha-modifier-v1.xml" \
    "$GEN_INC/staging/alpha-modifier/alpha-modifier-v1-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/staging/alpha-modifier/alpha-modifier-v1.xml" \
    "$GEN_SRC/staging/alpha-modifier/alpha-modifier-v1-protocol.c"

wayland-scanner client-header \
    "$PROTO_DIR/staging/tearing-control/tearing-control-v1.xml" \
    "$GEN_INC/staging/tearing-control/tearing-control-v1-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/staging/tearing-control/tearing-control-v1.xml" \
    "$GEN_SRC/staging/tearing-control/tearing-control-v1-protocol.c"

wayland-scanner client-header \
    "$PROTO_DIR/staging/color-representation/color-representation-v1.xml" \
    "$GEN_INC/staging/color-representation/color-representation-v1-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/staging/color-representation/color-representation-v1.xml" \
    "$GEN_SRC/staging/color-representation/color-representation-v1-protocol.c"

wayland-scanner client-header \
    "$PROTO_DIR/staging/color-management/color-management-v1.xml" \
    "$GEN_INC/staging/color-management/color-management-v1-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/staging/color-management/color-management-v1.xml" \
    "$GEN_SRC/staging/color-management/color-management-v1-protocol.c"

wayland-scanner client-header \
    "$PROTO_DIR/legacy-unstable/primary-selection/primary-selection-unstable-v1.xml" \
    "$GEN_INC/legacy-unstable/primary-selection/primary-selection-unstable-v1-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/legacy-unstable/primary-selection/primary-selection-unstable-v1.xml" \
    "$GEN_SRC/legacy-unstable/primary-selection/primary-selection-unstable-v1-protocol.c"

wayland-scanner client-header \
    "$PROTO_DIR/legacy-unstable/idle-inhibit/idle-inhibit-unstable-v1.xml" \
    "$GEN_INC/legacy-unstable/idle-inhibit/idle-inhibit-unstable-v1-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/legacy-unstable/idle-inhibit/idle-inhibit-unstable-v1.xml" \
    "$GEN_SRC/legacy-unstable/idle-inhibit/idle-inhibit-unstable-v1-protocol.c"

wayland-scanner client-header \
    "$PROTO_DIR/legacy-unstable/text-input/text-input-unstable-v3.xml" \
    "$GEN_INC/legacy-unstable/text-input/text-input-unstable-v3-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/legacy-unstable/text-input/text-input-unstable-v3.xml" \
    "$GEN_SRC/legacy-unstable/text-input/text-input-unstable-v3-protocol.c"

wayland-scanner client-header \
    "$PROTO_DIR/legacy-unstable/linux-dmabuf/linux-dmabuf-unstable-v1.xml" \
    "$GEN_INC/legacy-unstable/linux-dmabuf/linux-dmabuf-unstable-v1-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/legacy-unstable/linux-dmabuf/linux-dmabuf-unstable-v1.xml" \
    "$GEN_SRC/legacy-unstable/linux-dmabuf/linux-dmabuf-unstable-v1-protocol.c"

wayland-scanner client-header \
    "$PROTO_DIR/legacy-unstable/relative-pointer/relative-pointer-unstable-v1.xml" \
    "$GEN_INC/legacy-unstable/relative-pointer/relative-pointer-unstable-v1-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/legacy-unstable/relative-pointer/relative-pointer-unstable-v1.xml" \
    "$GEN_SRC/legacy-unstable/relative-pointer/relative-pointer-unstable-v1-protocol.c"

wayland-scanner client-header \
    "$PROTO_DIR/legacy-unstable/pointer-constraints/pointer-constraints-unstable-v1.xml" \
    "$GEN_INC/legacy-unstable/pointer-constraints/pointer-constraints-unstable-v1-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/legacy-unstable/pointer-constraints/pointer-constraints-unstable-v1.xml" \
    "$GEN_SRC/legacy-unstable/pointer-constraints/pointer-constraints-unstable-v1-protocol.c"

while IFS= read -r generated_file; do
    normalize_generated_file "$generated_file"
done < <(find "$GEN_INC" "$GEN_SRC" -type f \( -name '*.h' -o -name '*.c' \) | sort)

echo "Generated Wayland protocol artifacts in $OUT_DIR"
