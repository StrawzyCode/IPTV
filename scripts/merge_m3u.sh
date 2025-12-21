#!/usr/bin/env bash
set -euo pipefail

# Put your 3 playlist URLs here
URLS=(
  "https://raw.githubusercontent.com/BuddyChewChew/ppv/refs/heads/main/PPVLand.m3u8"
  "https://raw.githubusercontent.com/BuddyChewChew/My-Streams/refs/heads/main/Pixelsports.m3u8"
  "https://raw.githubusercontent.com/BuddyChewChew/My-Streams/refs/heads/main/Backup.m3u"
)

OUT="master.m3u"
TMP="$(mktemp -d)"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

echo "#EXTM3U" > "$OUT"

# Download and append each playlist (skipping its own #EXTM3U header lines)
i=0
for url in "${URLS[@]}"; do
  i=$((i+1))
  f="$TMP/list_$i.m3u"
  echo "Downloading $url"
  curl -fsSL "$url" -o "$f"

  # Remove possible BOM, drop #EXTM3U line(s), ensure newline at end
  sed -e '1s/^\xEF\xBB\xBF//' -e '/^#EXTM3U/d' "$f" >> "$OUT"
  echo "" >> "$OUT"
done

# Optional: remove exact duplicate stream URLs (simple but effective)
# Keeps first occurrence of each http(s) line and its preceding #EXTINF line.
awk '
  BEGIN { prev="" }
  /^https?:\/\// {
    if (!seen[$0]++) {
      if (prev != "") print prev
      print
    }
    prev=""
    next
  }
  { prev=$0 }
' "$OUT" > "$TMP/dedup.m3u"

# Rebuild final with header
{
  echo "#EXTM3U"
  # Remove any stray blank lines at the top
  awk 'NF{p=1} p' "$TMP/dedup.m3u"
} > "$OUT"

echo "Wrote $OUT"
