"""The trees, modelled in Blender.   blender -b -P build_trees.py -- <out_dir>

Seven species, two to three variants each, every one in a near and a far (..._far) version: birch, oak, Scots pine, spruce, poplar,
willow and a dead tree. Each is grown, not stacked: a tapering trunk with a flared root, limbs that fork off it and curve outward,
twigs, and the leaves as many small clumps hung on the ends of the twigs, so a crown has gaps, a ragged edge and light coming
through it. Metres, standing on the origin; roles are `wood` (bark) and `leaf` (every crown, tinted by vertex colour). The game
dresses them with shaders/tree_blender.gdshader and picks the species by height (scripts/env_trees.gd).
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc

out_dir = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
os.makedirs(out_dir, exist_ok=True)

GREENS = {"oak": ("2a4f20", "4a7430"), "birch": ("446f2a", "74a03e"), "pine": ("2a4636", "3f6040"), "spruce": ("1b3d2c", "2e5838"),
          "poplar": ("3a6428", "64903a"), "willow": ("587a3a", "86a64c")}


def mix(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(hexc(a), hexc(b)))


def vadd(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def vlerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t)


def unit(d):
    ln = math.sqrt(d[0] ** 2 + d[1] ** 2 + d[2] ** 2) or 1.0
    return (d[0] / ln, d[1] / ln, d[2] / ln)


class Tree:
    def __init__(self, m, rng, species, lod, bark):
        # lod 0 near, 1 mid (the same trees with cheaper primitives: a third of the triangles), 2 far (fewer limbs and clumps)
        self.m, self.rng, self.sp, self.far, self.bark = m, rng, species, lod == 2, bark
        self.low = lod >= 1

    def stem(self, pts, radii, bark=None):
        """A limb through the points, thickness tapering from radii[0] to radii[-1]."""
        n = len(pts) - 1
        for i in range(n):
            r0 = radii[0] + (radii[-1] - radii[0]) * i / n
            r1 = radii[0] + (radii[-1] - radii[0]) * (i + 1) / n
            self.m.pipe("wood", pts[i], pts[i + 1], r0, 5 if self.low else 8, tint=bark or self.bark, r2=r1)

    def curve(self, a, b, bend, steps=3):
        """Points from a to b bowed sideways by `bend` metres, so a limb is never a straight pole."""
        side = (self.rng.uniform(-1, 1), 0.0, self.rng.uniform(-1, 1))
        pts = []
        for i in range(steps + 1):
            p = vlerp(a, b, i / steps)
            k = math.sin(i / steps * math.pi) * bend
            pts.append((p[0] + side[0] * k, p[1], p[2] + side[2] * k))
        return pts

    def clump(self, c, r, t=None, flat=0.7):
        """A cluster of small leaf lumps round a point: a ragged tuft with the sky showing between."""
        lo, hi = GREENS[self.sp]
        n = 2 if self.far else self.rng.randint(3, 5)
        for k in range(n):
            a = self.rng.uniform(0, math.tau)
            d = r * self.rng.uniform(0.0, 0.8)
            p = (c[0] + math.cos(a) * d, c[1] + self.rng.uniform(-0.3, 0.3) * r, c[2] + math.sin(a) * d)
            tt = self.rng.random() if t is None else min(1.0, max(0.0, t + self.rng.uniform(-0.25, 0.25)))
            col = mix(lo, hi, tt)
            rr = r * self.rng.uniform(0.55, 0.95)
            self.m.geodome("leaf", p, rr, rr * flat, 1 if self.low else 2, tint=col, jitter=0.1)
            self.m.cyl("leaf", (p[0], p[1] - rr * 0.2, p[2]), rr * 0.9, rr * 0.25, 6 if self.low else 8, r2=rr * 0.4, tint=tuple(x * 0.5 for x in col))

    def twig(self, a, direction, length, depth, r0, leaf_r, tfrac):
        """A branch with `depth` more forks: it curves, may fork again, and ends in a tuft of leaves."""
        b = vadd(a, (direction[0] * length, direction[1] * length, direction[2] * length))
        r1 = max(r0 * 0.55, 0.015)
        self.stem(self.curve(a, b, length * 0.12, 2 if self.far else 3), (r0, r1))
        if depth > 0:
            forks = 1 if self.far else self.rng.randint(2, 3)
            for k in range(forks):
                at = vlerp(a, b, self.rng.uniform(0.45, 0.95))
                ang = self.rng.uniform(0, math.tau)
                spread = self.rng.uniform(0.5, 0.9)
                d = unit((direction[0] + math.cos(ang) * spread, direction[1] * 0.8 + self.rng.uniform(-0.1, 0.3), direction[2] + math.sin(ang) * spread))
                self.twig(at, d, length * self.rng.uniform(0.5, 0.75), depth - 1, r1 * 0.9, leaf_r * 0.9, tfrac)
        self.clump(b, leaf_r, tfrac)


def birch(m, rng, lod):
    far = lod == 2
    t = Tree(m, rng, "birch", lod, hexc("e4dfd2"))
    h = rng.uniform(8.5, 10.5)
    lean = (rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5))
    pts = [(lean[0] * (k / 4) ** 2, h * k / 4, lean[1] * (k / 4) ** 2) for k in range(5)]
    t.stem(pts, (0.2, 0.05))
    m.cyl("wood", (0, -0.1, 0), 0.3, 0.6, 7, r2=0.2, tint=hexc("4a443c"))                               # the dark rough base
    if not far:
        for k in range(9):                                                                          # sparse dark scars, uneven
            y = rng.uniform(1.0, h * 0.75)
            f = y / h
            ang = rng.uniform(0, math.tau)
            r = 0.2 - 0.15 * f
            cx, cz = lean[0] * f * f + math.cos(ang) * r, lean[1] * f * f + math.sin(ang) * r
            m.box("wood", (cx - 0.05, y, cz - 0.05), (cx + 0.05, y + rng.uniform(0.04, 0.09), cz + 0.05), tint=hexc("2a2622"))
    for k in range(7 if not far else 4):                                                           # slender limbs rising from the upper trunk
        y = h * rng.uniform(0.42, 0.92)
        f = y / h
        at = (lean[0] * f * f, y, lean[1] * f * f)
        a = rng.uniform(0, math.tau)
        d = unit((math.cos(a) * 0.8, rng.uniform(0.5, 0.9), math.sin(a) * 0.8))
        t.twig(at, d, rng.uniform(1.8, 2.8) * (1.15 - 0.4 * f), 1, 0.05, rng.uniform(0.7, 1.0), rng.uniform(0.3, 0.9))
    top = pts[-1]
    t.clump((top[0], h + 0.4, top[2]), 1.0, 0.9)


def oak(m, rng, lod):
    far = lod == 2
    t = Tree(m, rng, "oak", lod, hexc("4a3f35"))
    h = rng.uniform(9.0, 11.0)
    lean = (rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3))
    fork = rng.uniform(2.4, 3.2)
    t.stem([(0, 0, 0), (lean[0] * 0.5, fork * 0.5, lean[1] * 0.5), (lean[0], fork, lean[1])], (0.5, 0.38))
    m.cyl("wood", (0, -0.15, 0), 0.8, 0.7, 8, r2=0.5, tint=hexc("3e352d"))                              # the flared root
    if not far:
        for k in range(4):                                                                          # root buttresses
            a = math.tau * k / 4 + rng.uniform(-0.3, 0.3)
            t.stem([(math.cos(a) * 0.9, 0.0, math.sin(a) * 0.9), (math.cos(a) * 0.45, 0.5, math.sin(a) * 0.45)], (0.12, 0.06))
    top = (lean[0], fork, lean[1])
    n = 4
    for k in range(n):                                                                              # the great limbs
        a = math.tau * k / n + rng.uniform(-0.4, 0.4)
        d = unit((math.cos(a), rng.uniform(0.55, 0.9), math.sin(a)))
        t.twig(top, d, rng.uniform(3.2, 4.2), 1, 0.28, rng.uniform(1.3, 1.8), (k + rng.random()) / n)
    t.clump((top[0], h - 0.8, top[2]), 1.8, 0.85)


def pine(m, rng, lod):
    far = lod == 2
    t = Tree(m, rng, "pine", lod, hexc("7a4a32"))
    h = rng.uniform(12.0, 15.0)
    lean = (rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8))
    pts = [(lean[0] * (k / 5) ** 2, h * k / 5, lean[1] * (k / 5) ** 2) for k in range(6)]
    t.stem(pts, (0.32, 0.07))
    m.cyl("wood", (0, -0.1, 0), 0.42, 0.5, 8, r2=0.3, tint=hexc("4a3a30"))
    if not far:
        for k in range(8):                                                                          # dead stubs low on the trunk
            y = rng.uniform(1.5, h * 0.55)
            f = y / h
            a = rng.uniform(0, math.tau)
            at = (lean[0] * f * f, y, lean[1] * f * f)
            m.pipe("wood", at, vadd(at, (math.cos(a) * 0.9, 0.25, math.sin(a) * 0.9)), 0.05, 4, tint=hexc("4a3a30"), r2=0.02)
    for k in range(5 if not far else 3):                                                            # a few big flat-topped boughs near the top
        y = h * rng.uniform(0.66, 0.95)
        f = y / h
        at = (lean[0] * f * f, y, lean[1] * f * f)
        a = rng.uniform(0, math.tau)
        d = unit((math.cos(a) * 0.9, rng.uniform(0.1, 0.45), math.sin(a) * 0.9))
        t.twig(at, d, rng.uniform(2.0, 3.0) * (1.2 - 0.5 * f), 1, 0.09, rng.uniform(1.0, 1.4), rng.uniform(0.0, 1.0))
    t.clump((pts[-1][0], h + 0.2, pts[-1][2]), 1.3, 0.8, 0.6)


def spruce(m, rng, lod):
    far = lod == 2
    t = Tree(m, rng, "spruce", lod, hexc("4a3a30"))
    h = rng.uniform(11.5, 14.5)
    lean = (rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2))
    t.stem([(0, 0, 0), (lean[0] * 0.5, h * 0.5, lean[1] * 0.5), (lean[0], h, lean[1])], (0.26, 0.03))
    tiers = 7 if far else 15
    lo, hi = GREENS["spruce"]
    for k in range(tiers):
        f = k / (tiers - 1)
        y = 1.2 + f * (h - 1.9)
        r = (2.2 - f * 1.9) * rng.uniform(0.85, 1.12)
        col = mix(lo, hi, min(1.0, max(0.0, 0.1 + 0.7 * f + rng.uniform(-0.12, 0.12))))
        ox, oz = lean[0] * f + rng.uniform(-0.2, 0.2), lean[1] * f + rng.uniform(-0.2, 0.2)
        seg = 6 if lod else 9
        m.cyl("leaf", (ox, y, oz), r, 0.9 + (1 - f) * 0.5, seg, r2=0.05, tint=col)
        m.cyl("leaf", (ox, y - 0.3, oz), r * 0.98, 0.35, seg, r2=r * 0.6, tint=tuple(x * 0.55 for x in col))
        if not far:
            for b in range(5):                                                                      # bough tips hanging past the rim
                a = rng.uniform(0, math.tau)
                tip = (ox + math.cos(a) * r * 1.02, y - 0.55, oz + math.sin(a) * r * 1.02)
                m.pipe("leaf", (ox + math.cos(a) * r * 0.7, y - 0.1, oz + math.sin(a) * r * 0.7), tip, 0.1, 4, tint=col, r2=0.02)


def poplar(m, rng, lod):
    far = lod == 2
    t = Tree(m, rng, "poplar", lod, hexc("6a6252"))
    h = rng.uniform(12.0, 15.0)
    lean = (rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3))
    t.stem([(0, 0, 0), (lean[0] * 0.5, h * 0.5, lean[1] * 0.5), (lean[0], h, lean[1])], (0.26, 0.04))
    for k in range(9 if not far else 5):                                                            # short upswept limbs the whole way up
        y = 2.2 + (h - 3.0) * k / 8
        f = y / h
        at = (lean[0] * f, y, lean[1] * f)
        a = rng.uniform(0, math.tau)
        d = unit((math.cos(a) * 0.55, 1.0, math.sin(a) * 0.55))
        t.twig(at, d, rng.uniform(1.0, 1.6) * (1.1 - 0.5 * f), 1, 0.04, rng.uniform(0.7, 1.0), f)
    t.clump((lean[0], h + 0.2, lean[1]), 0.9, 0.9, 1.4)


def willow(m, rng, lod):
    far = lod == 2
    t = Tree(m, rng, "willow", lod, hexc("574a3a"))
    h = rng.uniform(8.0, 9.5)
    t.stem([(0, 0, 0), (0.1, 1.5, 0.0), (0.2, 2.4, 0.1)], (0.5, 0.36))
    m.cyl("wood", (0, -0.15, 0), 0.75, 0.6, 8, r2=0.5, tint=hexc("463c30"))
    top = (0.2, 2.4, 0.1)
    for k in range(4):
        a = math.tau * k / 4 + rng.uniform(-0.4, 0.4)
        d = unit((math.cos(a), rng.uniform(0.5, 0.9), math.sin(a)))
        L = rng.uniform(3.2, 4.0)
        a2 = vadd(top, (d[0] * L, d[1] * L, d[2] * L))
        t.stem(t.curve(top, a2, 0.4), (0.24, 0.1))
        t.clump(vadd(a2, (0, 0.4, 0)), 1.5, rng.random(), 0.6)
        for s in range(5 if far else 12):                                                           # long hanging strands
            ang = rng.uniform(0, math.tau)
            r = rng.uniform(0.2, 1.3)
            st = (a2[0] + math.cos(ang) * r, a2[1] - 0.1, a2[2] + math.sin(ang) * r)
            en = (st[0] + rng.uniform(-0.15, 0.15), max(0.8, st[1] - rng.uniform(2.6, 4.6)), st[2] + rng.uniform(-0.15, 0.15))
            m.pipe("leaf", st, en, 0.09 if not far else 0.14, 4, tint=mix(*GREENS["willow"], rng.random()), r2=0.025)
    t.clump((0.2, h - 1.2, 0.1), 2.0, 0.8, 0.6)


def dead(m, rng, lod):
    far = lod == 2
    t = Tree(m, rng, "oak", lod, hexc("6a645a"))
    h = rng.uniform(6.0, 8.0)
    lean = (rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6))
    t.stem([(0, 0, 0), (lean[0] * 0.4, h * 0.5, lean[1] * 0.4), (lean[0], h, lean[1])], (0.34, 0.04))
    for k in range(5 if far else 9):
        y = rng.uniform(h * 0.3, h * 0.92)
        f = y / h
        at = (lean[0] * f, y, lean[1] * f)
        a = rng.uniform(0, math.tau)
        d = unit((math.cos(a), rng.uniform(0.1, 0.7), math.sin(a)))
        L = rng.uniform(1.0, 2.0)
        e = vadd(at, (d[0] * L, d[1] * L, d[2] * L))
        t.stem(t.curve(at, e, 0.2, 2), (0.1, 0.025))
        if not far and k % 2 == 0:
            m.pipe("wood", e, vadd(e, (d[0] * 0.8, 0.5, d[2] * 0.8)), 0.04, 4, tint=hexc("6a645a"), r2=0.012)


MAKERS = {"birch": (birch, 3), "oak": (oak, 3), "pine": (pine, 3), "spruce": (spruce, 3), "poplar": (poplar, 2), "willow": (willow, 2), "dead": (dead, 2)}
for species, (fn, count) in MAKERS.items():
    for v in range(1, count + 1):
        for lod, suffix in ((0, ""), (1, "_mid"), (2, "_far")):
            name = "tree_%s_%d%s" % (species, v, suffix)
            m = Model(name)
            rng = random.Random(sum(map(ord, species)) + v * 31)
            fn(m, rng, lod)
            m.finish(os.path.join(out_dir, name + ".glb"))
