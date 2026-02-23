{
  description = "Flake migration from configuration.nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixpkgs-2505.url = "github:NixOS/nixpkgs/nixos-25.05";
    swww.url = "github:LGFae/swww";
  };

  outputs = { self, nixpkgs, nixpkgs-2505, ... }@inputs:
  let
    system = "x86_64-linux";

    overlay = final: prev: { };

    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [ ];
    }; 

    pkgs2505 = import nixpkgs-2505 {
      inherit system;
      config.allowUnfree = true;
    };

    mkScript = name: pkgs.writeShellScriptBin name (builtins.readFile (./scripts + "/${name}"));

    # os-scripts = pkgs.symlinkJoin {
    #   name = "os-scripts";
    #   paths = [
    #     (mkScript "lock")
    #     (mkScript "play-last")
    #     (mkScript "show-desktop")
    #   ];
    # };

    obs = pkgs.obs-studio.override {
      cudaSupport = true;
    };
    
  in {
    overlays.default = overlay;

    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        ./modules/vscode.nix
        {
          environment.systemPackages = with pkgs; [
            vim
            git
            wget
            google-chrome
            steam
            protonplus
            python314
            python3Packages.pip
            discord
            kitty
            (waybar.overrideAttrs (old: { mesonFlags = old.mesonFlags ++ [ "-Dexperimental=true" ]; }))
            (wrapOBS.override { obs-studio = pkgs.obs-studio.override { cudaSupport = true; }; } {
              plugins = with pkgs.obs-studio-plugins; [ wlrobs ];
            })
            wl-clipboard
            wofi
            hyprshot
            playerctl
            # xdg-desktop-portal-hyprland
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
            libimobiledevice
            ifuse
            usbmuxd
            tree
            protonup-qt
            ffmpeg
            qt6.qtwayland
            upower
            gamescope
          ];

          environment.etc = {
            "xdg/xdph.conf".text = ''
              screencopy {
                allow_token_by_default = true
              }
            '';
          };

          environment.variables = {
            GBM_BACKEND = "nvidia-drm";
            __GLX_VENDOR_LIBRARY_NAME = "nvidia";
            GBM_BACKENDS_PATH = "/run/opengl-driver/lib/gbm:/run/opengl-driver-32/lib/gbm";
          };

          # fonts.packages = with pkgs; [
          #   fira-code fira-code-symbols font-awesome liberation_ttf mplus-outline-fonts.githubRelease noto-fonts noto-fonts-color-emoji proggyfonts nerd-fonts._3270 nerd-fonts.agave nerd-fonts.anonymice nerd-fonts.arimo nerd-fonts.aurulent-sans-mono nerd-fonts.bigblue-terminal nerd-fonts.bitstream-vera-sans-mono nerd-fonts.blex-mono nerd-fonts.caskaydia-cove nerd-fonts.caskaydia-mono nerd-fonts.code-new-roman nerd-fonts.comic-shanns-mono nerd-fonts.commit-mono nerd-fonts.cousine nerd-fonts.d2coding nerd-fonts.daddy-time-mono nerd-fonts.departure-mono nerd-fonts.dejavu-sans-mono nerd-fonts.droid-sans-mono nerd-fonts.envy-code-r nerd-fonts.fantasque-sans-mono nerd-fonts.fira-code nerd-fonts.fira-mono nerd-fonts.geist-mono nerd-fonts.go-mono nerd-fonts.gohufont nerd-fonts.hack nerd-fonts.hasklug nerd-fonts.heavy-data nerd-fonts.hurmit nerd-fonts.im-writing nerd-fonts.inconsolata nerd-fonts.inconsolata-go nerd-fonts.inconsolata-lgc nerd-fonts.intone-mono nerd-fonts.iosevka nerd-fonts.iosevka-term nerd-fonts.iosevka-term-slab nerd-fonts.jetbrains-mono nerd-fonts.lekton nerd-fonts.liberation nerd-fonts.lilex nerd-fonts.martian-mono nerd-fonts.meslo-lg nerd-fonts.monaspace nerd-fonts.monofur nerd-fonts.monoid nerd-fonts.mononoki nerd-fonts.noto nerd-fonts.open-dyslexic nerd-fonts.overpass nerd-fonts.profont nerd-fonts.proggy-clean-tt nerd-fonts.recursive-mono nerd-fonts.roboto-mono nerd-fonts.shure-tech-mono nerd-fonts.sauce-code-pro nerd-fonts.space-mono nerd-fonts.symbols-only nerd-fonts.terminess-ttf nerd-fonts.tinos nerd-fonts.ubuntu nerd-fonts.ubuntu-mono nerd-fonts.ubuntu-sans nerd-fonts.victor-mono nerd-fonts.zed-mono
          # ];

          programs.bash.shellAliases = {
            l = "ls -l";
            ll = "ls -lah";
            rebuild = "sudo nixos-rebuild switch --flake /etc/nixos/.";
            rebuild-fallback = "sudo nixos-rebuild switch --flake /etc/nixos/. --option fallback false";
            waybar-reload = "pkill waybar && hyprctl dispatch exec waybar";
            matrix = "bash <(curl -s https://raw.githubusercontent.com/wick3dr0se/matrix/main/matrix)";
            open = "swayimg";
            clip = "wl-copy";
            play = "mpv --no-config --vo=gpu-next --gpu-api=vulkan --fullscreen --hwdec=no --";
          };

          programs = {
            gamescope = {
              enable = false;
              package = pkgs.gamescope.overrideAttrs (_: {
                NIX_CFLAGS_COMPILE = [ "-fno-fast-math" ];
              });
              capSysNice = false;
              args = [
                "--output-width 2560"
                "--nested-width 2560"
                "--output-height 1440"
                "--nested-height 1440"
                "--expose-wayland"
                "--force-grab-cursor"
                "--adaptive-sync"
                "--fullscreen"
              ];
            };
            gamemode.enable = true;
            steam = {
              enable = true;
              localNetworkGameTransfers.openFirewall = true;
              protontricks.enable = true;
              extest.enable = true;
              package = pkgs.steam.override {
                extraEnv = { STEAM_RUNTIME = "0";};
              };
              extraCompatPackages = [
                pkgs.steamtinkerlaunch
                pkgs.proton-ge-bin
              ];
            };
          };

          programs.hyprland = { 
            enable = true; 
            xwayland.enable = true;
            portalPackage = pkgs.xdg-desktop-portal-hyprland;
          };
          
          programs.sway = { enable = true; wrapperFeatures.gtk = true; };

          environment.sessionVariables = {
            NIXOS_OZONE_WL = "1";
            ELECTRON_OZONE_PLATFORM_HINT = "auto";
          };

          environment.etc."inputrc".text = ''
            "\C-v":
          '';

          xdg.portal = {
            enable = true;
            extraPortals = [
              pkgs.xdg-desktop-portal-wlr
              pkgs.xdg-desktop-portal-gtk
            ];
            # config = {
            #   hyprland = {
            #     default = [ "gtk" ];
            #     "org.freedesktop.impl.portal.ScreenCast" = "wlr";
            #   };
            # };
            config.common.default = "wlr";

            wlr = {
              enable = true;
              settings = {
                screencast = {
                  chooser_type = "none";
                  output_name = "DP-2";   # or "HDMI-A-1" / "DP-1"
                };
              };
            };
          };

          systemd.services.kill-obs-shutdown = {
            description = "Kill OBS before shutdown";
            unitConfig = {
              DefaultDependencies = "no";
              Before = "shutdown.target";
              Conflicts = "shutdown.target";
            };
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${pkgs.coreutils}/bin/true";
              ExecStop = pkgs.writeShellScript "stop-obs" ''
                ${pkgs.procps}/bin/pkill -9 obs || true
                rm -rf /home/bb99/.config/obs-studio/.sentinel || true
              '';
              RemainAfterExit = "yes";
              TimeoutStopSec = "5s";
            };
            wantedBy = [ "multi-user.target" ];
          };

          systemd.user.timers.mouse-low-batt = {
            description = "Check mouse battery periodically";
            timerConfig = {
              OnBootSec = "1m";
              OnUnitActiveSec = "1m";
            };
            wantedBy = [ "timers.target" ];
          };

          systemd.user.services.mouse-low-batt = {
            description = "Notify when mouse battery is low";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "/bin/sh -lc 'DEV=/org/freedesktop/UPower/devices/battery_hidpp_battery_0; P=$(upower -i \"$DEV\" | sed -n \"s/^ *percentage:[[:space:]]*\\([0-9]\\+\\)%.*/\\1/p\" | head -n1); [ -n \"$P\" ] || exit 0; if [ \"$P\" -le 5 ]; then notify-send -u critical \"G Pro Wireless\" \"Battery low - $P%\"; fi'";
            };
          };
        }
      ];
    };
  };
}
