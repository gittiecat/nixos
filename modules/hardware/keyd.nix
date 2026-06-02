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
        # Plain overload activates the Meta layer the instant Super is held and
        # only emits F14 if Super is released with no other key pressed during
        # the hold. This is robust to release ordering, so fast Super+digit
        # workspace chords never trip the menu (the prior overloadt2 timeout
        # variant raced: lifting Super before the digit, within the timeout,
        # resolved as a tap and dumped the digit into the menu).
        #
        # Trade-off: keyd can't see the mouse, so a Super+LMB/RMB drag with no
        # keyboard key pressed emits F14 (menu) on release. Acceptable here since
        # Super+drag window move/resize is used rarely.
        leftmeta = "overload(meta, f14)";
      };
    };
  };
}
