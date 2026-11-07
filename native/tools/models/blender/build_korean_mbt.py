"""Korean & Turkish Main Battle Tanks — K2, Altay, K1A2, K1E1 (4 variants), modelled in Blender.

Variants built (`--all`):
  - tank__k2_black_panther.glb  (ROK / Poland — 6 wheels, low faceted turret + long autoloader bustle, side radar panels, CN08 120 mm L/55)
  - tank__altay.glb             (Turkiye — Stretched 7-wheel hull, wide Roketsan modular turret & heavy skirts, SARP RWS, 120 mm L/55)
  - tank__k1a2.glb              (ROK — 6-wheel low-profile hull, broader K1A2 cheeks & mantlet, 120 mm KM256 L/44 smoothbore + IFF sensor)
  - tank__k1e1.glb              (ROK — 6-wheel low-profile hull, classic angular K1 cheeks, slender 105 mm KM68A1 rifled gun w/ eccentric evacuator)

Run:
    blender -b -P native/tools/models/blender/build_korean_mbt.py -- --all
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_vehicle import Part, VehicleRig, init_scene, export_vehicle
from build_leopard import build_leo_wheel, build_sprocket, build_idler, build_roller

OPTIC_FLIR = (2.1, 1.32, 0.52)
OPTIC_COOL = (0.78, 1.36, 1.48)


def add_rok_chevron_x(part, x_plane, cy, cz, sx_out, size=0.14, thick=0.042):
    """Crisp tactical V-chevron / diamond in `markings` role flush on Korean/Turkish armor."""
    out = (sx_out, 0.0, 0.0)
    part.decal_quad("markings",
                    (x_plane, cy - size * 0.65, cz),
                    (x_plane, cy + size * 0.55, cz - size * 0.85),
                    (x_plane, cy + size * 0.55 + thick, cz - size * 0.85 + thick * 0.4),
                    (x_plane, cy - size * 0.65 + thick * 1.25, cz),
                    outward=out)
    part.decal_quad("markings",
                    (x_plane, cy - size * 0.65, cz),
                    (x_plane, cy - size * 0.65 + thick * 1.25, cz),
                    (x_plane, cy + size * 0.55 + thick, cz + size * 0.85 - thick * 0.4),
                    (x_plane, cy + size * 0.55, cz + size * 0.85),
                    outward=out)


# ==============================================================================
# K2 BLACK PANTHER (6 wheels) & TURKISH ALTAY (7 wheels)
# ==============================================================================
def build_k2_or_altay_rig(lod=0, is_altay=False):
    rig = VehicleRig(lod=lod)
    k = 1.02 if is_altay else 0.96
    bev = 0.015 if lod else 0.025
    wheel_zs = [-2.46, -1.64, -0.82, 0.00, 0.82, 1.64, 2.46] if is_altay else [-2.44, -1.46, -0.49, 0.49, 1.46, 2.44]
    z_front = 3.96 if is_altay else 3.74
    z_rear = -3.98 if is_altay else -3.76
    y_deck = 1.50 if is_altay else 1.40

    # 1. Hull
    h = Part("Hull", seed=44)
    hull_yz = [
        (0.42, z_front - 0.62),
        (0.92, z_front),
        (1.10, z_front - 0.05),
        (y_deck, 1.88),
        (y_deck, -1.75),
        (y_deck + 0.06, z_rear + 0.14),
        (1.26, z_rear),
        (0.52, z_rear + 0.14),
        (0.42, z_rear + 0.55),
    ]
    h.prism_x("paint", hull_yz, -1.16 if is_altay else -1.12, 1.16 if is_altay else 1.12,
              bevel=bev, seg=1, ao_y=(0.42, y_deck, 0.68))

    # Bow ERA / Composite Nose Module + Left-offset Driver Hatch
    h.box("paint", (-1.14, 0.78, z_front - 0.46), (1.14, 1.16, z_front + 0.04), pitch=-0.24, bevel=0.018, tint=(1.03, 1.03, 1.01))
    h.box("paint", (-0.76, y_deck - 0.02, 1.85), (-0.18, y_deck + 0.09, 2.46), bevel=0.014)
    h.box("glass", (-0.66, y_deck + 0.04, 2.43), (-0.28, y_deck + 0.10, 2.50), tint=OPTIC_COOL)

    for sx in (-1, 1):
        h.box("paint", (sx * 0.96 - 0.15, 1.12, z_front - 0.30), (sx * 0.96 + 0.15, 1.28, z_front - 0.08), bevel=0.010)
        h.box("glass", (sx * 0.96 - 0.10, 1.16, z_front - 0.10), (sx * 0.96 + 0.10, 1.24, z_front - 0.06), tint=(1.7, 1.7, 1.5))
        h.box("dark", (sx * 1.14 - 0.03, 0.44, z_rear + 0.38), (sx * 1.14 + 0.03, y_deck - 0.06, z_front - 0.38))

        x_in, x_out = (1.12, 1.78 if is_altay else 1.74) if sx > 0 else (-(1.78 if is_altay else 1.74), -1.12)
        h.box("paint", (x_in, y_deck - 0.10, z_rear + 0.06), (x_out, y_deck, z_front - 0.28), bevel=0.014, tint=(0.98, 0.98, 0.96))
        h.box("rubber", (min(x_in, x_out) + 0.02, 0.50, z_rear - 0.05), (max(x_in, x_out) - 0.02, 1.32, z_rear + 0.02), bevel=0.008)

        # Heavy ERA/NERA forward skirts + rear ballistic skirts (`xo >= 1.84` clears tracks!)
        n_sk = 7 if is_altay else 6
        step = (z_front - z_rear - 0.82) / n_sk
        for idx in range(n_sk):
            zf = (z_front - 0.38) - idx * step
            zr = zf - (step - 0.04)
            heavy = idx < (4 if is_altay else 3)
            xo = (1.92 if heavy else 1.84) if is_altay else (1.86 if heavy else 1.81)
            x0, x1 = (abs(x_out) - 0.01, xo) if sx > 0 else (-xo, -(abs(x_out) - 0.01))
            h.box("paint", (x0, 0.68 if heavy else 0.80, zr), (x1, y_deck - 0.01, zf), bevel=0.014, tint=(1.02, 1.02, 1.0))
        add_rok_chevron_x(h, sx * (1.928 if is_altay else 1.868), 1.04, 1.20, sx, size=0.14)

    h.box("dark", (-0.94, y_deck + 0.02, z_rear + 0.28), (0.94, y_deck + 0.07, -1.98))
    if not lod:
        for i in range(10):
            gz = z_rear + 0.38 + i * 0.16
            h.box("metal_dark", (-0.88, y_deck + 0.04, gz - 0.02), (0.88, y_deck + 0.08, gz + 0.02))

    rig.add("Hull", rig.root_name, (0.0, 0.0, 0.0), h)
    ring = Part("Turret_Ring")
    ring.cyl("metal_dark", (0.0, y_deck - 0.01, 0.08), 1.06, 0.08, seg=14 if lod else 24)
    rig.add("Turret_Ring", "Hull", (0.0, y_deck + 0.03, 0.08), ring)

    # 2. Turret: K2 Low Faceted Stealth-Wedge + Long Bustle vs Altay Wide Bulky Modular Turret!
    t = Part("Turret", seed=57)
    y0 = y_deck + 0.05
    y_top = y0 + (1.02 if is_altay else 0.86)
    if is_altay:
        bot_xz = [(-0.46, 1.62), (0.46, 1.62), (1.60, 0.94), (1.58, -1.56), (1.26, -2.04), (-1.26, -2.04), (-1.58, -1.56), (-1.60, 0.94)]
        top_xz = [(-0.44, 0.98), (0.44, 0.98), (1.34, 0.56), (1.38, -1.54), (1.12, -1.94), (-1.12, -1.94), (-1.38, -1.54), (-1.34, 0.56)]
    else:
        bot_xz = [(-0.36, 1.56), (0.36, 1.56), (1.46, 0.62), (1.38, -1.48), (1.04, -2.16), (-1.04, -2.16), (-1.38, -1.48), (-1.46, 0.62)]
        top_xz = [(-0.32, 0.84), (0.32, 0.84), (1.12, 0.32), (1.14, -1.46), (0.88, -2.04), (-0.88, -2.04), (-1.14, -1.46), (-1.12, 0.32)]
    t.prism_y("paint", bot_xz, y0, y_top, top_xz=top_xz, bevel=bev, seg=1, ao_y=(y0, y_top, 0.78))

    # Bustle & Cheek ERA / Soft-Kill Radar Panels
    t.box("paint", (-1.18 if is_altay else -1.04, y0 + 0.22, -2.42), (1.18 if is_altay else 1.04, y_top + 0.02, -1.54),
          bevel=0.020, tint=(0.99, 0.99, 0.97))
    if not is_altay and not lod:
        # K2 signature roof ERA / blowout rib blocks along turret spine
        for rz in (-1.65, -1.25, -0.85):
            t.box("paint", (-0.72, y_top - 0.01, rz - 0.14), (0.72, y_top + 0.05, rz + 0.14), bevel=0.008, tint=(1.03, 1.03, 1.01))

    for sx in (-1, 1):
        if is_altay:
            with t.frame((sx * 1.04, (y0 + y_top) * 0.5, 1.12), yaw=-sx * 0.42):
                t.box("paint", (-0.42, -0.34, -0.18), (0.42, 0.34, 0.18), bevel=0.018, tint=(1.03, 1.03, 1.01))
            t.box("paint", (sx * 1.44 - 0.10, y0 + 0.18, -1.42), (sx * 1.44 + 0.10, y_top - 0.08, 0.28), bevel=0.016)
            add_rok_chevron_x(t, sx * 1.548, (y0 + y_top) * 0.5, -0.58, sx, size=0.13)
        else:
            # K2 Black Panther active/soft-kill millimeter-wave flat radar panels + ERA cheek bricks!
            with t.frame((sx * 0.92, (y0 + y_top) * 0.5, 1.02), yaw=-sx * 0.52):
                t.box("paint", (-0.36, -0.26, -0.14), (0.36, 0.26, 0.14), bevel=0.014, tint=(1.04, 1.04, 1.02))
            t.box("metal_dark", (sx * 1.34 - 0.03, y0 + 0.34, -0.68), (sx * 1.34 + 0.03, y0 + 0.62, -0.26), bevel=0.006)
            t.box("paint", (sx * 1.28 - 0.08, y0 + 0.22, -1.48), (sx * 1.28 + 0.08, y_top - 0.10, -0.74), bevel=0.014)
            add_rok_chevron_x(t, sx * 1.368, (y0 + y_top) * 0.5, -1.10, sx, size=0.12)

    rig.add("Turret", "Hull", (0.0, y0, 0.08), t)

    # 3. 120 mm L/55 Smoothbore Gun (CN08 on K2 / MKE on Altay)
    gp = (0.0, y0 + (0.52 if is_altay else 0.44), 1.32)
    g = Part("Gun", seed=89)
    seg = 10 if lod else 20
    z_tip = gp[2] + 5.24
    g.box("paint", (-0.32, gp[1] - 0.22, gp[2] - 0.10), (0.32, gp[1] + 0.22, gp[2] + 0.44), bevel=0.022)
    g.pipe("paint", (0, gp[1], gp[2] + 0.40), (0, gp[1], gp[2] + 2.15), 0.110, seg=seg, r2=0.100)
    g.pipe("paint", (0, gp[1] + 0.016, gp[2] + 2.12), (0, gp[1] + 0.016, gp[2] + 2.75), 0.156, seg=seg, bevel=0.012, tint=(1.02, 1.02, 1.0))
    g.pipe("paint", (0, gp[1], gp[2] + 2.73), (0, gp[1], z_tip - 0.16), 0.092, seg=seg, r2=0.084)
    if not lod:
        g.box("metal_dark", (-0.025, gp[1] + 0.082, z_tip - 0.22), (0.025, gp[1] + 0.15, z_tip - 0.08), bevel=0.005)
    g.tube_axis("metal_dark", (0, gp[1], z_tip - 0.18), (0, gp[1], z_tip), 0.088, 0.060, seg=seg)
    g.cyl("dark", (0, gp[1], z_tip - 0.19), 0.061, 0.02, seg=10)
    rig.add("Gun", "Turret", gp, g)
    rig.add("Muzzle", "Gun", (0.0, gp[1], z_tip), None)

    # Sights, Hatches & Aselsan SARP RWS (Altay) vs K6 HMG (K2)
    gs = Part("Gunner_Sight")
    gs.box("paint", (-0.72, y_top - 0.02, 0.28), (-0.34, y_top + 0.28, 0.74), bevel=0.016)
    gs.box("glass", (-0.66, y_top + 0.06, 0.72), (-0.40, y_top + 0.22, 0.76), tint=OPTIC_FLIR)
    rig.add("Gunner_Sight", "Turret", (-0.53, y_top, 0.50), gs)

    citv = Part("CITV")
    citv.cyl("paint", (0.54, y_top, -0.08), 0.16, 0.26, seg=10 if lod else 14)
    citv.box("paint", (0.35, y_top + 0.24, -0.26), (0.73, y_top + 0.48, 0.12), bevel=0.016)
    citv.box("glass", (0.42, y_top + 0.30, 0.10), (0.66, y_top + 0.42, 0.14), tint=OPTIC_FLIR)
    rig.add("CITV", "Turret", (0.54, y_top, -0.08), citv)

    for hname, hx, hz in (("Hatch_Commander", 0.50, -0.58), ("Hatch_Loader", -0.50, -0.58)):
        hp = Part(hname)
        hp.cyl("paint", (hx, y_top - 0.02, hz), 0.28, 0.09, seg=10 if lod else 16, bevel=0.012)
        rig.add(hname, "Turret", (hx, y_top + 0.02, hz - 0.26), hp)

    wep = Part("CROWS" if is_altay else "Commander_MG")
    wx_m, wz_m = (0.0, -1.18) if is_altay else (0.52, -0.38)
    wep.cyl("metal_dark", (wx_m, y_top + 0.02, wz_m), 0.11 if is_altay else 0.07, 0.24, seg=8)
    wep.box("metal_dark", (wx_m - 0.13, y_top + 0.24, wz_m - 0.20), (wx_m + 0.13, y_top + 0.42, wz_m + 0.20), bevel=0.010)
    wep.pipe("metal_dark", (wx_m, y_top + 0.34, wz_m + 0.18), (wx_m, y_top + 0.34, wz_m + 0.94), 0.022, seg=8)
    rig.add("CROWS" if is_altay else "Commander_MG", "Turret", (wx_m, y_top + 0.02, wz_m), wep)

    for label, side in (("L", -1), ("R", 1)):
        sm = Part(f"Smoke_Launcher_{label}")
        sx_p, sy_p, sz_p = side * (1.42 if is_altay else 1.24), y_top - 0.22, 0.42
        sm.box("paint", (sx_p - 0.07, sy_p - 0.08, sz_p - 0.18), (sx_p + 0.07, sy_p + 0.08, sz_p + 0.18), bevel=0.008)
        if not lod:
            for j in range(6):
                sm.pipe("metal_dark", (sx_p, sy_p + (0.04 if j >= 3 else -0.03), sz_p + ((j % 3) - 1) * 0.09),
                        (sx_p + side * 0.09, sy_p + (0.11 if j >= 3 else 0.04), sz_p + ((j % 3) - 1) * 0.09 + 0.14), 0.032, seg=6)
        rig.add(f"Smoke_Launcher_{label}", "Turret", (sx_p, sy_p, sz_p), sm)

    for idx, ax in ((1, -0.92), (2, 0.92)):
        ant = Part(f"Antenna_{idx}")
        ant.cyl("metal_dark", (ax, y_top, -2.18), 0.036, 0.11, seg=8)
        ant.pipe("metal_dark", (ax, y_top + 0.11, -2.18), (ax, y_top + 1.45, -2.22), 0.010, seg=6, r2=0.004)
        rig.add(f"Antenna_{idx}", "Turret", (ax, y_top, -2.18), ant)

    for label, side in (("L", -1), ("R", 1)):
        wx = side * (1.48 if is_altay else 1.42)
        for i, wz in enumerate(wheel_zs):
            wp = (wx, 0.45, wz * k)
            rig.add(f"Wheel_{label}{i}", "Hull", wp, build_leo_wheel(wp, lod, side, r=0.365))
        sp_piv = (wx, 0.65 * k, -3.23 * k)
        rig.add(f"Sprocket_{label}", "Hull", sp_piv, build_sprocket(sp_piv, lod, side, scale=k))
        id_piv = (wx, 0.65 * k, 3.23 * k)
        rig.add(f"Idler_{label}", "Hull", id_piv, build_idler(id_piv, lod, side, scale=k))
        for i, rz in enumerate((-1.75 * k, 0.0, 1.75 * k)):
            rp = (wx, 1.02 * k, rz)
            rig.add(f"Roller_{label}{i}", "Hull", rp, build_roller(rp, lod, side))
        trk = Part(f"Track_{label}")
        trk.build_track(wx, lod=lod, width=0.62 if is_altay else 0.59)
        rig.add(f"Track_{label}", "Hull", (wx, 0.0, 0.0), trk, mesh_scale=(1.0, k, k))

    rig.add("Exhaust", "Hull", (0.0, 1.24, z_rear), None)
    rig.add("Engine_Deck", "Hull", (0.0, y_deck + 0.05, -2.65), None)
    return rig


# ==============================================================================
# ROKA K1A2 (120 mm KM256) & K1E1 (105 mm KM68A1) — Chrysler/GDLS Korean Lineage!
# ==============================================================================
def build_k1_rig(lod=0, upgun=True):
    rig = VehicleRig(lod=lod)
    k = 0.94
    bev = 0.014 if lod else 0.024
    wheel_zs = [-2.44, -1.46, -0.49, 0.49, 1.46, 2.44]
    y_deck = 1.38

    # 1. Low, sleek Abrams-cousin 6-wheel K1 hull (`z = -3.72 .. +3.72`)
    h = Part("Hull", seed=62)
    hull_yz = [
        (0.42, 3.06),
        (0.88, 3.74),
        (1.02, 3.70),
        (y_deck, 1.98),
        (y_deck, -1.80),
        (1.44, -3.62),
        (1.26, -3.74),
        (0.50, -3.66),
        (0.42, -3.18),
    ]
    h.prism_x("paint", hull_yz, -1.12, 1.12, bevel=bev, seg=1, ao_y=(0.42, y_deck, 0.68))

    # Left-hull driver hatch & 3 vision blocks
    h.box("paint", (-0.82, y_deck - 0.02, 1.95), (-0.22, y_deck + 0.09, 2.55), bevel=0.014)
    h.box("glass", (-0.72, y_deck + 0.04, 2.52), (-0.32, y_deck + 0.10, 2.59), tint=OPTIC_COOL)

    for sx in (-1, 1):
        h.box("paint", (sx * 0.92 - 0.14, 1.08, 3.42), (sx * 0.92 + 0.14, 1.24, 3.64), bevel=0.010)
        h.box("glass", (sx * 0.92 - 0.09, 1.12, 3.62), (sx * 0.92 + 0.09, 1.20, 3.66), tint=(1.7, 1.7, 1.5))
        h.box("dark", (sx * 1.12 - 0.03, 0.42, -3.35), (sx * 1.12 + 0.03, y_deck - 0.06, 3.32))

        x_in, x_out = (1.10, 1.74) if sx > 0 else (-1.74, -1.10)
        h.box("paint", (x_in, y_deck - 0.10, -3.68), (x_out, y_deck, 3.48), bevel=0.014, tint=(0.98, 0.98, 0.96))
        h.box("rubber", (min(x_in, x_out) + 0.02, 0.48, -3.74), (max(x_in, x_out) - 0.02, 1.28, -3.67), bevel=0.008)

        # 5 distinctive K1 beveled ballistic side skirts (`xo = 1.82`)
        for idx in range(5):
            zf = 3.35 - idx * 1.32
            zr = zf - 1.26
            xo = 1.83
            x0, x1 = (1.73, xo) if sx > 0 else (-xo, -1.73)
            h.box("paint", (x0, 0.72 if idx < 3 else 0.82, zr), (x1, y_deck - 0.01, zf), bevel=0.012, tint=(1.0, 1.0, 0.98))
        add_rok_chevron_x(h, sx * 1.838, 1.04, 0.65, sx, size=0.14)

    h.box("dark", (-0.90, y_deck + 0.02, -3.46), (0.90, y_deck + 0.07, -2.02))
    if not lod:
        for i in range(9):
            gz = -3.38 + i * 0.15
            h.box("metal_dark", (-0.86, y_deck + 0.04, gz - 0.02), (0.86, y_deck + 0.08, gz + 0.02))

    rig.add("Hull", rig.root_name, (0.0, 0.0, 0.0), h)
    ring = Part("Turret_Ring")
    ring.cyl("metal_dark", (0.0, y_deck - 0.01, 0.02), 1.04, 0.08, seg=14 if lod else 24)
    rig.add("Turret_Ring", "Hull", (0.0, y_deck + 0.03, 0.02), ring)

    # 2. K1A2 vs K1E1 Low Angular Korean Welded Turret + Bustle Basket!
    t = Part("Turret", seed=69)
    y0, y_top = y_deck + 0.05, 2.25
    cw = 0.48 if upgun else 0.40
    sw = 1.54 if upgun else 1.46
    bot_xz = [(-cw, 1.68), (cw, 1.68), (sw, 0.66), (sw - 0.04, -1.58), (1.12, -2.02), (-1.12, -2.02), (-(sw - 0.04), -1.58), (-sw, 0.66)]
    top_xz = [(-cw, 0.96), (cw, 0.96), (sw - 0.20, 0.42), (sw - 0.18, -1.54), (1.04, -1.88), (-1.04, -1.88), (-(sw - 0.18), -1.54), (-(sw - 0.20), 0.42)]
    t.prism_y("paint", bot_xz, y0, y_top, top_xz=top_xz, bevel=bev, seg=1, ao_y=(y0, y_top, 0.78))

    for sx in (-1, 1):
        # Side stowage bins & tactical mark
        x0, x1 = (sw - 0.22, sw + 0.02) if sx > 0 else (-(sw + 0.02), -(sw - 0.22))
        t.box("paint", (x0, y0 + 0.24, -1.56), (x1, y_top - 0.14, -0.68), bevel=0.014, tint=(0.97, 0.97, 0.95))
        add_rok_chevron_x(t, sx * (sw + 0.028), (y0 + y_top) * 0.52, -1.12, sx, size=0.12)

    if upgun and not lod:
        # K1A2 signature Combat Identification (IFF) cylindrical sensor mast above gun mantlet!
        t.cyl("paint", (0.0, y_top - 0.02, 0.82), 0.085, 0.24, seg=10, bevel=0.01)

    if not lod:
        for ry in (y0 + 0.24, y_top - 0.12):
            t.pipe("metal_dark", (-1.18, ry, -2.42), (1.18, ry, -2.42), 0.016, seg=6)
            for sx in (-1, 1):
                t.pipe("metal_dark", (sx * 1.18, ry, -2.42), (sx * 1.18, ry, -1.96), 0.016, seg=6)

    rig.add("Turret", "Hull", (0.0, y0, 0.02), t)

    # 3. Main Gun: K1A2 120 mm KM256 Smoothbore vs K1E1 105 mm KM68A1 Rifled!
    gp = (0.0, 1.85, 1.36)
    g = Part("Gun", seed=85)
    seg = 10 if lod else 20
    mw = 0.36 if upgun else 0.30
    g.box("paint", (-mw, gp[1] - 0.22, gp[2] - 0.10), (mw, gp[1] + 0.22, gp[2] + 0.42), bevel=0.024)
    z_tip = gp[2] + (4.62 if upgun else 4.54)
    r_b = 0.106 if upgun else 0.090
    r_m = 0.088 if upgun else 0.075
    g.pipe("paint", (0, gp[1], gp[2] + 0.38), (0, gp[1], gp[2] + 1.82), r_b, seg=seg, r2=r_b * 0.92)
    # Concentric evacuator on 120 mm KM256 vs eccentric offset evacuator on 105 mm KM68A1!
    ev_y = gp[1] if upgun else gp[1] + 0.020
    g.pipe("paint", (0, ev_y, gp[2] + 1.80), (0, ev_y, gp[2] + 2.34), 0.150 if upgun else 0.132, seg=seg, bevel=0.012, tint=(1.02, 1.02, 1.0))
    g.pipe("paint", (0, gp[1], gp[2] + 2.32), (0, gp[1], z_tip - 0.14), r_m * 1.04, seg=seg, r2=r_m)
    g.tube_axis("metal_dark", (0, gp[1], z_tip - 0.16), (0, gp[1], z_tip), r_m, 0.060 if upgun else 0.0525, seg=seg)
    g.cyl("dark", (0, gp[1], z_tip - 0.17), 0.061 if upgun else 0.053, 0.02, seg=10)
    rig.add("Gun", "Turret", gp, g)
    rig.add("Muzzle", "Gun", (0.0, gp[1], z_tip), None)

    # KGPS (left front) + KCPS Panoramic Sight (right center) + K6 .50 cal HMG
    gs = Part("Gunner_Sight")
    gs.box("paint", (-0.84, y_top - 0.02, 0.44), (-0.44, y_top + 0.25, 0.90), bevel=0.016)
    gs.box("glass", (-0.78, y_top + 0.05, 0.88), (-0.50, y_top + 0.19, 0.92), tint=OPTIC_FLIR)
    rig.add("Gunner_Sight", "Turret", (-0.64, y_top, 0.67), gs)

    citv = Part("CITV")
    citv.cyl("paint", (0.58, y_top, -0.14), 0.16, 0.22 if upgun else 0.16, seg=10 if lod else 14)
    citv.box("paint", (0.40, y_top + (0.20 if upgun else 0.14), -0.32), (0.76, y_top + (0.44 if upgun else 0.34), 0.06), bevel=0.014)
    citv.box("glass", (0.46, y_top + (0.26 if upgun else 0.19), 0.04), (0.70, y_top + (0.38 if upgun else 0.30), 0.08), tint=OPTIC_FLIR)
    rig.add("CITV", "Turret", (0.58, y_top, -0.14), citv)

    for hname, hx, hz in (("Hatch_Commander", 0.56, -0.64), ("Hatch_Loader", -0.54, -0.60)):
        hp = Part(hname)
        hp.cyl("paint", (hx, y_top - 0.02, hz), 0.28, 0.09, seg=10 if lod else 16, bevel=0.012)
        rig.add(hname, "Turret", (hx, y_top + 0.02, hz - 0.26), hp)

    mg = Part("Commander_MG")
    mg.cyl("metal_dark", (0.62, y_top + 0.04, -0.44), 0.065, 0.22, seg=8)
    mg.box("metal_dark", (0.54, y_top + 0.24, -0.60), (0.70, y_top + 0.36, -0.22), bevel=0.008)
    mg.pipe("metal_dark", (0.62, y_top + 0.30, -0.24), (0.62, y_top + 0.30, 0.56), 0.022, seg=8)
    rig.add("Commander_MG", "Turret", (0.62, y_top + 0.04, -0.44), mg)

    for label, side in (("L", -1), ("R", 1)):
        sm = Part(f"Smoke_Launcher_{label}")
        sx_p, sy_p, sz_p = side * (sw - 0.04), y0 + 0.48, -0.10
        sm.box("paint", (sx_p - 0.07, sy_p - 0.08, sz_p - 0.18), (sx_p + 0.07, sy_p + 0.08, sz_p + 0.18), bevel=0.008)
        if not lod:
            for j in range(6):
                sm.pipe("metal_dark", (sx_p, sy_p + (0.04 if j >= 3 else -0.03), sz_p + ((j % 3) - 1) * 0.09),
                        (sx_p + side * 0.09, sy_p + (0.11 if j >= 3 else 0.04), sz_p + ((j % 3) - 1) * 0.09 + 0.14), 0.032, seg=6)
        rig.add(f"Smoke_Launcher_{label}", "Turret", (sx_p, sy_p, sz_p), sm)

    for idx, ax in ((1, -0.94), (2, 0.94)):
        ant = Part(f"Antenna_{idx}")
        ant.cyl("metal_dark", (ax, y_top, -1.82), 0.036, 0.11, seg=8)
        ant.pipe("metal_dark", (ax, y_top + 0.11, -1.82), (ax, y_top + 1.45, -1.86), 0.010, seg=6, r2=0.004)
        rig.add(f"Antenna_{idx}", "Turret", (ax, y_top, -1.82), ant)

    for label, side in (("L", -1), ("R", 1)):
        wx = side * 1.42
        for i, wz in enumerate(wheel_zs):
            wp = (wx, 0.44, wz * k)
            rig.add(f"Wheel_{label}{i}", "Hull", wp, build_leo_wheel(wp, lod, side, r=0.355))
        sp_piv = (wx, 0.65 * k, -3.23 * k)
        rig.add(f"Sprocket_{label}", "Hull", sp_piv, build_sprocket(sp_piv, lod, side, scale=k))
        id_piv = (wx, 0.65 * k, 3.23 * k)
        rig.add(f"Idler_{label}", "Hull", id_piv, build_idler(id_piv, lod, side, scale=k))
        for i, rz in enumerate((-1.75 * k, 0.0, 1.75 * k)):
            rp = (wx, 1.00 * k, rz)
            rig.add(f"Roller_{label}{i}", "Hull", rp, build_roller(rp, lod, side))
        trk = Part(f"Track_{label}")
        trk.build_track(wx, lod=lod, width=0.59)
        rig.add(f"Track_{label}", "Hull", (wx, 0.0, 0.0), trk, mesh_scale=(1.0, k, k))

    rig.add("Exhaust", "Hull", (0.0, 1.18, -3.72), None)
    rig.add("Engine_Deck", "Hull", (0.0, y_deck + 0.05, -2.75), None)
    return rig


def build_korean_mbt_rig(lod=0, variant="k2_black_panther"):
    if variant == "k2_black_panther":
        return build_k2_or_altay_rig(lod, is_altay=False)
    if variant == "altay":
        return build_k2_or_altay_rig(lod, is_altay=True)
    return build_k1_rig(lod, upgun=(variant == "k1a2"))


KOREAN_MBT_VARIANTS = ("k2_black_panther", "altay", "k1a2", "k1e1")


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    veh_dir = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../godot/assets/art/vehicles"))
    os.makedirs(veh_dir, exist_ok=True)
    targets = KOREAN_MBT_VARIANTS if ("--all" in argv or not argv) else [v for v in argv if not v.startswith("-")]
    for var in targets:
        init_scene()
        out_p = os.path.join(veh_dir, f"tank__{var}.glb")
        export_vehicle(out_p, build_korean_mbt_rig(0, var), build_korean_mbt_rig(1, var))
