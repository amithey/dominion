"""U.S. M1A2 SEPv3 Abrams Main Battle Tank, modelled in Blender.

Run:
    blender -b -P native/tools/models/blender/build_abrams.py -- native/godot/assets/art/vehicles/tank__m1a2_sepv3_abrams.glb

Produces the complete articulated glTF vehicle (`LOD0`, `LOD1`, `Wreck`) in real metres (+Y up, +Z front):
  - Split-cheek NGAP composite wedge turret with deep recessed mantlet slot, undercut cheeks, 3 roof blowout panels,
    side bustle racks with louvered CIP panels, jerrycans, spare track shoes, and canvas stowage rolls in the rear basket.
  - Body-painted 120 mm M256 L/44 smoothbore in CARC thermal shroud, eccentric bore evacuator, clamping bands, MRS sensor,
    coaxial M240 port, and recessed hollow muzzle.
  - CITV panoramic thermal sight, GPS armoured doghouse with ballistic shutter doors, octagonal 8-periscope commander's cupola,
    SEPv3 CROWS-LP remote weapon station with M2HB .50 cal & EO/IR pod, loader's skate-mounted M240 with gun shield,
    splayed 6-tube M250 smoke launchers, SINCGARS whip aerials & Counter-RCIED mast.
  - Sloped glacis with non-slip walkway pads, 3-periscope driver's alcove, welded headlight brush-guards, forged tow shackles,
    dark inner suspension tub with torsion swing-arms, 7 hinged ballistic/steel side skirt modules per side, AGT1500 turbine
    intake grilles, and full louvered rear turbine exhaust & battery doors.
  - 14 sculpted dual road wheels, 2 toothed rear sprockets, 2 front idlers, 6 return rollers, and 3D T158 'Bigfoot' track links
    driven along the canonical shader loop.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_vehicle import Part, VehicleRig, init_scene, export_vehicle

DEFAULT_OUT = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../godot/assets/art/vehicles/tank__m1a2_sepv3_abrams.glb")
)
OUT_PATH = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else DEFAULT_OUT

WHEEL_ZS = [-2.46, -1.64, -0.82, 0.00, 0.82, 1.64, 2.46]
TRACK_X = 1.46

# Optical glass tints (multiplied with Color(0.06, 0.13, 0.17) in vehicle_models.gd)
OPTIC_FLIR = (2.2, 1.35, 0.55)      # warm amber/gold germanium FLIR coating
OPTIC_COOL = (0.85, 1.35, 1.45)     # emerald-cyan laser/day coating
TAIL_RED = (4.5, 0.35, 0.25)        # deep ruby tail-light lens


def add_chevron_x(part, x_plane, cy, cz, sx_out, arm_len=0.20, thick=0.048, point_dir=1.0):
    """Crisp NATO company tactical chevron ('>' pointing forward along +Z) flush on a side plate at `x_plane`."""
    tip_z = cz + point_dir * arm_len * 0.65
    back_z = cz - point_dir * arm_len * 0.55
    out = (sx_out, 0.0, 0.0)
    # Upper arm of chevron
    part.decal_quad(
        "markings",
        (x_plane, cy, tip_z),
        (x_plane, cy, tip_z - point_dir * thick * 1.25),
        (x_plane, cy + arm_len * 0.72, back_z - point_dir * thick * 0.4),
        (x_plane, cy + arm_len * 0.72, back_z + point_dir * thick * 0.85),
        outward=out,
    )
    # Lower arm of chevron
    part.decal_quad(
        "markings",
        (x_plane, cy, tip_z - point_dir * thick * 1.25),
        (x_plane, cy, tip_z),
        (x_plane, cy - arm_len * 0.72, back_z + point_dir * thick * 0.85),
        (x_plane, cy - arm_len * 0.72, back_z - point_dir * thick * 0.4),
        outward=out,
    )


def build_road_wheel(wp, lod, side):
    """Paired dual M1 Abrams road wheel centered at `wp`, revolving around X."""
    p = Part(f"Wheel_{side}")
    r = 0.335
    with p.frame(wp):
        if lod:
            prof = [
                (-0.22, 0.0, "paint", 0.78),
                (-0.22, r, "rubber", 1.0),
                (0.22, r, "paint", 0.85),
                (0.22, 0.0, "paint", 0.85),
            ]
            p.lathe_x((0, 0, 0), prof, seg=8)
            return p

        s = side
        prof_inner_to_outer = [
            (-0.235, 0.0, "metal_dark", 0.45),
            (-0.235, 0.235, "paint", 0.72),
            (-0.225, 0.255, "rubber", 0.92),
            (-0.225, r, "rubber", 1.0),
            (-0.045, r, "metal_dark", 0.40),
            (-0.040, 0.225, "metal_dark", 0.35),   # central slot for track guide horn
            (0.040, 0.225, "rubber", 0.92),
            (0.045, r, "rubber", 1.0),
            (0.225, r, "paint", 0.95),
            (0.225, 0.265, "paint", 0.82),          # outer rim lip
            (0.185, 0.235, "paint", 0.76),          # recessed wheel dish
            (0.195, 0.125, "paint", 0.92),
            (0.195, 0.0, "paint", 0.92),
        ]
        if s < 0:
            prof = []
            for i in range(len(prof_inner_to_outer) - 1, -1, -1):
                x_cur, r_cur, _, _ = prof_inner_to_outer[i]
                role_prev = prof_inner_to_outer[i - 1][2] if i > 0 else "paint"
                k_prev = prof_inner_to_outer[i - 1][3] if i > 0 else 0.9
                prof.append((-x_cur, r_cur, role_prev, k_prev))
            p.lathe_x((0, 0, 0), prof, seg=18)
        else:
            p.lathe_x((0, 0, 0), prof_inner_to_outer, seg=18)

        # Central oil-lubricated hub cap + centre plug + 10 perimeter wheel bolts
        p.pipe("paint", (s * 0.185, 0, 0), (s * 0.242, 0, 0), 0.105, seg=14, r2=0.088, bevel=0.008, tint=(0.94, 0.94, 0.92))
        p.pipe("metal_dark", (s * 0.240, 0, 0), (s * 0.254, 0, 0), 0.042, seg=10, tint=(0.55, 0.55, 0.58))
        for k in range(10):
            a = math.tau * k / 10.0
            by, bz = 0.198 * math.cos(a), 0.198 * math.sin(a)
            p.pipe("metal_dark", (s * 0.188, by, bz), (s * 0.212, by, bz), 0.014, seg=6, tint=(0.62, 0.62, 0.65))
    return p


def build_sprocket(wp, lod, side):
    """Rear drive sprocket with planetary final-drive drum, mud-relief ring, and 11 bevelled steel teeth."""
    p = Part(f"Sprocket_{side}")
    s = side
    n_seg = 10 if lod else 20
    with p.frame(wp):
        prof = [
            (-0.23, 0.0, "metal_dark", 0.55),
            (-0.23, 0.435, "paint", 0.78),
            (-0.17, 0.445, "metal_dark", 0.45),
            (-0.15, 0.34, "metal_dark", 0.40),
            (0.15, 0.34, "paint", 0.85),
            (0.17, 0.445, "paint", 0.90),
            (0.23, 0.435, "paint", 0.88),
            (0.23, 0.0, "paint", 0.88),
        ]
        p.lathe_x((0, 0, 0), prof, seg=n_seg)
        p.pipe("paint", (s * 0.12, 0, 0), (s * 0.265, 0, 0), 0.21, seg=n_seg, r2=0.175, bevel=0.012, tint=(0.90, 0.90, 0.88))
        if not lod:
            for k in range(12):
                a = math.tau * k / 12.0
                p.pipe("metal_dark", (s * 0.262, 0.135 * math.cos(a), 0.135 * math.sin(a)),
                       (s * 0.278, 0.135 * math.cos(a), 0.135 * math.sin(a)), 0.013, seg=6)
            for tx in (-0.195, 0.195):
                for k in range(11):
                    a = math.tau * k / 11.0
                    with p.frame((tx, 0, 0), pitch=a):
                        p.box("metal", (-0.022, 0.415, -0.048), (0.022, 0.515, 0.048), bevel=0.008, tint=(1.05, 1.05, 1.08))
    return p


def build_idler(wp, lod, side):
    """Front track-tensioning idler wheel with sculpted dished face, dark steel outer rim & bolt ring."""
    p = Part(f"Idler_{side}")
    s = side
    n_seg = 8 if lod else 16
    with p.frame(wp):
        prof_r = [
            (-0.21, 0.0, "metal_dark", 0.50),
            (-0.21, 0.425, "metal", 0.90),
            (-0.06, 0.425, "metal_dark", 0.40),
            (-0.04, 0.29, "metal_dark", 0.40),
            (0.04, 0.29, "metal_dark", 0.75),
            (0.06, 0.425, "metal", 0.92),
            (0.21, 0.425, "paint", 0.88),
            (0.21, 0.365, "paint", 0.76),
            (0.165, 0.325, "paint", 0.74),
            (0.175, 0.14, "paint", 0.90),
            (0.175, 0.0, "paint", 0.90),
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
        p.pipe("paint", (s * 0.16, 0, 0), (s * 0.235, 0, 0), 0.125, seg=12, r2=0.098, bevel=0.008, tint=(0.94, 0.94, 0.92))
        if not lod:
            for k in range(8):
                a = math.tau * k / 8.0
                p.pipe("metal_dark", (s * 0.165, 0.235 * math.cos(a), 0.235 * math.sin(a)),
                       (s * 0.188, 0.235 * math.cos(a), 0.235 * math.sin(a)), 0.020, seg=6)
    return p


def build_roller(wp, lod, side):
    """Track return roller."""
    if lod:
        return None
    p = Part(f"Roller_{side}")
    with p.frame(wp):
        for dx in (-0.11, 0.11):
            p.pipe("rubber", (dx - 0.045, 0, 0), (dx + 0.045, 0, 0), 0.115, seg=12)
            p.pipe("paint", (dx - 0.05, 0, 0), (dx + 0.05, 0, 0), 0.068, seg=10, tint=(0.86, 0.86, 0.85))
        p.pipe("metal_dark", (-0.18, 0, 0), (0.18, 0, 0), 0.036, seg=8)
    return p


def build_hull(lod):
    """M1A2 SEPv3 hull: low-angle glacis, NGAP lower bow, inner dark wheel tub, 7 skirt modules/side, AGT1500 deck & louvered rear."""
    h = Part("Hull", seed=17)
    bev = 0.012 if lod else 0.026

    # 1. Main armoured hull tub (side profile extruded across X = -1.14 .. +1.14)
    #    Low-angle Abrams upper glacis: nose tip (z=+3.86, y=1.04) -> glacis break (z=+1.82, y=1.45) -> engine deck (z=-3.88, y=1.45)
    hull_yz = [
        (0.45, 3.22),    # forward belly pan break
        (0.96, 3.88),    # NGAP lower front bow lip
        (1.07, 3.84),    # nose weld seam
        (1.45, 1.82),    # upper glacis top / turret deck front
        (1.45, -1.65),   # turret ring deck rear
        (1.47, -3.78),   # raised AGT1500 engine deck
        (1.36, -3.94),   # rear upper bevel
        (0.56, -3.90),   # rear lower hull plate
        (0.45, -3.45),   # rear belly pan
    ]
    h.prism_x("paint", hull_yz, -1.14, 1.14, bevel=bev, seg=1, tint=(1.0, 1.0, 1.0), ao_y=(0.45, 1.35, 0.68))

    # 2. Deep dark inner suspension walls behind wheels (prevents sky/grass peeking behind running gear!)
    for sx in (-1, 1):
        h.box("dark", (sx * 1.14 - 0.03, 0.46, -3.45), (sx * 1.14 + 0.03, 1.36, 3.35))
        if not lod:
            # Torsion-bar swing arms angling back-and-down from hull tub to each road-wheel station
            for wz in WHEEL_ZS:
                h.pipe("metal_dark", (sx * 1.13, 0.56, wz + 0.24), (sx * 1.42, 0.45, wz), 0.052, seg=8, tint=(0.50, 0.50, 0.52))

    # 3. Upper track sponsons / fender decks (x = +-1.12 .. +-1.77) + sculpted sloped front fenders
    for sx in (-1, 1):
        x_in, x_out = (1.12, 1.77) if sx > 0 else (-1.77, -1.12)
        sponson_yz = [
            (1.34, -3.90),
            (1.44, -3.86),
            (1.45, 3.25),
            (1.18, 3.92),
            (1.06, 3.90),
            (1.32, 3.18),
        ]
        h.prism_x("paint", sponson_yz, x_in, x_out, bevel=0.016, seg=1, tint=(0.98, 0.98, 0.97))
        # Front spring-mounted rubber mudflap lip & rear heavy rubber mudflap
        h.box("rubber", (min(x_in, x_out) + 0.02, 0.88, 3.88), (max(x_in, x_out) - 0.02, 1.10, 3.93), bevel=0.008)
        h.box("rubber", (min(x_in, x_out) + 0.02, 0.50, -3.95), (max(x_in, x_out) - 0.02, 1.32, -3.89), bevel=0.008)

    # 4. Non-slip anti-skid CARC walkway zones on upper glacis & sponsons (subtle darker matte tone!)
    if not lod:
        for sx in (-1, 1):
            with h.frame((sx * 0.72, 1.27, 2.75), pitch=math.atan2(1.45 - 1.07, 3.84 - 1.82)):
                h.box("paint", (-0.28, -0.006, -0.68), (0.28, 0.012, 0.68), tint=(0.82, 0.81, 0.78))
            h.box("paint", (sx * 1.44 - 0.22, 1.448, 0.20), (sx * 1.44 + 0.22, 1.462, 2.70), tint=(0.83, 0.82, 0.79))

    # 5. SEPv3 Heavy Ballistic Side Skirts (7 distinct hinged modules per side!)
    #    Modules 0..3 (front-to-mid): thick heavy NGAP composite armour blocks (0.13 m thick)
    #    Modules 4..6 (rear): thinner steel engine-bay skirts with angled sprocket mud-relief cutout on #6
    skirt_edges = [3.32, 2.28, 1.24, 0.20, -0.84, -1.84, -2.82, -3.76]
    for sx in (-1, 1):
        # Dark backing shadow strip along sponson edge so vertical module seams read razor-sharp
        h.box("dark", (sx * 1.74 - 0.02, 0.92, -3.65), (sx * 1.74 + 0.02, 1.43, 3.25))
        for idx in range(7):
            zf = skirt_edges[idx] - 0.016
            zr = skirt_edges[idx + 1] + 0.016
            heavy = idx < 4
            thick = 0.125 if heavy else 0.065
            xo = 1.83 if heavy else 1.795
            xi = xo - thick
            x0, x1 = (xi, xo) if sx > 0 else (-xo, -xi)

            if idx == 0:
                # Front ballistic skirt module with sloped lower front corner clearing the idler
                yz = [(0.92, zf), (1.44, zf), (1.44, zr), (0.68, zr), (0.68, zf - 0.42)]
                h.prism_x("paint", yz, x0, x1, bevel=0.018, seg=1, tint=(1.02, 1.02, 1.0), ao_y=(0.68, 1.44, 0.82))
            elif idx == 6:
                # Rear sprocket skirt with high angled mud-relief cutout exposing the toothed drive sprocket
                yz = [(0.74, zf), (1.44, zf), (1.44, zr), (1.16, zr), (0.98, zr + 0.45)]
                h.prism_x("paint", yz, x0, x1, bevel=0.014, seg=1, tint=(0.97, 0.97, 0.96), ao_y=(0.74, 1.44, 0.84))
            else:
                y_bot = 0.68 if heavy else 0.74
                tint_k = 1.01 if idx % 2 == 0 else 0.97   # subtle per-panel CARC replacement variation!
                h.box("paint", (x0, y_bot, zr), (x1, 1.44, zf), bevel=0.018 if heavy else 0.012, seg=1,
                      tint=(tint_k, tint_k, tint_k * 0.99), ao_y=(y_bot, 1.44, 0.82))

            if not lod:
                # Upper hinge barrels + recessed crew step / lifting lug hardware
                zc = (zf + zr) * 0.5
                for dz in (-0.30, 0.30):
                    h.pipe("metal_dark", (sx * xo, 1.39, zc + dz - 0.05), (sx * xo, 1.39, zc + dz + 0.05), 0.020, seg=6)
                if heavy:
                    h.box("metal_dark", (sx * (xo - 0.005) - 0.012, 0.82, zc - 0.07), (sx * (xo + 0.010) + 0.012, 0.86, zc + 0.07))

    # 6. Driver's Centre Hatch & 3 Splayed Armoured Periscopes (`z ~ +2.15..2.55`)
    glacis_pitch = -math.atan2(1.45 - 1.07, 3.84 - 1.82)
    with h.frame((0.0, 1.34, 2.30), pitch=glacis_pitch):
        h.box("paint", (-0.34, -0.02, -0.36), (0.34, 0.065, 0.36), bevel=0.02, tint=(1.03, 1.03, 1.01))
        for px, yaw_p in ((-0.20, 0.32), (0.0, 0.0), (0.20, -0.32)):
            with h.frame((px, 0.055, 0.24), yaw=yaw_p):
                h.box("paint", (-0.085, 0.0, -0.09), (0.085, 0.085, 0.08), bevel=0.01, tint=(0.92, 0.92, 0.90))
                h.box("glass", (-0.068, 0.018, 0.068), (0.068, 0.068, 0.086), tint=OPTIC_COOL)

    # 7. Front Lower Bow Details: SEPv3 Tow Shackles + Welded Headlight Brush-Guards + Pioneer Tools
    for sx in (-1, 1):
        # Forged front tow lug & hanging D-shackle on lower glacis nose
        h.box("metal_dark", (sx * 0.82 - 0.045, 0.86, 3.82), (sx * 0.82 + 0.045, 1.02, 3.98), bevel=0.01)
        if not lod:
            h.pipe("metal", (sx * 0.82 - 0.07, 0.90, 3.95), (sx * 0.82 + 0.07, 0.90, 3.95), 0.024, seg=8)
            h.pipe("metal", (sx * 0.82 - 0.055, 0.90, 3.95), (sx * 0.82, 0.78, 4.02), 0.020, seg=6)
            h.pipe("metal", (sx * 0.82 + 0.055, 0.90, 3.95), (sx * 0.82, 0.78, 4.02), 0.020, seg=6)

        # Armoured rectangular headlight housing + welded brush-guard bars (`x = +-1.02, z = 3.68`)
        hx = sx * 0.98
        h.box("dark", (hx - 0.14, 1.12, 3.58), (hx + 0.14, 1.30, 3.76))
        h.box("paint", (hx - 0.16, 1.29, 3.54), (hx + 0.16, 1.325, 3.81), bevel=0.008)
        h.box("paint", (hx - 0.16, 1.11, 3.54), (hx - 0.13, 1.32, 3.80), bevel=0.006)
        h.box("paint", (hx + 0.13, 1.11, 3.54), (hx + 0.16, 1.32, 3.80), bevel=0.006)
        # Main headlamp + IR blackout lamp inside cage
        h.pipe("glass", (hx - 0.055, 1.20, 3.73), (hx - 0.055, 1.20, 3.77), 0.052, seg=10, tint=(2.2, 2.1, 1.8))
        h.pipe("metal_dark", (hx + 0.065, 1.20, 3.72), (hx + 0.065, 1.20, 3.77), 0.038, seg=8)
        if not lod:
            h.pipe("metal_dark", (hx - 0.15, 1.21, 3.81), (hx + 0.15, 1.21, 3.81), 0.010, seg=6)

    # Pioneer tools strapped to left sponson deck
    if not lod:
        h.pipe("wood", (-1.42, 1.47, 1.20), (-1.42, 1.47, 2.25), 0.018, seg=6)
        h.box("metal_dark", (-1.49, 1.46, 2.24), (-1.35, 1.485, 2.44), bevel=0.005)
        h.pipe("wood", (1.42, 1.47, 1.40), (1.42, 1.47, 2.30), 0.016, seg=6)
        h.box("metal", (1.34, 1.46, 2.26), (1.50, 1.49, 2.36), bevel=0.005)

    # 8. AGT1500 Gas Turbine Engine Deck (`z = -1.75 .. -3.78`)
    #    Twin recessed black intake plenums with individual transverse steel louver slats + central access doors + fuel caps
    for sx in (-1, 1):
        gx0, gx1 = (0.16, 0.98) if sx > 0 else (-0.98, -0.16)
        # Forward & aft intake grilles
        for gz0, gz1, n_slats in ((-2.82, -1.96, 9), (-3.64, -2.96, 7)):
            h.box("dark", (gx0, 1.445, gz0), (gx1, 1.478, gz1))
            h.box("metal_dark", (gx0 - 0.025, 1.468, gz0 - 0.025), (gx1 + 0.025, 1.486, gz0), bevel=0.005)
            h.box("metal_dark", (gx0 - 0.025, 1.468, gz1), (gx1 + 0.025, 1.486, gz1 + 0.025), bevel=0.005)
            if not lod:
                for k in range(n_slats):
                    sz = gz0 + (k + 0.5) * (gz1 - gz0) / n_slats
                    h.box("metal_dark", (gx0 + 0.01, 1.472, sz - 0.018), (gx1 - 0.01, 1.490, sz + 0.018), tint=(0.72, 0.72, 0.74))
        # Raised engine deck side retaining curbs + armoured fuel caps
        h.box("paint", (sx * 1.06 - 0.045, 1.46, -3.72), (sx * 1.06 + 0.045, 1.535, -1.85), bevel=0.012, tint=(1.03, 1.03, 1.01))
        if not lod:
            h.cyl("paint", (sx * 1.32, 1.45, -3.35), 0.095, 0.032, seg=12, bevel=0.006, tint=(0.90, 0.90, 0.88))
    # Central spine access cover & SEPv3 left-rear Under-Armour APU exhaust port
    h.box("paint", (-0.13, 1.465, -3.68), (0.13, 1.505, -1.92), bevel=0.012, tint=(1.04, 1.04, 1.02))
    h.box("metal_dark", (-1.38, 1.45, -3.74), (-1.14, 1.54, -3.48), bevel=0.012, tint=(0.65, 0.63, 0.60))

    # 9. Iconic Abrams Rear Hull Plate (`z = -3.94`):
    #    Central AGT1500 hot-gas louvered exhaust grille + left/right hinged battery access doors + oval tail-lights + tow pintle
    # Central turbine exhaust housing
    h.box("metal_dark", (-0.56, 0.78, -3.98), (0.56, 1.34, -3.86), bevel=0.016, tint=(0.55, 0.53, 0.50))
    h.box("dark", (-0.50, 0.83, -3.99), (0.50, 1.29, -3.93))
    if not lod:
        # Vertical centre divider + 6 angled horizontal turbine deflector louvers (soot-darkened!)
        h.box("metal_dark", (-0.02, 0.83, -4.00), (0.02, 1.29, -3.93), tint=(0.45, 0.43, 0.40))
        for k in range(6):
            ly = 0.87 + k * 0.072
            h.box("metal_dark", (-0.49, ly - 0.012, -4.00), (0.49, ly + 0.016, -3.93), pitch=0.35, tint=(0.42, 0.40, 0.38))
    # Central lower NATO towing pintle hook
    h.box("metal_dark", (-0.10, 0.60, -4.01), (0.10, 0.75, -3.88), bevel=0.012, tint=(0.65, 0.65, 0.68))

    # Left & Right hinged armoured battery/transmission doors + recessed tail-lights + rear tow shackles
    for sx in (-1, 1):
        dx0, dx1 = (0.60, 1.12) if sx > 0 else (-1.12, -0.60)
        h.box("paint", (dx0, 0.74, -3.97), (dx1, 1.35, -3.88), bevel=0.018, tint=(0.96, 0.96, 0.95))
        # Recessed armoured tail-light cluster
        tx = sx * 0.94
        h.box("metal_dark", (tx - 0.09, 1.14, -3.99), (tx + 0.09, 1.25, -3.94), bevel=0.008)
        h.box("glass", (tx - 0.065, 1.165, -3.995), (tx + 0.065, 1.225, -3.975), tint=TAIL_RED)
        if not lod:
            h.pipe("metal", (sx * 0.78, 0.66, -3.94), (sx * 0.78, 0.66, -4.03), 0.035, seg=8)

    # 10. Subtle tactical hull chevron on mid ballistic skirt #3
    for sx in (-1, 1):
        add_chevron_x(h, sx * 1.836, 1.07, -0.32, sx, arm_len=0.17, thick=0.042, point_dir=1.0)

    return h


def build_turret(lod, variant="m1a2_sepv3_abrams"):
    """Authentic Abrams wide wedge-faceted split-cheek turret, blowout roof, CIP panels & variant-specific bustle stowage."""
    t = Part("Turret", seed=23)
    bev = 0.016 if lod else 0.032
    is_sepv3 = variant == "m1a2_sepv3_abrams"
    cheek_z = 2.04 if is_sepv3 else (1.98 if variant == "m1a2s_abrams" else 1.93)

    # Turret base sits at y = 1.48, roof at y = 2.25 (sleek, wide, predatory Abrams profile!)
    # 1. Core fighting compartment & long overhanging rear ammunition bustle (behind the mantlet slot)
    #    8-point planform from z = +1.15 (behind cheeks) back to z = -2.38 (bustle rear)
    core_bot = [
        (-0.40, 1.28), (0.40, 1.28),
        (1.62, 1.02), (1.58, -0.85),
        (1.36, -2.38), (-1.36, -2.38),
        (-1.58, -0.85), (-1.62, 1.02),
    ]
    core_top = [
        (-0.38, 1.05), (0.38, 1.05),
        (1.40, 0.72), (1.38, -0.88),
        (1.22, -2.30), (-1.22, -2.30),
        (-1.38, -0.88), (-1.40, 0.72),
    ]
    t.prism_y("paint", core_bot, 1.50, 2.25, top_xz=core_top, bevel=bev, seg=1,
              tint=(1.01, 1.01, 1.0), ao_y=(1.50, 2.25, 0.82))

    # Dark recessed central mantlet well (`x = -0.37 .. +0.37, z = 1.02 .. 1.58`) so the gun cradle nests cleanly!
    t.box("dark", (-0.37, 1.54, 1.00), (0.37, 2.21, 1.48))

    # 2. Left & Right Forward-Projecting Composite Turret Cheeks!
    for sx in (-1, 1):
        pts_cheek = [
            (sx * 0.37, 2.25, 1.05),
            (sx * 1.40, 2.25, 0.72),
            (sx * 1.32, 2.18, 1.12),
            (sx * 0.37, 2.20, 1.26),
            (sx * 0.37, 1.66, cheek_z),
            (sx * 0.92, 1.66, cheek_z - 0.06),
            (sx * 1.48, 1.68, cheek_z - 0.30),
            (sx * 1.62, 1.62, 1.02),
            (sx * 1.36, 1.49, 0.96),
            (sx * 0.37, 1.49, 1.24),
            (sx * 0.37, 1.55, cheek_z - 0.20),
            (sx * 1.22, 1.54, cheek_z - 0.46),
        ]
        t.hull("paint", pts_cheek, bevel=bev, seg=1, tint=(1.03, 1.03, 1.01), ao_y=(1.49, 2.25, 0.80))

        if not lod and is_sepv3:
            # SEPv3 cheek lifting lugs / tow eyes on upper cheek slope
            t.box("metal_dark", (sx * 0.96 - 0.025, 2.02, 1.44), (sx * 0.96 + 0.025, 2.11, 1.54), bevel=0.006)

    if variant in ("m1a1_abrams", "m1a1m_abrams") and not lod:
        # M1A1 bolted circular blanking plate where M1A2 CITV would sit
        t.cyl("paint", (-0.78, 2.248, 0.52), 0.22, 0.032, seg=12, bevel=0.006, tint=(0.94, 0.94, 0.92))

    # 3. Sloped Turret Roof Glacis Bridge & 3 Rear Blow-Out Ammunition Panels
    t.box("paint", (-0.37, 2.18, 0.95), (0.37, 2.255, 1.28), pitch=0.14, bevel=0.015, tint=(1.03, 1.03, 1.01))
    # Blowout panel dark perimeter recess + 3 armoured relief panels (`z = -1.05 .. -2.18`)
    t.box("dark", (-1.06, 2.242, -2.18), (1.06, 2.258, -1.02))
    for bx0, bx1 in ((-1.04, -0.36), (-0.33, 0.33), (0.36, 1.04)):
        t.box("paint", (bx0, 2.248, -2.16), (bx1, 2.282, -1.04), bevel=0.012, tint=(1.04, 1.04, 1.02))
        if not lod:
            cx = (bx0 + bx1) * 0.5
            t.box("paint", (bx0 + 0.06, 2.280, -1.63), (bx1 - 0.06, 2.294, -1.57), tint=(0.94, 0.94, 0.92))
            t.cyl("metal_dark", (cx, 2.28, -2.06), 0.028, 0.025, seg=8)

    # 4. Side Bustle Tubular Rails, Corrugated CIP Panels, NATO Jerrycans & Spare Track Shoes
    for sx in (-1, 1):
        # Forward flank armoured tool stowage box (`z = 0.05 .. 0.65`)
        bx0, bx1 = (1.46, 1.62) if sx > 0 else (-1.62, -1.46)
        t.box("paint", (bx0, 1.76, -0.05), (bx1, 2.10, 0.52), bevel=0.014, tint=(0.95, 0.95, 0.93))

        # Tubular side bustle rack (`z = -0.55 .. -2.28`)
        rx = sx * 1.52
        if lod:
            t.box("paint", (rx - 0.06, 1.78, -2.15), (rx + 0.06, 2.22, -0.70), tint=(0.94, 0.94, 0.91))
        else:
            for ry in (1.76, 2.00, 2.23):
                t.pipe("metal_dark", (rx, ry, -2.28), (rx, ry, -0.55), 0.018, seg=6)
                t.pipe("metal_dark", (sx * 1.34, ry, -2.28), (rx, ry, -2.28), 0.018, seg=6)
                t.pipe("metal_dark", (sx * 1.46, ry, -0.55), (rx, ry, -0.55), 0.018, seg=6)
            for rz in (-2.28, -1.70, -1.12, -0.55):
                t.pipe("metal_dark", (rx, 1.76, rz), (rx, 2.23, rz), 0.017, seg=6)

            # Iconic Corrugated Combat Identification Panel (CIP) mounted on mid-aft side rail!
            cip_x0, cip_x1 = (rx, rx + 0.045) if sx > 0 else (rx - 0.045, rx)
            t.box("paint", (cip_x0, 1.80, -1.96), (cip_x1, 2.20, -1.20), bevel=0.008, tint=(1.06, 1.05, 1.00))
            for k in range(9):
                lz = -1.90 + k * 0.080
                t.box("paint", (cip_x0 - 0.006, 1.83, lz - 0.015), (cip_x1 + 0.006, 2.17, lz + 0.015), tint=(0.86, 0.85, 0.82))

            # Strapped 20L NATO Jerrycan in forward rack bay (`z = -1.06 .. -0.68`)
            jx0, jx1 = (rx - 0.16, rx - 0.01) if sx > 0 else (rx + 0.01, rx + 0.16)
            t.box("paint", (jx0, 1.78, -1.04), (jx1, 2.22, -0.70), bevel=0.018, tint=(0.82, 0.84, 0.74))
            t.box("metal_dark", (jx0 - 0.006, 1.98, -1.05), (jx1 + 0.006, 2.02, -0.69))

            # Spare T158 track-link pair clamped to forward side cheek
            t.box("metal_dark", (sx * 1.56 - 0.03, 1.72, 0.62), (sx * 1.56 + 0.03, 2.02, 0.86), yaw=-sx * 0.12, bevel=0.006)

        # Tactical NATO Chevron on sleek turret flank (`z = -0.35`, clear of rails!)
        # Turret side slopes from x=1.59 at y=1.50 to x=1.39 at y=2.25; place flush along slope!
        y_lo, y_hi, y_mid = 1.76, 2.08, 1.92
        def flank_x(yy):
            return sx * (1.59 + (1.39 - 1.59) * (yy - 1.50) / (2.25 - 1.50) + 0.012)
        t.decal_quad("markings",
                     (flank_x(y_mid), y_mid, -0.14),
                     (flank_x(y_mid), y_mid, -0.22),
                     (flank_x(y_hi), y_hi, -0.44),
                     (flank_x(y_hi), y_hi, -0.36),
                     outward=(sx, 0.26, 0.0))
        t.decal_quad("markings",
                     (flank_x(y_mid), y_mid, -0.22),
                     (flank_x(y_mid), y_mid, -0.14),
                     (flank_x(y_lo), y_lo, -0.36),
                     (flank_x(y_lo), y_lo, -0.44),
                     outward=(sx, 0.26, 0.0))

    # 5. Rear Extended Bustle Stowage Basket (`z = -2.38 .. -2.96`) + Sculpted Canvas Tarps, Duffels & Crosswind Mast
    if lod:
        t.box("metal_dark", (-1.22, 1.82, -2.92), (1.22, 2.22, -2.38), bevel=0.02, tint=(0.65, 0.65, 0.65))
        t.box("canvas", (-0.95, 1.88, -2.86), (0.95, 2.24, -2.44), bevel=0.06, tint=(0.96, 0.94, 0.88))
    else:
        for ry in (1.82, 2.03, 2.24):
            t.pipe("metal_dark", (-1.24, ry, -2.94), (1.24, ry, -2.94), 0.018, seg=6)
            for sx in (-1, 1):
                t.pipe("metal_dark", (sx * 1.24, ry, -2.94), (sx * 1.24, ry, -2.36), 0.018, seg=6)
        for rx in (-1.24, -0.82, -0.41, 0.0, 0.41, 0.82, 1.24):
            t.pipe("metal_dark", (rx, 1.82, -2.94), (rx, 2.24, -2.94), 0.015, seg=6)
            t.pipe("metal_dark", (rx, 1.82, -2.94), (rx, 1.82, -2.38), 0.014, seg=5)

        # Rear CIP panel on left of bustle rack
        t.box("paint", (-1.16, 1.85, -2.97), (-0.54, 2.21, -2.93), bevel=0.008, tint=(1.05, 1.04, 1.00))
        # Rolled canvas tarpaulin across upper bustle + two crew duffel bags + steel ammo boxes inside basket!
        t.pipe("canvas", (-0.88, 2.22, -2.66), (0.38, 2.22, -2.66), 0.135, seg=12, bevel=0.03, tint=(1.02, 1.00, 0.92))
        for sz in (-0.58, -0.08):
            t.pipe("dark", (sz - 0.018, 2.22, -2.66), (sz + 0.018, 2.22, -2.66), 0.141, seg=12)
        t.pipe("canvas", (0.48, 1.99, -2.66), (1.12, 1.99, -2.66), 0.145, seg=10, bevel=0.03, tint=(0.84, 0.88, 0.76))
        t.box("paint", (-0.42, 1.84, -2.86), (0.36, 2.08, -2.46), bevel=0.018, tint=(0.78, 0.82, 0.72))

        # Rear meteorological crosswind sensor mast (`x = 0.0, z = -2.32`)
        t.pipe("metal_dark", (0.0, 2.25, -2.30), (0.0, 2.68, -2.30), 0.022, seg=8)
        t.box("metal_dark", (-0.07, 2.68, -2.33), (0.07, 2.75, -2.27), bevel=0.008)

    if variant == "m1a1m_abrams":
        # Iraqi M1A1M external Bustle Auxiliary Power Unit (EAPU) housing + exhaust pipe in left rear basket
        t.box("paint", (-1.16, 1.84, -2.90), (-0.52, 2.30, -2.42), bevel=0.018, tint=(0.94, 0.93, 0.89))
        if not lod:
            t.pipe("metal_dark", (-0.98, 2.30, -2.76), (-0.98, 2.46, -2.84), 0.030, seg=8)
            for ky in (1.92, 2.04, 2.16):
                t.box("metal_dark", (-1.14, ky - 0.014, -2.92), (-0.56, ky + 0.014, -2.89))
    elif variant == "m1a2s_abrams":
        # Saudi M1A2S slatted Thermal Management System (TMS) desert cooling carrier on left rear bustle
        t.box("paint", (-1.22, 1.86, -2.92), (-0.64, 2.34, -2.38), bevel=0.02, tint=(0.98, 0.97, 0.93))
        if not lod:
            for ky in (1.94, 2.06, 2.18, 2.28):
                t.box("metal_dark", (-1.18, ky - 0.016, -2.94), (-0.68, ky + 0.016, -2.90))

    return t


def build_gun(lod, gp):
    """120 mm M256 L/44 smoothbore in body-painted CARC thermal shroud, eccentric bore evacuator, MRS & coaxial M240."""
    g = Part("Gun", seed=31)
    gx, gy, gz = gp
    seg = 8 if lod else 20

    # 1. Nested armoured mantlet / gun rotor block + canvas dust boot collar
    g.box("paint", (gx - 0.34, gy - 0.24, gz - 0.22), (gx + 0.34, gy + 0.25, gz + 0.42), bevel=0.025, tint=(0.98, 0.98, 0.96))
    g.box("canvas", (gx - 0.355, gy - 0.255, gz + 0.18), (gx + 0.355, gy + 0.265, gz + 0.32), bevel=0.03, tint=(0.88, 0.86, 0.78))
    # Coaxial 7.62 mm M240 aperture & flash suppressor on right side of mantlet
    if not lod:
        g.box("dark", (gx + 0.21, gy - 0.04, gz + 0.36), (gx + 0.31, gy + 0.08, gz + 0.45))
        g.pipe("metal_dark", (gx + 0.26, gy + 0.02, gz + 0.38), (gx + 0.26, gy + 0.02, gz + 0.62), 0.020, seg=8)

    # 2. Body-painted CARC thermal shroud sections along the 120 mm barrel (`gz + 0.40 .. gz + 4.38`)
    #    Rear heavy cradle sleeve -> mid tube -> eccentric bore evacuator -> forward thermal shroud -> muzzle collar
    g.pipe("paint", (gx, gy, gz + 0.38), (gx, gy, gz + 1.18), 0.128, seg=seg, r2=0.114, tint=(1.0, 1.0, 0.99))
    g.pipe("paint", (gx, gy, gz + 1.18), (gx, gy, gz + 1.82), 0.106, seg=seg, r2=0.102, tint=(1.0, 1.0, 0.99))

    # Eccentric upper-offset cylindrical Bore Evacuator (fume extractor, characteristic of M256!)
    ev_y = gy + 0.026
    g.pipe("paint", (gx, ev_y, gz + 1.78), (gx, ev_y, gz + 1.90), 0.108, seg=seg, r2=0.162, tint=(1.02, 1.02, 1.0))
    g.pipe("paint", (gx, ev_y, gz + 1.90), (gx, ev_y, gz + 2.48), 0.162, seg=seg, tint=(1.02, 1.02, 1.0))
    g.pipe("paint", (gx, ev_y, gz + 2.48), (gx, ev_y, gz + 2.60), 0.162, seg=seg, r2=0.104, tint=(1.02, 1.02, 1.0))

    # Forward thermal shroud tapering subtly towards muzzle (`gz + 2.58 .. gz + 4.24`)
    g.pipe("paint", (gx, gy, gz + 2.58), (gx, gy, gz + 4.24), 0.098, seg=seg, r2=0.090, tint=(1.0, 1.0, 0.99))

    # Dark steel thermal-sleeve retaining bands & evacuator end-rings
    if not lod:
        for bz, br in ((0.76, 0.125), (1.17, 0.117), (1.91, 0.166), (2.47, 0.166), (3.22, 0.099), (3.86, 0.095)):
            by = ev_y if 1.85 < bz < 2.52 else gy
            g.pipe("metal_dark", (gx, by, gz + bz - 0.022), (gx, by, gz + bz + 0.022), br, seg=seg, tint=(0.62, 0.62, 0.65))

    # 3. Bare gunmetal muzzle reference collar + MRS sensor perch + deep hollow recessed 120 mm bore!
    g.tube_axis("metal_dark", (gx, gy, gz + 4.22), (gx, gy, gz + 4.38), 0.094, 0.060, seg=seg, tint=(0.68, 0.68, 0.72))
    g.cyl("dark", (gx, gy, gz + 4.21), 0.061, 0.02, seg=12)  # pitch-black inner bore stop
    # Muzzle Reference Sensor (MRS) bracket on top right of muzzle tip
    if not lod:
        g.box("metal_dark", (gx + 0.01, gy + 0.085, gz + 4.26), (gx + 0.048, gy + 0.165, gz + 4.35), bevel=0.005)
    return g


def build_citv(lod):
    """Commander's Independent Thermal Viewer on left forward turret roof."""
    p = Part("CITV")
    cx, cy, cz = -0.78, 2.25, 0.52
    seg = 8 if lod else 16
    p.cyl("paint", (cx, cy - 0.02, cz), 0.21, 0.14, seg=seg, bevel=0.01, tint=(0.95, 0.95, 0.93))
    p.cyl("paint", (cx, cy + 0.11, cz), 0.185, 0.22, seg=seg, bevel=0.015, tint=(1.02, 1.02, 1.0))
    # Bevelled rotating sensor head + recessed golden FLIR thermal window + armoured sun hood
    p.box("paint", (cx - 0.20, cy + 0.24, cz - 0.19), (cx + 0.20, cy + 0.48, cz + 0.20), bevel=0.025, tint=(1.03, 1.03, 1.01))
    p.box("dark", (cx - 0.14, cy + 0.28, cz + 0.17), (cx + 0.14, cy + 0.43, cz + 0.205))
    p.box("glass", (cx - 0.125, cy + 0.295, cz + 0.195), (cx + 0.125, cy + 0.415, cz + 0.212), tint=OPTIC_FLIR)
    if not lod:
        p.box("paint", (cx - 0.16, cy + 0.43, cz + 0.16), (cx + 0.16, cy + 0.46, cz + 0.25), bevel=0.006)
    return p


