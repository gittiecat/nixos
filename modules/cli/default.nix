{ config, pkgs, lib, ... }:

let
  scripts = import ../../scripts { inherit pkgs; };
in

{
  environment.systemPackages = with pkgs; [
    scripts #custom scripts
    vim
    git
    wget
    jq
    tree
    mpv
    ffmpeg
    upower
    ripgrep
    unzip
  ];
}
