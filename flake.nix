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
              pkgs.swift
              pkgs.swift-format
              pkgs.swiftlint
              pkgs.wayland-scanner
              pkgs.wayland-protocols
              pkgs.weston
            ] ++ nativeLibraries;

            LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath nativeLibraries;
          };
        });
    };
}
