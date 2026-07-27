{
  description = "Nix flake for the Polytoken CLI";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      release = builtins.fromJSON (builtins.readFile ./release.json);
      artifact =
        release.platforms.${system}
          or (throw "Polytoken ${release.version} has no artifact for ${system}");
      version = release.version;

      polytoken = pkgs.stdenvNoCC.mkDerivation {
        pname = "polytoken";
        inherit version;

        src = pkgs.fetchurl {
          url = "https://dl.polytoken.dev/${version}/${artifact.path}";
          inherit (artifact) hash;
        };

        dontUnpack = true;

        installPhase = ''
          runHook preInstall
          install -Dm755 "$src" "$out/bin/polytoken"
          runHook postInstall
        '';

        meta = {
          description = "Local-first AI coding agent daemon and CLI";
          homepage = "https://polytoken.dev";
          mainProgram = "polytoken";
          platforms = [ "x86_64-linux" ];
          sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
        };
      };

      updater = pkgs.writeShellApplication {
        name = "polytoken-update";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.curl
          pkgs.gawk
          pkgs.jq
          pkgs.nix
        ];
        text = ''
          exec ${pkgs.bash}/bin/bash ${./scripts/update.sh} "$@"
        '';
      };
    in
    {
      packages.${system} = {
        inherit polytoken;
        default = polytoken;
      };

      apps.${system} = {
        default = {
          type = "app";
          program = "${polytoken}/bin/polytoken";
          meta.description = "Run Polytoken";
        };

        update = {
          type = "app";
          program = "${updater}/bin/polytoken-update";
          meta.description = "Update release.json to the latest Polytoken release";
        };
      };

      checks.${system} = {
        version = pkgs.runCommand "polytoken-version-check" {
          nativeBuildInputs = [ polytoken ];
        } ''
          polytoken --version | grep -Fx "polytoken ${version}"
          touch "$out"
        '';

        update-script = pkgs.runCommand "polytoken-update-shellcheck" {
          nativeBuildInputs = [ pkgs.shellcheck ];
        } ''
          shellcheck ${./scripts/update.sh}
          touch "$out"
        '';

        workflows = pkgs.runCommand "polytoken-workflow-check" {
          nativeBuildInputs = [ pkgs.actionlint ];
        } ''
          actionlint \
            ${./.github/workflows/ci.yml} \
            ${./.github/workflows/update.yml}
          touch "$out"
        '';
      };
    };
}
