#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

VERSION="${SWIFTWAYLAND_CLEANUP_SCAN_VERSION:-3.7.4}"
USER_HOME="${HOME:-}"
CACHE_ROOT="${SWIFTWAYLAND_CLEANUP_SCAN_CACHE:-${XDG_CACHE_HOME:-${USER_HOME}/.cache}/swiftwayland/cleanup-scan}"
SOURCE_DIR="${CACHE_ROOT}/source-${VERSION}"
TOOL_HOME="${CACHE_ROOT}/home"
RESULTS_PATH="${ROOT}/.build/cleanup-scan/results.json"
FORMAT="json"
CLEAN_BUILD=1
RETAIN_PUBLIC=1
USE_NIX="${SWIFTWAYLAND_CLEANUP_SCAN_NIX:-auto}"
PRINT_RESULTS=0
EXTRA_SCAN_ARGS=()
ORIGINAL_ARGS=("$@")

usage() {
    cat <<'EOF'
Usage: scripts/dev/cleanup-scan.sh [options] [-- scan-options...]

Builds and caches the cleanup analyzer, then scans the Swift package.

Options:
  --output PATH        write formatted results to PATH
  --format FORMAT      output format passed to the scanner (default: json)
  --clean-build        clean package build artifacts before scanning (default)
  --no-clean-build     reuse package build artifacts
  --retain-public      retain public declarations (default)
  --no-retain-public   report public declarations too
  --print-results      print formatted results to stdout
  --nix                force re-running inside the Nix dependency shell
  --no-nix             do not auto-enter the Nix dependency shell
  -h, --help           show this help

Environment:
  SWIFTWAYLAND_CLEANUP_SCAN_VERSION  analyzer release tag to build
  SWIFTWAYLAND_CLEANUP_SCAN_CACHE    cache directory for source/build artifacts
  SWIFTWAYLAND_CLEANUP_SCAN_NIX      auto, 1, or 0
  SWIFTWAYLAND_SWIFT_COMPAT_DIR      directory containing Swift compatibility libs

Examples:
  scripts/dev/cleanup-scan.sh
  scripts/dev/cleanup-scan.sh --no-clean-build
  scripts/dev/cleanup-scan.sh -- --strict
EOF
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

have() {
    command -v "$1" >/dev/null 2>&1
}

quote_command() {
    local quoted=()
    local word
    for word in "$@"; do
        printf -v word '%q' "$word"
        quoted+=("$word")
    done
    printf '%s ' "${quoted[@]}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)
            [[ $# -gt 1 ]] || die "--output requires a path"
            RESULTS_PATH="$2"
            shift
            ;;
        --output=*)
            RESULTS_PATH="${1#--output=}"
            [[ -n "$RESULTS_PATH" ]] || die "--output requires a path"
            ;;
        --format)
            [[ $# -gt 1 ]] || die "--format requires a value"
            FORMAT="$2"
            shift
            ;;
        --format=*)
            FORMAT="${1#--format=}"
            [[ -n "$FORMAT" ]] || die "--format requires a value"
            ;;
        --clean-build)
            CLEAN_BUILD=1
            ;;
        --no-clean-build)
            CLEAN_BUILD=0
            ;;
        --retain-public)
            RETAIN_PUBLIC=1
            ;;
        --no-retain-public)
            RETAIN_PUBLIC=0
            ;;
        --print-results)
            PRINT_RESULTS=1
            ;;
        --nix)
            USE_NIX=1
            ;;
        --no-nix)
            USE_NIX=0
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        --)
            shift
            EXTRA_SCAN_ARGS+=("$@")
            break
            ;;
        *)
            die "unknown argument: $1"
            ;;
    esac
    shift
done

case "$USE_NIX" in
    auto | 0 | 1)
        ;;
    *)
        die "SWIFTWAYLAND_CLEANUP_SCAN_NIX must be auto, 1, or 0"
        ;;
esac

if [[ "$USE_NIX" != "0" && -z "${IN_NIX_SHELL:-}" ]] && have nix-shell; then
    exec nix-shell \
        -p git pkg-config wayland.dev libxkbcommon.dev libdrm.dev libgbm libglvnd.dev \
        --run "$(quote_command "$0" --no-nix "${ORIGINAL_ARGS[@]}")"
fi

