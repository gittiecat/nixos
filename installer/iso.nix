# Custom installer ISO: the upstream minimal installation CD plus the
# nixos-bootstrap script and the tools it needs. Built via
# `nix build .#nixosConfigurations.installer.config.system.build.isoImage`.
# See docs/002-installer-iso.md.
{ pkgs, lib, ... }:

let
  nixos-bootstrap = pkgs.writeShellScriptBin "nixos-bootstrap"
    (builtins.readFile ./bootstrap.sh);
in
{
  # nixos-bootstrap clones a flake and runs disko via `nix run`.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # This config still builds some packages from source (CUDA-enabled packages,
  # waybar/gamescope overrides), which is memory-hungry. The live ISO's store is
  # RAM-backed, so a big build can OOM. Compressed RAM swap gives the build room
  # to breathe on low-RAM machines and in VMs.
  zramSwap.enable = true;

  # disko.nix needs to exist on the live system before the repo is cloned, so
  # ship it at a stable path the script reads.
  environment.etc."nixos-installer/disko.nix".source = ./disko.nix;

  environment.systemPackages = [
    nixos-bootstrap
    pkgs.git
  ];

  # Point people at the script on the login screen.
  services.getty.helpLine = lib.mkAfter ''

    To install this NixOS config, run:  sudo nixos-bootstrap
  '';
}
