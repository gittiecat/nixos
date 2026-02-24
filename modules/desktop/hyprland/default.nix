{ config, pkgs, ... }:

{

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
  ];
}