prepend_ld_library_path() {
    local directory="$1"

    [[ -d "$directory" ]] || return 0
    if [[ ":${LD_LIBRARY_PATH:-}:" == *":$directory:"* ]]; then
        return 0
    fi

    if [[ -n "${LD_LIBRARY_PATH:-}" ]]; then
        export LD_LIBRARY_PATH="$directory:$LD_LIBRARY_PATH"
    else
        export LD_LIBRARY_PATH="$directory"
    fi
}

find_swift_compat_dir() {
    local directory
    local candidates=()

    candidates+=("${SWIFTWAYLAND_SWIFT_COMPAT_DIR:-}")
    candidates+=("${SWIFT_COMPAT_LIBS:-}")
    if [[ -n "$USER_HOME" ]]; then
        candidates+=("${USER_HOME}/.local/share/swift-compat-libs")
    fi
    candidates+=(
        /nix/store/*apple-swift*env-fhsenv-rootfs/usr/lib64
        /usr/lib64
        /usr/lib/x86_64-linux-gnu
    )

    for directory in "${candidates[@]}"; do
        [[ -n "$directory" ]] || continue
        [[ -d "$directory" ]] || continue
        [[ -e "$directory/libxml2.so.2" ]] || continue
        [[ -e "$directory/libz.so.1" ]] || continue
        [[ -e "$directory/libcurl.so.4" ]] || continue
        [[ -e "$directory/libstdc++.so.6" ]] || continue
        printf '%s\n' "$directory"
        return 0
    done

    return 1
}

ensure_tool_source() {
    if [[ -d "$SOURCE_DIR/.git" ]]; then
        return 0
    fi

    [[ ! -e "$SOURCE_DIR" ]] || die "cache path exists but is not a git checkout: $SOURCE_DIR"
    have git || die "git is required to fetch the cleanup analyzer"

    mkdir -p "$(dirname "$SOURCE_DIR")"
    git clone --depth 1 --branch "$VERSION" \
        https://github.com/peripheryapp/periphery.git \
        "$SOURCE_DIR"
}

patch_tool_for_nixos() {
    local shell_file="${SOURCE_DIR}/Sources/Shared/Shell.swift"

    [[ -f "$shell_file" ]] || return 0
    if grep -q 'process.launchPath = "/bin/bash"' "$shell_file"; then
        sed -i \
            -e 's#process.launchPath = "/bin/bash"#process.launchPath = "/usr/bin/env"#' \
            -e 's#process.arguments = \["-c", cmd.joined(separator: " ")\]#process.arguments = ["bash", "-c", cmd.joined(separator: " ")]#' \
            "$shell_file"
    fi
}

build_tool() {
    mkdir -p "$TOOL_HOME"
    HOME="$TOOL_HOME" "$ROOT/scripts/dev/swift.sh" \
        build -c release --product periphery --disable-sandbox \
        --package-path "$SOURCE_DIR"
}

tool_binary_path() {
    printf '%s\n' "${SOURCE_DIR}/.build/release/periphery"
}

ensure_tool_source
patch_tool_for_nixos
build_tool

COMPAT_DIR="$(find_swift_compat_dir || true)"
if [[ -n "$COMPAT_DIR" ]]; then
    prepend_ld_library_path "$COMPAT_DIR"
fi

BINARY="$(tool_binary_path)"
[[ -x "$BINARY" ]] || die "cleanup analyzer binary was not built: $BINARY"

SCAN_ARGS=(
    scan
    --disable-update-check
    --relative-results
    --format "$FORMAT"
    --write-results "$RESULTS_PATH"
)

if [[ "$RETAIN_PUBLIC" -eq 1 ]]; then
    SCAN_ARGS+=(--retain-public)
fi

if [[ "$CLEAN_BUILD" -eq 1 ]]; then
    SCAN_ARGS+=(--clean-build)
fi

SCAN_ARGS+=("${EXTRA_SCAN_ARGS[@]}")

mkdir -p "$(dirname "$RESULTS_PATH")"
if [[ "$PRINT_RESULTS" -eq 1 ]]; then
    HOME="$TOOL_HOME" "$BINARY" "${SCAN_ARGS[@]}"
else
    HOME="$TOOL_HOME" "$BINARY" "${SCAN_ARGS[@]}" > "${RESULTS_PATH}.stdout"
fi
printf 'cleanup scan results: %s\n' "$RESULTS_PATH"
if [[ "$PRINT_RESULTS" -eq 0 ]]; then
    printf 'cleanup scan stdout: %s\n' "${RESULTS_PATH}.stdout"
fi
