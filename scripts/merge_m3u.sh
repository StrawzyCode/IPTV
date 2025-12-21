#!/usr/bin/env bash
set -euo pipefail

URLS=(
  "https://raw.githubusercontent.com/BuddyChewChew/ppv/refs/heads/main/PPVLand.m3u8"
  "https://raw.githubusercontent.com/BuddyChewChew/My-Streams/refs/heads/main/Pixelsports.m3u8"
  "https://raw.githubusercontent.com/BuddyChewChew/My-Streams/refs/heads/main/Backup.m3u"
  "https://raw.githubusercontent.com/BuddyChewChew/My-Streams/refs/heads/main/StreamedSU.m3u8"
)

OUT="master.m3u"
TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# Start fresh
echo "#EXTM3U" > "$OUT"

i=0
for url in "${URLS[@]}"; do
  i=$((i+1))
  f="$TMP/list_$i.m3u"

  echo "Downloading $url"
  curl -fsSL "$url" -o "$f"

  # Remove UTF-8 BOM on first line if present, and remove ALL #EXTM3U headers
  # Then append to master
  sed -e '1s/^\xEF\xBB\xBF//' -e '/^#EXTM3U/d' "$f" >> "$OUT"

  # Ensure there's a newline between playlists
  echo "" >> "$OUT"
done

echo "Wrote $OUT"
wc -l "$OUT" || true
