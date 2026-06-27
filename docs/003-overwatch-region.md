# Overwatch region forcing (`ow-region`)

> Living reference for the `ow-region` command — how it lets you pick which
> Overwatch 2 region you play on, scoped to the game so it doesn't disrupt
> Discord or anything else.

## TL;DR

You're in the EU but want to play on, say, **North America West**. Overwatch 2
has no in-game region picker, so `ow-region` forces it by firewall-blocking the
IP ranges of every region you *don't* want — but **only for the game's own
process**, so Discord voice and the rest of your machine keep working.

**Steam / Proton setup (one time):** in Overwatch's *Properties → Launch
Options*, set:

```
ow-region play na-west %command%
```

Swap `na-west` for any region key. Launch normally from Steam; the region is
forced while the game runs and released automatically when it quits.

## How it works

- Overwatch 2 game servers run on Blizzard and Google Cloud IP ranges, one set
  per region (e.g. NA West / LAS1 is `64.224.24.0/23`; the Google-hosted regions
  are larger `34.x`/`35.x` blocks).
- The matchmaker routes you to the **lowest-latency reachable** server. Block
  every *other* region (EU/Finland, NA East/Central, Netherlands, ME, AU, Japan,
  Korea, Singapore, Taiwan, Brazil) and it falls back to the one you left open.
- **Why it's scoped to the game:** some regions are shared Google Cloud blocks
  and Discord's voice servers are on GCP too, so a machine-wide block could catch
  Discord. Instead, the game runs inside a
  transient systemd scope under `ow-region.slice`, and the nftables rule only
  acts **on that cgroup** (`socket cgroupv2`). Everything outside the game is
  untouched.
- Blocking covers **all protocols**, not just UDP. (An earlier UDP-only attempt
  let the matchmaker still pick a blocked region — it probes reachability over
  TCP — and then the match connection over UDP failed, so you couldn't *join
  matches*. Blocking all protocols stops the matchmaker choosing those regions
  at all.) Because it's cgroup-scoped, blocking everything only affects the game.
- The **target region is allow-listed first** (`accept` before `drop`), so it is
  never collaterally blocked where another region's broad range overlaps it.
- The block is torn down automatically when the game exits (crash / Ctrl-C too).

## Usage

