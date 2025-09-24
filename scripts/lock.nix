{ pkgs, ... }:

let
  showDesktop = pkgs.callPackage ./show-desktop.nix {};
in
pkgs.writeShellScriptBin "lock" ''
  #!${pkgs.bash}/bin/bash
  set -euo pipefail

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT

  # Disable animations to avoid transition glitches
  ANIMS_ENABLED="$(${pkgs.hyprland}/bin/hyprctl getoption animations:enabled | awk 'NR==1{print $2}')" || true
  ${pkgs.hyprland}/bin/hyprctl -q keyword animations:enabled 0

  # Hide visible windows and waybar
  ${showDesktop}/bin/hypr-hide-visible-windows
  ${pkgs.procps}/bin/pkill -USR1 -f waybar

  # Small settle
  ${pkgs.coreutils}/bin/sleep 0.05

  # Per-output screenshots
  mapfile -t outputs < <(${pkgs.hyprland}/bin/hyprctl -j monitors | ${pkgs.jq}/bin/jq -r '.[].name')
  args=()
  for out in "''${outputs[@]}"; do
    img="$tmpdir/$out.png"
    ${pkgs.grim}/bin/grim -o "$out" "$img"
    args+=( --image "$out:$img" )
  done

  # Start swaylock (tiny fade smooths perceived flicker; set 0 to disable)
  ${pkgs.swaylock-effects}/bin/swaylock \
    --clock \
    --indicator \
    --indicator-radius 120 \
    --indicator-thickness 8 \
    --ring-color a6accd \
    --key-hl-color e06c75 \
    --line-color 00000000 \
    --inside-color 282c3400 \
    --separator-color 00000000 \
    --datestr "%a %e.%m.%Y" \
    --timestr "%H:%M" \
    --font "Fira Mono" \
    --fade-in 0.15 \
    --show-failed-attempts \
    --ignore-empty-password \
    --ring-wrong-color=31748f \
    --text-wrong-color=31748f \
    "''${args[@]}" &

  pkill -f '[dD]iscord'

  # Wait until swaylock layer is mapped
  for i in $(seq 1 50); do
    ${pkgs.coreutils}/bin/sleep 0.02
    ${pkgs.hyprland}/bin/hyprctl -j layers | ${pkgs.jq}/bin/jq -e '
      [.[][].namespace] | flatten | any(. == "swaylock")' >/dev/null 2>&1 && break || true
  done

  # Restore windows and waybar under the lock
  ${showDesktop}/bin/hypr-hide-visible-windows
  ${pkgs.procps}/bin/pkill -USR1 -f waybar

  # Give compositor one frame, then (optionally) re-enable animations
  ${pkgs.coreutils}/bin/sleep 0.05
  if [ "''${ANIMS_ENABLED:-1}" = "1" ]; then
    ${pkgs.hyprland}/bin/hyprctl -q keyword animations:enabled 1
  fi

  # Wait for unlock
  wait

  # Relaunch Discord after unlock; detach robustly
  discord &
''
