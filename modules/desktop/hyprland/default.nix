{ config, pkgs, lib, ... }:

let
  cfg = config.desktop.hyprland;
in
{
  options.desktop.hyprland.enable = lib.mkEnableOption "Hyprland (Wayland) desktop session";

  config = lib.mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
      portalPackage = pkgs.xdg-desktop-portal-hyprland;
    };

    environment.systemPackages = with pkgs; [
      hyprpaper
      hyprshot
      hyprpicker
      hyprprop
      catppuccin-cursors.mochaLight
    ];
  };
}
