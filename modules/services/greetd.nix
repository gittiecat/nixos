{ config, pkgs, lib, ... }:

let
  desktops    = config.services.displayManager.sessionData.desktops;
  xsessions   = "${desktops}/share/xsessions";
  waysessions = "${desktops}/share/wayland-sessions";

  bspwmStartxSession =
    (pkgs.writeTextFile {
      name = "bspwm-startx-session";
      destination = "/share/xsessions/bspwm-startx.desktop";
      text = ''
        [Desktop Entry]
        Version=1.0
        Type=Application
        Name=bspwm (startx)
        Comment=bspwm started via startx
        Exec=${pkgs.xinit}/bin/startx ${pkgs.bspwm}/bin/bspwm
      '';
    }).overrideAttrs (_: {
      passthru.providedSessions = [ "bspwm-startx" ];
    });
in
{
  services.xserver.enable = true;

  # This is the important part: make the session file part of the desktops bundle
  services.displayManager.sessionPackages = [
    bspwmStartxSession
  ];

  services.greetd = {
    enable = true;
    settings.default_session = {
      user = "greeter";
      command =
        "${pkgs.tuigreet}/bin/tuigreet "
        + "--time --remember --remember-session "
        + "--sessions ${waysessions}:${xsessions}";
      # command = "exec start-hyprland";
    };
  };

  environment.systemPackages = with pkgs; [
    tuigreet
  ];
}
