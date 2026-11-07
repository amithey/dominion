"""Soviet Legacy & DPRK Main Battle Tanks (5 variants), modelled in Blender.

Variants built (`--all`):
  - tank__t_64bv.glb             (Ukraine/USSR — 6 small all-steel road wheels + 4 return rollers, Kontakt-1 ERA array, 125 mm)
  - tank__t_55_t_62.glb          (T-55A — 5 starfish spoked wheels with 1-4 front gap, no rollers, egg dome turret, 100 mm forward evacuator)
  - tank__t_62_captured.glb      (Captured T-62 — 5 starfish wheels with rear gaps, wide saucer turret, 115 mm mid-evacuator, field stowage)
  - tank__t_62_t_72_captured.glb (Captured T-62 w/ improvised rear turret cage & fender stowage crates, 115 mm U-5TS, DShKM)
  - tank__chonma_216.glb         (DPRK Chonma-216 — 6 spoked wheels, cheek appliqué cast turret, twin ATGM + MANPADS tubes & met mast)

Run:
    blender -b -P native/tools/models/blender/build_soviet_legacy.py -- --all
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_vehicle import Part, VehicleRig, init_scene, export_vehicle
from build_t72_t90 import build_rear_fuel_drums_and_log, build_uvz_sprocket, build_uvz_idler, build_uvz_roller

OPTIC_GREEN = (0.55, 1.45, 0.75)
IR_LAMP = (0.35, 0.18, 0.22)


def add_tactical_mark_x(part, x_plane, cy, cz, sx_out, captured=False, size=0.14):
    """Tactical diamond or captured upturned V-chevron flush on side armor/fender."""
    out = (sx_out, 0.0, 0.0)
    if captured:
        # Crisp V-chevron for captured coalition service
        t = 0.042
        part.decal_quad("markings",
                        (x_plane, cy - size * 0.6, cz),
                        (x_plane, cy + size * 0.5, cz - size * 0.9),
                        (x_plane, cy + size * 0.5 + t, cz - size * 0.9 + t * 0.5),
                        (x_plane, cy - size * 0.6 + t * 1.2, cz),
                        outward=out)
        part.decal_quad("markings",
                        (x_plane, cy - size * 0.6, cz),
                        (x_plane, cy - size * 0.6 + t * 1.2, cz),
                        (x_plane, cy + size * 0.5 + t, cz + size * 0.9 - t * 0.5),
                        (x_plane, cy + size * 0.5, cz + size * 0.9),
                        outward=out)
    else:
        part.decal_quad("markings",
                        (x_plane, cy, cz - size),
                        (x_plane, cy - size * 0.85, cz),
                        (x_plane, cy, cz + size),
                        (x_plane, cy + size * 0.85, cz),
                        outward=out)


# ==============================================================================
# DISTINCTIVE RUNNING GEARS: T-64 Small All-Steel Wheels vs T-55/T-62 Starfish Wheels!
# ==============================================================================
def build_t64_steel_wheel(wp, lod, side, r=0.275):
    """Signature Kharkiv Morozov 555 mm SMALL stamped all-steel road wheel with internal rubber damper hub!"""
    p = Part(f"Wheel_{side}")
    s = side
    with p.frame(wp):
        if lod:
            p.lathe_x((0, 0, 0), [(-0.18, 0.0, "paint", 0.8), (-0.18, r, "metal", 0.9),
                                  (0.18, r, "paint", 0.86), (0.18, 0.0, "paint", 0.86)], seg=8)
            return p
        prof_r = [
            (-0.185, 0.0, "metal_dark", 0.45),
            (-0.185, r * 0.88, "paint", 0.78),
            (-0.175, r, "metal", 0.92),        # bare polished steel rim riding on track!
            (-0.038, r, "metal_dark", 0.40),
            (-0.032, r * 0.64, "metal_dark", 0.36),
            (0.032, r * 0.64, "metal", 0.88),
            (0.038, r, "metal", 0.95),
            (0.175, r, "paint", 0.90),
            (0.135, r * 0.62, "paint", 0.72),
            (0.155, r * 0.38, "rubber", 0.95),  # internal rubber shock ring around hub!
            (0.175, r * 0.28, "paint", 0.92),
            (0.175, 0.0, "paint", 0.92),
        ]
        if s < 0:
            prof = [(-prof_r[i][0], prof_r[i][1], prof_r[i - 1][2] if i > 0 else "paint", prof_r[i - 1][3] if i > 0 else 0.9)
                    for i in range(len(prof_r) - 1, -1, -1)]
            p.lathe_x((0, 0, 0), prof, seg=16)
        else:
            p.lathe_x((0, 0, 0), prof_r, seg=16)
        p.pipe("paint", (s * 0.16, 0, 0), (s * 0.22, 0, 0), 0.082, seg=10, r2=0.062, bevel=0.008)
    return p


def build_starfish_wheel(wp, lod, side, r=0.405):
    """Iconic Soviet T-54/55/62/Chonma large 810 mm 5-spoke 'Starfish' cast steel road wheel!"""
    p = Part(f"Wheel_{side}")
    s = side
    with p.frame(wp):
        if lod:
            p.lathe_x((0, 0, 0), [(-0.20, 0.0, "paint", 0.8), (-0.20, r, "rubber", 1.0),
                                  (0.20, r, "paint", 0.85), (0.20, 0.0, "paint", 0.85)], seg=8)
            return p
        prof_r = [
            (-0.20, 0.0, "metal_dark", 0.45),
            (-0.20, r * 0.78, "paint", 0.72),
            (-0.195, r * 0.84, "rubber", 0.94),
            (-0.195, r, "rubber", 1.0),
            (-0.04, r, "metal_dark", 0.38),
            (-0.035, r * 0.68, "metal_dark", 0.35),
            (0.035, r * 0.68, "rubber", 0.94),
            (0.04, r, "rubber", 1.0),
            (0.195, r, "paint", 0.90),
            (0.195, r * 0.82, "paint", 0.78),
            (0.115, r * 0.68, "dark", 0.55),    # deep recessed dish making the 5 starfish spokes pop!
            (0.145, r * 0.28, "paint", 0.88),
            (0.145, 0.0, "paint", 0.88),
        ]
        if s < 0:
            prof = [(-prof_r[i][0], prof_r[i][1], prof_r[i - 1][2] if i > 0 else "paint", prof_r[i - 1][3] if i > 0 else 0.9)
                    for i in range(len(prof_r) - 1, -1, -1)]
            p.lathe_x((0, 0, 0), prof, seg=18)
        else:
            p.lathe_x((0, 0, 0), prof_r, seg=18)

        # Prominent central hub dome + 5 cast 'Starfish' spokes with lightening dimples
        p.pipe("paint", (s * 0.13, 0, 0), (s * 0.225, 0, 0), 0.115, seg=12, r2=0.082, bevel=0.01)
        for k in range(5):
            a = math.tau * k / 5.0
            with p.frame((s * 0.165, 0, 0), pitch=a):
                p.box("paint", (-0.026, r * 0.24, -0.046), (0.026, r * 0.80, 0.046), bevel=0.008, tint=(0.98, 0.98, 0.96))
    return p


# ==============================================================================
# HULLS — T-64BV, T-55A, T-62 Captured, Chonma-216
# ==============================================================================
def build_legacy_hull(lod, variant, k):
    h = Part("Hull", seed=33)
    bev = 0.014 if lod else 0.022
    is_t64 = variant == "t_64bv"
    is_t55 = variant == "t_55_t_62"
    is_t62 = variant in ("t_62_captured", "t_62_t_72_captured")
    is_chonma = variant == "chonma_216"
    captured = "captured" in variant

    z_front = 3.16 if is_t55 else (3.32 if is_t64 else (3.36 if is_t62 else 3.55))
    z_rear = -3.14 if is_t55 else (-3.28 if is_t64 else (-3.34 if is_t62 else -3.55))
    y_deck = 1.24 if is_t64 else (1.30 if is_t55 else (1.33 if is_t62 else 1.35))

    hull_yz = [
        (0.40, z_front - 0.52),
        (0.84, z_front),
        (0.95, z_front - 0.04),
        (y_deck, z_front - 1.45),
        (y_deck, z_rear + 0.16),
        (1.04, z_rear),
        (0.50, z_rear + 0.16),
        (0.40, z_rear + 0.52),
    ]
    h.prism_x("paint", hull_yz, -1.06, 1.06, bevel=bev, seg=1, ao_y=(0.40, y_deck, 0.66))

    glacis_pitch = math.atan2(y_deck - 0.90, (z_front - 0.08) - (z_front - 1.45))

    # Driver hatch: left-offset on T-55/T-62/Chonma (`x = -0.46`), central on T-64BV (`x = 0.0`)!
    dx = 0.0 if is_t64 else -0.46
    h.box("paint", (dx - 0.28, y_deck - 0.02, z_front - 1.55), (dx + 0.28, y_deck + 0.09, z_front - 1.02), bevel=0.014)
    h.box("glass", (dx - 0.16, y_deck + 0.04, z_front - 1.05), (dx + 0.16, y_deck + 0.10, z_front - 0.98), tint=OPTIC_GREEN)

    # Splash board on glacis
    if not lod:
        with h.frame((0.0, 1.05, z_front - 0.72), pitch=glacis_pitch):
            h.box("paint", (-0.96, -0.01, -0.025), (0.96, 0.07, 0.025), bevel=0.005, tint=(0.92, 0.92, 0.90))

    # T-64BV Kontakt-1 ERA array on front glacis!
    if is_t64:
        rows = 2 if lod else 3
        cols = 3 if lod else 6
        for r_i in range(rows):
            zf_r = (z_front - 1.05) + r_i * 0.32
            y_r = y_deck - 0.05 - (zf_r - (z_front - 1.45)) * math.tan(glacis_pitch)
            for c_i in range(cols):
                bx = -0.86 + c_i * (1.72 / (cols - 1))
                if r_i == 0 and abs(bx) < 0.30:
                    continue
                with h.frame((bx, y_r, zf_r), pitch=glacis_pitch):
                    h.box("paint", (-0.125, 0.01, -0.14), (0.125, 0.09, 0.14), bevel=0.008, tint=(0.95, 0.98, 0.92), jitter=0.03)

    # Headlights on right/left bow (`FG-125` + `FG-100` IR driving lamp)
    for sx in (-1, 1):
        h.cyl("paint", (sx * 0.86, 1.02, z_front - 0.44), 0.085, 0.10, seg=10)
        if not lod:
            h.pipe("glass", (sx * 0.86, 1.07, z_front - 0.36), (sx * 0.86, 1.07, z_front - 0.33), 0.068, seg=10, tint=(1.6, 1.6, 1.3))
            h.tube_axis("metal_dark", (sx * 0.74, 0.76, z_front - 0.04), (sx * 0.74, 0.76, z_front + 0.08), 0.050, 0.024, seg=8)

    # Wheel wells, Sponsons, Fender Fuel Cells, and Skirts (or Exposed Tracks on T-55/T-62!)
    for sx in (-1, 1):
        h.box("dark", (sx * 1.06 - 0.03, 0.42, z_rear + 0.35), (sx * 1.06 + 0.03, y_deck - 0.06, z_front - 0.35))
        x_in, x_out = (1.04, 1.68) if sx > 0 else (-1.68, -1.04)
        h.box("paint", (x_in, y_deck - 0.08, z_rear + 0.06), (x_out, y_deck, z_front - 0.08), bevel=0.012, tint=(0.98, 0.98, 0.96))
        # Curved front & rear mudguards
        h.box("paint", (x_in, y_deck - 0.24, z_front - 0.12), (x_out, y_deck - 0.02, z_front + 0.04), pitch=0.45, bevel=0.010)
        h.box("rubber", (x_in + 0.02, 0.54, z_rear - 0.02), (x_out - 0.02, y_deck - 0.04, z_rear + 0.04), bevel=0.008)

        # Fender external diesel tanks (right side) & ZIP tool boxes (left side) — iconic T-55/T-62 asymmetry!
        if sx > 0:
            h.box("paint", (1.12, y_deck - 0.01, -1.85), (1.64, y_deck + 0.22, 0.95), bevel=0.018, tint=(0.95, 0.95, 0.93))
        else:
            h.box("paint", (-1.64, y_deck - 0.01, -1.55), (-1.14, y_deck + 0.22, -0.35), bevel=0.016, tint=(0.94, 0.94, 0.92))
            if variant == "t_62_t_72_captured":
                # Extra captured field ammunition/ration crate strapped on forward left fender
                h.box("wood", (-1.64, y_deck - 0.01, 0.15), (-1.16, y_deck + 0.28, 1.05), bevel=0.012, tint=(0.95, 0.90, 0.82))
            # Left rear exhaust manifold port
            if not is_t64:
                h.box("metal_dark", (-1.71, y_deck - 0.04, -2.35), (-1.58, y_deck + 0.10, -1.85), bevel=0.008)

        if is_t64:
            # Tall thin T-64BV side shields covered in Kontakt-1 ERA bricks!
            x0, x1 = (1.68, 1.74) if sx > 0 else (-1.74, -1.68)
            h.box("paint", (x0, 0.72, z_rear + 0.35), (x1, y_deck - 0.02, z_front - 0.35), bevel=0.008, tint=(0.94, 0.95, 0.92))
            n_b = 3 if lod else 7
            for bi in range(n_b):
                bz = (z_front - 0.70) - bi * (3.60 / max(1, n_b - 1))
                bx0, bx1 = (1.74, 1.81) if sx > 0 else (-1.81, -1.74)
                h.box("paint", (bx0, 0.84, bz - 0.21), (bx1, 1.22, bz + 0.21), bevel=0.008, tint=(0.96, 0.98, 0.93), jitter=0.03)
            add_tactical_mark_x(h, sx * 1.818, 1.03, 0.55, sx, captured=False, size=0.13)
        elif is_chonma:
            # 5 scalloped DPRK side skirts
            x0, x1 = (1.68, 1.74) if sx > 0 else (-1.74, -1.68)
            for idx in range(5):
                zf = 2.86 - idx * 1.16
                zr = zf - 1.11
                h.box("paint", (x0, 0.78, zr), (x1, y_deck - 0.02, zf), bevel=0.008, tint=(0.95, 0.96, 0.93))
            add_tactical_mark_x(h, sx * 1.748, 1.05, 0.28, sx, captured=False, size=0.13)
        else:
            # T-55 / T-62 have NO side skirts (exposed upper track run!) — put tactical mark on fender fuel/tool box!
            add_tactical_mark_x(h, sx * 1.648, y_deck + 0.11, -0.95, sx, captured=captured, size=0.095)

    # Engine deck louvers (T-64 has distinctive rear-edge exhaust grille!)
    h.box("dark", (-0.88, y_deck - 0.02, z_rear + 0.28), (0.88, y_deck + 0.015, z_rear + 1.55))
    if not lod:
        for i in range(9):
            gz = z_rear + 0.36 + i * 0.13
            h.box("metal_dark", (-0.84, y_deck - 0.005, gz - 0.02), (0.84, y_deck + 0.025, gz + 0.02))
        if is_t64:
            h.box("metal_dark", (-0.72, y_deck - 0.14, z_rear - 0.04), (0.72, y_deck + 0.02, z_rear + 0.12), bevel=0.01)

    build_rear_fuel_drums_and_log(h, lod, z_rear=z_rear, y_deck=y_deck, with_drums=True, with_log=True)
    return h


# ==============================================================================
# TURRETS & GUNS — T-64BV, T-55 Egg Dome, T-62 Flattened Saucer, Chonma-216
# ==============================================================================
def build_legacy_turret(lod, variant):
    t = Part("Turret", seed=61)
    is_t64 = variant == "t_64bv"
    is_t55 = variant == "t_55_t_62"
    is_t62 = variant in ("t_62_captured", "t_62_t_72_captured")
    is_chonma = variant == "chonma_216"
    captured = "captured" in variant

    y0 = 1.28 if is_t64 else (1.34 if is_t55 else (1.37 if is_t62 else 1.39))
    seg = 14 if lod else 28

    # Authentic dome proportions: T-62 has wider/flatter saucer (`r=1.44, z_shift=0.02`), T-55 taller egg dome (`r=1.30`)
    r_base = 1.32 if is_t64 else (1.30 if is_t55 else (1.44 if is_t62 else 1.36))
    h_tot = 0.72 if is_t64 else (0.78 if is_t55 else (0.74 if is_t62 else 0.80))
    tz = 0.05 if is_t64 else (0.10 if is_t55 else 0.02)

    t.cyl("paint", (0.0, y0, tz), r_base, h_tot * 0.36, seg=seg, r2=r_base * 0.96, bevel=0.04, tint=(0.98, 0.98, 0.96))
    t.cyl("paint", (0.0, y0 + h_tot * 0.32, tz), r_base * 0.96, h_tot * 0.40, seg=seg, r2=r_base * 0.80, bevel=0.05, tint=(1.0, 1.0, 0.98))
    t.cyl("paint", (0.0, y0 + h_tot * 0.68, tz), r_base * 0.80, h_tot * 0.32, seg=seg, r2=r_base * 0.60, bevel=0.06, tint=(1.02, 1.02, 1.0))

    # T-62 signature rear spent-casing automatic ejection port hatch!
    if is_t62:
        t.pipe("paint", (0.0, y0 + 0.46, tz - 1.14), (0.0, y0 + 0.52, tz - 1.24), 0.18, seg=10, bevel=0.012, tint=(0.94, 0.94, 0.92))

    # T-64BV Kontakt-1 ERA V-wedge array around cast turret!
    if is_t64:
        n_ang = 3 if lod else 6
        for sx in (-1, 1):
            for i in range(n_ang):
                ang = 0.25 + i * (1.20 / max(1, n_ang - 1))
                bx = sx * 1.34 * math.sin(ang)
                bz = tz + 1.34 * math.cos(ang)
                with t.frame((bx, y0 + 0.34, bz), yaw=-sx * ang):
                    t.box("paint", (-0.125, 0.00, -0.02), (0.125, 0.23, 0.13), pitch=0.44, bevel=0.008, tint=(0.96, 0.98, 0.93), jitter=0.03)
                    t.box("paint", (-0.125, -0.22, -0.02), (0.125, 0.00, 0.13), pitch=-0.42, bevel=0.008, tint=(0.94, 0.96, 0.91), jitter=0.03)

    # Chonma-216 Welded Cheek Appliqué + Twin Bulsae ATGM Tubes + Twin Igla MANPADS + Tall Met Mast!
    if is_chonma:
        for sx in (-1, 1):
            with t.frame((sx * 0.86, y0 + 0.38, 0.92), yaw=sx * 0.42):
                t.box("paint", (-0.34, -0.24, -0.18), (0.34, 0.24, 0.18), bevel=0.016, tint=(1.02, 1.02, 1.0))
        # Port-side twin Bulsae-3 ATGM launch canisters on elevated pylon
        t.box("metal_dark", (-0.98, y0 + 0.56, -0.58), (-0.84, y0 + 1.04, -0.38), bevel=0.008)
        for dx in (-1.04, -0.80):
            t.pipe("paint", (dx, y0 + 1.12, -0.98), (dx, y0 + 1.12, 0.26), 0.095, seg=8 if lod else 14, bevel=0.01, tint=(0.88, 0.92, 0.85))
            t.cyl("metal_dark", (dx, y0 + 1.12, 0.25), 0.098, 0.03, seg=8)
        # Starboard twin 9K38 Igla / Hwasung-Chong MANPADS tubes
        t.box("metal_dark", (0.84, y0 + 0.56, -0.58), (0.98, y0 + 1.02, -0.38), bevel=0.008)
        for dx in (0.82, 1.00):
            t.pipe("metal_dark", (dx, y0 + 1.08, -0.92), (dx, y0 + 1.08, 0.38), 0.058, seg=8 if lod else 12)
        # Tall central rear crosswind sensor mast
        t.pipe("metal_dark", (0.0, y0 + 0.72, -0.96), (0.0, y0 + 1.68, -0.96), 0.022, seg=6)
        t.box("metal_dark", (-0.11, y0 + 1.65, -1.02), (0.11, y0 + 1.72, -0.90), bevel=0.005)

    # Luna L-2 / L-4 Infrared Searchlight right of main gun (`x = +0.52`)
    lx, ly, lz = 0.52, y0 + 0.42, tz + 1.02
    t.pipe("paint", (lx, ly, lz - 0.22), (lx, ly, lz + 0.16), 0.19, seg=10 if lod else 14, bevel=0.014)
    t.pipe("glass", (lx, ly, lz + 0.15), (lx, ly, lz + 0.18), 0.165, seg=10 if lod else 14, tint=IR_LAMP)

    # Turret handrail grab bars (classic Soviet infantry tank-desant handrails!) & captured stowage
    if not lod and (is_t55 or is_t62):
        for sx in (-1, 1):
            t.pipe("metal_dark", (sx * 1.24, y0 + 0.42, -0.75), (sx * 1.16, y0 + 0.46, 0.28), 0.016, seg=6)

    if variant == "t_62_captured":
        t.box("paint", (-0.92, y0 + 0.30, -1.38), (-0.18, y0 + 0.62, -0.88), bevel=0.014, tint=(0.93, 0.92, 0.88))
        if not lod:
            t.pipe("canvas", (0.05, y0 + 0.46, -1.26), (0.85, y0 + 0.46, -1.26), 0.12, seg=10, bevel=0.02)
    elif variant == "t_62_t_72_captured":
        # Improvised welded rear turret field stowage basket + canvas rolls!
        if lod:
            t.box("metal_dark", (-0.95, y0 + 0.28, -1.78), (0.95, y0 + 0.68, -1.22))
        else:
            for ry in (y0 + 0.30, y0 + 0.66):
                t.pipe("metal_dark", (-0.96, ry, -1.78), (0.96, ry, -1.78), 0.016, seg=6)
                for sx in (-1, 1):
                    t.pipe("metal_dark", (sx * 0.96, ry, -1.78), (sx * 1.12, ry, -1.05), 0.016, seg=6)
            for bx in (-0.96, -0.32, 0.32, 0.96):
                t.pipe("metal_dark", (bx, y0 + 0.30, -1.78), (bx, y0 + 0.66, -1.78), 0.014, seg=6)
            t.pipe("canvas", (-0.72, y0 + 0.46, -1.52), (0.72, y0 + 0.46, -1.52), 0.13, seg=10, bevel=0.02)

    # Turret side identification carrier plates
    for sx in (-1, 1):
        px = sx * (r_base - 0.04)
        t.box("paint", (px - 0.03, y0 + 0.26, tz - 0.62), (px + 0.03, y0 + 0.50, tz - 0.18), bevel=0.006)
        add_tactical_mark_x(t, px + sx * 0.036, y0 + 0.38, tz - 0.40, sx, captured=captured, size=0.10)

    return t, y0 + h_tot, tz


def build_legacy_gun(lod, gp, variant):
    """Distinct gun silhouettes:
      - T-55A: 100 mm D-10T2S rifled gun with bore evacuator RIGHT NEAR THE MUZZLE!
      - T-62 / Chonma-216: 115 mm U-5TS smoothbore gun with MID-BARREL bore evacuator (+ KTD-2 laser box on Chonma)
      - T-64BV: 125 mm 2A46M-1 smoothbore gun with thermal sleeve & eccentric evacuator
    """
    g = Part("Gun", seed=77)
    gy, gz = gp[1], gp[2]
    seg = 10 if lod else 20

    g.box("canvas", (-0.30, gy - 0.20, gz - 0.10), (0.30, gy + 0.20, gz + 0.38), bevel=0.04, tint=(0.88, 0.87, 0.82))

    if variant == "chonma_216":
        # Boxy KTD-2 laser rangefinder mounted directly atop gun mantlet!
        g.box("paint", (-0.18, gy + 0.20, gz + 0.02), (0.18, gy + 0.40, gz + 0.54), bevel=0.014)
        g.box("glass", (-0.12, gy + 0.25, gz + 0.52), (0.12, gy + 0.35, gz + 0.56), tint=OPTIC_GREEN)

    if variant == "t_55_t_62":
        # 100 mm D-10T2S: slender tapered barrel with iconic forward-mounted bore evacuator near muzzle!
        z_tip = gz + 4.64
        g.pipe("paint", (0, gy, gz + 0.32), (0, gy, z_tip - 1.18), 0.095, seg=seg, r2=0.076, tint=(0.96, 0.96, 0.94))
        g.pipe("paint", (0, gy, z_tip - 1.20), (0, gy, z_tip - 0.58), 0.132, seg=seg, bevel=0.012, tint=(1.0, 1.0, 0.98))
        g.pipe("paint", (0, gy, z_tip - 0.60), (0, gy, z_tip - 0.12), 0.075, seg=seg, r2=0.072)
        g.tube_axis("metal_dark", (0, gy, z_tip - 0.14), (0, gy, z_tip), 0.074, 0.050, seg=seg)
        g.cyl("dark", (0, gy, z_tip - 0.15), 0.051, 0.02, seg=10)
    elif variant == "t_64bv":
        # 125 mm 2A46M-1 thermal-jacketed smoothbore
        z_tip = gz + 4.76
        g.pipe("paint", (0, gy, gz + 0.32), (0, gy, gz + 1.82), 0.106, seg=seg, r2=0.096)
        g.pipe("paint", (0, gy + 0.016, gz + 1.80), (0, gy + 0.016, gz + 2.40), 0.152, seg=seg, bevel=0.012)
        g.pipe("paint", (0, gy, gz + 2.38), (0, gy, z_tip - 0.14), 0.090, seg=seg, r2=0.082)
        g.tube_axis("metal_dark", (0, gy, z_tip - 0.16), (0, gy, z_tip), 0.088, 0.0625, seg=seg)
        g.cyl("dark", (0, gy, z_tip - 0.17), 0.063, 0.02, seg=10)
    else:
        # 115 mm U-5TS 'Molot' smoothbore (T-62 & Chonma-216): smooth barrel with mid-barrel symmetrical evacuator!
        z_tip = gz + 4.80
        g.pipe("paint", (0, gy, gz + 0.32), (0, gy, gz + 2.02), 0.102, seg=seg, r2=0.088)
        g.pipe("paint", (0, gy, gz + 2.00), (0, gy, gz + 2.56), 0.138, seg=seg, bevel=0.012, tint=(1.0, 1.0, 0.98))
        g.pipe("paint", (0, gy, gz + 2.54), (0, gy, z_tip - 0.14), 0.084, seg=seg, r2=0.078)
        g.tube_axis("metal_dark", (0, gy, z_tip - 0.16), (0, gy, z_tip), 0.082, 0.0575, seg=seg)
        g.cyl("dark", (0, gy, z_tip - 0.17), 0.058, 0.02, seg=10)

    return g, z_tip


# ==============================================================================
# RIG ASSEMBLY
# ==============================================================================
def build_legacy_rig(lod=0, variant="t_64bv"):
    rig = VehicleRig(lod=lod)
    is_t64 = variant == "t_64bv"
    is_t55 = variant == "t_55_t_62"
    is_t62 = variant in ("t_62_captured", "t_62_t_72_captured")
    is_chonma = variant == "chonma_216"

    k = 0.83 if is_t64 else (0.80 if is_t55 else (0.84 if is_t62 else 0.88))
    rig.add("Hull", rig.root_name, (0.0, 0.0, 0.0), build_legacy_hull(lod, variant, k))

    turret_part, y_roof, tz = build_legacy_turret(lod, variant)
    y_deck = y_roof - (0.76 if is_t64 else 0.82)
    ring = Part("Turret_Ring")
    ring.cyl("metal_dark", (0.0, y_deck, tz), 1.02, 0.08, seg=14 if lod else 24)
    rig.add("Turret_Ring", "Hull", (0.0, y_deck + 0.04, tz), ring)
    rig.add("Turret", "Hull", (0.0, y_deck + 0.06, tz), turret_part)

    gp = (0.0, 1.68 if is_t64 else (1.78 if is_t55 else (1.82 if is_t62 else 1.86)), tz + 1.04)
    gun_part, z_tip = build_legacy_gun(lod, gp, variant)
    rig.add("Gun", "Turret", gp, gun_part)
    rig.add("Muzzle", "Gun", (0.0, gp[1], z_tip), None)

    # Hatches (on T-55/T-62 commander is on LEFT, loader w/ DShKM on RIGHT; on T-64 commander is on RIGHT!)
    cmd_x = 0.50 if is_t64 else -0.48
    ldr_x = -0.50 if is_t64 else 0.48
    for hname, hx, hz in (("Hatch_Commander", cmd_x, tz - 0.24), ("Hatch_Loader", ldr_x, tz - 0.30)):
        hp = Part(hname)
        hp.cyl("paint", (hx, y_roof - 0.05, hz), 0.28, 0.11, seg=10 if lod else 16, bevel=0.012)
        rig.add(hname, "Turret", (hx, y_roof, hz - 0.26), hp)

    # Gunner primary sight housing
    gs = Part("Gunner_Sight")
    gs.box("paint", (-0.68, y_roof - 0.06, tz + 0.22), (-0.36, y_roof + 0.16, tz + 0.58), bevel=0.014)
    gs.box("glass", (-0.62, y_roof + 0.02, tz + 0.56), (-0.42, y_roof + 0.12, tz + 0.60), tint=OPTIC_GREEN)
    rig.add("Gunner_Sight", "Turret", (-0.52, y_roof - 0.02, tz + 0.40), gs)

    # Heavy 12.7 mm AA Machine Gun (DShKM with fluted barrel & muzzle brake on T-55/T-62/Chonma; closed NSVT on T-64BV)
    mg = Part("Commander_MG")
    mx, mz = (0.50, tz - 0.36) if is_t64 else (0.48, tz - 0.42)
    mg.cyl("metal_dark", (mx, y_roof + 0.02, mz), 0.075, 0.20, seg=8)
    mg.box("metal_dark", (mx - 0.08, y_roof + 0.20, mz - 0.18), (mx + 0.08, y_roof + 0.34, mz + 0.20), bevel=0.008)
    mg.box("metal_dark", (mx + 0.07, y_roof + 0.16, mz - 0.11), (mx + 0.22, y_roof + 0.33, mz + 0.11), bevel=0.008)
    mg.pipe("metal_dark", (mx, y_roof + 0.28, mz + 0.18), (mx, y_roof + 0.28, mz + 0.94), 0.022, seg=8)
    if not is_t64 and not lod:
        mg.box("metal_dark", (mx - 0.035, y_roof + 0.25, mz + 0.92), (mx + 0.035, y_roof + 0.31, mz + 1.00), bevel=0.004)
    rig.add("Commander_MG", "Turret", (mx, y_roof + 0.02, mz), mg)

    # Tucha Smoke Grenade Launchers on T-64BV & Chonma-216
    if is_t64 or is_chonma:
        for label, side in (("L", -1), ("R", 1)):
            sm = Part(f"Smoke_Launcher_{label}")
            sx_p, sy_p, sz_p = side * 1.18, y_roof - 0.28, tz + 0.15
            sm.box("paint", (sx_p - 0.06, sy_p - 0.07, sz_p - 0.16), (sx_p + 0.06, sy_p + 0.07, sz_p + 0.16), bevel=0.008)
            if not lod:
                for j in range(4):
                    sm.pipe("metal_dark", (sx_p, sy_p + 0.02, sz_p - 0.10 + j * 0.07),
                            (sx_p + side * 0.08, sy_p + 0.09, sz_p + 0.04 + j * 0.07), 0.032, seg=6)
            rig.add(f"Smoke_Launcher_{label}", "Turret", (sx_p, sy_p, sz_p), sm)

    # Whip Radio Antenna
    ant = Part("Antenna_1")
    ax, ay, az = -0.84, y_roof - 0.14, tz - 0.78
    ant.cyl("metal_dark", (ax, ay, az), 0.036, 0.10, seg=8)
    ant.pipe("metal_dark", (ax, ay + 0.10, az), (ax - 0.02, ay + 1.34, az - 0.05), 0.010, seg=6, r2=0.004)
    rig.add("Antenna_1", "Turret", (ax, ay, az), ant)

    # Running Gear (Authentic wheel counts, diameters, gaps, and return roller counts!)
    if is_t64:
        wheel_zs = [-2.42, -1.45, -0.48, 0.48, 1.45, 2.42]
        rollers = [-2.05, -0.68, 0.68, 2.05]   # 4 return rollers per side!
    elif is_t55:
        wheel_zs = [-2.42, -1.36, -0.32, 0.72, 2.28]  # Iconic gap before front wheel #1!
        rollers = []                                  # Christie-derived torsion suspension, 0 return rollers!
    elif is_t62:
        wheel_zs = [-2.44, -1.12, 0.04, 1.06, 2.08]   # Iconic gaps between rear wheels on T-62!
        rollers = []
    else:
        wheel_zs = [-2.42, -1.45, -0.48, 0.48, 1.45, 2.42]
        rollers = [-1.75, 0.0, 1.75]

    for label, side in (("L", -1), ("R", 1)):
        wx = side * 1.36
        w_r = 0.275 if is_t64 else (0.405 if (is_t55 or is_t62) else 0.365)
        w_y = w_r + 0.065
        for i, wz in enumerate(wheel_zs):
            wp = (wx, w_y, wz * k)
            w_part = build_t64_steel_wheel(wp, lod, side, r=w_r) if is_t64 else build_starfish_wheel(wp, lod, side, r=w_r)
            rig.add(f"Wheel_{label}{i}", "Hull", wp, w_part)

        sp_piv = (wx, 0.65 * k, -3.23 * k)
        rig.add(f"Sprocket_{label}", "Hull", sp_piv, build_uvz_sprocket(sp_piv, lod, side, scale=k))
        id_piv = (wx, 0.65 * k, 3.23 * k)
        rig.add(f"Idler_{label}", "Hull", id_piv, build_uvz_idler(id_piv, lod, side, scale=k))
        for i, rz in enumerate(rollers):
            rp = (wx, 1.00 * k, rz * k)
            rig.add(f"Roller_{label}{i}", "Hull", rp, build_uvz_roller(rp, lod, side, scale=k))

        trk = Part(f"Track_{label}")
        trk.build_track(wx, lod=lod, width=0.54 if is_t64 else 0.58)
        rig.add(f"Track_{label}", "Hull", (wx, 0.0, 0.0), trk, mesh_scale=(1.0, k, k))

    rig.add("Exhaust", "Hull", (0.0 if is_t64 else -1.66, 1.15, -3.15 if is_t64 else -2.10), None)
    rig.add("Engine_Deck", "Hull", (0.0, y_deck, -2.35), None)
    return rig


LEGACY_VARIANTS = (
    "t_64bv",
    "t_55_t_62",
    "t_62_captured",
    "t_62_t_72_captured",
    "chonma_216",
)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    veh_dir = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../godot/assets/art/vehicles"))
    os.makedirs(veh_dir, exist_ok=True)
    targets = LEGACY_VARIANTS if ("--all" in argv or not argv) else [v for v in argv if not v.startswith("-")]
    for var in targets:
        init_scene()
        out_p = os.path.join(veh_dir, f"tank__{var}.glb")
        export_vehicle(out_p, build_legacy_rig(0, var), build_legacy_rig(1, var))
