{
  description = "SwiftWayland development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forEachSystem = function:
        nixpkgs.lib.genAttrs systems (system:
          function (import nixpkgs { inherit system; }));
    in
    {
      devShells = forEachSystem (pkgs:
        let
          minimumSwiftVersion = "6.3.2";
          nixSwiftIsCurrent =
            !(pkgs.lib.versionOlder pkgs.swift.version minimumSwiftVersion);
          swiftTooling = pkgs.lib.optionals nixSwiftIsCurrent [
            pkgs.swift
            pkgs.swift-format
          ];
          nativeLibraries = [
            pkgs.libdrm
            pkgs.libgbm
            pkgs.libglvnd
            pkgs.libxkbcommon
            pkgs.mesa
            pkgs.wayland
          ];
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.clang
              pkgs.git
              pkgs.just
              pkgs.pkg-config
              pkgs.ripgrep
              pkgs.swiftlint
              pkgs.wayland-scanner
              pkgs.wayland-protocols
              pkgs.weston
            ] ++ swiftTooling ++ nativeLibraries;

            LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath nativeLibraries;
            SWIFT_WAYLAND_MINIMUM_SWIFT = minimumSwiftVersion;

            shellHook = ''
              swl_check_version() {
                tool_name="$1"
                version="$2"
                major="''${version%%.*}"
                rest="''${version#*.}"
                minor="''${rest%%.*}"
                if [ -z "$major" ] || [ -z "$minor" ]; then
                  echo "error: could not parse $tool_name version: $version" >&2
                  return 1
                fi
                if [ "$major" -lt 6 ] || { [ "$major" -eq 6 ] && [ "$minor" -lt 3 ]; } || [ "$major" -ge 100 ]; then
                  echo "error: $tool_name $version is too old; SwiftWayland requires $SWIFT_WAYLAND_MINIMUM_SWIFT or newer" >&2
                  echo "hint: install Swift $SWIFT_WAYLAND_MINIMUM_SWIFT with Swiftly or set SWIFT_BIN to the desired toolchain" >&2
                  return 1
                fi
              }

              if [ -z "''${SWIFT_BIN:-}" ]; then
                SWIFT_BIN="$(command -v swift || true)"
                export SWIFT_BIN
              fi
              if [ -z "$SWIFT_BIN" ] || [ ! -x "$SWIFT_BIN" ]; then
                echo "error: SwiftWayland requires Swift $SWIFT_WAYLAND_MINIMUM_SWIFT or newer, but swift was not found" >&2
                echo "hint: install Swift $SWIFT_WAYLAND_MINIMUM_SWIFT with Swiftly or set SWIFT_BIN to the desired toolchain" >&2
                exit 1
              fi
              swift_line="$("$SWIFT_BIN" --version)"
              swift_line="''${swift_line%%$'\n'*}"
              swift_version="''${swift_line#Swift version }"
              swift_version="''${swift_version%% *}"
              swl_check_version "Swift" "$swift_version" || exit 1

              if [ -z "''${SWIFT_FORMAT_BIN:-}" ]; then
                SWIFT_FORMAT_BIN="$(command -v swift-format || true)"
                export SWIFT_FORMAT_BIN
              fi
              if [ -z "$SWIFT_FORMAT_BIN" ] || [ ! -x "$SWIFT_FORMAT_BIN" ]; then
                echo "error: SwiftWayland requires swift-format $SWIFT_WAYLAND_MINIMUM_SWIFT or newer, but swift-format was not found" >&2
                echo "hint: install Swift $SWIFT_WAYLAND_MINIMUM_SWIFT with Swiftly or set SWIFT_FORMAT_BIN to the desired swift-format" >&2
                exit 1
              fi
              swift_format_version="$("$SWIFT_FORMAT_BIN" --version)"
              swift_format_version="''${swift_format_version%%$'\n'*}"
              swl_check_version "swift-format" "$swift_format_version" || exit 1
            '';
          };
        });
    };
}
