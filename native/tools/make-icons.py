"""Draws DOMINION's interface icons (resources and panels) with Pillow.

Each icon is drawn at 4x on a 256 px canvas and scaled down to 64 px, so edges
are smooth. Run from the repository root:  python native/tools/make-icons.py
The PNGs go to native/godot/ui/icons/ and are committed; nothing is downloaded.
"""
import math
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "godot", "ui", "icons")
S = 256
GOLD = (226, 190, 92, 255)
GOLD_D = (160, 124, 48, 255)
CREAM = (241, 227, 180, 255)
DARK = (22, 30, 34, 255)


def canvas():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def save(img, name):
    img.resize((64, 64), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))


def poly(d, pts, fill, outline=None, width=0):
    d.polygon([(x, y) for x, y in pts], fill=fill, outline=outline, width=width)


def star(cx, cy, r1, r2, n=5, rot=-math.pi / 2):
    return [(cx + (r1 if k % 2 == 0 else r2) * math.cos(rot + k * math.pi / n),
             cy + (r1 if k % 2 == 0 else r2) * math.sin(rot + k * math.pi / n)) for k in range(2 * n)]


def money():
    img, d = canvas()
    for i, off in enumerate([40, 20, 0]):
        d.ellipse([48, 150 - off - 36, 208, 150 - off + 36], fill=GOLD_D, outline=DARK, width=6)
        d.ellipse([48, 150 - off - 44, 208, 150 - off + 28], fill=GOLD, outline=DARK, width=6)
    d.ellipse([88, 76, 168, 124], outline=GOLD_D, width=8)
    save(img, "money")


def food():
    img, d = canvas()
    d.line([(128, 236), (128, 60)], fill=(196, 160, 72, 255), width=14)
    for i in range(5):
        y = 70 + i * 30
        for side in (-1, 1):
            cx = 128 + side * 30
            d.ellipse([cx - 22, y - 14, cx + 22, y + 22], fill=(232, 196, 96, 255), outline=(150, 110, 40, 255), width=5)
    d.ellipse([106, 30, 150, 78], fill=(232, 196, 96, 255), outline=(150, 110, 40, 255), width=5)
    save(img, "food")


def iron():
    img, d = canvas()
    for y, shade in ((150, (120, 128, 134, 255)), (100, (160, 168, 174, 255))):
        poly(d, [(40, y + 60), (216, y + 60), (186, y), (70, y)], shade, DARK, 6)
        poly(d, [(70, y), (186, y), (176, y - 12), (80, y - 12)], (200, 206, 210, 255), DARK, 4)
    save(img, "iron")


def oil():
    img, d = canvas()
    d.ellipse([58, 96, 198, 236], fill=(40, 44, 48, 255), outline=(10, 10, 12, 255), width=6)
    poly(d, [(128, 20), (62, 140), (194, 140)], (40, 44, 48, 255))
    d.ellipse([90, 140, 122, 172], fill=(120, 130, 140, 255))
    save(img, "oil")


def silicon():
    img, d = canvas()
    for i in range(5):
        x = 70 + i * 29
        for y0, y1 in ((32, 64), (192, 224)):
            d.rectangle([x - 6, y0, x + 6, y1], fill=(190, 196, 200, 255))
        for x0, x1 in ((32, 64), (192, 224)):
            d.rectangle([x0, x - 6, x1, x + 6], fill=(190, 196, 200, 255))
    d.rounded_rectangle([60, 60, 196, 196], radius=14, fill=(44, 92, 120, 255), outline=DARK, width=6)
    d.rounded_rectangle([92, 92, 164, 164], radius=8, fill=(120, 190, 220, 255))
    save(img, "silicon")


def uranium():
    img, d = canvas()
    d.ellipse([20, 20, 236, 236], fill=(210, 200, 60, 255), outline=DARK, width=8)
    for k in range(3):
        a0 = -90 + k * 120 - 30
        d.pieslice([44, 44, 212, 212], a0, a0 + 60, fill=DARK)
    d.ellipse([104, 104, 152, 152], fill=(210, 200, 60, 255))
    d.ellipse([114, 114, 142, 142], fill=DARK)
    save(img, "uranium")


def research():
    img, d = canvas()
    poly(d, [(104, 30), (152, 30), (152, 100), (216, 214), (40, 214), (104, 100)], (120, 190, 230, 255), DARK, 8)
    poly(d, [(80, 150), (176, 150), (206, 206), (50, 206)], (90, 220, 150, 255))
    d.rectangle([96, 22, 160, 36], fill=CREAM)
    for x, y, r in ((110, 180, 10), (140, 170, 7), (126, 192, 6)):
        d.ellipse([x - r, y - r, x + r, y + r], fill=(220, 255, 230, 255))
    save(img, "research")


def army():
    img, d = canvas()
    d.pieslice([40, 40, 216, 216], 180, 360, fill=(110, 124, 80, 255), outline=DARK, width=8)
    d.rectangle([30, 124, 226, 150], fill=(90, 102, 64, 255), outline=DARK, width=6)
    d.rectangle([100, 150, 156, 176], fill=(70, 80, 50, 255))
    save(img, "army")


