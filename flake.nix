{
  description = "Flake migration from configuration.nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixpkgs-2505.url = "github:NixOS/nixpkgs/nixos-25.05";
    swww.url = "github:LGFae/swww";
    obs-module.url = "path:./modules/media/obs";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
  };

  outputs = { self, nixpkgs, nixpkgs-2505, nix-vscode-extensions, ... }@inputs:
  let
    system = "x86_64-linux";

    overlay = final: prev: { };

    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      cudaSupport = true;
      overlays = [
        inputs.nix-vscode-extensions.overlays.default  # ← add this
      ];
    }; 

    pkgs2505 = import nixpkgs-2505 {
      inherit system;
      config.allowUnfree = true;
    };    
  in {
    overlays.default = overlay;

    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      specialArgs = { 
        inherit inputs pkgs2505;
        marketplaceExtensions = pkgs.vscode-marketplace;
      };
      modules = [
        {
          nixpkgs.config.allowUnfree = true;
          nixpkgs.hostPlatform = system;
        }
        ./configuration.nix
        {
          environment.systemPackages = with pkgs; [
            (waybar.overrideAttrs (old: { mesonFlags = old.mesonFlags ++ [ "-Dexperimental=true" ]; }))
            wl-clipboard
            wofi
            playerctl
            # xdg-desktop-portal-hyprland
            mangohud
            ferium
            pywal16
            networkmanager
            mako
            swaylock-effects
            tokyonight-gtk-theme
            nwg-look
            pkgs2505.kdePackages.xwaylandvideobridge
            v4l-utils  
            vulkan-tools
            vulkan-validation-layers
            libnotify 
            glib-networking
            cava
            swayidle
            sqlite
            swayimg
            swaybg
            grimblast
            imagemagick
            slurp
            lv2
            psmisc
            libimobiledevice
            ifuse
            usbmuxd
            qt6.qtwayland
            gamescope
          ];

          environment.etc = {
            "xdg/xdph.conf".text = ''
              screencopy {
                allow_token_by_default = true
              }
            '';
          };

          environment.variables = { };

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
