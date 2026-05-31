# Replace Chrome's password manager with KeePassXC + YubiKey Bio

## Context

You want to stop relying on Chrome's built-in password manager and move to a
local **KeePassXC** vault, using your newly acquired **YubiKey Bio** where it
helps. Research settled the key constraint:

- KeePassXC's *only* hardware-key unlock mechanism is **HMAC-SHA1
  Challenge-Response**. FIDO2 `hmac-secret` support is still an open feature
  request, not in any stable release
  ([#3560](https://github.com/keepassxreboot/keepassxc/issues/3560)).
- The **YubiKey Bio has no OTP application**, so it *cannot* do
  Challenge-Response ([Yubico protocols](https://docs.yubico.com/hardware/yubikey/yk-tech-manual/yk5-apps.html)).
  → The Bio cannot be KeePassXC's hardware key.

So the design is a **two-lane** model you confirmed:

1. **KeePassXC** (guarded by a strong master passphrase) is the vault for every
   site that still needs a username/password. Its browser extension replaces
   Chrome's autofill.
2. **The Bio** is your **FIDO2 passkey / security key** for sites that support
   it (Google, GitHub, Microsoft, etc.) — fingerprint instead of a password,
   nothing stored in any vault at all.

Together they fully replace Chrome's password manager. No PAM/login changes are
in scope (you did not select that).

## How authentication works

### Lane 1 — KeePassXC vault → Chrome autofill (password-protected sites)

```
  You ── master passphrase ──▶ ┌───────────┐
                               │ KeePassXC │ ── decrypts ──▶ vault.kdbx
                               └─────┬─────┘                 (local file, backed up)
                                     │ KeePassXC-Browser
                                     │ (native messaging proxy)
                                     ▼
                              ┌──────────────┐
                              │ Google Chrome│ ── autofills user/pass ──▶ website
                              └──────────────┘
```

### Lane 2 — YubiKey Bio as a passkey (passwordless sites)

```
  Website: "sign in with your security key / passkey"
          │
          ▼
   ┌──────────────┐   WebAuthn / CTAP2 (USB)   ┌────────────────┐
   │ Google Chrome│ ─────────────────────────▶ │  YubiKey Bio   │
   └──────────────┘                            │  fingerprint ✔ │  (presence + identity)
          ▲                                    └───────┬────────┘
          │            signed assertion                │
          └────────────────────────────────────────────┘
                          │
                          ▼
                    logged in — no password, nothing in the vault
```

**Mental model:** KeePassXC covers the long tail of password sites; the Bio
covers sites that accept passkeys. The two never overlap, so there is no factor
the Bio is "missing" on the vault — that lane simply isn't password-based.

## Changes

### 1. New module: `modules/security/yubikey.nix` (new dir)
Follow the existing per-module `environment.systemPackages` pattern (e.g.
[modules/applications/default.nix](modules/applications/default.nix)).

```nix
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    keepassxc        # built with YubiKey + browser-integration support by default
    yubikey-manager  # `ykman` — inspect the key, manage FIDO2 PIN/fingerprints
  ];

  # udev rules so a non-root user can talk to the key over USB (FIDO2/WebAuthn).
  services.udev.packages = [ pkgs.yubikey-personalization ];
}
```
*pcscd is intentionally omitted — only needed for PIV/smartcard, not FIDO2.*

### 2. Import the module
Add `./modules/security/yubikey.nix` to the `imports` list in
[configuration.nix](configuration.nix).
**Before rebuilding, `git add` the new file** — the flake ignores untracked
files (see memory `new-nix-files-git-add`). Then apply with `rebuild`.

### 3. Autostart KeePassXC under Hyprland
Add to the tracked, symlinked
[configs/wayland/hyprland/hyprland.conf](configs/wayland/hyprland/hyprland.conf)
near the other `exec-once` entries (lines ~33-51):

```
exec-once = keepassxc
```
KeePassXC can minimize to the system tray on close. **Verify waybar has a `tray`
module** in [configs/wayland/waybar/config](configs/wayland/waybar/config); if
not, either add it or disable "minimize to tray" so the window stays reachable.

### 4. (Optional, declarative) force-install the browser extension
Instead of installing KeePassXC-Browser by hand, drop a Chrome managed policy so
it's always present:
```nix
environment.etc."opt/chrome/policies/managed/keepassxc.json".text = builtins.toJSON {
  ExtensionInstallForcelist = [ "oboonakemofpalcgghocfoadofidjkkk;https://clients2.google.com/service/update2/crx" ];
};
```
(That ID is the official KeePassXC-Browser extension.) Skip if you'd rather
install it manually.

## Manual steps (not config — done once, by you)

1. **Create the vault:** open KeePassXC → new database → **password only**, a
   long passphrase. Save the `.kdbx` to a real location (e.g.
   `~/Sync/keepassxc/vault.kdbx`). **Do not commit it to /etc/nixos** — it's a
   secret binary blob. Back it up (Syncthing / encrypted cloud / external drive).
2. **Enable browser integration:** KeePassXC → Settings → Browser Integration →
   enable, tick **Chrome**. This writes the native-messaging manifest into
   `~/.config/google-chrome/NativeMessagingHosts/`. *Caveat:* after a major
   KeePassXC update the store path can go stale — just re-toggle this setting if
   autofill stops connecting.
3. **Migrate from Chrome:** `chrome://password-manager/passwords` → export to
   CSV → KeePassXC → Import → CSV. Then **delete the CSV** (plaintext!).
4. **Turn off Chrome's manager:** in Chrome password settings disable "Offer to
   save passwords" and "Auto Sign-in", and clear the saved passwords.
5. **Set up Bio passkeys:** run `ykman info` to confirm the key + its FIDO2 app,
   set a FIDO2 PIN and enroll your fingerprint via `ykman fido` (or Chrome's
   `chrome://settings/securityKeys`). Then on each supporting site (Google,
   GitHub, etc.) add the Bio as a passkey/security key.

## Backup & recovery — how and where

Three separate things must survive, and they are **not** stored together. The
Bio cannot hold any of them (it's an authenticator, not storage), so "back it up
to the YubiKey" is not an option here.

### A. The `.kdbx` vault file (encrypted blob)
Because it's already AES-encrypted, the file itself can sit in multiple places —
its safety equals your passphrase strength. Apply the **3-2-1 rule**: 3 copies,
2 media types, 1 kept offsite/offline.

- **Live sync (convenience, not a backup):** Syncthing between your machines —
  no third party. Turn on **File Versioning** so a deletion/corruption doesn't
  instantly propagate everywhere.
- **Offsite copy:** an encrypted cloud (Proton Drive, or `rclone crypt` to any
  provider). The kdbx is encrypted already; cloud-side encryption is just
  defense in depth.
- **Offline copy (hardware):** two USB flash drives — one at home, one kept
  elsewhere (work, family). Refresh every few months. For higher assurance use a
  **hardware-encrypted USB** (e.g. IronKey/Apricorn), though it's largely
  redundant given the kdbx is encrypted.
- In KeePassXC enable **Settings → enable "Backup database file before saving"**
  so it keeps a `.old` copy locally against corruption.

### B. The master passphrase (the real secret — no reset exists)
With a password-only vault, losing this means the vault is gone permanently.
Keep it **physical and offline**, never in a file next to the vault:

- **Memorize** a long diceware passphrase (6–7 words).
- **Paper** copy in a fireproof/waterproof safe or a bank safe-deposit box.
- For fire/water resilience, stamp it onto a **metal backup plate**
  (Cryptosteel / Billfodl — sold for crypto seed phrases, work fine for a
  passphrase).
- Optional split: store two halves in two locations so no single site exposes
  it (trades a little recoverability for secrecy).
- Never: in the kdbx itself, in plaintext on disk, in a note synced to a phone.

### C. Passkey recovery for the Bio (single authenticator = lockout risk)
The Bio is one device; if it's lost or broken you must still get into
passkey-only accounts:

- On **every** site, register a **second** authenticator — a phone/platform
  passkey, or a backup security key — at the same time you add the Bio.
- Save each site's **recovery/backup codes** into KeePassXC (and/or print them
  into the safe with the passphrase).

### Test it
Once a quarter, copy the `.kdbx` from a backup location to a scratch machine and
confirm it opens with the passphrase. An untested backup isn't a backup.

## Verification

- `rebuild` succeeds; `which keepassxc ykman` resolve.
- `ykman info` lists the Bio and shows **FIDO2** enabled.
- KeePassXC opens the vault with the passphrase; Browser Integration shows
  **Connected**; visiting a saved site triggers KeePassXC autofill (not Chrome's).
- Register the Bio as a passkey on a test account (e.g. GitHub security
  settings) and confirm fingerprint sign-in works end-to-end.
- KeePassXC autostarts on next Hyprland login and is reachable (tray or window).

## Notes / risks

- Recoverability of the vault, the passphrase, and passkeys is covered in
  **Backup & recovery** above — that section is the security model for a
  password-only vault, not an afterthought.
- **Future upgrade path (not now):** if you later want a hardware factor on the
  vault itself, a YubiKey 5-series (~$50) enables the classic password +
  Challenge-Response unlock, or the `.kdbx` could live in a Bio-unlocked LUKS
  container (`systemd-cryptenroll --fido2-device`).
