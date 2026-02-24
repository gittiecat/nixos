{ config, pkgs, pkgs2505, lib, ... }:

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
    pkgs2505.gimp
  ];
}