def build_gunner_sight(lod):
    """Gunner's Primary Sight (GPS) armoured 'doghouse' with open ballistic shutter doors."""
    p = Part("Gunner_Sight")
    cx, cy, cz = 0.74, 2.25, 0.68
    p.box("paint", (cx - 0.24, cy - 0.02, cz - 0.28), (cx + 0.24, cy + 0.23, cz + 0.26), bevel=0.022, tint=(1.02, 1.02, 1.0))
    p.box("dark", (cx - 0.19, cy + 0.03, cz + 0.22), (cx + 0.19, cy + 0.19, cz + 0.265))
    p.box("glass", (cx - 0.16, cy + 0.05, cz + 0.25), (cx - 0.02, cy + 0.17, cz + 0.272), tint=OPTIC_FLIR)
    p.box("glass", (cx + 0.02, cy + 0.05, cz + 0.25), (cx + 0.16, cy + 0.17, cz + 0.272), tint=OPTIC_COOL)
    if not lod:
        # Splayed left/right armoured shutter doors + overhanging rain brow
        for sx in (-1, 1):
            p.box("paint", (cx + sx * 0.22 - 0.015, cy + 0.02, cz + 0.22),
                  (cx + sx * 0.22 + 0.015, cy + 0.20, cz + 0.36), yaw=sx * 0.28, bevel=0.005)
        p.box("paint", (cx - 0.24, cy + 0.20, cz + 0.20), (cx + 0.24, cy + 0.235, cz + 0.35), bevel=0.006)
    return p


