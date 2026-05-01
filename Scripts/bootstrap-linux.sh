#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MODE="check"
MODE_SELECTED=0
MAINTAINER=0
RUN_BUILD=0
STRICT_SWIFT="${STRICT_SWIFT:-0}"
SUDO="${SUDO-sudo}"
PACKAGE_MANAGER="${PACKAGE_MANAGER:-}"
PKG_CONFIG="${PKG_CONFIG:-pkg-config}"
SWIFT_COMMAND="${SWIFT_COMMAND:-$ROOT/Scripts/swift.sh}"
SUDO_WORDS=()

usage() {
    cat <<'EOF'
Usage: Scripts/bootstrap-linux.sh [--check] [--install] [--dry-run] [--maintainer] [--build] [--strict-swift] [--package-manager PM]

Default behavior is --check: no sudo, no package installation.

Options:
  --check              verify dependencies only
  --install            install distro packages before checks
  --dry-run            print package-manager commands and exit
  --maintainer         also verify wayland-scanner and protocol XML inputs
  --build              run swift build after dependency checks
  --strict-swift       require an exact Swift version match with Package.swift
  --package-manager PM use a specific package manager mapping
  -h, --help           show this help

Environment:
  STRICT_SWIFT=1       same as --strict-swift
  SUDO=doas            command used for privileged package installation
  SUDO=                run package manager directly, useful in containers
  PACKAGE_MANAGER=nix  package manager mapping to use instead of detection
  PKG_CONFIG=pkgconf   pkg-config-compatible command to use for checks
  SWIFT_COMMAND=swift   Swift command used for version and build checks

Supported package managers:
  apt-get dnf pacman zypper apk emerge nix
EOF
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

ok() {
    printf 'ok: %s\n' "$*"
}

have() {
    command -v "$1" >/dev/null 2>&1
}

set_mode() {
    if [[ "$MODE_SELECTED" -eq 1 ]]; then
        die "choose only one mode: --check, --install, or --dry-run"
    fi

    MODE="$1"
    MODE_SELECTED=1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check)
            set_mode check
            ;;
        --install)
            set_mode install
            ;;
        --dry-run)
            set_mode dry-run
            ;;
        --maintainer)
            MAINTAINER=1
            ;;
        --build)
            RUN_BUILD=1
            ;;
        --strict-swift)
            STRICT_SWIFT=1
            ;;
        --package-manager)
            [[ $# -gt 1 ]] || die "--package-manager requires a value"
            PACKAGE_MANAGER="$2"
            shift
            ;;
        --package-manager=*)
            PACKAGE_MANAGER="${1#--package-manager=}"
            [[ -n "$PACKAGE_MANAGER" ]] || die "--package-manager requires a value"
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            die "unknown argument: $1"
            ;;
    esac
    shift
done

case "$STRICT_SWIFT" in
    0 | 1)
        ;;
    *)
        die "STRICT_SWIFT must be 0 or 1"
        ;;
esac

if [[ -n "$PACKAGE_MANAGER" ]]; then
    case "$PACKAGE_MANAGER" in
        apt-get | dnf | pacman | zypper | apk | emerge | nix)
            ;;
        *)
            die "unsupported package manager: $PACKAGE_MANAGER"
            ;;
    esac
fi

if [[ "$MODE" == "dry-run" && "$MAINTAINER" -eq 1 ]]; then
    die "--dry-run cannot be combined with --maintainer"
fi

if [[ "$MODE" == "dry-run" && "$RUN_BUILD" -eq 1 ]]; then
    die "--dry-run cannot be combined with --build"
fi

detect_pm() {
    local pm

    if [[ -n "$PACKAGE_MANAGER" ]]; then
        printf '%s\n' "$PACKAGE_MANAGER"
        return 0
    fi

    for pm in apt-get dnf pacman zypper apk emerge; do
        if have "$pm"; then
            printf '%s\n' "$pm"
            return 0
        fi
    done

    if have nix; then
        printf 'nix\n'
        return 0
    fi

    return 1
}

