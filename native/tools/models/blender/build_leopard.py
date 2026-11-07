"""German / NATO Leopard Family Main Battle Tanks (6 variants), modelled in Blender.

Variants built (`--all`):
  - tank__leopard_2a8.glb     (Germany / Netherlands / Norway / Czechia — L/55A1, EuroTrophy APS, bow add-on armor)
  - tank__leopard_2a7v.glb    (Germany / Denmark — L/55A1, Keilpanzerung arrowhead wedges, bow beak armor, bustle APU)
  - tank__leopard_2a6.glb     (Portugal / Finland / Ukraine / Greece / Canada — L/55, Keilpanzerung wedges, clean glacis)
  - tank__leopard_2a4.glb     (Poland / Spain / Turkiye / Chile / Singapore — L/44, classic vertical box turret & EMES-15 notch)
  - tank__leopard_2ri.glb     (Indonesia — L/44, thick Revolution modular turret & hull side armor, bustle AC unit)
  - tank__leopard_1a5br.glb   (Brazil — 105 mm L7A3, rounded cast turret with spaced bolted Lexan/steel armor panels)

Run:
    blender -b -P native/tools/models/blender/build_leopard.py -- --all
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_vehicle import Part, VehicleRig, init_scene, export_vehicle

LEO2_WHEEL_ZS = [-2.46, -1.64, -0.82, 0.00, 0.82, 1.64, 2.46]
OPTIC_FLIR = (2.2, 1.35, 0.55)
OPTIC_COOL = (0.85, 1.35, 1.45)
TAIL_RED = (4.5, 0.35, 0.25)


def add_cross_decal_x(part, x_plane, cy, cz, sx_out, size=0.15, thick=0.046):
    """Crisp tactical cross / Iron-Cross-style nation team emblem in `markings` role flush on side armor."""
    out = (sx_out, 0.0, 0.0)
    # Horizontal bar
    part.decal_quad("markings",
                    (x_plane, cy - thick * 0.5, cz - size),
                    (x_plane, cy - thick * 0.5, cz + size),
                    (x_plane, cy + thick * 0.5, cz + size),
                    (x_plane, cy + thick * 0.5, cz - size),
                    outward=out)
    # Top & bottom vertical arms (avoiding overlap z-fighting at centre)
    part.decal_quad("markings",
                    (x_plane, cy + thick * 0.52, cz - thick * 0.5),
                    (x_plane, cy + thick * 0.52, cz + thick * 0.5),
                    (x_plane, cy + size, cz + thick * 0.62),
                    (x_plane, cy + size, cz - thick * 0.62),
                    outward=out)
    part.decal_quad("markings",
                    (x_plane, cy - size, cz - thick * 0.62),
                    (x_plane, cy - size, cz + thick * 0.62),
                    (x_plane, cy - thick * 0.52, cz + thick * 0.5),
                    (x_plane, cy - thick * 0.52, cz - thick * 0.5),
                    outward=out)


def build_leo_wheel(wp, lod, side, r=0.345):
    """Smooth dished German Diehl dual road wheel with 12 rim bolts & central grease cap."""
    p = Part(f"Wheel_{side}")
    s = side
    with p.frame(wp):
        if lod:
            p.lathe_x((0, 0, 0), [(-0.22, 0.0, "paint", 0.8), (-0.22, r, "rubber", 1.0),
                                  (0.22, r, "paint", 0.86), (0.22, 0.0, "paint", 0.86)], seg=8)
            return p
        prof_r = [
            (-0.23, 0.0, "metal_dark", 0.45),
            (-0.23, r * 0.72, "paint", 0.74),
            (-0.22, r * 0.78, "rubber", 0.92),
            (-0.22, r, "rubber", 1.0),
            (-0.045, r, "metal_dark", 0.40),
            (-0.04, r * 0.68, "metal_dark", 0.35),
            (0.04, r * 0.68, "rubber", 0.92),
            (0.045, r, "rubber", 1.0),
            (0.22, r, "paint", 0.94),
            (0.22, r * 0.78, "paint", 0.84),
            (0.175, r * 0.66, "paint", 0.74),
            (0.19, r * 0.34, "paint", 0.92),
            (0.19, 0.0, "paint", 0.92),
        ]
        if s < 0:
            prof = [(-prof_r[i][0], prof_r[i][1], prof_r[i - 1][2] if i > 0 else "paint", prof_r[i - 1][3] if i > 0 else 0.9)
                    for i in range(len(prof_r) - 1, -1, -1)]
            p.lathe_x((0, 0, 0), prof, seg=18)
        else:
            p.lathe_x((0, 0, 0), prof_r, seg=18)
        p.pipe("paint", (s * 0.18, 0, 0), (s * 0.24, 0, 0), 0.095, seg=12, r2=0.075, bevel=0.008)
        for k in range(10):
            a = math.tau * k / 10.0
            p.pipe("metal_dark", (s * 0.18, r * 0.56 * math.cos(a), r * 0.56 * math.sin(a)),
                   (s * 0.20, r * 0.56 * math.cos(a), r * 0.56 * math.sin(a)), 0.013, seg=6)
    return p


def build_sprocket(wp, lod, side, scale=1.0):
    p = Part(f"Sprocket_{side}")
    s = side
    n_seg = 10 if lod else 20
    r = 0.43 * scale
    with p.frame(wp):
        p.lathe_x((0, 0, 0), [
            (-0.22, 0.0, "metal_dark", 0.55), (-0.22, r, "paint", 0.80),
            (-0.15, r, "metal_dark", 0.42), (-0.13, r * 0.78, "metal_dark", 0.40),
            (0.13, r * 0.78, "paint", 0.84), (0.15, r, "paint", 0.90),
            (0.22, r, "paint", 0.88), (0.22, 0.0, "paint", 0.88),
        ], seg=n_seg)
        p.pipe("paint", (s * 0.12, 0, 0), (s * 0.26, 0, 0), 0.19 * scale, seg=n_seg, r2=0.15 * scale, bevel=0.01)
        if not lod:
            for tx in (-0.185, 0.185):
                for k in range(11):
                    a = math.tau * k / 11.0
                    with p.frame((tx, 0, 0), pitch=a):
                        p.box("metal", (-0.02, r - 0.02, -0.042), (0.02, r + 0.075 * scale, 0.042), bevel=0.006)
    return p


def build_idler(wp, lod, side, scale=1.0):
    p = Part(f"Idler_{side}")
    s = side
    r = 0.415 * scale
    n_seg = 8 if lod else 16
    with p.frame(wp):
        prof_r = [
            (-0.20, 0.0, "metal_dark", 0.5), (-0.20, r, "metal", 0.9),
            (-0.05, r, "metal_dark", 0.4), (-0.04, r * 0.7, "metal_dark", 0.4),
            (0.04, r * 0.7, "metal_dark", 0.75), (0.05, r, "metal", 0.92),
            (0.20, r, "paint", 0.88), (0.16, r * 0.74, "paint", 0.74),
            (0.17, r * 0.32, "paint", 0.9), (0.17, 0.0, "paint", 0.9),
        ]
        if s < 0:
            prof = [(-prof_r[i][0], prof_r[i][1], prof_r[i - 1][2] if i > 0 else "paint", prof_r[i - 1][3] if i > 0 else 0.9)
                    for i in range(len(prof_r) - 1, -1, -1)]
            p.lathe_x((0, 0, 0), prof, seg=n_seg)
        else:
            p.lathe_x((0, 0, 0), prof_r, seg=n_seg)
        p.pipe("paint", (s * 0.15, 0, 0), (s * 0.22, 0, 0), 0.11 * scale, seg=12, r2=0.085 * scale, bevel=0.008)
    return p


def build_roller(wp, lod, side):
    if lod:
        return None
    p = Part(f"Roller_{side}")
    with p.frame(wp):
        for dx in (-0.10, 0.10):
            p.pipe("rubber", (dx - 0.04, 0, 0), (dx + 0.04, 0, 0), 0.11, seg=10)
        p.pipe("metal_dark", (-0.17, 0, 0), (0.17, 0, 0), 0.034, seg=8)
    return p


# ==============================================================================
# LEOPARD 2 HULL & TURRETS (2A4, 2A6, 2A7V, 2A8, 2RI)
# ==============================================================================
def build_leo2_hull(lod, variant):
    h = Part("Hull", seed=71)
    bev = 0.014 if lod else 0.026
    has_bow_addon = variant in ("leopard_2a7v", "leopard_2a8")
    is_ri = variant == "leopard_2ri"

    # 1. Classic German Leopard 2 welded box-wedge hull (`x = -1.16 .. +1.16, z = -3.86 .. +3.82`)
    hull_yz = [
        (0.45, 3.15),
        (0.95, 3.84),
        (1.12, 3.80),
        (1.46, 2.05),
        (1.46, -1.80),
        (1.50, -3.76),    # slightly raised MTU MB 873 engine deck
        (1.38, -3.88),
        (0.56, -3.84),
        (0.45, -3.35),
    ]
    h.prism_x("paint", hull_yz, -1.16, 1.16, bevel=bev, seg=1, tint=(1.0, 1.0, 1.0), ao_y=(0.45, 1.40, 0.68))

    # Variant Bow Add-on Armor (`Zusatzpanzerung` beak on 2A7V/2A8, or deep AMAP slab on 2RI)
    if has_bow_addon:
        beak_yz = [(0.78, 3.56), (1.06, 4.02), (1.24, 3.96), (1.42, 2.85), (1.18, 2.95)]
        h.prism_x("paint", beak_yz, -1.72, 1.72, bevel=0.020, seg=1, tint=(1.03, 1.03, 1.01))
    elif is_ri:
        ri_yz = [(0.74, 3.48), (1.08, 3.98), (1.32, 3.86), (1.46, 2.55), (1.16, 2.65)]
        h.prism_x("paint", ri_yz, -1.78, 1.78, bevel=0.022, seg=1, tint=(1.03, 1.03, 1.01))
    elif not lod:
        # Classic 2A4/2A6 ice-cleat / spare track rack across lower bow nose
        for x0 in (-0.95, -0.30, 0.35):
            h.box("metal_dark", (x0, 0.94, 3.80), (x0 + 0.52, 1.12, 3.88), pitch=0.22, bevel=0.006)

    # 2. Inner dark wheel wells & torsion arms
    for sx in (-1, 1):
        h.box("dark", (sx * 1.16 - 0.03, 0.46, -3.45), (sx * 1.16 + 0.03, 1.38, 3.35))
        if not lod:
            for wz in LEO2_WHEEL_ZS:
                h.pipe("metal_dark", (sx * 1.15, 0.56, wz + 0.22), (sx * 1.44, 0.45, wz), 0.050, seg=8)

    # 3. Upper Track Sponsons & Leopard 2 Stepped Ballistic + Wavy Rear Skirts!
    for sx in (-1, 1):
        x_in, x_out = (1.14, 1.79) if sx > 0 else (-1.79, -1.14)
        sponson_yz = [(1.36, -3.86), (1.46, -3.82), (1.46, 3.25), (1.18, 3.88), (1.06, 3.86), (1.32, 3.16)]
        h.prism_x("paint", sponson_yz, x_in, x_out, bevel=0.016, seg=1, tint=(0.98, 0.98, 0.97))
        h.box("rubber", (min(x_in, x_out) + 0.02, 0.50, -3.91), (max(x_in, x_out) - 0.02, 1.32, -3.85), bevel=0.008)

        h.box("dark", (sx * 1.75 - 0.02, 0.86, -3.60), (sx * 1.75 + 0.02, 1.44, 3.28))
        skirt_edges = [3.34, 2.34, 1.34, 0.34, -0.66, -1.66, -2.66, -3.66]
        for idx in range(7):
            zf, zr = skirt_edges[idx] - 0.015, skirt_edges[idx + 1] + 0.015
            heavy = is_ri or idx < 3
            thick = 0.17 if is_ri and idx < 5 else (0.135 if heavy else 0.065)
            xo = 1.92 if (is_ri and idx < 5) else (1.865 if heavy else 1.832)
            xi = xo - thick
            x0, x1 = (xi, xo) if sx > 0 else (-xo, -xi)
            if idx == 0:
                yz = [(0.90, zf), (1.45, zf), (1.45, zr), (0.66, zr), (0.72, zf - 0.38)]
            elif idx == 6:
                yz = [(0.82, zf), (1.45, zf), (1.45, zr), (1.14, zr), (0.94, zr + 0.42)]
            else:
                yb = 0.66 if heavy else 0.82
                yz = [(yb, zf), (1.45, zf), (1.45, zr), (yb, zr)]
            tk = 1.01 if idx % 2 == 0 else 0.97
            h.prism_x("paint", yz, x0, x1, bevel=0.018 if heavy else 0.010, seg=1, tint=(tk, tk, tk * 0.99), ao_y=(0.66, 1.45, 0.82))
            if not lod and heavy:
                zc = (zf + zr) * 0.5
                h.box("metal_dark", (sx * xo - 0.014, 0.84, zc - 0.06), (sx * xo + 0.014, 0.89, zc + 0.06))

        decal_x = sx * (1.928 if is_ri else 1.838)
        add_cross_decal_x(h, decal_x, 1.12, -0.16, sx, size=0.14, thick=0.044)

    # 4. Right-Side Driver's Sliding Hatch & 3 Periscopes + Fender Headlights
    glacis_p = math.atan2(1.46 - 1.12, 3.80 - 2.05)
    with h.frame((0.54, 1.38, 2.48), pitch=glacis_p):
        h.box("paint", (-0.28, -0.02, -0.32), (0.28, 0.055, 0.32), bevel=0.016)
        for px, yp in ((-0.16, 0.25), (0.0, 0.0), (0.16, -0.25)):
            with h.frame((px, 0.048, 0.20), yaw=yp):
                h.box("paint", (-0.07, 0.0, -0.08), (0.07, 0.075, 0.08), bevel=0.008)
                h.box("glass", (-0.055, 0.015, 0.065), (0.055, 0.060, 0.084), tint=OPTIC_COOL)

    for sx in (-1, 1):
        hx = sx * 1.42
        h.pipe("paint", (hx, 1.48, 3.42), (hx, 1.48, 3.58), 0.085, seg=10)
        h.pipe("glass", (hx, 1.48, 3.56), (hx, 1.48, 3.60), 0.068, seg=10, tint=(2.2, 2.1, 1.8))

    # 5. Signature Leopard 2 MTU Engine Deck: Twin Large Circular Cooling Fan Rings (`z = -2.52`) + Side Exhaust Louvers!
    for sx in (-1, 1):
        fx, fz = sx * 0.56, -2.56
        h.cyl("dark", (fx, 1.485, fz), 0.44, 0.035, seg=12 if lod else 24)
        h.tube_axis("paint", (fx, 1.49, fz), (fx, 1.545, fz), 0.48, 0.41, seg=12 if lod else 24, tint=(1.02, 1.02, 1.0))
        if not lod:
            h.cyl("metal_dark", (fx, 1.50, fz), 0.12, 0.042, seg=12)
            for k in range(8):
                a = math.tau * k / 8.0
                with h.frame((fx, 1.52, fz), yaw=a):
                    h.box("metal_dark", (-0.014, -0.012, 0.11), (0.014, 0.012, 0.41), tint=(0.68, 0.68, 0.70))
        # Rear corner horizontal exhaust louver banks (`z = -3.65 .. -3.10`)
        h.box("metal_dark", (sx * 1.76 - 0.04, 1.12, -3.76), (sx * 1.76 + 0.04, 1.35, -3.18), bevel=0.01, tint=(0.45, 0.43, 0.42))
        # NATO round 3-chamber tail-light cluster on rear plate
        h.box("metal_dark", (sx * 0.92 - 0.11, 1.14, -3.91), (sx * 0.92 + 0.11, 1.25, -3.85), bevel=0.008)
        h.box("glass", (sx * 0.92 - 0.08, 1.165, -3.92), (sx * 0.92 + 0.08, 1.225, -3.89), tint=TAIL_RED)

    # Rectangular central rear transmission grille + Bundeswehr Leitkreuz shield
    h.box("dark", (-0.58, 0.80, -3.90), (0.58, 1.24, -3.84))
    if not lod:
        for ky in (0.88, 0.98, 1.08, 1.18):
            h.box("metal_dark", (-0.56, ky - 0.014, -3.91), (0.56, ky + 0.014, -3.85), tint=(0.58, 0.58, 0.60))
        h.box("metal", (-0.06, 0.64, -3.91), (0.06, 0.76, -3.86), bevel=0.005)
    return h


def build_leo2_turret(lod, variant):
    """Variant-accurate Leopard 2 turret: 2A4 box, 2A6/2A7V Keilpanzerung wedges, 2A8 EuroTrophy, or 2RI AMAP modular."""
    t = Part("Turret", seed=79)
    bev = 0.016 if lod else 0.028
    is_a4 = variant == "leopard_2a4"
    is_ri = variant == "leopard_2ri"
    is_a8 = variant == "leopard_2a8"
    has_wedge = variant in ("leopard_2a6", "leopard_2a7v", "leopard_2a8")

    # 1. Core Welded Box Turret (`y = 1.50 .. 2.34, z = -2.08 .. +1.22`)
    bot = [
        (-0.42, 1.24), (0.42, 1.24),
        (1.50, 1.08), (1.50, -1.62),
        (1.24, -2.08), (-1.24, -2.08),
        (-1.50, -1.62), (-1.50, 1.08),
    ]
    top = [
        (-0.42, 1.14), (0.42, 1.14),
        (1.40, 0.98), (1.40, -1.58),
        (1.16, -2.00), (-1.16, -2.00),
        (-1.40, -1.58), (-1.40, 0.98),
    ]
    t.prism_y("paint", bot, 1.50, 2.34, top_xz=top, bevel=bev, seg=1, tint=(1.0, 1.0, 0.99), ao_y=(1.50, 2.34, 0.82))
    t.box("dark", (-0.40, 1.56, 0.95), (0.40, 2.28, 1.34))

    # 2. Variant Cheek & Side Armor Architecture!
    if is_a4:
        # Classic Leopard 2A4 vertical flat front cheeks, with iconic stepped EMES-15 cutout on RIGHT cheek (`x > 0`)!
        t.box("paint", (-1.48, 1.52, 1.02), (-0.42, 2.33, 1.38), bevel=bev, tint=(1.02, 1.02, 1.0))
        t.box("paint", (0.42, 1.52, 1.02), (1.48, 2.02, 1.38), bevel=bev, tint=(1.02, 1.02, 1.0))
        t.box("paint", (1.16, 2.00, 1.02), (1.48, 2.33, 1.38), bevel=bev, tint=(1.02, 1.02, 1.0))
        # Recessed EMES-15 armoured sight box inside right upper cheek notch!
        t.box("dark", (0.54, 2.02, 1.14), (1.14, 2.32, 1.39))
    elif has_wedge:
        # Iconic Leopard 2A5/2A6/2A7V/2A8 Hollow Spaced Arrowhead Cheek Wedges (`Keilpanzerung`) + Flank Wedges!
        wz_tip = 2.06 if is_a8 else 1.98
        wx_out = 1.72 if is_a8 else 1.64
        for sx in (-1, 1):
            pts_keil = [
                # Upper sloped face
                (sx * 0.43, 2.33, 1.12),
                (sx * 1.44, 2.33, 0.72),
                # Sharp horizontal arrowhead beak edge (`y = 1.92`)!
                (sx * 0.43, 1.92, wz_tip),
                (sx * 1.02, 1.92, wz_tip - 0.14),
                (sx * wx_out, 1.92, 1.08),
                # Lower angled chin sloping back under the turret!
                (sx * 0.43, 1.56, 1.24),
                (sx * 1.46, 1.58, 0.78),
            ]
            t.hull("paint", pts_keil, bevel=0.018, seg=1, tint=(1.04, 1.04, 1.02), ao_y=(1.56, 2.33, 0.80))
            # Pivoting side spaced-armor wedge module (`z = -0.35 .. +1.05`)
            pts_side = [
                (sx * 1.42, 2.32, 0.72), (sx * 1.42, 2.32, -0.38),
                (sx * wx_out, 1.92, 1.06), (sx * (wx_out - 0.04), 1.92, -0.36),
                (sx * 1.48, 1.58, 0.78), (sx * 1.48, 1.58, -0.38),
            ]
            t.hull("paint", pts_side, bevel=0.016, seg=1, tint=(1.01, 1.01, 1.0))
    elif is_ri:
        # Indonesian Leopard 2RI thick boxy AMAP modular slab-and-chamfer armor enveloping cheeks & flanks!
        for sx in (-1, 1):
            pts_ri = [
                (sx * 0.43, 2.36, 1.32), (sx * 1.60, 2.36, 1.12), (sx * 1.62, 2.36, -1.25), (sx * 1.42, 2.34, -1.55),
                (sx * 0.43, 1.88, 1.66), (sx * 1.76, 1.88, 1.30), (sx * 1.76, 1.88, -1.22), (sx * 1.50, 1.86, -1.55),
                (sx * 0.43, 1.54, 1.32), (sx * 1.58, 1.54, 1.12), (sx * 1.58, 1.54, -1.25),
            ]
            t.hull("paint", pts_ri, bevel=0.022, seg=1, tint=(1.02, 1.02, 1.0), ao_y=(1.54, 2.36, 0.80))

    # 3. EuroTrophy APS on Leopard 2A8 (4 WindGuard radar panels + 2 rooftop countermeasure launchers & blast shields!)
    if is_a8:
        for sx in (-1, 1):
            for rz, ryaw in ((0.46, -sx * 0.62), (-1.52, -sx * 2.45)):
                with t.frame((sx * 1.56, 2.18, rz), yaw=ryaw):
                    t.box("paint", (-0.17, -0.15, -0.07), (0.17, 0.15, 0.04), bevel=0.012)
                    t.box("metal_dark", (-0.14, -0.12, 0.025), (0.14, 0.12, 0.052), bevel=0.006, tint=(0.76, 0.74, 0.68))
            t.box("paint", (sx * 1.48 - 0.16, 2.32, -1.32), (sx * 1.48 + 0.16, 2.64, -0.68), bevel=0.016)
            t.pipe("metal_dark", (sx * 1.48, 2.50, -1.00), (sx * 1.68, 2.50, -1.00), 0.13, seg=8 if lod else 14)

    # 4. Rear Turret Stowage Baskets & Bustle Climate/APU Units (`2A7V`, `2A8`, `2RI`)
    for sx in (-1, 1):
        # Side aft mesh stowage basket (`z = -2.05 .. -1.25`)
        if not is_ri:
            bx0, bx1 = (1.42, 1.62) if sx > 0 else (-1.62, -1.42)
            t.box("paint", (bx0, 1.72, -1.98), (bx1, 2.22, -1.22), bevel=0.014, tint=(0.95, 0.95, 0.93))
        tx_dec = sx * (1.768 if is_ri else 1.512)
        tz_dec = -0.65 if is_ri else -0.82
        add_cross_decal_x(t, tx_dec, 1.96, tz_dec, sx, size=0.14, thick=0.044)

    # Rear bustle basket (`z = -2.08 .. -2.62`) + variant APU/AC module
    if variant in ("leopard_2a7v", "leopard_2a8", "leopard_2ri"):
        t.box("paint", (0.12, 1.78, -2.56), (1.18, 2.30, -2.06), bevel=0.018, tint=(0.97, 0.97, 0.95))
        if not lod:
            for ky in (1.88, 2.00, 2.12, 2.22):
                t.box("metal_dark", (0.20, ky - 0.014, -2.58), (1.10, ky + 0.014, -2.54))
    if not lod:
        for ry in (1.78, 2.04, 2.28):
            t.pipe("metal_dark", (-1.22, ry, -2.58), (0.08 if variant in ("leopard_2a7v", "leopard_2a8", "leopard_2ri") else 1.22, ry, -2.58), 0.017, seg=6)
            for sx in (-1, 1):
                t.pipe("metal_dark", (sx * 1.22, ry, -2.58), (sx * 1.22, ry, -2.05), 0.017, seg=6)
        t.pipe("canvas", (-1.06, 2.06, -2.32), (-0.05, 2.06, -2.32), 0.135, seg=10, bevel=0.03, tint=(0.88, 0.90, 0.80))

    return t


def build_rh120_gun(lod, gp, l55=True):
    """Rheinmetall 120 mm Rh-120 smoothbore (`L/55` long barrel or `L/44` standard barrel) + heavy wedge mantlet!"""
    g = Part("Gun", seed=83)
    gx, gy, gz = gp
    seg = 8 if lod else 20
    tip_z = 5.26 if l55 else 4.38

    # Iconic Leopard 2 heavy wedge/beak armoured rotor mantlet!
    mantlet_pts = [
        (gx - 0.38, gy - 0.26, gz - 0.18), (gx + 0.38, gy - 0.26, gz - 0.18),
        (gx - 0.38, gy + 0.28, gz - 0.18), (gx + 0.38, gy + 0.28, gz - 0.18),
        (gx - 0.34, gy - 0.18, gz + 0.56), (gx + 0.34, gy - 0.18, gz + 0.56),
        (gx - 0.34, gy + 0.20, gz + 0.52), (gx + 0.34, gy + 0.20, gz + 0.52),
    ]
    g.hull("paint", mantlet_pts, bevel=0.024, seg=1, tint=(1.02, 1.02, 1.0))

    # Thermal sleeve + Rh-120 eccentric stepped fiberglass bore evacuator + MRS mirror!
    g.pipe("paint", (gx, gy, gz + 0.50), (gx, gy, gz + 1.65), 0.122, seg=seg, r2=0.108)
    ev_y = gy + 0.022
    g.pipe("paint", (gx, ev_y, gz + 1.62), (gx, ev_y, gz + 1.76), 0.110, seg=seg, r2=0.164, tint=(1.02, 1.02, 1.0))
    g.pipe("paint", (gx, ev_y, gz + 1.76), (gx, ev_y, gz + 2.46), 0.164, seg=seg, tint=(1.02, 1.02, 1.0))
    g.pipe("paint", (gx, ev_y, gz + 2.46), (gx, ev_y, gz + 2.60), 0.164, seg=seg, r2=0.102, tint=(1.02, 1.02, 1.0))
    g.pipe("paint", (gx, gy, gz + 2.58), (gx, gy, gz + tip_z - 0.16), 0.098, seg=seg, r2=0.088)

    if not lod:
        bands = (0.95, 1.48, 3.15, 3.85, 4.55, 5.02) if l55 else (0.95, 1.48, 3.05, 3.65, 4.14)
        for bz in bands:
            g.pipe("metal_dark", (gx, gy, gz + bz - 0.02), (gx, gy, gz + bz + 0.02), 0.104 if bz < 1.6 else 0.096, seg=seg)

    g.tube_axis("metal_dark", (gx, gy, gz + tip_z - 0.18), (gx, gy, gz + tip_z), 0.094, 0.060, seg=seg, tint=(0.68, 0.68, 0.72))
    g.cyl("dark", (gx, gy, gz + tip_z - 0.19), 0.061, 0.02, seg=12)
    if not lod:
        # Characteristic Rh-120 Muzzle Reference System (MRS) tall fin on top of muzzle!
        g.box("metal_dark", (gx - 0.022, gy + 0.085, gz + tip_z - 0.14), (gx + 0.022, gy + 0.185, gz + tip_z - 0.03), bevel=0.005)
    return g


def build_emes_sight(lod, variant):
    """EMES-15 Gunner's Primary Sight (in cheek notch on 2A4, or raised behind right wedge on 2A6/2A7V/2A8/2RI)."""
    p = Part("Gunner_Sight")
    if variant == "leopard_2a4":
        cx, cy, cz = 0.84, 2.04, 1.18
    else:
        cx, cy, cz = 0.82, 2.34, 0.58
    p.box("paint", (cx - 0.24, cy - 0.02, cz - 0.24), (cx + 0.24, cy + 0.25, cz + 0.24), bevel=0.02)
    p.box("dark", (cx - 0.18, cy + 0.03, cz + 0.20), (cx + 0.18, cy + 0.20, cz + 0.246))
    p.box("glass", (cx - 0.15, cy + 0.05, cz + 0.228), (cx - 0.01, cy + 0.18, cz + 0.252), tint=OPTIC_FLIR)
    p.box("glass", (cx + 0.01, cy + 0.05, cz + 0.228), (cx + 0.15, cy + 0.18, cz + 0.252), tint=OPTIC_COOL)
    return p


