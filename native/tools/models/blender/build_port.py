"""The Port, modelled in Blender.   blender -b -P build_port.py -- <out.glb>

A container quay: rubber fenders, bollards, three bays of corrugated containers stacked up to three high, two ship-to-shore
cranes on rails (one lifting a container over the water, trusses and all), a gabled warehouse with roller doors, a harbour
master's tower, mast lights and yard tractors. The water is on the +z side; the game turns the whole model to face it.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import container
from bl_harbour import quay, tower, mast_lights, tractor, beam, Q, CONC, CLAD, METAL, DARK, GLASS

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "port.glb"
m = Model("port")
rng = random.Random(4)
TEAL = hexc("2f6f7e")
PAINTS = [hexc(h) for h in ("8a3a2e", "2f5a78", "56703a", "a8782a", "c8c8c0", "6a2f50")]


def quay_crane(x, lifting):
    lxs = (x - 1.7, x + 1.7)
    for lx in lxs:
        for lz in (6.0, 8.2):
            m.box("paint", (lx - 0.17, Q + 0.3, lz - 0.17), (lx + 0.17, 8.6, lz + 0.17), bevel=0.02, seg=1, tint=TEAL)
            m.box("dark", (lx - 0.3, Q, lz - 0.3), (lx + 0.3, Q + 0.4, lz + 0.3), bevel=0.03, seg=1)     # the bogie
        m.box("paint", (lx - 0.15, 8.45, 5.85), (lx + 0.15, 8.75, 8.35), bevel=0.02, seg=1, tint=TEAL)
        beam(m, (lx, 1.8, 6.0), (lx, 7.4, 8.2), 0.05, "paint", TEAL)
        beam(m, (lx, 1.8, 8.2), (lx, 7.4, 6.0), 0.05, "paint", TEAL)
        beam(m, (lx, 3.0, 6.0), (lx, 3.0, 8.2), 0.06, "paint", TEAL)
        # the boom: top and bottom chords, posts and diagonals, out over the water; and the back reach
        beam(m, (lx, 9.0, 3.0), (lx, 9.5, 13.6), 0.09, "paint", TEAL)
        beam(m, (lx, 8.2, 6.0), (lx, 8.55, 13.6), 0.07, "paint", TEAL)
        for k in range(6):
            z0, z1 = 6.0 + k * 1.3, 7.3 + k * 1.3
            yt0, yt1 = 9.0 + (z0 - 3.0) * 0.047, 9.0 + (z1 - 3.0) * 0.047
            beam(m, (lx, yt0 - 0.85, z0), (lx, yt0, z0), 0.035, "paint", TEAL)
            beam(m, (lx, yt0 - 0.85, z0), (lx, yt1, z1), 0.03, "paint", TEAL)
        beam(m, (lx, 9.0, 3.0), (lx, 8.6, 6.0), 0.07, "paint", TEAL)
        beam(m, (lx, 9.0, 3.0), (lx, 7.0, 3.2), 0.04, "paint", TEAL)
    for z in (6.0, 8.2, 13.6):
        beam(m, (lxs[0], 9.0 + (z - 3.0) * 0.047, z), (lxs[1], 9.0 + (z - 3.0) * 0.047, z), 0.07, "paint", TEAL)
    m.box("paint", (x - 1.5, 9.1, 3.2), (x + 1.5, 10.5, 5.6), bevel=0.05, seg=1, tint=TEAL)             # the machinery house
    m.box(GLASS, (x - 1.4, 9.5, 5.58), (x + 1.4, 10.3, 5.64))
    m.box(CONC, (x - 1.6, 10.5, 3.1), (x + 1.6, 10.62, 5.7), bevel=0.02, seg=1)
    m.box(DARK, (x - 1.2, 7.7, 10.5), (x + 1.2, 8.2, 11.7), bevel=0.03, seg=1)                          # the trolley
    m.box("paint", (x - 2.9, 6.7, 10.7), (x - 2.2, 7.6, 11.5), bevel=0.03, seg=1, tint=hexc("3a4a54"))   # the driver's cab
    m.box(GLASS, (x - 2.88, 6.9, 11.48), (x - 2.22, 7.5, 11.54))
    drop = 2.8 if lifting else 6.2
    for cx in (-0.7, 0.7):
        m.pipe(DARK, (x + cx, 7.6, 11.1), (x + cx, drop + 0.3, 11.1), 0.02, 4)
    m.box(DARK, (x - 0.9, drop, 10.75), (x + 0.9, drop + 0.3, 11.45), bevel=0.02, seg=1)               # the spreader
    if lifting:
        container(m, x, 11.0, 0.0, PAINTS[3], 2.6, 1.1, 1.25, y0=drop - 1.25)
    m.cyl("glow_red", (x, 9.6, 13.6), 0.08, 0.3, 8)
    for lz in (6.0, 8.2):
        m.box(METAL, (-8.0, Q, lz - 0.05), (8.0, Q + 0.06, lz + 0.05))                                   # the crane rail
        for k in range(17):
            m.box(CONC, (-8.0 + k * 1.0 - 0.1, Q, lz - 0.2), (-8.0 + k * 1.0 + 0.1, Q + 0.03, lz + 0.2))


quay(m, True)
for bay in range(3):                                                                          # container stacks
    for col in range(2):
        for row in range(2):
            cx = -7.2 + bay * 2.9
            cz = -7.4 + col * 2.4 + row * 1.15
            for layer in range(1 + (bay + col + row) % 3):
                container(m, cx + 1.3, cz + 0.55, 0.0, PAINTS[rng.randrange(len(PAINTS))], 2.6, 1.1, 1.25, y0=Q + layer * 1.25)
quay_crane(-3.2, True)
quay_crane(3.4, False)

# the warehouse: corrugated cladding, a gable roof with seams, roller doors and vents
m.box(CLAD, (2.4, Q, -8.0), (7.8, 4.2, -2.2), bevel=0.03, seg=1)
for k in range(21):
    m.box(CLAD, (2.45 + k * 0.255, Q + 0.2, -2.2), (2.5 + k * 0.255, 4.0, -2.17), tint=(0.88, 0.88, 0.9))
for sgn in (-1, 1):                                                                           # the two roof planes
    zr = -5.1
    z_edge = -8.1 if sgn < 0 else -2.1
    m.hull(CONC, [(2.3, 4.2, z_edge), (7.9, 4.2, z_edge), (2.3, 4.2, zr), (7.9, 4.2, zr), (2.3, 5.35, zr), (7.9, 5.35, zr),
                  (2.3, 4.32, z_edge), (7.9, 4.32, z_edge)], tint=(0.9, 0.95, 1.0))
for k in range(9):
    for sgn in (-1, 1):
        z_edge = -8.1 if sgn < 0 else -2.1
        m.pipe(METAL, (2.4 + k * 0.62, 4.32, z_edge), (2.4 + k * 0.62, 5.38, -5.1), 0.025, 4)
m.box(DARK, (2.3, 5.35, -5.2), (7.9, 5.45, -5.0), bevel=0.02, seg=1)
for k in range(3):
    m.cyl(METAL, (3.6 + k * 1.8, 5.3, -6.6), 0.3, 0.4, 10)
    m.cyl(DARK, (3.6 + k * 1.8, 5.7, -6.6), 0.38, 0.06, 10)
for k in range(3):                                                                            # roller doors
    x0 = 2.8 + k * 1.7
    m.box("dark", (x0, Q, -2.2), (x0 + 1.4, 3.0, -2.15))
    for q in range(10):
        m.box(METAL, (x0 + 0.03, Q + 0.2 + q * 0.25, -2.15), (x0 + 1.37, Q + 0.2 + q * 0.25 + 0.1, -2.12))
    m.box(DARK, (x0, 3.0, -2.2), (x0 + 1.4, 3.15, -2.1), bevel=0.02, seg=1)
m.box("glow_warm", (3.2, 3.5, -2.17), (7.4, 3.58, -2.1))
tower(m, -6.8, 2.6)
mast_lights(m, [(-7.4, -1.0), (0.0, 2.6), (7.4, 2.6)])
tractor(m, -0.8, 4.4, math.pi / 2)
tractor(m, 5.4, 5.4, math.pi / 2)
m.finish(out)
