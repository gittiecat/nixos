{ config, pkgs, lib, ... }:

let
  cfg = config.desktop.bspwm;
in
{
  options.desktop.bspwm.enable = lib.mkEnableOption "bspwm (X11) desktop session";

  config = lib.mkIf cfg.enable {
    
    services.xserver = {
      enable = true;

      windowManager.bspwm = {
        enable = true;

        sxhkd = {
          package = pkgs.sxhkd;
        };
      };

      displayManager.lightdm.enable = lib.mkForce false;
    };

    services.libinput.enable = true;

    services.displayManager = {
      gdm.enable     = lib.mkForce false;
      sddm.enable    = lib.mkForce false;
    };

    # Optional quality-of-life X11 tools
    environment.systemPackages = with pkgs; [
      bspwm
      sxhkd
      xrandr
      xsetroot
      xprop
			xinit
      xf86inputlibinput
    ];
  };
}
