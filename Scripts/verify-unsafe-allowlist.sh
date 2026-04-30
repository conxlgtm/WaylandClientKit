#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALLOWLIST_PATH="${ROOT_DIR}/Scripts/unsafe-token-allowlist.tsv"
TOKEN_PATTERN='@unchecked[[:space:]]+Sendable|UnsafeMutableRawBufferPointer|UnsafeMutableBufferPointer|UnsafeRawBufferPointer|UnsafeBufferPointer|UnsafeMutableRawPointer|UnsafeMutablePointer|UnsafeRawPointer|UnsafePointer|OpaquePointer|Unmanaged|unsafeBitCast|withUnsafeCurrentTask|nonisolated\(unsafe\)|unowned\(unsafe\)|pthread_[A-Za-z0-9_]+|eventfd|ppoll\(|poll\(|\bwl_display_dispatch\b|\bwl_display_dispatch_pending\b|\bwl_display_prepare_read\b|wl_proxy_add_listener|\bwl_proxy_get_queue\b|\bwl_proxy_set_queue\b|\bwl_proxy_create_wrapper\b|\bwl_proxy_wrapper_destroy\b|swl_proxy_get_queue_raw|UnsafeDefaultQueueEventLoop|EventLoop\.pumpOnce\(display:'

cd "${ROOT_DIR}"

is_allowed() {
    local path="$1"
    local token="$2"
    local pattern allowed_token reason

    while IFS=$'\t' read -r pattern allowed_token reason; do
        if [[ -z "${pattern}" || "${pattern}" == \#* ]]; then
            continue
        fi

        if [[ "${path}" != ${pattern} ]]; then
            continue
        fi

        if [[ "${token}" == ${allowed_token} ]]; then
            return 0
        fi
    done < "${ALLOWLIST_PATH}"

    return 1
}

failures=0
while IFS=: read -r path line token; do
    if [[ -z "${path}" ]]; then
        continue
    fi

    if is_allowed "${path}" "${token}"; then
        continue
    fi

    printf '%s:%s: unsafe token %q is not allowlisted\n' "${path}" "${line}" "${token}" >&2
    failures=1
done < <(rg -n -o "${TOKEN_PATTERN}" Sources Tests Package.swift || true)

if [[ "${failures}" -ne 0 ]]; then
    cat >&2 <<'MESSAGE'
Unsafe-token allowlist check failed.

Move the unsafe construct into an approved raw/shim boundary, or add a narrow entry
to Scripts/unsafe-token-allowlist.tsv with a concrete reason.
MESSAGE
fi

exit "${failures}"
