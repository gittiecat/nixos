
{ pkgs, ... }:
{
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "play_last" ''
      #!/usr/bin/env bash
      
      set -euo pipefail

      DIR="/home/bb99/Videos/OBS"
      mode="${1:-mtime}"
      [[ "${mode}" == "--name-ts" ]] && mode="name-ts"
      dry_run="no"
      [[ "${mode}" == "--dry-run" ]] && { dry_run="yes"; mode="mtime"; }

      video_find() {
        find "$DIR" -maxdepth 1 -type f \( \
          -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.webm' -o \
          -iname '*.avi' -o -iname '*.m4v' -o -iname '*.flv' -o -iname '*.ts' -o -iname '*.m3u8' \
        \)
      }

      pick_by_mtime() {
        video_find -printf '%T@ %p\n' | sort -nr | head -n1 | cut -d' ' -f2-
      }

      pick_by_ctime() {
        video_find -printf '%C@ %p\n' | sort -nr | head -n1 | cut -d' ' -f2-
      }

      extract_ts_sort_key() {
        local base="$1"
        if [[ "$base" =~ ([0-9]{4})[-_]?([0-9]{2})[-_]?([0-9]{2})[_-]([0-9]{2})([0-9]{2})([0-9]{2}) ]]; then
          printf "%s%s%s%s%s%s\n" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[4]}" "${BASH_REMATCH[5]}" "${BASH_REMATCH[6]}"; return
        fi
        if [[ "$base" =~ ([0-9]{8})[-_]?([0-9]{6}) ]]; then
          printf "%s%s\n" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"; return
        fi
        if [[ "$base" =~ ([0-9]{14}) ]]; then
          printf "%s\n" "${BASH_REMATCH[1]}"; return
        fi
        echo ""
      }

      pick_latest_by_name_ts() {
        mapfile -d '' -t files < <(video_find -print0)
        {
          for f in "${files[@]}"; do
            base="$(basename "$f")"
            key="$(extract_ts_sort_key "$base")"
            [[ -n "$key" ]] && printf "%s\t%s\n" "$key" "$f"
          done
        } | sort -r | head -n1 | cut -f2-
      }

      [[ -d "$DIR" ]] || { echo "Directory not found: $DIR"; exit 1; }

      latest=""
      case "$mode" in
        name-ts) latest="$(pick_latest_by_name_ts || true)" ;;
        mtime)   latest="$(pick_by_mtime || true)" ;;
        ctime)   latest="$(pick_by_ctime || true)" ;;
        *)       latest="$(pick_by_mtime || true)" ;;
      esac

      if [[ -z "${latest:-}" || ! -f "$latest" ]]; then
        echo "No matching videos in $DIR"
        exit 2
      fi

      echo "Latest recording: $latest"
      [[ "$dry_run" == "yes" ]] && exit 0

      mpv --no-config --really-quiet --vo=gpu-next --gpu-api=vulkan --hwdec=no -- "$latest"

    '')
  ];
}