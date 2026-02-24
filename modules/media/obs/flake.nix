{
  description = "OBS module with its own pinned nixpkgs";

  inputs = {
    nixpkgs-obs.url = "github:NixOS/nixpkgs/ac62194c3917d5f474c1a844b6fd6da2db95077d";
  };

  outputs = { self, nixpkgs-obs, ... }:
  let
    system = "x86_64-linux";
    pkgsObs = import nixpkgs-obs {
      inherit system;
      config.allowUnfree = true;
    };
  in
  {
    nixosModules.default = { ... }: {
      programs.obs-studio = {
        enable = true;
        package = pkgsObs.obs-studio.override { cudaSupport = true; };
        plugins = with pkgsObs.obs-studio-plugins; [ wlrobs ];
      };
    };
  };
}