def build_commander_hatch(lod):
    """Octagonal commander's cupola with 8 radial periscope blocks & armoured hatch lid."""
    p = Part("Hatch_Commander")
    cx, cy, cz = 0.60, 2.25, -0.18
    p.cyl("paint", (cx, cy - 0.01, cz), 0.34, 0.11, seg=8, bevel=0.012, tint=(0.97, 0.97, 0.95))
    p.cyl("paint", (cx, cy + 0.09, cz), 0.28, 0.045, seg=12, bevel=0.01, tint=(1.03, 1.03, 1.01))
    if not lod:
        for k in range(8):
            a = math.tau * k / 8.0
            with p.frame((cx, cy + 0.055, cz), yaw=a):
                p.box("glass", (-0.055, -0.02, 0.305), (0.055, 0.025, 0.335), tint=OPTIC_COOL)
                p.box("paint", (-0.065, 0.022, 0.295), (0.065, 0.038, 0.348), bevel=0.004)
    return p


def build_loader_station(lod):
    """Loader's circular hatch + skate-ring pintle M240 7.62 mm machine gun with ballistic armor shield & ammo can."""
    p = Part("Hatch_Loader")
    cx, cy, cz = -0.58, 2.25, -0.52
    p.cyl("paint", (cx, cy - 0.01, cz), 0.30, 0.075, seg=8 if lod else 14, bevel=0.01, tint=(0.98, 0.98, 0.96))
    if not lod:
        # Pintle post forward of loader's hatch + M240 7.62mm + angled ballistic shield wings + 7.62 ammo box
        mx, my, mz = cx - 0.05, cy + 0.24, cz + 0.28
        p.pipe("metal_dark", (mx, cy + 0.04, mz - 0.06), (mx, my, mz), 0.024, seg=6)
        p.box("metal_dark", (mx - 0.045, my - 0.03, mz - 0.22), (mx + 0.045, my + 0.07, mz + 0.18), bevel=0.008)
        p.pipe("metal_dark", (mx, my + 0.03, mz + 0.18), (mx, my + 0.03, mz + 0.66), 0.016, seg=8)
        # Winged ballistic gun shield in CARC paint + green ammo box
        for sx in (-1, 1):
            p.box("paint", (mx + sx * 0.12 - 0.08, my - 0.04, mz + 0.11),
                  (mx + sx * 0.12 + 0.08, my + 0.17, mz + 0.135), yaw=-sx * 0.25, bevel=0.005)
        p.box("paint", (mx - 0.18, my - 0.06, mz - 0.08), (mx - 0.055, my + 0.08, mz + 0.10), bevel=0.008, tint=(0.78, 0.84, 0.70))
    return p


