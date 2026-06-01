{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.keyd ];   # `keyd monitor` etc. on PATH

  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];                       # all keyboards
      settings.main = {
        # Tap Super  -> F14 (bound to the wofi launcher in hyprland.conf).
        # (F13/code:191 is already taken by the mic-mute bind, so use F14.)
        # Hold Super -> Meta modifier for $mainMod combos.
        #
        # overloadt2 resolves to the Meta modifier the instant another key is
        # struck (so keyboard combos stay snappy) OR after the 200ms timeout
        # (so Super+LMB window-drag works once held past the timeout, since keyd
        # can't see the mouse). Only a quick tap with no intervening key emits F13.
        # Tune 200 down if Super+drag occasionally trips the menu.
        leftmeta = "overloadt2(meta, f14, 200)";
      };
    };
  };
}
