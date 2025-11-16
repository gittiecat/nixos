{
  description = "Flake migration from configuration.nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixpkgs-2505.url = "github:NixOS/nixpkgs/nixos-25.05";
    nix-citizen.url = "github:LovingMelody/nix-citizen";
    swww.url = "github:LGFae/swww";
  };

  outputs = { self, nixpkgs, nixpkgs-2505, ... }@inputs:
  let
    system = "x86_64-linux";

    obsWrapOverlay = import ./overlays/obs-wrap.nix;

    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [ obsWrapOverlay ];
    }; 

    pkgs2505 = import nixpkgs-2505 {
      inherit system;
      config.allowUnfree = true;
    };

    mkScript = name: pkgs.writeShellScriptBin name (builtins.readFile (./scripts + "/${name}"));

    os-scripts = pkgs.symlinkJoin {
      name = "os-scripts";
      paths = [
        (mkScript "lock")
        (mkScript "play-last")
        (mkScript "show-desktop")
      ];
    };
    
  in {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        ./modules/vscode.nix
        {
          environment.systemPackages = with pkgs; [
            os-scripts
            vim
            git
            wget
            google-chrome
            steam
            protonplus
            python314
            discord
            kitty
            (waybar.overrideAttrs (old: { mesonFlags = old.mesonFlags ++ [ "-Dexperimental=true" ]; }))
            wl-clipboard
            wofi
            hyprshot
            playerctl
            xdg-desktop-portal-hyprland
            obs-studio
            mangohud
            protonup-qt
            ferium
            prismlauncher
            easyeffects
            telegram-desktop
            audacity
            pywal16
            hyprpicker
            networkmanager
            mako
            swaylock-effects
            tokyonight-gtk-theme
            nwg-look
            pkgs2505.kdePackages.xwaylandvideobridge
            v4l-utils
            gimp
            vulkan-tools
            vulkan-validation-layers
            wireshark
            libnotify 
            glib-networking
            cava
            swayidle
            sqlite
            shotcut
            mpv
            swayimg
            hyprpaper
            swaybg
            jq
            vencord
            vesktop
            hyprprop
            grimblast
            imagemagick
            slurp
            lv2
            psmisc
          ];

          fonts.packages = with pkgs; [
            fira-code
            fira-code-symbols
            font-awesome
            liberation_ttf
            mplus-outline-fonts.githubRelease
            noto-fonts
            noto-fonts-color-emoji
            proggyfonts
            nerd-fonts._3270
            nerd-fonts.agave
            nerd-fonts.anonymice
            nerd-fonts.arimo
            nerd-fonts.aurulent-sans-mono
            nerd-fonts.bigblue-terminal
            nerd-fonts.bitstream-vera-sans-mono
            nerd-fonts.blex-mono
            nerd-fonts.caskaydia-cove
            nerd-fonts.caskaydia-mono
            nerd-fonts.code-new-roman
            nerd-fonts.comic-shanns-mono
            nerd-fonts.commit-mono
            nerd-fonts.cousine
            nerd-fonts.d2coding
            nerd-fonts.daddy-time-mono
            nerd-fonts.departure-mono
            nerd-fonts.dejavu-sans-mono
            nerd-fonts.droid-sans-mono
            nerd-fonts.envy-code-r
            nerd-fonts.fantasque-sans-mono
            nerd-fonts.fira-code
            nerd-fonts.fira-mono
            nerd-fonts.geist-mono
            nerd-fonts.go-mono
            nerd-fonts.gohufont
            nerd-fonts.hack
            nerd-fonts.hasklug
            nerd-fonts.heavy-data
            nerd-fonts.hurmit
            nerd-fonts.im-writing
            nerd-fonts.inconsolata
            nerd-fonts.inconsolata-go
            nerd-fonts.inconsolata-lgc
            nerd-fonts.intone-mono
            nerd-fonts.iosevka
            nerd-fonts.iosevka-term
            nerd-fonts.iosevka-term-slab
            nerd-fonts.jetbrains-mono
            nerd-fonts.lekton
            nerd-fonts.liberation
            nerd-fonts.lilex
            nerd-fonts.martian-mono
            nerd-fonts.meslo-lg
            nerd-fonts.monaspace
            nerd-fonts.monofur
            nerd-fonts.monoid
            nerd-fonts.mononoki
            nerd-fonts.noto
            nerd-fonts.open-dyslexic
            nerd-fonts.overpass
            nerd-fonts.profont
            nerd-fonts.proggy-clean-tt
            nerd-fonts.recursive-mono
            nerd-fonts.roboto-mono
            nerd-fonts.shure-tech-mono
            nerd-fonts.sauce-code-pro
            nerd-fonts.space-mono
            nerd-fonts.symbols-only
            nerd-fonts.terminess-ttf
            nerd-fonts.tinos
            nerd-fonts.ubuntu
            nerd-fonts.ubuntu-mono
            nerd-fonts.ubuntu-sans
            nerd-fonts.victor-mono
            nerd-fonts.zed-mono
          ];

          programs.bash.shellAliases = {
            l = "ls -l";
            ll = "ls -lah";
            rebuild = "sudo nixos-rebuild switch --flake /etc/nixos/.";
            waybar-reload = "pkill waybar && hyprctl dispatch exec waybar";
            matrix = "bash <(curl -s https://raw.githubusercontent.com/wick3dr0se/matrix/main/matrix)";
            open = "swayimg";
            clip = "wl-copy";
          };

          programs.vim.enable = true;
          programs.steam = { enable = true; gamescopeSession.enable = true; };
          programs.gamemode.enable = true;

          programs.hyprland = { enable = true; xwayland.enable = true; };
          programs.sway = { enable = true; wrapperFeatures.gtk = true; };

          environment.sessionVariables = {
            WLR_NO_HARDWARE_CURSORS = "1";
            NIXOS_OZONE_WL = "1";
            ELECTRON_OZONE_PLATFORM_HINT = "auto";
          };

          environment.etc."inputrc".text = ''
            "\C-v":
          '';

          systemd.user.services.obs-quit = {
            description = "Quit OBS gracefully (SIGINT) on shutdown";
            wantedBy = [ "default.target" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;  # This is required!
              ExecStart = "${pkgs.coreutils}/bin/true";
              ExecStop = "${pkgs.bash}/bin/bash -c 'pkill -SIGINT -x obs || true'";
              TimeoutStopSec = 15;
            };
          };


          xdg.portal = {
            enable = true;
            extraPortals = [
              pkgs.xdg-desktop-portal-hyprland
              pkgs.xdg-desktop-portal-gtk
            ];
          };
        }
      ];
    };
  };
}