def build_crows(lod):
    """SEPv3 CROWS-LP (Low Profile) Remote Weapon Station base, EO/IR sensor pod & 400-rd .50 cal ammo chest."""
    p = Part("CROWS")
    cx, cy, cz = 0.58, 2.36, -0.74
    seg = 8 if lod else 14
    # Bolted base ring & U-shaped servo yoke
    p.cyl("paint", (cx, cy - 0.12, cz), 0.19, 0.16, seg=seg, bevel=0.01, tint=(0.94, 0.94, 0.92))
    p.box("paint", (cx - 0.18, cy + 0.02, cz - 0.16), (cx + 0.18, cy + 0.12, cz + 0.16), bevel=0.015)
    p.box("paint", (cx - 0.19, cy + 0.10, cz - 0.12), (cx - 0.11, cy + 0.38, cz + 0.12), bevel=0.012)
    p.box("paint", (cx + 0.11, cy + 0.10, cz - 0.12), (cx + 0.19, cy + 0.38, cz + 0.12), bevel=0.012)

    # Multi-aperture EO/IR sensor pod mounted forward-lower-left of the cradle
    p.box("paint", (cx - 0.15, cy + 0.11, cz + 0.06), (cx + 0.13, cy + 0.28, cz + 0.32), bevel=0.02, tint=(0.98, 0.98, 0.96))
    p.box("dark", (cx - 0.12, cy + 0.135, cz + 0.29), (cx + 0.10, cy + 0.255, cz + 0.328))
    p.box("glass", (cx - 0.10, cy + 0.15, cz + 0.315), (cx - 0.01, cy + 0.24, cz + 0.334), tint=OPTIC_FLIR)
    p.box("glass", (cx + 0.015, cy + 0.155, cz + 0.315), (cx + 0.085, cy + 0.235, cz + 0.334), tint=OPTIC_COOL)

    # Large right-side ribbed .50 cal ammunition chest + feed chute
    p.box("paint", (cx + 0.19, cy + 0.12, cz - 0.20), (cx + 0.44, cy + 0.42, cz + 0.16), bevel=0.016, tint=(0.88, 0.90, 0.82))
    if not lod:
        p.box("metal_dark", (cx + 0.08, cy + 0.36, cz - 0.08), (cx + 0.24, cy + 0.45, cz + 0.08), bevel=0.01)
    return p


