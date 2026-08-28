{
  description = "Harmonica — dynamic-island shell for Hyprland (quickshell) + control CLI";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          inherit (pkgs) lib;

          # Rust CLI
          harmonica-cli = pkgs.rustPlatform.buildRustPackage {
            pname = "harmonica-cli";
            version = "0.1.0";
            src = ./cli;
            cargoLock.lockFile = ./cli/Cargo.lock;
            meta.mainProgram = "harmonica";
          };

          # Shell config (QML), read-only in the store
          harmonica-shell = pkgs.stdenv.mkDerivation {
            name = "harmonica-shell-0.1.0";
            src = self;
            phases = [ "installPhase" ];
            installPhase = ''
              mkdir -p $out/share/harmonica/scripts
              cp -r $src/shell.qml $src/Common $src/Modules $src/Widgets $src/Services \
                    $src/assets $out/share/harmonica/
              cp $src/scripts/*.lua $out/share/harmonica/scripts/
            '';
          };

          # User-facing binary: CLI wired to the store copy of the shell
          harmonica = pkgs.runCommand "harmonica-0.1.0"
            {
              meta.mainProgram = "harmonica";
              nativeBuildInputs = [ pkgs.makeWrapper ];
            }
            ''
              mkdir -p $out/bin
              makeWrapper ${harmonica-cli}/bin/harmonica $out/bin/harmonica \
                --set-default HARMONICA_CONFIG_DIR ${harmonica-shell}/share/harmonica
              ln -s ${harmonica-shell}/share $out/share
            '';
        in
        rec {
          inherit harmonica-cli harmonica-shell;
          default = harmonica;
        }
      );

      # programs.harmonica.enable → CLI on PATH + user service autostart
      homeManagerModules.default =
        { config, lib, pkgs, ... }:
        let
          cfg = config.programs.harmonica;
          pkg = self.packages.${pkgs.system}.default;
        in
        {
          options.programs.harmonica = {
            enable = lib.mkEnableOption "Harmonica dynamic-island shell";
          };

          config = lib.mkIf cfg.enable {
            home.packages = [
              pkg
              pkgs.wf-recorder   # screen-record backend
            ];

            # autostart via Hyprland exec-once (clearest for a Wayland shell)
            xdg.configFile."hypr/harmonica-autostart.conf".text =
              "exec-once = ${pkg}/bin/harmonica start";

            systemd.user.services.harmonica = {
              Unit = {
                Description = "Harmonica quickshell island";
                PartOf = [ "graphical-session.target" ];
                After = [ "graphical-session.target" ];
              };
              Service = {
                ExecStart = "${pkg}/bin/harmonica start --no-detach";
                Restart = "on-failure";
                RestartSec = 2;
              };
              Install.WantedBy = [ "graphical-session.target" ];
            };
          };
        };

      # nix develop — rust toolchain + quickshell + deps for local dev
      devShells = forSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              rustc
              cargo
              rust-analyzer
              clippy
              quickshell
              grim
              wf-recorder
              wl-clipboard
            ];
          };
        }
      );
    };
}
