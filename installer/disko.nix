# Declarative disk layout used by the installer's bootstrap script (via disko).
# Mirrors this machine's layout: a GPT disk with a 1 GB EFI System Partition and
# the rest a single btrfs filesystem with an "@" subvolume mounted at / plus an
# "@swap" subvolume holding a swapfile.
#
# This is only consumed at install time (disko partitions/formats/mounts). The
# installed system's fileSystems come from the regenerated
# hardware-configuration.nix, NOT from this file — so it is not imported into the
# running system. See docs/002-installer-iso.md.
#
# The target device is passed in by the script: `disko --argstr device /dev/...`.
{ device ? "/dev/nvme0n1", ... }:
{
  disko.devices.disk.main = {
    inherit device;
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
            subvolumes = {
              "@" = {
                mountpoint = "/";
                mountOptions = [ "subvol=@" "compress=zstd" "noatime" ];
              };
              "@swap" = {
                mountpoint = "/swap";
                # Tune to taste; btrfs swapfile is created NOCOW automatically.
                swap.swapfile.size = "8G";
              };
            };
          };
        };
      };
    };
  };
}
