{ config, pkgs, lib, ... }:

let
  scripts = import ../../scripts { inherit pkgs lib; };
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
    slurp
  ];
}
