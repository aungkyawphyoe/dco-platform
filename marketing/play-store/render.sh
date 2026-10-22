#!/usr/bin/env bash
# Render the four Google Play screenshot mockups (1080x1920 PNG).
set -euo pipefail

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
DIR="$(cd "$(dirname "$0")" && pwd)"
NAMES=(dashboard garage maintenance refuel)

for i in 0 1 2 3; do
  out="$DIR/out/play-store-$((i + 1))-${NAMES[$i]}.png"
  "$CHROME" \
    --headless=new \
    --disable-gpu \
    --hide-scrollbars \
    --force-device-scale-factor=1 \
    --window-size=1080,1920 \
    --virtual-time-budget=15000 \
    --screenshot="$out" \
    "file://$DIR/index.html?slide=$i" 2>/dev/null
  echo "wrote $out"
done
