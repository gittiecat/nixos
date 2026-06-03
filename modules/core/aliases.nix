{ ... }:

{
  programs.bash.shellAliases = {
    l = "ls -l";
    ll = "ls -lah";
    # hardware-configuration.nix is gitignored (per-machine), and the flake
    # ignores untracked files — so intent-to-add it first or the build can't see
    # it. -N keeps it staged for evaluation without ever committing the UUIDs.
    rebuild = "git -C /etc/nixos add -fN hardware-configuration.nix; sudo nixos-rebuild switch --flake /etc/nixos/.";
    rebuild-lock = "git -C /etc/nixos add -fN hardware-configuration.nix; sudo nixos-rebuild switch --flake /etc/nixos/. --no-update-lock-file";
    # Build the custom installer ISO -> ./result/iso/*.iso (see docs/002).
    build-iso = "nix build /etc/nixos#nixosConfigurations.installer.config.system.build.isoImage";
    waybar-reload = "pkill waybar && hyprctl dispatch exec waybar";
    open = "swayimg";
    clip = "wl-copy";
    play = "mpv --no-config --vo=gpu-next --gpu-api=vulkan --fullscreen --hwdec=no --";
  };
}
