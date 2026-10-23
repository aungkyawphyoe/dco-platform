#!/usr/bin/env bash
# Render the two subscription product icons (800x800, 32-bit RGBA PNG).
set -euo pipefail

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$DIR/out/sub-icons"
export OUT_DIR="$OUT"

mkdir -p "$OUT"
rm -f "$OUT"/autox-lite-*.png "$OUT"/autox-standard-*.png

for plan in lite standard; do
  "$CHROME" \
    --headless=new \
    --disable-gpu \
    --hide-scrollbars \
    --force-device-scale-factor=1 \
    --window-size=800,800 \
    --virtual-time-budget=15000 \
    --screenshot="$OUT/autox-$plan.png" \
    "file://$DIR/sub-icons.html?plan=$plan" 2>/dev/null
done

python3 - <<'EOF'
import os
from pathlib import Path
from PIL import Image

out = Path(os.environ["OUT_DIR"])
for p in sorted(out.glob("*.png")):
    Image.open(p).convert("RGBA").save(p)
    print("32-bit", p.name)
EOF
