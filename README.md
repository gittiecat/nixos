/etc/nixos/
├── flake.nix
├── configuration.nix
├── hardware-configuration.nix
├── modules/
│   ├── core/
│   │   ├── boot.nix
│   │   ├── networking.nix
│   │   ├── locale.nix
│   │   ├── users.nix
│   │   └── system.nix
│   ├── hardware/
│   │   ├── nvidia.nix
│   │   ├── audio.nix
│   │   └── peripherals.nix
│   ├── desktop/
│   │   ├── wayland-common.nix      # Shared Wayland: portals, variables, etc.
│   │   ├── hyprland/
│   │   │   └── default.nix         # hyprland.enable, xwayland, config location
│   │   ├── bspwm/
│   │   │   └── default.nix         # bspwm config (future)
│   │   └── sway/
│   │       └── default.nix         # sway config
│   ├── services/
│   │   ├── systemd-daemons.nix     # All systemd user/system services
│   │   ├── greetd.nix              # Login manager
│   │   └── common.nix              # UPower, polkit, etc.
│   ├── development/
│   │   ├── vscode.nix              # Already exists
│   │   └── languages.nix           # Python, Go, etc.
│   ├── gaming/
│   │   ├── default.nix             # Steam, GameMode, Gamescope
│   │   └── proton.nix              # Proton, wine, proton-ge-bin
│   ├── media/
│   │   ├── obs.nix                 # OBS with CUDA, plugins, services
│   │   ├── audio.nix               # Audacity, EasyEffects, etc.
│   │   └── image.nix               # GIMP, ImageMagick, etc.
│   ├── applications/
│   │   ├── default.nix             # Common apps (Chrome, Discord, etc.)
│   │   ├── browsers.nix            # Firefox, Chromium variants
│   │   └── terminals.nix           # Kitty, etc.
│   ├── cli-tools/
│   │   ├── default.nix             # jq, tree, ffmpeg, etc.
│   │   └── utilities.nix           # Specific tool configs
│   └── fonts.nix                   # All fonts config
├── hosts/
│   └── nixos/                      # Host-specific overrides
│       └── configuration.nix       # Imports core modules + hardware
├── scripts/
│   ├── lock
│   ├── play-last
│   ├── show-desktop
│   └── default.nix                 # Script building logic
├── configs/
│   ├── wayland/
│   │   ├── hyprland.conf           # **Keep here for future reference**
│   │   ├── bspwm-config.sh         # Future bspwm config
│   │   └── waybar-config.json      # If using waybar
│   └── dotfiles/                   # Other dotfile configs
└── overlays/
    └── default.nix                 # Custom overlays
