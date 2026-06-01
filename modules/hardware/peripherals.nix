{ config, pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    exfatprogs   # mkfs.exfat / fsck.exfat for formatting flash drives
  ];
}