def build_crows_gun(lod):
    """M2HB .50 cal Browning heavy machine gun on CROWS-LP trunnion `(0.58, 2.74, -0.68)`."""
    p = Part("CROWS_Gun")
    gx, gy, gz = 0.58, 2.74, -0.68
    # Heavy M2HB boxy receiver + rear buffer
    p.box("metal_dark", (gx - 0.075, gy - 0.08, gz - 0.28), (gx + 0.075, gy + 0.10, gz + 0.26), bevel=0.012, tint=(0.62, 0.62, 0.65))
    # Perforated barrel cooling support jacket + long heavy .50 cal barrel + flash suppressor
    p.pipe("metal_dark", (gx, gy + 0.02, gz + 0.26), (gx, gy + 0.02, gz + 0.56), 0.034, seg=8 if lod else 12, tint=(0.55, 0.55, 0.58))
    p.pipe("metal_dark", (gx, gy + 0.02, gz + 0.56), (gx, gy + 0.02, gz + 1.18), 0.020, seg=6 if lod else 10, tint=(0.68, 0.68, 0.72))
    if not lod:
        p.tube_axis("metal_dark", (gx, gy + 0.02, gz + 1.16), (gx, gy + 0.02, gz + 1.25), 0.028, 0.014, seg=10)
    return p


