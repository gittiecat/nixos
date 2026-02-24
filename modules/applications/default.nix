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
    vencord #discord
    vesktop
    wireshark
    shotcut
    gimp
  ];
}
