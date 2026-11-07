"""Israeli Merkava Mk 4M ('Meil Ruach' / Trophy APS) & Merkava Mk 3D Baz Main Battle Tanks, modelled in Blender.

Run all Merkava variants:
    blender -b -P native/tools/models/blender/build_merkava.py -- --all

Produces game-ready articulated glTF vehicles (`LOD0`, `LOD1`, `Wreck`) in real metres (+Y up, +Z front):
  - Front-engine Merkava hull: long asymmetric sloped glacis with raised right-side powerpack deck & recessed soot-stained
    right-flank exhaust louver box, recessed left-side driver's station with 3 angled periscopes, 6 heavy spring-hung modular
    ballistic side skirts per side, rear clamshell infantry/ammo access door, and slatted rear stowage baskets.
  - Front drive sprockets (`Sprocket_L/R` at +Z), rear track-tensioning idlers (`Idler_L/R` at -Z), 12 sculpted steel-ribbed
    Merkava road wheels on coil-spring suspension arms, 6 return rollers, and 3D heavy steel Merkava tracks.
  - Merkava Mk 4M turret: broad low-profile modular arrowhead composite shell, 4 Elta WindGuard AESA radar panels + twin
    Trophy APS hemisphere launchers & reload shields, stabilized panoramic COAPS sight, mantlet-mounted .50 cal M2HB + roof
    7.62 mm FN MAG, IMI 120 mm MG253 smoothbore in quilted/ringed thermal sleeve, and rear turret basket with 16 hanging
    ball-and-chain anti-RPG curtains.
  - Merkava Mk 3D Baz ('Dor Dalet') turret: sharper narrow arrowhead profile with 3 bolted modular cheek armor packs per
    flank, left-forward Baz gunner sight, twin pintle roof machine guns, and roof-level rear basket with ball-and-chain curtain.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_vehicle import Part, VehicleRig, init_scene, export_vehicle

TRACK_SCALE = 0.98
TRACK_X = 1.48
WHEEL_ZS = [-2.52, -1.52, -0.52, 0.48, 1.48, 2.48]

OPTIC_FLIR = (2.2, 1.35, 0.55)
OPTIC_COOL = (0.85, 1.35, 1.45)
TAIL_RED = (4.5, 0.35, 0.25)


def add_idf_chevron_x(part, x_plane, cy, cz, sx_out, arm_len=0.19, thick=0.045, mode="down", x_fn=None):
    """IDF company tactical 'V' or '>' chevron flush on a vertical or sloped side plate."""
    xf = (lambda y: x_plane) if x_fn is None else x_fn
    out = (sx_out, 0.25 if x_fn is not None else 0.0, 0.0)
    if mode == "down":
        tip_y = cy - arm_len * 0.55
        top_y = cy + arm_len * 0.55
        for sz in (-1.0, 1.0):
            p0 = (xf(tip_y), tip_y, cz)
            p1 = (xf(tip_y + thick * 1.3), tip_y + thick * 1.3, cz)
            p2 = (xf(top_y + thick * 0.4), top_y + thick * 0.4, cz + sz * arm_len * 0.72)
            p3 = (xf(top_y - thick * 0.8), top_y - thick * 0.8, cz + sz * arm_len * 0.72)
            part.decal_quad("markings", p0, p1, p2, p3, outward=out)
    else:
        tip_z = cz + arm_len * 0.65
        back_z = cz - arm_len * 0.55
        part.decal_quad(
            "markings",
            (xf(cy), cy, tip_z),
            (xf(cy), cy, tip_z - thick * 1.25),
            (xf(cy + arm_len * 0.72), cy + arm_len * 0.72, back_z - thick * 0.4),
            (xf(cy + arm_len * 0.72), cy + arm_len * 0.72, back_z + thick * 0.85),
            outward=out,
        )
        part.decal_quad(
            "markings",
            (xf(cy), cy, tip_z - thick * 1.25),
            (xf(cy), cy, tip_z),
            (xf(cy - arm_len * 0.72), cy - arm_len * 0.72, back_z + thick * 0.85),
            (xf(cy - arm_len * 0.72), cy - arm_len * 0.72, back_z - thick * 0.4),
            outward=out,
        )


def build_merkava_wheel(wp, lod, side):
    """Heavy Merkava paired road wheel with radial reinforcement ribs & ventilation holes."""
    p = Part(f"Wheel_{side}")
    r = 0.39
    s = side
    with p.frame(wp):
        if lod:
            prof = [
                (-0.22, 0.0, "paint", 0.78),
                (-0.22, r, "rubber", 1.0),
                (0.22, r, "paint", 0.86),
                (0.22, 0.0, "paint", 0.86),
            ]
            p.lathe_x((0, 0, 0), prof, seg=8)
            return p

        prof_r = [
            (-0.23, 0.0, "metal_dark", 0.45),
            (-0.23, 0.28, "paint", 0.74),
            (-0.22, 0.30, "rubber", 0.92),
            (-0.22, r, "rubber", 1.0),
            (-0.045, r, "metal_dark", 0.40),
            (-0.040, 0.26, "metal_dark", 0.35),
            (0.040, 0.26, "rubber", 0.92),
            (0.045, r, "rubber", 1.0),
            (0.22, r, "paint", 0.94),
            (0.22, 0.31, "paint", 0.84),
            (0.175, 0.27, "paint", 0.74),
            (0.185, 0.135, "paint", 0.92),
            (0.185, 0.0, "paint", 0.92),
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

        # Heavy domed Merkava oil hub + 8 radial structural ribs!
        p.pipe("paint", (s * 0.175, 0, 0), (s * 0.245, 0, 0), 0.115, seg=14, r2=0.085, bevel=0.01, tint=(0.95, 0.95, 0.93))
        for k in range(8):
            a = math.tau * k / 8.0
            with p.frame((s * 0.188, 0, 0), pitch=a):
                p.box("paint", (-0.016, 0.11, -0.018), (0.016, 0.285, 0.018), bevel=0.004, tint=(0.90, 0.90, 0.88))
            # Dark relief holes between ribs
            ha = a + math.pi / 8.0
            p.pipe("dark", (s * 0.172, 0.215 * math.cos(ha), 0.215 * math.sin(ha)),
                   (s * 0.188, 0.215 * math.cos(ha), 0.215 * math.sin(ha)), 0.024, seg=6)
    return p


def build_front_sprocket(wp, lod, side):
    """Front-mounted Merkava final-drive sprocket with heavy armoured hub dome & 12 drive teeth."""
    p = Part(f"Sprocket_{side}")
    s = side
    n_seg = 10 if lod else 20
    with p.frame(wp):
        prof = [
            (-0.23, 0.0, "metal_dark", 0.55),
            (-0.23, 0.42, "paint", 0.78),
            (-0.16, 0.43, "metal_dark", 0.45),
            (-0.14, 0.33, "metal_dark", 0.40),
            (0.14, 0.33, "paint", 0.85),
            (0.16, 0.43, "paint", 0.90),
            (0.23, 0.42, "paint", 0.88),
            (0.23, 0.0, "paint", 0.88),
        ]
        p.lathe_x((0, 0, 0), prof, seg=n_seg)
        p.pipe("paint", (s * 0.12, 0, 0), (s * 0.27, 0, 0), 0.22, seg=n_seg, r2=0.16, bevel=0.014, tint=(0.92, 0.92, 0.90))
        if not lod:
            for tx in (-0.19, 0.19):
                for k in range(12):
                    a = math.tau * k / 12.0
                    with p.frame((tx, 0, 0), pitch=a):
                        p.box("metal", (-0.022, 0.40, -0.045), (0.022, 0.505, 0.045), bevel=0.007, tint=(1.04, 1.04, 1.06))
    return p


def build_rear_idler(wp, lod, side):
    """Rear track-tensioning idler wheel."""
    p = Part(f"Idler_{side}")
    s = side
    n_seg = 8 if lod else 16
    with p.frame(wp):
        prof_r = [
            (-0.20, 0.0, "metal_dark", 0.50),
            (-0.20, 0.415, "metal", 0.90),
            (-0.05, 0.415, "metal_dark", 0.42),
            (-0.04, 0.28, "metal_dark", 0.42),
            (0.04, 0.28, "metal_dark", 0.72),
            (0.05, 0.415, "metal", 0.92),
            (0.20, 0.415, "paint", 0.88),
            (0.16, 0.31, "paint", 0.75),
            (0.17, 0.13, "paint", 0.90),
            (0.17, 0.0, "paint", 0.90),
        ]
        if s < 0:
            prof = []
            for i in range(len(prof_r) - 1, -1, -1):
                x_cur, r_cur, _, _ = prof_r[i]
                rp = prof_r[i - 1][2] if i > 0 else "paint"
                kp = prof_r[i - 1][3] if i > 0 else 0.9
                prof.append((-x_cur, r_cur, rp, kp))
            p.lathe_x((0, 0, 0), prof, seg=n_seg)
        else:
            p.lathe_x((0, 0, 0), prof_r, seg=n_seg)
        p.pipe("paint", (s * 0.155, 0, 0), (s * 0.225, 0, 0), 0.12, seg=12, r2=0.092, bevel=0.008)
    return p


def build_roller(wp, lod, side):
    if lod:
        return None
    p = Part(f"Roller_{side}")
    with p.frame(wp):
        for dx in (-0.11, 0.11):
            p.pipe("rubber", (dx - 0.042, 0, 0), (dx + 0.042, 0, 0), 0.11, seg=10)
        p.pipe("metal_dark", (-0.17, 0, 0), (0.17, 0, 0), 0.035, seg=8)
    return p


def build_merkava_hull(lod, mk4=True):
    """Merkava front-engine hull: sloped asymmetric powerpack glacis, right side exhaust, 6 heavy skirts/side & rear troop door."""
    h = Part("Hull", seed=41 if mk4 else 43)
    bev = 0.014 if lod else 0.028
    deck_y = 1.56 if mk4 else 1.52

    # 1. Core V-bottom armoured hull tub (`x = -1.16 .. +1.16, z = -3.82 .. +3.76`)
    hull_yz = [
        (0.46, 3.10),          # front lower belly break
        (0.94, 3.78),          # front bow nose (ahead of front final-drive sprockets)
        (1.12, 3.74),          # upper bow crease
        (deck_y, 0.85),        # long sloped front engine glacis!
        (deck_y, -3.76),       # fighting/troop compartment deck
        (1.42, -3.84),         # rear upper bevel
        (0.54, -3.82),         # vertical rear infantry access wall
        (0.44, -3.28),         # rear belly pan
    ]
    h.prism_x("paint", hull_yz, -1.16, 1.16, bevel=bev, seg=1, tint=(1.0, 1.0, 1.0), ao_y=(0.45, 1.45, 0.68))

    # 2. Asymmetric Raised Right-Side Engine Hood (`x = -0.18 .. +1.12, z = +0.75 .. +3.52`) — signature Merkava silhouette!
    eng_pts = [
        (-0.18, deck_y - 0.02, 0.72),
        (1.12, deck_y - 0.02, 0.72),
        (1.12, 1.10, 3.64),
        (-0.10, 1.10, 3.64),
        (-0.06, deck_y + (0.14 if mk4 else 0.10), 0.92),
        (1.04, deck_y + (0.14 if mk4 else 0.10), 0.92),
        (1.02, 1.20, 3.46),
        (-0.04, 1.18, 3.46),
    ]
    h.hull("paint", eng_pts, bevel=bev, seg=1, tint=(1.03, 1.03, 1.01))

    # Engine intake grilles flush on sloped right glacis deck (positive pitch tilts +Z downward along glacis!)
    glacis_pitch = math.atan2((deck_y + 0.12) - 1.20, 3.46 - 0.92)
    with h.frame((0.50, (deck_y + 0.12 + 1.20) * 0.5 + 0.008, 2.19), pitch=glacis_pitch):
        h.box("dark", (-0.40, -0.018, -0.78), (0.40, 0.012, 0.78))
        if not lod:
            for k in range(11):
                sz = -0.70 + k * 0.140
                h.box("metal_dark", (-0.38, 0.008, sz - 0.022), (0.38, 0.024, sz + 0.022), tint=(0.68, 0.68, 0.70))

    # 3. Left-Forward Driver's Recessed Alcove & 3 Angled Periscopes (`x = -0.64, z = +1.55`)
    glacis_left_pitch = math.atan2(deck_y - 1.12, 3.74 - 0.85)
    with h.frame((-0.64, 1.44, 1.58), pitch=glacis_left_pitch):
        h.box("paint", (-0.28, -0.02, -0.32), (0.28, 0.065, 0.32), bevel=0.016, tint=(0.98, 0.98, 0.96))
        for px, yaw_p in ((-0.16, 0.28), (0.0, 0.0), (0.16, -0.28)):
            with h.frame((px, 0.055, 0.20), yaw=yaw_p):
                h.box("paint", (-0.072, 0.0, -0.08), (0.072, 0.078, 0.08), bevel=0.008)
                h.box("glass", (-0.058, 0.016, 0.065), (0.058, 0.062, 0.084), tint=OPTIC_COOL)

    # 4. Dark Inner Wheel Wells + Merkava External Helical Coil-Spring Suspension Bogies!
    for sx in (-1, 1):
        h.box("dark", (sx * 1.16 - 0.03, 0.46, -3.40), (sx * 1.16 + 0.03, 1.44, 3.32))
        if not lod:
            for wz in WHEEL_ZS:
                h.pipe("metal_dark", (sx * 1.15, 0.62, wz + 0.20), (sx * 1.44, 0.49, wz), 0.055, seg=8)
                # Vertical coil spring cylinder visible behind skirt gap
                h.cyl("metal_dark", (sx * 1.24, 0.56, wz + 0.08), 0.058, 0.28, seg=8, tint=(0.52, 0.52, 0.55))

    # 5. Track Sponsons (`x = +-1.14 .. +-1.80`) + Iconic Right-Flank Soot-Darkened Exhaust Louver Box!
    for sx in (-1, 1):
        x_in, x_out = (1.14, 1.80) if sx > 0 else (-1.80, -1.14)
        sponson_yz = [
            (1.38, -3.82),
            (deck_y - 0.02, -3.76),
            (deck_y - 0.02, 2.95),
            (1.16, 3.80),
            (1.02, 3.78),
            (1.30, 2.88),
        ]
        h.prism_x("paint", sponson_yz, x_in, x_out, bevel=0.016, seg=1, tint=(0.98, 0.98, 0.97))
        # Front & rear heavy mudflaps
        h.box("rubber", (min(x_in, x_out) + 0.02, 0.84, 3.76), (max(x_in, x_out) - 0.02, 1.08, 3.82), bevel=0.008)
        h.box("rubber", (min(x_in, x_out) + 0.02, 0.48, -3.88), (max(x_in, x_out) - 0.02, 1.32, -3.82), bevel=0.008)

    # Right-side armoured engine exhaust louver box (`x = +1.72..+1.86, z = +1.55..+2.48`)
    h.box("metal_dark", (1.72, 1.24, 1.52), (1.865, 1.53, 2.52), bevel=0.014, tint=(0.48, 0.46, 0.44))
    h.box("dark", (1.83, 1.28, 1.58), (1.872, 1.49, 2.46))
    if not lod:
        for k in range(8):
            lz = 1.64 + k * 0.108
            h.box("metal_dark", (1.835, 1.29, lz - 0.016), (1.878, 1.48, lz + 0.016), yaw=0.35, tint=(0.38, 0.36, 0.35))

    # 6. Six Heavy Modular Ballistic Side Skirts per Side (`Bazooka plates`) with stepped lower contour & spring hangers!
    skirt_zs = [3.16, 2.06, 0.96, -0.14, -1.24, -2.34, -3.44]
    for sx in (-1, 1):
        h.box("dark", (sx * 1.76 - 0.02, 0.88, -3.40), (sx * 1.76 + 0.02, 1.46, 3.12))
        for idx in range(6):
            zf = skirt_zs[idx] - 0.018
            zr = skirt_zs[idx + 1] + 0.018
            xo = 1.855
            xi = 1.745
            x0, x1 = (xi, xo) if sx > 0 else (-xo, -xi)
            # Merkava skirts have angled front/rear lower corners & slight sawtooth bottom height
            y_bot = 0.72 if idx % 2 == 0 else 0.68
            if idx == 0:
                # Front sprocket mud-relief skirt
                yz = [(0.96, zf), (1.42, zf), (1.46, zr), (0.72, zr), (0.82, zf - 0.36)]
            elif idx == 5:
                yz = [(0.72, zf), (1.46, zf), (1.42, zr), (0.94, zr), (0.78, zr + 0.36)]
            else:
                yz = [(y_bot + 0.04, zf), (1.46, zf), (1.46, zr), (y_bot, zr)]
            tk = 1.01 if idx % 2 == 0 else 0.97
            h.prism_x("paint", yz, x0, x1, bevel=0.018, seg=1, tint=(tk, tk, tk * 0.99), ao_y=(0.68, 1.46, 0.82))
            if not lod:
                zc = (zf + zr) * 0.5
                for dz in (-0.32, 0.32):
                    h.box("metal_dark", (sx * xo - 0.014, 1.34, zc + dz - 0.035), (sx * xo + 0.014, 1.44, zc + dz + 0.035), bevel=0.005)
                h.cyl("metal_dark", (sx * xo, 0.96, zc), 0.022, 0.02, seg=6)

        # IDF tactical chevron on mid side skirt #3
        add_idf_chevron_x(h, sx * 1.862, 1.08, -0.69, sx, arm_len=0.17, thick=0.042, mode="down")

    # 7. Front Headlight Clusters & Heavy Forged IDF Tow Horns (`z = +3.72`)
    for sx in (-1, 1):
        # Forged front tow horn + shackle
        h.box("metal_dark", (sx * 0.76 - 0.05, 0.82, 3.68), (sx * 0.76 + 0.05, 0.98, 3.88), bevel=0.012)
        if not lod:
            h.pipe("metal", (sx * 0.76 - 0.06, 0.86, 3.85), (sx * 0.76 + 0.06, 0.86, 3.85), 0.024, seg=8)
        # Armoured headlamp box on front fender shoulder
        hx = sx * 1.38
        h.box("paint", (hx - 0.16, 1.18, 3.42), (hx + 0.16, 1.36, 3.66), bevel=0.012)
        h.box("dark", (hx - 0.13, 1.20, 3.58), (hx + 0.13, 1.33, 3.67))
        h.pipe("glass", (hx - 0.05, 1.265, 3.63), (hx - 0.05, 1.265, 3.68), 0.048, seg=10, tint=(2.2, 2.1, 1.8))
        h.pipe("metal_dark", (hx + 0.06, 1.265, 3.63), (hx + 0.06, 1.265, 3.68), 0.036, seg=8)

    # 8. Signature Merkava Rear Hull: Central Clamshell Infantry/Ammo Access Door + Side AC/Battery Boxes + Rear Baskets!
    # Central upper/lower clamshell armoured door (`x = -0.42 .. +0.42, z = -3.88`)
    h.box("paint", (-0.42, 0.56, -3.90), (0.42, 1.02, -3.80), bevel=0.016, tint=(0.94, 0.94, 0.92))
    h.box("paint", (-0.42, 1.04, -3.90), (0.42, 1.46, -3.80), bevel=0.016, tint=(0.96, 0.96, 0.94))
    h.box("metal_dark", (-0.48, 0.44, -3.98), (0.48, 0.53, -3.80), bevel=0.01)  # armored rear entry step!
    if not lod:
        h.box("metal_dark", (-0.08, 0.99, -3.93), (0.08, 1.08, -3.88), bevel=0.008)  # central locking lever
        # Left & Right rear hull stowage baskets / APU & AC armored boxes + ruby tail-lights
        for sx in (-1, 1):
            bx0, bx1 = (0.50, 1.14) if sx > 0 else (-1.14, -0.50)
            h.box("paint", (bx0, 0.78, -3.94), (bx1, 1.42, -3.80), bevel=0.018, tint=(0.95, 0.95, 0.93))
            for ky in (0.90, 1.04, 1.18):
                h.box("metal_dark", (bx0 + 0.08, ky - 0.014, -3.96), (bx1 - 0.08, ky + 0.014, -3.92))
            tx = sx * 1.32
            h.box("metal_dark", (tx - 0.09, 1.18, -3.89), (tx + 0.09, 1.29, -3.82), bevel=0.008)
            h.box("glass", (tx - 0.065, 1.205, -3.90), (tx + 0.065, 1.265, -3.875), tint=TAIL_RED)

    return h


def _add_ball_and_chain_curtain(t, lod, z_bar, x_half, y_top, y_bot, n_chains=15):
    """Iconic Merkava rear turret basket anti-RPG hanging steel chains & weighted balls."""
    t.pipe("metal_dark", (-x_half, y_top, z_bar), (x_half, y_top, z_bar), 0.018, seg=6)
    if lod:
        return
    for k in range(n_chains):
        cx = -x_half + 0.08 + k * (2.0 * x_half - 0.16) / max(1, n_chains - 1)
        # Slight alternating sway so the curtain looks natural and heavy
        dz = 0.012 if k % 2 == 0 else -0.012
        t.pipe("metal_dark", (cx, y_top, z_bar), (cx, y_bot + 0.07, z_bar + dz), 0.011, seg=5, tint=(0.55, 0.55, 0.58))
        t.cyl("metal", (cx, y_bot, z_bar + dz), 0.036, 0.075, seg=8, bevel=0.016, tint=(0.78, 0.78, 0.82))


def build_mk4_turret(lod):
    """Merkava Mk 4M ('Meil Ruach') wide modular arrowhead turret with Trophy APS radars & launchers + ball-and-chain basket."""
    t = Part("Turret", seed=53)
    bev = 0.016 if lod else 0.032
    pz = -0.35  # Turret ring centre

    # 1. Broad, Low Modular Arrowhead Composite Turret Shell (`y = 1.58 .. 2.38`)
    #    Merkava Mk 4's turret sweeps from a narrow needle-like gun nose (`z = +1.82`) out to wide overhanging
    #    modular shoulders (`x = +-1.66` at `z = -0.35`) and tapers into the long rear module (`z = -2.18`).
    bot_xz = [
        (-0.30, 1.78), (0.30, 1.78),
        (1.58, 0.35), (1.68, -0.85),
        (1.32, -2.15), (-1.32, -2.15),
        (-1.68, -0.85), (-1.58, 0.35),
    ]
    top_xz = [
        (-0.26, 0.92), (0.26, 0.92),
        (1.24, 0.08), (1.28, -0.95),
        (1.02, -2.02), (-1.02, -2.02),
        (-1.28, -0.95), (-1.24, 0.08),
    ]
    t.prism_y("paint", bot_xz, 1.60, 2.38, top_xz=top_xz, bevel=bev, seg=1,
              tint=(1.01, 1.01, 1.0), ao_y=(1.60, 2.38, 0.80))

    # Recessed dark gun rotor slot at narrow arrowhead nose
    t.box("dark", (-0.28, 1.66, 0.86), (0.28, 2.32, 1.52))

    # Sculpted Left & Right Sloped Modular Cheek Armor Wedges (overhanging lower skirt & sharp nose crease!)
    for sx in (-1, 1):
        pts_wedge = [
            (sx * 0.27, 2.38, 0.92),
            (sx * 1.24, 2.38, 0.08),
            (sx * 1.62, 1.88, 0.32),
            (sx * 1.48, 1.60, 0.25),
            (sx * 0.27, 1.62, 1.46),
            (sx * 0.27, 1.92, 1.88),
            (sx * 0.88, 1.88, 1.28),
        ]
        t.hull("paint", pts_wedge, bevel=bev, seg=1, tint=(1.03, 1.03, 1.01), ao_y=(1.60, 2.38, 0.80))

        # Modular armor seam grooves & lifting lugs along turret roof/side
        if not lod:
            for sz in (-0.15, -0.85, -1.50):
                t.box("metal_dark", (sx * 1.18 - 0.03, 2.365, sz - 0.012), (sx * 1.18 + 0.03, 2.392, sz + 0.012))

    # Thick Modular Roof Armor Cap Plates (`y = 2.38 .. 2.44`)
    t.box("paint", (-0.98, 2.37, -1.92), (0.98, 2.435, 0.02), bevel=0.018, tint=(1.04, 1.04, 1.02))

    # 2. Trophy APS ('Meil Ruach' / Windbreaker):
    #    - 4 Flat Octagonal Elta EL/M-2133 WindGuard AESA Radar Panels angled at front-quarter & rear-quarter shoulders!
    #    - Left & Right rotating Trophy Countermeasure Launchers + reload blast shields on mid turret flanks!
    for sx in (-1, 1):
        # Forward-quarter WindGuard AESA radar face (`z = +0.18`, yawed 42 deg outward)
        with t.frame((sx * 1.38, 2.16, 0.16), yaw=-sx * 0.68, pitch=-0.12):
            t.box("paint", (-0.18, -0.15, -0.08), (0.18, 0.15, 0.04), bevel=0.012, tint=(0.96, 0.96, 0.94))
            t.box("metal_dark", (-0.15, -0.12, 0.025), (0.15, 0.12, 0.055), bevel=0.008, tint=(0.78, 0.76, 0.68))

        # Rear-quarter WindGuard AESA radar face (`z = -1.78`, yawed backward-outward)
        with t.frame((sx * 1.24, 2.16, -1.78), yaw=-sx * 2.42, pitch=-0.10):
            t.box("paint", (-0.16, -0.13, -0.07), (0.16, 0.13, 0.04), bevel=0.012, tint=(0.96, 0.96, 0.94))
            t.box("metal_dark", (-0.13, -0.10, 0.025), (0.13, 0.10, 0.052), bevel=0.008, tint=(0.78, 0.76, 0.68))

        # Trophy Hemisphere Countermeasure Launcher & Armored Autoloader Shield (`x = +-1.56, z = -0.78`)
        lx = sx * 1.56
        t.box("paint", (lx - 0.12, 1.98, -1.16), (lx + 0.12, 2.38, -0.44), bevel=0.016, tint=(0.97, 0.97, 0.95))
        # Exposed rotating countermeasure launch plate & twin blast-deflector cheeks
        ox = lx + sx * 0.11
        t.pipe("metal_dark", (lx, 2.20, -0.78), (ox + sx * 0.04, 2.20, -0.78), 0.135, seg=8 if lod else 14, tint=(0.58, 0.58, 0.60))
        if not lod:
            t.box("paint", (lx - 0.06, 2.36, -1.08), (ox + sx * 0.05, 2.44, -0.50), bevel=0.008, tint=(1.02, 1.02, 1.0))

        # IDF Tactical 'V' Chevron flush on sloped turret flank ahead of Trophy (`z = -0.22`)
        def mk4_flank_x(yy, _sx=sx):
            return _sx * (1.62 + (1.26 - 1.62) * (yy - 1.60) / (2.38 - 1.60) + 0.012)
        add_idf_chevron_x(t, sx * 1.54, 1.90, -0.22, sx, arm_len=0.17, thick=0.040, mode="down", x_fn=mk4_flank_x)

    # 3. Large Rear Turret Stowage Basket (`z = -2.15 .. -2.86`) + Iconic Hanging Ball-and-Chain Anti-RPG Curtain!
    if lod:
        t.box("metal_dark", (-1.28, 1.88, -2.82), (1.28, 2.32, -2.15), bevel=0.02)
    else:
        for ry in (1.90, 2.12, 2.34):
            t.pipe("metal_dark", (-1.30, ry, -2.84), (1.30, ry, -2.84), 0.018, seg=6)
            for sx in (-1, 1):
                t.pipe("metal_dark", (sx * 1.30, ry, -2.84), (sx * 1.30, ry, -2.12), 0.018, seg=6)
        for rx in (-1.30, -0.86, -0.43, 0.0, 0.43, 0.86, 1.30):
            t.pipe("metal_dark", (rx, 1.90, -2.84), (rx, 2.34, -2.84), 0.015, seg=6)
            t.pipe("metal_dark", (rx, 1.90, -2.84), (rx, 1.90, -2.15), 0.014, seg=5)
        # Stretcher / canvas rolls & ammo cans inside Merkava basket + tall Met Mast
        t.pipe("canvas", (-0.95, 2.18, -2.52), (0.25, 2.18, -2.52), 0.135, seg=10, bevel=0.03, tint=(0.94, 0.92, 0.84))
        t.box("paint", (0.35, 1.92, -2.76), (1.12, 2.22, -2.30), bevel=0.016, tint=(0.82, 0.84, 0.76))
        t.pipe("metal_dark", (-0.92, 2.40, -1.86), (-0.92, 2.86, -1.86), 0.022, seg=8)
        t.cyl("metal_dark", (-0.92, 2.84, -1.86), 0.048, 0.08, seg=8)

    _add_ball_and_chain_curtain(t, lod, z_bar=-2.82, x_half=1.26, y_top=1.90, y_bot=1.52, n_chains=16)
    return t


def build_mk3_baz_turret(lod):
    """Merkava Mk 3D Baz ('Dor Dalet'): sharper narrow wedge turret, 3 bolted side armor modules/side, roof-flush basket & chains."""
    t = Part("Turret", seed=59)
    bev = 0.014 if lod else 0.028

    bot_xz = [
        (-0.28, 1.72), (0.28, 1.72),
        (1.44, 0.42), (1.46, -1.45),
        (1.12, -2.05), (-1.12, -2.05),
        (-1.46, -1.45), (-1.44, 0.42),
    ]
    top_xz = [
        (-0.24, 1.05), (0.24, 1.05),
        (1.16, 0.22), (1.18, -1.42),
        (0.92, -1.92), (-0.92, -1.92),
        (-1.18, -1.42), (-1.16, 0.22),
    ]
    t.prism_y("paint", bot_xz, 1.56, 2.28, top_xz=top_xz, bevel=bev, seg=1,
              tint=(1.0, 1.0, 0.99), ao_y=(1.56, 2.28, 0.80))
    t.box("dark", (-0.26, 1.62, 0.92), (0.26, 2.24, 1.54))

    # Dor-Dalet overhanging sloped composite cheek armor + 3 bolted side modules per flank (no Trophy!)
    for sx in (-1, 1):
        pts_wedge = [
            (sx * 0.25, 2.28, 1.05),
            (sx * 1.16, 2.28, 0.22),
            (sx * 1.50, 1.84, 0.44),
            (sx * 1.38, 1.56, 0.34),
            (sx * 0.25, 1.58, 1.48),
            (sx * 0.25, 1.88, 1.84),
            (sx * 0.84, 1.84, 1.26),
        ]
        t.hull("paint", pts_wedge, bevel=bev, seg=1, tint=(1.03, 1.03, 1.01))

        # 3 distinct bolted Dor-Dalet flank modules (`z = +0.20 .. -1.42`)
        for idx, (zf, zr) in enumerate(((0.22, -0.32), (-0.35, -0.89), (-0.92, -1.46))):
            xo = 1.52 - idx * 0.02
            xi = xo - 0.14
            x0, x1 = (xi, xo) if sx > 0 else (-xo, -xi)
            tk = 1.02 if idx % 2 == 0 else 0.98
            t.box("paint", (x0, 1.72, zr), (x1, 2.24, zf), bevel=0.016, tint=(tk, tk, tk * 0.99))
            if not lod:
                for bz in (zr + 0.12, zf - 0.12):
                    t.pipe("metal_dark", (sx * xo, 2.02, bz), (sx * (xo + 0.022), 2.02, bz), 0.022, seg=6)

        add_idf_chevron_x(t, sx * 1.532, 1.96, -0.62, sx, arm_len=0.16, thick=0.038, mode="down")

    # Roof-flush Mk 3 rear turret stowage basket (`z = -2.05 .. -2.80`) + ball-and-chain curtain
    t.box("paint", (-1.16, 1.84, -2.80), (1.16, 1.92, -2.04), bevel=0.012)
    if not lod:
        for ry in (2.06, 2.24):
            t.pipe("metal_dark", (-1.18, ry, -2.80), (1.18, ry, -2.80), 0.016, seg=6)
            for sx in (-1, 1):
                t.pipe("metal_dark", (sx * 1.18, ry, -2.80), (sx * 1.18, ry, -2.04), 0.016, seg=6)
        for rx in (-1.18, -0.78, -0.39, 0.0, 0.39, 0.78, 1.18):
            t.pipe("metal_dark", (rx, 1.88, -2.80), (rx, 2.25, -2.80), 0.014, seg=6)
        t.pipe("canvas", (-0.84, 2.08, -2.44), (0.56, 2.08, -2.44), 0.125, seg=10, bevel=0.03, tint=(0.92, 0.90, 0.82))

    _add_ball_and_chain_curtain(t, lod, z_bar=-2.78, x_half=1.14, y_top=1.86, y_bot=1.48, n_chains=14)
    return t


def build_merkava_gun(lod, gp, mk4=True):
    """IMI 120 mm MG253 / MG251 smoothbore in quilted Israeli thermal sleeve + signature mantlet-mounted .50 cal M2HB!"""
    g = Part("Gun", seed=61)
    gx, gy, gz = gp
    seg = 8 if lod else 20

    # Compact narrow Merkava mantlet rotor + ribbed canvas dust boot
    g.box("paint", (gx - 0.25, gy - 0.20, gz - 0.16), (gx + 0.25, gy + 0.22, gz + 0.44), bevel=0.022)
    g.box("canvas", (gx - 0.265, gy - 0.215, gz + 0.20), (gx + 0.265, gy + 0.235, gz + 0.38), bevel=0.028, tint=(0.86, 0.84, 0.76))

    # Signature IDF .50 cal M2HB heavy machine gun mounted directly ABOVE the main gun mantlet (fires coaxially for training/urban!)
    if not lod:
        my = gy + 0.30
        g.box("metal_dark", (gx - 0.03, gy + 0.20, gz + 0.18), (gx + 0.03, my, gz + 0.36))
        g.box("metal_dark", (gx - 0.068, my - 0.05, gz + 0.02), (gx + 0.068, my + 0.09, gz + 0.48), bevel=0.01, tint=(0.60, 0.60, 0.64))
        g.pipe("metal_dark", (gx, my + 0.02, gz + 0.48), (gx, my + 0.02, gz + 0.74), 0.030, seg=10)
        g.pipe("metal_dark", (gx, my + 0.02, gz + 0.74), (gx, my + 0.02, gz + 1.26), 0.018, seg=8)
        g.box("paint", (gx + 0.08, my - 0.04, gz + 0.12), (gx + 0.24, my + 0.14, gz + 0.36), bevel=0.01, tint=(0.82, 0.85, 0.75))

    # 120 mm barrel in distinctive Israeli multi-band thermal jacket (`gz + 0.42 .. gz + 4.42`)
    g.pipe("paint", (gx, gy, gz + 0.42), (gx, gy, gz + 1.56), 0.118, seg=seg, r2=0.106, tint=(0.98, 0.98, 0.96))
    # Concentric fluted Israeli fume extractor / bore evacuator
    g.pipe("paint", (gx, gy, gz + 1.54), (gx, gy, gz + 1.68), 0.108, seg=seg, r2=0.156, tint=(1.02, 1.02, 1.0))
    g.pipe("paint", (gx, gy, gz + 1.68), (gx, gy, gz + 2.30), 0.156, seg=seg, tint=(1.02, 1.02, 1.0))
    g.pipe("paint", (gx, gy, gz + 2.30), (gx, gy, gz + 2.44), 0.156, seg=seg, r2=0.100, tint=(1.02, 1.02, 1.0))
    # Forward quilted thermal sleeve
    g.pipe("paint", (gx, gy, gz + 2.42), (gx, gy, gz + 4.28), 0.098, seg=seg, r2=0.090, tint=(0.98, 0.98, 0.96))

    if not lod:
        for bz in (0.72, 1.08, 1.42, 2.74, 3.16, 3.58, 3.98):
            g.pipe("metal_dark", (gx, gy, gz + bz - 0.020), (gx, gy, gz + bz + 0.020), 0.108 if bz < 1.5 else 0.098, seg=seg)

    # Hollow 120 mm muzzle + MRS reference sensor
    g.tube_axis("metal_dark", (gx, gy, gz + 4.26), (gx, gy, gz + 4.42), 0.094, 0.060, seg=seg, tint=(0.68, 0.68, 0.72))
    g.cyl("dark", (gx, gy, gz + 4.25), 0.061, 0.02, seg=12)
    if not lod:
        g.box("metal_dark", (gx - 0.022, gy + 0.085, gz + 4.30), (gx + 0.022, gy + 0.165, gz + 4.39), bevel=0.005)
    return g


def build_coaps_sight(lod, pos, mk4=True):
    """Commander's Panoramic Sight (COAPS on Mk 4 / Baz commander sight on Mk 3)."""
    p = Part("CITV")
    cx, cy, cz = pos
    seg = 8 if lod else 14
    p.cyl("paint", (cx, cy - 0.02, cz), 0.18, 0.16, seg=seg, bevel=0.01)
    p.box("paint", (cx - 0.19, cy + 0.14, cz - 0.18), (cx + 0.19, cy + 0.39, cz + 0.19), bevel=0.022, tint=(1.02, 1.02, 1.0))
    p.box("dark", (cx - 0.14, cy + 0.18, cz + 0.16), (cx + 0.14, cy + 0.34, cz + 0.196))
    p.box("glass", (cx - 0.12, cy + 0.20, cz + 0.185), (cx + 0.12, cy + 0.32, cz + 0.204), tint=OPTIC_FLIR)
    return p


