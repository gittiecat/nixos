{ config, pkgs, lib, ... }:

# Force which Overwatch 2 region you play on, WITHOUT disrupting anything else.
#
# Overwatch 2 game servers run on Google Cloud with well-known IPv4 ranges per
# region, and the matchmaker routes you to the lowest-latency *reachable*
# server. There is no in-game setting, so the trick is to firewall-block every
# region you DON'T want — leaving your target region as the only viable option.
#
# The catch: the upstream IP lists cover whole Google Cloud regions (big /14
# blocks), so a machine-wide UDP block also kills other UDP services hosted on
# GCP — notably Discord voice. To avoid that, this scopes the block to the
# *game's cgroup only*: the game runs inside a transient systemd scope under
# `ow-region.slice`, and the nftables rule drops UDP only from that cgroup.
# Discord and everything else are unaffected.
#
# Setup (Steam / Proton): set the Overwatch Launch Options to
#     ow-region play na-west %command%
# (swap na-west for any region key). That's it — region is forced while the
# game runs and released automatically when it exits.
#
# Manual usage:
#   ow-region play <region> -- <command...>   # run <command> region-locked
#   ow-region status                          # is a session active? which region?
#   ow-region off                             # emergency teardown (normally automatic)
#   ow-region list                            # list valid region keys
#
# Unofficial; use at your own discretion. Forcing a distant region means higher
# ping by design.

