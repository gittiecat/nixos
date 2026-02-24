{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    python314
    python3Packages.pip
    go
  ];
}