def build_peri_sight(lod, variant):
    """PERI-R17A2 / RTWL Commander's Panoramic Periscope on left turret roof."""
    p = Part("CITV")
    cx, cy, cz = (-0.58, 2.34, -0.78) if variant != "leopard_2a4" else (-0.58, 2.34, -0.10)
    seg = 8 if lod else 14
    p.cyl("paint", (cx, cy - 0.02, cz), 0.17, 0.18, seg=seg, bevel=0.01)
    p.box("paint", (cx - 0.18, cy + 0.15, cz - 0.17), (cx + 0.18, cy + 0.40, cz + 0.18), bevel=0.02, tint=(1.02, 1.02, 1.0))
    p.box("glass", (cx - 0.12, cy + 0.20, cz + 0.165), (cx + 0.12, cy + 0.34, cz + 0.190), tint=OPTIC_FLIR)
    return p


def build_leo_hatch_mg3(name, lod, pos, with_mg3=False):
    """Circular Leopard crew hatch + Rheinmetall MG3 7.62 mm machine gun on AA ring."""
    p = Part(name)
    cx, cy, cz = pos
    p.cyl("paint", (cx, cy - 0.01, cz), 0.30, 0.08, seg=8 if lod else 14, bevel=0.012)
    if with_mg3 and not lod:
        mx, my, mz = cx - 0.06, cy + 0.22, cz + 0.22
        p.pipe("metal_dark", (mx, cy + 0.06, mz - 0.04), (mx, my, mz), 0.020, seg=6)
        p.box("metal_dark", (mx - 0.035, my - 0.025, mz - 0.16), (mx + 0.035, my + 0.045, mz + 0.20), bevel=0.006)
        p.pipe("metal_dark", (mx, my + 0.015, mz + 0.20), (mx, my + 0.015, mz + 0.64), 0.016, seg=8)
        p.box("paint", (mx - 0.14, my - 0.04, mz - 0.04), (mx - 0.04, my + 0.06, mz + 0.10), bevel=0.006, tint=(0.78, 0.82, 0.72))
    return p


