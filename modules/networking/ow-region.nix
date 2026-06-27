{ config, pkgs, lib, ... }:

# Force which Overwatch 2 region you play on, WITHOUT disrupting anything else.
#
# Overwatch 2 game servers run on Blizzard and Google Cloud IP ranges, one set
# per region, and the matchmaker routes you to the lowest-latency *reachable*
# server. There is no in-game setting, so the trick is to firewall-block every
# region you DON'T want — leaving your target region as the only viable option.
# The per-region IP ranges are embedded from the `dropship` server selector
# (stowmyy/dropship) — see the data block below.
#
# The catch: some of those ranges are shared Google Cloud blocks, so a
# machine-wide block could also catch other services hosted on GCP — e.g.
# Discord voice. To avoid that, this scopes the block to the *game's cgroup
# only*: the game runs inside a transient systemd scope under `ow-region.slice`,
# and the nftables rule drops traffic only from that cgroup. Discord and
# everything else are unaffected.
#
# Setup (Steam / Proton): set the Overwatch Launch Options to
#     ow-region play na-west %command%
# (swap na-west for any region key). That's it — region is forced while the
# game runs and released automatically when it exits.
#
# The special key `none` blocks EVERY region — no game servers are reachable.
# Only whitelisted IPs (e.g. the lobby/login server, see `ow-region allow`) get
# through, so you can sit in the lobby/practice range but never be matched.
#
# Auto-allow (opt-in): prefix the launch options with OW_REGION_PROMOTE_AFTER=N
# to auto-unblock any server once it's been dropped N times — e.g.
#     OW_REGION_PROMOTE_AFTER=22 ow-region play none %command%
# A lobby/login server in a blocked region gets allowed automatically after the
# client retries past the threshold, so you don't have to hunt its IP by hand.
# (It also unblocks any game server hammered past N, which dilutes the lock —
# hence off by default. Tune the poll with OW_REGION_PROMOTE_INTERVAL, default 5s.)
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
  # Server IP-range data lifted verbatim from the `dropship` Overwatch server
  # selector (stowmyy/dropship, src/core/Settings.h — the GPC_* / BLIZZARD_*
  # consts and the per-server `.block` strings). dropship bakes these into its
  # binary rather than serving them over HTTP, so we embed them here too; there
  # is no live fetch. The IPv6 prefixes are kept verbatim for fidelity but are
  # ignored at runtime — the tool is IPv4-only (extract_ranges drops them).
  #
  # To refresh after an upstream change, re-copy the relevant strings from that
  # header. Last synced from dropship/main: 2026-06-05.
  gpc = {
    europeNorth1      = "34.88.0.0/16,34.104.96.0/21,34.124.32.0/21,35.203.232.0/21,35.217.0.0/18,35.220.26.0/24,35.228.0.0/16,35.242.26.0/24,2600:1900:4150::/44";
    asiaSoutheast1    = "34.1.128.0/20,34.1.192.0/20,34.2.16.0/20,34.2.128.0/17,34.21.128.0/17,34.87.0.0/17,34.87.128.0/18,34.104.58.0/23,34.104.106.0/23,34.124.42.0/23,34.124.128.0/17,34.126.64.0/18,34.126.128.0/18,34.128.44.0/23,34.128.60.0/23,34.142.128.0/17,34.143.128.0/17,34.152.104.0/23,34.153.40.0/23,34.153.232.0/23,34.157.82.0/23,34.157.88.0/23,34.157.210.0/23,34.158.32.0/19,34.177.72.0/23,34.177.80.0/20,34.177.96.0/20,34.183.80.0/24,34.184.75.0/24,35.185.176.0/20,35.186.144.0/20,35.187.224.0/19,35.197.128.0/19,35.198.192.0/18,35.213.128.0/18,35.220.24.0/23,35.234.192.0/20,35.240.128.0/17,35.242.24.0/23,35.247.128.0/18,136.110.0.0/18,2600:1900:4080::/44";
    southamericaEast1 = "34.39.128.0/17,34.95.128.0/17,34.104.80.0/21,34.124.16.0/21,34.151.0.0/18,34.151.192.0/18,35.198.0.0/18,35.199.64.0/18,35.215.192.0/18,35.220.40.0/24,35.235.0.0/20,35.242.40.0/24,35.247.192.0/18,2600:1900:40f0::/44";
    asiaNortheast1    = "34.84.0.0/16,34.85.0.0/17,34.104.62.0/23,34.104.128.0/17,34.127.190.0/23,34.146.0.0/16,34.153.192.0/19,34.157.64.0/20,34.157.164.0/22,34.157.192.0/20,34.180.64.0/18,35.187.192.0/19,35.189.128.0/19,35.190.224.0/20,35.194.96.0/19,35.200.0.0/17,35.213.0.0/17,35.220.56.0/22,35.221.64.0/18,35.230.240.0/20,35.242.56.0/22,35.243.64.0/18,104.198.80.0/20,104.198.112.0/20,136.110.64.0/18,2600:1900:4050::/44";
    meCentral2        = "8.228.192.0/19,8.230.64.0/19,34.1.48.0/20,34.152.84.0/23,34.152.102.0/24,34.157.122.128/25,34.157.218.128/25,34.166.0.0/16,34.177.48.0/23,34.177.70.0/24,34.183.69.0/24,34.184.68.0/24,35.252.32.0/19,2600:1900:5400::/44";
    usEast4           = "8.228.64.0/18,8.234.2.0/24,8.234.128.0/17,34.4.32.0/20,34.11.0.0/17,34.21.0.0/17,34.48.0.0/16,34.85.128.0/17,34.86.0.0/16,34.104.60.0/23,34.104.124.0/23,34.118.252.0/23,34.124.60.0/23,34.127.188.0/23,34.145.128.0/17,34.150.128.0/17,34.157.0.0/21,34.157.16.0/20,34.157.128.0/21,34.157.144.0/20,34.181.128.0/17,34.182.128.0/17,34.183.12.0/22,34.183.34.0/23,34.183.60.0/24,34.183.68.0/24,34.184.12.0/22,34.184.32.0/23,34.184.59.0/24,34.184.67.0/24,34.186.32.0/19,34.186.64.0/18,35.186.160.0/19,35.188.224.0/19,35.194.64.0/19,35.199.0.0/18,35.212.0.0/17,35.220.60.0/22,35.221.0.0/18,35.230.160.0/19,35.234.176.0/20,35.236.192.0/18,35.242.60.0/22,35.243.40.0/21,35.245.0.0/16,136.23.64.0/19,136.107.0.0/16,2600:1900:4090::/44";
  };
  dacomKr = "110.45.208.0/24,117.52.6.0/24,117.52.26.0/23,117.52.28.0/23,117.52.33.0/24,117.52.34.0/23,117.52.36.0/23,121.254.137.0/24,121.254.206.0/23,121.254.218.0/24,182.162.31.0/24";

  # region key -> blocked CIDR ranges, mapping dropship's user-facing endpoints to
  # their backing server's `.block` list. Keys keep the old names so existing
  # launch options stay valid; `netherlands` (AMS1) is new vs. the previous set.
  regions = {
    na-west     = "64.224.24.0/23";                  # LAS1  (blizzard/las1)   USA - West
    na-central  = "64.224.0.0/21,24.105.40.0/21";    # ORD1  (blizzard/ord1)   USA - Central
    na-east     = gpc.usEast4;                        # GUE4  (google/us-east4) USA - East
    eu          = gpc.europeNorth1;                   # GEN1  (google/europe-north1) Finland
    netherlands = "64.224.26.0/23";                   # AMS1  (blizzard/ams1)   Netherlands
    me          = gpc.meCentral2;                     # GMEC2 (google/me-central2) Saudi Arabia
    au          = "158.115.196.0/23";                 # SYD2  (blizzard/syd2)   Australia
    japan       = gpc.asiaNortheast1;                 # GTK1  (google/asia-northeast1) Tokyo
    korea       = dacomKr;                            # ICN1  (blizzard/icn1)   South Korea
    singapore   = gpc.asiaSoutheast1;                 # GSG1  (google/asia-southeast1)
    taiwan      = "5.42.160.0/22,5.42.164.0/22";      # TPE1  (blizzard/tpe1)   Taiwan
    brazil      = gpc.southamericaEast1;              # GBR1  (google/southamerica-east1)
  };

  # Bash associative-array literal: [na-west]="64.224.24.0/23" ...
  regionMapEntries = lib.concatStringsSep " "
    (lib.mapAttrsToList (k: v: "[${k}]=\"${v}\"") regions);

  ow-region = pkgs.writeShellApplication {
    name = "ow-region";
    runtimeInputs = with pkgs; [ nftables gnugrep coreutils systemd getent ];
    text = ''
      # region key -> blocked CIDR ranges (comma-separated; IPv6 entries are
      # filtered out downstream). Embedded from dropship — no network fetch.
      declare -A REGIONS=( ${regionMapEntries} )
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
        echo "       ow-region metrics              (per-server packet counts, passed+dropped -> $METRICS_FILE)" >&2
        echo "regions: ''${!REGIONS[*]} none" >&2
        echo "  ('none' blocks every region — no game servers reachable)" >&2
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

      # Render a dynamic counter set ("<ip> <packets>", busiest first) from raw
      # `nft list set` output piped on stdin.
      fmt_counters() {
        grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ counter packets [0-9]+' \
          | while read -r ip _ _ pkts; do echo "$ip $pkts"; done \
          | sort -k2 -nr
      }

      # Snapshot per-destination packet counts into the metrics file. Lists the
      # PASSED (non-dropped) servers first — the busiest is the one you're
      # actually talking to — then the DROPPED (blocked-region) servers.
      # Returns non-zero (and writes nothing) if no session/table.
      dump_metrics() {
        local dropped passed
        dropped="$(nft_root list set inet ow_region dropstats 2>/dev/null)" || return 1
        passed="$(nft_root list set inet ow_region passstats 2>/dev/null)" || true
        mkdir -p "$METRICS_DIR"
        {
          echo "# ow-region metrics — $(date -Is) — region=''${region:-?}"
          echo "# === PASSED (non-dropped) — your live servers, busiest first ==="
          echo "# <server-ip> <passed-packets>"
          printf '%s\n' "$passed" | fmt_counters
          echo
          echo "# === DROPPED (blocked regions) — busiest first ==="
          echo "# <server-ip> <dropped-packets>"
          printf '%s\n' "$dropped" | fmt_counters
        } > "$METRICS_FILE"
      }

      # Optional auto-allow watcher (opt-in via OW_REGION_PROMOTE_AFTER=N): poll
      # the drop counters and, once a server has been dropped >= N times, move it
      # into allowed4 so its traffic is accepted from then on. Handy for a
      # lobby/login server that lives in a blocked region — it gets unblocked
      # automatically after the client retries enough, no manual IP hunting.
      # Caveat: it will also unblock any *game* server the matchmaker hammers
      # past N, which dilutes region forcing — hence opt-in. Poll interval is
      # OW_REGION_PROMOTE_INTERVAL seconds (default 5).
      promoter() {
        local n="$1" ip pkts
        declare -A promoted=()
        while sleep "''${OW_REGION_PROMOTE_INTERVAL:-5}"; do
          while read -r ip _ _ pkts; do
            [ -n "''${promoted[$ip]:-}" ] && continue
            [ "$pkts" -ge "$n" ] || continue
            if nft_root add element inet ow_region allowed4 "{ $ip }" 2>/dev/null; then
              promoted[$ip]=1
              echo "ow-region: auto-allowed $ip (>= $n dropped packets)" >&2
            fi
          done < <(nft_root list set inet ow_region dropstats 2>/dev/null \
                     | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ counter packets [0-9]+')
        done
      }

      # Tear down the scoped block and the cgroup holder. Safe to call twice.
      cleanup() {
        [ -n "''${WATCH_PID:-}" ] && kill "$WATCH_PID" 2>/dev/null || true
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
          { for r in "''${!REGIONS[@]}"; do echo "$r"; done; echo none; } | sort
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
            echo "ow-region: per-server packet counts (passed + dropped) -> $METRICS_FILE"
            cat "$METRICS_FILE"
          else
            echo "ow-region: no active session — no counters to read" >&2
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
          if [ "$region" != "none" ] && [ -z "''${REGIONS[$region]:-}" ]; then
            echo "ow-region: unknown region '$region'" >&2; usage; exit 1
          fi
          if [ "$#" -eq 0 ]; then
            echo "ow-region: nothing to run (expected a command after the region)" >&2
            usage; exit 1
          fi

          # Steam/Proton inject the Steam-runtime LD_LIBRARY_PATH/LD_PRELOAD,
          # which override our nixpkgs tools' RPATH and can make them load Steam's
          # incompatible libraries (systemd-run, getent, …). Stash them for the
          # game, scrub them for our own use, restore them only at game launch.
          GAME_LD_LIBRARY_PATH="''${LD_LIBRARY_PATH:-}"
          GAME_LD_PRELOAD="''${LD_PRELOAD:-}"
          unset LD_LIBRARY_PATH LD_PRELOAD

          TMP="$(mktemp -d)"

          # Collect ranges from every region EXCEPT the target. Ranges are
          # embedded (dropship) — no download — so this can't fail on the network.
          elements_file="$TMP/elements"
          : > "$elements_file"
          for r in "''${!REGIONS[@]}"; do
            [ "$r" = "$region" ] && continue
            # Extract every CIDR / dash-range token, one per line — robust to the
            # comma separators in the embedded strings; IPv6 is dropped.
            printf '%s\n' "''${REGIONS[$r]}" | extract_ranges >> "$elements_file"
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
          # 'none' has no target region to allow-list — only the whitelist below.
          if [ "$region" != "none" ]; then
            printf '%s\n' "''${REGIONS[$region]}" | extract_ranges >> "$allow_file"
          fi
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
            # The allow-list set always exists (even when empty) so the auto-allow
            # watcher can promote servers into it at runtime. Only emit the
            # 'elements = {...}' line when non-empty — 'elements = { }' is invalid.
            echo "  set allowed4 {"
            echo "    type ipv4_addr"
            echo "    flags interval"
            echo "    auto-merge"
            [ -n "$allow_body" ] && echo "    elements = { $allow_body }"
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
            # Mirror of dropstats for traffic that is NOT dropped: the target
            # region, the whitelist, and anything not covered by a blocked list
            # (e.g. the lobby, or a stray server the embedded lists miss). The
            # busiest entry here is the server you're actually talking to.
            echo "  set passstats {"
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
            echo "    socket cgroupv2 level $level \"$slice_cg\" ip daddr @allowed4 update @passstats { ip daddr } accept"
            # Tally per-destination drops into dropstats, then drop.
            echo "    socket cgroupv2 level $level \"$slice_cg\" ip daddr @blocked4 update @dropstats { ip daddr } drop"
            # Anything still here is game traffic we let through (lobby, an
            # uncovered server, etc.) — tally it into passstats and fall through
            # to the accept policy.
            echo "    socket cgroupv2 level $level \"$slice_cg\" update @passstats { ip daddr }"
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
          if [ "$region" = "none" ]; then
            echo "ow-region: ALL regions blocked ($count ranges) — no game servers reachable; only whitelisted IPs (e.g. lobby) pass — launching..."
          else
            echo "ow-region: locked to '$region' ($count ranges blocked for the game only) — launching..."
          fi

          # Opt-in auto-allow: promote any server past OW_REGION_PROMOTE_AFTER
          # dropped packets into allowed4. Disabled unless the var is a positive
          # integer. The watcher is a background job, killed by cleanup on exit.
          WATCH_PID=""
          case "''${OW_REGION_PROMOTE_AFTER:-0}" in
            '''|*[!0-9]*|0) : ;;   # unset / non-numeric / zero -> disabled
            *)
              echo "ow-region: auto-allow ON — servers exceeding ''${OW_REGION_PROMOTE_AFTER} dropped packets get unblocked"
              promoter "$OW_REGION_PROMOTE_AFTER" & WATCH_PID=$!
              ;;
          esac

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
