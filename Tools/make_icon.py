"""Draws the app icon: one white hand-drawn line drawing on a flat dark-slate ground.

The drawing is the four PARA boxes as a 2x2 grid with the first one done: a tick
where the first box would be, and three rounded squares. It is drawn on the icon
library's 24-point grid with one 1.9 stroke, round ends and round corners, no fill,
and sits at 62 % of the tile.

Why (premium review round 5, icons-05, build 311): the icon before this had a
gradient ground, six colours, four filled tiles, a gold frame, a thin white frame
and a filled star, which blurred together at home-screen sizes and broke the house
rule for app icons: a FLAT calm background with ONE WHITE hand-drawn symbol, no
glow, no gradient, no transparency. The owner picked this drawing (option A) from
`findings/img/icons-appicon-options.png` in the review folder.

What it writes, into App/Paragon/Assets.xcassets/AppIcon.appiconset:
  icon-ios-1024.png   full-bleed square, RGB, no alpha (Apple refuses alpha)
  icon-mac-<n>.png    16 ... 1024, the same picture on a rounded tile inset 9.5 %
                      with a 22.5 % corner radius, clear outside the tile, no shadow
                      (the same Mac geometry the files have always had)

Run with `python3 Tools/make_icon.py` from the repo root (needs Pillow). This
script *is* the icon: it is the only place the icon is drawn, so change the icon
here and re-run, never by editing the PNGs.
"""
import os
from PIL import Image, ImageDraw

SLATE = (38, 45, 50)         # the flat ground, #262D32
WHITE = (255, 255, 255)

GRID = 24.0                  # the icon library's grid
STROKE = 1.9                 # its one line width, on that grid
GLYPH = 0.62                 # the 24-point grid's share of the tile's side

# The drawing, in grid points.
TICK = ((4.8, 8.6), (7.0, 10.9), (11.0, 6.1))
BOX_SIDE, BOX_CORNER = 6.2, 1.5
BOXES = ((13.6, 4.6), (4.2, 14.0), (13.6, 14.0))   # top-left corners
# The ink spans 4.6 ... 20.2 top to bottom, so its middle is 12.4, not 12: lift it
# 0.4 so the drawing sits dead centre on the tile.
LIFT = -0.4

MAC_INSET = 0.095            # clear margin around the Mac tile, of the canvas
CORNER = 0.225               # the Mac tile's corner radius, of the tile's side

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                   "App", "Paragon", "Assets.xcassets", "AppIcon.appiconset")


def glyph_mask(canvas, left, top, side):
    """The drawing as a white-on-black mask: `side` is the tile it is centred on."""
    m = Image.new("L", (canvas, canvas), 0)
    d = ImageDraw.Draw(m)
    k = side * GLYPH / GRID                       # pixels per grid point
    ox = left + side * (1 - GLYPH) / 2
    oy = top + side * (1 - GLYPH) / 2 + LIFT * k
    h = STROKE * k / 2                            # half the line width

    def dot(x, y):
        d.ellipse([ox + x * k - h, oy + y * k - h, ox + x * k + h, oy + y * k + h], fill=255)

    # the tick: two straight strokes with round ends and a round elbow
    d.line([(ox + x * k, oy + y * k) for x, y in TICK], fill=255, width=round(2 * h))
    for x, y in TICK:
        dot(x, y)

    # the three boxes: a rounded outline, drawn as an outer shape with its inside cut out
    for x, y in BOXES:
        x0, y0 = ox + x * k, oy + y * k
        x1, y1 = x0 + BOX_SIDE * k, y0 + BOX_SIDE * k
        d.rounded_rectangle([x0 - h, y0 - h, x1 + h, y1 + h], radius=BOX_CORNER * k + h, fill=255)
        d.rounded_rectangle([x0 + h, y0 + h, x1 - h, y1 - h], radius=max(BOX_CORNER * k - h, 0), fill=0)
    return m


def render(size, mac):
    """mac=True: the rounded tile with a clear margin (RGBA). False: the full-bleed iOS square (RGB)."""
    big = max(size * 4, 1024)                     # supersampled, then averaged down once (no ringing)
    if mac:
        inset = round(big * MAC_INSET)
        side = big - 2 * inset
    else:
        inset, side = 0, big
    glyph = glyph_mask(big, inset, inset, side).resize((size, size), Image.BOX)
    # Ground and drawing meet only through the mask, so the ground stays one flat colour.
    icon = Image.composite(Image.new("RGB", (size, size), WHITE),
                           Image.new("RGB", (size, size), SLATE), glyph)
    if mac:
        tile = Image.new("L", (big, big), 0)
        ImageDraw.Draw(tile).rounded_rectangle(
            [inset, inset, inset + side - 1, inset + side - 1], radius=round(side * CORNER), fill=255)
        icon.putalpha(tile.resize((size, size), Image.BOX))
    return icon


if __name__ == "__main__":
    for s in (16, 32, 64, 128, 256, 512, 1024):
        render(s, mac=True).save(os.path.join(OUT, f"icon-mac-{s}.png"))
    render(1024, mac=False).save(os.path.join(OUT, "icon-ios-1024.png"))
    print("icons written")
