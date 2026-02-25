{ ... }:

{
  services.greetd = {
    enable = true;
    settings = rec {
      initial_session = {
        command = "start-hyprland";
        user = "bb99";
      };
      default_session = initial_session;
    };
  };
}