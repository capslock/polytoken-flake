{
  description = "Nix flake for the Polytoken CLI";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      version = "0.5.6";

      polytoken = pkgs.stdenvNoCC.mkDerivation {
        pname = "polytoken";
        inherit version;

        src = pkgs.fetchurl {
          url = "https://dl.polytoken.dev/${version}/linux-amd64/polytoken";
          hash = "sha256-9mAEgTKbUf4TvJjpAUIyJR8LwynBM8Pk2K4mVQq0020=";
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
    in
    {
      packages.${system} = {
        inherit polytoken;
        default = polytoken;
      };

      apps.${system}.default = {
        type = "app";
        program = "${polytoken}/bin/polytoken";
        meta.description = "Run Polytoken";
      };

      checks.${system}.version = pkgs.runCommand "polytoken-version-check" {
        nativeBuildInputs = [ polytoken ];
      } ''
        polytoken --version | grep -Fx "polytoken ${version}"
        touch "$out"
      '';
    };
}