set_packages_for_pm() {
    case "$1" in
        apt-get)
            PACKAGES=(
                clang
                git
                libwayland-dev
                libxkbcommon-dev
                make
                pkg-config
                ripgrep
                wayland-protocols
            )
            ;;
        dnf)
            PACKAGES=(
                clang
                git
                wayland-devel
                wayland-protocols-devel
                libxkbcommon-devel
                make
                pkgconf-pkg-config
                ripgrep
            )
            ;;
        pacman)
            PACKAGES=(
                clang
                git
                wayland
                wayland-protocols
                libxkbcommon
                make
                pkgconf
                ripgrep
            )
            ;;
        zypper)
            PACKAGES=(
                clang
                git
                wayland-devel
                wayland-protocols-devel
                libxkbcommon-devel
                make
                pkgconf-pkg-config
                ripgrep
            )
            ;;
        apk)
            PACKAGES=(
                clang
                git
                wayland-dev
                wayland-protocols
                libxkbcommon-dev
                make
                pkgconf
                ripgrep
            )
            ;;
        emerge)
            PACKAGES=(
                sys-devel/clang
                dev-vcs/git
                dev-libs/wayland
                dev-libs/wayland-protocols
                dev-util/wayland-scanner
                x11-libs/libxkbcommon
                dev-build/make
                virtual/pkgconfig
                sys-apps/ripgrep
            )
            ;;
        nix)
            PACKAGES=(
                nixpkgs#clang
                nixpkgs#git
                nixpkgs#wayland
                nixpkgs#wayland-protocols
                nixpkgs#libxkbcommon
                nixpkgs#gnumake
                nixpkgs#pkg-config
                nixpkgs#ripgrep
            )
            ;;
        *)
            return 1
            ;;
    esac
}

sudo_words() {
    SUDO_WORDS=()
    [[ -n "$SUDO" ]] || return 0
    read -r -a SUDO_WORDS <<< "$SUDO"
}

print_shell_command() {
    local separator=''
    local word

    printf '  '
    for word in "$@"; do
        printf '%s%q' "$separator" "$word"
        separator=' '
    done
    printf '\n'
}

print_with_sudo() {
    sudo_words
    if [[ "${#SUDO_WORDS[@]}" -gt 0 ]]; then
        print_shell_command "${SUDO_WORDS[@]}" "$@"
    else
        print_shell_command "$@"
    fi
}

run_with_sudo() {
    sudo_words
    if [[ "${#SUDO_WORDS[@]}" -gt 0 ]]; then
        "${SUDO_WORDS[@]}" "$@"
    else
        "$@"
    fi
}

package_commands() {
    local pm="$1"
    shift

    case "$pm" in
        apt-get)
            print_with_sudo apt-get update
            print_with_sudo apt-get install -y "$@"
            ;;
        dnf)
            print_with_sudo dnf install -y "$@"
            ;;
        pacman)
            print_with_sudo pacman -S --needed --noconfirm "$@"
            ;;
        zypper)
            print_with_sudo zypper --non-interactive install "$@"
            ;;
        apk)
            print_with_sudo apk add "$@"
            ;;
        emerge)
            print_with_sudo emerge --ask=n --verbose "$@"
            ;;
        nix)
            print_shell_command nix shell "$@"
            ;;
        *)
            die "unsupported package manager: $pm"
            ;;
    esac
}

install_packages() {
    local pm="$1"
    shift

    case "$pm" in
        apt-get)
            run_with_sudo apt-get update
            run_with_sudo apt-get install -y "$@"
            ;;
        dnf)
            run_with_sudo dnf install -y "$@"
            ;;
        pacman)
            run_with_sudo pacman -S --needed --noconfirm "$@"
            ;;
        zypper)
            run_with_sudo zypper --non-interactive install "$@"
            ;;
        apk)
            run_with_sudo apk add "$@"
            ;;
        emerge)
            run_with_sudo emerge --ask=n --verbose "$@"
            ;;
        nix)
            die "Nix support is shell-based; use --dry-run to print a nix shell command, or add the listed inputs to a flake/shell.nix"
            ;;
        *)
            die "unsupported package manager: $pm"
            ;;
    esac
}

print_install_hint() {
    local pm

    pm="$(detect_pm || true)"
    [[ -n "$pm" ]] || return 0

    set_packages_for_pm "$pm" || return 0
    printf 'hint: prepare dependencies with:\n' >&2
    package_commands "$pm" "${PACKAGES[@]}" >&2
}

version_ge() {
    local have_v="$1"
    local need_v="$2"
    local h1 h2 h3 n1 n2 n3

    IFS=. read -r h1 h2 h3 <<< "$have_v"
    IFS=. read -r n1 n2 n3 <<< "$need_v"

    h1=${h1:-0}
    h2=${h2:-0}
    h3=${h3:-0}
    n1=${n1:-0}
    n2=${n2:-0}
    n3=${n3:-0}

    ((h1 > n1)) && return 0
    ((h1 < n1)) && return 1
    ((h2 > n2)) && return 0
    ((h2 < n2)) && return 1
    ((h3 >= n3))
}