def build_smoke_launcher(lod, side):
    """U.S. M250 6-barrel fanned smoke grenade launcher projecting forward & outward from turret cheek."""
    p = Part(f"Smoke_{side}")
    sx = side
    bx, by, bz = sx * 1.48, 1.94, 0.56
    p.box("paint", (bx - 0.055, by - 0.10, bz - 0.16), (bx + 0.055, by + 0.10, bz + 0.14), yaw=sx * 0.18, bevel=0.012)
    if not lod:
        # In Blender Z-up (`P(x,-z,y)`): yaw about +Z by `-sx * angle` turns +Z forward-and-outward towards `sx * +X`,
        # and positive pitch about +X tilts the +Z barrel upward towards +Y!
        # Wait: let's compute exact game-space start -> end points so there is ZERO Euler sign ambiguity!
        for dy, up_k in ((-0.04, 0.18), (0.05, 0.30)):
            for dz, out_k, fwd_k in ((-0.09, 0.52, 0.78), (0.0, 0.35, 0.88), (0.09, 0.18, 0.94)):
                a = (bx + sx * 0.035, by + dy, bz + dz)
                L = 0.24
                nrm = math.sqrt(out_k * out_k + up_k * up_k + fwd_k * fwd_k)
                dx_, dy_, dz_ = sx * out_k / nrm, up_k / nrm, fwd_k / nrm
                b = (a[0] + dx_ * L, a[1] + dy_ * L, a[2] + dz_ * L)
                c = (a[0] + dx_ * (L + 0.028), a[1] + dy_ * (L + 0.028), a[2] + dz_ * (L + 0.028))
                p.pipe("paint", a, b, 0.036, seg=8, tint=(0.94, 0.94, 0.92))
                p.pipe("rubber", b, c, 0.039, seg=8)
    return p