| Command | Effect |
| --- | --- |
| `ow-region play <region> -- <command...>` | Run `<command>` (the game) region-locked. The `--` is optional; Steam passes `%command%` directly. |
| `ow-region status` | Is a session active, and which region? |
| `ow-region off` | Emergency teardown (normally automatic on game exit). |
| `ow-region play none -- <command...>` | Block **every** region — no game servers reachable. Only whitelisted IPs (e.g. the lobby) pass, so you can stay in the lobby/practice range but never be matched. |
| `ow-region list` | Print the valid region keys. |
| `ow-region allow <ip\|cidr>...` | Add to the persistent whitelist (always accepted). |
| `ow-region allowlist` | Show the current whitelist. |
| `ow-region metrics` | Write per-server packet counts to `/tmp/ow-region/metrics.txt` — **passed** (non-dropped) servers first, busiest at the top (the one you're actually talking to), then **dropped** (blocked regions). |

**Region keys:** `na-west` (LAS1), `na-central` (ORD1), `na-east` (GUE4),
`eu` (Finland/GEN1), `netherlands` (AMS1), `me` (Saudi Arabia/GMEC2),
`au` (SYD2), `japan` (Tokyo/GTK1), `korea` (ICN1), `singapore` (GSG1),
`taiwan` (TPE1), `brazil` (GBR1), plus the special `none` (blocks every region —
no game servers reachable). Names in parentheses are dropship's server codes.

## Implementation

Defined in [`modules/networking/ow-region.nix`](../modules/networking/ow-region.nix),
imported from `configuration.nix`. It's a `pkgs.writeShellApplication` exposed
via `environment.systemPackages` — same pattern as the `hotspot` command in
[`vpn-hotspot.nix`](../modules/networking/vpn-hotspot.nix).

- **IP ranges are embedded**, not fetched. They're lifted verbatim from the
  [stowmyy/dropship](https://github.com/stowmyy/dropship) selector's
  `src/core/Settings.h` (the `GPC_*` / `BLIZZARD_*` consts and each server's
  `.block` list) into the module's `regions` map. dropship bakes this data into
  its binary rather than serving it, so there's **no network dependency** at
  launch. IPv6 prefixes are kept verbatim but ignored (the tool is IPv4-only).
  To refresh after an upstream change, re-copy the strings from that header.
- **cgroup scoping:** a tiny `sleep infinity` holder is started under
  `ow-region.slice` so the slice's cgroup exists; the script reads its
  `ControlGroup` path to compute the nftables `socket cgroupv2 level N "<path>"`
  match. The game is then launched with `systemd-run --user --scope
  --slice=ow-region.slice`, so it (and all its children, including the Proton /
  pressure-vessel chain) live under that slice and are matched by the rule.
- **An independent nftables table**, `inet ow_region`, holds two `interval` sets
  (`auto-merge`d): `blocked4` (all other regions) and `allowed4` (the target
  region). The `output` hook chain, scoped to the game's cgroup, accepts
  `ip daddr @allowed4` first, then on `ip daddr @blocked4` does
  `update @dropstats { ip daddr } drop`. A separate table coexists with the
  default NixOS iptables firewall and is trivial to flush.
- **`dropstats` / `passstats`** are two `flags dynamic; counter` sets, so each
  destination IP gets its own packet/byte counter. Every blocked packet updates
  `dropstats`; every *non-dropped* game packet updates `passstats` — counted on
  the `@allowed4` accept and on a trailing fall-through rule, so it captures the
  target region, the whitelist, **and** servers the embedded lists don't cover
  (e.g. the lobby, or a stray region). The busiest `passstats` entry is the
  server you're actually talking to. The `metrics` subcommand snapshots both to
  `/tmp/ow-region/metrics.txt` (passed first, busiest at the top), and teardown
  dumps them there before flushing the table.
- Set elements come straight from the embedded `regions` strings, extracted with
  `grep -oE` so the comma-separated lists are handled. nftables interval sets
  accept both CIDR (`34.76.0.0/14`) and dash ranges (`24.105.8.0-24.105.15.255`).
- **Steam runtime env:** Steam injects an `LD_LIBRARY_PATH`/`LD_PRELOAD` pointing
  at its own runtime, which overrides our nixpkgs tools' RPATH and can make them
  load Steam's incompatible libraries (e.g. `systemd-run`, `getent`). The script
  stashes those vars, scrubs them for its own work, and restores them only for
  the game launch (via an `env` wrapper inside the scope) so Proton/MangoHud
  still get them.
- **Sudo:** `nft` needs root, so the module grants `bb99` passwordless use of
  the `nft` binary via `security.sudo.extraRules` (only that binary).
  `systemd-run`/`systemctl --user` need no sudo.
- **no_new_privs:** a Steam launch runs the whole tree under `no_new_privs`,
  which blocks `sudo` from escalating. So the privileged `nft` calls are
  dispatched through the systemd **user manager** (`systemd-run --user --wait
  -- sudo nft …`), which runs them in a fresh unit without that flag. The game
  itself stays under `no_new_privs` (it needs no privileges).
- The active region is recorded in `/tmp/ow-region.active` for `status`; cleanup
  removes it along with the table and the holder.

## If the lobby won't connect

Because the block covers all protocols, it can also catch Overwatch's **lobby /
login server** when that happens to live inside a blocked region's range (for an
EU player, the lobby is an EU-listed IP). Symptom: the game opens but can't reach
the lobby at all. Fix — whitelist the lobby server:

1. Launch the game (it'll hang connecting), then read the per-server drop tally:
   ```
   ow-region metrics
   ```
   The drop rule feeds an nftables dynamic counter set (`dropstats`), one counter
   per destination IP. `metrics` snapshots it — sorted by drop count — into
   `/tmp/ow-region/metrics.txt`. (It's also written automatically at teardown,
   before the table is flushed.)
2. Identify the lobby server IP(s) — the ones with the highest drop counts while
   the client is stuck at "connecting".
3. Whitelist them and relaunch:
   ```
   ow-region allow 34.x.x.x
   ```
   The whitelist (`~/.config/ow-region/allow.txt`, where `~` is resolved from the
   passwd database so it matches even under Steam's overridden env) is accepted
   before the drop, so the lobby connects while the rest of that region's *game*
   servers stay blocked — forcing matches onto your target region. Both single
   IPs and CIDRs are accepted; `play` prints how many whitelist entries it merged.

The same approach handles "can join the lobby but not matches": that's the
matchmaker still picking a blocked region; the all-protocol block (vs. the old
UDP-only one) is what prevents it.

### Auto-allow (skip the manual hunt)

Instead of reading `metrics` and whitelisting by hand, you can let `ow-region`
promote a server automatically once the client has retried it enough. Set
`OW_REGION_PROMOTE_AFTER=N` in the launch options:

```
OW_REGION_PROMOTE_AFTER=22 ow-region play none %command%
```

A background watcher polls `dropstats` every `OW_REGION_PROMOTE_INTERVAL` seconds
(default 5) and, when a destination crosses **N dropped packets**, adds it to
`allowed4` so its traffic is accepted from then on. A lobby/login server stuck in
a blocked region therefore unblocks itself after the client hammers it past the
threshold — no IP hunting. The promotion is session-only (it isn't written to the
persistent whitelist); use `ow-region allow` if you want it to stick.

It's **opt-in** for a reason: the matchmaker also retries the *game* servers of
blocked regions, so a low threshold can promote a region you were trying to
block. Pick N high enough that only the persistent lobby/login traffic clears it.

## Caveats

- **Higher ping by design** — you're deliberately playing on a distant region.
- **Lists can change upstream.** The ranges are embedded, so a Blizzard server
  move means the data goes stale — re-sync the `regions` map from dropship's
  `Settings.h` (and rebuild). If forcing stops working, check there first.
- **cgroup matching needs a systemd `--user` session** (the normal graphical
  login). If Overwatch is ever launched outside one, the lock won't apply.
- **Don't spam "rejoin"** if you ever land on an unwanted server — per community
  guidance it can cost SR.
- This is **unofficial**; use at your own discretion.
