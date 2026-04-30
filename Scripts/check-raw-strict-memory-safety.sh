#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASELINE_FILE="${SWIFTWAYLAND_STRICT_MEMORY_SAFETY_BASELINE:-$ROOT/Scripts/strict-memory-safety-baseline.tsv}"
DIAGNOSTIC_BASELINE_FILE="${SWIFTWAYLAND_STRICT_MEMORY_SAFETY_DIAGNOSTIC_BASELINE:-$ROOT/Scripts/strict-memory-safety-diagnostics.tsv}"
UPDATE_DIAGNOSTIC_BASELINE="${SWIFTWAYLAND_UPDATE_STRICT_MEMORY_SAFETY_DIAGNOSTICS:-0}"
LOG_DIR="$(mktemp -d)"
BUILD_ROOT="$(mktemp -d)"
OBSERVED_DIAGNOSTICS_FILE="$LOG_DIR/observed-diagnostics.tsv"

cleanup() {
    rm -rf "$LOG_DIR"
    rm -rf "$BUILD_ROOT"
}
trap cleanup EXIT

if [[ ! -f "$BASELINE_FILE" ]]; then
    echo "Missing strict-memory-safety baseline: $BASELINE_FILE"
    exit 1
fi

declare -A allowed_counts=()
declare -A observed_counts=()
declare -A target_totals=()
declare -A allowed_diagnostics=()
declare -A observed_diagnostics=()
targets=(WaylandRaw WaylandRawUnsafeShim)

toolchain_identity() {
    local version_line
    version_line="$("$ROOT/Scripts/swift.sh" --version | head -n 1 | sed -E 's/[[:space:]]+/ /g')"

    local normalized
    normalized="$(printf '%s\n' "$version_line" \
        | sed -En 's/.*Swift version ([0-9]+(\.[0-9]+){1,2}).*/swift-\1/p' \
        | head -n 1)"

    if [[ -n "$normalized" ]]; then
        printf '%s\n' "$normalized"
    else
        printf '%s\n' "$version_line"
    fi
}

toolchain="$(toolchain_identity)"

