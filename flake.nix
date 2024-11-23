{
  description = "Flake migration from configuration.nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { nixpkgs, ... } @ inputs:
		let
			pkgs = import nixpkgs { system = "x86_64-linux"; config.allowUnfree = true; };
		in {
			nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
	
				specialArgs = { 
					inherit inputs;
    	  };

				modules = [

					./configuration.nix
					./modules/vscode.nix # with extensions
					./modules/krisp.nix

					{
						environment.systemPackages = with pkgs; [
							vim
							neovim
							git
							wget
    					google-chrome
    					steam
    					protonplus
    					discord
							kitty
							(waybar.overrideAttrs (oldAttrs: {
								mesonFlags = oldAttrs.mesonFlags ++ [ "-Dexperimental=true"];
							})) # hyprland
							dunst
							libnotify
							wl-clipboard
							swww
							rofi-wayland
							hyprshot
						];

						programs.bash.shellAliases = {
							l = "ls -l";
							ll = "ls -lah";
							rebuild = "sudo nixos-rebuild switch --flake /etc/nixos/.";
							waybar-reload = "pkill waybar && hyprctl dispatch exec waybar";
						};
	
						programs.vim.enable = true;
						programs.steam.enable = true;
						programs.hyprland = {
							enable = true;
							xwayland.enable = true;
						};

						environment.sessionVariables = {
							WLR_NO_HARDWARE_CURSORS = "1";
							NIXOS_OZONE_WL = "1";
							ELECTRON_OZONE_PLATFORM_HINT="wayland";
						};

						xdg.portal.enable = true;
						xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
					}
				];
			};
  	};
}