def build_antenna(lod, idx, x_pos):
    """SINCGARS spring-pot antenna mount + slender tapered whip aerial."""
    p = Part(f"Antenna_{idx}")
    ax, ay, az = x_pos, 2.25, -1.78
    p.cyl("metal_dark", (ax, ay - 0.01, az), 0.042, 0.13, seg=6 if lod else 10, tint=(0.55, 0.55, 0.58))
    p.pipe("metal_dark", (ax, ay + 0.12, az), (ax + (0.02 if x_pos > 0 else -0.02), ay + 1.42, az - 0.06),
           0.011, seg=4 if lod else 6, r2=0.004, tint=(0.45, 0.45, 0.48))
    return p


def build_cws_station(lod, thermal_sight=False):
    """Classic M1A1 / M1A2S Commander's Weapon Station (CWS): powered pintle M2HB .50 cal & 100-rd ammo box on cupola."""
    p = Part("Commander_Weapon_Station")
    cx, cy, cz = 0.60, 2.38, -0.14
    seg = 6 if lod else 12
    p.cyl("paint", (cx, cy - 0.04, cz), 0.24, 0.14, seg=seg, bevel=0.01, tint=(0.95, 0.95, 0.93))
    p.box("metal_dark", (cx - 0.075, cy + 0.10, cz - 0.18), (cx + 0.075, cy + 0.26, cz + 0.30), bevel=0.012, tint=(0.62, 0.62, 0.65))
    p.pipe("metal_dark", (cx, cy + 0.19, cz + 0.30), (cx, cy + 0.19, cz + 0.56), 0.032, seg=seg, tint=(0.55, 0.55, 0.58))
    p.pipe("metal_dark", (cx, cy + 0.19, cz + 0.56), (cx, cy + 0.19, cz + 1.12), 0.019, seg=seg, tint=(0.68, 0.68, 0.72))
    p.box("paint", (cx + 0.09, cy + 0.08, cz - 0.10), (cx + 0.29, cy + 0.30, cz + 0.18), bevel=0.012, tint=(0.82, 0.86, 0.74))
    if thermal_sight:
        # Iraqi M1A1M AN/VSG-X stabilised commander thermal sight box beside M2HB
        p.box("paint", (cx - 0.26, cy + 0.10, cz - 0.06), (cx - 0.09, cy + 0.31, cz + 0.22), bevel=0.012, tint=(0.98, 0.98, 0.96))
        p.box("glass", (cx - 0.23, cy + 0.14, cz + 0.205), (cx - 0.12, cy + 0.27, cz + 0.230), tint=OPTIC_FLIR)
    return p


