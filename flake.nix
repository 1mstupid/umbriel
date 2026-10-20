{
  description = "Umbriel configuration and launcher";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    umbriel.url = "github:noctalia-dev/umbriel";
  };

  outputs = { self, nixpkgs, umbriel, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;

      mkConfig = system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        pkgs.stdenvNoCC.mkDerivation {
          pname = "umbriel-config";
          version = "1.0.0";

          src = pkgs.lib.cleanSourceWith {
            src = ./.;
            filter = path: type:
              let
                name = baseNameOf path;
              in
              !(builtins.elem name [
                ".git"
                ".direnv"
                "result"
              ]);
          };

          dontBuild = true;

          installPhase = ''
            runHook preInstall

            mkdir -p "$out/cfg"

            cp config.toml "$out/config.toml"
            cp -r cfg/. "$out/cfg/"

            runHook postInstall
          '';
        };

        mkUmbriel = system:
        let
          pkgs = import nixpkgs { inherit system; };
          config = mkConfig system;
          upstream = umbriel.packages.${system}.default;
        in
        (pkgs.symlinkJoin {
          name = "umbriel-with-config";
          paths = [ upstream ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram "$out/bin/umbriel" \
              --add-flags "-c ${config}/config.toml"
          '';
        }).overrideAttrs (old: {
          passthru = (upstream.passthru or {}) // (old.passthru or {});
          meta = (upstream.meta or {}) // (old.meta or {});
        });
    in
    {
      packages = forAllSystems (system:
        let
          config = mkConfig system;
          compositor = mkUmbriel system;
        in
        {
          default = compositor;
          umbriel = compositor;
          inherit config;
        });

      apps = forAllSystems (system:
        let
          compositor = mkUmbriel system;
        in
        {
          default = {
            type = "app";
            program = "${compositor}/bin/umbriel";
          };

          umbriel = {
            type = "app";
            program = "${compositor}/bin/umbriel";
          };
        });
    };
}