def build_baz_gunner_sight(lod, pos):
    """Armoured Gunner's Sight doghouse."""
    p = Part("Gunner_Sight")
    cx, cy, cz = pos
    p.box("paint", (cx - 0.21, cy - 0.02, cz - 0.22), (cx + 0.21, cy + 0.21, cz + 0.22), bevel=0.02)
    p.box("dark", (cx - 0.16, cy + 0.03, cz + 0.19), (cx + 0.16, cy + 0.17, cz + 0.226))
    p.box("glass", (cx - 0.13, cy + 0.05, cz + 0.212), (cx + 0.13, cy + 0.15, cz + 0.232), tint=OPTIC_COOL)
    return p


def build_roof_hatch_mg(name, lod, pos, with_mg=True):
    """Low-profile Merkava thick composite hatch + pintle-mounted 7.62 mm FN MAG machine gun."""
    p = Part(name)
    cx, cy, cz = pos
    p.cyl("paint", (cx, cy - 0.01, cz), 0.29, 0.085, seg=8 if lod else 14, bevel=0.014, tint=(1.02, 1.02, 1.0))
    if with_mg and not lod:
        mx, my, mz = cx, cy + 0.22, cz + 0.24
        p.pipe("metal_dark", (mx, cy + 0.06, mz - 0.04), (mx, my, mz), 0.022, seg=6)
        p.box("metal_dark", (mx - 0.04, my - 0.03, mz - 0.18), (mx + 0.04, my + 0.06, mz + 0.16), bevel=0.008)
        p.pipe("metal_dark", (mx, my + 0.02, mz + 0.16), (mx, my + 0.02, mz + 0.62), 0.015, seg=8)
        p.box("paint", (mx - 0.16, my - 0.05, mz - 0.06), (mx - 0.05, my + 0.07, mz + 0.10), bevel=0.008, tint=(0.80, 0.84, 0.72))
    return p