def build_wegmann_smoke(lod, side, z_base=-1.18, y_base=2.04):
    """German Wegmann 76 mm 8-barrel fanned smoke grenade discharger bank (4+4 staggered)."""
    p = Part(f"Smoke_{side}")
    sx = side
    bx = sx * 1.52
    p.box("paint", (bx - 0.05, y_base - 0.08, z_base - 0.34), (bx + 0.05, y_base + 0.04, z_base + 0.34), bevel=0.01)
    if not lod:
        for k in range(8):
            dz = -0.28 + k * 0.08
            dy = 0.04 if k % 2 == 0 else -0.02
            out_k = 0.48
            up_k = 0.36
            fwd_k = 0.80 - k * 0.06
            nrm = math.sqrt(out_k * out_k + up_k * up_k + fwd_k * fwd_k)
            dx_, dy_, dz_ = sx * out_k / nrm, up_k / nrm, fwd_k / nrm
            a = (bx + sx * 0.03, y_base + dy, z_base + dz)
            b = (a[0] + dx_ * 0.21, a[1] + dy_ * 0.21, a[2] + dz_ * 0.21)
            c = (a[0] + dx_ * 0.24, a[1] + dy_ * 0.24, a[2] + dz_ * 0.24)
            p.pipe("paint", a, b, 0.034, seg=8)
            p.pipe("rubber", b, c, 0.037, seg=8)
    return p


