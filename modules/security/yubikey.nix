{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    keepassxc        # built with YubiKey + browser-integration support by default
    yubikey-manager  # `ykman` - inspect the key, manage FIDO2 PIN/fingerprints
  ];

  # udev rules so a non-root user can talk to the YubiKey over USB (FIDO2/WebAuthn).
  services.udev.packages = [ pkgs.yubikey-personalization ];

  # Force-install the official KeePassXC-Browser extension into Chrome so the
  # native-messaging autofill works out of the box. Remove this block to install
  # the extension manually instead. (Applies to every Chrome user on the host.)
  environment.etc."opt/chrome/policies/managed/keepassxc.json".text = builtins.toJSON {
    ExtensionInstallForcelist = [
      "oboonakemofpalcgghocfoadofidjkkk;https://clients2.google.com/service/update2/crx"
    ];
  };
}