def build_imi_smoke(lod, side, y_base):
    """IMI CL-3030 6-tube instantaneous smoke grenade launcher flush-clustered on turret cheek."""
    p = Part(f"Smoke_{side}")
    sx = side
    bx, by, bz = sx * 1.32, y_base, 0.42
    p.box("paint", (bx - 0.08, by - 0.06, bz - 0.15), (bx + 0.08, by + 0.08, bz + 0.15), yaw=-sx * 0.35, bevel=0.012)
    if not lod:
        for k in range(6):
            dz = -0.10 + k * 0.04
            out_k = 0.22 + 0.06 * abs(k - 2.5)
            up_k = 0.34
            fwd_k = 0.88
            nrm = math.sqrt(out_k * out_k + up_k * up_k + fwd_k * fwd_k)
            dx_, dy_, dz_ = sx * out_k / nrm, up_k / nrm, fwd_k / nrm
            a = (bx + sx * 0.02, by + 0.04, bz + dz)
            b = (a[0] + dx_ * 0.20, a[1] + dy_ * 0.20, a[2] + dz_ * 0.20)
            p.pipe("metal_dark", a, b, 0.032, seg=8)
    return p


def build_antenna(lod, idx, pos):
    p = Part(f"Antenna_{idx}")
    ax, ay, az = pos
    p.cyl("metal_dark", (ax, ay - 0.01, az), 0.042, 0.13, seg=6 if lod else 10)
    p.pipe("metal_dark", (ax, ay + 0.12, az), (ax + (0.04 if ax > 0 else -0.04), ay + 1.48, az - 0.08),
           0.012, seg=4 if lod else 6, r2=0.004, tint=(0.42, 0.42, 0.45))
    return p


