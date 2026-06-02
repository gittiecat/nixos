# Self-installing NixOS installer ISO — bootstrap a new machine from this repo

> Living reference for the custom installer USB: a minimal NixOS live image that
> carries a single `nixos-bootstrap` script. The script partitions the disk,
> clones this repo into `/etc/nixos`, generates a fresh machine-specific
> `hardware-configuration.nix`, fixes ownership, and installs — leaving a system
> where the home dotfile symlinks are already wired and you just run `rebuild`.

## Final decisions (TL;DR)

- **Don't carry the repo on the USB.** It changes constantly. The USB carries
  only the OS + one install script; the config is *cloned fresh* at install time.
- **`hardware-configuration.nix` is untracked.** It is `git rm --cached`-ed and
  gitignored, so the shared repo holds **no** machine-specific UUIDs. Each machine
  generates its own copy locally.
- **The `rebuild` alias stages it with `git add -fN`.** Because the flake ignores
  untracked files, an ungitignored hardware file would break every build — so the
  alias (and the bootstrap script) intent-to-add it before building. `-N` means it
  is never re-committed, so UUIDs never leak back into the repo.
- **Partitioning is automated with [disko](https://github.com/nix-community/disko)**
  from `installer/disko.nix` (EFI + `btrfs` `@`-subvol layout). It is a
  **destructive** wipe of the chosen disk, used at install time only — the running
  system's filesystems come from the regenerated `hardware-configuration.nix`.
- **Dotfile symlinks are declarative.** `modules/desktop/dotfile-links.nix` wires
  `~/.config/{hypr,waybar,bspwm,sxhkd}` into the repo via `systemd.tmpfiles`, so a
  rebuild sets them up — no manual `ln -s`.
- **The repo is cloned over HTTPS** (`https://github.com/gittiecat/nixos.git`); no
  SSH key needed in the live environment.
- **Machine-class modules stay enabled.** NVIDIA and the extra `/mnt/h`,`/mnt/g`
  data-disk mounts are this-PC-specific; regenerating the hardware file fixes
  UUIDs/CPU but not those — disable them by hand on a different machine.

## How it fits together

```
  ┌─────────────────────────────┐        nix build .#…installer…isoImage
  │  this repo (flake)          │ ───────────────────────────────────────▶  custom .iso
  │  + installer/iso.nix        │                                              │
  │  + installer/bootstrap.sh   │                            dd to USB ◀───────┘
  │  + installer/disko.nix      │
  └─────────────────────────────┘
                                          boot USB → `sudo nixos-bootstrap`
                                                          │
        ┌─────────────────────────────────────────────────┼───────────────────────────┐
        ▼                    ▼                    ▼         ▼              ▼              ▼
   disko wipe+        nixos-generate-      git clone     drop fresh   git add -fN    nixos-install
   format+mount       config (fresh        repo →        hw config    hw config →    --flake
   /mnt               hardware UUIDs)      /mnt/etc/nixos into clone   flake sees it  #nixos
                                                                                         │
                                              reboot → log in → `passwd` → `rebuild` ◀────┘
                                              (dotfile symlinks already wired)
```

## Repo pieces this relies on

| File | Role |
|------|------|
| `flake.nix` → `nixosConfigurations.installer` | builds the ISO from the upstream minimal installer + `installer/iso.nix` |
| `installer/iso.nix` | enables flakes, ships `git` + the `nixos-bootstrap` script, adds a login banner |
| `installer/bootstrap.sh` | the single install script (steps below) |
| `installer/disko.nix` | declarative disk layout (EFI + `btrfs` `@`) used by disko |
| `modules/desktop/dotfile-links.nix` | declarative `~/.config` symlinks into `/etc/nixos/configs/…` |
| `.gitignore` + untracked `hardware-configuration.nix` | keeps machine UUIDs out of the repo |
| `modules/core/aliases.nix` | `rebuild` stages the hardware file via `git add -fN` |

## Build the ISO

From a machine that already has Nix with flakes:

```bash
nix build .#nixosConfigurations.installer.config.system.build.isoImage
# result/iso/*.iso
```

Flash it to a USB stick (replace `/dev/sdX` with the real device — check `lsblk`):

```bash
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

## Install flow on the target machine

1. Boot the USB (disable Secure Boot if it blocks the kernel).
2. Get networking up (Ethernet is automatic; for Wi-Fi use `nmtui`).
3. Run the script:
   ```bash
   sudo nixos-bootstrap
   ```
   It will:
   1. List the candidate disks and ask which one to install to (see
      [Choosing the target disk](#choosing-the-target-disk)), then require a typed
      confirmation (disko **erases** that disk).
   2. Run disko against `installer/disko.nix` → partition, format, mount `/mnt`.
   3. `nixos-generate-config --root /mnt` → writes a correct
      `/mnt/etc/nixos/hardware-configuration.nix` with this machine's UUIDs, CPU,
      and initrd modules; save it aside.
   4. `git clone https://github.com/gittiecat/nixos.git /mnt/etc/nixos`.
   5. Drop the saved hardware file into the clone and
      `git -C /mnt/etc/nixos add -fN hardware-configuration.nix` so the flake sees
      it.
   6. `chown -R bb99:users /mnt/etc/nixos` so the user can edit/commit without sudo.
   7. `nixos-install --flake /mnt/etc/nixos#nixos` (prompts for the **root**
      password).
   8. Set the **user** passwords before you reboot (see
      [Setting user passwords](#setting-user-passwords)) — the script does this
      with `nixos-enter` so you can log straight into the desktop on first boot.
4. Reboot, remove the USB.
5. Log in as `bb99` at the tuigreet screen with the password you just set.
6. `rebuild` — the dotfile symlinks are already wired; this just confirms the
   system rebuilds cleanly going forward.

## Choosing the target disk

This is the dangerous step: the machine is booted *from the USB*, so the USB
itself shows up in the disk list, and any second/data drive you don't want
touched shows up too. The script narrows it down for you rather than trusting a
guess.

**What the script does:**

1. **List only whole disks** (not partitions, not the squashfs loop devices),
   with enough detail to identify them physically:
   ```bash
   lsblk -dpno NAME,SIZE,MODEL,TRAN,SERIAL --filter 'TYPE=="disk"'
   # /dev/nvme0n1  931.5G  Samsung SSD 990 PRO 1TB  nvme   S6...
   # /dev/sda       57.3G  SanDisk Ultra            usb    4C...   ← the installer USB
   ```
   `TRAN` (transport: `nvme`/`sata`/`usb`) plus `MODEL`, `SIZE`, and `SERIAL` let
   you tell the internal target disk from the USB stick at a glance.

2. **Auto-detect and exclude the live USB.** The NixOS live image is mounted at
   `/iso`, so the script resolves the device backing it and drops it from the
   candidate list:
   ```bash
   live_part=$(findmnt -no SOURCE /iso)        # e.g. /dev/sda1
   live_disk=/dev/$(lsblk -no PKNAME "$live_part")  # e.g. /dev/sda
   ```
   That removes the most common footgun (installing onto the stick you booted
   from).

3. **Present the remaining candidates and make you pick.** If exactly one disk
   remains it's suggested as the default; otherwise you choose. Either way the
   script **requires you to type the full device path** (e.g. `/dev/nvme0n1`) and
   then confirm a second time, because disko will destroy everything on it.

**Cross-checks if you're unsure which physical drive is which:**

- `ls -l /dev/disk/by-id/` — stable names that include model + serial, the same
  serial shown above. Safer to reason about than `sda`/`nvme0n1`, which can
  reorder between boots.
- `nvme list` / `lsblk -o NAME,SIZE,MODEL,SERIAL,MOUNTPOINTS` for a fuller picture.
- Size is usually the quickest tell: a 1 TB internal SSD vs a 32–64 GB stick.

The chosen path is passed straight to disko: `--arg device '"/dev/nvme0n1"'`.
disko handles the partition-suffix difference for you (`nvme0n1p1` vs `sda1`).

## How `hardware-configuration.nix` is handled

It is **untracked and gitignored**, so it never travels with the repo:

```bash
git rm --cached hardware-configuration.nix   # done once; local file kept
echo 'hardware-configuration.nix' >> .gitignore
```

`configuration.nix` still `imports = [ ./hardware-configuration.nix … ]`, and the
file still exists on disk — it's just not version-controlled. Because Nix flakes
**ignore untracked files**, the file must be staged into the git index for the
build to see it. We do that with intent-to-add inside the `rebuild` alias:

```nix
rebuild = "git -C /etc/nixos add -fN hardware-configuration.nix; sudo nixos-rebuild switch --flake /etc/nixos/.";
```

- `-f` overrides the `.gitignore`.
- `-N` (intent-to-add) makes Nix pick up the working-tree content **without**
  staging it for commit — so a plain `git commit` won't push the UUIDs back into
  the repo.

For the `git` call to work as your user, `/etc/nixos` must be user-owned (the
bootstrap script chowns it; on an existing machine do it once with
`sudo chown -R bb99:users /etc/nixos`, or set
`git config --global --add safe.directory /etc/nixos`).

## Setting user passwords

The `bb99` account in `configuration.nix` declares **no password**, so NixOS
creates it *locked* (`!` in `/etc/shadow`). `nixos-install` only ever prompts for
the **root** password. That leaves a first-boot chicken-and-egg: the
login screen is **tuigreet** (greetd), which is the only thing on the greeter VT,
and PAM won't let a locked account in — so you can't just "log in and run
`passwd`" the normal way.

`users.mutableUsers` is left at its default of **`true`**, which is what makes the
clean fix possible: passwords set with `passwd` are written to `/etc/shadow` and
**persist across rebuilds** (they are *not* clobbered by `nixos-rebuild`). So we
set them once, imperatively, and they stick.

**Preferred — set them during install (what the bootstrap script does).**
Right after `nixos-install` succeeds and before rebooting, set each user's
password inside the freshly installed system with `nixos-enter`:

```bash
nixos-enter --root /mnt -c 'passwd bb99'
```

Now the account is unlocked at first boot and you log straight into tuigreet.

**Fallback — if you skipped it and booted into a locked account.** tuigreet owns
the greeter VT, but systemd still spawns a `getty` on the other virtual terminals
on demand, so:

1. Press **Ctrl+Alt+F2** (try F3–F6 if F2 is busy) to reach a text `login:`.
2. Log in as `root` with the password you set during `nixos-install`.
3. `passwd bb99`.
4. Switch back to the greeter with **Ctrl+Alt+F1** (or F7) and log in as `bb99`.

## Hurdles & gotchas

1. **Untracked-file trap (critical).** With `hardware-configuration.nix`
   gitignored, any build that doesn't stage it first fails with a missing-import
   error. The `rebuild` alias and the bootstrap script handle it via `git add -fN`;
   a bare `nixos-rebuild --flake` will not — stage it yourself first.
2. **`flake.lock` is gitignored.** A fresh clone resolves inputs to the latest
   `nixos-unstable` and rebuilds everything `cudaSupport = true` pulls in (long,
   occasionally broken). For reproducible installs, consider committing
   `flake.lock`; otherwise accept input drift between installs.
3. **Machine-class hardware stays enabled.** `modules/hardware/nvidia.nix` and the
   `/mnt/h`,`/mnt/g` mounts are specific to the current PC. Regenerating the
   hardware file fixes UUIDs/CPU/initrd but does **not** disable NVIDIA — on an
   AMD/Intel-only box, edit/disable that module by hand. The extra mounts use
   `nofail`, so a missing disk won't block boot, but their UUIDs are wrong until
   edited.
4. **disko is destructive.** A wrong disk selection wipes data — hence the typed
   confirmation. The script auto-excludes the *live USB* but **not** any secondary
   data drive (e.g. an internal HDD): those stay in the candidate list, so on a
   multi-disk machine read `SIZE`/`MODEL`/`SERIAL` carefully before confirming.
   (Note: `lsblk --filter` needs util-linux ≥ 2.40; on older live images the
   script falls back to filtering `TYPE` with `awk`/`grep`.)
5. **HTTPS clone needs the repo reachable.** Public repo clones with no auth; a
   private repo needs a token or `gh auth login` in the live environment (SSH keys
   aren't present).
6. **User passwords.** `nixos-install` sets only root; the user accounts are
   created *locked* and tuigreet can't log into a locked account — so they must be
   set with `passwd`/`nixos-enter`, not at the greeter. See
   [Setting user passwords](#setting-user-passwords).
7. **tmpfiles `L+` clobbers existing files.** Any real `~/.config/waybar` (etc.) is
   replaced by a symlink into `/etc/nixos` on rebuild — intended here, but be aware
   on a machine that already had real configs there.
8. **Secrets are out of scope.** The KeePassXC vault and YubiKey live on external
   media (see [001-keepassxc-yubikey.md](001-keepassxc-yubikey.md)); nothing secret
   is in the repo, so a fresh install has no vault until you restore it.

## Verification

- **ISO builds:** `nix build .#nixosConfigurations.installer.config.system.build.isoImage`
  produces `result/iso/*.iso`.
- **Symlink module evaluates:** `nixos-rebuild build --flake .#nixos` succeeds and
  the four `L+` rules appear in the tmpfiles config.
- **End-to-end (test in a VM first):** boot the ISO in QEMU with a blank virtual
  disk, run `sudo nixos-bootstrap`, pick the vdisk, install, reboot, log in,
  confirm `ls -l ~/.config/waybar` is a symlink into `/etc/nixos`, then run
  `rebuild` and confirm it completes.