check_swift_version() {
    local required installed swift_version_output

    required="$(
        sed -nE \
            '1s|^//[[:space:]]*swift-tools-version:[[:space:]]*([0-9]+(\.[0-9]+){0,2}).*|\1|p' \
            Package.swift
    )"
    [[ -n "$required" ]] || die "could not read swift-tools-version from Package.swift"

    if ! swift_version_output="$("$SWIFT_COMMAND" --version 2>&1)"; then
        printf '%s\n' "$swift_version_output" >&2
        die "missing usable Swift toolchain; install Swift $required or set SWIFT_COMMAND"
    fi

    installed="$(printf '%s\n' "$swift_version_output" \
        | sed -nE 's/^Swift version ([0-9]+)(\.[0-9]+)?(\.[0-9]+)?.*/\1\2\3/p' \
        | head -n 1)"
    [[ -n "$installed" ]] || die "could not parse swift --version"

    if [[ "$STRICT_SWIFT" -eq 1 ]]; then
        [[ "$installed" == "$required" ]] ||
            die "Swift $required required, found $installed"
    else
        version_ge "$installed" "$required" ||
            die "Swift >= $required required, found $installed"
    fi

    ok "swift $installed: $SWIFT_COMMAND"
}

check_commands() {
    local missing=()

    have clang || missing+=(clang)
    have "$PKG_CONFIG" || missing+=("$PKG_CONFIG")

    if [[ "${#missing[@]}" -gt 0 ]]; then
        printf 'error: missing required commands:' >&2
        printf ' %s' "${missing[@]}" >&2
        printf '\n' >&2
        print_install_hint
        exit 1
    fi

    ok "clang: $(command -v clang)"
    ok "$PKG_CONFIG: $(command -v "$PKG_CONFIG")"
    check_swift_version
}

check_pkg_config() {
    local missing=()
    local module

    for module in wayland-client wayland-cursor xkbcommon; do
        if "$PKG_CONFIG" --exists "$module"; then
            ok "$module $("$PKG_CONFIG" --modversion "$module")"
        else
            missing+=("$module")
        fi
    done

    if [[ "${#missing[@]}" -gt 0 ]]; then
        printf 'error: missing pkg-config modules:' >&2
        printf ' %s' "${missing[@]}" >&2
        printf '\n' >&2
        print_install_hint
        exit 1
    fi
}

pkg_config_variable() {
    local value

    value="$("$PKG_CONFIG" --variable="$2" "$1" 2>/dev/null || true)"
    printf '%s\n' "${value/#\/\//\/}"
}

first_existing_file() {
    local path

    for path in "$@"; do
        [[ -n "$path" ]] || continue
        if [[ -f "$path" ]]; then
            printf '%s\n' "$path"
            return 0
        fi
    done

    return 1
}

check_file_candidates() {
    local label="$1"
    shift
    local found

    found="$(first_existing_file "$@" || true)"
    if [[ -n "$found" ]]; then
        ok "$label: $found"
        return 0
    fi

    printf 'error: missing %s. Checked:\n' "$label" >&2
    printf '  %s\n' "$@" >&2
    exit 1
}

check_protocols_for_maintainers() {
    local wayland_client_dir wayland_scanner_dir protocols_dir

    have wayland-scanner || die "missing wayland-scanner"
    ok "wayland-scanner: $(command -v wayland-scanner)"

    "$PKG_CONFIG" --exists wayland-protocols ||
        die "missing pkg-config module: wayland-protocols"
    ok "wayland-protocols $("$PKG_CONFIG" --modversion wayland-protocols)"

    wayland_client_dir="$(pkg_config_variable wayland-client pkgdatadir)"
    wayland_scanner_dir="$(pkg_config_variable wayland-scanner pkgdatadir)"
    protocols_dir="$(pkg_config_variable wayland-protocols pkgdatadir)"

    check_file_candidates "wayland.xml" \
        "${wayland_client_dir:+$wayland_client_dir/wayland.xml}" \
        "${wayland_scanner_dir:+$wayland_scanner_dir/wayland.xml}" \
        /usr/share/wayland/wayland.xml \
        /usr/local/share/wayland/wayland.xml

    check_file_candidates "xdg-shell.xml" \
        "${protocols_dir:+$protocols_dir/stable/xdg-shell/xdg-shell.xml}" \
        /usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml \
        /usr/local/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml \
        /usr/share/qt6/wayland/protocols/xdg-shell/xdg-shell.xml
}

if [[ "$MODE" == "install" || "$MODE" == "dry-run" ]]; then
    PM="$(detect_pm || true)"
    [[ -n "$PM" ]] || die "could not detect a supported package manager"
    set_packages_for_pm "$PM" || die "unsupported package manager: $PM"

    if [[ "$MODE" == "dry-run" ]]; then
        if [[ "$PM" == "nix" ]]; then
            printf 'Dependency shell command for nix:\n'
        else
            printf 'Install commands for %s:\n' "$PM"
        fi
        package_commands "$PM" "${PACKAGES[@]}"
        exit 0
    fi

    install_packages "$PM" "${PACKAGES[@]}"
fi

check_commands
check_pkg_config

if [[ "$MAINTAINER" -eq 1 ]]; then
    check_protocols_for_maintainers
fi

if [[ "$RUN_BUILD" -eq 1 ]]; then
    "$SWIFT_COMMAND" build
fi

echo "Linux bootstrap checks passed."
