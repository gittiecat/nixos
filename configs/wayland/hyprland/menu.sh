#!/usr/bin/env bash
# Race-safe, debounced toggle for the wofi app launcher.
#
# Bound to a bare modifier (Super) release. On this machine Hyprland sees
# six keyboard devices (keychron, g-pro mouse, ACPI buttons, ...), so one
# physical tap can emit several release events within a few milliseconds.
# A naive "pgrep || wofi" loses that race (multiple wofis) and a naive
# "pkill wofi || wofi" flickers on close (kill then instant relaunch).
#
# The flock makes the decision atomic; the timestamp debounce collapses a
# single tap's burst into one toggle.
set -euo pipefail

lock=/tmp/wofi-menu.lock
stamp=/tmp/wofi-menu.stamp
debounce_ms=250

exec 9>"$lock"
flock -n 9 || exit 0            # another event is mid-toggle — ignore this one

now=$(date +%s%3N)
last=$(cat "$stamp" 2>/dev/null || echo 0)
if (( now - last < debounce_ms )); then
    exit 0                      # same physical tap, already handled
fi
printf '%s' "$now" > "$stamp"

# NixOS renames the binary to ".wofi-wrapped", so match both names exactly.
wofi_re='wofi|\.wofi-wrapped'
if pgrep -x "$wofi_re" >/dev/null; then
    pkill -x "$wofi_re"
else
    # 9>&- so the backgrounded child does NOT inherit the lock fd, otherwise
    # the lock would stay held for wofi's whole lifetime and block the close.
    setsid wofi --show drun -n >/dev/null 2>&1 9>&- &
fi
