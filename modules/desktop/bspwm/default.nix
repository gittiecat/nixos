{ config, pkgs, ... }:

{
  # X11 stack (bspwm is an X11 WM)
  services.xserver = {
    enable = true;

    # If you want a DM later (lightdm/sddm), this is where it lives.
    # displayManager.defaultSession = "none+bspwm";

    windowManager.bspwm = {
      enable = true;

      # Optional: point to a Nix store file for bspwmrc (or leave null to use ~/.config/bspwm/bspwmrc)
      # configFile = /abs/path/to/bspwmrc;

      # sxhkd is wired up by the bspwm module; you can provide a configFile similarly.
      sxhkd.enable = true;
      # sxhkd.configFile = /abs/path/to/sxhkdrc;
      # sxhkd.package = pkgs.sxhkd;
    };
  };

  # Handy X11 bits you’ll likely want while moving from Hyprland
  environment.systemPackages = with pkgs; [
    xorg.xrandr
    xorg.xsetroot
    xorg.xprop
  ];
}
