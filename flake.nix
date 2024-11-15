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

					{
						environment.systemPackages = with pkgs; [
							vim
							git
							vscode
							wget
    					google-chrome
    					steam
    					protonplus
    					discord
						];
	
						programs.vim.enable = true;
						programs.steam.enable = true;
					}
				];
			};
  	};
}
