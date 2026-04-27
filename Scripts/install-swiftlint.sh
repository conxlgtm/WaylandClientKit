#!/usr/bin/env bash
set -euo pipefail

VERSION="${SWIFTLINT_VERSION:-0.61.0}"
DESTINATION="${1:-$HOME/.local/bin}"

case "$(uname -m)" in
    x86_64 | amd64)
        ARCHIVE_ARCH="amd64"
        ;;
    aarch64 | arm64)
        ARCHIVE_ARCH="arm64"
        ;;
    *)
        echo "Unsupported SwiftLint architecture: $(uname -m)"
        exit 1
        ;;
esac

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

ARCHIVE="$TMPDIR/swiftlint.zip"
URL="https://github.com/realm/SwiftLint/releases/download/${VERSION}/swiftlint_linux_${ARCHIVE_ARCH}.zip"

mkdir -p "$DESTINATION"
curl --fail --location --silent --show-error "$URL" --output "$ARCHIVE"
unzip -q "$ARCHIVE" -d "$TMPDIR"

if [[ -x "$TMPDIR/swiftlint" ]]; then
    install -m 0755 "$TMPDIR/swiftlint" "$DESTINATION/swiftlint"
elif [[ -x "$TMPDIR/swiftlint-static" ]]; then
    install -m 0755 "$TMPDIR/swiftlint-static" "$DESTINATION/swiftlint"
else
    echo "SwiftLint binary not found in $URL"
    exit 1
fi

"$DESTINATION/swiftlint" version
