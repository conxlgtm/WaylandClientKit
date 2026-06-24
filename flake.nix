{
  description = "WaylandClientKit development environment";

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
          lib = pkgs.lib;
          minimumSwiftVersion = "6.3.2";

          nixSwiftIsCurrent =
            !(lib.versionOlder pkgs.swift.version minimumSwiftVersion);

          # Swift 6.3.2 upstream binaries still expect libxml2.so.2.
          # nixos-unstable may expose newer libxml2 with a different SONAME,
          # so prefer a compat/older package when available.
          swiftCompatibleLibxml2Candidates =
            lib.filter (candidate: candidate != null) (map
              (attrName:
                if builtins.hasAttr attrName pkgs then
                  builtins.getAttr attrName pkgs
                else
                  null)
              [
                "libxml2_13"
                "libxml2_14"
                "libxml2_2_13"
                "libxml2"
              ]);

          swiftCompatibleLibxml2 =
            lib.findFirst
              (candidate: lib.versionOlder candidate.version "2.15")
              (throw "WaylandClientKit requires a nixpkgs libxml2 package that provides libxml2.so.2")
              swiftCompatibleLibxml2Candidates;

          swiftTooling = lib.optionals nixSwiftIsCurrent [
            pkgs.swift
            pkgs.swift-format
          ];

          tools = [
            pkgs.clang
            pkgs.git
            pkgs.just
            pkgs.pkg-config
            pkgs.ripgrep
            pkgs.swiftlint
            pkgs.wayland-scanner
            pkgs.wayland-protocols
            pkgs.weston
          ];

          waylandLibraries = [
            pkgs.libdrm
            pkgs.libgbm
            pkgs.libglvnd
            pkgs.libxkbcommon
            pkgs.mesa
            pkgs.wayland
          ];

          swiftlyRuntimeLibraries = [
            pkgs.stdenv.cc.cc.lib
            pkgs.glibc
            pkgs.glibc.dev
            swiftCompatibleLibxml2
            pkgs.icu
            pkgs.libedit
            pkgs.ncurses
            pkgs.zlib
            pkgs.openssl
            pkgs.curl
            pkgs.libffi
            pkgs.sqlite
            pkgs.xz
            pkgs.bzip2
            pkgs.util-linux
            pkgs.zstd
            pkgs.brotli
            pkgs.nghttp2
            pkgs.nghttp3
            pkgs.ngtcp2
            pkgs.libssh2
            pkgs.krb5
            pkgs.libidn2
            pkgs.libpsl
          ];

          allLibraries = waylandLibraries ++ swiftlyRuntimeLibraries;

          runtimeLibraryPath = lib.makeLibraryPath allLibraries;

          gccSupportLibraryPath =
            "${pkgs.stdenv.cc.cc}/lib/gcc/${pkgs.stdenv.hostPlatform.config}/${pkgs.stdenv.cc.cc.version}";

          compilerSearchPath = lib.concatStringsSep ":" [
            "${pkgs.glibc}/lib"
            gccSupportLibraryPath
          ];

          linkLibraryPath = lib.concatStringsSep ":" [
            gccSupportLibraryPath
            runtimeLibraryPath
          ];

          swiftLibcHeaders = pkgs.buildEnv {
            name = "waylandclientkit-swift-libc-headers";
            paths = [
              pkgs.glibc.dev
              pkgs.util-linux.dev
            ];
            pathsToLink = [ "/include" ];
          };

          includePath = lib.makeSearchPathOutput "dev" "include" [
            pkgs.glibc
            swiftCompatibleLibxml2
            pkgs.icu
            pkgs.libedit
            pkgs.ncurses
            pkgs.zlib
            pkgs.openssl
            pkgs.curl
            pkgs.libffi
            pkgs.sqlite
            pkgs.util-linux
            pkgs.wayland
            pkgs.libxkbcommon
            pkgs.libdrm
            pkgs.mesa
          ];
        in
        {
          default = pkgs.mkShell {
            packages = tools ++ swiftTooling ++ allLibraries;

            LD_LIBRARY_PATH = runtimeLibraryPath;
            LIBRARY_PATH = linkLibraryPath;
            COMPILER_PATH = compilerSearchPath;
            NIX_LD_LIBRARY_PATH = runtimeLibraryPath;
            CPATH = includePath;
            WAYLAND_CLIENT_KIT_MINIMUM_SWIFT = minimumSwiftVersion;

            shellHook = ''
              export LD_LIBRARY_PATH="${runtimeLibraryPath}"
              export LIBRARY_PATH="${linkLibraryPath}"
              export COMPILER_PATH="${compilerSearchPath}"
              export NIX_LD_LIBRARY_PATH="${runtimeLibraryPath}"
              export CPATH="${includePath}"

              if [ -f "''${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh" ]; then
                . "''${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh"
              fi

              swiftly_toolchain_bin="''${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/toolchains/$WAYLAND_CLIENT_KIT_MINIMUM_SWIFT/usr/bin"

              if [ -x "$swiftly_toolchain_bin/swift" ]; then
                export PATH="$swiftly_toolchain_bin:$PATH"
                export SWIFT_BIN="$swiftly_toolchain_bin/swift"
                export CC="$swiftly_toolchain_bin/clang"
                export CXX="$swiftly_toolchain_bin/clang++"
              elif [ -z "''${SWIFT_BIN:-}" ]; then
                SWIFT_BIN="$(command -v swift || true)"
                export SWIFT_BIN
              fi

              if [ -z "$SWIFT_BIN" ] || [ ! -x "$SWIFT_BIN" ]; then
                echo "error: WaylandClientKit requires Swift $WAYLAND_CLIENT_KIT_MINIMUM_SWIFT or newer, but swift was not found" >&2
                echo "hint: install Swift $WAYLAND_CLIENT_KIT_MINIMUM_SWIFT with Swiftly or set SWIFT_BIN to the desired toolchain" >&2
                exit 1
              fi

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

                case "$major" in
                  *[!0-9]*)
                    echo "error: could not parse $tool_name version: $version" >&2
                    return 1
                    ;;
                esac

                case "$minor" in
                  *[!0-9]*)
                    echo "error: could not parse $tool_name version: $version" >&2
                    return 1
                    ;;
                esac

                if [ "$major" -lt 6 ] || { [ "$major" -eq 6 ] && [ "$minor" -lt 3 ]; } || [ "$major" -ge 100 ]; then
                  echo "error: $tool_name $version is too old; WaylandClientKit requires $WAYLAND_CLIENT_KIT_MINIMUM_SWIFT or newer" >&2
                  return 1
                fi
              }

              swift_output="$("$SWIFT_BIN" --version 2>&1 || true)"
              swift_line="$(printf '%s\n' "$swift_output" | grep -m1 '^Swift version ' || true)"
              swift_version="''${swift_line#Swift version }"
              swift_version="''${swift_version%% *}"

              if [ -z "$swift_version" ]; then
                echo "error: could not find Swift version in output:" >&2
                printf '%s\n' "$swift_output" >&2
                exit 1
              fi

              swl_check_version "Swift" "$swift_version" || exit 1

              swift_resource_dir="$(dirname "$(dirname "$SWIFT_BIN")")/lib/swift"
              swift_libc_arch="${pkgs.stdenv.hostPlatform.parsed.cpu.name}"
              swift_glibc_modulemap="$swift_resource_dir/linux/$swift_libc_arch/glibc.modulemap"
              swift_glibc_runtime="$swift_resource_dir/linux/$swift_libc_arch/swiftrt.o"
              swift_sdkroot="''${TMPDIR:-/tmp}/waylandclientkit-swift-sdk"

              if [ ! -f "$swift_glibc_modulemap" ] || [ ! -f "$swift_glibc_runtime" ]; then
                echo "error: Swift toolchain is missing the expected Linux Glibc module files" >&2
                exit 1
              fi

              mkdir -p "$swift_sdkroot/usr" "$swift_sdkroot/usr/lib"
              ln -sfn "${swiftLibcHeaders}/include" "$swift_sdkroot/usr/include"
              ln -sfn "$swift_resource_dir" "$swift_sdkroot/usr/lib/swift"
              export SDKROOT="$swift_sdkroot"

              if [ -z "''${SWIFT_FORMAT_BIN:-}" ]; then
                SWIFT_FORMAT_BIN="$(command -v swift-format || true)"
                export SWIFT_FORMAT_BIN
              fi

              if [ -z "$SWIFT_FORMAT_BIN" ] || [ ! -x "$SWIFT_FORMAT_BIN" ]; then
                echo "warning: swift-format $WAYLAND_CLIENT_KIT_MINIMUM_SWIFT or newer was not found" >&2
              fi
            '';
          };
        });
    };
}
