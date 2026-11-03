#!/usr/bin/env python3
"""Centre Roadwarden's presplash on the 1280x720 panel.

The stock presplash is a 577x299 card (presplash_background + presplash_foreground).
Ren'Py blits it 1:1 at the top-left before the display is up, so on TSPS the logo
sits in the corner for the first seconds. Composite both layers at 1.6x into a
full-screen 1280x720 image; an empty foreground keeps Ren'Py from drawing the
old rock strip again.

Usage: python3 tools/fix-presplash.py /path/to/roadwarden/game
"""
import sys
from pathlib import Path
from PIL import Image

W, H, SCALE = 1280, 720, 1.6

g = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
bg, fg = g / "presplash_background.png", g / "presplash_foreground.png"
if not bg.exists():
    sys.exit(f"no {bg}")

card = Image.open(bg).convert("RGBA")
if fg.exists():
    card = Image.alpha_composite(card, Image.open(fg).convert("RGBA"))

cw, ch = int(card.width * SCALE), int(card.height * SCALE)
out = Image.new("RGBA", (W, H), (0, 0, 0, 255))
out.alpha_composite(card.resize((cw, ch), Image.Resampling.NEAREST), ((W - cw) // 2, (H - ch) // 2))

out.convert("RGB").save(bg)
Image.new("RGBA", (W, H), (0, 0, 0, 0)).save(fg)
print(f"presplash centred: {cw}x{ch} at {(W - cw) // 2},{(H - ch) // 2}")
