"""Rocks, ore deposits and boulders, modelled in Blender.   blender -b -P build_rocks.py -- <out_dir>

Deposit sites (about 10 m across, three variants each, scripts/deposit_art.gd): iron (rust-red boulders with ore seams), gold
(pale granite with gold nuggets and veins), silicon (grey sand-coloured rock with blue quartz clusters), uranium (dark rock with
green crystals), diamond (kimberlite with pale stones) and oil (a few grey rocks round the seep). And the scenery: single boulders and
groups (rock_boulder_N), a rock outcrop of layered slabs (rock_outcrop_N) and scree (rock_scree_N), scattered on the slopes
(scripts/env_rocks.gd). Every rock is a faceted, displaced icosphere with a flat bottom that reaches below the ground, so it
stands on any slope without a gap. Roles: rock (grey stone), rock_iron, rock_gold, rock_silicon, rock_uranium, rock_diamond,
gold (nuggets), crystal_silicon, crystal_uranium, crystal_diamond.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh
from mathutils import Matrix, Vector
from bl_kit import Model, P, hexc

out_dir = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
os.makedirs(out_dir, exist_ok=True)


def boulder(m, rng, role, x, z, sx, sy, sz, tint, yaw=None, y0=0.0, bottom=-0.9, lumps=(0.8, 1.18), strata=0.0):
    """A faceted boulder at ground point (x, z): an icosphere pushed in and out, flat underneath and sunk below the ground."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    push = {}
    for v in bm.verts:
        k = (round(v.co.x * 50), round(v.co.y * 50), round(v.co.z * 50))
        if k not in push:
            push[k] = rng.uniform(*lumps)
        f = push[k]
        c = Vector((v.co.x * sx * f, v.co.y * sz * f, v.co.z * sy * f))
        if strata:                                                              # layered stone: terraces up the sides
            c.z = round(c.z / strata) * strata * 0.5 + c.z * 0.5
        c.z = max(c.z, bottom)
        v.co = c
    yaw = rng.uniform(0, math.tau) if yaw is None else yaw
    mat = Matrix.Translation(P(x, y0, z)) @ Matrix.Rotation(yaw, 4, "Z")
    m.add(role, bm, mat, tint)
    bm.free()


def crystal(m, rng, role, x, z, h, r, tint, tilt=0.4):
    """A six-sided crystal: a prism with a pointed tip, leaning."""
    a = rng.uniform(0, math.tau)
    dx, dz = math.cos(a) * math.sin(tilt) * h, math.sin(a) * math.sin(tilt) * h
    base = (x, -0.2, z)
    top = (x + dx * 0.8, h * math.cos(tilt) * 0.85, z + dz * 0.8)
    tip = (x + dx, h * math.cos(tilt) + r * 1.6, z + dz)
    m.pipe(role, base, top, r, 6, tint=tint)
    m.pipe(role, top, tip, r, 6, tint=tint, r2=0.01)


def ring_positions(rng, n, rmin, rmax):
    out = []
    for i in range(n):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(rmin, rmax)
        out.append((math.cos(a) * r, math.sin(a) * r))
    return out