def build_merkava_rig(lod=0, variant="merkava_mk_4"):
    mk4 = variant == "merkava_mk_4"
    rig = VehicleRig(lod=lod)
    deck_y = 1.56 if mk4 else 1.52
    roof_y = 2.43 if mk4 else 2.28

    rig.add("Hull", rig.root_name, (0.0, 0.0, 0.0), build_merkava_hull(lod, mk4=mk4))

    ring = Part("Turret_Ring")
    ring.cyl("metal_dark", (0.0, deck_y - 0.02, -0.35), 1.08, 0.08, seg=14 if lod else 28, tint=(0.48, 0.48, 0.50))
    rig.add("Turret_Ring", "Hull", (0.0, deck_y + 0.02, -0.35), ring)

    turret_pivot = (0.0, deck_y + 0.02, -0.35)
    rig.add("Turret", "Hull", turret_pivot, build_mk4_turret(lod) if mk4 else build_mk3_baz_turret(lod))

    gun_pivot = (0.0, 1.98 if mk4 else 1.92, 0.88)
    rig.add("Gun", "Turret", gun_pivot, build_merkava_gun(lod, gun_pivot, mk4=mk4))
    rig.add("Muzzle", "Gun", (0.0, gun_pivot[1], gun_pivot[2] + 4.42), None)

    # Crew hatches, COAPS / Baz optics, smoke & IDF twin rear basket antennas
    rig.add("Hatch_Commander", "Turret", (0.54, roof_y, -0.82), build_roof_hatch_mg("Hatch_Commander", lod, (0.54, roof_y, -0.82), with_mg=True))
    rig.add("Hatch_Loader", "Turret", (-0.54, roof_y, -0.96), build_roof_hatch_mg("Hatch_Loader", lod, (-0.54, roof_y, -0.96), with_mg=not mk4))
    if mk4:
        rig.add("CITV", "Turret", (0.58, roof_y, -0.22), build_coaps_sight(lod, (0.58, roof_y, -0.22), mk4=True))
        rig.add("Gunner_Sight", "Turret", (-0.58, roof_y - 0.04, 0.14), build_baz_gunner_sight(lod, (-0.58, roof_y - 0.04, 0.14)))
    else:
        rig.add("CITV", "Turret", (0.52, roof_y, -0.26), build_coaps_sight(lod, (0.52, roof_y, -0.26), mk4=False))
        rig.add("Gunner_Sight", "Turret", (-0.64, roof_y, 0.24), build_baz_gunner_sight(lod, (-0.64, roof_y, 0.24)))

    for label, side in (("L", -1), ("R", 1)):
        rig.add(f"Smoke_Launcher_{label}", "Turret", (side * 1.32, roof_y - 0.22, 0.42), build_imi_smoke(lod, side, roof_y - 0.22))

    rig.add("Antenna_1", "Turret", (-1.12, roof_y - 0.08, -2.02), build_antenna(lod, 1, (-1.12, roof_y - 0.08, -2.02)))
    rig.add("Antenna_2", "Turret", (1.12, roof_y - 0.08, -2.02), build_antenna(lod, 2, (1.12, roof_y - 0.08, -2.02)))

    # Front-Engine Running Gear: 6 Road Wheels, FRONT Sprocket (+Z), REAR Idler (-Z), 3 Return Rollers & Scaled 3D Track Loop!
    k = TRACK_SCALE
    for label, side in (("L", -1), ("R", 1)):
        wx = side * TRACK_X
        for i, wz in enumerate(WHEEL_ZS):
            wp = (wx, 0.49, wz * k)
            rig.add(f"Wheel_{label}{i}", "Hull", wp, build_merkava_wheel(wp, lod, side))

        sp_piv = (wx, 0.65 * k, 3.23 * k)   # FRONT drive sprocket!
        rig.add(f"Sprocket_{label}", "Hull", sp_piv, build_front_sprocket(sp_piv, lod, side))

        id_piv = (wx, 0.65 * k, -3.23 * k)  # REAR idler!
        rig.add(f"Idler_{label}", "Hull", id_piv, build_rear_idler(id_piv, lod, side))

        for i, rz in enumerate((-1.75 * k, 0.0, 1.75 * k)):
            rp = (wx, 1.02 * k, rz)
            rig.add(f"Roller_{label}{i}", "Hull", rp, build_roller(rp, lod, side))

        trk = Part(f"Track_{label}")
        trk.build_track(wx, lod=lod, width=0.66)
        rig.add(f"Track_{label}", "Hull", (wx, 0.0, 0.0), trk, mesh_scale=(1.0, k, k))

    rig.add("Exhaust", "Hull", (1.86, 1.38, 2.02), None)
    rig.add("Engine_Deck", "Hull", (0.45, deck_y + 0.08, 2.15), None)
    return rig


MERKAVA_VARIANTS = ("merkava_mk_4", "merkava_mk_3_baz")


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    veh_dir = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../godot/assets/art/vehicles"))
    os.makedirs(veh_dir, exist_ok=True)
    targets = MERKAVA_VARIANTS if ("--all" in argv or not argv) else [v for v in argv if not v.startswith("-")]
    for var in targets:
        init_scene()
        out_p = os.path.join(veh_dir, f"tank__{var}.glb")
        export_vehicle(out_p, build_merkava_rig(0, var), build_merkava_rig(1, var))