def citizens():
    img, d = canvas()
    for cx, scale, col in ((84, 0.8, (170, 180, 190, 255)), (172, 0.8, (170, 180, 190, 255)), (128, 1.0, CREAM)):
        r = 30 * scale
        d.ellipse([cx - r, 96 - 40 * scale - r, cx + r, 96 - 40 * scale + r], fill=col, outline=DARK, width=5)
        d.pieslice([cx - 60 * scale, 110, cx + 60 * scale, 110 + 180 * scale], 180, 360, fill=col, outline=DARK, width=5)
    save(img, "citizens")


def land():
    img, d = canvas()
    d.rectangle([60, 30, 74, 230], fill=(180, 180, 172, 255))
    poly(d, [(74, 36), (206, 60), (170, 96), (206, 132), (74, 120)], (200, 70, 60, 255), DARK, 6)
    d.ellipse([40, 214, 96, 238], fill=(90, 120, 60, 255))
    save(img, "land")


def missile():
    img, d = canvas()
    poly(d, [(128, 16), (156, 70), (156, 196), (100, 196), (100, 70)], (220, 224, 228, 255), DARK, 6)
    poly(d, [(128, 16), (156, 70), (100, 70)], (200, 60, 50, 255))
    poly(d, [(100, 150), (60, 214), (100, 196)], (160, 60, 50, 255), DARK, 4)
    poly(d, [(156, 150), (196, 214), (156, 196)], (160, 60, 50, 255), DARK, 4)
    poly(d, [(108, 196), (148, 196), (128, 244)], (255, 170, 60, 255))
    save(img, "missile")


def supply():
    img, d = canvas()
    poly(d, [(100, 20), (156, 20), (230, 236), (26, 236)], (70, 74, 78, 255), DARK, 6)
    for y in (50, 110, 170):
        d.rectangle([122, y, 134, y + 34], fill=(240, 220, 120, 255))
    save(img, "supply")


def happiness():
    img, d = canvas()
    d.ellipse([28, 28, 228, 228], fill=GOLD, outline=DARK, width=8)
    d.ellipse([86, 88, 110, 118], fill=DARK)
    d.ellipse([146, 88, 170, 118], fill=DARK)
    d.arc([76, 100, 180, 190], 20, 160, fill=DARK, width=12)
    save(img, "happiness")


def diplomacy():
    img, d = canvas()
    poly(d, [(30, 120), (100, 80), (150, 100), (110, 150), (70, 170)], (220, 190, 150, 255), DARK, 6)
    poly(d, [(226, 120), (156, 80), (106, 100), (146, 150), (186, 170)], (190, 150, 110, 255), DARK, 6)
    d.rectangle([14, 100, 40, 160], fill=(70, 90, 140, 255))
    d.rectangle([216, 100, 242, 160], fill=(140, 60, 60, 255))
    save(img, "diplomacy")


def market():
    img, d = canvas()
    d.line([(128, 30), (128, 220)], fill=GOLD, width=12)
    d.line([(40, 70), (216, 70)], fill=GOLD, width=10)
    d.rectangle([90, 214, 166, 232], fill=GOLD)
    for cx in (56, 200):
        d.line([(cx, 70), (cx - 30, 150)], fill=GOLD_D, width=4)
        d.line([(cx, 70), (cx + 30, 150)], fill=GOLD_D, width=4)
        d.pieslice([cx - 40, 110, cx + 40, 190], 0, 180, fill=GOLD, outline=DARK, width=5)
    save(img, "market")


def intel():
    img, d = canvas()
    d.ellipse([20, 70, 236, 186], fill=CREAM, outline=DARK, width=8)
    d.ellipse([88, 88, 168, 168], fill=(60, 110, 140, 255), outline=DARK, width=6)
    d.ellipse([112, 112, 144, 144], fill=DARK)
    save(img, "intel")


def gear():
    img, d = canvas()
    poly(d, star(128, 128, 110, 84, 8, 0), (180, 186, 190, 255), DARK, 6)
    d.ellipse([78, 78, 178, 178], fill=(180, 186, 190, 255), outline=DARK, width=6)
    d.ellipse([106, 106, 150, 150], fill=DARK)
    save(img, "menu")


def build():
    img, d = canvas()
    poly(d, [(40, 140), (128, 60), (216, 140)], (190, 80, 60, 255), DARK, 6)
    d.rectangle([64, 140, 192, 224], fill=CREAM, outline=DARK, width=6)
    d.rectangle([110, 170, 146, 224], fill=(120, 90, 60, 255))
    save(img, "build")


def health():
    img, d = canvas()
    d.rounded_rectangle([96, 30, 160, 226], radius=10, fill=(210, 60, 60, 255), outline=DARK, width=6)
    d.rounded_rectangle([30, 96, 226, 160], radius=10, fill=(210, 60, 60, 255), outline=DARK, width=6)
    d.rectangle([100, 100, 156, 156], fill=(210, 60, 60, 255))
    save(img, "health")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for f in (money, food, iron, oil, silicon, uranium, research, army, citizens, land, missile, supply,
              happiness, diplomacy, market, intel, gear, build, health):
        f()
    print("icons written to native/godot/ui/icons")