def build_antenna(lod, idx, pos):
    p = Part(f"Antenna_{idx}")
    ax, ay, az = pos
    p.cyl("metal_dark", (ax, ay - 0.01, az), 0.04, 0.12, seg=6 if lod else 10)
    p.pipe("metal_dark", (ax, ay + 0.11, az), (ax, ay + 1.42, az - 0.05), 0.011, seg=4 if lod else 6, r2=0.004)
    return p


# ==============================================================================
# LEOPARD 1A5BR (BRAZIL) — Distinct Compact Hull, Spaced Cast Turret & 105mm L7A3
# ==============================================================================
def build_leo1a5_rig(lod=0):
    rig = VehicleRig(lod=lod)
    k = 0.89
    bev = 0.014 if lod else 0.026

    # 1. Sleek Cold-War Leopard 1 Hull (`7.09 x 3.37 m`) with sloped bow & angled side engine exhaust louvers!
    h = Part("Hull", seed=89)
    hull_yz = [
        (0.42, 2.80), (0.94, 3.52), (1.06, 3.48),
        (1.38, 1.90), (1.38, -1.60), (1.42, -3.38),
        (1.24, -3.54), (0.52, -3.42), (0.42, -2.95),
    ]
    h.prism_x("paint", hull_yz, -1.06, 1.06, bevel=bev, seg=1, ao_y=(0.42, 1.38, 0.68))
    for sx in (-1, 1):
        h.box("dark", (sx * 1.06 - 0.03, 0.44, -3.10), (sx * 1.06 + 0.03, 1.32, 3.00))
        x_in, x_out = (1.04, 1.62) if sx > 0 else (-1.62, -1.04)
        h.box("paint", (x_in, 1.28, -3.44), (x_out, 1.38, 3.18), bevel=0.014)
        # Signature Leopard 1 raised rear-side angled exhaust louver boxes!
        h.box("paint", (x_in, 1.36, -3.22), (x_out - (0.04 if sx > 0 else -0.04), 1.62, -1.68), bevel=0.016, tint=(0.96, 0.96, 0.94))
        h.box("dark", (sx * 1.60 - 0.02, 1.40, -3.08), (sx * 1.60 + 0.02, 1.57, -1.82))
        if not lod:
            for kz in range(8):
                lz = -3.00 + kz * 0.16
                h.box("metal_dark", (sx * 1.60 - 0.025, 1.41, lz - 0.02), (sx * 1.60 + 0.025, 1.56, lz + 0.02))
        # 5 rubberized steel side skirts per side
        for idx in range(5):
            zf = 2.86 - idx * 1.14
            zr = zf - 1.10
            xo = 1.68
            x0, x1 = (1.62, xo) if sx > 0 else (-xo, -1.62)
            h.box("paint", (x0, 0.78, zr), (x1, 1.36, zf), bevel=0.010, tint=(0.98, 0.98, 0.96))
        add_cross_decal_x(h, sx * 1.688, 1.07, 0.02, sx, size=0.13, thick=0.040)

    rig.add("Hull", rig.root_name, (0.0, 0.0, 0.0), h)
    ring = Part("Turret_Ring")
    ring.cyl("metal_dark", (0.0, 1.36, 0.10), 0.98, 0.08, seg=14 if lod else 24)
    rig.add("Turret_Ring", "Hull", (0.0, 1.40, 0.10), ring)

    # 2. Leopard 1A5 Rounded Cast Turret + Stand-Off Bolted Lexan/Steel Spaced Armor Panels + Rear Basket!
    t = Part("Turret", seed=97)
    t.cyl("paint", (0.0, 1.42, 0.05), 1.24, 0.78, seg=14 if lod else 26, r2=0.98, bevel=0.08, tint=(1.0, 1.0, 0.98))
    # Characteristic Leopard 1A5 angular rubber-coated Lexan spaced armor plates stood off around turret cheeks & sides!
    for sx in (-1, 1):
        with t.frame((sx * 1.24, 1.84, -0.15), yaw=-sx * 0.10):
            t.box("paint", (-0.06, -0.32, -1.05), (0.06, 0.30, 0.95), bevel=0.018, tint=(0.93, 0.94, 0.90))
            if not lod:
                for bz in (-0.82, -0.28, 0.28, 0.78):
                    for by in (-0.20, 0.18):
                        t.cyl("metal_dark", (sx * 0.062, by, bz), 0.022, 0.02, seg=6)
        with t.frame((sx * 0.88, 1.84, 1.06), yaw=sx * 0.58):
            t.box("paint", (-0.06, -0.28, -0.38), (0.06, 0.28, 0.38), bevel=0.016, tint=(0.94, 0.95, 0.91))
        add_cross_decal_x(t, sx * 1.31, 1.84, -0.25, sx, size=0.13, thick=0.040)

    if not lod:
        for ry in (1.72, 2.08):
            t.pipe("metal_dark", (-1.04, ry, -1.88), (1.04, ry, -1.88), 0.016, seg=6)
            for sx in (-1, 1):
                t.pipe("metal_dark", (sx * 1.04, ry, -1.88), (sx * 1.04, ry, -1.18), 0.016, seg=6)
        t.pipe("canvas", (-0.78, 1.92, -1.58), (0.78, 1.92, -1.58), 0.13, seg=10, bevel=0.03)
    rig.add("Turret", "Hull", (0.0, 1.42, 0.10), t)

    # 3. 105 mm L7A3 Rifled Gun with iconic rounded cast Leopard 1 mantlet & eccentric fume extractor!
    gp = (0.0, 1.84, 1.12)
    g = Part("Gun", seed=101)
    seg = 8 if lod else 18
    g.box("paint", (-0.34, 1.60, 0.96), (0.34, 2.08, 1.54), bevel=0.06, tint=(1.02, 1.02, 1.0))
    g.pipe("paint", (0, 1.84, 1.50), (0, 1.84, 2.75), 0.104, seg=seg, r2=0.092)
    g.pipe("paint", (0, 1.86, 2.72), (0, 1.86, 3.28), 0.142, seg=seg, tint=(1.02, 1.02, 1.0))
    g.pipe("paint", (0, 1.84, 3.26), (0, 1.84, 5.26), 0.084, seg=seg, r2=0.076)
    g.tube_axis("metal_dark", (0, 1.84, 5.24), (0, 1.84, 5.38), 0.082, 0.052, seg=seg)
    g.cyl("dark", (0, 1.84, 5.23), 0.053, 0.02, seg=10)
    rig.add("Gun", "Turret", gp, g)
    rig.add("Muzzle", "Gun", (0.0, 1.84, 5.38), None)

    # EMES-18 sight box on right roof + commander/loader hatches + Wegmann smoke + aerials
    emes = Part("Gunner_Sight")
    emes.box("paint", (0.42, 2.16, 0.28), (0.86, 2.42, 0.82), bevel=0.018)
    emes.box("glass", (0.48, 2.22, 0.80), (0.80, 2.36, 0.835), tint=OPTIC_FLIR)
    rig.add("Gunner_Sight", "Turret", (0.64, 2.18, 0.55), emes)
    rig.add("Hatch_Commander", "Turret", (0.46, 2.20, -0.32), build_leo_hatch_mg3("Hatch_Commander", lod, (0.46, 2.20, -0.32), with_mg3=True))
    rig.add("Hatch_Loader", "Turret", (-0.46, 2.20, -0.38), build_leo_hatch_mg3("Hatch_Loader", lod, (-0.46, 2.20, -0.38), with_mg3=False))
    for label, side in (("L", -1), ("R", 1)):
        rig.add(f"Smoke_Launcher_{label}", "Turret", (side * 1.32, 1.92, -0.85), build_wegmann_smoke(lod, side, z_base=-0.85, y_base=1.92))
    rig.add("Antenna_1", "Turret", (-0.82, 2.16, -1.05), build_antenna(lod, 1, (-0.82, 2.16, -1.05)))
    rig.add("Antenna_2", "Turret", (0.82, 2.16, -1.05), build_antenna(lod, 2, (0.82, 2.16, -1.05)))

    # Scaled 7-wheel Leopard 1 running gear (`k = 0.89`)
    for label, side in (("L", -1), ("R", 1)):
        wx = side * 1.35
        for i, wz in enumerate(LEO2_WHEEL_ZS):
            wp = (wx, 0.42, wz * k)
            rig.add(f"Wheel_{label}{i}", "Hull", wp, build_leo_wheel(wp, lod, side, r=0.315))
        sp_piv = (wx, 0.65 * k, -3.23 * k)
        rig.add(f"Sprocket_{label}", "Hull", sp_piv, build_sprocket(sp_piv, lod, side, scale=k))
        id_piv = (wx, 0.65 * k, 3.23 * k)
        rig.add(f"Idler_{label}", "Hull", id_piv, build_idler(id_piv, lod, side, scale=k))
        for i, rz in enumerate((-1.75 * k, 0.0, 1.75 * k)):
            rp = (wx, 1.00 * k, rz)
            rig.add(f"Roller_{label}{i}", "Hull", rp, build_roller(rp, lod, side))
        trk = Part(f"Track_{label}")
        trk.build_track(wx, lod=lod, width=0.58)
        rig.add(f"Track_{label}", "Hull", (wx, 0.0, 0.0), trk, mesh_scale=(1.0, k, k))

    rig.add("Exhaust", "Hull", (0.0, 1.48, -2.50), None)
    rig.add("Engine_Deck", "Hull", (0.0, 1.42, -2.45), None)
    return rig


