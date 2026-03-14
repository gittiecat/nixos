{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    python314
    python3Packages.pip
    python313Packages.pytest
    go
  ];
}