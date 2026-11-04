"""The trees, modelled in Blender.   blender -b -P build_trees.py -- <out_dir>

Seven species, three variants each, every one in a near and a far (…_far) version: birch (white bark with dark bands, light slim
crown), oak (a stout trunk with limbs, a broad crown of lumpy blobs), Scots pine (a tall bare trunk with a flat dark crown on top),
spruce (stacked drooping skirts), poplar (a narrow column), willow (a wide crown with hanging strands) and a dead tree. Metres,
standing on the origin; roles are `wood` (bark) and `leaf` (every crown, tinted by vertex colour). The game dresses them with
shaders/tree_blender.gdshader and picks the species by height and wetness (scripts/env_trees.gd).
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc

out_dir = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
os.makedirs(out_dir, exist_ok=True)

BARK = hexc("5a4636")
GREENS = {"oak": ("28501f", "3f6a2c"), "birch": ("3f6e2c", "628c3a"), "pine": ("2a4636", "3c5c40"), "spruce": ("1b3d2c", "2e5838"),
          "poplar": ("3a6428", "5e8a38"), "willow": ("55783a", "7a9a48")}


def mix(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(hexc(a), hexc(b)))


def blob(m, rng, species, x, y, z, r, flat=0.8, t=None, far=False):
    """A lumpy crown blob: a faceted dome, an inverted shallow one below it and a dark underside."""
    lo, hi = GREENS[species]
    t = rng.random() if t is None else t
    col = mix(lo, hi, min(1.0, max(0.0, t)))
    m.geodome("leaf", (x, y, z), r, r * flat, 1 if far else 2, tint=col, jitter=0.07)
    m.cyl("leaf", (x, y - r * 0.28, z), r * 0.92, r * 0.3, 7 if far else 9, r2=r * 0.5, tint=tuple(c * 0.55 for c in col))


def limb(m, a, b, r, far=False):
    m.pipe("wood", a, b, r, 5 if far else 7, tint=BARK, r2=r * 0.6)


def birch(m, rng, far):
    h = rng.uniform(8.0, 10.5)
    lean = rng.uniform(-0.25, 0.25)
    pts = [(0.0, 0.0, 0.0), (lean * 0.4, h * 0.35, 0.1 * lean), (lean * 0.9, h * 0.7, -0.15 * lean), (lean * 1.3, h * 0.92, 0.0)]
    for a, b, r in zip(pts, pts[1:], (0.24, 0.18, 0.11)):
        m.pipe("wood", a, b, r, 6, tint=hexc("e2ddd0"), r2=r * 0.75)
    if not far:
        for k in range(12):                                           # the dark bands of the bark
            y = 0.5 + k * 0.5
            if y < h * 0.8:
                f = y / (h * 0.7) if y < h * 0.7 else 1.0
                bx = lean * 0.9 * min(f, 1.0) * 0.8
                m.cyl("wood", (bx, y, 0.0), 0.26 - 0.1 * min(f, 1.0), 0.12, 7, tint=hexc("2c2824"))
    top = pts[-1]
    n = 4 if far else 7
    for k in range(n):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.2, 1.1)
        y = h * (0.5 + 0.46 * rng.random())
        blob(m, rng, "birch", top[0] * y / h + math.cos(a) * d, y, math.sin(a) * d, rng.uniform(0.9, 1.3), 0.95, y / h, far)
        if not far and k < 3:
            limb(m, (pts[2][0], h * 0.62, 0.0), (top[0] + math.cos(a) * d * 0.9, y - 0.4, math.sin(a) * d * 0.9), 0.05, far)


def oak(m, rng, far):
    h = rng.uniform(8.5, 11.0)
    lean = rng.uniform(-0.3, 0.3)
    m.pipe("wood", (0, 0, 0), (lean * 0.3, 2.2, 0.1 * lean), 0.42, 8, tint=BARK, r2=0.32)
    m.pipe("wood", (lean * 0.3, 2.2, 0.1 * lean), (lean, 4.0, 0), 0.32, 8, tint=BARK, r2=0.2)
    m.cyl("wood", (0, -0.05, 0), 0.62, 0.35, 7, r2=0.4, tint=BARK)                                      # a flared root
    n = 5 if far else 8
    for k in range(n):
        a = math.tau * k / n + rng.uniform(-0.3, 0.3)
        d = rng.uniform(1.2, 2.2) * (1.2 if k % 2 else 0.8)
        y = rng.uniform(5.0, h - 1.2)
        if not far and k < 5:
            limb(m, (lean * 0.8, 3.3 + rng.random(), 0), (math.cos(a) * d * 0.6 + lean, y - 1.0, math.sin(a) * d * 0.6), 0.14, far)
        blob(m, rng, "oak", math.cos(a) * d + lean, y, math.sin(a) * d, rng.uniform(1.2, 1.8), 0.75, (y - 4.5) / (h - 4.5), far)
    blob(m, rng, "oak", lean, h - 1.2, 0, rng.uniform(1.5, 1.9), 0.85, 0.9, far)


def pine(m, rng, far):
    h = rng.uniform(11.0, 14.0)
    lean = rng.uniform(-0.5, 0.5)
    pts = [(0.0, 0.0, 0.0), (lean * 0.3, h * 0.35, 0.0), (lean * 0.8, h * 0.7, 0.1 * lean), (lean, h * 0.95, 0.0)]
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        m.pipe("wood", a, b, (0.3, 0.22, 0.15)[i], 7, tint=hexc("7a4a30") if i == 2 else hexc("5a4030"), r2=(0.22, 0.15, 0.08)[i])
    if not far:
        for k in range(6):                                                     # dead stubs low on the trunk
            a = rng.uniform(0, math.tau)
            y = rng.uniform(2.0, h * 0.5)
            m.pipe("wood", (lean * y / h, y, 0), (lean * y / h + math.cos(a) * 0.8, y + 0.3, math.sin(a) * 0.8), 0.05, 4, tint=BARK, r2=0.02)
    n = 3 if far else 5
    for k in range(n):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.2, 1.6) if k else 0.0
        y = h * (0.72 + 0.26 * rng.random())
        blob(m, rng, "pine", lean + math.cos(a) * d, y, math.sin(a) * d, rng.uniform(1.4, 2.2), 0.5, rng.random(), far)


def spruce(m, rng, far):
    h = rng.uniform(11.0, 14.5)
    m.pipe("wood", (0, 0, 0), (0, h, 0), 0.22, 6, tint=BARK, r2=0.04)
    tiers = 6 if far else 10
    for k in range(tiers):
        f = k / (tiers - 1)
        y = 1.4 + f * (h - 2.2)
        r = (1.9 - f * 1.6) * rng.uniform(0.9, 1.1)
        col = mix(*GREENS["spruce"], 0.15 + 0.6 * f + rng.uniform(-0.1, 0.1))
        ox, oz = rng.uniform(-0.12, 0.12), rng.uniform(-0.12, 0.12)
        m.cyl("leaf", (ox, y, oz), r, 1.3 + (1 - f) * 0.5, 7 if far else 10, r2=0.06, tint=col)
        m.cyl("leaf", (ox, y - 0.18, oz), r * 0.95, 0.2, 7 if far else 10, r2=r * 0.55, tint=tuple(c * 0.5 for c in col))


def poplar(m, rng, far):
    h = rng.uniform(11.0, 14.0)
    m.pipe("wood", (0, 0, 0), (0, 3.0, 0), 0.22, 6, tint=hexc("6a6252"), r2=0.15)
    n = 4 if far else 6
    for k in range(n):
        f = k / (n - 1)
        r = 0.85 + math.sin(f * math.pi) * 0.7
        blob(m, rng, "poplar", rng.uniform(-0.25, 0.25), 2.6 + f * (h - 3.4), rng.uniform(-0.25, 0.25), r, 1.5, f, far)


def willow(m, rng, far):
    h = rng.uniform(7.5, 9.0)
    m.pipe("wood", (0, 0, 0), (0.2, 2.2, 0), 0.45, 8, tint=hexc("574a3a"), r2=0.34)
    for k in range(3):
        a = math.tau * k / 3 + rng.uniform(-0.4, 0.4)
        limb(m, (0.2, 2.1, 0), (math.cos(a) * 1.5, 4.6, math.sin(a) * 1.5), 0.2, far)
    for k in range(3 if far else 5):
        a = math.tau * k / 5
        blob(m, rng, "willow", math.cos(a) * 1.7, h - 1.2 - rng.random(), math.sin(a) * 1.7, rng.uniform(1.6, 2.1), 0.7, rng.random(), far)
    blob(m, rng, "willow", 0.0, h - 0.3, 0.0, 2.2, 0.7, 0.8, far)
    n = 8 if far else 18
    for k in range(n):                                                       # the hanging strands
        a = math.tau * k / n + rng.uniform(-0.1, 0.1)
        rr = rng.uniform(2.4, 3.1)
        top = (math.cos(a) * rr * 0.75, h - 1.6, math.sin(a) * rr * 0.75)
        m.pipe("leaf", top, (math.cos(a) * rr, rng.uniform(1.0, 2.4), math.sin(a) * rr), 0.07 if not far else 0.12, 4, tint=mix(*GREENS["willow"], rng.random()), r2=0.025)


def dead(m, rng, far):
    h = rng.uniform(6.0, 8.0)
    lean = rng.uniform(-0.6, 0.6)
    col = hexc("6a645a")
    m.pipe("wood", (0, 0, 0), (lean * 0.4, h * 0.5, 0), 0.32, 6, tint=col, r2=0.2)
    m.pipe("wood", (lean * 0.4, h * 0.5, 0), (lean, h, 0.1), 0.2, 6, tint=col, r2=0.04)
    for k in range(4 if far else 8):
        a = rng.uniform(0, math.tau)
        y = rng.uniform(h * 0.35, h * 0.9)
        x0 = lean * y / h
        e = (x0 + math.cos(a) * rng.uniform(1.0, 2.0), y + rng.uniform(0.6, 1.5), math.sin(a) * rng.uniform(1.0, 2.0))
        m.pipe("wood", (x0, y, 0), e, 0.09, 5, tint=col, r2=0.025)
        if not far and k < 4:
            m.pipe("wood", ((x0 + e[0]) / 2, (y + e[1]) / 2, e[2] / 2), (e[0] + rng.uniform(-0.7, 0.7), e[1] + 0.7, e[2] + rng.uniform(-0.7, 0.7)), 0.04, 4, tint=col, r2=0.015)


MAKERS = {"birch": (birch, 3), "oak": (oak, 3), "pine": (pine, 3), "spruce": (spruce, 3), "poplar": (poplar, 2), "willow": (willow, 2), "dead": (dead, 2)}
for species, (fn, count) in MAKERS.items():
    for v in range(1, count + 1):
        for far in (False, True):
            name = "tree_%s_%d%s" % (species, v, "_far" if far else "")
            m = Model(name)
            rng = random.Random(sum(map(ord, species)) + v * 31)
            fn(m, rng, far)
            m.finish(os.path.join(out_dir, name + ".glb"))
