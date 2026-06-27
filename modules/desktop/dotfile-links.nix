# Declaratively link the tracked dotfiles in configs/ into the user's home,
# replacing the manual `ln -s` step that used to be documented in the README.
# Editing either the repo path or the ~/.config path touches the same file.
#
# These use tmpfiles "L+" (create-or-replace symlink): on every rebuild the link
# is recreated, clobbering any real file/dir that snuck in at the target. The "d"
# rules ensure the leaf parent dirs exist and are owned by the user (tmpfiles
# would otherwise create them as root).
{ ... }:

let
  home = "/home/bb99";
  cfg = "/etc/nixos/configs";
in
{
  systemd.tmpfiles.rules = [
    "d ${home}/.config 0755 bb99 users - -"

    # Wayland / Hyprland
    "d ${home}/.config/hypr 0755 bb99 users - -"
    "L+ ${home}/.config/hypr/hyprland.conf - - - - ${cfg}/wayland/hyprland/hyprland.conf"
    "L+ ${home}/.config/waybar - - - - ${cfg}/wayland/waybar"
    "L+ ${home}/.config/wofi - - - - ${cfg}/wayland/wofi"

    # Terminal
    "d ${home}/.config/kitty 0755 bb99 users - -"
    "L+ ${home}/.config/kitty/kitty.conf - - - - ${cfg}/kitty/kitty.conf"

    # X11 / bspwm
    "d ${home}/.config/bspwm 0755 bb99 users - -"
    "L+ ${home}/.config/bspwm/bspwmrc - - - - ${cfg}/x11/bspwm/bspwmrc"
    "d ${home}/.config/sxhkd 0755 bb99 users - -"
    "L+ ${home}/.config/sxhkd/sxhkdrc - - - - ${cfg}/x11/sxhkd/sxhkdrc"
  ];
}