def lerp(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


# ------------------------------------------------------------------ the deposits
def iron(m, rng):
    cols = (hexc("e08a5a"), hexc("b5643c"))
    for (x, z) in ring_positions(rng, 12, 0.0, 4.6):
        s = rng.uniform(0.9, 2.3)
        boulder(m, rng, "rock_iron", x, z, s, s * rng.uniform(0.6, 0.9), s * rng.uniform(0.8, 1.2), lerp(cols[0], cols[1], rng.random()), strata=0.5)
    for (x, z) in ring_positions(rng, 6, 0.5, 4.2):                                 # ore seams: dark red-brown chunks on top
        s = rng.uniform(0.3, 0.6)
        boulder(m, rng, "rock_iron", x, z, s, s * 0.7, s * 1.3, hexc("7a3a22"), y0=rng.uniform(0.5, 1.4), bottom=-0.2)


def gold(m, rng):
    for (x, z) in ring_positions(rng, 9, 0.0, 4.4):
        s = rng.uniform(1.0, 2.4)
        boulder(m, rng, "rock_gold", x, z, s, s * 0.8, s, lerp(hexc("e6e0d4"), hexc("c9bfae"), rng.random()))
    for (x, z) in ring_positions(rng, 22, 0.3, 4.6):
        s = rng.uniform(0.22, 0.55)
        boulder(m, rng, "gold", x, z, s, s * 0.7, s * 1.4, hexc("e0b23c"), y0=rng.uniform(0.2, 1.2), bottom=-0.1, lumps=(0.85, 1.12))


def gems(m, rng, kind):
    base = {"silicon": hexc("d8d2c6"), "uranium": hexc("8c9a80"), "diamond": hexc("8b93a6")}[kind]
    for (x, z) in ring_positions(rng, 8, 1.0, 4.8):
        s = rng.uniform(0.7, 1.6)
        boulder(m, rng, "rock_" + kind, x, z, s, s * 0.7, s, tuple(c * (1.0 - rng.random() * 0.3) for c in base))
    n = 9 if kind == "diamond" else 7
    for c in range(n):
        cx, cz = ring_positions(rng, 1, 0.0, 3.2)[0]
        for k in range(rng.randint(3, 5)):
            h = rng.uniform(0.8, 2.2) * (0.6 if kind == "diamond" else 1.0)
            crystal(m, rng, "crystal_" + kind, cx + rng.uniform(-0.4, 0.4), cz + rng.uniform(-0.4, 0.4), h, rng.uniform(0.14, 0.3), (1, 1, 1))


def oil(m, rng):
    for k in range(4):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(3.5, 4.6)
        s = rng.uniform(0.5, 0.9)
        boulder(m, rng, "rock", math.cos(a) * r, math.sin(a) * r, s, s * 0.8, s, hexc("a39a90"))


# ------------------------------------------------------------------ the scenery
def boulder_single(m, rng):
    s = rng.uniform(1.1, 1.8)
    boulder(m, rng, "rock", 0.0, 0.0, s, s * rng.uniform(0.6, 0.9), s * rng.uniform(0.85, 1.15), lerp(hexc("a39a90"), hexc("8a847c"), rng.random()), strata=0.6)
    for k in range(rng.randint(1, 3)):
        a = rng.uniform(0, math.tau)
        r = s * rng.uniform(1.0, 1.5)
        t = s * rng.uniform(0.3, 0.5)
        boulder(m, rng, "rock", math.cos(a) * r, math.sin(a) * r, t, t * 0.7, t, lerp(hexc("a39a90"), hexc("7f7a72"), rng.random()), bottom=-0.5)


def boulder_group(m, rng):
    for (x, z) in ring_positions(rng, rng.randint(4, 6), 0.0, 2.6):
        s = rng.uniform(0.5, 1.5)
        boulder(m, rng, "rock", x, z, s, s * rng.uniform(0.6, 0.9), s * rng.uniform(0.8, 1.2), lerp(hexc("a8a096"), hexc("7a746c"), rng.random()), strata=0.5)


def outcrop(m, rng):
    """Layered slabs leaning together: a low cliff face, darker in the cracks."""
    n = rng.randint(5, 7)
    for k in range(n):
        x = (k - n / 2) * rng.uniform(1.0, 1.4)
        z = rng.uniform(-0.8, 0.8)
        w = rng.uniform(1.4, 2.2)
        h = rng.uniform(1.6, 3.8)
        boulder(m, rng, "rock", x, z, w, h, rng.uniform(0.9, 1.5), lerp(hexc("9c948a"), hexc("6f6a63"), rng.random()), yaw=rng.uniform(-0.4, 0.4), bottom=-1.2, lumps=(0.85, 1.12), strata=0.7)
    for k in range(4):
        boulder(m, rng, "rock", rng.uniform(-3.5, 3.5), rng.uniform(1.4, 2.4), 0.5, 0.4, 0.5, hexc("857f77"), bottom=-0.4)


def scree(m, rng):
    for (x, z) in ring_positions(rng, rng.randint(9, 13), 0.0, 3.4):
        s = rng.uniform(0.2, 0.6)
        boulder(m, rng, "rock", x, z, s, s * 0.6, s * 1.1, lerp(hexc("a8a096"), hexc("6f6a63"), rng.random()), bottom=-0.25)


MAKERS = [("dep_iron", iron, 3), ("dep_gold", gold, 3), ("dep_silicon", lambda m, r: gems(m, r, "silicon"), 3), ("dep_uranium", lambda m, r: gems(m, r, "uranium"), 3),
          ("dep_diamond", lambda m, r: gems(m, r, "diamond"), 3), ("dep_oil", oil, 2),
          ("rock_boulder", boulder_single, 4), ("rock_group", boulder_group, 3), ("rock_outcrop", outcrop, 3), ("rock_scree", scree, 2)]
for prefix, fn, count in MAKERS:
    for v in range(1, count + 1):
        name = "%s_%d" % (prefix, v)
        m = Model(name)
        rng = random.Random(sum(map(ord, prefix)) * 17 + v)
        fn(m, rng)
        m.finish(os.path.join(out_dir, name + ".glb"), smooth_angle=22.0)
