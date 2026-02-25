{ config, pkgs, lib, ... }:

let
  cfg = config.desktop.bspwm;
in
{
  options.desktop.bspwm.enable = lib.mkEnableOption "bspwm (X11) desktop session";

  config = lib.mkIf cfg.enable {
    # bspwm is X11, so xserver must be enabled when you turn it on
    services.xserver.enable = true;

    services.xserver.windowManager.bspwm = {
      enable = true;
      # configFile = "${./configs/x11/bspwm/bspwmrc}";

      sxhkd = {
        package = pkgs.sxhkd;
        # configFile = "${./configs/x11/sxhkd/sxhkdrc}";
      };
    };

    # Optional quality-of-life X11 tools
    environment.systemPackages = with pkgs; [
      bspwm
      sxhkd
      xrandr
      xsetroot
      xprop
    ];
  };
}