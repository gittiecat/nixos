#!/usr/bin/env bash
# nixos-bootstrap — install this flake onto a target machine from the live ISO.
# See docs/002-installer-iso.md for the full design and hurdles.
set -euo pipefail

REPO_URL="https://github.com/gittiecat/nixos.git"
FLAKE_HOST="nixos"
TARGET_USER="bb99"
# uid:gid the user/group get on the installed system (first normal user / users).
TARGET_UIDGID="1000:100"
DISKO_NIX="/etc/nixos-installer/disko.nix"

die() { echo "error: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run as root: sudo nixos-bootstrap"
[ -f "$DISKO_NIX" ] || die "missing $DISKO_NIX (is this the custom installer ISO?)"

# --- 1. choose the target disk -------------------------------------------------
# Exclude the disk the live ISO is running from (mounted at /iso).
live_part="$(findmnt -no SOURCE /iso 2>/dev/null || true)"
live_disk=""
[ -n "$live_part" ] && live_disk="/dev/$(lsblk -no PKNAME "$live_part" | head -n1)"

echo "Available disks (the live USB ${live_disk:+$live_disk }is excluded):"
echo
candidates=()
while read -r name type; do
  [ "$type" = "disk" ] || continue
  [ "/dev/$name" = "$live_disk" ] && continue
  candidates+=("/dev/$name")
  printf '  %s\n' "$(lsblk -dno PATH,SIZE,MODEL,TRAN,SERIAL "/dev/$name")"
done < <(lsblk -no NAME,TYPE)
echo
[ "${#candidates[@]}" -gt 0 ] || die "no installable disks found"

read -rp "Target disk to ERASE and install to (e.g. ${candidates[0]}): " TARGET
printf '%s\n' "${candidates[@]}" | grep -qxF "$TARGET" \
  || die "$TARGET is not in the candidate list"

echo
echo ">>> This will DESTROY ALL DATA on $TARGET <<<"
read -rp "Type the disk path again to confirm: " CONFIRM
[ "$TARGET" = "$CONFIRM" ] || die "confirmation did not match; aborting"

# --- 2. partition + format + mount via disko ----------------------------------
echo "==> Partitioning $TARGET with disko..."
nix --extra-experimental-features "nix-command flakes" \
  run github:nix-community/disko/latest -- \
  --mode destroy,format,mount --argstr device "$TARGET" "$DISKO_NIX"

# --- 3. generate a fresh, machine-specific hardware-configuration.nix ----------
echo "==> Generating hardware-configuration.nix for this machine..."
nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix /tmp/hardware-configuration.nix

# --- 4. clone the config repo into place --------------------------------------
echo "==> Cloning $REPO_URL ..."
rm -rf /mnt/etc/nixos
git clone "$REPO_URL" /mnt/etc/nixos

# --- 5. drop in the generated hardware config and make the flake see it --------
# hardware-configuration.nix is gitignored, so intent-to-add (-fN) it: the flake
# evaluates the working-tree file without it ever being committed.
cp /tmp/hardware-configuration.nix /mnt/etc/nixos/hardware-configuration.nix
git -C /mnt/etc/nixos add -fN hardware-configuration.nix

# --- 6. install ---------------------------------------------------------------
echo "==> Installing (this builds the whole system; grab a coffee)..."
nixos-install --flake "/mnt/etc/nixos#${FLAKE_HOST}"

# --- 7. ownership so the user can edit/commit the repo without sudo -----------
chown -R "$TARGET_UIDGID" /mnt/etc/nixos

# --- 8. set the user password now so first boot logs straight into the desktop -
echo "==> Set a password for ${TARGET_USER}:"
nixos-enter --root /mnt -c "passwd ${TARGET_USER}"

cat <<EOF

Done. Now:
  1. reboot and remove the USB
  2. log in as ${TARGET_USER}
  3. run 'rebuild' to confirm the system rebuilds cleanly

Dotfile symlinks (hyprland/waybar/...) are wired declaratively, so there is
nothing to symlink by hand.
EOF
