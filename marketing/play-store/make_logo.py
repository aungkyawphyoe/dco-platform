#!/usr/bin/env python3
"""Strip the white background from the AutoX logo (edge flood-fill only)."""
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "Logo-varient-main.png"
DST = Path(__file__).resolve().parent / "assets" / "logo.png"

im = Image.open(SRC).convert("RGBA")
w, h = im.size
px = im.load()


def is_bg(x: int, y: int) -> bool:
    r, g, b, _ = px[x, y]
    return r > 242 and g > 242 and b > 242


seen = bytearray(w * h)
q: deque[tuple[int, int]] = deque()

for x in range(w):
    for y in (0, h - 1):
        if is_bg(x, y) and not seen[y * w + x]:
            seen[y * w + x] = 1
            q.append((x, y))
for y in range(h):
    for x in (0, w - 1):
        if is_bg(x, y) and not seen[y * w + x]:
            seen[y * w + x] = 1
            q.append((x, y))

while q:
    x, y = q.popleft()
    px[x, y] = (0, 0, 0, 0)
    for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
        if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and is_bg(nx, ny):
            seen[ny * w + nx] = 1
            q.append((nx, ny))

# Downscale for the web page (keep 2x for crispness)
im = im.resize((512, 512), Image.LANCZOS)
im.save(DST)
print(f"saved {DST} ({w}x{h} -> 512x512)")
