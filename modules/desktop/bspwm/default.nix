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
      # configFile = null;

      sxhkd = {
        package = pkgs.sxhkd;
        # configFile = null;
      };
    };

    # Optional quality-of-life X11 tools
    environment.systemPackages = with pkgs; [
      bspwm
      sxhkd
      xorg.xrandr
      xorg.xsetroot
      xorg.xprop
    ];
  };
}