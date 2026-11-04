"""Regional style for the civic buildings: stone and plaster colour, the roof material, what crowns the roof and a landmark at the
front of the plaza. Import with `from bl_style import *`, call apply_style(m) after creating the Model; the style is the last
word of the command line that names one (euro, med, asia, arab, us, india, africa)."""
import math
import sys
from bl_kit import hexc

_argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
STYLE = "euro"
for _a in _argv[1:]:
    if _a in ("euro", "med", "asia", "arab", "us", "india", "africa"):
        STYLE = _a

_STONE_TINT = {"euro": (1, 1, 1), "med": (1.18, 1.14, 1.04), "asia": (0.82, 0.8, 0.78), "arab": (1.02, 0.86, 0.62),
               "us": (1.25, 1.25, 1.3), "india": (1.0, 0.52, 0.38), "africa": (0.9, 0.62, 0.46)}
_ROOF = {"euro": None, "med": "roof_tile", "asia": None, "arab": "plaster", "us": None, "india": "plaster", "africa": "plaster"}


def apply_style(m):
    """Dress a civic model for the owning nation's region: stone and plaster colour, the roof material."""
    t = _STONE_TINT[STYLE]
    m.role_tint["stone"] = t
    m.role_tint["plaster"] = tuple(0.5 + 0.5 * c for c in t)
    if _ROOF[STYLE]:
        m.role_map["roof_slate"] = _ROOF[STYLE]


def crown(m, cx, y, cz, w, d, corners_only=False):
    """What stands on the roof in this region: upturned eaves (East Asia), domes (Arab), chhatris (India), turrets (Africa), a rotunda
    (US), a belvedere (Mediterranean). (cx, cz) is the roof centre, y the ridge, w x d the footprint; corners_only keeps the middle free."""
    sx, sz = w / 2, d / 2
    if STYLE == "asia":
        e = 0.9
        pts = []
        for (px, pz) in ((-sx - e, -sz - e), (sx + e, -sz - e), (sx + e, sz + e), (-sx - e, sz + e)):
            pts.append((cx + px, y - 1.2, cz + pz))
            pts.append((cx + px * 1.12, y - 0.5, cz + pz * 1.12))
        pts += [(cx - sx * 0.6, y + 0.2, cz - sz * 0.6), (cx + sx * 0.6, y + 0.2, cz - sz * 0.6), (cx + sx * 0.6, y + 0.2, cz + sz * 0.6), (cx - sx * 0.6, y + 0.2, cz + sz * 0.6)]
        m.hull("roof_slate", pts)
        if not corners_only:
            m.pipe("gold", (cx, y + 0.2, cz), (cx, y + 1.6, cz), 0.06, 8, r2=0.02)
        for px, pz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            m.cyl("gold", (cx + px * (sx + e * 1.1), y - 0.5, cz + pz * (sz + e * 1.1)), 0.1, 0.35, 6, r2=0.02)
    elif STYLE == "arab":
        r = min(sx, sz)
        if not corners_only:
            m.cyl("plaster", (cx, y, cz), r * 0.62, 1.0, 24)
            m.lathe("copper", (cx, y + 1.0, cz), [(0.0, 0.0), (r * 0.65, 0.0), (r * 0.6, 0.7), (r * 0.4, 1.4), (r * 0.15, 1.8), (0.0, 1.9)], 24)
            m.pipe("gold", (cx, y + 2.9, cz), (cx, y + 3.6, cz), 0.04, 6, r2=0.012)
        for px, pz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            x, z = cx + px * (sx - 0.5), cz + pz * (sz - 0.5)
            m.cyl("plaster", (x, y - 1.2, z), 0.4, 1.8, 12)
            m.lathe("copper", (x, y + 0.6, z), [(0.0, 0.0), (0.5, 0.0), (0.4, 0.4), (0.0, 0.8)], 12)
    elif STYLE == "india":
        r = min(sx, sz)
        if not corners_only:
            m.cyl("plaster", (cx, y, cz), r * 0.55, 1.2, 8)
            m.lathe("plaster", (cx, y + 1.2, cz), [(0.0, 0.0), (r * 0.6, 0.0), (r * 0.58, 0.8), (r * 0.35, 1.6), (r * 0.1, 2.0), (0.0, 2.1)], 24)
            m.pipe("gold", (cx, y + 3.2, cz), (cx, y + 4.0, cz), 0.05, 6, r2=0.012)
        for px, pz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):                                     # chhatris: four pillars under a small dome
            x, z = cx + px * (sx - 0.6), cz + pz * (sz - 0.6)
            for qx, qz in ((-0.3, -0.3), (0.3, -0.3), (0.3, 0.3), (-0.3, 0.3)):
                m.pipe("stone", (x + qx, y, z + qz), (x + qx, y + 1.3, z + qz), 0.06, 6)
            m.box("stone", (x - 0.4, y + 1.3, z - 0.4), (x + 0.4, y + 1.45, z + 0.4), bevel=0.02, seg=1)
            m.lathe("plaster", (x, y + 1.45, z), [(0.0, 0.0), (0.42, 0.0), (0.35, 0.3), (0.12, 0.6), (0.0, 0.7)], 12)
    elif STYLE == "africa":
        for px, pz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):                                     # earthen turrets with spikes
            x, z = cx + px * (sx - 0.4), cz + pz * (sz - 0.4)
            m.cyl("plaster", (x, y - 1.0, z), 0.55, 2.0, 10, r2=0.42)
            for k in range(6):
                a = math.tau * k / 6
                m.pipe("wood", (x + math.cos(a) * 0.3, y + 0.9, z + math.sin(a) * 0.3), (x + math.cos(a) * 0.45, y + 1.5, z + math.sin(a) * 0.45), 0.04, 4)
        if not corners_only:
            for k in range(9):
                xx = cx - sx + (k + 0.5) * w / 9
                m.box("plaster", (xx - 0.25, y - 0.2, cz + sz - 0.4), (xx + 0.25, y + 0.5, cz + sz - 0.1), bevel=0.02, seg=1)
    elif STYLE == "us" and not corners_only:                                                    # a white rotunda
        r = min(sx, sz) * 0.45
        white = (1.2, 1.2, 1.25)
        m.cyl("plaster", (cx, y, cz), r, 1.4, 24, tint=white)
        for k in range(12):
            a = math.tau * k / 12
            m.pipe("plaster", (cx + math.cos(a) * r * 0.95, y + 0.1, cz + math.sin(a) * r * 0.95), (cx + math.cos(a) * r * 0.95, y + 1.3, cz + math.sin(a) * r * 0.95), 0.07, 6, tint=white)
        m.lathe("plaster", (cx, y + 1.4, cz), [(0.0, 0.0), (r * 1.05, 0.0), (r * 0.95, 0.9), (r * 0.6, 1.8), (r * 0.2, 2.3), (0.0, 2.4)], 28, tint=white)
        m.cyl("gold", (cx, y + 3.7, cz), 0.15, 0.4, 8, r2=0.04)
    elif STYLE == "med" and not corners_only:                                                   # a belvedere under a terracotta roof
        for qx, qz in ((-0.5, -0.5), (0.5, -0.5), (0.5, 0.5), (-0.5, 0.5)):
            m.pipe("stone", (cx + qx, y, cz + qz), (cx + qx, y + 1.6, cz + qz), 0.08, 6)
        m.hull("roof_tile", [(cx - 0.9, y + 1.6, cz - 0.9), (cx + 0.9, y + 1.6, cz - 0.9), (cx - 0.9, y + 1.6, cz + 0.9), (cx + 0.9, y + 1.6, cz + 0.9), (cx, y + 2.4, cz)])


