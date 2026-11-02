"""Parts for the Blender-made civic buildings: the hex plaza with lawns, paths, trees and lamps; window banks; columns, pediments,
steps, hipped roofs, a clock tower, flags. Game coordinates; the plaza top is y 0.1."""
import math
from bl_kit import hexc

CONC = "wall_concrete"
STONE, PLASTER, BRICK, SLATE, TILE, COPPER = "stone", "plaster", "brick", "roof_slate", "roof_tile", "copper"
GLASS, METAL, DARK = "glass", "metal", "steel_dark"


def ground(m, lawns=True, pave=hexc("d8d4c8")):
    """The hex slab, a paved plaza and (optionally) four lawns cut by paths."""
    slab = [(math.cos(math.radians(30 + 60 * k)) * 12.3, math.sin(math.radians(30 + 60 * k)) * 12.3) for k in range(6)]
    m.polygon(CONC, slab, -1.6, 1.7)
    inner = [(math.cos(math.radians(30 + 60 * k)) * 11.6, math.sin(math.radians(30 + 60 * k)) * 11.6) for k in range(6)]
    m.polygon("pavers", inner, 0.1, 0.03, tint=pave)
    if lawns:
        for sx in (-1, 1):
            for z0, z1 in ((-9.0, -3.2), (3.8, 8.6)):
                pts = [(sx * 3.0, z0), (sx * 8.8, z0), (sx * 8.8, z1), (sx * 3.0, z1)]
                if z0 > 0:
                    pts = [(sx * 3.2, z0), (sx * 8.0, z0), (sx * 8.0, z1 - 1.0), (sx * 3.2, z1 - 1.0)]
                m.box(CONC, (min(p[0] for p in pts) - 0.12, 0.13, min(p[1] for p in pts) - 0.12), (max(p[0] for p in pts) + 0.12, 0.2, max(p[1] for p in pts) + 0.12), bevel=0.02, seg=1)
                m.box("turf", (min(p[0] for p in pts), 0.2, min(p[1] for p in pts)), (max(p[0] for p in pts), 0.24, max(p[1] for p in pts)), tint=hexc("5a8a46"))


def tree(m, x, z, h=2.0, s=1.0):
    m.cyl("wood", (x, 0.2, z), 0.16 * s, h, 7, r2=0.1 * s)
    m.dome("leaf", (x, 0.2 + h - 0.4, z), 1.2 * s, 1.1 * s, 10, 4, tint=hexc("3f6e3c"))
    m.dome("leaf", (x + 0.4 * s, 0.2 + h + 0.4, z + 0.2 * s), 0.8 * s, 0.85 * s, 8, 3, tint=hexc("4f8046"))


def lamp(m, x, z, h=3.6):
    m.pipe(DARK, (x, 0.13, z), (x, h, z), 0.04, 6)
    m.pipe(DARK, (x, h, z), (x + 0.4, h + 0.1, z), 0.03, 5)
    m.box("glow_warm", (x + 0.3, h - 0.04, z - 0.12), (x + 0.6, h, z + 0.12))
    m.cyl(DARK, (x, 0.13, z), 0.1, 0.25, 8)


def bench(m, x, z, yaw=0.0):
    m.box("wood", (x - 0.7, 0.45, z - 0.2), (x + 0.7, 0.5, z + 0.2), yaw=yaw, about=(x, 0, z))
    m.box("wood", (x - 0.7, 0.7, z - 0.22), (x + 0.7, 0.9, z - 0.18), yaw=yaw, about=(x, 0, z))
    for sx in (-0.6, 0.6):
        m.box(DARK, (x + sx - 0.03, 0.13, z - 0.18), (x + sx + 0.03, 0.5, z + 0.18), yaw=yaw, about=(x, 0, z))


def window(m, x, y, z, w=0.9, h=1.4, facing=1, frame="trim", arch=False):
    """A window on a wall facing +z (facing=1) or -z: a deep reveal, glass, mullions, a sill and a lintel."""
    m.box("dark", (x - w / 2, y, z - 0.02 * facing), (x + w / 2, y + h, z + 0.0))
    m.box(GLASS, (x - w / 2, y, z + 0.0), (x + w / 2, y + h, z + 0.03 * facing))
    m.box("wall_concrete", (x - w / 2 - 0.1, y - 0.08, z), (x + w / 2 + 0.1, y, z + 0.2 * facing), bevel=0.015, seg=1, tint=(1.5, 1.5, 1.45))          # sill
    m.box("wall_concrete", (x - w / 2 - 0.1, y + h, z), (x + w / 2 + 0.1, y + h + 0.12, z + 0.15 * facing), bevel=0.015, seg=1, tint=(1.5, 1.5, 1.45))   # lintel
    m.box("wall_concrete", (x - 0.025, y, z + 0.0), (x + 0.025, y + h, z + 0.06 * facing), tint=(1.6, 1.6, 1.55))
    m.box("wall_concrete", (x - w / 2, y + h * 0.62, z + 0.0), (x + w / 2, y + h * 0.62 + 0.04, z + 0.06 * facing), tint=(1.6, 1.6, 1.55))


