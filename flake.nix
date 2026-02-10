{
  description = "XDG desktop portal for the COSMIC desktop environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix-filter.url = "github:numtide/nix-filter";
    crane = {
      url = "github:ipetkov/crane";
    };
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, nix-filter, crane, fenix }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        craneLib = (crane.mkLib pkgs).overrideToolchain fenix.packages.${system}.stable.toolchain;

        runtimeDeps = with pkgs; [
          wayland
          libxkbcommon
          pipewire
          libei
          libglvnd
          mesa
          vulkan-loader
        ];

        pkgDef = {
          src = nix-filter.lib.filter {
            root = ./.;
            include = [
              ./src
              ./cosmic-portal-config
              ./data
              ./Cargo.toml
              ./Cargo.lock
              ./Makefile
              ./i18n.toml
              ./i18n
            ];
          };
          nativeBuildInputs = with pkgs; [
            pkg-config
            rustPlatform.bindgenHook
            gnumake
            autoPatchelfHook
          ];
          buildInputs = with pkgs; [
            pipewire
            libxkbcommon
            libglvnd
            glib
            gst_all_1.gstreamer
            libei
            libgbm
            wayland
            fontconfig
            freetype
            expat
            mesa
            vulkan-loader
            dbus
          ];
          runtimeDependencies = runtimeDeps;
          installCargoArtifactsMode = "use-zstd";
        };

        cargoArtifacts = craneLib.buildDepsOnly pkgDef;
        xdg-desktop-portal-cosmic = craneLib.buildPackage (pkgDef // {
          inherit cargoArtifacts;
          doNotPostBuildInstallCargoBinaries = true;

          buildPhase = ''
            runHook preBuild
            make DEBUG=0 VENDOR=0
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            make prefix=$out libexecdir=$out/libexec DEBUG=0 install
            runHook postInstall
          '';
        });
      in {
        checks = {
          inherit xdg-desktop-portal-cosmic;
        };

        packages = {
          default = xdg-desktop-portal-cosmic;
          xdg-desktop-portal-cosmic = xdg-desktop-portal-cosmic;
        };

        apps.default = flake-utils.lib.mkApp {
          drv = xdg-desktop-portal-cosmic;
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = builtins.attrValues self.checks.${system};
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath runtimeDeps;
        };
      }
    ) // {
      nixosModules = {
        default = import ./nix/module.nix;
        xdg-desktop-portal-cosmic = import ./nix/module.nix;
      };

      homeManagerModules = {
        default = import ./nix/home-manager.nix;
        xdg-desktop-portal-cosmic = import ./nix/home-manager.nix;
      };

      overlays.default = final: prev: {
        xdg-desktop-portal-cosmic = self.packages.${prev.system}.default;
      };
    };

  nixConfig = {
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];
  };
}
