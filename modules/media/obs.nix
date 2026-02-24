{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    python314
    python3Packages.pip
    go
    # Add any other languages you need
  ];
}