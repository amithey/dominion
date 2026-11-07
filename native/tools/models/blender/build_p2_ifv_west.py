"""Tier P2.1A — Heavy Tracked APC & Western/Asian Tracked IFVs (13 vehicles), modelled in Blender 5.2.

Run all 13 variants:
    blender -b -P native/tools/models/blender/build_p2_ifv_west.py -- --all

Vehicles produced (`native/godot/assets/art/vehicles/`):
  1. heavyAPC__namer.glb            (IDF Namer Trophy 'Meil Ruach' Heavy APC on Merkava Mk 4 chassis)
  2. ifv__m2a4_bradley.glb          (US M2A4 Bradley w/ BUSK ERA, CIV sight, 25mm M242 & twin TOW pod)
  3. ifv__m2a2_bradley.glb          (US M2A2 ODS-SA Bradley w/ BUSK ERA, IBAS sight, 25mm & twin TOW pod)
  4. ifv__puma_ifv.glb              (German Puma IFV w/ CLARA ERA skirts, unmanned RCT-30, shrouded 30mm & Spike)
  5. ifv__lynx_kf41_lance_italy.glb (KF41 Lynx w/ faceted Lance 2.0 turret, 35mm Wotan & dual Spike-LR2 pods)
  6. ifv__cv9035nl.glb              (BAE Hägglunds CV9035NL w/ 7 wheels, stealth faceted hull & 35mm Bushmaster III)
  7. ifv__warrior.glb               (British FV510 Warrior w/ appliqué armor, 30mm Rarden & rear troop doors)
  8. ifv__dardo_ifv.glb             (Italian VCC-80 Dardo w/ Hitfist-25 turret, 25mm KBA & dual side TOW pods)
  9. ifv__as21_redback.glb          (Hanwha AS21 Redback w/ T2000 turret, Iron Fist APS & 30mm Mk44S)
 10. ifv__k21_ifv.glb               (ROK K21 NIFV w/ amphibious flotation fairings, 40mm L/70 & Raybolt pod)
 11. ifv__k21_korean_legacy.glb     (ROK K21 early production w/ amphibious fairings & 40mm Bofors L/70)
 12. ifv__type_89_ifv.glb           (JGSDF Type 89 IFV w/ dual cheek Type 79 Jyu-MAT ATGM boxes & 35mm KDE)
 13. ifv__acv_15.glb                (Turkish FNSS ACV-15 5-wheel AIFV w/ spaced bow & Sharpshooter 25mm turret)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_vehicle import Part, VehicleRig, init_scene, export_vehicle
from build_merkava import (
    add_idf_chevron_x,
    build_merkava_wheel,
    build_front_sprocket,
    build_rear_idler,
)

OPTIC_FLIR = (0.25, 1.35, 0.95)
OPTIC_COOL = (0.35, 1.15, 1.45)
TAIL_RED = (2.8, 0.25, 0.20)


# =============================================================================
# SHARED WESTERN IFV RUNNING GEAR
# =============================================================================

def build_ifv_road_wheel(wp, lod, side, r=0.33, ribs=6):
    """Sculpted rubber-tyred IFV dual road wheel with recessed dish & radial stiffeners."""
    p = Part(f"Wheel_{side}")
    s = side
    with p.frame(wp):
        if lod:
            prof = [
                (-0.18, 0.0, "paint", 0.78),
                (-0.18, r, "rubber", 1.0),
                (0.18, r, "paint", 0.86),
                (0.18, 0.0, "paint", 0.86),
            ]
            p.lathe_x((0, 0, 0), prof, seg=8)
            return p

        ri = r * 0.72
        prof_r = [
            (-0.18, 0.0, "metal_dark", 0.45),
            (-0.18, ri, "paint", 0.75),
            (-0.175, ri + 0.015, "rubber", 0.92),
            (-0.175, r, "rubber", 1.0),
            (-0.032, r, "metal_dark", 0.40),
            (-0.028, r * 0.65, "metal_dark", 0.36),
            (0.028, r * 0.65, "rubber", 0.92),
            (0.032, r, "rubber", 1.0),
            (0.175, r, "paint", 0.92),
            (0.175, ri + 0.015, "paint", 0.84),
            (0.135, ri * 0.88, "paint", 0.72),
            (0.150, r * 0.34, "paint", 0.92),
            (0.150, 0.0, "paint", 0.92),
        ]
        if s < 0:
            prof = []
            for i in range(len(prof_r) - 1, -1, -1):
                x_cur, r_cur, _, _ = prof_r[i]
                rp = prof_r[i - 1][2] if i > 0 else "paint"
                kp = prof_r[i - 1][3] if i > 0 else 0.9
                prof.append((-x_cur, r_cur, rp, kp))
            p.lathe_x((0, 0, 0), prof, seg=18)
        else:
            p.lathe_x((0, 0, 0), prof_r, seg=18)

        p.pipe("paint", (s * 0.14, 0, 0), (s * 0.195, 0, 0), r * 0.28, seg=12, r2=r * 0.21, bevel=0.008)
        for k in range(ribs):
            a = math.tau * k / ribs
            if ribs > 0:
                with p.frame((s * 0.152, 0, 0), pitch=a):
                    p.box("paint", (-0.012, r * 0.26, -0.014), (0.012, ri * 0.92, 0.014), bevel=0.003, tint=(0.90, 0.90, 0.88))
            else:
                pass
        for b in range(10):
            ba = math.tau * b / 10.0
            p.pipe("metal_dark", (s * 0.142, ri * 0.78 * math.cos(ba), ri * 0.78 * math.sin(ba)),
                   (s * 0.162, ri * 0.78 * math.cos(ba), ri * 0.78 * math.sin(ba)), 0.013, seg=5)
    return p


def build_ifv_sprocket(wp, lod, side, r=0.35):
    """Front-mounted IFV drive sprocket (since virtually all IFVs mount front engines for rear troop ramps!)."""
    p = Part(f"Sprocket_{side}")
    s = side
    seg = 10 if lod else 18
    with p.frame(wp):
        prof = [
            (-0.18, 0.0, "metal_dark", 0.52),
            (-0.18, r, "paint", 0.80),
            (-0.12, r * 1.02, "metal_dark", 0.45),
            (-0.10, r * 0.76, "metal_dark", 0.40),
            (0.10, r * 0.76, "paint", 0.84),
            (0.12, r * 1.02, "paint", 0.90),
            (0.18, r, "paint", 0.88),
            (0.18, 0.0, "paint", 0.88),
        ]
        p.lathe_x((0, 0, 0), prof, seg=seg)
        p.pipe("paint", (s * 0.10, 0, 0), (s * 0.22, 0, 0), r * 0.52, seg=seg, r2=r * 0.36, bevel=0.012)
        if not lod:
            for tx in (-0.15, 0.15):
                for k in range(11):
                    a = math.tau * k / 11.0
                    with p.frame((tx, 0, 0), pitch=a):
                        p.box("metal", (-0.018, r * 0.94, -0.036), (0.018, r * 1.18, 0.036), bevel=0.005)
    return p


def build_ifv_idler(wp, lod, side, r=0.33):
    p = Part(f"Idler_{side}")
    s = side
    seg = 8 if lod else 16
    with p.frame(wp):
        prof = [
            (-0.16, 0.0, "metal_dark", 0.50),
            (-0.16, r, "metal", 0.90),
            (-0.04, r, "metal_dark", 0.44),
            (-0.03, r * 0.68, "metal_dark", 0.44),
            (0.03, r * 0.68, "paint", 0.78),
            (0.04, r, "metal", 0.92),
            (0.16, r, "paint", 0.88),
            (0.16, 0.0, "paint", 0.88),
        ]
        p.lathe_x((0, 0, 0), prof, seg=seg)
        p.pipe("paint", (s * 0.14, 0, 0), (s * 0.19, 0, 0), r * 0.32, seg=10, r2=r * 0.24, bevel=0.007)
    return p


def build_ifv_roller(wp, lod, side, r=0.13):
    p = Part(f"Roller_{side}")
    with p.frame(wp):
        p.pipe("rubber", (-0.14, 0, 0), (-0.03, 0, 0), r, seg=8 if lod else 12)
        p.pipe("rubber", (0.03, 0, 0), (0.14, 0, 0), r, seg=8 if lod else 12)
        p.pipe("paint", (-0.16, 0, 0), (0.16, 0, 0), r * 0.58, seg=8)
    return p


def add_nato_diamond(part, x_plane, cy, cz, sx_out, size=0.14):
    out = (sx_out, 0.0, 0.0)
    for sy_arm in (-1.0, 1.0):
        t = 0.032
        part.decal_quad(
            "markings",
            (x_plane, cy + sy_arm * size, cz),
            (x_plane, cy + sy_arm * (size - t * 1.4), cz),
            (x_plane, cy, cz + size * 0.82 - t * 1.1),
            (x_plane, cy, cz + size * 0.82),
            outward=out,
        )
        part.decal_quad(
            "markings",
            (x_plane, cy + sy_arm * (size - t * 1.4), cz),
            (x_plane, cy + sy_arm * size, cz),
            (x_plane, cy, cz - size * 0.82),
            (x_plane, cy, cz - size * 0.82 + t * 1.1),
            outward=out,
        )


# =============================================================================
# 1. IDF NAMER HEAVY APC (`heavyAPC__namer`)
# =============================================================================

def build_namer_rig(lod=0):
    """IDF Namer Trophy ('Meil Ruach') Heavy APC built on the front-engine Merkava Mk 4 chassis."""
    rig = VehicleRig(lod=lod)
    track_scale = 0.98
    track_x = 1.48
    wheel_zs = [-2.52, -1.52, -0.52, 0.48, 1.48, 2.48]

    hull = Part("Hull")
    # 1. Merkava Mk 4 lower tub & front-engine asymmetric sloped glacis
    hull_prof = [
        (-3.68, 0.50),
        (-3.50, 0.34),
        (2.85, 0.34),
        (3.48, 0.54),
        (3.92, 0.96),
        (3.84, 1.12),
        (1.30, 1.56),
        (-3.62, 1.56),
        (-3.76, 1.38),
    ]
    hull.profile_x("paint", hull_prof, -1.16, 1.16, bevel=0.018 if not lod else 0.0, ao_y=(0.34, 2.25))

    # Raised Namer armoured troop superstructure (replaces Merkava turret ring!)
    casemate_prof = [
        (-3.58, 1.52),
        (1.48, 1.52),
        (1.02, 2.16),
        (-3.36, 2.16),
    ]
    hull.profile_x("paint", casemate_prof, -1.18, 1.18, bevel=0.022 if not lod else 0.0, tint=(1.02, 1.02, 1.00))
    # Sloped composite side shoulders over sponsons
    for sx in (-1, 1):
        hull.wedge("paint", (sx * 1.46, 1.54, -3.54), (sx * 1.16, 2.14, 1.00), axis="y", slope_dir="-x" if sx < 0 else "+x", bevel=0.014 if not lod else 0.0)
        hull.box("paint", (sx * 1.16, 1.32, -3.65), (sx * 1.80, 1.56, 3.74), bevel=0.014 if not lod else 0.0)

    # Right-side raised front AVDS-1790 engine deck + right-flank armored exhaust louver box!
    glacis_pitch = math.atan2(1.56 - 1.12, 3.84 - 1.30)
    with hull.frame((0.46, 1.36, 2.58), pitch=glacis_pitch):
        hull.box("paint", (-0.64, -0.02, -1.15), (0.64, 0.14, 1.12), bevel=0.016 if not lod else 0.0, tint=(1.03, 1.03, 1.01))
        if not lod:
            for i in range(10):
                lz = -0.85 + i * 0.17
                hull.box("dark", (-0.48, 0.135, lz - 0.045), (0.48, 0.155, lz + 0.045))

    hull.box("paint", (1.76, 1.14, 0.95), (1.92, 1.54, 2.25), bevel=0.012 if not lod else 0.0)
    if not lod:
        for i in range(9):
            lz = 1.06 + i * 0.135
            hull.box("dark", (1.90, 1.20, lz - 0.04), (1.93, 1.48, lz + 0.04))

        # Left driver recess + 3 angled periscopes
        hull.box("dark", (-0.96, 1.48, 1.48), (-0.36, 1.58, 1.98))
        hull.cyl("paint", (-0.66, 1.56, 1.62), 0.25, 0.055, seg=16, bevel=0.008)
        for dx, yaw in ((-0.15, 0.30), (0.0, 0.0), (0.15, -0.30)):
            with hull.frame((-0.66 + dx, 1.60, 1.90), yaw=yaw):
                hull.box("paint", (-0.055, 0.0, -0.05), (0.055, 0.08, 0.05), bevel=0.005)
                hull.box("glass", (-0.045, 0.02, 0.046), (0.045, 0.068, 0.056), tint=OPTIC_COOL)

        # Heavy spring-hung ballistic modular side skirts (6 per side) + IDF chevrons
        sk_z = [-3.64, -2.42, -1.20, 0.02, 1.24, 2.46, 3.66]
        for sx in (-1, 1):
            xi, xo = sx * 1.80, sx * 1.90
            for idx in range(6):
                z0, z1 = sk_z[idx] + 0.016, sk_z[idx + 1] - 0.016
                y_bot = 0.62 if idx in (0, 5) else 0.46
                hull.box("paint", (xi, y_bot, z0), (xo, 1.52, z1), bevel=0.012, tint=(0.98 + 0.015 * (idx % 2),) * 3)
                hull.box("metal_dark", (xo - sx * 0.01, 1.42, (z0 + z1) * 0.5 - 0.06),
                         (xo + sx * 0.014, 1.55, (z0 + z1) * 0.5 + 0.06), bevel=0.004)
            add_idf_chevron_x(hull, sx * 1.906, 1.00, 0.63, sx, arm_len=0.20, mode="down")
            add_idf_chevron_x(hull, sx * 1.46, 1.86, -1.20, sx, arm_len=0.20, mode="forward",
                              x_fn=lambda y, s=sx: s * (1.46 - (y - 1.54) * (0.30 / 0.60)))

        # Trophy 'Meil Ruach' APS: 4 Elta WindGuard AESA radar panels + 2 launcher hemispheres on superstructure!
        for sx in (-1, 1):
            with hull.frame((sx * 1.18, 2.02, 0.72), yaw=sx * (-0.65)):
                hull.box("paint", (-0.16, -0.14, -0.05), (0.16, 0.14, 0.05), bevel=0.008)
                hull.box("metal_dark", (-0.13, -0.11, 0.045), (0.13, 0.11, 0.062), tint=(1.15, 1.12, 1.05))
            with hull.frame((sx * 1.18, 2.02, -3.12), yaw=math.pi + sx * 0.65):
                hull.box("paint", (-0.16, -0.14, -0.05), (0.16, 0.14, 0.05), bevel=0.008)
                hull.box("metal_dark", (-0.13, -0.11, 0.045), (0.13, 0.11, 0.062), tint=(1.15, 1.12, 1.05))
            # Trophy rotating launcher assembly mid-flank
            hull.box("paint", (sx * 1.16, 1.98, -1.45), (sx * 1.46, 2.24, -0.82), bevel=0.010)
            hull.cyl("metal_dark", (sx * 1.32, 2.24, -1.14), 0.15, 0.16, seg=14, bevel=0.01)
            hull.dome("metal_dark", (sx * 1.32, 2.40, -1.14), 0.14, 0.10, seg=12, rings=4)

        # Roof hatches, commander panoramic cupola, rear squad hatches & side stowage baskets
        hull.cyl("paint", (-0.48, 2.16, 0.25), 0.34, 0.10, seg=18, bevel=0.010)
        for k in range(6):
            ka = math.tau * k / 6.0
            with hull.frame((-0.48 + 0.28 * math.sin(ka), 2.22, 0.25 + 0.28 * math.cos(ka)), yaw=ka):
                hull.box("glass", (-0.045, 0.0, -0.02), (0.045, 0.055, 0.025), tint=OPTIC_COOL)
        for z_h in (-1.20, -2.35):
            hull.box("paint", (-0.65, 2.16, z_h - 0.36), (0.65, 2.22, z_h + 0.36), bevel=0.010, tint=(0.94, 0.94, 0.92))

        # Open tubular rear side stowage baskets + hydraulic rear infantry assault ramp w/ sniper port!
        for sx in (-1, 1):
            bx0, bx1 = sorted((sx * 1.20, sx * 1.68))
            hull.box("metal_dark", (bx0, 1.60, -3.56), (bx1, 1.64, -1.80), bevel=0.005)
            for ry in (1.78, 1.94, 2.08):
                hull.pipe("metal_dark", (sx * 1.67, ry, -3.56), (sx * 1.67, ry, -1.80), 0.014, seg=6)
                hull.pipe("metal_dark", (sx * 1.20, ry, -3.56), (sx * 1.67, ry, -3.56), 0.014, seg=6)
                hull.pipe("metal_dark", (sx * 1.20, ry, -1.80), (sx * 1.67, ry, -1.80), 0.014, seg=6)
            for pz in (-3.55, -2.96, -2.38, -1.81):
                hull.pipe("metal_dark", (sx * 1.67, 1.62, pz), (sx * 1.67, 2.09, pz), 0.015, seg=6)
            hull.box("paint", (sx * 1.18, 0.72, -3.86), (sx * 1.72, 1.54, -3.58), bevel=0.012)
            hull.box("glass", (sx * 1.40, 1.34, -3.88), (sx * 1.56, 1.44, -3.85), tint=TAIL_RED)
            # Front armored headlight clusters + tow shackles
            hull.box("paint", (sx * 1.24, 1.06, 3.74), (sx * 1.56, 1.28, 3.94), bevel=0.010)
            hull.cyl("glass", (sx * 1.40, 1.17, 3.94), 0.055, 0.02, axis="z", seg=10, tint=(1.8, 1.8, 1.6))
            hull.tube_axis("metal_dark", (sx * 0.84 - 0.04, 0.70, 3.90), (sx * 0.84 + 0.04, 0.70, 3.90), 0.085, 0.04, axis="x", seg=10)
        # Rear hydraulic assault ramp + central armored door
        hull.box("paint", (-0.72, 0.58, -3.82), (0.72, 1.98, -3.62), bevel=0.016, tint=(0.92, 0.92, 0.90))
        hull.box("metal_dark", (-0.16, 1.42, -3.85), (0.16, 1.66, -3.80), bevel=0.006)
        hull.cyl("metal_dark", (-0.80, 0.64, -3.76), 0.055, 0.90, seg=8)
        hull.cyl("metal_dark", (0.80, 0.64, -3.76), 0.055, 0.90, seg=8)
        # Twin rear IDF whip antennas (raises overall height cleanly)
        for sx in (-1, 1):
            hull.cyl("metal_dark", (sx * 1.10, 2.16, -3.28), 0.035, 0.14, seg=8)
            hull.cyl("dark", (sx * 1.10, 2.30, -3.28), 0.012, 1.25, seg=6)
    else:
        for sx in (-1, 1):
            hull.box("paint", (sx * 1.80, 0.50, -3.64), (sx * 1.90, 1.52, 3.66))

    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hull)

    # Tracks & Merkava front-drive running gear
    for side_lbl, sx in (("L", -1), ("R", 1)):
        tp = Part(f"Track_{side_lbl}")
        tp.build_track(sx * track_x, lod=lod, width=0.64)
        rig.add(f"Track_{side_lbl}", f"LOD{lod}", (sx * track_x, 0.0, 0.0), tp, mesh_scale=(1.0, track_scale, track_scale))
        sp_p = (sx * track_x, 0.68 * track_scale, 3.22 * track_scale)
        id_p = (sx * track_x, 0.65 * track_scale, -3.24 * track_scale)
        rig.add(f"Sprocket_{side_lbl}", f"LOD{lod}", sp_p, build_front_sprocket(sp_p, lod, sx))
        rig.add(f"Idler_{side_lbl}", f"LOD{lod}", id_p, build_rear_idler(id_p, lod, sx))
        for i, wz in enumerate(wheel_zs):
            wp = (sx * track_x, 0.39, wz * track_scale)
            rig.add(f"Wheel_{side_lbl}{i}", f"LOD{lod}", wp, build_merkava_wheel(wp, lod, sx))
        if not lod:
            for r_i, rz in enumerate((-1.90, 0.0, 1.90)):
                rp = (sx * track_x, 1.07, rz)
                rig.add(f"Roller_{side_lbl}{r_i}", f"LOD{lod}", rp, build_ifv_roller(rp, lod, sx))

    # Katlanit / Samson RCWS Turret + .50 cal M2HB Gun + Muzzle (`Muzzle` 1.38 m from `Turret` pivot!)
    t_piv = (0.44, 2.18, 0.42)
    turret = Part("Turret")
    turret.cyl("metal_dark", (0.44, 2.16, 0.42), 0.32, 0.08, seg=16, bevel=0.008)
    turret.box("paint", (0.20, 2.24, 0.16), (0.68, 2.62, 0.64), bevel=0.012 if not lod else 0.0)
    # Right-side FLIR / day-TV optronics pod + left-side armored .50 cal ammo chest
    turret.box("paint", (0.68, 2.30, 0.26), (0.94, 2.58, 0.62), bevel=0.010 if not lod else 0.0)
    if not lod:
        turret.box("glass", (0.71, 2.35, 0.615), (0.91, 2.53, 0.630), tint=OPTIC_FLIR)
        turret.box("paint", (-0.06, 2.32, 0.18), (0.20, 2.58, 0.56), bevel=0.008, tint=(0.88, 0.88, 0.86))
        # ISMI 6-tube smoke grenade launcher cluster on superstructure front
        for k in range(6):
            turret.cyl("metal_dark", (0.22 + k * 0.08, 2.28, 0.68), 0.028, 0.16, axis="z", seg=8)
    rig.add("Turret", "Hull", t_piv, turret)

    g_piv = (0.44, 2.50, 0.56)
    gun = Part("Gun")
    gun.box("metal_dark", (0.35, 2.41, 0.32), (0.53, 2.60, 0.88), bevel=0.008 if not lod else 0.0)
    # Perforated M2HB barrel jacket + long heavy .50 cal barrel + flash suppressor
    gun.cyl("metal_dark", (0.44, 2.50, 0.88), 0.038, 0.36, axis="z", seg=10)
    gun.cyl("metal_dark", (0.44, 2.50, 1.24), 0.020, 0.58, axis="z", seg=10)
    gun.tube_axis("metal_dark", (0.44, 2.50, 1.78), (0.44, 2.50, 1.88), 0.030, 0.016, axis="z", seg=10)
    rig.add("Gun", "Turret", g_piv, gun)
    rig.add("Muzzle", "Gun", (0.44, 2.50, 1.88), None)  # dist from t_piv = hypot(0.32, 1.46) = 1.49 m!
    return rig


# =============================================================================
# PARAMETRIC WESTERN / ASIAN TRACKED IFV BUILDER (12 IFVs)
# =============================================================================

IFV_SPECS = {
    "ifv__m2a4_bradley": {
        "style": "bradley_a4",
        "track_scale": 0.88, "track_x": 1.42, "track_w": 0.54,
        "wheel_r": 0.33, "wheels": [-2.18, -1.31, -0.44, 0.43, 1.30, 2.17], "rollers": [-1.20, 1.15],
        "hull_l": 6.55, "hull_w": 2.32, "hull_h": 1.66,
        "turret_x": 0.24, "turret_z": -0.18, "turret_h": 0.62,
        "gun_len": 2.05, "gun_cal": 0.032, "atgm": "tow_left", "era": True, "civ": True,
    },
    "ifv__m2a2_bradley": {
        "style": "bradley_a2",
        "track_scale": 0.88, "track_x": 1.42, "track_w": 0.54,
        "wheel_r": 0.33, "wheels": [-2.18, -1.31, -0.44, 0.43, 1.30, 2.17], "rollers": [-1.20, 1.15],
        "hull_l": 6.55, "hull_w": 2.32, "hull_h": 1.64,
        "turret_x": 0.24, "turret_z": -0.18, "turret_h": 0.62,
        "gun_len": 2.05, "gun_cal": 0.032, "atgm": "tow_left", "era": True, "civ": False,
    },
    "ifv__puma_ifv": {
        "style": "puma",
        "track_scale": 0.95, "track_x": 1.50, "track_w": 0.50,
        "wheel_r": 0.35, "wheels": [-2.42, -1.45, -0.48, 0.48, 1.45, 2.42], "rollers": [-1.40, 0.0, 1.40],
        "hull_l": 7.35, "hull_w": 2.44, "hull_h": 1.62,
        "turret_x": -0.18, "turret_z": -0.25, "turret_h": 0.52,
        "gun_len": 2.45, "gun_cal": 0.038, "atgm": "spike_left", "era": True, "shrouded_gun": True,
    },
    "ifv__lynx_kf41_lance_italy": {
        "style": "lynx",
        "track_scale": 0.98, "track_x": 1.52, "track_w": 0.54,
        "wheel_r": 0.36, "wheels": [-2.50, -1.50, -0.50, 0.50, 1.50, 2.50], "rollers": [-1.45, 0.0, 1.45],
        "hull_l": 7.65, "hull_w": 2.48, "hull_h": 1.78,
        "turret_x": 0.0, "turret_z": -0.12, "turret_h": 0.68,
        "gun_len": 2.55, "gun_cal": 0.042, "atgm": "spike_dual", "era": False,
    },
    "ifv__cv9035nl": {
        "style": "cv90",
        "track_scale": 0.90, "track_x": 1.42, "track_w": 0.54,
        "wheel_r": 0.33, "wheels": [-2.34, -1.56, -0.78, 0.0, 0.78, 1.56, 2.34], "rollers": [],
        "hull_l": 6.75, "hull_w": 2.36, "hull_h": 1.52,
        "turret_x": 0.0, "turret_z": -0.22, "turret_h": 0.58,
        "gun_len": 2.48, "gun_cal": 0.042, "atgm": None, "era": False,
    },
    "ifv__warrior": {
        "style": "warrior",
        "track_scale": 0.84, "track_x": 1.34, "track_w": 0.48,
        "wheel_r": 0.33, "wheels": [-2.05, -1.23, -0.41, 0.41, 1.23, 2.05], "rollers": [-1.15, 1.15],
        "hull_l": 6.34, "hull_w": 2.18, "hull_h": 1.66,
        "turret_x": 0.0, "turret_z": 0.05, "turret_h": 0.64,
        "gun_len": 2.25, "gun_cal": 0.036, "atgm": None, "era": True,
    },
    "ifv__dardo_ifv": {
        "style": "dardo",
        "track_scale": 0.86, "track_x": 1.36, "track_w": 0.48,
        "wheel_r": 0.33, "wheels": [-2.12, -1.27, -0.42, 0.42, 1.27, 2.12], "rollers": [-1.15, 0.0, 1.15],
        "hull_l": 6.65, "hull_w": 2.24, "hull_h": 1.56,
        "turret_x": 0.0, "turret_z": -0.05, "turret_h": 0.58,
        "gun_len": 2.05, "gun_cal": 0.032, "atgm": "tow_dual", "era": False,
    },
    "ifv__as21_redback": {
        "style": "redback",
        "track_scale": 0.94, "track_x": 1.48, "track_w": 0.54,
        "wheel_r": 0.35, "wheels": [-2.38, -1.43, -0.48, 0.48, 1.43, 2.38], "rollers": [-1.35, 0.0, 1.35],
        "hull_l": 7.15, "hull_w": 2.42, "hull_h": 1.68,
        "turret_x": 0.0, "turret_z": -0.10, "turret_h": 0.64,
        "gun_len": 2.32, "gun_cal": 0.038, "atgm": "spike_left", "aps": True,
    },
    "ifv__k21_ifv": {
        "style": "k21",
        "track_scale": 0.90, "track_x": 1.42, "track_w": 0.52,
        "wheel_r": 0.34, "wheels": [-2.25, -1.35, -0.45, 0.45, 1.35, 2.25], "rollers": [-1.25, 0.0, 1.25],
        "hull_l": 6.90, "hull_w": 2.36, "hull_h": 1.60,
        "turret_x": 0.0, "turret_z": -0.14, "turret_h": 0.62,
        "gun_len": 2.65, "gun_cal": 0.045, "atgm": "spike_left", "flotation": True,
    },
    "ifv__k21_korean_legacy": {
        "style": "k21",
        "track_scale": 0.90, "track_x": 1.42, "track_w": 0.52,
        "wheel_r": 0.34, "wheels": [-2.25, -1.35, -0.45, 0.45, 1.35, 2.25], "rollers": [-1.25, 0.0, 1.25],
        "hull_l": 6.90, "hull_w": 2.36, "hull_h": 1.60,
        "turret_x": 0.0, "turret_z": -0.14, "turret_h": 0.60,
        "gun_len": 2.65, "gun_cal": 0.045, "atgm": None, "flotation": True, "legacy": True,
    },
    "ifv__type_89_ifv": {
        "style": "type89",
        "track_scale": 0.88, "track_x": 1.38, "track_w": 0.48,
        "wheel_r": 0.33, "wheels": [-2.18, -1.31, -0.44, 0.44, 1.31, 2.18], "rollers": [-1.25, 0.0, 1.25],
        "hull_l": 6.80, "hull_w": 2.26, "hull_h": 1.56,
        "turret_x": 0.0, "turret_z": -0.18, "turret_h": 0.60,
        "gun_len": 2.38, "gun_cal": 0.040, "atgm": "jyu_mat_dual",
    },
    "ifv__acv_15": {
        "style": "acv15",
        "track_scale": 0.72, "track_x": 1.24, "track_w": 0.42,
        "wheel_r": 0.31, "wheels": [-1.72, -0.86, 0.0, 0.86, 1.72], "rollers": [-0.86, 0.86],
        "hull_l": 5.36, "hull_w": 2.02, "hull_h": 1.68,
        "turret_x": 0.24, "turret_z": 0.05, "turret_h": 0.54,
        "gun_len": 1.85, "gun_cal": 0.032, "atgm": None,
    },
}


def build_west_ifv_rig(slug, lod=0):
    s = IFV_SPECS[slug]
    rig = VehicleRig(lod=lod)
    ts = s["track_scale"]
    tx = s["track_x"]
    tw = s["track_w"]
    hl = s["hull_l"] * 0.5
    hw = s["hull_w"] * 0.5
    hh = s["hull_h"]
    style = s["style"]

    hull = Part("Hull")
    # 1. Sloped front-engine IFV hull profile
    bow_tip_y = 0.98 if style in ("cv90", "k21") else 1.08
    hull_prof = [
        (-hl, 0.54),
        (-hl + 0.22, 0.34),
        (hl - 0.82, 0.34),
        (hl - 0.16, 0.62),
        (hl + 0.16, bow_tip_y),
        (hl - 0.04, bow_tip_y + 0.16),
        (hl - 1.55, hh),
        (-hl + 0.08, hh),
        (-hl - 0.08, hh - 0.28),
    ]
    hull.profile_x("paint", hull_prof, -hw, hw, bevel=0.018 if not lod else 0.0, ao_y=(0.34, hh + 0.4))

    # Sponson fenders over tracks + outer ballistic skirts (strictly clearing tracks!)
    sk_xi = tx + tw * 0.515 + 0.025
    sk_xo = sk_xi + (0.14 if s.get("era") or style in ("puma", "lynx", "redback") else 0.08)
    for sx in (-1, 1):
        # Sponson upper shelf
        if style == "cv90":
            # CV90 signature inward-sloped stealth upper superstructure!
            hull.wedge("paint", (sx * sk_xi, hh - 0.24, -hl + 0.10), (sx * (hw - 0.05), hh + 0.12, hl - 0.35),
                       axis="y", slope_dir="-x" if sx < 0 else "+x", bevel=0.012 if not lod else 0.0)
        else:
            hull.box("paint", (sx * hw, hh - 0.24, -hl + 0.08), (sx * sk_xi, hh, hl - 0.12), bevel=0.012 if not lod else 0.0)

        if not lod:
            n_pan = 5 if style == "acv15" else 6
            z_start, z_end = -hl + 0.10, hl - 0.10
            dz = (z_end - z_start) / n_pan
            for idx in range(n_pan):
                p_z0 = z_start + idx * dz + 0.014
                p_z1 = z_start + (idx + 1) * dz - 0.014
                y_bot = 0.66 if idx in (0, n_pan - 1) else 0.52
                hull.box("paint", (sx * sk_xi, y_bot, p_z0), (sx * sk_xo, hh - 0.02, p_z1),
                         bevel=0.010, tint=(0.98 + 0.018 * (idx % 2),) * 3)
                if s.get("era"):
                    # BUSK / CLARA / Chobham reactive ERA bricks on side skirts!
                    for ry in (0.70, 1.06):
                        if ry + 0.28 < hh:
                            hull.box("paint", (sx * sk_xo, ry, p_z0 + 0.02),
                                     (sx * (sk_xo + 0.065), ry + 0.30, p_z1 - 0.02),
                                     bevel=0.008, tint=(0.92, 0.94, 0.90))
                elif s.get("flotation"):
                    # K21 inflatable amphibious side flotation bag casing
                    hull.box("paint", (sx * sk_xo, hh - 0.42, p_z0), (sx * (sk_xo + 0.075), hh - 0.05, p_z1),
                             bevel=0.014, tint=(0.93, 0.94, 0.91))
            add_nato_diamond(hull, sx * ((sk_xo + 0.068) if s.get("era") else (sk_xo + 0.004)), 1.05, 0.25, sx, size=0.13)
        else:
            hull.box("paint", (sx * sk_xi, 0.54, -hl + 0.10), (sx * sk_xo, hh - 0.02, hl - 0.10))

    if not lod:
        # Front-right engine intake louvers & exhaust grille (authentic IFV layout: driver left, powerpack right!)
        glacis_pitch = math.atan2(hh - (bow_tip_y + 0.16), (hl - 0.04) - (hl - 1.55))
        with hull.frame((hw * 0.44, (hh + bow_tip_y + 0.16) * 0.5, hl - 0.80), pitch=glacis_pitch):
            hull.box("paint", (-hw * 0.42, -0.01, -0.62), (hw * 0.42, 0.065, 0.62), bevel=0.010, tint=(0.95, 0.95, 0.93))
            for i in range(7):
                lz = -0.48 + i * 0.16
                hull.box("dark", (-hw * 0.34, 0.060, lz - 0.04), (hw * 0.34, 0.076, lz + 0.04))

        # Driver hatch + 3 periscopes on front-left deck
        hull.cyl("paint", (-hw * 0.52, hh, hl - 1.38), 0.26, 0.06, seg=16, bevel=0.008)
        for dx, yaw in ((-0.13, 0.28), (0.0, 0.0), (0.13, -0.28)):
            with hull.frame((-hw * 0.52 + dx, hh + 0.04, hl - 1.12), yaw=yaw):
                hull.box("paint", (-0.05, 0.0, -0.045), (0.05, 0.075, 0.045), bevel=0.004)
                hull.box("glass", (-0.04, 0.018, 0.042), (0.04, 0.065, 0.052), tint=OPTIC_COOL)

        # Amphibious bow trim vane on Bradley / K21 / ACV-15
        if style in ("bradley_a4", "bradley_a2", "k21", "acv15"):
            hull.box("paint", (-hw * 0.92, bow_tip_y + 0.06, hl - 0.12), (hw * 0.92, bow_tip_y + 0.24, hl + 0.02),
                     bevel=0.008, tint=(0.90, 0.91, 0.88))

        # Headlights + front tow shackles
        for sx in (-1, 1):
            hull.box("paint", (sx * (hw + 0.05), bow_tip_y - 0.02, hl - 0.16), (sx * (sk_xi - 0.04), bow_tip_y + 0.18, hl + 0.04), bevel=0.008)
            hull.cyl("glass", (sx * (hw + 0.16), bow_tip_y + 0.08, hl + 0.04), 0.05, 0.02, axis="z", seg=10, tint=(1.8, 1.8, 1.6))
            hull.tube_axis("metal_dark", (sx * hw * 0.65 - 0.035, 0.68, hl + 0.14), (sx * hw * 0.65 + 0.035, 0.68, hl + 0.14), 0.075, 0.035, axis="x", seg=8)

        # Rear infantry troop ramp + integral emergency troop door + tail lights + roof squad hatches
        if style == "warrior":
            # Warrior double rear doors
            for sx in (-1, 1):
                hull.box("paint", (sx * 0.04, 0.58, -hl - 0.12), (sx * (hw * 0.78), hh - 0.10, -hl + 0.02), bevel=0.012, tint=(0.93, 0.93, 0.91))
        else:
            hull.box("paint", (-hw * 0.82, 0.56, -hl - 0.12), (hw * 0.82, hh - 0.08, -hl + 0.02), bevel=0.014, tint=(0.92, 0.92, 0.90))
            hull.box("paint", (-0.52, 0.68, -hl - 0.16), (0.14, hh - 0.20, -hl - 0.10), bevel=0.008, tint=(0.96, 0.96, 0.94))
            hull.cyl("metal_dark", (-hw * 0.86, 0.62, -hl - 0.08), 0.045, 0.78, seg=8)
            hull.cyl("metal_dark", (hw * 0.86, 0.62, -hl - 0.08), 0.045, 0.78, seg=8)
        for sx in (-1, 1):
            hull.box("glass", (sx * (hw + 0.08), hh - 0.22, -hl - 0.02), (sx * (hw + 0.22), hh - 0.12, -hl + 0.02), tint=TAIL_RED)
        # Rear troop compartment roof hatch
        hull.box("paint", (-0.58, hh, -hl + 0.35), (0.58, hh + 0.055, -hl + 1.35), bevel=0.008, tint=(0.94, 0.94, 0.92))

    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hull)

    # 2. Tracks & Front-Drive IFV Running Gear
    wr = s["wheel_r"]
    for side_lbl, sx in (("L", -1), ("R", 1)):
        tp = Part(f"Track_{side_lbl}")
        tp.build_track(sx * tx, lod=lod, width=tw)
        rig.add(f"Track_{side_lbl}", f"LOD{lod}", (sx * tx, 0.0, 0.0), tp, mesh_scale=(1.0, ts, ts))
        sp_p = (sx * tx, 0.68 * ts, 3.22 * ts)
        id_p = (sx * tx, 0.65 * ts, -3.24 * ts)
        rig.add(f"Sprocket_{side_lbl}", f"LOD{lod}", sp_p, build_ifv_sprocket(sp_p, lod, sx, r=wr * 1.04))
        rig.add(f"Idler_{side_lbl}", f"LOD{lod}", id_p, build_ifv_idler(id_p, lod, sx, r=wr * 0.98))
        for i, wz in enumerate(s["wheels"]):
            wp = (sx * tx, wr, wz)
            rig.add(f"Wheel_{side_lbl}{i}", f"LOD{lod}", wp, build_ifv_road_wheel(wp, lod, sx, r=wr))
        if not lod:
            for r_i, rz in enumerate(s["rollers"]):
                rp = (sx * tx, 1.06 * ts, rz)
                rig.add(f"Roller_{side_lbl}{r_i}", f"LOD{lod}", rp, build_ifv_roller(rp, lod, sx))

    # 3. Turret (`Turret` + `Gun` + `Muzzle`)
    tur_x, tur_z = s["turret_x"], s["turret_z"]
    th = s["turret_h"]
    t_piv = (tur_x, hh + 0.02, tur_z)

    ring = Part("Turret_Ring")
    ring_r = 0.62 if style in ("puma", "acv15") else 0.86
    ring.cyl("metal_dark", (tur_x, hh - 0.02, tur_z), ring_r, 0.07, seg=20 if not lod else 10)
    rig.add("Turret_Ring", "Hull", t_piv, ring)

    turret = Part("Turret")
    tw_b = 0.68 if style in ("puma", "acv15") else 0.98
    tl_f = 0.88 if style in ("puma", "acv15") else 1.12
    tl_r = -0.95 if style in ("puma", "acv15") else -1.28
    base_pts = [
        (-tw_b * 0.55, tl_f),
        (tw_b * 0.55, tl_f),
        (tw_b, tl_f * 0.30),
        (tw_b * 0.92, tl_r * 0.65),
        (tw_b * 0.68, tl_r),
        (-tw_b * 0.68, tl_r),
        (-tw_b * 0.92, tl_r * 0.65),
        (-tw_b, tl_f * 0.30),
    ]
    top_pts = [(x * 0.78 + tur_x, z * 0.84 + tur_z) for x, z in base_pts]
    bot_pts = [(x + tur_x, z + tur_z) for x, z in base_pts]
    turret.frustum_xz("paint", bot_pts, top_pts, hh + 0.04, hh + 0.04 + th, bevel=0.018 if not lod else 0.0)

    if not lod:
        ty_top = hh + 0.04 + th
        # Gunner primary sight doghouse + commander panoramic sight (CITV/CIV/SEOSS/UTAAS)
        turret.box("paint", (tur_x + 0.22, ty_top, tur_z + 0.18), (tur_x + 0.56, ty_top + 0.24, tur_z + 0.58), bevel=0.008)
        turret.box("glass", (tur_x + 0.26, ty_top + 0.05, tur_z + 0.575), (tur_x + 0.52, ty_top + 0.19, tur_z + 0.59), tint=OPTIC_FLIR)

        if not s.get("legacy"):
            turret.cyl("paint", (tur_x - 0.28, ty_top, tur_z - 0.18), 0.14, 0.14, seg=12)
            turret.box("paint", (tur_x - 0.44, ty_top + 0.14, tur_z - 0.34), (tur_x - 0.12, ty_top + 0.36, tur_z - 0.02), bevel=0.008)
            turret.box("glass", (tur_x - 0.40, ty_top + 0.18, tur_z - 0.025), (tur_x - 0.16, ty_top + 0.32, tur_z - 0.01), tint=OPTIC_COOL)

        # Crew hatches on manned turrets
        if style != "puma":
            turret.cyl("paint", (tur_x + 0.30, ty_top, tur_z - 0.28), 0.24, 0.05, seg=14, bevel=0.006)
            if style != "acv15":
                turret.cyl("paint", (tur_x - 0.30, ty_top, tur_z - 0.52), 0.22, 0.05, seg=14, bevel=0.006)

        # Redback Iron Fist APS launchers + corner radars on T2000 turret!
        if s.get("aps"):
            for sx in (-1, 1):
                turret.box("paint", (tur_x + sx * (tw_b * 0.85), ty_top - 0.18, tur_z - 0.65),
                           (tur_x + sx * (tw_b * 1.08), ty_top + 0.08, tur_z - 0.15), bevel=0.008)
                for st in (-0.12, 0.12):
                    turret.cyl("metal_dark", (tur_x + sx * (tw_b * 0.98), ty_top + 0.14, tur_z - 0.40 + st), 0.055, 0.26, axis="z", seg=8)

        # ATGM Launcher Pods (signature IFV silhouette feature!)
        atgm = s.get("atgm")
        if atgm == "tow_left":
            # M2 Bradley armored rectangular twin-tube TOW launcher pod on port cheek!
            lx0, lx1 = tur_x - tw_b - 0.42, tur_x - tw_b + 0.04
            turret.box("paint", (lx0, hh + 0.18, tur_z - 0.68), (lx1, ty_top - 0.02, tur_z + 0.62), bevel=0.012, tint=(0.94, 0.94, 0.92))
            for dy in (0.14, 0.34):
                turret.tube_axis("dark", (0.5 * (lx0 + lx1), hh + 0.14 + dy, tur_z + 0.55),
                                 (0.5 * (lx0 + lx1), hh + 0.14 + dy, tur_z + 0.65), 0.095, 0.075, axis="z", seg=12)
        elif atgm == "tow_dual":
            # Italian Dardo twin single-tube TOW pods on BOTH cheeks
            for sx in (-1, 1):
                cx = tur_x + sx * (tw_b + 0.18)
                turret.box("paint", (cx - 0.14, hh + 0.22, tur_z - 0.55), (cx + 0.14, hh + 0.50, tur_z + 0.55), bevel=0.010)
                turret.tube_axis("metal_dark", (cx, hh + 0.36, tur_z + 0.50), (cx, hh + 0.36, tur_z + 0.66), 0.09, 0.07, axis="z", seg=12)
        elif atgm == "spike_left":
            lx0, lx1 = tur_x - tw_b - 0.32, tur_x - tw_b + 0.02
            turret.box("paint", (lx0, hh + 0.22, tur_z - 0.52), (lx1, ty_top - 0.04, tur_z + 0.48), bevel=0.010, tint=(0.93, 0.94, 0.91))
            for dx in (-0.08, 0.08):
                turret.cyl("metal_dark", (0.5 * (lx0 + lx1) + dx, hh + 0.38, tur_z + 0.44), 0.055, 0.12, axis="z", seg=10)
        elif atgm == "spike_dual":
            # KF41 Lynx integrated stealth side pods
            for sx in (-1, 1):
                cx = tur_x + sx * (tw_b + 0.16)
                turret.box("paint", (cx - 0.15, hh + 0.18, tur_z - 0.62), (cx + 0.15, ty_top - 0.06, tur_z + 0.48), bevel=0.012)
                turret.cyl("metal_dark", (cx, hh + 0.36, tur_z + 0.45), 0.065, 0.10, axis="z", seg=10)
        elif atgm == "jyu_mat_dual":
            # Japanese Type 89 IFV twin rectangular Type 79 Jyu-MAT box launchers on both cheeks
            for sx in (-1, 1):
                cx = tur_x + sx * (tw_b + 0.20)
                turret.box("paint", (cx - 0.16, hh + 0.24, tur_z - 0.58), (cx + 0.16, hh + 0.48, tur_z + 0.62), bevel=0.008)

        # Smoke grenade clusters + rear turret basket + twin whip antennas (ensures height > 2.6 m)
        for sx in (-1, 1):
            for k in range(4):
                with turret.frame((tur_x + sx * (tw_b * 0.72), hh + 0.28 + 0.04 * (k % 2), tur_z + tl_f * 0.62 + 0.05 * (k // 2)),
                                  yaw=sx * 0.32, pitch=-0.38):
                    turret.cyl("metal_dark", (0, 0, 0), 0.032, 0.17, axis="z", seg=8)
            turret.cyl("metal_dark", (tur_x + sx * (tw_b * 0.60), ty_top, tur_z + tl_r + 0.12), 0.030, 0.12, seg=8)
            turret.cyl("dark", (tur_x + sx * (tw_b * 0.60), ty_top + 0.12, tur_z + tl_r + 0.12), 0.011, 1.05, seg=6)
        turret.box("metal_dark", (tur_x - tw_b * 0.64, hh + 0.16, tur_z + tl_r - 0.34),
                   (tur_x + tw_b * 0.64, ty_top - 0.08, tur_z + tl_r), bevel=0.008, tint=(0.65, 0.65, 0.65))

    rig.add("Turret", "Hull", t_piv, turret)

    # 4. Autocannon (`Gun` + `Muzzle`)
    g_piv = (tur_x, hh + 0.04 + th * 0.48, tur_z + tl_f * 0.85)
    gy, gz = g_piv[1], g_piv[2]
    gun = Part("Gun")
    cal = s["gun_cal"]
    glen = s["gun_len"]

    # Armored gun mantlet + coaxial 7.62mm MG
    gun.box("paint", (tur_x - 0.22, gy - 0.15, gz - 0.24), (tur_x + 0.22, gy + 0.16, gz + 0.24), bevel=0.012 if not lod else 0.0)
    if s.get("shrouded_gun"):
        # German Puma triangular structural composite barrel shroud!
        gun.box("paint", (tur_x - 0.085, gy - 0.08, gz + 0.20), (tur_x + 0.085, gy + 0.09, gz + glen * 0.78), bevel=0.010 if not lod else 0.0)
        gun.cyl("metal_dark", (tur_x, gy, gz + glen * 0.78), cal, glen * 0.22, axis="z", seg=12)
    else:
        # Stepped autocannon recoil cradle + fluted barrel
        gun.cyl("paint", (tur_x, gy, gz + 0.20), cal * 1.85, glen * 0.28, axis="z", seg=12)
        gun.cyl("metal_dark", (tur_x, gy, gz + 0.20 + glen * 0.28), cal * 1.25, glen * 0.34, axis="z", seg=12)
        gun.cyl("metal_dark", (tur_x, gy, gz + 0.20 + glen * 0.62), cal, glen * 0.38, axis="z", seg=12)
    # Slotted muzzle brake / ABM programmer coil
    muz_z = gz + 0.20 + glen
    gun.tube_axis("metal_dark", (tur_x, gy, muz_z - 0.04), (tur_x, gy, muz_z + 0.12), cal * 1.55, cal * 0.75, axis="z", seg=12)
    if not lod:
        gun.cyl("metal_dark", (tur_x + 0.13, gy + 0.02, gz + 0.24), 0.015, 0.42, axis="z", seg=8)

    rig.add("Gun", "Turret", g_piv, gun)
    rig.add("Muzzle", "Gun", (tur_x, gy, muz_z + 0.12), None)
    return rig


def export_all(out_dir, only=None):
    os.makedirs(out_dir, exist_ok=True)
    if only is None or only == "heavyAPC__namer":
        init_scene()
        export_vehicle(
            os.path.join(out_dir, "heavyAPC__namer.glb"),
            build_namer_rig(0),
            build_namer_rig(1),
            turret_offset=(3.8, 0.0, 0.2),
            ring_radius=0.30,
        )
    for slug in IFV_SPECS:
        if only and slug != only:
            continue
        init_scene()
        ring_r = 0.56 if slug in ("ifv__puma_ifv", "ifv__acv_15") else 0.78
        export_vehicle(
            os.path.join(out_dir, f"{slug}.glb"),
            build_west_ifv_rig(slug, 0),
            build_west_ifv_rig(slug, 1),
            turret_offset=(4.1, 0.0, -0.2),
            ring_radius=ring_r,
        )


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
    out_dir = os.path.join(repo_root, "native", "godot", "assets", "art", "vehicles")
    only = None
    for i, a in enumerate(argv):
        if a == "--only" and i + 1 < len(argv):
            only = argv[i + 1]
    export_all(out_dir, only=only)


if __name__ == "__main__":
    main()
