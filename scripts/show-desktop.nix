{ pkgs }:

pkgs.writeShellApplication {
  name = "hypr-hide-visible-windows";
  runtimeInputs = [ pkgs.jq pkgs.hyprland ];
  text = ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    SPEC_NAME="hideall"
    STATE_FILE="''${XDG_RUNTIME_DIR:-/tmp}/hypr-''${SPEC_NAME}-state.json"

    # If a state file exists, restore and exit
    if [ -s "$STATE_FILE" ]; then
      CMDS=$(jq -r '.[] | "dispatch movetoworkspacesilent name:\(.workspace),address:\(.address)"' "$STATE_FILE" | paste -sd ';' -)
      if [ -n "$CMDS" ]; then
        hyprctl --batch "$CMDS"
      fi
      rm -f "$STATE_FILE"
      exit 0
    fi

    # Unique list of all monitors' visible workspaces
    mapfile -t WORKSPACES < <(hyprctl monitors -j | jq -r '.[].activeWorkspace.name' | awk '!seen[$0]++')

    TMP_JSON="$(mktemp)"
    : > "$TMP_JSON"

    CMDS=""
    for ws in "''${WORKSPACES[@]}"; do
      addrs=$(hyprctl clients -j | jq -r --arg WS "''${ws}" '.[] | select(.workspace.name == $WS) | .address')
      [ -n "''${addrs}" ] || continue

      while IFS= read -r addr; do
        [ -n "$addr" ] || continue
        printf '{"address":"%s","workspace":"%s"}\n' "$addr" "$ws" >> "$TMP_JSON"
        CMDS="''${CMDS:+$CMDS;}"$(printf 'dispatch movetoworkspacesilent special:%s,address:%s' "$SPEC_NAME" "$addr")
      done <<< "$addrs"
    done

    if [ -z "$CMDS" ]; then
      rm -f "$TMP_JSON"
      exit 0
    fi

    jq -s '.' "$TMP_JSON" > "$STATE_FILE"
    rm -f "$TMP_JSON"

    hyprctl --batch "$CMDS"

    # Optional: ensure the special workspace is not shown
    # hyprctl dispatch togglespecialworkspace "''${SPEC_NAME}" || true
  '';
}
