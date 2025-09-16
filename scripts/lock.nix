{ pkgs, ... }:

let
  showDesktop = pkgs.callPackage ./show-desktop.nix {};
in

pkgs.writeShellScriptBin "lock" ''
  #!${pkgs.bash}/bin/bash
  set -euo pipefail

  tmpdir="$(mktemp -d)"
  cleanup() { rm -rf "$tmpdir"; }
  trap cleanup EXIT

  "${showDesktop}/bin/hypr-hide-visible-windows"

  # Enumerate outputs (Hyprland first, Sway fallback)
  if command -v ${pkgs.hyprland}/bin/hyprctl >/dev/null 2>&1; then
    mapfile -t outputs < <(${pkgs.hyprland}/bin/hyprctl -j monitors | ${pkgs.jq}/bin/jq -r '.[].name')
  else
    mapfile -t outputs < <(${pkgs.sway}/bin/swaymsg -r -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.active==true) | .name')
  fi

  args=()
  for out in "''${outputs[@]}"; do
    img="$tmpdir/$out.png"
    ${pkgs.grim}/bin/grim -o "$out" "$img"
    args+=( --image "$out:$img" )
  done

  # Run swaylock-effects with per-output images and effects
  exec ${pkgs.swaylock-effects}/bin/swaylock \
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
    "''${args[@]}"
''