def build_leo2_rig(lod=0, variant="leopard_2a7v"):
    if variant == "leopard_1a5br":
        return build_leo1a5_rig(lod)

    rig = VehicleRig(lod=lod)
    l55 = variant in ("leopard_2a6", "leopard_2a7v", "leopard_2a8")
    k = 0.99

    rig.add("Hull", rig.root_name, (0.0, 0.0, 0.0), build_leo2_hull(lod, variant))
    ring = Part("Turret_Ring")
    ring.cyl("metal_dark", (0.0, 1.44, 0.05), 1.08, 0.08, seg=14 if lod else 28)
    rig.add("Turret_Ring", "Hull", (0.0, 1.48, 0.05), ring)

    rig.add("Turret", "Hull", (0.0, 1.50, 0.05), build_leo2_turret(lod, variant))

    gp = (0.0, 1.96, 1.38)
    rig.add("Gun", "Turret", gp, build_rh120_gun(lod, gp, l55=l55))
    rig.add("Muzzle", "Gun", (0.0, 1.96, gp[2] + (5.26 if l55 else 4.38)), None)

    rig.add("Gunner_Sight", "Turret", (0.82, 2.34, 0.58), build_emes_sight(lod, variant))
    rig.add("CITV", "Turret", (-0.58, 2.34, -0.78), build_peri_sight(lod, variant))
    rig.add("Hatch_Commander", "Turret", (-0.56, 2.34, -0.28 if variant != "leopard_2a4" else -0.56),
            build_leo_hatch_mg3("Hatch_Commander", lod, (-0.56, 2.34, -0.28 if variant != "leopard_2a4" else -0.56), with_mg3=False))
    rig.add("Hatch_Loader", "Turret", (0.56, 2.34, -0.52),
            build_leo_hatch_mg3("Hatch_Loader", lod, (0.56, 2.34, -0.52), with_mg3=True))

    for label, side in (("L", -1), ("R", 1)):
        rig.add(f"Smoke_Launcher_{label}", "Turret", (side * 1.52, 2.04, -1.18), build_wegmann_smoke(lod, side))

    rig.add("Antenna_1", "Turret", (-1.12, 2.34, -1.85), build_antenna(lod, 1, (-1.12, 2.34, -1.85)))
    rig.add("Antenna_2", "Turret", (1.12, 2.34, -1.85), build_antenna(lod, 2, (1.12, 2.34, -1.85)))

    for label, side in (("L", -1), ("R", 1)):
        wx = side * 1.48
        for i, wz in enumerate(LEO2_WHEEL_ZS):
            wp = (wx, 0.46, wz * k)
            rig.add(f"Wheel_{label}{i}", "Hull", wp, build_leo_wheel(wp, lod, side, r=0.345))
        sp_piv = (wx, 0.65 * k, -3.23 * k)
        rig.add(f"Sprocket_{label}", "Hull", sp_piv, build_sprocket(sp_piv, lod, side, scale=k))
        id_piv = (wx, 0.65 * k, 3.23 * k)
        rig.add(f"Idler_{label}", "Hull", id_piv, build_idler(id_piv, lod, side, scale=k))
        for i, rz in enumerate((-1.75 * k, 0.0, 1.75 * k)):
            rp = (wx, 1.03 * k, rz)
            rig.add(f"Roller_{label}{i}", "Hull", rp, build_roller(rp, lod, side))
        trk = Part(f"Track_{label}")
        trk.build_track(wx, lod=lod, width=0.635)
        rig.add(f"Track_{label}", "Hull", (wx, 0.0, 0.0), trk, mesh_scale=(1.0, k, k))

    rig.add("Exhaust", "Hull", (0.0, 1.22, -3.88), None)
    rig.add("Engine_Deck", "Hull", (0.0, 1.52, -2.56), None)
    return rig


LEOPARD_VARIANTS = (
    "leopard_2a8",
    "leopard_2a7v",
    "leopard_2a6",
    "leopard_2a4",
    "leopard_2ri",
    "leopard_1a5br",
)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    veh_dir = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../godot/assets/art/vehicles"))
    os.makedirs(veh_dir, exist_ok=True)
    targets = LEOPARD_VARIANTS if ("--all" in argv or not argv) else [v for v in argv if not v.startswith("-")]
    for var in targets:
        init_scene()
        out_p = os.path.join(veh_dir, f"tank__{var}.glb")
        export_vehicle(out_p, build_leo2_rig(0, var), build_leo2_rig(1, var))
