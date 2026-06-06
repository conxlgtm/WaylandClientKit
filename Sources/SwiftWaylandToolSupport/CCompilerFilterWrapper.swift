import Foundation

public enum CCompilerFilterWrapper {
    public static func install(in directory: URL, fileSystem: FileSystem) throws -> URL {
        let wrapper = directory.appendingPathComponent("clang-filter-index-store")
        try fileSystem.writeText(scriptText, to: wrapper)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: wrapper.path)
        return wrapper
    }

    public static func integrationTestEnvironment(
        wrapper: URL,
        base: [String: String],
        inherited: [String: String]
    ) -> [String: String] {
        var environment = base
        if environment["SWIFTWAYLAND_REAL_CC"] == nil {
            environment["SWIFTWAYLAND_REAL_CC"] = environment["CC"] ?? inherited["CC"]
        }
        environment["CC"] = wrapper.path
        return environment
    }

    public static let scriptText = """
        #!/usr/bin/env bash
        set -euo pipefail

        real_cc="${SWIFTWAYLAND_REAL_CC:-}"
        if [[ -z "$real_cc" ]]; then
            if [[ -n "${SWIFT_BIN:-}" && -x "$(dirname "$SWIFT_BIN")/clang" ]]; then
                real_cc="$(dirname "$SWIFT_BIN")/clang"
            else
                swiftly_home_dir="${SWIFTLY_HOME:-$HOME/.local/share/swiftly}"
                if [[ -d "$swiftly_home_dir/toolchains" ]]; then
                    real_cc="$(
                        find "$swiftly_home_dir/toolchains" -path '*/usr/bin/clang' \
                            | sort \
                            | tail -n 1
                    )"
                fi
            fi
        fi

        if [[ -z "$real_cc" ]]; then
            real_cc="$(command -v clang || command -v cc)"
        fi

        filtered_args=()
        skip_next=false

        for arg in "$@"; do
            if [[ "$skip_next" == true ]]; then
                skip_next=false
                continue
            fi

            case "$arg" in
            -index-store-path|-index-unit-output-path)
                skip_next=true
                ;;
            -index-store-path=*|-index-unit-output-path=*)
                ;;
            *)
                filtered_args+=("$arg")
                ;;
            esac
        done

        exec "$real_cc" "${filtered_args[@]}"
        """
}