let
  rawBase = "https://raw.githubusercontent.com/foryVERX/Overwatch-Server-Selector/main/ip_lists";

  # region key -> upstream filename (one IP list per region).
  regions = {
    na-west    = "Ip_ranges_NA_West.txt";
    na-east    = "Ip_ranges_NA_East.txt";
    na-central = "Ip_ranges_NA_central.txt";
    eu         = "Ip_ranges_EU.txt";
    me         = "Ip_ranges_ME.txt";
    au         = "Ip_ranges_Australia.txt";
    japan      = "Ip_ranges_AS_Japan.txt";
    korea      = "Ip_ranges_AS_Korea.txt";
    singapore  = "Ip_ranges_AS_Singapore.txt";
    taiwan     = "Ip_ranges_AS_Taiwan.txt";
    brazil     = "Ip_ranges_Brazil.txt";
  };

  # Bash associative-array literal: [na-west]="Ip_ranges_NA_West.txt" ...
  regionMapEntries = lib.concatStringsSep " "
    (lib.mapAttrsToList (k: v: "[${k}]=\"${v}\"") regions);

  ow-region = pkgs.writeShellApplication {
    name = "ow-region";
    runtimeInputs = with pkgs; [ curl nftables gnugrep coreutils systemd getent ];
    text = ''
      declare -A REGIONS=( ${regionMapEntries} )
      RAW_BASE="${rawBase}"
      # Resolve HOME from the passwd db, not the environment: Steam launches with
      # a different/overridden HOME & XDG_CONFIG_HOME, so env-derived paths would
      # not match what was written from a normal terminal.
      OW_HOME="$(getent passwd "$(id -u)" | cut -d: -f6)"
      : "''${OW_HOME:=''${HOME:-/tmp}}"
      # User-owned state file (no privilege needed).
      STATE_FILE="''${XDG_RUNTIME_DIR:-/tmp}/ow-region.active"
      # Persistent extra allow-list (e.g. lobby/login servers to never block).
      WHITELIST="$OW_HOME/.config/ow-region/allow.txt"
      # Per-server drop metrics, written on demand and at teardown.
      METRICS_DIR="/tmp/ow-region"
      METRICS_FILE="$METRICS_DIR/metrics.txt"
      HOLDER="ow-region-holder.service"

      usage() {
        echo "usage: ow-region play <region> -- <command...>" >&2
        echo "       ow-region status|off|list" >&2
        echo "       ow-region allow <ip|cidr>...   (whitelist, e.g. lobby servers)" >&2
        echo "       ow-region allowlist            (show whitelist)" >&2
        echo "       ow-region metrics              (per-server drop counts -> $METRICS_FILE)" >&2
        echo "regions: ''${!REGIONS[*]}" >&2
      }

      # Pull valid CIDR / dash-range tokens out of arbitrary text.
      extract_ranges() {
        grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+|-[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)?' "$@"
      }

      # nft needs root, but a Steam launch runs under no_new_privs, so sudo
      # can't escalate here. Dispatch via the systemd user manager, which spawns
      # the command in a fresh unit WITHOUT no_new_privs — there sudo works. This
      # path is equally fine when invoked from a normal terminal.
      nft_root() {
        systemd-run --user --pipe --wait --collect --quiet \
          -- sudo ${pkgs.nftables}/bin/nft "$@"
      }

      # Snapshot per-destination drop counts from the dynamic set into the
      # metrics file. Returns non-zero (and writes nothing) if no session/table.
      dump_metrics() {
        local raw
        raw="$(nft_root list set inet ow_region dropstats 2>/dev/null)" || return 1
        mkdir -p "$METRICS_DIR"
        {
          echo "# ow-region drop metrics — $(date -Is) — region=''${region:-?}"
          echo "# <server-ip> <dropped-packets>"
          printf '%s\n' "$raw" \
            | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ counter packets [0-9]+' \
            | while read -r ip _ _ pkts; do echo "$ip $pkts"; done \
            | sort -k2 -nr
        } > "$METRICS_FILE"
      }

      # Tear down the scoped block and the cgroup holder. Safe to call twice.
      cleanup() {
        dump_metrics || true
        nft_root delete table inet ow_region 2>/dev/null || true
        systemctl --user stop "$HOLDER" 2>/dev/null || true
        systemctl --user reset-failed "$HOLDER" 2>/dev/null || true
        rm -f "$STATE_FILE"
        [ -n "''${TMP:-}" ] && rm -rf "$TMP"
      }

      cmd="''${1:-}"
      case "$cmd" in
        list)
          for r in "''${!REGIONS[@]}"; do echo "$r"; done | sort
          ;;

        allow)
          shift
          if [ "$#" -eq 0 ]; then
            echo "usage: ow-region allow <ip|cidr>..." >&2; exit 1
          fi
          mkdir -p "$(dirname "$WHITELIST")"
          for t in "$@"; do printf '%s\n' "$t"; done | extract_ranges >> "$WHITELIST"
          sort -u -o "$WHITELIST" "$WHITELIST"
          echo "ow-region: whitelist is now:"; cat "$WHITELIST"
          echo "(takes effect on the next 'ow-region play')"
          ;;

        allowlist)
          if [ -s "$WHITELIST" ]; then cat "$WHITELIST"; else echo "(whitelist empty)"; fi
          ;;

        metrics)
          if dump_metrics; then
            echo "ow-region: per-server drop counts -> $METRICS_FILE"
            cat "$METRICS_FILE"
          else
            echo "ow-region: no active session — no drop counters to read" >&2
            exit 1
          fi
          ;;

        status)
          if [ -f "$STATE_FILE" ]; then
            echo "ow-region: ACTIVE — game locked to '$(cat "$STATE_FILE")' (all other regions blocked)"
          else
            echo "ow-region: inactive (no game session locked)"
          fi
          ;;

        off)
          cleanup
          echo "ow-region: off — any region lock removed"
          ;;

        play)
          shift
          region="''${1:-}"
          if [ -z "$region" ]; then usage; exit 1; fi
          shift
          [ "''${1:-}" = "--" ] && shift   # tolerate an explicit separator
          if [ -z "''${REGIONS[$region]:-}" ]; then
            echo "ow-region: unknown region '$region'" >&2; usage; exit 1
          fi
          if [ "$#" -eq 0 ]; then
            echo "ow-region: nothing to run (expected a command after the region)" >&2
            usage; exit 1
          fi

          # Steam/Proton inject the Steam-runtime LD_LIBRARY_PATH/LD_PRELOAD,
          # which override our nixpkgs tools' RPATH (e.g. curl then loads Steam's
          # incompatible libcurl and fails). Stash them for the game, scrub them
          # for our own use, and restore them only around the game launch.
          GAME_LD_LIBRARY_PATH="''${LD_LIBRARY_PATH:-}"
          GAME_LD_PRELOAD="''${LD_PRELOAD:-}"
          unset LD_LIBRARY_PATH LD_PRELOAD

          TMP="$(mktemp -d)"

          # Collect ranges from every region EXCEPT the target.
          elements_file="$TMP/elements"
          : > "$elements_file"
          for r in "''${!REGIONS[@]}"; do
            [ "$r" = "$region" ] && continue
            file="''${REGIONS[$r]}"
            if ! curl -fsSL "$RAW_BASE/$file" -o "$TMP/$file"; then
              echo "ow-region: failed to download list for '$r' ($file) — is the network up?" >&2
              cleanup; exit 1
            fi
            # Extract every CIDR / dash-range token, one per line — robust to
            # lines carrying several ranges or comma/space separators.
            extract_ranges "$TMP/$file" >> "$elements_file"
          done
          sort -u -o "$elements_file" "$elements_file"
          if [ ! -s "$elements_file" ]; then
            echo "ow-region: no IP ranges collected — aborting" >&2; cleanup; exit 1
          fi
          set_body="$(paste -sd, "$elements_file")"

          # Build the allow-list (accepted before the drop): the TARGET region's
          # ranges (so it's never collaterally blocked) PLUS the persistent
          # whitelist (e.g. lobby/login servers that live in a blocked region).
          allow_file="$TMP/allow"
          : > "$allow_file"
          target_list="''${REGIONS[$region]}"
          if ! curl -fsSL "$RAW_BASE/$target_list" -o "$TMP/$target_list"; then
            echo "ow-region: failed to download list for target '$region' ($target_list)" >&2
            cleanup; exit 1
          fi
          extract_ranges "$TMP/$target_list" >> "$allow_file"
          if [ -f "$WHITELIST" ]; then
            wl_n="$(extract_ranges "$WHITELIST" | tee -a "$allow_file" | wc -l)"
            echo "ow-region: whitelist $WHITELIST ($wl_n entries) merged into allow-list"
          else
            echo "ow-region: no whitelist at $WHITELIST"
          fi
          sort -u -o "$allow_file" "$allow_file"
          allow_body="$(paste -sd, "$allow_file")"

          # Materialise the slice cgroup up front (a tiny holder), so the
          # nftables rule can resolve the cgroup path before the game starts.
          systemctl --user reset-failed "$HOLDER" 2>/dev/null || true
          systemd-run --user --quiet --unit="$HOLDER" --slice=ow-region.slice \
            -- sleep infinity
          cg=""
          for _ in $(seq 1 100); do
            cg="$(systemctl --user show -p ControlGroup --value "$HOLDER" 2>/dev/null)"
            [ -n "$cg" ] && [ -d "/sys/fs/cgroup$cg" ] && break
            sleep 0.05
          done
          if [ -z "$cg" ] || [ ! -d "/sys/fs/cgroup$cg" ]; then
            echo "ow-region: could not create the cgroup holder (no systemd --user session?)" >&2
            cleanup; exit 1
          fi
          # The holder lives in .../ow-region.slice/<holder>; we match the slice
          # so every scope launched under it (i.e. the game) is covered.
          slice_cg="$(dirname "$cg")"; slice_cg="''${slice_cg#/}"
          IFS=/ read -ra _parts <<< "$slice_cg"
          level="''${#_parts[@]}"

          ruleset="$TMP/ow-region.nft"
          {
            echo "table inet ow_region {"
            echo "  set blocked4 {"
            echo "    type ipv4_addr"
            echo "    flags interval"
            echo "    auto-merge"
            echo "    elements = { $set_body }"
            echo "  }"
            echo "  set allowed4 {"
            echo "    type ipv4_addr"
            echo "    flags interval"
            echo "    auto-merge"
            echo "    elements = { $allow_body }"
            echo "  }"
            # Dynamic set with a per-element counter: each blocked destination
            # IP gets its own packet/byte counter, giving us per-server drop
            # metrics (see the 'metrics' subcommand / $METRICS_FILE).
            echo "  set dropstats {"
            echo "    type ipv4_addr"
            echo "    size 65535"
            echo "    flags dynamic"
            echo "    counter"
            echo "  }"
            echo "  chain output {"
            echo "    type filter hook output priority 0; policy accept;"
            # Let the target region through first (covers any overlap), then drop
            # everything else to the other regions — ALL protocols, not just UDP,
            # so the matchmaker can't even probe them and is forced onto the
            # target. Scoped to the game's cgroup, so nothing else is affected.
            echo "    socket cgroupv2 level $level \"$slice_cg\" ip daddr @allowed4 accept"
            # Tally per-destination drops into dropstats, then drop.
            echo "    socket cgroupv2 level $level \"$slice_cg\" ip daddr @blocked4 update @dropstats { ip daddr } drop"
            echo "  }"
            echo "}"
          } > "$ruleset"

          # From here on, always tear down on exit (game quit, Ctrl-C, crash).
          trap cleanup EXIT INT TERM

          nft_root delete table inet ow_region 2>/dev/null || true
          # Feed the ruleset over stdin (an fd opened here), not by path: under
          # Steam the privileged nft runs in the host mount namespace and can't
          # see our private-/tmp path, but an inherited fd crosses namespaces.
          if ! nft_err="$(nft_root -f - < "$ruleset" 2>&1)"; then
            saved="''${XDG_RUNTIME_DIR:-/tmp}/ow-region-last.nft"
            cp "$ruleset" "$saved" 2>/dev/null || true
            echo "ow-region: failed to apply nftables ruleset:" >&2
            printf '%s\n' "$nft_err" >&2
            echo "ow-region: (the generated ruleset was saved to $saved)" >&2
            exit 1
          fi
          printf '%s\n' "$region" > "$STATE_FILE"

          count="$(wc -l < "$elements_file")"
          echo "ow-region: locked to '$region' ($count ranges blocked for the game only) — launching..."

          # Run the game inside the slice; blocks until it exits, then trap fires.
          # Restore the stashed Steam env for the game only (systemd-run itself
          # stays on our scrubbed env so it isn't broken by Steam's libs).
          game_env=( env )
          [ -n "$GAME_LD_LIBRARY_PATH" ] && game_env+=( "LD_LIBRARY_PATH=$GAME_LD_LIBRARY_PATH" )
          [ -n "$GAME_LD_PRELOAD" ] && game_env+=( "LD_PRELOAD=$GAME_LD_PRELOAD" )
          systemd-run --user --scope --collect --quiet --slice=ow-region.slice \
            -- "''${game_env[@]}" "$@"
          ;;

        *)
          usage; exit 1
          ;;
      esac
    '';
  };
in
{
  # Non-interactive sudo for the toggle command (mirrors the rules in
  # vpn-hotspot.nix). nft needs root; only that binary is granted.
  security.sudo.extraRules = [{
    users = [ "bb99" ];
    commands = [
      { command = "${pkgs.nftables}/bin/nft *"; options = [ "NOPASSWD" ]; }
    ];
  }];

  environment.systemPackages = [
    ow-region        # `ow-region play <region> -- <cmd>` / status / off / list
    pkgs.nftables    # `nft` on PATH for inspecting rules (sudo nft list ...)
  ];
}