def forecourt(m, z=9.0):
    """A regional landmark at the front edge of the plaza."""
    if STYLE == "asia":                                                                          # a red paifang gate
        for sx in (-1, 1):
            m.pipe("paint", (sx * 2.4, 0.13, z), (sx * 2.4, 3.6, z), 0.18, 10, tint=hexc("a8322a"))
        m.box("paint", (-3.0, 3.6, z - 0.15), (3.0, 4.0, z + 0.15), bevel=0.03, seg=1, tint=hexc("a8322a"))
        m.hull("roof_slate", [(-3.4, 4.0, z - 0.6), (3.4, 4.0, z - 0.6), (-3.4, 4.0, z + 0.6), (3.4, 4.0, z + 0.6), (-3.7, 4.4, z - 0.8), (3.7, 4.4, z - 0.8), (-3.7, 4.4, z + 0.8), (3.7, 4.4, z + 0.8), (0.0, 4.7, z)])
        m.box("gold", (-1.0, 3.65, z + 0.16), (1.0, 3.95, z + 0.19))
    elif STYLE in ("arab", "africa"):                                                            # an octagonal fountain
        m.cyl("stone", (0.0, 0.13, z - 0.4), 1.4, 0.4, 8)
        m.cyl("glass", (0.0, 0.5, z - 0.4), 1.2, 0.03, 8, tint=(0.7, 1.1, 1.5))
        m.cyl("stone", (0.0, 0.5, z - 0.4), 0.25, 0.9, 8)
    elif STYLE == "india":                                                                       # a gateway with chhatri domes
        for sx in (-1, 1):
            m.box("stone", (sx * 2.0 - 0.35, 0.13, z - 0.35), (sx * 2.0 + 0.35, 3.2, z + 0.35), bevel=0.04, seg=1)
            m.lathe("plaster", (sx * 2.0, 3.2, z), [(0.0, 0.0), (0.5, 0.0), (0.4, 0.4), (0.0, 0.8)], 10)
        m.box("stone", (-2.0, 3.0, z - 0.25), (2.0, 3.3, z + 0.25), bevel=0.03, seg=1)
    elif STYLE == "us":                                                                          # a big flag
        m.pipe("metal", (0.0, 0.13, z), (0.0, 9.0, z), 0.07, 8)
        m.box("paint", (0.02, 7.2, z), (0.04, 8.8, z + 2.2), tint=hexc("c0392b"))
    elif STYLE == "med":                                                                         # two cypresses
        for sx in (-1, 1):
            m.cyl("wood", (sx * 3.0, 0.13, z), 0.12, 0.6, 6)
            m.cyl("leaf", (sx * 3.0, 0.7, z), 0.5, 3.4, 8, r2=0.05, tint=hexc("2f5a32"))
