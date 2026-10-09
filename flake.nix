{
  description = "Umbriel configuration and launcher";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    umbriel.url = "git+https://github.com/noctalia-dev/umbriel";
  };

  outputs = { self, nixpkgs, umbriel }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;

      mkUmbriel = system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };

          umbrielConfig = pkgs.stdenvNoCC.mkDerivation {
            pname = "umbriel-config";
            version = "unstable";

            src = ./.;
            dontBuild = true;

            installPhase = ''
              mkdir -p $out/cfg

              cp config.toml $out/config.toml
              cp cfg/*.toml $out/cfg/
            '';
          };

          umbrielPackage = umbriel.packages.${system}.default;
        in
      pkgs.symlinkJoin {
        name = "umbriel-with-config";

        paths = [
          umbrielPackage
        ];

        nativeBuildInputs = [
          pkgs.makeWrapper
        ];

        postBuild = ''
          wrapProgram $out/bin/umbriel \
            --add-flags "--config ${umbrielConfig}/config.toml"

          mkdir -p $out/share/wayland-sessions

          cat > $out/share/wayland-sessions/umbriel.desktop <<EOF
          [Desktop Entry]
          Name=Umbriel
          Comment=Umbriel Wayland Session
          Exec=$out/bin/umbriel
          Type=Application
          DesktopNames=Umbriel
          EOF
        '';
      };
      mkConfig = system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };
        in
        pkgs.stdenvNoCC.mkDerivation {
          pname = "umbriel-config";
          version = "unstable";

          src = ./.;
          dontBuild = true;

          installPhase = ''
            mkdir -p $out/cfg

            cp config.toml $out/config.toml
            cp cfg/*.toml $out/cfg/
          '';
        };
    in
    {
      packages = forAllSystems (system: {
        default = mkUmbriel system;
        umbriel = mkUmbriel system;
        config = mkConfig system;
      });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${mkUmbriel system}/bin/umbriel";
        };
      });
    };
}
