#!/usr/bin/env bash
# Render the Google Play store graphics from the Android screenshots:
#   - 5 phone screenshots, 1080x1920 PNG
#   - 1 feature graphic, 1024x500 PNG
set -euo pipefail

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$DIR/out"
export OUT_DIR="$OUT"

mkdir -p "$OUT"

NAMES=(dashboard maintenance expenses refuel garage)
for i in 0 1 2 3 4; do
  out="$OUT/play-store-$((i + 1))-${NAMES[$i]}.png"
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

"$CHROME" \
  --headless=new \
  --disable-gpu \
  --hide-scrollbars \
  --force-device-scale-factor=1 \
  --window-size=1024,500 \
  --virtual-time-budget=15000 \
  --screenshot="$OUT/feature-graphic.png" \
  "file://$DIR/feature.html" 2>/dev/null
echo "wrote $OUT/feature-graphic.png"

# Play requires 24-bit PNGs without transparency, at the exact sizes.
python3 - <<'EOF'
import os
from pathlib import Path
from PIL import Image

out = Path(os.environ["OUT_DIR"])
expected = {
    "feature-graphic.png": (1024, 500),
    **{f"play-store-{i}-{name}.png": (1080, 1920)
       for i, name in enumerate(
           ["dashboard", "maintenance", "expenses", "refuel", "garage"], start=1)},
}

for name, size in expected.items():
    path = out / name
    im = Image.open(path).convert("RGB")
    if im.size != size:
        raise SystemExit(f"{name}: expected {size}, got {im.size}")
    im.save(path, optimize=True)
    print(f"ok {name} {im.size[0]}x{im.size[1]} 24-bit")
EOF
