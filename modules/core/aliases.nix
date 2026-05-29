{ ... }:

{
  programs.bash.shellAliases = {
    l = "ls -l";
    ll = "ls -lah";
    rebuild = "sudo nixos-rebuild switch --flake /etc/nixos/.";
    rebuild-lock = "sudo nixos-rebuild switch --flake /etc/nixos/. --no-update-lock-file";
    waybar-reload = "pkill waybar && hyprctl dispatch exec waybar";
    open = "swayimg";
    clip = "wl-copy";
    play = "mpv --no-config --vo=gpu-next --gpu-api=vulkan --fullscreen --hwdec=no --";
  };
}
