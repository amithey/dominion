"""Western European Main Battle Tanks — France & Italy (3 variants), modelled in Blender.

Variants built (`--all`):
  - tank__leclerc.glb    (France / UAE — Compact 6-wheel hull, modular flat-roof turret + bustle autoloader, GIAT L/52 WITHOUT bore evacuator!, HL-70 CITV)
  - tank__ariete_c2.glb  (Italy C2 — 7 wheels + 4 rollers, raised IVECO V12 powerpack deck, Attila-D + Lothar-SD optics, sloped wedge turret, OTO 120 mm L/44)
  - tank__ariete.glb     (Italy C1 — 7 wheels + 3 rollers, clean deck, straight sloped C1 wedge turret, TURMS optics, OTO 120 mm L/44)

Run:
    blender -b -P native/tools/models/blender/build_euro_mbt.py -- --all
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_vehicle import Part, VehicleRig, init_scene, export_vehicle
from build_leopard import build_leo_wheel, build_sprocket, build_idler, build_roller

OPTIC_FLIR = (2.1, 1.30, 0.52)
OPTIC_COOL = (0.75, 1.38, 1.48)


def add_nato_lozenge_x(part, x_plane, cy, cz, sx_out, size=0.14, thick=0.040):
    """Hollow NATO tactical lozenge / French-Italian squadron diamond in `markings` role."""
    out = (sx_out, 0.0, 0.0)
    for dy, dz in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        p0 = (x_plane, cy + dy * size, cz)
        p1 = (x_plane, cy, cz + dz * size * 1.15)
        p2 = (x_plane, cy, cz + dz * (size * 1.15 - thick * 1.3))
        p3 = (x_plane, cy + dy * (size - thick * 1.15), cz)
        part.decal_quad("markings", p0, p1, p2, p3, outward=out)


# ==============================================================================
# FRENCH AMX-56 LECLERC (6 wheels, k=0.88, GIAT L/52 compressed-air bore purge!)
# ==============================================================================
def build_leclerc_rig(lod=0):
    rig = VehicleRig(lod=lod)
    k = 0.88
    bev = 0.015 if lod else 0.025
    wheel_zs = [-2.44, -1.46, -0.49, 0.49, 1.46, 2.44]

    # 1. Compact French Leclerc Hull (`z = -3.44 .. +3.44`, hydropneumatic 6-wheel chassis)
    h = Part("Hull", seed=51)
    hull_yz = [
        (0.42, 2.86),
        (0.92, 3.46),
        (1.08, 3.42),
        (1.40, 1.92),
        (1.40, -1.75),
        (1.46, -3.36),
        (1.30, -3.48),
        (0.54, -3.40),
        (0.42, -2.96),
    ]
    h.prism_x("paint", hull_yz, -1.14, 1.14, bevel=bev, seg=1, ao_y=(0.42, 1.38, 0.68))

    # Left-hull driver hatch & 3 episcopes + composite front nose module
    h.box("paint", (-1.12, 0.72, 3.05), (1.12, 1.12, 3.52), pitch=-0.24, bevel=0.018, tint=(1.02, 1.02, 1.0))
    h.box("paint", (-0.78, 1.38, 1.78), (-0.18, 1.48, 2.38), bevel=0.014)
    h.box("glass", (-0.68, 1.43, 2.35), (-0.28, 1.49, 2.42), tint=OPTIC_COOL)

    for sx in (-1, 1):
        h.box("paint", (sx * 0.94 - 0.14, 1.12, 3.18), (sx * 0.94 + 0.14, 1.28, 3.40), bevel=0.010)
        h.box("glass", (sx * 0.94 - 0.09, 1.16, 3.38), (sx * 0.94 + 0.09, 1.24, 3.42), tint=(1.7, 1.7, 1.5))
        h.box("dark", (sx * 1.14 - 0.03, 0.44, -3.12), (sx * 1.14 + 0.03, 1.34, 3.08))

        x_in, x_out = (1.12, 1.76) if sx > 0 else (-1.76, -1.12)
        h.box("paint", (x_in, 1.30, -3.42), (x_out, 1.40, 3.22), bevel=0.014, tint=(0.98, 0.98, 0.96))
        h.box("rubber", (min(x_in, x_out) + 0.02, 0.50, -3.48), (max(x_in, x_out) - 0.02, 1.30, -3.41), bevel=0.008)

        # Heavy front 3 composite skirts + 3 lighter wavy rear skirts (`xo >= 1.82` clears `1.44 + 0.60*0.515 = 1.749`!)
        for idx in range(6):
            zf = 3.08 - idx * 1.06
            zr = zf - 1.02
            heavy = idx < 3
            xo = 1.87 if heavy else 1.82
            x0, x1 = (1.75, xo) if sx > 0 else (-xo, -1.75)
            h.box("paint", (x0, 0.68 if heavy else 0.80, zr), (x1, 1.39, zf), bevel=0.012, tint=(1.01, 1.01, 0.99))
        add_nato_lozenge_x(h, sx * 1.878, 1.04, 1.52, sx, size=0.14)

    # V8X Hyperbar Engine Deck + Optional Rear Drum Mounts
    h.box("dark", (-0.92, 1.43, -3.22), (0.92, 1.47, -1.92))
    if not lod:
        for i in range(9):
            gz = -3.14 + i * 0.14
            h.box("metal_dark", (-0.88, 1.45, gz - 0.02), (0.88, 1.48, gz + 0.02))
        for sx in (-1, 1):
            h.pipe("paint", (sx * 0.64 - 0.36, 1.18, -3.70), (sx * 0.64 + 0.36, 1.18, -3.70), 0.22, seg=12, bevel=0.015, tint=(0.95, 0.95, 0.92))
            h.box("metal_dark", (sx * 0.64 - 0.04, 1.06, -3.52), (sx * 0.64 + 0.04, 1.28, -3.44))

    rig.add("Hull", rig.root_name, (0.0, 0.0, 0.0), h)
    ring = Part("Turret_Ring")
    ring.cyl("metal_dark", (0.0, 1.38, 0.05), 1.04, 0.08, seg=14 if lod else 24)
    rig.add("Turret_Ring", "Hull", (0.0, 1.42, 0.05), ring)

    # 2. Leclerc Low Modular Box-Faceted Turret + Broad 22-Round Autoloader Bustle + GALIX Tubes!
    t = Part("Turret", seed=59)
    y0, y_top = 1.44, 2.28
    bot_xz = [(-0.36, 1.38), (0.36, 1.38), (1.46, 0.68), (1.44, -1.48), (1.20, -1.92), (-1.20, -1.92), (-1.44, -1.48), (-1.46, 0.68)]
    top_xz = [(-0.34, 0.98), (0.34, 0.98), (1.24, 0.48), (1.26, -1.46), (1.08, -1.84), (-1.08, -1.84), (-1.26, -1.46), (-1.24, 0.48)]
    t.prism_y("paint", bot_xz, y0, y_top, top_xz=top_xz, bevel=bev, seg=1, ao_y=(y0, y_top, 0.78))

    # Signature Leclerc thick wrap-around side modular stowage/composite pods & bustle autoloader!
    t.box("paint", (-1.12, y0 + 0.20, -2.38), (1.12, y_top + 0.02, -1.52), bevel=0.020, tint=(0.99, 0.99, 0.97))
    for sx in (-1, 1):
        x0, x1 = (1.24, 1.50) if sx > 0 else (-1.50, -1.24)
        t.box("paint", (x0, y0 + 0.14, -1.46), (x1, y_top - 0.06, 0.62), bevel=0.018, tint=(1.02, 1.02, 1.0))
        add_nato_lozenge_x(t, sx * 1.508, (y0 + y_top) * 0.5, -0.45, sx, size=0.13)
        # Flush GALIX 80 mm grenade launcher ports along rear bustle roof edge!
        if not lod:
            for gz in (-2.18, -1.98, -1.78, -1.58):
                t.cyl("metal_dark", (sx * 1.02, y_top + 0.01, gz), 0.042, 0.05, seg=8)

    rig.add("Turret", "Hull", (0.0, 1.44, 0.05), t)

    # 3. 120 mm GIAT CN120-26 L/52 Smoothbore — NO mid-barrel bore evacuator! (compressed air purge!)
    gp = (0.0, 1.88, 1.24)
    g = Part("Gun", seed=63)
    seg = 10 if lod else 20
    z_tip = gp[2] + 5.18
    g.box("paint", (-0.32, gp[1] - 0.22, gp[2] - 0.10), (0.32, gp[1] + 0.22, gp[2] + 0.42), bevel=0.022)
    # Clean uninterrupted tapered thermal jacket (distinctive Leclerc visual trademark!)
    g.pipe("paint", (0, gp[1], gp[2] + 0.38), (0, gp[1], gp[2] + 2.50), 0.112, seg=seg, r2=0.098, tint=(1.0, 1.0, 0.98))
    g.pipe("paint", (0, gp[1], gp[2] + 2.48), (0, gp[1], z_tip - 0.16), 0.098, seg=seg, r2=0.084, tint=(0.98, 0.98, 0.96))
    if not lod:
        for sz in (gp[2] + 1.05, gp[2] + 1.95, gp[2] + 3.15, gp[2] + 4.15):
            g.pipe("metal_dark", (0, gp[1], sz), (0, gp[1], sz + 0.038), 0.106, seg=seg)
        g.box("metal_dark", (-0.026, gp[1] + 0.082, z_tip - 0.22), (0.026, gp[1] + 0.15, z_tip - 0.08), bevel=0.005)
    g.tube_axis("metal_dark", (0, gp[1], z_tip - 0.18), (0, gp[1], z_tip), 0.088, 0.060, seg=seg)
    g.cyl("dark", (0, gp[1], z_tip - 0.19), 0.061, 0.02, seg=10)
    rig.add("Gun", "Turret", gp, g)
    rig.add("Muzzle", "Gun", (0.0, gp[1], z_tip), None)

    # SAVAN-20 Gunner Sight (right front) + Tall HL-70 Panoramic CITV (left roof) + M2HB coaxial/roof MG
    gs = Part("Gunner_Sight")
    gs.box("paint", (0.44, y_top - 0.04, 0.42), (0.86, y_top + 0.22, 0.88), bevel=0.016)
    gs.box("glass", (0.50, y_top + 0.02, 0.86), (0.80, y_top + 0.16, 0.90), tint=OPTIC_FLIR)
    rig.add("Gunner_Sight", "Turret", (0.65, y_top, 0.65), gs)

    citv = Part("CITV")
    citv.cyl("paint", (-0.60, y_top, -0.22), 0.17, 0.28, seg=10 if lod else 16)
    citv.box("paint", (-0.80, y_top + 0.26, -0.40), (-0.40, y_top + 0.52, -0.02), bevel=0.016)
    citv.box("glass", (-0.73, y_top + 0.32, -0.04), (-0.47, y_top + 0.46, 0.01), tint=OPTIC_FLIR)
    rig.add("CITV", "Turret", (-0.60, y_top, -0.22), citv)

    for hname, hx, hz in (("Hatch_Commander", -0.54, -0.74), ("Hatch_Loader", 0.54, -0.68)):
        hp = Part(hname)
        hp.cyl("paint", (hx, y_top - 0.02, hz), 0.29, 0.09, seg=10 if lod else 16, bevel=0.012)
        rig.add(hname, "Turret", (hx, y_top + 0.02, hz - 0.27), hp)

    mg = Part("Commander_MG")
    mg.cyl("metal_dark", (0.54, y_top + 0.05, -0.40), 0.06, 0.20, seg=8)
    mg.box("metal_dark", (0.47, y_top + 0.23, -0.56), (0.61, y_top + 0.34, -0.22), bevel=0.006)
    mg.pipe("metal_dark", (0.54, y_top + 0.29, -0.24), (0.54, y_top + 0.29, 0.42), 0.018, seg=8)
    rig.add("Commander_MG", "Turret", (0.54, y_top + 0.05, -0.40), mg)

    for label, side in (("L", -1), ("R", 1)):
        sm = Part(f"Smoke_Launcher_{label}")
        sm.box("paint", (side * 1.12 - 0.08, y_top - 0.02, -2.26), (side * 1.12 + 0.08, y_top + 0.09, -1.72), bevel=0.008)
        rig.add(f"Smoke_Launcher_{label}", "Turret", (side * 1.12, y_top, -2.00), sm)

    for idx, ax in ((1, -0.96), (2, 0.96)):
        ant = Part(f"Antenna_{idx}")
        ant.cyl("metal_dark", (ax, y_top, -2.28), 0.036, 0.11, seg=8)
        ant.pipe("metal_dark", (ax, y_top + 0.11, -2.28), (ax, y_top + 1.45, -2.32), 0.010, seg=6, r2=0.004)
        rig.add(f"Antenna_{idx}", "Turret", (ax, y_top, -2.28), ant)

    for label, side in (("L", -1), ("R", 1)):
        wx = side * 1.44
        for i, wz in enumerate(wheel_zs):
            wp = (wx, 0.43, wz * k)
            rig.add(f"Wheel_{label}{i}", "Hull", wp, build_leo_wheel(wp, lod, side, r=0.355))
        sp_piv = (wx, 0.65 * k, -3.23 * k)
        rig.add(f"Sprocket_{label}", "Hull", sp_piv, build_sprocket(sp_piv, lod, side, scale=k))
        id_piv = (wx, 0.65 * k, 3.23 * k)
        rig.add(f"Idler_{label}", "Hull", id_piv, build_idler(id_piv, lod, side, scale=k))
        for i, rz in enumerate((-1.75 * k, 0.0, 1.75 * k)):
            rp = (wx, 1.00 * k, rz)
            rig.add(f"Roller_{label}{i}", "Hull", rp, build_roller(rp, lod, side))
        trk = Part(f"Track_{label}")
        trk.build_track(wx, lod=lod, width=0.60)
        rig.add(f"Track_{label}", "Hull", (wx, 0.0, 0.0), trk, mesh_scale=(1.0, k, k))

    rig.add("Exhaust", "Hull", (-1.70, 1.24, -3.20), None)
    rig.add("Engine_Deck", "Hull", (0.0, 1.46, -2.55), None)
    return rig


# ==============================================================================
# ITALIAN C1 ARIETE & C2 ARIETE (7 wheels, sloped arrow-wedge turret, OTO L/44)
# ==============================================================================
def build_ariete_rig(lod=0, is_c2=False):
    rig = VehicleRig(lod=lod)
    k = 1.00 if is_c2 else 0.96
    bev = 0.015 if lod else 0.025
    wheel_zs = [-2.46, -1.64, -0.82, 0.00, 0.82, 1.64, 2.46]
    z_front = 3.92 if is_c2 else 3.78
    z_rear = -3.96 if is_c2 else -3.80
    y_deck = 1.50 if is_c2 else 1.45

    h = Part("Hull", seed=64)
    hull_yz = [
        (0.44, z_front - 0.64),
        (0.94, z_front),
        (1.10, z_front - 0.06),
        (y_deck, 1.95),
        (y_deck, -1.70),
        (y_deck + (0.14 if is_c2 else 0.04), z_rear + 0.14),
        (1.32, z_rear),
        (0.54, z_rear + 0.12),
        (0.44, z_rear + 0.56),
    ]
    h.prism_x("paint", hull_yz, -1.14, 1.14, bevel=bev, seg=1, ao_y=(0.44, y_deck, 0.68))

    # Right-side Italian driver hatch (`x = +0.58`) + 3 periscopes!
    h.box("paint", (0.28, y_deck - 0.02, 1.82), (0.86, y_deck + 0.09, 2.46), bevel=0.014)
    h.box("glass", (0.38, y_deck + 0.04, 2.43), (0.76, y_deck + 0.10, 2.50), tint=OPTIC_COOL)

    # Ariete C2 raised 1,500 hp IVECO V12 MTCA elongated engine deck!
    if is_c2:
        h.box("paint", (-1.04, y_deck - 0.02, -3.65), (1.04, y_deck + 0.18, -1.85), bevel=0.020, tint=(0.98, 0.99, 0.96))
        h.box("dark", (-0.88, y_deck + 0.15, -3.45), (0.88, y_deck + 0.19, -2.05))
        if not lod:
            for i in range(10):
                gz = -3.38 + i * 0.14
                h.box("metal_dark", (-0.84, y_deck + 0.17, gz - 0.02), (0.84, y_deck + 0.20, gz + 0.02))
    else:
        h.box("dark", (-0.90, y_deck - 0.01, -3.52), (0.90, y_deck + 0.04, -2.05))
        if not lod:
            for i in range(9):
                gz = -3.44 + i * 0.15
                h.box("metal_dark", (-0.86, y_deck + 0.02, gz - 0.02), (0.86, y_deck + 0.05, gz + 0.02))

    for sx in (-1, 1):
        h.box("paint", (sx * 0.92 - 0.14, 1.14, z_front - 0.34), (sx * 0.92 + 0.14, 1.30, z_front - 0.12), bevel=0.010)
        h.box("glass", (sx * 0.92 - 0.09, 1.18, z_front - 0.14), (sx * 0.92 + 0.09, 1.26, z_front - 0.10), tint=(1.7, 1.7, 1.5))
        h.box("dark", (sx * 1.14 - 0.03, 0.44, z_rear + 0.38), (sx * 1.14 + 0.03, y_deck - 0.06, z_front - 0.38))

        x_in, x_out = (1.12, 1.76) if sx > 0 else (-1.76, -1.12)
        h.box("paint", (x_in, y_deck - 0.10, z_rear + 0.06), (x_out, y_deck, z_front - 0.32), bevel=0.014, tint=(0.98, 0.98, 0.96))
        h.box("rubber", (min(x_in, x_out) + 0.02, 0.50, z_rear - 0.05), (max(x_in, x_out) - 0.02, 1.34, z_rear + 0.02), bevel=0.008)

        # 7 clean Italian ballistic side skirts (`xo = 1.84` clears `1.44 + 0.62*0.515 = 1.759`!)
        for idx in range(7):
            zf = (z_front - 0.42) - idx * 1.02
            zr = zf - 0.97
            xo = 1.86 if (is_c2 and idx < 4) else 1.83
            x0, x1 = (1.75, xo) if sx > 0 else (-xo, -1.75)
            h.box("paint", (x0, 0.72, zr), (x1, y_deck - 0.02, zf), bevel=0.012, tint=(1.0, 1.0, 0.98))
        add_nato_lozenge_x(h, sx * (1.868 if is_c2 else 1.838), 1.06, 0.45, sx, size=0.14)

    rig.add("Hull", rig.root_name, (0.0, 0.0, 0.0), h)
    ring = Part("Turret_Ring")
    ring.cyl("metal_dark", (0.0, y_deck - 0.01, 0.10), 1.06, 0.09, seg=14 if lod else 24)
    rig.add("Turret_Ring", "Hull", (0.0, y_deck + 0.04, 0.10), ring)

    # 2. Ariete Straight-Sloped Arrow-Wedge Welded Turret + Rear Basket!
    t = Part("Turret", seed=71)
    y0 = y_deck + 0.06
    y_top = y0 + (0.96 if is_c2 else 0.92)
    bot_xz = [(-0.44, 1.46), (0.44, 1.46), (1.46, 0.72), (1.44, -1.38), (1.10, -1.92), (-1.10, -1.92), (-1.44, -1.38), (-1.46, 0.72)]
    top_xz = [(-0.42, 0.80), (0.42, 0.80), (1.14, 0.44), (1.20, -1.38), (0.98, -1.80), (-0.98, -1.80), (-1.20, -1.38), (-1.14, 0.44)]
    t.prism_y("paint", bot_xz, y0, y_top, top_xz=top_xz, bevel=bev, seg=1, ao_y=(y0, y_top, 0.78))

    for sx in (-1, 1):
        x0, x1 = (1.24, 1.46) if sx > 0 else (-1.46, -1.24)
        t.box("paint", (x0, y0 + 0.24, -1.52), (x1, y_top - 0.16, -0.52), bevel=0.016, tint=(0.97, 0.97, 0.95))
        add_nato_lozenge_x(t, sx * 1.468, (y0 + y_top) * 0.52, -1.02, sx, size=0.12)

    if not lod:
        for ry in (y0 + 0.26, y_top - 0.14):
            t.pipe("metal_dark", (-1.14, ry, -2.32), (1.14, ry, -2.32), 0.016, seg=6)
            for sx in (-1, 1):
                t.pipe("metal_dark", (sx * 1.14, ry, -2.32), (sx * 1.14, ry, -1.86), 0.016, seg=6)
        for bx in (-1.14, -0.56, 0.0, 0.56, 1.14):
            t.pipe("metal_dark", (bx, y0 + 0.26, -2.32), (bx, y_top - 0.14, -2.32), 0.014, seg=6)

    rig.add("Turret", "Hull", (0.0, y0, 0.10), t)

    # 3. OTO Melara 120 mm L/44 Smoothbore Gun
    gp = (0.0, y0 + 0.46, 1.32)
    g = Part("Gun", seed=83)
    seg = 10 if lod else 20
    z_tip = gp[2] + 4.46
    g.box("paint", (-0.34, gp[1] - 0.22, gp[2] - 0.10), (0.34, gp[1] + 0.22, gp[2] + 0.42), bevel=0.022)
    g.pipe("paint", (0, gp[1], gp[2] + 0.38), (0, gp[1], gp[2] + 1.82), 0.110, seg=seg, r2=0.100)
    g.pipe("paint", (0, gp[1] + 0.015, gp[2] + 1.80), (0, gp[1] + 0.015, gp[2] + 2.40), 0.154, seg=seg, bevel=0.012, tint=(1.02, 1.02, 1.0))
    g.pipe("paint", (0, gp[1], gp[2] + 2.38), (0, gp[1], z_tip - 0.16), 0.092, seg=seg, r2=0.084)
    g.tube_axis("metal_dark", (0, gp[1], z_tip - 0.18), (0, gp[1], z_tip), 0.088, 0.060, seg=seg)
    g.cyl("dark", (0, gp[1], z_tip - 0.19), 0.061, 0.02, seg=10)
    rig.add("Gun", "Turret", gp, g)
    rig.add("Muzzle", "Gun", (0.0, gp[1], z_tip), None)

    # Optics: Lothar-SD / TURMS Gunner Sight + Attila-D / SP-T-694 Panoramic CITV
    gs = Part("Gunner_Sight")
    gx = 0.58 if is_c2 else -0.64
    gs.box("paint", (gx - 0.24, y_top - 0.02, 0.56), (gx + 0.24, y_top + 0.28, 1.04), bevel=0.016)
    gs.box("glass", (gx - 0.16, y_top + 0.06, 1.02), (gx + 0.16, y_top + 0.22, 1.06), tint=OPTIC_FLIR)
    rig.add("Gunner_Sight", "Turret", (gx, y_top, 0.80), gs)

    citv = Part("CITV")
    cx, cz = (-0.64, 0.08) if is_c2 else (0.58, -0.05)
    citv.cyl("paint", (cx, y_top, cz), 0.16, 0.24, seg=10 if lod else 14)
    citv.box("paint", (cx - 0.20, y_top + 0.22, cz - 0.20), (cx + 0.20, y_top + 0.48, cz + 0.20), bevel=0.016)
    citv.box("glass", (cx - 0.14, y_top + 0.28, cz + 0.18), (cx + 0.14, y_top + 0.42, cz + 0.22), tint=OPTIC_FLIR)
    rig.add("CITV", "Turret", (cx, y_top, cz), citv)

    for hname, hx, hz in (("Hatch_Commander", 0.54, -0.58), ("Hatch_Loader", -0.54, -0.62)):
        hp = Part(hname)
        hp.cyl("paint", (hx, y_top - 0.02, hz), 0.29, 0.09, seg=10 if lod else 16, bevel=0.012)
        rig.add(hname, "Turret", (hx, y_top + 0.02, hz - 0.27), hp)

    mg = Part("Commander_MG")
    mg.cyl("metal_dark", (0.54, y_top + 0.05, -0.34), 0.06, 0.20, seg=8)
    mg.box("metal_dark", (0.47, y_top + 0.23, -0.50), (0.61, y_top + 0.34, -0.16), bevel=0.006)
    mg.pipe("metal_dark", (0.54, y_top + 0.29, -0.18), (0.54, y_top + 0.29, 0.48), 0.018, seg=8)
    rig.add("Commander_MG", "Turret", (0.54, y_top + 0.05, -0.34), mg)

    # 4-barrel Galix/OTO smoke launchers on turret rear flanks
    for label, side in (("L", -1), ("R", 1)):
        sm = Part(f"Smoke_Launcher_{label}")
        sx_p, sy_p, sz_p = side * 1.44, y0 + 0.56, -0.22
        sm.box("paint", (sx_p - 0.06, sy_p - 0.08, sz_p - 0.18), (sx_p + 0.06, sy_p + 0.08, sz_p + 0.18), bevel=0.008)
        if not lod:
            for j in range(4):
                sm.pipe("metal_dark", (sx_p, sy_p + 0.02, sz_p - 0.12 + j * 0.08),
                        (sx_p + side * 0.09, sy_p + 0.09, sz_p + 0.02 + j * 0.08), 0.034, seg=6)
        rig.add(f"Smoke_Launcher_{label}", "Turret", (sx_p, sy_p, sz_p), sm)

    for idx, ax in ((1, -0.96), (2, 0.96)):
        ant = Part(f"Antenna_{idx}")
        ant.cyl("metal_dark", (ax, y_top, -1.68), 0.036, 0.11, seg=8)
        ant.pipe("metal_dark", (ax, y_top + 0.11, -1.68), (ax, y_top + 1.45, -1.72), 0.010, seg=6, r2=0.004)
        rig.add(f"Antenna_{idx}", "Turret", (ax, y_top, -1.68), ant)

    rollers = [-2.05, -0.68, 0.68, 2.05] if is_c2 else [-1.75, 0.0, 1.75]
    for label, side in (("L", -1), ("R", 1)):
        wx = side * 1.44
        for i, wz in enumerate(wheel_zs):
            wp = (wx, 0.45, wz * k)
            rig.add(f"Wheel_{label}{i}", "Hull", wp, build_leo_wheel(wp, lod, side, r=0.345))
        sp_piv = (wx, 0.65 * k, -3.23 * k)
        rig.add(f"Sprocket_{label}", "Hull", sp_piv, build_sprocket(sp_piv, lod, side, scale=k))
        id_piv = (wx, 0.65 * k, 3.23 * k)
        rig.add(f"Idler_{label}", "Hull", id_piv, build_idler(id_piv, lod, side, scale=k))
        for i, rz in enumerate(rollers):
            rp = (wx, 1.02 * k, rz * k)
            rig.add(f"Roller_{label}{i}", "Hull", rp, build_roller(rp, lod, side))
        trk = Part(f"Track_{label}")
        trk.build_track(wx, lod=lod, width=0.62 if is_c2 else 0.59)
        rig.add(f"Track_{label}", "Hull", (wx, 0.0, 0.0), trk, mesh_scale=(1.0, k, k))

    rig.add("Exhaust", "Hull", (-1.72, 1.28, -3.45), None)
    rig.add("Engine_Deck", "Hull", (0.0, y_deck + (0.18 if is_c2 else 0.04), -2.75), None)
    return rig


def build_euro_rig(lod=0, variant="leclerc"):
    if variant == "leclerc":
        return build_leclerc_rig(lod)
    return build_ariete_rig(lod, is_c2=(variant == "ariete_c2"))


EURO_VARIANTS = ("leclerc", "ariete_c2", "ariete")


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    veh_dir = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../godot/assets/art/vehicles"))
    os.makedirs(veh_dir, exist_ok=True)
    targets = EURO_VARIANTS if ("--all" in argv or not argv) else [v for v in argv if not v.startswith("-")]
    for var in targets:
        init_scene()
        out_p = os.path.join(veh_dir, f"tank__{var}.glb")
        export_vehicle(out_p, build_euro_rig(0, var), build_euro_rig(1, var))
