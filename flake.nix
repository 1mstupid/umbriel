{
  description = "Umbriel configuration and launcher";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    umbriel = {
      url = "github:noctalia-dev/umbriel";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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

      # Overridable: .override { config = otherConfigDerivation; }
      mkUmbriel = system:
        let
          pkgs = import nixpkgs { inherit system; };
          upstream = umbriel.packages.${system}.default;
        in
        pkgs.lib.makeOverridable ({ config }:
          (pkgs.symlinkJoin {
            name = "umbriel-with-config";
            paths = [ upstream ];
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram "$out/bin/umbriel" \
                --add-flags "-c ${config}/config.toml"

              # Replace the launcher with a copy that calls the wrapped binary.
              # The copy keeps the login-environment logic from upstream.
              rm "$out/bin/start-umbriel"
              sed "s|${upstream}/bin/umbriel|$out/bin/umbriel|g" \
                ${upstream}/bin/start-umbriel > "$out/bin/start-umbriel"
              chmod +x "$out/bin/start-umbriel"

              # Point the session file at the patched launcher.
              for f in "$out/share/wayland-sessions/"*.desktop; do
                sed -i "s|${upstream}/bin/start-umbriel|$out/bin/start-umbriel|g" "$f"
              done
            '';
            passthru = upstream.passthru or {};
            meta = upstream.meta or {};
          })) { config = mkConfig system; };
    in
    {
      nixosModules.default = umbriel.nixosModules.default;
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