def column(m, x, z, y0, y1, r=0.28, role=STONE):
    """A fluted column on a base with a capital."""
    m.box(role, (x - r * 1.5, y0, z - r * 1.5), (x + r * 1.5, y0 + 0.2, z + r * 1.5), bevel=0.03, seg=1)
    m.cyl(role, (x, y0 + 0.2, z), r, y1 - y0 - 0.5, 14, r2=r * 0.9)
    for k in range(10):
        a = math.tau * k / 10
        m.pipe("dark", (x + math.cos(a) * r * 0.97, y0 + 0.4, z + math.sin(a) * r * 0.97), (x + math.cos(a) * r * 0.9, y1 - 0.4, z + math.sin(a) * r * 0.9), 0.012, 3)
    m.box(role, (x - r * 1.4, y1 - 0.3, z - r * 1.4), (x + r * 1.4, y1, z + r * 1.4), bevel=0.04, seg=2)
    m.cyl(role, (x, y1 - 0.3, z), r * 1.05, 0.1, 14)


def pediment(m, x0, x1, y, z, rise, depth, role=STONE):
    """A triangular pediment over a portico with a tympanum, on a wall facing +z."""
    xm = (x0 + x1) / 2
    m.hull(role, [(x0, y, z), (x1, y, z), (xm, y + rise, z), (x0, y, z - depth), (x1, y, z - depth), (xm, y + rise, z - depth)])
    m.hull(role, [(x0 + 0.25, y + 0.15, z + 0.05), (x1 - 0.25, y + 0.15, z + 0.05), (xm, y + rise - 0.2, z + 0.05), (x0 + 0.25, y + 0.15, z - 0.2), (x1 - 0.25, y + 0.15, z - 0.2), (xm, y + rise - 0.2, z - 0.2)], tint=(0.85, 0.85, 0.85))
    m.box(role, (x0 - 0.15, y - 0.25, z - depth), (x1 + 0.15, y, z + 0.25), bevel=0.03, seg=1)      # the entablature
    m.hull(role, [(x0 - 0.2, y, z + 0.25), (x1 + 0.2, y, z + 0.25), (xm, y + rise + 0.1, z + 0.25), (x0 - 0.2, y, z + 0.1), (x1 + 0.2, y, z + 0.1), (xm, y + rise + 0.1, z + 0.1)], tint=(1.1, 1.1, 1.1))


def steps(m, x0, x1, z, n=5, rise=0.16, run=0.4, role=STONE):
    """A flight of steps rising towards the building at z (+z is down the flight); each tread a little wider than the one above."""
    for i in range(n):
        top = 0.1 + rise * (n - i)
        m.box(role, (x0 - i * 0.12, 0.1, z + i * run), (x1 + i * 0.12, top, z + (i + 1) * run), bevel=0.015, seg=1)


def hip_roof(m, x0, x1, z0, z1, y, rise, overhang=0.4, role=SLATE, ridge_len=None):
    """A hipped roof over x0..x1 and z0..z1 at height y, ridge along x."""
    a, b = x0 - overhang, x1 + overhang
    c, d = z0 - overhang, z1 + overhang
    inset = (d - c) / 2
    rl = ridge_len if ridge_len is not None else 0.0
    m.hull(role, [(a, y, c), (b, y, c), (a, y, d), (b, y, d), (a + inset, y + rise, (c + d) / 2), (b - inset, y + rise, (c + d) / 2)])
    m.box("wall_concrete", (a, y - 0.12, c), (b, y, d), bevel=0.03, seg=1, tint=(1.2, 1.2, 1.2))     # the eaves


def gable_roof(m, x0, x1, z0, z1, y, rise, overhang=0.35, role=SLATE):
    a, b = x0 - overhang, x1 + overhang
    c, d = z0 - overhang, z1 + overhang
    zm = (c + d) / 2
    m.hull(role, [(a, y, c), (b, y, c), (a, y + rise, zm), (b, y + rise, zm), (a, y, zm), (b, y, zm)])
    m.hull(role, [(a, y, d), (b, y, d), (a, y + rise, zm), (b, y + rise, zm), (a, y, zm), (b, y, zm)])
    m.pipe("metal", (a, y + rise, zm), (b, y + rise, zm), 0.06, 6)


def flagpole(m, x, z, h=7.0):
    m.pipe(METAL, (x, 0.13, z), (x, h, z), 0.05, 8)
    m.cyl(DARK, (x, 0.13, z), 0.18, 0.2, 10)
    m.cyl("gold", (x, h, z), 0.08, 0.1, 8)
    m.box("banner", (x + 0.02, h - 1.3, z), (x + 0.04, h - 0.2, z + 1.5))
