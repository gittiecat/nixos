let
  scripts = import ../../scripts { inherit pkgs; };
in
{
  environment.systemPackages = with pkgs; [
    scripts
  ];
}
