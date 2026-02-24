{ ... }:

{
  programs.bash.shellAliases = {
    l = "ls -l";
    ll = "ls -lah";
    rebuild = "sudo nixos-rebuild switch --flake /etc/nixos/.";
    rebuild-fallback = "sudo nixos-rebuild switch --flake /etc/nixos/. --option fallback false";
    waybar-reload = "pkill waybar && hyprctl dispatch exec waybar";
    matrix = "bash <(curl -s https://raw.githubusercontent.com/wick3dr0se/matrix/main/matrix)";
    open = "swayimg";
    clip = "wl-copy";
    play = "mpv --no-config --vo=gpu-next --gpu-api=vulkan --fullscreen --hwdec=no --";
  };
}