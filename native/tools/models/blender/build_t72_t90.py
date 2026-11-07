"""Soviet / Russian / Iranian / Ukrainian / Sudanese T-72 & T-90 Family MBTs (6 variants), modelled in Blender.

Variants built (`--all`):
  - tank__t_90m_proryv.glb    (Russia — Welded Proryv-3 turret, Relikt ERA wedges & side bags, bustle + rear slats, Kord RWS, 2A46M-5)
  - tank__karrar.glb          (Iran — Welded angular carousel turret, shrouded 125 mm barrel jacket, rear slat cages, RWS)
  - tank__t_72ua1_t_72b.glb   (Ukraine/Russia — Cast turret + Kontakt-1/Nozh ERA, raised 5TDFMA rear engine deck & side exhaust)
  - tank__t_72av.glb          (Syria/Export — Cast T-72A turret & glacis covered in V-angled Kontakt-1 ERA bricks, Luna IR)
  - tank__t_72.glb            (Export T-72M1 — Clean cast dome turret, V-splash board, Luna IR searchlight, rear fuel drums + log)
  - tank__t_72_al_bashir.glb  (Sudan / Type 85-IIM — Welded slab-and-wedge composite turret, bustle & side stowage racks, 125 mm)

Run:
    blender -b -P native/tools/models/blender/build_t72_t90.py -- --all
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_vehicle import Part, VehicleRig, init_scene, export_vehicle

UVZ_WHEEL_ZS = [-2.44, -1.46, -0.49, 0.49, 1.46, 2.44]
OPTIC_GREEN = (0.55, 1.45, 0.75)
OPTIC_FLIR = (2.1, 1.25, 0.50)
IR_LAMP = (0.35, 0.18, 0.22)


def add_star_or_diamond_decal_x(part, x_plane, cy, cz, sx_out, size=0.14):
    """Tactical diamond / guard emblem in `markings` role flush on side skirts or turret plates."""
    out = (sx_out, 0.0, 0.0)
    part.decal_quad("markings",
                    (x_plane, cy, cz - size),
                    (x_plane, cy - size * 0.85, cz),
                    (x_plane, cy, cz + size),
                    (x_plane, cy + size * 0.85, cz),
                    outward=out)


# ==============================================================================
# RUNNING GEAR — UVZ Stamped-Star 6-Spoke Road Wheels, Sprocket, Idler, Rollers
# ==============================================================================
def build_uvz_wheel(wp, lod, side, r=0.365):
    """Iconic Uralvagonzavod 750 mm stamped-dish road wheel with 6 radial ribs & central hub dome."""
    p = Part(f"Wheel_{side}")
    s = side
    with p.frame(wp):
        if lod:
            p.lathe_x((0, 0, 0), [(-0.21, 0.0, "paint", 0.8), (-0.21, r, "rubber", 1.0),
                                  (0.21, r, "paint", 0.85), (0.21, 0.0, "paint", 0.85)], seg=8)
            return p
        prof_r = [
            (-0.22, 0.0, "metal_dark", 0.45),
            (-0.22, r * 0.76, "paint", 0.74),
            (-0.21, r * 0.82, "rubber", 0.94),
            (-0.21, r, "rubber", 1.0),
            (-0.042, r, "metal_dark", 0.38),
            (-0.036, r * 0.70, "metal_dark", 0.35),
            (0.036, r * 0.70, "rubber", 0.94),
            (0.042, r, "rubber", 1.0),
            (0.21, r, "paint", 0.92),
            (0.21, r * 0.82, "paint", 0.84),
            (0.15, r * 0.66, "paint", 0.68),
            (0.175, r * 0.30, "paint", 0.90),
            (0.175, 0.0, "paint", 0.90),
        ]
        if s < 0:
            prof = [(-prof_r[i][0], prof_r[i][1], prof_r[i - 1][2] if i > 0 else "paint", prof_r[i - 1][3] if i > 0 else 0.9)
                    for i in range(len(prof_r) - 1, -1, -1)]
            p.lathe_x((0, 0, 0), prof, seg=18)
        else:
            p.lathe_x((0, 0, 0), prof_r, seg=18)

        # Central oil cap + 6 stamped stiffening ribs
        p.pipe("paint", (s * 0.16, 0, 0), (s * 0.235, 0, 0), 0.105, seg=12, r2=0.078, bevel=0.01)
        for k in range(6):
            a = math.tau * k / 6.0
            with p.frame((s * 0.175, 0, 0), pitch=a):
                p.box("paint", (-0.018, r * 0.28, -0.028), (0.018, r * 0.75, 0.028), bevel=0.005, tint=(0.95, 0.95, 0.93))
    return p


def build_uvz_sprocket(wp, lod, side, scale=0.87):
    p = Part(f"Sprocket_{side}")
    s = side
    n_seg = 10 if lod else 18
    r = 0.42 * scale
    with p.frame(wp):
        p.lathe_x((0, 0, 0), [
            (-0.20, 0.0, "metal_dark", 0.55), (-0.20, r, "paint", 0.80),
            (-0.14, r, "metal_dark", 0.42), (-0.12, r * 0.76, "metal_dark", 0.40),
            (0.12, r * 0.76, "paint", 0.84), (0.14, r, "paint", 0.90),
            (0.20, r, "paint", 0.88), (0.20, 0.0, "paint", 0.88),
        ], seg=n_seg)
        p.pipe("paint", (s * 0.11, 0, 0), (s * 0.24, 0, 0), 0.17 * scale, seg=n_seg, r2=0.13 * scale, bevel=0.01)
        if not lod:
            for tx in (-0.17, 0.17):
                for k in range(12):
                    a = math.tau * k / 12.0
                    with p.frame((tx, 0, 0), pitch=a):
                        p.box("metal", (-0.018, r - 0.018, -0.036), (0.018, r + 0.065 * scale, 0.036), bevel=0.005)
    return p


def build_uvz_idler(wp, lod, side, scale=0.87):
    p = Part(f"Idler_{side}")
    s = side
    r = 0.39 * scale
    n_seg = 8 if lod else 16
    with p.frame(wp):
        p.lathe_x((0, 0, 0), [
            (-0.18, 0.0, "metal_dark", 0.5), (-0.18, r, "metal", 0.9),
            (-0.04, r, "metal_dark", 0.42), (0.04, r, "metal", 0.92),
            (0.18, r, "paint", 0.88), (0.15, r * 0.68, "paint", 0.74),
            (0.16, 0.0, "paint", 0.9),
        ], seg=n_seg)
        p.pipe("paint", (s * 0.14, 0, 0), (s * 0.21, 0, 0), 0.10 * scale, seg=10, r2=0.075 * scale)
    return p


def build_uvz_roller(wp, lod, side, scale=0.87):
    if lod:
        return None
    p = Part(f"Roller_{side}")
    with p.frame(wp):
        for dx in (-0.09, 0.09):
            p.pipe("rubber", (dx - 0.035, 0, 0), (dx + 0.035, 0, 0), 0.11 * scale, seg=10)
        p.pipe("metal_dark", (-0.15, 0, 0), (0.15, 0, 0), 0.032, seg=8)
    return p


# ==============================================================================
# HULL — Low Soviet 68-deg Sloped Glacis, Fuel Drums, Unditching Log, ERA/Slats
# ==============================================================================
def build_rear_fuel_drums_and_log(h, lod, z_rear=-3.46, y_deck=1.28, with_drums=True, with_log=True):
    """Signature Soviet twin 200L jettisonable rear fuel drums + wooden self-recovery unditching beam."""
    if with_drums:
        zd = z_rear - 0.24
        yd = y_deck - 0.18
        seg = 8 if lod else 16
        for sx in (-1, 1):
            cx = sx * 0.68
            h.pipe("paint", (cx - 0.46, yd, zd), (cx + 0.46, yd, zd), 0.255, seg=seg, bevel=0.018, tint=(0.95, 0.95, 0.92))
            # Steel drum stiffening ribs & mounting straps
            if not lod:
                for dx in (-0.28, 0.0, 0.28):
                    h.pipe("metal_dark", (cx + dx - 0.02, yd, zd), (cx + dx + 0.02, yd, zd), 0.266, seg=seg)
                for bx in (-0.30, 0.30):
                    h.box("metal_dark", (cx + bx - 0.025, yd - 0.12, z_rear - 0.04), (cx + bx + 0.025, yd + 0.22, zd + 0.20), bevel=0.005)
    if with_log:
        zl = z_rear - (0.08 if with_drums else 0.14)
        yl = 0.64 if with_drums else 0.86
        h.pipe("wood", (-1.28, yl, zl), (1.28, yl, zl), 0.095, seg=8 if lod else 12, bevel=0.01)
        if not lod:
            for bx in (-0.92, 0.92):
                h.pipe("metal_dark", (bx - 0.025, yl, zl), (bx + 0.025, yl, zl), 0.106, seg=10)


def build_t72_hull(lod, variant, k):
    h = Part("Hull", seed=41)
    bev = 0.014 if lod else 0.024
    is_t90m = variant == "t_90m_proryv"
    is_karrar = variant == "karrar"
    is_ua1 = variant == "t_72ua1_t_72b"
    is_av = variant == "t_72av"
    is_bashir = variant == "t_72_al_bashir"

    z_front = 3.56 if is_bashir else 3.44
    z_rear = -3.62 if is_bashir else -3.48
    y_deck = 1.31 if is_bashir else 1.27

    # 1. Low-profile Soviet hull tub (`x = -1.10 .. +1.10`) with sharp 68-degree front glacis
    hull_yz = [
        (0.40, z_front - 0.56),
        (0.84, z_front),
        (0.96, z_front - 0.05),
        (y_deck, 1.72),
        (y_deck, z_rear + 0.18),
        (1.06, z_rear),
        (0.50, z_rear + 0.16),
        (0.40, z_rear + 0.55),
    ]
    h.prism_x("paint", hull_yz, -1.10, 1.10, bevel=bev, seg=1, ao_y=(0.40, 1.24, 0.66))

    # Glacis slope pitch (tilts +Z downward onto glacis)
    glacis_pitch = math.atan2(y_deck - 0.88, (z_front - 0.08) - 1.72)

    # Central driver hatch & TNPO-168V periscope block (signature central Soviet driver position!)
    h.box("paint", (-0.30, y_deck - 0.02, 1.56), (0.30, y_deck + 0.09, 2.08), bevel=0.015)
    h.box("glass", (-0.16, y_deck + 0.04, 2.05), (0.16, y_deck + 0.10, 2.12), tint=OPTIC_GREEN)
    # Driver's V-shaped glacis splash board (`volnootrazhatel`) on non-Relikt hulls
    if not is_t90m and not is_karrar and not lod:
        for sx in (-1, 1):
            with h.frame((sx * 0.52, 1.08, 2.66), yaw=-sx * 0.42, pitch=glacis_pitch):
                h.box("paint", (-0.54, -0.02, -0.03), (0.54, 0.08, 0.03), bevel=0.005, tint=(0.92, 0.92, 0.90))

    # Glacis ERA Layouts per variant!
    if is_t90m or is_karrar:
        # Smooth heavy Relikt / Karrar modular ERA glacis panels with central driver V-cutout
        for sx in (-1, 1):
            with h.frame((sx * 0.62, 1.07, 2.58), pitch=glacis_pitch):
                h.box("paint", (-0.44, 0.0, -0.68), (0.44, 0.095, 0.68), bevel=0.014, tint=(1.03, 1.03, 1.01))
                if not lod:
                    for rz in (-0.22, 0.22):
                        h.box("metal_dark", (-0.43, 0.092, rz - 0.012), (0.43, 0.104, rz + 0.012))
        with h.frame((0.0, 0.95, 3.05), pitch=glacis_pitch):
            h.box("paint", (-0.22, 0.0, -0.28), (0.22, 0.09, 0.28), bevel=0.012, tint=(1.02, 1.02, 1.0))
    elif is_av or is_ua1:
        # Classic Kontakt-1 rectangular ERA bricks laid across front glacis!
        rows = 2 if lod else 3
        cols = 3 if lod else 6
        for r_i in range(rows):
            zf_row = 2.26 + r_i * 0.36
            y_row = y_deck - 0.06 - (zf_row - 1.72) * math.tan(glacis_pitch)
            for c_i in range(cols):
                bx = -0.90 + c_i * (1.80 / (cols - 1))
                if r_i == 0 and abs(bx) < 0.32:
                    continue  # clear of driver's vision path!
                with h.frame((bx, y_row, zf_row), pitch=glacis_pitch):
                    h.box("paint", (-0.13, 0.01, -0.15), (0.13, 0.095, 0.15), bevel=0.008, tint=(0.95, 0.97, 0.92), jitter=0.03)

    # Lower bow dozer/entrenching blade (`סכין התחפרות מובנית` — classic Soviet MBT chin feature!)
    if not lod:
        with h.frame((0.0, 0.58, z_front - 0.26), pitch=-0.42):
            h.box("metal_dark", (-0.98, -0.02, -0.18), (0.98, 0.03, 0.18), bevel=0.006)
        for sx in (-1, 1):
            h.tube_axis("metal_dark", (sx * 0.78, 0.78, z_front - 0.04), (sx * 0.78, 0.78, z_front + 0.08), 0.052, 0.025, seg=8)

    # Headlights & guards on bow
    for sx in (-1, 1):
        h.cyl("paint", (sx * 0.94, 1.04, z_front - 0.42), 0.085, 0.10, seg=10)
        if not lod:
            h.pipe("glass", (sx * 0.94, 1.09, z_front - 0.34), (sx * 0.94, 1.09, z_front - 0.31), 0.068, seg=10, tint=(1.6, 1.6, 1.4))

    # 2. Inner dark wheel wells & torsion arms
    for sx in (-1, 1):
        h.box("dark", (sx * 1.10 - 0.03, 0.42, z_rear + 0.35), (sx * 1.10 + 0.03, 1.22, z_front - 0.35))
        if not lod:
            for wz in UVZ_WHEEL_ZS:
                h.pipe("metal_dark", (sx * 1.09, 0.52, (wz + 0.22) * k), (sx * 1.38, 0.44, wz * k), 0.046, seg=8)

    # 3. Track Sponsons, Fender Fuel Cells, Side Skirts / ERA / Slat Cages!
    # Track outer end-connectors reach `1.42 + 0.58 * 0.515 = 1.719`, so skirts start at `>= 1.74`!
    for sx in (-1, 1):
        x_in, x_out = (1.08, 1.74) if sx > 0 else (-1.74, -1.08)
        sponson_yz = [(y_deck - 0.08, z_rear + 0.05), (y_deck, z_rear + 0.10), (y_deck, z_front - 0.50),
                      (0.96, z_front + 0.02), (0.86, z_front - 0.02), (y_deck - 0.12, z_front - 0.58)]
        h.prism_x("paint", sponson_yz, x_in, x_out, bevel=0.014, seg=1, tint=(0.98, 0.98, 0.96))
        h.box("rubber", (min(x_in, x_out) + 0.02, 0.48, z_rear - 0.04), (max(x_in, x_out) - 0.02, 1.18, z_rear + 0.03), bevel=0.008)

        # Classic angled fender stowage / diesel cells along upper sponsons
        if not is_t90m and not lod:
            h.box("paint", (sx * 1.40 - 0.24, y_deck - 0.01, -1.85), (sx * 1.40 + 0.24, y_deck + 0.19, 0.95), bevel=0.016, tint=(0.95, 0.95, 0.93))

        # Left-side exhaust port (classic V-84 / V-92S2F flat port exhaust on T-72/T-90, or armored box on UA1!)
        if sx < 0:
            if is_ua1:
                h.box("metal_dark", (-1.82, 1.02, -2.78), (-1.62, 1.34, -1.96), bevel=0.014)
            else:
                h.box("metal_dark", (-1.78, 1.12, -2.35), (-1.66, 1.26, -1.82), bevel=0.010)

        # Side Skirts per variant
        if is_t90m:
            # Heavy Relikt side armor plates + bloated Relikt soft-case ERA bags + rear slat cage!
            for idx in range(5):
                zf = 2.96 - idx * 0.92
                zr = zf - 0.88
                x0, x1 = (1.74, 1.88) if sx > 0 else (-1.88, -1.74)
                h.box("paint", (x0, 0.64, zr), (x1, 1.28, zf), bevel=0.020, tint=(0.96, 0.97, 0.93), jitter=0.02)
                if not lod:
                    # Soft bag strap bands
                    for sz in (zr + 0.24, zf - 0.24):
                        h.box("metal_dark", (sx * 1.882 - 0.008, 0.65, sz - 0.02), (sx * 1.882 + 0.008, 1.27, sz + 0.02))
            # Rear engine-compartment bar-slat cage (`z = -3.45 .. -1.65`)
            if not lod:
                for sy in (0.68, 0.82, 0.96, 1.10, 1.24):
                    h.box("metal_dark", (sx * 1.85 - 0.012, sy - 0.01, -3.44), (sx * 1.85 + 0.012, sy + 0.01, -1.66))
                for sz in (-3.40, -2.82, -2.24, -1.68):
                    h.box("metal_dark", (sx * 1.84 - 0.015, 0.66, sz - 0.015), (sx * 1.84 + 0.015, 1.26, sz + 0.015))
            else:
                h.box("metal_dark", (sx * 1.84 - 0.02, 0.68, -3.42), (sx * 1.84 + 0.02, 1.25, -1.68))
            add_star_or_diamond_decal_x(h, sx * 1.888, 0.96, 0.64, sx, size=0.14)

        elif is_karrar:
            # Front heavy ERA side panels + long Iranian rear slat cages
            for idx in range(4):
                zf = 2.94 - idx * 1.06
                zr = zf - 1.01
                x0, x1 = (1.74, 1.86) if sx > 0 else (-1.86, -1.74)
                h.box("paint", (x0, 0.68, zr), (x1, 1.28, zf), bevel=0.016, tint=(1.01, 1.01, 0.99))
            if not lod:
                for sy in (0.72, 0.86, 1.00, 1.14, 1.26):
                    h.box("metal_dark", (sx * 1.85 - 0.012, sy - 0.01, -3.42), (sx * 1.85 + 0.012, sy + 0.01, -1.32))
                for sz in (-3.38, -2.70, -2.02, -1.35):
                    h.box("metal_dark", (sx * 1.84 - 0.015, 0.70, sz - 0.015), (sx * 1.84 + 0.015, 1.28, sz + 0.015))
            add_star_or_diamond_decal_x(h, sx * 1.868, 0.98, 0.82, sx, size=0.14)

        else:
            # Rubber-fabric side skirts (`t_72`, `t_72av`, `t_72ua1_t_72b`, `t_72_al_bashir`)
            x0, x1 = (1.74, 1.79) if sx > 0 else (-1.79, -1.74)
            for idx in range(5):
                zf = 2.92 - idx * 1.22
                zr = zf - 1.18
                h.box("paint", (x0, 0.74, zr), (x1, 1.26, zf), bevel=0.008, tint=(0.94, 0.94, 0.92))
            if is_av or is_ua1:
                # Kontakt-1 bricks mounted along forward 3 skirt sections!
                n_b = 3 if lod else 7
                for bi in range(n_b):
                    bz = 2.65 - bi * (3.10 / max(1, n_b - 1))
                    bx0, bx1 = (1.79, 1.86) if sx > 0 else (-1.86, -1.79)
                    h.box("paint", (bx0, 0.86, bz - 0.19), (bx1, 1.24, bz + 0.19), bevel=0.008, tint=(0.97, 0.99, 0.94), jitter=0.03)
                add_star_or_diamond_decal_x(h, sx * 1.868, 1.05, 0.75, sx, size=0.13)
            else:
                add_star_or_diamond_decal_x(h, sx * 1.798, 1.00, 0.18, sx, size=0.14)

    # 4. Rear Engine Deck Louvers & Variant Powerpack Bulge (`t_72ua1_t_72b` raised 5TDFMA deck!)
    if is_ua1:
        h.box("paint", (-0.98, y_deck - 0.02, -3.28), (0.98, y_deck + 0.15, -1.72), bevel=0.020, tint=(0.96, 0.97, 0.94))
        h.box("dark", (-0.78, y_deck + 0.12, -3.12), (0.78, y_deck + 0.16, -2.05))
        if not lod:
            for i in range(9):
                gz = -3.06 + i * 0.12
                h.box("metal_dark", (-0.76, y_deck + 0.14, gz - 0.02), (0.76, y_deck + 0.17, gz + 0.02))
    else:
        h.box("dark", (-0.92, y_deck - 0.02, -3.26), (0.92, y_deck + 0.015, -1.86))
        if not lod:
            for i in range(10):
                gz = -3.18 + i * 0.13
                h.box("metal_dark", (-0.88, y_deck - 0.005, gz - 0.02), (0.88, y_deck + 0.025, gz + 0.02))

    # Rear slat grill on T-90M vs Rear Fuel Drums + Log on T-72/Karrar/Al-Bashir
    if is_t90m:
        if not lod:
            for sy in (0.64, 0.78, 0.92, 1.06, 1.20):
                h.box("metal_dark", (-1.65, sy - 0.01, z_rear - 0.12), (1.65, sy + 0.01, z_rear - 0.09))
        build_rear_fuel_drums_and_log(h, lod, z_rear=z_rear, y_deck=y_deck, with_drums=False, with_log=True)
    else:
        build_rear_fuel_drums_and_log(h, lod, z_rear=z_rear, y_deck=y_deck, with_drums=True, with_log=True)

    return h


# ==============================================================================
# TURRETS — Cast T-72 Dome (Clean / Kontakt-1) vs Welded T-90M / Karrar / Type 85
# ==============================================================================
def build_cast_t72_turret(lod, variant):
    """Authentic compound-curved Soviet cast T-72 turret ('Ural'/'Dolly Parton') with optional Kontakt-1 ERA."""
    t = Part("Turret", seed=53)
    has_era = variant in ("t_72av", "t_72ua1_t_72b")
    y0 = 1.32
    seg = 14 if lod else 28

    # Multi-tier lathed/frustum cast dome shifted slightly forward on cheeks (`Dolly Parton` bulge)
    t.cyl("paint", (0.0, y0, 0.08), 1.36, 0.28, seg=seg, r2=1.32, bevel=0.04, tint=(0.98, 0.98, 0.96))
    t.cyl("paint", (0.0, y0 + 0.24, 0.06), 1.32, 0.34, seg=seg, r2=1.12, bevel=0.05, tint=(1.0, 1.0, 0.98))
    t.cyl("paint", (0.0, y0 + 0.54, 0.03), 1.12, 0.24, seg=seg, r2=0.86, bevel=0.06, tint=(1.02, 1.02, 1.0))

    #Thickened cast frontal cheek bulges ("Super Dolly Parton" on T-72B / T-72M1)
    for sx in (-1, 1):
        with t.frame((sx * 0.68, y0 + 0.34, 0.84), yaw=sx * 0.42):
            t.box("paint", (-0.42, -0.24, -0.32), (0.42, 0.26, 0.32), bevel=0.09, seg=2, tint=(1.01, 1.01, 0.99))

    if has_era:
        # Iconic V-chevron angled Kontakt-1 ERA wedge array wrapped around cast turret front & cheeks!
        n_ang = 3 if lod else 6
        for sx in (-1, 1):
            for i in range(n_ang):
                ang = 0.26 + i * (1.18 / max(1, n_ang - 1))
                rad = 1.38
                bx = sx * rad * math.sin(ang)
                bz = 0.08 + rad * math.cos(ang)
                with t.frame((bx, y0 + 0.38, bz), yaw=-sx * ang):
                    # Upper + lower angled V-brick pair (`уголок` wedge!)
                    t.box("paint", (-0.13, 0.00, -0.02), (0.13, 0.25, 0.14), pitch=0.45, bevel=0.008, tint=(0.96, 0.98, 0.93), jitter=0.03)
                    t.box("paint", (-0.13, -0.24, -0.02), (0.13, 0.00, 0.14), pitch=-0.42, bevel=0.008, tint=(0.94, 0.96, 0.91), jitter=0.03)
            # Roof-edge flat Kontakt-1 tiles!
            if not lod:
                for rz in (0.35, 0.72):
                    t.box("paint", (sx * 0.56 - 0.16, y0 + 0.74, rz - 0.14), (sx * 0.56 + 0.16, y0 + 0.81, rz + 0.14),
                          pitch=0.14, bevel=0.006, tint=(0.97, 0.98, 0.94))

    # Luna L-4A Infrared Searchlight right of main gun (`x = +0.54, z = +1.12`)
    lx, ly, lz = 0.56, y0 + 0.44, 1.08
    t.pipe("paint", (lx, ly, lz - 0.24), (lx, ly, lz + 0.16), 0.20, seg=10 if lod else 16, bevel=0.015)
    t.pipe("glass", (lx, ly, lz + 0.15), (lx, ly, lz + 0.18), 0.175, seg=10 if lod else 16, tint=IR_LAMP)
    t.box("metal_dark", (lx - 0.08, ly - 0.24, lz - 0.18), (lx + 0.08, ly - 0.14, lz + 0.06))

    # Rear turret snorkel tube & stowage boxes (and UA1 bustle box)
    t.pipe("paint", (-0.65, y0 + 0.36, -1.32), (0.65, y0 + 0.36, -1.32), 0.105, seg=8 if lod else 12, bevel=0.01)
    for sx in (-1, 1):
        bx_pos = sx * 1.26
        with t.frame((bx_pos, y0 + 0.34, -0.58), yaw=sx * 0.22):
            t.box("paint", (-0.12, -0.18, -0.34), (0.12, 0.18, 0.34), bevel=0.012, tint=(0.95, 0.95, 0.93))
        # Side marking carrier plate
        t.box("paint", (sx * 1.32 - 0.03, y0 + 0.34, -0.58 - 0.22), (sx * 1.32 + 0.03, y0 + 0.54, -0.58 + 0.22), bevel=0.006)
        add_star_or_diamond_decal_x(t, sx * 1.356, y0 + 0.44, -0.58, sx, size=0.11)

    if variant == "t_72ua1_t_72b":
        t.box("paint", (-0.62, y0 + 0.32, -1.48), (0.62, y0 + 0.64, -1.02), bevel=0.016, tint=(0.96, 0.97, 0.93))

    return t


def build_welded_turret(lod, variant):
    """Welded modern turrets for T-90M Proryv-3, Iranian Karrar, and Sudanese Al-Bashir (Type 85-IIM)."""
    t = Part("Turret", seed=67)
    bev = 0.016 if lod else 0.026
    is_t90m = variant == "t_90m_proryv"
    is_karrar = variant == "karrar"
    y0 = 1.32 if not variant == "t_72_al_bashir" else 1.36
    y_top = 2.08 if is_t90m else (2.14 if is_karrar else 2.18)

    # Core welded hexagonal/octagonal turret shell
    bot_xz = [(-0.36, 1.36), (0.36, 1.36), (1.38, 0.66), (1.32, -1.28), (1.02, -1.72), (-1.02, -1.72), (-1.32, -1.28), (-1.38, 0.66)]
    top_xz = [(-0.32, 0.88), (0.32, 0.88), (1.12, 0.40), (1.10, -1.24), (0.88, -1.62), (-0.88, -1.62), (-1.10, -1.24), (-1.12, 0.40)]
    t.prism_y("paint", bot_xz, y0, y_top, top_xz=top_xz, bevel=bev, seg=1, ao_y=(y0, y_top, 0.78))

    if is_t90m:
        # Iconic T-90M "clamshell" Relikt heavy wedge ERA modules across turret front cheeks!
        for sx in (-1, 1):
            w_bot = [(sx * 0.36, 1.54), (sx * 1.48, 0.78), (sx * 1.44, 0.12), (sx * 0.38, 0.88)]
            w_top = [(sx * 0.34, 1.06), (sx * 1.24, 0.48), (sx * 1.20, 0.08), (sx * 0.36, 0.66)]
            if sx < 0:
                w_bot = list(reversed(w_bot))
                w_top = list(reversed(w_top))
            t.prism_y("paint", w_bot, y0 + 0.08, y_top - 0.02, top_xz=w_top, bevel=0.018, seg=1, tint=(1.04, 1.04, 1.02))
            # Side Relikt ERA blocks & turret rear slat cage
            t.box("paint", (sx * 1.32 - 0.08, y0 + 0.12, -1.22), (sx * 1.32 + 0.08, y_top - 0.08, 0.14), bevel=0.014, tint=(1.02, 1.02, 1.0))
            add_star_or_diamond_decal_x(t, sx * 1.408, (y0 + y_top) * 0.5, -0.55, sx, size=0.13)
        # Rear external isolated ammunition bustle (`ארגז תחמושת אחורי של Proryv-3`) + bustle slat basket
        t.box("paint", (-0.98, y0 + 0.24, -2.36), (0.98, y_top + 0.02, -1.58), bevel=0.020, tint=(0.98, 0.99, 0.96))
        if not lod:
            for ry in (y0 + 0.28, y0 + 0.48, y0 + 0.68):
                t.pipe("metal_dark", (-1.18, ry, -2.52), (1.18, ry, -2.52), 0.014, seg=6)
                for sx in (-1, 1):
                    t.pipe("metal_dark", (sx * 1.18, ry, -2.52), (sx * 1.36, ry, -1.35), 0.014, seg=6)

    elif is_karrar:
        # Angular stepped Iranian Karrar ERA cheek blocks + rear carousel bustle + side cages
        for sx in (-1, 1):
            for j in range(3):
                cx = sx * (0.54 + j * 0.28)
                cz = 1.28 - j * 0.24
                with t.frame((cx, (y0 + y_top) * 0.5, cz), yaw=-sx * 0.46):
                    t.box("paint", (-0.16, -0.32, -0.18), (0.16, 0.32, 0.18), bevel=0.014, tint=(1.03, 1.03, 1.01))
            t.box("paint", (sx * 1.30 - 0.08, y0 + 0.14, -1.30), (sx * 1.30 + 0.08, y_top - 0.08, 0.18), bevel=0.014)
            add_star_or_diamond_decal_x(t, sx * 1.388, (y0 + y_top) * 0.5, -0.55, sx, size=0.13)
        t.box("paint", (-1.04, y0 + 0.22, -2.32), (1.04, y_top + 0.02, -1.56), bevel=0.020, tint=(0.99, 0.99, 0.97))

    else:
        # Al-Bashir / Type 85-IIM clean sharp welded composite wedge cheeks + bustle stowage basket
        for sx in (-1, 1):
            w_bot = [(sx * 0.36, 1.48), (sx * 1.44, 0.76), (sx * 1.40, 0.18), (sx * 0.38, 0.92)]
            w_top = [(sx * 0.34, 1.04), (sx * 1.20, 0.52), (sx * 1.18, 0.14), (sx * 0.36, 0.72)]
            if sx < 0:
                w_bot = list(reversed(w_bot))
                w_top = list(reversed(w_top))
            t.prism_y("paint", w_bot, y0 + 0.06, y_top - 0.02, top_xz=w_top, bevel=0.018, seg=1, tint=(1.02, 1.02, 1.0))
            t.box("paint", (sx * 1.30 - 0.09, y0 + 0.18, -1.25), (sx * 1.30 + 0.09, y_top - 0.12, -0.10), bevel=0.014, tint=(0.96, 0.96, 0.94))
            add_star_or_diamond_decal_x(t, sx * 1.396, (y0 + y_top) * 0.5, -0.68, sx, size=0.13)
        t.box("paint", (-0.96, y0 + 0.28, -2.18), (0.96, y_top - 0.04, -1.58), bevel=0.018)

    return t


# ==============================================================================
# 125 MM 2A46M / 2A46M-5 SMOOTHBORE GUN & ROOF EQUIPMENT
# ==============================================================================
def build_125mm_gun(lod, gp, variant):
    """125 mm 2A46M / 2A46M-5 smoothbore gun (with Karrar armored thermal barrel shroud option!)."""
    g = Part("Gun", seed=81)
    gy, gz = gp[1], gp[2]
    seg = 10 if lod else 20

    # Armored gun mantlet / canvas dust cover
    g.box("canvas" if "t_72" in variant and variant != "t_72_al_bashir" else "paint",
          (-0.32, gy - 0.22, gz - 0.10), (0.32, gy + 0.22, gz + 0.42), bevel=0.04, tint=(0.92, 0.92, 0.88))

    if variant == "karrar":
        # Iconic thick faceted thermal barrel shroud of Iranian Karrar!
        g.pipe("paint", (0, gy, gz + 0.36), (0, gy, gz + 2.15), 0.165, seg=8 if lod else 8, r2=0.150, bevel=0.01, tint=(1.02, 1.02, 1.0))
        g.pipe("paint", (0, gy + 0.015, gz + 2.12), (0, gy + 0.015, gz + 2.74), 0.175, seg=seg, tint=(0.98, 0.98, 0.96))
    else:
        # Standard 2A46M thermal sleeve segments + eccentric bore evacuator
        g.pipe("paint", (0, gy, gz + 0.36), (0, gy, gz + 1.88), 0.108, seg=seg, r2=0.098, tint=(0.98, 0.98, 0.96))
        g.pipe("paint", (0, gy + 0.018, gz + 1.85), (0, gy + 0.018, gz + 2.48), 0.155, seg=seg, bevel=0.012, tint=(1.02, 1.02, 1.0))

    z_tip = gz + 4.96
    g.pipe("paint", (0, gy, gz + 2.45), (0, gy, z_tip - 0.14), 0.092, seg=seg, r2=0.084, tint=(0.97, 0.97, 0.95))
    if not lod:
        for sz in (gz + 0.95, gz + 1.55, gz + 3.25, gz + 4.05):
            g.pipe("metal_dark", (0, gy, sz), (0, gy, sz + 0.035), 0.104, seg=seg)
        if variant in ("t_90m_proryv", "karrar"):
            # Muzzle reference system mirror above barrel tip
            g.box("metal_dark", (-0.025, gy + 0.082, z_tip - 0.20), (0.025, gy + 0.145, z_tip - 0.08), bevel=0.004)

    g.tube_axis("metal_dark", (0, gy, z_tip - 0.16), (0, gy, z_tip), 0.090, 0.0625, seg=seg)
    g.cyl("dark", (0, gy, z_tip - 0.17), 0.063, 0.02, seg=10)
    return g, z_tip


def build_roof_weapons_and_sights(rig, lod, variant):
    is_modern = variant in ("t_90m_proryv", "karrar")
    y_roof = 2.08 if variant == "t_90m_proryv" else (2.14 if variant == "karrar" else (2.18 if variant == "t_72_al_bashir" else 2.10))

    # Gunner primary sight (Sosna-U / TPD-K1 on left roof)
    gs = Part("Gunner_Sight")
    gs.box("paint", (-0.78, y_roof - 0.02, 0.18), (-0.38, y_roof + 0.28, 0.64), bevel=0.016)
    gs.box("glass", (-0.72, y_roof + 0.06, 0.62), (-0.44, y_roof + 0.22, 0.66), tint=OPTIC_FLIR if is_modern else OPTIC_GREEN)
    rig.add("Gunner_Sight", "Turret", (-0.58, y_roof, 0.40), gs)

    # Commander & Gunner Hatches
    for hname, hx, hz in (("Hatch_Commander", 0.52, -0.28), ("Hatch_Loader", -0.52, -0.36)):
        hp = Part(hname)
        hp.cyl("paint", (hx, y_roof - 0.02, hz), 0.28, 0.09, seg=10 if lod else 16, bevel=0.012)
        rig.add(hname, "Turret", (hx, y_roof + 0.02, hz - 0.26), hp)

    if is_modern:
        # PK-PAN Hawkeye Panoramic CITV + UDP T05BV-1 12.7mm Kord Remote Weapon Station!
        citv = Part("CITV")
        citv.cyl("paint", (0.52, y_roof + 0.04, -0.68), 0.16, 0.26, seg=10 if lod else 14, bevel=0.01)
        citv.box("paint", (0.34, y_roof + 0.28, -0.86), (0.70, y_roof + 0.52, -0.50), bevel=0.016)
        citv.box("glass", (0.40, y_roof + 0.33, -0.52), (0.64, y_roof + 0.47, -0.48), tint=OPTIC_FLIR)
        rig.add("CITV", "Turret", (0.52, y_roof + 0.04, -0.68), citv)

        rws = Part("CROWS")
        rx, rz = 0.62, -1.08
        rws.cyl("paint", (rx, y_roof + 0.02, rz), 0.13, 0.28, seg=8 if lod else 14)
        rws.box("paint", (rx - 0.16, y_roof + 0.28, rz - 0.22), (rx + 0.16, y_roof + 0.50, rz + 0.22), bevel=0.014)
        rws.box("metal_dark", (rx + 0.14, y_roof + 0.30, rz - 0.16), (rx + 0.30, y_roof + 0.52, rz + 0.14), bevel=0.01)
        rws.pipe("metal_dark", (rx, y_roof + 0.42, rz + 0.18), (rx, y_roof + 0.42, rz + 0.96), 0.024, seg=8)
        rig.add("CROWS", "Turret", (rx, y_roof + 0.04, rz), rws)
    else:
        # Manual NSVT / W85 12.7 mm Heavy AA Machine Gun on Commander's Cupola!
        mg = Part("Commander_MG")
        mx, mz = 0.52, -0.44
        mg.cyl("metal_dark", (mx, y_roof + 0.05, mz), 0.08, 0.22, seg=8)
        mg.box("metal_dark", (mx - 0.09, y_roof + 0.24, mz - 0.20), (mx + 0.09, y_roof + 0.38, mz + 0.22), bevel=0.008)
        mg.box("metal_dark", (mx + 0.08, y_roof + 0.20, mz - 0.12), (mx + 0.24, y_roof + 0.38, mz + 0.12), bevel=0.008)
        mg.pipe("metal_dark", (mx, y_roof + 0.32, mz + 0.20), (mx, y_roof + 0.32, mz + 0.98), 0.022, seg=8)
        rig.add("Commander_MG", "Turret", (mx, y_roof + 0.06, mz), mg)

    # Tucha 902B 81 mm Smoke Grenade Dischargers
    for label, side in (("L", -1), ("R", 1)):
        sm = Part(f"Smoke_Launcher_{label}")
        sx_p = side * (1.28 if is_modern else 1.20)
        sz_p = -0.15 if is_modern else 0.22
        sy_p = y_roof - 0.24
        sm.box("paint", (sx_p - 0.07, sy_p - 0.08, sz_p - 0.18), (sx_p + 0.07, sy_p + 0.08, sz_p + 0.18), bevel=0.008)
        if not lod:
            for j in range(6):
                ty = sy_p + (0.05 if j >= 3 else -0.03)
                tz = sz_p + ((j % 3) - 1) * 0.10
                sm.pipe("metal_dark", (sx_p, ty, tz), (sx_p + side * 0.09, ty + 0.08, tz + 0.15), 0.034, seg=6)
        rig.add(f"Smoke_Launcher_{label}", "Turret", (sx_p, sy_p, sz_p), sm)

    # Whip radio antenna
    ant = Part("Antenna_1")
    ax, ay, az = -0.88, y_roof - 0.04, -1.08
    ant.cyl("metal_dark", (ax, ay, az), 0.038, 0.11, seg=8)
    ant.pipe("metal_dark", (ax, ay + 0.11, az), (ax - 0.03, ay + 1.32, az - 0.06), 0.011, seg=6, r2=0.004)
    rig.add("Antenna_1", "Turret", (ax, ay, az), ant)


# ==============================================================================
# RIG ASSEMBLY
# ==============================================================================
def build_t72_t90_rig(lod=0, variant="t_90m_proryv"):
    rig = VehicleRig(lod=lod)
    k = 0.90 if variant == "t_72_al_bashir" else (0.86 if variant == "karrar" else 0.87)
    cast = variant in ("t_72", "t_72av", "t_72ua1_t_72b")

    rig.add("Hull", rig.root_name, (0.0, 0.0, 0.0), build_t72_hull(lod, variant, k))

    y_deck = 1.31 if variant == "t_72_al_bashir" else 1.27
    tz = 0.08
    ring = Part("Turret_Ring")
    ring.cyl("metal_dark", (0.0, y_deck - 0.02, tz), 1.04, 0.08, seg=14 if lod else 24)
    rig.add("Turret_Ring", "Hull", (0.0, y_deck + 0.02, tz), ring)

    turret_part = build_cast_t72_turret(lod, variant) if cast else build_welded_turret(lod, variant)
    rig.add("Turret", "Hull", (0.0, y_deck + 0.04, tz), turret_part)

    gp = (0.0, 1.76 if cast else 1.80, 1.18)
    gun_part, z_tip = build_125mm_gun(lod, gp, variant)
    rig.add("Gun", "Turret", gp, gun_part)
    rig.add("Muzzle", "Gun", (0.0, gp[1], z_tip), None)

    build_roof_weapons_and_sights(rig, lod, variant)

    for label, side in (("L", -1), ("R", 1)):
        wx = side * 1.42
        for i, wz in enumerate(UVZ_WHEEL_ZS):
            wp = (wx, 0.44, wz * k)
            rig.add(f"Wheel_{label}{i}", "Hull", wp, build_uvz_wheel(wp, lod, side, r=0.365))
        sp_piv = (wx, 0.65 * k, -3.23 * k)
        rig.add(f"Sprocket_{label}", "Hull", sp_piv, build_uvz_sprocket(sp_piv, lod, side, scale=k))
        id_piv = (wx, 0.65 * k, 3.23 * k)
        rig.add(f"Idler_{label}", "Hull", id_piv, build_uvz_idler(id_piv, lod, side, scale=k))
        for i, rz in enumerate((-1.75 * k, 0.0, 1.75 * k)):
            rp = (wx, 1.00 * k, rz)
            rig.add(f"Roller_{label}{i}", "Hull", rp, build_uvz_roller(rp, lod, side, scale=k))
        trk = Part(f"Track_{label}")
        trk.build_track(wx, lod=lod, width=0.58)
        rig.add(f"Track_{label}", "Hull", (wx, 0.0, 0.0), trk, mesh_scale=(1.0, k, k))

    rig.add("Exhaust", "Hull", (-1.75, 1.18, -2.10), None)
    rig.add("Engine_Deck", "Hull", (0.0, y_deck + 0.05, -2.55), None)
    return rig


T72_T90_VARIANTS = (
    "t_90m_proryv",
    "karrar",
    "t_72ua1_t_72b",
    "t_72av",
    "t_72",
    "t_72_al_bashir",
)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    veh_dir = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../godot/assets/art/vehicles"))
    os.makedirs(veh_dir, exist_ok=True)
    targets = T72_T90_VARIANTS if ("--all" in argv or not argv) else [v for v in argv if not v.startswith("-")]
    for var in targets:
        init_scene()
        out_p = os.path.join(veh_dir, f"tank__{var}.glb")
        export_vehicle(out_p, build_t72_t90_rig(0, var), build_t72_t90_rig(1, var))