def build_abrams_rig(lod=0, variant="m1a2_sepv3_abrams"):
    rig = VehicleRig(lod=lod)

    # Hull & Turret Ring
    rig.add("Hull", rig.root_name, (0.0, 0.0, 0.0), build_hull(lod))
    ring = Part("Turret_Ring")
    ring.cyl("metal_dark", (0.0, 1.44, 0.15), 1.06, 0.08, seg=14 if lod else 28, tint=(0.48, 0.48, 0.50))
    rig.add("Turret_Ring", "Hull", (0.0, 1.48, 0.15), ring)

    # Turret & Main 120mm Gun + Muzzle
    turret_pivot = (0.0, 1.50, 0.15)
    rig.add("Turret", "Hull", turret_pivot, build_turret(lod, variant=variant))

    gun_pivot = (0.0, 1.93, 1.38)
    rig.add("Gun", "Turret", gun_pivot, build_gun(lod, gun_pivot))
    rig.add("Muzzle", "Gun", (0.0, 1.93, 5.76), None)

    # Turret Roof Crew Stations, Optics, RWS/CWS, Smoke & Aerials
    rig.add("Hatch_Commander", "Turret", (0.60, 2.25, -0.44), build_commander_hatch(lod))
    rig.add("Hatch_Loader", "Turret", (-0.58, 2.25, -0.78), build_loader_station(lod))
    if variant in ("m1a2_sepv3_abrams", "m1a2s_abrams"):
        rig.add("CITV", "Turret", (-0.78, 2.25, 0.52), build_citv(lod))
    rig.add("Gunner_Sight", "Turret", (0.74, 2.25, 0.68), build_gunner_sight(lod))
    if variant == "m1a2_sepv3_abrams":
        rig.add("CROWS", "Turret", (0.58, 2.36, -0.74), build_crows(lod))
        rig.add("CROWS_Gun", "CROWS", (0.58, 2.74, -0.68), build_crows_gun(lod))
    else:
        rig.add("Commander_Weapon_Station", "Turret", (0.60, 2.38, -0.14),
                build_cws_station(lod, thermal_sight=(variant == "m1a1m_abrams")))

    for label, side in (("L", -1), ("R", 1)):
        rig.add(f"Smoke_Launcher_{label}", "Turret", (side * 1.48, 1.94, 0.54), build_smoke_launcher(lod, side))

    rig.add("Antenna_1", "Turret", (-0.98, 2.25, -1.78), build_antenna(lod, 1, -0.98))
    rig.add("Antenna_2", "Turret", (0.98, 2.25, -1.78), build_antenna(lod, 2, 0.98))

    # Running Gear: 7 Dual Road Wheels, Rear Sprocket, Front Idler, 3 Return Rollers & 3D T158 Track Loop per Side
    for label, side in (("L", -1), ("R", 1)):
        wx = side * TRACK_X
        for i, wz in enumerate(WHEEL_ZS):
            wp = (wx, 0.455, wz)
            rig.add(f"Wheel_{label}{i}", "Hull", wp, build_road_wheel(wp, lod, side))

        sp_piv = (wx, 0.65, -3.23)
        rig.add(f"Sprocket_{label}", "Hull", sp_piv, build_sprocket(sp_piv, lod, side))

        id_piv = (wx, 0.65, 3.23)
        rig.add(f"Idler_{label}", "Hull", id_piv, build_idler(id_piv, lod, side))

        for i, rz in enumerate((-1.75, 0.0, 1.75)):
            rp = (wx, 1.03, rz)
            rig.add(f"Roller_{label}{i}", "Hull", rp, build_roller(rp, lod, side))

        trk = Part(f"Track_{label}")
        trk.build_track(wx, lod=lod, width=0.635)
        rig.add(f"Track_{label}", "Hull", (wx, 0.0, 0.0), trk)

    rig.add("Exhaust", "Hull", (0.0, 1.06, -3.98), None)
    rig.add("Engine_Deck", "Hull", (0.0, 1.49, -2.75), None)
    return rig


ABRAMS_VARIANTS = ("m1a2_sepv3_abrams", "m1a1_abrams", "m1a1m_abrams", "m1a2s_abrams")


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    veh_dir = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../godot/assets/art/vehicles"))
    if "--all" in argv:
        os.makedirs(veh_dir, exist_ok=True)
        for var in ABRAMS_VARIANTS:
            init_scene()
            out_p = os.path.join(veh_dir, f"tank__{var}.glb")
            export_vehicle(out_p, build_abrams_rig(0, var), build_abrams_rig(1, var))
    elif "--variants-only" in argv:
        os.makedirs(veh_dir, exist_ok=True)
        for var in ("m1a1_abrams", "m1a1m_abrams", "m1a2s_abrams"):
            init_scene()
            out_p = os.path.join(veh_dir, f"tank__{var}.glb")
            export_vehicle(out_p, build_abrams_rig(0, var), build_abrams_rig(1, var))
    else:
        out_p = argv[0] if argv else DEFAULT_OUT
        os.makedirs(os.path.dirname(os.path.abspath(out_p)), exist_ok=True)
        init_scene()
        export_vehicle(out_p, build_abrams_rig(0, "m1a2_sepv3_abrams"), build_abrams_rig(1, "m1a2_sepv3_abrams"))
