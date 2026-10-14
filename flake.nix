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
          minimumSwiftVersion = "6.4.0";

          nixSwiftIsCurrent =
            !(lib.versionOlder pkgs.swift.version minimumSwiftVersion);

          # Upstream Swift tools need libxml2.so.2.
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
            pkgs.python3
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

          swiftSDKConfiguration = pkgs.writeText "waylandclientkit-swift-sdk.json"
            (builtins.toJSON {
              minimumVersion = minimumSwiftVersion;
              targetTriple = pkgs.stdenv.hostPlatform.config;
              bash = "${pkgs.bash}/bin/bash";
              bubblewrap = "${pkgs.bubblewrap}/bin/bwrap";
              hostTools = "${pkgs.coreutils}/bin";
              dynamicLinker = pkgs.stdenv.cc.bintools.dynamicLinker;
              linker = "${pkgs.stdenv.cc.bintools}/bin/ld";
              gccRoot = toString pkgs.stdenv.cc.cc;
              nixStore = builtins.storeDir;
              libcHeaders = "${swiftLibcHeaders}/include";
              libcLibraryPaths = [
                "${pkgs.glibc}/lib"
              ];
              inherit runtimeLibraryPath;
              includeSearchPaths = lib.splitString ":" includePath;
              librarySearchPaths =
                [ gccSupportLibraryPath ] ++ lib.splitString ":" runtimeLibraryPath;
            });
        in
        {
          default = pkgs.mkShell {
            packages = tools ++ swiftTooling ++ allLibraries;

            CPATH = includePath;
            WAYLAND_CLIENT_KIT_MINIMUM_SWIFT = minimumSwiftVersion;

            shellHook = ''
              # Build the SDK for this Nix platform and the selected compiler.
              # Set runtime paths per tool so Git and hooks keep the host libc.
              swift_environment="$(${pkgs.python3}/bin/python ${./nix/swift-toolchain.py} ${swiftSDKConfiguration})" || exit 1
              eval "$swift_environment"
            '';
          };
        });
    };
}
