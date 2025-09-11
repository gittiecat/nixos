# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    useOSProber = true;
    efiSupport = true;
    configurationLimit = 15;
  };

  boot.kernelParams = [ "nvidia-drm.modeset=1" "nvidia-drm.fbdev=1" ];
  boot.supportedFilesystems = [ "ntfs" ];

  # Nvidia
  hardware.graphics = {
    enable = true;
  };

  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.beta;
  };

  environment = {
    systemPackages = [
      inputs.swww.packages.${pkgs.system}.swww
    ];
  };

  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1
  '';

  # Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/London";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
    LC_MEASUREMENT = "en_GB.UTF-8";
    LC_MONETARY = "en_GB.UTF-8";
    LC_NAME = "en_GB.UTF-8";
    LC_NUMERIC = "en_GB.UTF-8";
    LC_PAPER = "en_GB.UTF-8";
    LC_TELEPHONE = "en_GB.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;

  # Enable the Plasma6 Desktop Environment.
  # services.displayManager = {
  #   sddm.enable = true;
  #   sddm.wayland.enable = true;
  # };
  # services.desktopManager.plasma6.enable = true;
  
  # Configure keymap in X11
  # services.xserver.xkb = {
  #   layout = "gb";
  #   variant = "extd";
  # };

  # Configure console keymap
  console.keyMap = "us";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  security.polkit.enable = true;

  security.sudo.extraRules = [{
    users = [ "bb99" ];
    commands = [{
      command = "${pkgs.networkmanager}/bin/nmcli";
      options = [ "NOPASSWD" ];
    }];
  }];

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    audio.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;

    configPackages = [
      (pkgs.writeTextDir "share/pipewire/pipewire.conf.d/combine-scarlett-solo.conf" ''
        context.modules = [
          {
            name = libpipewire-module-combine-stream
            args = {
              node.name = "scarlett_solo_combined"
              node.description = "Combined Source"
              combine.mode = "source"
              combine.props = {
                audio.position = [ FL FR ]
              }
              stream.dont-remix = true
              streamrules = [
                {
                  matches = [
                    {
                      media.class = "Audio/Source"
                      node.name = "alsa_input.usb-Focusrite_Scarlett_Solo_USB_Y7CJRNG2A6D0E8-00.HiFi__Mic2__source"
                    }
                  ]
                  actions = {
                    create-stream = {
                      combine.audio.position = [ FL FR ]
                      audio.position = [ FL FR ]
                    }
                  }
                }
                {
                  matches = [
                    {
                      media.class = "Audio/Source"
                      node.name = "alsa_input.usb-Focusrite_Scarlett_Solo_USB_Y7CJRNG2A6D0E8-00.HiFi__Mic1__source"
                    }
                  ]
                  actions = {
                    create-stream = {
                      combine.audio.position = [ FL FR ]
                      audio.position = [ FL FR ]
                    }
                  }
                }
              ]
            }
          }
        ]
      '')
    ];
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.bb99 = {
    isNormalUser = true;
    description = "Michael Ivoylov";
    extraGroups = [ "networkmanager" "wheel" "gamemode" ];
    packages = with pkgs; [
    #  thunderbird
    ];
  };

  users.users.jed = {
    isNormalUser = true;
    description = "Jed Kim";
    extraGroups = [ "networkmanager" "wheel" "gamemode" ];
    packages = with pkgs; [
    #  thunderbird
    ];
  };



  # Enable automatic login for the user.
  services.greetd = {
    enable = true;
    settings = rec {
      initial_session = {
        command = "Hyprland";
        user = "bb99";
      };
      default_session = initial_session;
    };
  };
  
  # services.displayManager = {
  #   autoLogin.enable = true;
  #   autoLogin.user = "bb99";
  # };

  # Install firefox.
  programs.firefox.enable = true;

	# Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?

}
