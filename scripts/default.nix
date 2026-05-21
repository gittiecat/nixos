{ pkgs, lib }:

let
  scriptsDir = builtins.readDir ./.;

  scriptNames = lib.filterAttrs (name: type:
    type == "regular" && name != "default.nix"
  ) scriptsDir;

  mkScript = name: pkgs.writeShellScriptBin name (builtins.readFile ./${name});
in

pkgs.symlinkJoin {
  name = "os-scripts";
  paths = map mkScript (builtins.attrNames scriptNames);
}