#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

./scripts/dev/swift.sh build --disable-index-store -c release --target CWaylandProtocols
./scripts/dev/swift.sh build --disable-index-store -c release --target CGBMShims

if ! command -v nm >/dev/null 2>&1; then
    echo "nm is required to verify release shim symbols." >&2
    exit 1
fi

if ! command -v rg >/dev/null 2>&1; then
    echo "rg is required to verify release shim symbols." >&2
    exit 1
fi

mapfile -d '' release_objects < <(
    find "$ROOT/.build" \
        -type f \
        -name '*.o' \
        \( \
            -path '*/release/CWaylandProtocols.build/*' \
            -o -path '*/release/CGBMShims.build/*' \
        \) \
        -print0
)

if [[ "${#release_objects[@]}" -eq 0 ]]; then
    echo "No release shim objects were found." >&2
    exit 1
fi

found=0
for object in "${release_objects[@]}"; do
    if nm -g "$object" | rg --quiet '\bswl_test_'; then
        echo "Test shim symbol found in release object: $object" >&2
        nm -g "$object" | rg '\bswl_test_' >&2
        found=1
    fi
done

exit "$found"
