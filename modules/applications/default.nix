{ config, pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    google-chrome
    steam
    kitty
    prismlauncher
    easyeffects
    telegram-desktop
    audacity
    #basically discord
    vencord
    vesktop
    #--
    wireshark
  ];
}