while IFS=$'\t' read -r target path max_warnings; do
    [[ -z "${target:-}" || "$target" =~ ^# ]] && continue
    allowed_counts["$target"$'\t'"$path"]="$max_warnings"
done <"$BASELINE_FILE"

if [[ -f "$DIAGNOSTIC_BASELINE_FILE" ]]; then
    while IFS=$'\t' read -r baseline_toolchain target path line column context group stem hash; do
        [[ -z "${baseline_toolchain:-}" || "$baseline_toolchain" =~ ^# ]] && continue
        key="$baseline_toolchain"$'\t'"$target"$'\t'"$path"$'\t'"$group"$'\t'"$stem"$'\t'"$hash"
        allowed_diagnostics["$key"]=1
    done <"$DIAGNOSTIC_BASELINE_FILE"
elif [[ "$UPDATE_DIAGNOSTIC_BASELINE" != "1" ]]; then
    echo "Missing strict-memory-safety diagnostic baseline: $DIAGNOSTIC_BASELINE_FILE"
    exit 1
fi

normalize_diagnostic() {
    sed -E \
        -e "s/'[^']+'/'<value>'/g" \
        -e 's/`[^`]+`/`<value>`/g' \
        -e 's/"[^"]+"/"<value>"/g' \
        -e 's/[[:space:]]+/ /g' \
        -e 's/[[:space:]]+$//'
}

source_context_hash() {
    local path="$1"
    local line="$2"
    local start=$(( line > 2 ? line - 2 : 1 ))
    local end=$(( line + 2 ))

    sed -n "${start},${end}p" "$ROOT/$path" \
        | sed -E 's/[[:space:]]+/ /g' \
        | sha256sum \
        | cut -c 1-16
}

declaration_context() {
    local path="$1"
    local line="$2"

    awk -v max_line="$line" '
        NR > max_line { exit }
        /^[[:space:]]*(@safe|@unsafe|public|package|private|internal|final|static|class|struct|enum|actor|extension|func|var|let)[[:space:]]/ {
            context = $0
        }
        END {
            gsub(/^[ \t]+|[ \t]+$/, "", context)
            gsub(/[ \t]+/, " ", context)
            if (context == "") {
                context = "-"
            }
            print context
        }
    ' "$ROOT/$path" | cut -c 1-160
}

record_warning() {
    local target="$1"
    local warning="$2"
    local relative="${warning#"$ROOT/"}"
    local path="${relative%%:*}"
    local rest="${relative#"$path:"}"
    local line="${rest%%:*}"
    rest="${rest#*:}"
    local column="${rest%%:*}"
    local message="${rest#*: warning: }"

    local key="$target"$'\t'"$path"
    observed_counts["$key"]="$(( ${observed_counts["$key"]:-0} + 1 ))"
    target_totals["$target"]="$(( ${target_totals["$target"]:-0} + 1 ))"

    local stem
    stem="$(printf '%s' "$message" | normalize_diagnostic | cut -c 1-160)"
    local hash
    hash="$(source_context_hash "$path" "$line")"
    local context
    context="$(declaration_context "$path" "$line" | tr '\t' ' ')"
    local diagnostic_key="$toolchain"$'\t'"$target"$'\t'"$path"$'\t''StrictMemorySafety'$'\t'"$stem"$'\t'"$hash"
    observed_diagnostics["$diagnostic_key"]=1

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$toolchain" \
        "$target" \
        "$path" \
        "$line" \
        "$column" \
        "$context" \
        "StrictMemorySafety" \
        "$stem" \
        "$hash" >>"$OBSERVED_DIAGNOSTICS_FILE"
}

build_target() {
    local target="$1"
    local log_file="$LOG_DIR/$target.log"
    local build_dir="$BUILD_ROOT/$target"

    set +e
    CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/tmp/swiftwayland-module-cache}" \
        "$ROOT/Scripts/swift.sh" build \
        --target "$target" \
        --scratch-path "$build_dir" \
        --disable-index-store \
        -Xswiftc -strict-memory-safety \
        >"$log_file" 2>&1
    local build_status="$?"
    set -e

    if [[ "$build_status" -ne 0 ]]; then
        cat "$log_file"
        exit "$build_status"
    fi

    while IFS= read -r warning; do
        [[ -z "$warning" ]] && continue
        local relative="${warning#"$ROOT/"}"
        local path="${relative%%:*}"
        [[ "$path" == "Sources/$target/"* ]] || continue
        record_warning "$target" "$warning"
    done < <(
        rg "^$ROOT/.*warning:" "$log_file" \
            || true
    )
}

for target in "${targets[@]}"; do
    build_target "$target"
done

if [[ "$UPDATE_DIAGNOSTIC_BASELINE" == "1" ]]; then
    {
        echo "# toolchain	target	path	line	column	declaration_context	diagnostic_group	normalized_diagnostic_stem	source_context_hash"
        sort -u "$OBSERVED_DIAGNOSTICS_FILE"
    } >"$DIAGNOSTIC_BASELINE_FILE"
fi

failed=0
for key in "${!observed_counts[@]}"; do
    observed="${observed_counts["$key"]}"
    allowed="${allowed_counts["$key"]:-}"

    if [[ -z "$allowed" ]]; then
        echo "New strict-memory-safety warning file: ${key//$'\t'/ } has $observed warnings"
        failed=1
        continue
    fi

    if (( observed > allowed )); then
        echo "Strict-memory-safety warnings increased: ${key//$'\t'/ } $observed > $allowed"
        failed=1
    fi
done

if [[ "$UPDATE_DIAGNOSTIC_BASELINE" != "1" ]]; then
    for key in "${!observed_diagnostics[@]}"; do
        if [[ -n "${allowed_diagnostics["$key"]:-}" ]]; then
            continue
        fi

        IFS=$'\t' read -r diagnostic_toolchain target path group stem hash <<<"$key"
        echo "New strict-memory-safety diagnostic: $target $path [$group] $stem ($hash, $diagnostic_toolchain)"
        failed=1
    done
fi

for key in "${!allowed_counts[@]}"; do
    observed="${observed_counts["$key"]:-0}"
    allowed="${allowed_counts["$key"]}"

    if (( observed < allowed )); then
        echo "Strict-memory-safety warnings decreased: ${key//$'\t'/ } $observed < $allowed"
    fi
done

for target in "${targets[@]}"; do
    total="${target_totals["$target"]:-0}"
    echo "$target strict-memory-safety warnings: $total (file baseline)"
done

if (( failed != 0 )); then
    echo "Strict-memory-safety baseline failed."
    echo "Audit the new unsafe surface or deliberately update $BASELINE_FILE and $DIAGNOSTIC_BASELINE_FILE."
    exit 1
fi
