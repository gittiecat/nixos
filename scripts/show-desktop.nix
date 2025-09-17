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
      CMDS=""
      while IFS= read -r line; do
        addr=$(echo "$line" | jq -r '.address')
        ws=$(echo "$line" | jq -r '.workspace')
        x=$(echo "$line" | jq -r '.at')
        y=$(echo "$line" | jq -r '.at[18]')
        w=$(echo "$line" | jq -r '.size')
        h=$(echo "$line" | jq -r '.size[18]')
        floating=$(echo "$line" | jq -r '.floating')
        
        # Move to workspace first
        CMDS="''${CMDS:+$CMDS;}dispatch movetoworkspacesilent name:$ws,address:$addr"
        
        # Restore position and size for tiled windows (floating windows keep position automatically)
        if [ "$floating" = "false" ]; then
          CMDS="''${CMDS};dispatch movewindowpixel exact $x $y,address:$addr"
          CMDS="''${CMDS};dispatch resizewindowpixel exact $w $h,address:$addr"
        fi
      done < <(jq -c '.[]' "$STATE_FILE")
      
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
      # Get full client info including position and size
      clients=$(hyprctl clients -j | jq -c --arg WS "''${ws}" '.[] | select(.workspace.name == $WS)')
      [ -n "$clients" ] || continue

      while IFS= read -r client; do
        addr=$(echo "$client" | jq -r '.address')
        [ -n "$addr" ] || continue
        
        # Save complete window state
        echo "$client" | jq --arg ws "$ws" '{address, workspace: $ws, at, size, floating}' >> "$TMP_JSON"
        CMDS="''${CMDS:+$CMDS;}"$(printf 'dispatch movetoworkspacesilent special:%s,address:%s' "$SPEC_NAME" "$addr")
      done <<< "$clients"
    done

    if [ -z "$CMDS" ]; then
      rm -f "$TMP_JSON"
      exit 0
    fi

    jq -s '.' "$TMP_JSON" > "$STATE_FILE"
    rm -f "$TMP_JSON"

    hyprctl --batch "$CMDS"
  '';
}
