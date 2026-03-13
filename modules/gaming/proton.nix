{ config, pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    protonplus
    protonup-qt
  ];
}