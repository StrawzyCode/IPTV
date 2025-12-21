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
MERGED="$TMP/merged.m3u"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# Start a merged file (we'll sort it after)
: > "$MERGED"

i=0
for url in "${URLS[@]}"; do
  i=$((i+1))
  f="$TMP/list_$i.m3u"
  echo "Downloading $url"
  curl -fsSL "$url" -o "$f"

  # Remove UTF-8 BOM and remove any #EXTM3U header lines so we only have one at the top later
  sed -e '1s/^\xEF\xBB\xBF//' -e '/^#EXTM3U/d' "$f" >> "$MERGED"
  echo "" >> "$MERGED"
done

# Sort by category (group-title="...") while keeping the order of channels inside each category stable.
python3 - <<'PY' "$MERGED" "$OUT"
import re
import sys
from collections import defaultdict

inp = sys.argv[1]
outp = sys.argv[2]

group_re = re.compile(r'group-title="([^"]*)"')

# We store "entries" as blocks: any option lines + EXTINF line + one URL line
buckets = defaultdict(list)
uncat = "Uncategorised"

with open(inp, "r", encoding="utf-8", errors="replace") as f:
    lines = [ln.rstrip("\n") for ln in f]

i = 0
pending_opts = []

def add_entry(extinf_line, url_line, opts):
    m = group_re.search(extinf_line)
    group = (m.group(1).strip() if m else "") or uncat
    block = []
    block.extend(opts)
    block.append(extinf_line)
    block.append(url_line)
    buckets[group].append(block)

while i < len(lines):
    line = lines[i].strip()
    if not line:
        i += 1
        continue

    # Keep VLC opts / misc tags that apply to the next item
    if line.startswith("#") and not line.startswith("#EXTINF"):
        pending_opts.append(lines[i])
        i += 1
        continue

    if line.startswith("#EXTINF"):
        # Next non-empty line should be the stream URL
        j = i + 1
        while j < len(lines) and not lines[j].strip():
            j += 1
        if j < len(lines):
            add_entry(lines[i], lines[j], pending_opts)
            pending_opts = []
            i = j + 1
            continue
        else:
            # EXTINF with no URL; drop it
            pending_opts = []
            break

    # If we hit a non-comment, non-EXTINF line unexpectedly, just clear pending opts and move on
    pending_opts = []
    i += 1

# Write sorted output
with open(outp, "w", encoding="utf-8") as out:
    out.write("#EXTM3U\n")

    for group in sorted(buckets.keys(), key=lambda s: s.casefold()):
        # Optional: insert a comment header for each category
        out.write(f"\n# --- {group} ---\n")
        for block in buckets[group]:
            for ln in block:
                out.write(ln + "\n")
PY

echo "Wrote $OUT"
