{ pkgs, ... }:

pkgs.writeShellScriptBin "lock" ''

  # Run swaylock-effects and wait for unlock
  ${pkgs.swaylock-effects}/bin/swaylock \
    --image /home/bb99/Downloads/maurice-sahl-hSHfXSHLlN4-unsplash.jpg
    --screenshots \
    --clock \
    --indicator \
    --indicator-radius 120 \
    --indicator-thickness 8 \
    --effect-pixelate 75 \
    --effect-vignette 0.5:0.5 \
    --effect-greyscale \
    --ring-color a6accd \
    --key-hl-color e06c75 \
    --line-color 00000000 \
    --inside-color 282c3400 \
    --separator-color 00000000 \
    --datestr "%a %e.%m.%Y" --timestr "%H:%M" \
    --font "Fira Mono"

  # # Reconnect internet after unlock
  # ${pkgs.networkmanager}/bin/nmcli networking on
''
