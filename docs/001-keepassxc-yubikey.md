# KeePassXC + YubiKey Bio — password & passkey setup (final)

> Living reference for how passwords, passkeys, and the YubiKey Bio are set up
> on this machine. Reflects the decisions we actually landed on, including the
> rough edges discovered during setup.

## Final decisions (TL;DR)

- **Hardware:** only a **YubiKey Bio** (FIDO Edition). No 5-series, so **no
  HMAC-SHA1 Challenge-Response** and **no OATH/TOTP** are available on the key.
- **Vault:** **KeePassXC, password-only** — no key file, no hardware key. The
  Bio *cannot* unlock the vault (KeePassXC only supports Challenge-Response;
  FIDO2 `hmac-secret` is still unmerged as of 2.7.12, issue
  [#3560](https://github.com/keepassxreboot/keepassxc/issues/3560)).
- **No LUKS container.** We considered wrapping the `.kdbx` in a Bio-unlocked
  LUKS volume for an at-rest hardware factor, but **decided against it** —
  encrypted-USB backups + a strong master passphrase are sufficient for this
  threat model.
- **Browser passwords:** KeePassXC-Browser extension replaces Chrome's built-in
  password manager (autofill).
- **Passkeys:** stored in the **KeePassXC vault by default** (the extension is
  itself a passkey provider), **and** the **Bio is registered as an additional
  passkey** on important accounts. The two are mutual backups — see
  [Passkeys](#passkeys--how-they-work-here).
- **Vault stays running:** KeePassXC minimizes to the Waybar tray on window
  close so the browser extension never loses its connection.

## How authentication works

### Lane 1 — KeePassXC vault → Chrome autofill (password sites)

```
  You ── master passphrase ──▶ ┌───────────┐
                               │ KeePassXC │ ── decrypts ──▶ vault.kdbx
                               └─────┬─────┘                 (local + USB backups)
                                     │ KeePassXC-Browser
                                     │ (native messaging proxy)
                                     ▼
                              ┌──────────────┐
                              │ Google Chrome│ ── autofills user/pass ──▶ website
                              └──────────────┘
```

### Lane 2 — Passkeys: vault is primary, Bio is the backup

```
  Website: "sign in with a passkey / security key"
        │
        ▼
  ┌──────────────┐
  │ Google Chrome│
  └──────┬───────┘
         │  KeePassXC-Browser intercepts WebAuthn (it's a passkey provider)
         ▼
   ┌───────────────┐   default path    ╔════════════════════════════╗
   │   KeePassXC   │ ───────────────▶  ║ passkey stored in vault.kdbx║  (unlocked vault = auth)
   └───────────────┘                   ╚════════════════════════════╝
         │
         │  break-glass: disable extension passkey support, then Chrome's
         │  native dialog → "USB security key" →
         ▼
   ┌───────────────┐   ── touch + fingerprint (UV) ──▶  logged in
   │  YubiKey Bio  │   hardware-bound passkey, used when the vault isn't
   └───────────────┘   available or as a deliberate stronger factor
```

**Mental model:** KeePassXC covers password sites and is also the *default*
passkey authenticator (because the vault is backed up and synced, there's no
lockout risk). The Bio is registered as a **second** passkey on accounts that
matter, so either one can get you in if the other is gone.

## What's configured in this NixOS repo

| Where | What |
|---|---|
| [modules/security/yubikey.nix](../modules/security/yubikey.nix) | `keepassxc` + `yubikey-manager` packages, FIDO2 udev rules (`services.udev.packages`), and a Chrome managed policy that force-installs the KeePassXC-Browser extension for all Chrome users on the host. |
| [configuration.nix](../configuration.nix) (`imports`) | Imports the security module under the `#security` heading. |
| [configs/wayland/hyprland/hyprland.conf](../configs/wayland/hyprland/hyprland.conf) | `exec-once = keepassxc &` autostart. |
| [configs/wayland/waybar/config](../configs/wayland/waybar/config) | Already has a `tray` module, so the minimized KeePassXC icon appears in the bar. |

> ⚠️ New `.nix` files must be `git add`ed before `rebuild` — the flake ignores
> untracked files.

## KeePassXC app settings (stateful — set once in the GUI)

These live in `~/.config/keepassxc/keepassxc.ini`, not in Nix.

- **Settings → General:**
  - ✅ Show a system tray icon
  - ✅ Minimize instead of app exit when closing the window  ← keeps it running
  - ✅ Hide window to system tray instead of app exit
  - ✅ Minimize window at application startup (so autostart launches it hidden)
- **Settings → Browser Integration:** enabled, **Chrome** ticked.
- **Settings → Security:** keep auto-lock on inactivity / session lock, and
  "clear clipboard after N seconds" enabled (see best practices below).

## One-time setup & migration (done)

1. **Create vault:** new database → **password only**, strong passphrase. Saved
   outside `/etc/nixos`; **not** committed to git.
2. **Browser integration / association:** enable in KeePassXC, then click the
   extension's **Connect** button once → approve the association in KeePassXC
   (this is what fixes *"Current database is not connected"* — see gotchas).
3. **Migrate from Chrome:** `chrome://password-manager/passwords` → Export CSV →
   KeePassXC Import → **delete the CSV** (plaintext!).
4. **Disable Chrome's manager:** turned off "Offer to save passwords" and
   "Auto Sign-in"; cleared stored passwords.
5. **Bio FIDO2:** set a FIDO2 PIN and enrolled a fingerprint via `ykman`.

## Passkeys — how they work here

Things that tripped us up, documented so future-me doesn't repeat them:

- **There is no "biometric" option on websites.** A site only sees a FIDO2
  authenticator. The fingerprint is **on-device user verification (UV)**, done
  by touching the Bio — not something you select in the site's UI.
- **Registering the Bio when KeePassXC is intercepting:** the KeePassXC-Browser
  extension grabs every WebAuthn request, so to put a passkey **on the Bio** you
  must temporarily **untick "Enable Passkeys support"** in the extension's
  options, register via **Chrome's native dialog → "USB security key"** (touch
  Bio), then **re-enable** it.
- **"Current database is not connected":** means the extension reached the app
  but the open database isn't associated (or is locked). Fix: unlock the DB →
  click the extension → **Connect** → approve in KeePassXC. (Native messaging
  itself was fine — the running `keepassxc-proxy` confirmed it.)
- **Both passkeys registered = mutual backup.** Sites allow multiple passkeys.
  Day-to-day KeePassXC offers its vault passkey first; to *deliberately* use the
  Bio you toggle the extension's passkey support off for that moment — so treat
  the **Bio as break-glass**, not the everyday path.
- **FIDO2 PIN lockout (important):** ~3 wrong PINs in a row blocks the key until
  replug; **8 wrong total permanently locks the FIDO2 app and wipes its
  credentials** (requires a FIDO2 reset, destroying every passkey on the key).
  Know the PIN.

## Service-specific notes

- **GitHub:** Settings → Password and authentication → **Passkeys** (passwordless)
  or Security keys (2FA). Bio registered as a backup alongside the vault passkey.
- **AWS:** **Console** sign-in supports FIDO2 security keys for MFA (root + IAM,
  up to **8 MFA devices** — register a backup!). The Bio works there. **Gap:**
  AWS **CLI/API MFA uses TOTP**, which the Bio can't produce (no OATH app), so
  CLI MFA needs an authenticator app or a YubiKey 5.

## Security model — what actually protects what

- **The `.kdbx` is encrypted at rest (AES-256 + Argon2/KDBX4).** A stolen USB is
  just an encrypted blob — **its safety equals the master passphrase strength**,
  because an attacker with the file can brute-force it **offline** (no rate
  limit, GPU speed). Strong passphrase + Argon2 → infeasible. Weak/reused
  passphrase → crackable regardless of encryption.
- **At-rest ≠ live machine.** Encryption does nothing while the vault is
  *unlocked* on a running machine — keyloggers, memory scraping, and clipboard
  sniffing are the live-machine threats. Different problem, addressed below.
- **Why no LUKS container:** it would have added a real "something you have"
  (Bio) factor *at rest*, but at the cost of a two-step unlock, a second
  recovery secret to guard, and lockout risk. Not worth it here; a strong
  passphrase carries the at-rest case.

## Best practices: storing secrets (READ THIS BEFORE STASHING ANYTHING)

The single rule everything else derives from: **never store the thing that
unlocks the vault inside (or beside) the vault, and never store any plaintext
secret where the machine or git can leak it.**

### What is "tier-0" vs "in-vault"
- **Tier-0 secrets (the keys to the kingdom)** — the **master passphrase**, the
  Bio's **FIDO2 PIN**, and any account **recovery codes that bypass the vault**.
  These must live **offline and physical only**, never on the live machine and
  never inside the vault they could unlock (circular dependency).
- **In-vault secrets** — everything else: site passwords, API keys, 2FA backup
  codes for individual accounts, software licenses. These belong **inside the
  encrypted vault** (and are therefore safe on the USB backups).

### On physical media (USB sticks, paper, metal)
- **The `.kdbx` on USB is fine** — it's encrypted. Apply **3-2-1**: ≥3 copies, 2
  media types, 1 offsite. Refresh the offline copies periodically.
- **A hardware-encrypted USB** (IronKey/Apricorn) is optional and largely
  redundant since the file is already encrypted — don't rely on it *instead* of
  a strong passphrase.
- **The master passphrase + FIDO2 PIN go on paper or a metal backup plate**
  (Cryptosteel/Billfodl for fire/water resistance), kept in a safe or
  safe-deposit box — **on different media from the `.kdbx`, ideally a different
  location.** Whoever holds *both* the USB and this paper holds everything, so
  keep them apart.
- **Do not** write the master passphrase on the same USB as the vault, on a
  sticky note at the desk, or in a phone "notes" app that syncs to the cloud.
- **Account recovery codes:** the per-site backup codes can live **in the
  vault** (encrypted) for convenience *and/or* printed into the safe. The one
  exception is recovery codes for whatever protects the vault/email-of-record —
  those are tier-0, paper-only.
- **Label discipline:** don't label the USB "passwords" or the paper "KeePassXC
  master." Anonymous is better.
- **Test restores quarterly:** copy a `.kdbx` from a backup USB to a scratch
  location and confirm it opens. An untested backup is not a backup.

### On the live machine
- **Never put tier-0 secrets in any file on disk** — not in dotfiles, not in
  `~/.bash_history`, not in environment variables, not in scripts, and
  **never in this Nix repo** (committed secrets are permanent in git history,
  and pushing publishes them).
- **Lock the vault when away:** rely on KeePassXC auto-lock (inactivity +
  session/screen lock). An unlocked vault on an unattended machine defeats the
  whole scheme.
- **Prefer autofill/auto-type over manual copy:** it avoids the clipboard. When
  you must copy, keep **"clear clipboard after N seconds"** enabled so secrets
  don't linger (clipboard managers / `wl-clipboard` history can capture them).
- **Sync the encrypted file, not exports:** never leave a CSV/export lying
  around — delete it immediately and empty the trash.
- **FIDO2 PIN:** memorize it; mind the 8-attempt permanent lockout. Don't store
  it on the machine.
- **Keep the system patched and avoid running untrusted binaries** — at-rest
  encryption can't protect an unlocked vault from local malware.

### Quick reference — where does X go?

| Secret | Live machine | USB / encrypted backup | Paper / metal in safe |
|---|---|---|---|
| Site passwords, API keys | in vault (unlocked only when used) | inside `.kdbx` ✅ | — |
| Per-account 2FA backup codes | in vault | inside `.kdbx` ✅ | optional copy |
| **Master passphrase** | ❌ never | ❌ never | ✅ only here |
| **FIDO2 PIN** | ❌ never | ❌ never | ✅ only here |
| **`.kdbx` file itself** | working copy | ✅ (encrypted) | — |

## Backup & recovery summary

- **Vault file:** 3-2-1 across local + ≥2 USBs (one offsite); KeePassXC's
  "backup database before saving" keeps a local `.old`.
- **Master passphrase / FIDO2 PIN:** offline, physical, separate from the USB.
  No reset exists for the passphrase — lose it and the vault is gone.
- **Passkey redundancy:** every important account has the **vault passkey + Bio
  passkey** (+ printed recovery codes). Losing the Bio ≠ lockout.
- **Test restores quarterly.**

## Verification / health checks

- `ykman info` lists the Bio with **FIDO2** enabled.
- KeePassXC autostarts to the Waybar tray on login; closing the window minimizes
  (doesn't quit); extension shows **Connected** with the DB unlocked.
- A saved site triggers KeePassXC autofill; a passkey login works via the vault,
  and (after toggling extension passkey support off) via the Bio.

## Future upgrade path (if the threat model changes)

- A **YubiKey 5-series** would add: native KeePassXC **Challenge-Response**
  vault unlock (password + hardware factor), and **OATH-TOTP** for AWS CLI / any
  TOTP-only service the Bio can't cover.
- The **Bio-unlocked LUKS container** remains available if at-rest hardware
  protection ever becomes worth the extra complexity
  (`systemd-cryptenroll --fido2-device`).
