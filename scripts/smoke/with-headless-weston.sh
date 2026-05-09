#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat >&2 <<'USAGE'
usage: scripts/smoke/with-headless-weston.sh -- command [arguments...]
USAGE
}

if [[ $# -lt 2 || "${1:-}" != "--" ]]; then
    usage
    exit 2
fi
shift

if ! command -v weston >/dev/null 2>&1; then
    echo "weston is required for headless Wayland tests." >&2
    exit 1
fi

runtime_dir="$(mktemp -d -t swiftwayland-runtime.XXXXXX)"
socket="swiftwayland-${RANDOM}-$$"
log="${runtime_dir}/weston.log"
process_log="${runtime_dir}/weston-process.log"
config_dir="${runtime_dir}/config"
weston_pid=""

cleanup() {
    local status="$?"
    trap - EXIT INT TERM

    if [[ -n "$weston_pid" ]]; then
        kill "$weston_pid" 2>/dev/null || true
        wait "$weston_pid" 2>/dev/null || true
    fi

    if [[ "$status" -ne 0 && -f "$log" ]]; then
        {
            echo "----- weston.log -----"
            cat "$log"
            echo "----------------------"
        } >&2
    fi
    if [[ "$status" -ne 0 && -s "$process_log" ]]; then
        {
            echo "----- weston process output -----"
            cat "$process_log"
            echo "---------------------------------"
        } >&2
    fi

    rm -rf "$runtime_dir"
    exit "$status"
}
trap cleanup EXIT INT TERM

chmod 700 "$runtime_dir"
mkdir -p "$config_dir"

export XDG_RUNTIME_DIR="$runtime_dir"
export XDG_CONFIG_HOME="$config_dir"
export WAYLAND_DISPLAY="$socket"
unset WAYLAND_SOCKET

weston \
    --backend=headless-backend.so \
    --socket="$socket" \
    --idle-time=0 \
    --log="$log" \
    >"$process_log" 2>&1 &
weston_pid="$!"

for _ in {1..100}; do
    if [[ -S "${runtime_dir}/${socket}" ]]; then
        break
    fi
    if ! kill -0 "$weston_pid" 2>/dev/null; then
        echo "weston exited before creating ${runtime_dir}/${socket}." >&2
        exit 1
    fi
    sleep 0.05
done

if [[ ! -S "${runtime_dir}/${socket}" ]]; then
    echo "weston did not create ${runtime_dir}/${socket}." >&2
    exit 1
fi

"$@"
