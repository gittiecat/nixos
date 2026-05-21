{ config, pkgs, lib, ... }:

{
  hardware = {
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true;
      powerManagement.finegrained = false;
      open = false;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.latest;
    };

    graphics = {
      enable = true;
      enable32Bit = true;
    };
  };

  services.xserver.videoDrivers = [ "nvidia" ];

	environment.etc."X11/xorg.conf.d/10-nvidia-only.conf".text = ''
		Section "Device"
			Identifier "NvidiaGPU"
			Driver		 "nvidia"
		EndSection
	'';

  environment.etc."X11/xorg.conf.d/05-modulepath.conf".text = ''
    Section "Files"
      ModulePath "/run/current-system/sw/lib/xorg/modules"
      ModulePath "/nix/store/a86d34l78hd1cm0dg3fw09c0qqr245dw-xorg-server-21.1.21/lib/xorg/modules"
    EndSection
  '';

  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    "nvidia.NVreg_RegistryDwords=RMUseSwI2c=0x01"
    "vsyscall=emulate"
    "modprobe.blacklist=nouveau"
    "rd.driver.blacklist=nouveau"
    "module_blacklist=nouveau"
    "nvidia_modeset.enable_overlay_layers=N"
  ];
  boot.blacklistedKernelModules = [ "nouveau" "nvidiafb" ];

}
