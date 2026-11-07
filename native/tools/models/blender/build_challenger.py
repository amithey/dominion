"""British Challenger Family Main Battle Tanks (2 variants), modelled in Blender.

Variants built (`--all`):
  - tank__challenger_2.glb  (UK / Oman / Ukraine — Dorchester sloped cheeks, 120 mm L30A1 rifled gun + TOGS-II box over mantlet, rear fuel drums)
  - tank__challenger_3.glb  (UK RBSL — New welded modular turret, 120 mm L/55A1 smoothbore gun, Orion + gunner sights, no TOGS box)

Run:
    blender -b -P native/tools/models/blender/build_challenger.py -- --all
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_vehicle import Part, VehicleRig, init_scene, export_vehicle

CHALLY_WHEEL_ZS = [-2.46, -1.48, -0.49, 0.49, 1.48, 2.46]
OPTIC_FLIR = (2.1, 1.30, 0.50)
OPTIC_COOL = (0.75, 1.35, 1.45)


def add_british_chevron_x(part, x_plane, cy, cz, sx_out, size=0.15, thick=0.044):
    """British tactical squadron chevron (`>`) in `markings` role flush on side armor."""
    out = (sx_out, 0.0, 0.0)
    part.decal_quad("markings",
                    (x_plane, cy, cz + size * 0.75),
                    (x_plane, cy + size, cz - size * 0.65),
                    (x_plane, cy + size - thick * 1.1, cz - size * 0.65 - thick * 0.4),
                    (x_plane, cy, cz + size * 0.75 - thick * 1.3),
                    outward=out)
    part.decal_quad("markings",
                    (x_plane, cy, cz + size * 0.75),
                    (x_plane, cy, cz + size * 0.75 - thick * 1.3),
                    (x_plane, cy - size + thick * 1.1, cz - size * 0.65 - thick * 0.4),
                    (x_plane, cy - size, cz - size * 0.65),
                    outward=out)


def build_chally_wheel(wp, lod, side, r=0.395):
    """Large 790 mm British solid-dish Hydrogas road wheel with bolted hub flange."""
    p = Part(f"Wheel_{side}")
    s = side
    with p.frame(wp):
        if lod:
            p.lathe_x((0, 0, 0), [(-0.22, 0.0, "paint", 0.8), (-0.22, r, "rubber", 1.0),
                                  (0.22, r, "paint", 0.86), (0.22, 0.0, "paint", 0.86)], seg=8)
            return p
        prof_r = [
            (-0.22, 0.0, "metal_dark", 0.45),
            (-0.22, r * 0.78, "paint", 0.74),
            (-0.215, r * 0.83, "rubber", 0.94),
            (-0.215, r, "rubber", 1.0),
            (-0.045, r, "metal_dark", 0.38),
            (-0.038, r * 0.70, "metal_dark", 0.35),
            (0.038, r * 0.70, "rubber", 0.94),
            (0.045, r, "rubber", 1.0),
            (0.215, r, "paint", 0.92),
            (0.215, r * 0.82, "paint", 0.84),
            (0.165, r * 0.64, "paint", 0.72),
            (0.185, r * 0.32, "paint", 0.90),
            (0.185, 0.0, "paint", 0.90),
        ]
        if s < 0:
            prof = [(-prof_r[i][0], prof_r[i][1], prof_r[i - 1][2] if i > 0 else "paint", prof_r[i - 1][3] if i > 0 else 0.9)
                    for i in range(len(prof_r) - 1, -1, -1)]
            p.lathe_x((0, 0, 0), prof, seg=18)
        else:
            p.lathe_x((0, 0, 0), prof_r, seg=18)
        p.pipe("paint", (s * 0.17, 0, 0), (s * 0.24, 0, 0), 0.115, seg=12, r2=0.088, bevel=0.008)
        for k in range(12):
            a = math.tau * k / 12.0
            p.pipe("metal_dark", (s * 0.175, r * 0.54 * math.cos(a), r * 0.54 * math.sin(a)),
                   (s * 0.195, r * 0.54 * math.cos(a), r * 0.54 * math.sin(a)), 0.012, seg=6)
    return p


def build_chally_sprocket(wp, lod, side, scale=1.03):
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
                for k in range(12):
                    a = math.tau * k / 12.0
                    with p.frame((tx, 0, 0), pitch=a):
                        p.box("metal", (-0.02, r - 0.02, -0.042), (0.02, r + 0.072 * scale, 0.042), bevel=0.006)
    return p


def build_chally_idler(wp, lod, side, scale=1.03):
    p = Part(f"Idler_{side}")
    s = side
    r = 0.405 * scale
    n_seg = 8 if lod else 16
    with p.frame(wp):
        p.lathe_x((0, 0, 0), [
            (-0.20, 0.0, "metal_dark", 0.5), (-0.20, r, "metal", 0.9),
            (-0.04, r, "metal_dark", 0.4), (0.04, r, "metal", 0.92),
            (0.20, r, "paint", 0.88), (0.16, r * 0.70, "paint", 0.74),
            (0.17, 0.0, "paint", 0.9),
        ], seg=n_seg)
        p.pipe("paint", (s * 0.15, 0, 0), (s * 0.22, 0, 0), 0.11 * scale, seg=12, r2=0.085 * scale)
    return p


def build_chally_roller(wp, lod, side):
    if lod:
        return None
    p = Part(f"Roller_{side}")
    with p.frame(wp):
        for dx in (-0.10, 0.10):
            p.pipe("rubber", (dx - 0.04, 0, 0), (dx + 0.04, 0, 0), 0.115, seg=10)
        p.pipe("metal_dark", (-0.17, 0, 0), (0.17, 0, 0), 0.034, seg=8)
    return p


# ==============================================================================
# CHALLENGER HULL — Central Driver Slot, Dorchester Side Skirts, Perkins CV12 Deck
# ==============================================================================
def build_chally_hull(lod, variant, k):
    h = Part("Hull", seed=29)
    bev = 0.015 if lod else 0.026

    # Long British hull (`z = -4.08 .. +4.12`) with stepped upper glacis & raised rear CV12 engine deck
    hull_yz = [
        (0.44, 3.42),
        (0.96, 4.14),
        (1.10, 4.08),
        (1.50, 2.18),
        (1.50, -1.78),
        (1.58, -3.96),
        (1.38, -4.12),
        (0.56, -4.02),
        (0.44, -3.50),
    ]
    h.prism_x("paint", hull_yz, -1.14, 1.14, bevel=bev, seg=1, ao_y=(0.44, 1.48, 0.68))

    # Signature Challenger central recessed driver's V-trough & wide-angle periscope!
    h.box("dark", (-0.30, 1.38, 2.28), (0.30, 1.51, 3.12))
    h.box("paint", (-0.34, 1.44, 2.02), (0.34, 1.57, 2.58), bevel=0.016)
    h.box("glass", (-0.20, 1.49, 2.55), (0.20, 1.56, 2.62), tint=OPTIC_COOL)

    # Lower bow Dorchester armor block + tow shackles + recessed twin headlight clusters
    h.box("paint", (-1.10, 0.62, 3.68), (1.10, 1.04, 4.18), pitch=-0.28, bevel=0.020, tint=(1.02, 1.02, 1.0))
    for sx in (-1, 1):
        h.box("paint", (sx * 0.92 - 0.16, 1.14, 3.74), (sx * 0.92 + 0.16, 1.32, 3.98), bevel=0.010)
        h.box("glass", (sx * 0.92 - 0.11, 1.18, 3.96), (sx * 0.92 + 0.11, 1.28, 4.00), tint=(1.7, 1.7, 1.5))
        if not lod:
            h.tube_axis("metal_dark", (sx * 0.84, 0.82, 4.10), (sx * 0.84, 0.82, 4.24), 0.058, 0.028, seg=8)

    # Wheel wells, Hydrogas units, Sponsons & Heavy Dorchester Side Skirts
    # Track outer connectors at `1.44 + 0.62 * 0.515 = 1.759` -> skirts outer face at `1.88`!
    for sx in (-1, 1):
        h.box("dark", (sx * 1.14 - 0.03, 0.46, -3.65), (sx * 1.14 + 0.03, 1.42, 3.55))
        if not lod:
            for wz in CHALLY_WHEEL_ZS:
                h.pipe("metal_dark", (sx * 1.13, 0.58, (wz + 0.22) * k), (sx * 1.40, 0.48, wz * k), 0.052, seg=8)

        x_in, x_out = (1.12, 1.78) if sx > 0 else (-1.78, -1.12)
        sponson_yz = [(1.40, -4.08), (1.50, -4.04), (1.50, 3.45), (1.14, 4.12), (1.02, 4.10), (1.36, 3.35)]
        h.prism_x("paint", sponson_yz, x_in, x_out, bevel=0.015, seg=1, tint=(0.98, 0.98, 0.96))
        h.box("rubber", (min(x_in, x_out) + 0.02, 0.50, -4.14), (max(x_in, x_out) - 0.02, 1.36, -4.07), bevel=0.008)

        # 6 segmented Dorchester composite ballistic skirts (`x = 1.76 .. 1.88`) + lifting lugs
        for idx in range(6):
            zf = 3.52 - idx * 1.18
            zr = zf - 1.13
            thick = 0.12 if idx < 4 else 0.075
            xo = 1.76 + thick
            x0, x1 = (1.76, xo) if sx > 0 else (-xo, -1.76)
            y_bot = 0.64 if idx < 4 else 0.78
            h.box("paint", (x0, y_bot, zr), (x1, 1.48, zf), bevel=0.014, tint=(1.01, 1.01, 0.99), jitter=0.015)
            if not lod:
                h.box("metal_dark", (sx * (xo + 0.006) - 0.008, 1.38, (zf + zr) * 0.5 - 0.05),
                      (sx * (xo + 0.006) + 0.008, 1.45, (zf + zr) * 0.5 + 0.05))
        add_british_chevron_x(h, sx * 1.888, 1.06, 0.58, sx, size=0.15)

    # Raised Perkins CV12 Rear Powerpack Deck & Twin Rear Jettisonable Fuel Drums!
    h.box("dark", (-0.94, 1.54, -3.82), (0.94, 1.59, -2.10))
    if not lod:
        for bx in (-0.48, 0.48):
            for i in range(10):
                gz = -3.74 + i * 0.16
                h.box("metal_dark", (bx - 0.38, 1.56, gz - 0.025), (bx + 0.38, 1.60, gz + 0.025))
    # Rear twin auxiliary fuel drums (classic Challenger 2 desert/deployment fit)
    for sx in (-1, 1):
        cx = sx * 0.68
        h.pipe("paint", (cx - 0.42, 1.18, -4.34), (cx + 0.42, 1.18, -4.34), 0.24, seg=8 if lod else 14, bevel=0.016, tint=(0.95, 0.95, 0.92))
        h.box("metal_dark", (cx - 0.05, 1.02, -4.16), (cx + 0.05, 1.30, -4.06))

    return h


# ==============================================================================
# CHALLENGER 2 vs CHALLENGER 3 TURRETS & 120 MM GUNS
# ==============================================================================
def build_chally_turret(lod, variant):
    t = Part("Turret", seed=73)
    bev = 0.016 if lod else 0.028
    is_cr3 = variant == "challenger_3"
    y0 = 1.54
    y_top = 2.48 if is_cr3 else 2.44

    if not is_cr3:
        # Challenger 2: Wide continuously sloped Dorchester composite cheeks + long bustle + side stowage bins
        bot_xz = [(-0.48, 1.48), (0.48, 1.48), (1.48, 0.82), (1.44, -1.68), (1.12, -2.18), (-1.12, -2.18), (-1.44, -1.68), (-1.48, 0.82)]
        top_xz = [(-0.44, 0.88), (0.44, 0.88), (1.22, 0.46), (1.24, -1.62), (0.98, -2.02), (-0.98, -2.02), (-1.24, -1.62), (-1.22, 0.46)]
        t.prism_y("paint", bot_xz, y0, y_top, top_xz=top_xz, bevel=bev, seg=1, ao_y=(y0, y_top, 0.78))

        # Side turret equipment/NBC bins & tactical chevron
        for sx in (-1, 1):
            x0, x1 = (1.26, 1.50) if sx > 0 else (-1.50, -1.26)
            t.box("paint", (x0, y0 + 0.26, -1.78), (x1, y_top - 0.12, -0.36), bevel=0.016, tint=(0.96, 0.96, 0.94))
            add_british_chevron_x(t, sx * 1.508, (y0 + y_top) * 0.52, -1.05, sx, size=0.14)
    else:
        # Challenger 3: New RBSL broad flat-angled modular turret cheeks + slab side modules + bustle!
        bot_xz = [(-0.46, 1.54), (0.46, 1.54), (1.52, 0.94), (1.50, -1.68), (1.20, -2.24), (-1.20, -2.24), (-1.50, -1.68), (-1.52, 0.94)]
        top_xz = [(-0.42, 1.04), (0.42, 1.04), (1.36, 0.56), (1.34, -1.66), (1.10, -2.10), (-1.10, -2.10), (-1.34, -1.66), (-1.36, 0.56)]
        t.prism_y("paint", bot_xz, y0, y_top, top_xz=top_xz, bevel=bev, seg=1, ao_y=(y0, y_top, 0.78))

        for sx in (-1, 1):
            # Modular bolt-on cheek blocks & vertical side armor modules
            with t.frame((sx * 1.04, y0 + 0.48, 1.08), yaw=-sx * 0.42):
                t.box("paint", (-0.42, -0.34, -0.18), (0.42, 0.34, 0.18), bevel=0.018, tint=(1.04, 1.04, 1.02))
            x0, x1 = (1.36, 1.58) if sx > 0 else (-1.58, -1.36)
            t.box("paint", (x0, y0 + 0.16, -1.62), (x1, y_top - 0.08, 0.18), bevel=0.018, tint=(1.02, 1.02, 1.0))
            if not lod:
                for bz in (-1.35, -0.80, -0.25):
                    t.cyl("metal_dark", (sx * 1.582, y0 + 0.52, bz), 0.020, 0.02, seg=6)
            add_british_chevron_x(t, sx * 1.588, y0 + 0.52, -0.72, sx, size=0.14)

    # Rear Turret Wire Stowage Basket
    if not lod:
        for ry in (y0 + 0.28, y_top - 0.14):
            t.pipe("metal_dark", (-1.18, ry, -2.54), (1.18, ry, -2.54), 0.016, seg=6)
            for sx in (-1, 1):
                t.pipe("metal_dark", (sx * 1.18, ry, -2.54), (sx * 1.18, ry, -2.12), 0.016, seg=6)
        for bx in (-1.18, -0.58, 0.0, 0.58, 1.18):
            t.pipe("metal_dark", (bx, y0 + 0.28, -2.54), (bx, y_top - 0.14, -2.54), 0.014, seg=6)
    return t


def build_chally_gun(lod, gp, variant):
    """Challenger 2: 120 mm L30A1 rifled gun + TOGS-II armored box over mantlet!
       Challenger 3: 120 mm Rheinmetall L/55A1 smoothbore gun (no TOGS box!)."""
    g = Part("Gun", seed=88)
    gy, gz = gp[1], gp[2]
    seg = 10 if lod else 20
    is_cr3 = variant == "challenger_3"

    g.box("paint", (-0.34, gy - 0.22, gz - 0.12), (0.34, gy + 0.24, gz + 0.44), bevel=0.024)

    if not is_cr3:
        # SIGNATURE Challenger 2 TOGS-II armored thermal sight box directly above gun mantlet!
        g.box("paint", (-0.28, gy + 0.22, gz - 0.06), (0.28, gy + 0.50, gz + 0.56), bevel=0.018, tint=(1.03, 1.03, 1.01))
        g.box("glass", (-0.18, gy + 0.28, gz + 0.54), (0.18, gy + 0.44, gz + 0.58), tint=OPTIC_FLIR)

    z_tip = gz + 5.26
    g.pipe("paint", (0, gy, gz + 0.40), (0, gy, gz + 2.15), 0.108, seg=seg, r2=0.100, tint=(0.98, 0.98, 0.96))
    g.pipe("paint", (0, gy + (0.0 if is_cr3 else 0.016), gz + 2.12), (0, gy + (0.0 if is_cr3 else 0.016), gz + 2.76),
           0.156, seg=seg, bevel=0.014, tint=(1.02, 1.02, 1.0))
    g.pipe("paint", (0, gy, gz + 2.74), (0, gy, z_tip - 0.16), 0.092, seg=seg, r2=0.084)

    if not lod:
        # Quilted thermal sleeve straps & MRS muzzle mirror
        for sz in (gz + 0.95, gz + 1.58, gz + 3.45, gz + 4.25):
            g.pipe("metal_dark", (0, gy, sz), (0, gy, sz + 0.04), 0.106, seg=seg)
        g.box("metal_dark", (-0.025, gy + 0.082, z_tip - 0.22), (0.025, gy + 0.15, z_tip - 0.08), bevel=0.005)

    g.tube_axis("metal_dark", (0, gy, z_tip - 0.18), (0, gy, z_tip), 0.090, 0.060, seg=seg)
    g.cyl("dark", (0, gy, z_tip - 0.19), 0.061, 0.02, seg=10)
    return g, z_tip


# ==============================================================================
# RIG ASSEMBLY
# ==============================================================================
def build_challenger_rig(lod=0, variant="challenger_2"):
    rig = VehicleRig(lod=lod)
    is_cr3 = variant == "challenger_3"
    k = 1.03
    y_roof = 2.48 if is_cr3 else 2.44
    tz = 0.14

    rig.add("Hull", rig.root_name, (0.0, 0.0, 0.0), build_chally_hull(lod, variant, k))
    ring = Part("Turret_Ring")
    ring.cyl("metal_dark", (0.0, 1.48, tz), 1.08, 0.08, seg=14 if lod else 26)
    rig.add("Turret_Ring", "Hull", (0.0, 1.52, tz), ring)
    rig.add("Turret", "Hull", (0.0, 1.54, tz), build_chally_turret(lod, variant))

    gp = (0.0, 2.02, 1.46)
    gun_part, z_tip = build_chally_gun(lod, gp, variant)
    rig.add("Gun", "Turret", gp, gun_part)
    rig.add("Muzzle", "Gun", (0.0, gp[1], z_tip), None)

    # Sights: Gunner Primary Sight (right roof) + Panoramic CITV (Orion on CR3, Pilkington on CR2)
    gs = Part("Gunner_Sight")
    gs.box("paint", (0.34, y_roof - 0.02, 0.42), (0.78, y_roof + 0.28, 0.96), bevel=0.016)
    gs.box("glass", (0.40, y_roof + 0.06, 0.94), (0.72, y_roof + 0.22, 0.98), tint=OPTIC_FLIR)
    rig.add("Gunner_Sight", "Turret", (0.56, y_roof, 0.68), gs)

    citv = Part("CITV")
    cx, cz = (-0.54, -0.18) if is_cr3 else (0.54, -0.18)
    citv.cyl("paint", (cx, y_roof, cz), 0.17, 0.28 if is_cr3 else 0.22, seg=10 if lod else 16)
    citv.box("paint", (cx - 0.19, y_roof + (0.26 if is_cr3 else 0.20), cz - 0.19),
             (cx + 0.19, y_roof + (0.52 if is_cr3 else 0.42), cz + 0.19), bevel=0.016)
    citv.box("glass", (cx - 0.13, y_roof + (0.32 if is_cr3 else 0.25), cz + 0.17),
             (cx + 0.13, y_roof + (0.46 if is_cr3 else 0.37), cz + 0.21), tint=OPTIC_FLIR)
    rig.add("CITV", "Turret", (cx, y_roof, cz), citv)

    for hname, hx, hz in (("Hatch_Commander", 0.54, -0.68), ("Hatch_Loader", -0.54, -0.68)):
        hp = Part(hname)
        hp.cyl("paint", (hx, y_roof - 0.02, hz), 0.30, 0.10, seg=10 if lod else 16, bevel=0.012)
        rig.add(hname, "Turret", (hx, y_roof + 0.02, hz - 0.28), hp)

    # Loader's L37A2 7.62 mm GPMG Pintle
    mg = Part("Commander_MG")
    mx, mz = -0.54, -0.42
    mg.cyl("metal_dark", (mx, y_roof + 0.06, mz), 0.06, 0.20, seg=8)
    mg.box("metal_dark", (mx - 0.07, y_roof + 0.24, mz - 0.16), (mx + 0.07, y_roof + 0.35, mz + 0.18), bevel=0.006)
    mg.pipe("metal_dark", (mx, y_roof + 0.30, mz + 0.16), (mx, y_roof + 0.30, mz + 0.78), 0.018, seg=8)
    rig.add("Commander_MG", "Turret", (mx, y_roof + 0.06, mz), mg)

    # Cheek Smoke Grenade Dischargers (5-barrel L8 on CR2, 4-barrel cheek pods on CR3)
    for label, side in (("L", -1), ("R", 1)):
        sm = Part(f"Smoke_Launcher_{label}")
        sx_p, sy_p, sz_p = side * (1.32 if is_cr3 else 1.18), y_roof - 0.38, 0.96
        sm.box("paint", (sx_p - 0.09, sy_p - 0.10, sz_p - 0.18), (sx_p + 0.09, sy_p + 0.10, sz_p + 0.18), bevel=0.010)
        if not lod:
            for j in range(4 if is_cr3 else 5):
                dz = (j - 1.5) * 0.08 if is_cr3 else (j - 2) * 0.07
                sm.pipe("metal_dark", (sx_p, sy_p + 0.04, sz_p + dz),
                        (sx_p + side * 0.10, sy_p + 0.12, sz_p + dz + 0.14), 0.035, seg=6)
        rig.add(f"Smoke_Launcher_{label}", "Turret", (sx_p, sy_p, sz_p), sm)

    for idx, ax in ((1, -0.96), (2, 0.96)):
        ant = Part(f"Antenna_{idx}")
        ant.cyl("metal_dark", (ax, y_roof - 0.02, -1.92), 0.038, 0.12, seg=8)
        ant.pipe("metal_dark", (ax, y_roof + 0.10, -1.92), (ax, y_roof + 1.48, -1.96), 0.011, seg=6, r2=0.004)
        rig.add(f"Antenna_{idx}", "Turret", (ax, y_roof, -1.92), ant)

    for label, side in (("L", -1), ("R", 1)):
        wx = side * 1.44
        for i, wz in enumerate(CHALLY_WHEEL_ZS):
            wp = (wx, 0.46, wz * k)
            rig.add(f"Wheel_{label}{i}", "Hull", wp, build_chally_wheel(wp, lod, side, r=0.395))
        sp_piv = (wx, 0.65 * k, -3.23 * k)
        rig.add(f"Sprocket_{label}", "Hull", sp_piv, build_chally_sprocket(sp_piv, lod, side, scale=k))
        id_piv = (wx, 0.65 * k, 3.23 * k)
        rig.add(f"Idler_{label}", "Hull", id_piv, build_chally_idler(id_piv, lod, side, scale=k))
        for i, rz in enumerate((-1.75 * k, 0.0, 1.75 * k)):
            rp = (wx, 1.04 * k, rz)
            rig.add(f"Roller_{label}{i}", "Hull", rp, build_chally_roller(rp, lod, side))
        trk = Part(f"Track_{label}")
        trk.build_track(wx, lod=lod, width=0.62)
        rig.add(f"Track_{label}", "Hull", (wx, 0.0, 0.0), trk, mesh_scale=(1.0, k, k))

    rig.add("Exhaust", "Hull", (-1.75, 1.36, -3.35), None)
    rig.add("Engine_Deck", "Hull", (0.0, 1.58, -2.95), None)
    return rig


CHALLENGER_VARIANTS = ("challenger_3", "challenger_2")


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    veh_dir = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../godot/assets/art/vehicles"))
    os.makedirs(veh_dir, exist_ok=True)
    targets = CHALLENGER_VARIANTS if ("--all" in argv or not argv) else [v for v in argv if not v.startswith("-")]
    for var in targets:
        init_scene()
        out_p = os.path.join(veh_dir, f"tank__{var}.glb")
        export_vehicle(out_p, build_challenger_rig(0, var), build_challenger_rig(1, var))
