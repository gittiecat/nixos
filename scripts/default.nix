{ pkgs }:

let
  mkScript = name: pkgs.writeShellScriptBin name (builtins.readFile ./${name});
in

pkgs.symlinkJoin {
  name = "os-scripts";
  paths = [
    (mkScript "lock")
    (mkScript "play-last")
    (mkScript "show-desktop")
    (mkScript "enable-side-monitor")
  ];
}