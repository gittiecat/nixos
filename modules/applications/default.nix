{ config, pkgs, pkgs2505, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    google-chrome
    kitty
    prismlauncher
    easyeffects
    telegram-desktop
    audacity
    vencord #discord
    vesktop
    # wireshark
    pkgs2505.gimp
    shotcut
  ];

  systemd.user.services.easyeffects = {
    description = "EasyEffects audio effects (headless background service)";
    after = [ "pipewire.service" "wireplumber.service" ];
    wants = [ "pipewire.service" "wireplumber.service" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.easyeffects}/bin/easyeffects --service-mode";
      Restart = "always";
      RestartSec = 3;
    };
  };
}
