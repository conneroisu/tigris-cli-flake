{
  description = "Personal Website for Conner Ohnesorge";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };

    nix2container = {
      url = "github:nlewo/nix2container";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";

    bun2nix.url = "github:baileyluTCD/bun2nix";

    systems.url = "github:nix-systems/default";
  };

  nixConfig = {
    extra-substituters = ''
      https://cache.nixos.org
      https://nix-community.cachix.org
      https://devenv.cachix.org
      https://conneroisu.cachix.org
    '';
    extra-trusted-public-keys = ''
      cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
      nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
      devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=
      conneroisu.cachix.org-1:PgOlJ8/5i/XBz2HhKZIYBSxNiyzalr1B/63T74lRcU0=
    '';
    extra-experimental-features = "nix-command flakes";
  };

  outputs = inputs @ {flake-utils, ...}:
    flake-utils.lib.eachSystem [
      "x86_64-linux"
      "i686-linux"
      "x86_64-darwin"
      "aarch64-linux"
      "aarch64-darwin"
    ] (system: let
      overlays = [(final: prev: {final.go = prev.go_1_24;})];
      pkgs = import inputs.nixpkgs {inherit system overlays;};
      buildGoModule = pkgs.buildGoModule.override {go = pkgs.go_1_24;};
      buildWithSpecificGo = pkg: pkg.override {inherit buildGoModule;};

      bunDeps = pkgs.callPackage ./bun.nix {};

      scripts = {
        dx = {
          exec = ''$EDITOR $REPO_ROOT/flake.nix'';
          description = "Edit flake.nix";
        };
      };

      # Convert scripts to packages
      scriptPackages =
        pkgs.lib.mapAttrsToList
        (name: script: pkgs.writeShellScriptBin name script.exec)
        scripts;
    in rec {
      devShells.default = pkgs.mkShell {
        shellHook = ''
          export REPO_ROOT=$(git rev-parse --show-toplevel)
          # Print available commands
          echo "Available commands:"
          ${pkgs.lib.concatStringsSep "\n" (
            pkgs.lib.mapAttrsToList (
              name: script: ''echo "  ${name} - ${script.description}"''
            )
            scripts
          )}
        '';
        packages = with pkgs;
          [
            # Nix
            alejandra
            nixd
            statix
            deadnix
            inputs.bun2nix.defaultPackage.${pkgs.system}.bin
          ]
          # Add the generated script packages
          ++ scriptPackages;
      };

      packages = {
        default = pkgs.buildGoModule {
          pname = "tigris-cli";
          version = "0.0.1";
          src = pkgs.fetchFromGitHub {
            owner = "tigrisdata-archive";
            repo = "tigris-cli";
            rev = "v1.0.6";
            sha256 = "sha256-J4h5a5xV7A/mJp0QDXALshvh5T340GGKoArxD8CoXYY=";
          };
          vendorHash = "sha256-lL8vbRtqKW46ic/CdW1ccEpcN6btTDaTKQzwq0D1Jfc=";
        };
      };
    });
}
