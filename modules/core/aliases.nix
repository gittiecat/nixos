{ ... }:

{
  programs.bash.shellAliases = {
    l = "ls -l";
    ll = "ls -lah";
    rebuild = "git -C /etc/nixos add -fN hardware-configuration.nix; sudo nixos-rebuild switch --flake /etc/nixos/.";
    rebuild-lock = "git -C /etc/nixos add -fN hardware-configuration.nix; sudo nixos-rebuild switch --flake /etc/nixos/. --no-update-lock-file";
    build-iso = "nix build /etc/nixos#nixosConfigurations.installer.config.system.build.isoImage";
    waybar-reload = "pkill waybar && hyprctl dispatch exec waybar";
    open = "swayimg";
    clip = "wl-copy";
    play = "mpv --no-config --vo=gpu-next --gpu-api=vulkan --fullscreen --hwdec=no --";
    collect-garbage = "sudo nix-collect-garbage -d";
  };
}
