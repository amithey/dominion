"""Tier P3.3 — MLRS, HIMARS, PULS, TOS-1A, Heavy Rocket Launchers, Coastal ASM & Hypersonic TELs (54 vehicles).

Run all 54 variants:
    blender -b --python-exit-code 1 -P native/tools/models/blender/build_p3_mlrs_missiles.py -- --all
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_vehicle import Part, VehicleRig, build_offroad_tyre, init_scene, export_vehicle
from build_merkava import add_idf_chevron_x
from build_p2_ifv_west import add_nato_diamond
from build_p3_sph_tracked import add_sph_running_gear, rect_xz

GLASS_ARMOUR = (0.24, 0.58, 0.52)
TAIL_RED = (2.8, 0.25, 0.20)


# =============================================================================
# 1–9. TRACKED MLRS (`M270` / `MARS II` / `LRU`) & `TOS-1A SOLNTSEPYOK`
# =============================================================================

M270_SLUGS = [
    "mlrs__m270a2_mlrs",
    "mlrs__m270_mlrs",
    "mlrs__m270_jgsdf",
    "mlrs__mars_ii",
    "mlrs__lru",
    "himars__m270a2_gmlrs",
    "himars__m270_gmlrs",
    "himars__lru_gmlrs",
]


def build_m270_or_tos1a_rig(slug: str, lod: int = 0) -> VehicleRig:
    rig = VehicleRig(lod=lod)
    bv = 0.016 if not lod else 0.0

    if slug == "tos1a__tos_1a_solntsepyok":
        # Russian TOS-1A on T-72 6-wheel hull w/ Kontakt-5 glacis ERA + 24-tube thermobaric armored box!
        tx, tw, wr, ts = 1.44, 0.54, 0.36, 0.90
        wheels = [-2.25, -1.35, -0.45, 0.45, 1.35, 2.25]
        rollers = [-1.40, 0.0, 1.40]
        hl, hw, hh = 7.05, 2.32, 1.46
        z0, z1 = -hl * 0.5, hl * 0.5
        hx, ow = hw * 0.5, tx + tw * 0.5 + 0.06
        hp = Part("Hull")
        hp.profile_x(
            "paint",
            [(z0 + 0.18, 0.42), (z1 - 0.72, 0.42), (z1, 0.94), (z1 - 1.15, hh), (z0 + 0.12, hh), (z0, 1.00)],
            -hx, hx, bevel=bv, ao_y=(0.35, hh + 1.0),
        )
        for sx in (-1, 1):
            hp.box("paint", (sx * hx, 0.88, z0 + 0.06), (sx * ow, hh - 0.02, z1 - 0.14), bevel=bv)
            hp.box("paint", (sx * (ow - 0.05), 0.50, z0 + 0.16), (sx * (ow + 0.02), 0.92, z1 - 0.22), bevel=bv * 0.7)
        if not lod:
            for ex in (-0.75, -0.25, 0.25, 0.75):
                hp.box("paint", (ex - 0.21, 1.06, z1 - 0.98), (ex + 0.21, 1.34, z1 - 0.42), bevel=0.01)
        rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
        add_sph_running_gear(rig, lod, tx, tw, wr, wheels, rollers, ts, front_drive=False)

        tz = -0.25
        t_piv = (0.0, hh + 0.02, tz)
        tp = Part("Turret")
        tp.cyl("metal_dark", (0.0, hh, tz), 0.96, 0.26, seg=18 if not lod else 10)
        for sx in (-1, 1):
            tp.box("paint", (sx * 0.86 - 0.18, hh + 0.22, tz - 0.65), (sx * 0.86 + 0.18, hh + 1.02, tz + 0.65), bevel=bv)
        rig.add("Turret", "Hull", t_piv, tp)

        g_piv = (0.0, hh + 0.92, tz)
        gp = Part("Gun")
        with gp.frame(g_piv, pitch=-0.16):
            # Iconic flat-topped trapezoidal 24-tube thermobaric launcher pack
            gp.box("paint", (-1.12, -0.18, -1.75), (1.12, 0.78, 1.75), bevel=bv)
            gp.box("metal_dark", (-1.04, -0.10, 1.70), (1.04, 0.68, 1.79))
            if not lod:
                for row_y in (0.08, 0.30, 0.52):
                    for col_i in range(8):
                        cx = -0.88 + col_i * (1.76 / 7.0)
                        gp.cyl("dark", (cx, row_y, 1.76), 0.092, 0.05, seg=10, axis="z")
        muz_pt = (0.0, g_piv[1] + 0.55, tz + 1.82)
        rig.add("Gun", "Turret", g_piv, gp)
        rig.add("Muzzle", "Gun", muz_pt, None)
        return rig

    # M270 / M270A2 / MARS II / LRU Tracked Armored Twin-Pod MLRS
    is_a2 = "m270a2" in slug
    tx, tw, wr, ts = 1.28, 0.52, 0.32, 0.88
    wheels = [-2.25, -1.35, -0.45, 0.45, 1.35, 2.25]
    rollers = [-1.40, 0.0, 1.40]
    hl, hw, hh = 6.95, 2.38, 1.36
    z0, z1 = -hl * 0.5, hl * 0.5
    hx, ow = hw * 0.5, tx + tw * 0.5 + 0.04
    hp = Part("Hull")
    hp.box("paint", (-ow, 0.46, z0), (ow, hh, z1 - 0.16), bevel=bv)
    # Forward armored 3-man crew cab (`z = 0.85..z1`) — taller IAC on M270A2!
    cab_top = 2.58 if is_a2 else 2.42
    hp.profile_x(
        "paint",
        [(0.82, hh), (z1 - 0.16, hh), (z1, hh + 0.48), (z1 - 0.38, cab_top), (0.82, cab_top)],
        -ow + 0.02, ow - 0.02, bevel=bv, ao_y=(0.45, cab_top + 0.2),
    )
    if not lod:
        # 3 armored windshield windows w/ louvered blast shutters
        for wx_i in (-0.78, 0.0, 0.78):
            hp.box("glass", (wx_i - 0.30, cab_top - 0.54, z1 - 0.38), (wx_i + 0.30, cab_top - 0.16, z1 - 0.12), tint=GLASS_ARMOUR)
            hp.box("metal_dark", (wx_i - 0.32, cab_top - 0.18, z1 - 0.40), (wx_i + 0.32, cab_top - 0.10, z1 - 0.10))
        for sx in (-1, 1):
            add_nato_diamond(hp, sx * (ow + 0.008), 0.95, 1.55, sx, size=0.12)

    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
    add_sph_running_gear(rig, lod, tx, tw, wr, wheels, rollers, ts, front_drive=True)

    # Rear slewing turntable (`Turret`) + elevating Armored Launcher Cage Module w/ twin 6-tube pods (`Gun`)
    tz = -1.45
    t_piv = (0.0, hh + 0.02, tz)
    tp = Part("Turret")
    tp.cyl("metal_dark", (0.0, hh, tz), 0.98, 0.18, seg=18 if not lod else 10)
    tp.box("paint", (-1.22, hh + 0.16, tz - 1.65), (1.22, hh + 0.38, tz + 1.65), bevel=bv)
    rig.add("Turret", "Hull", t_piv, tp)

    g_piv = (0.0, hh + 0.38, tz - 1.35)
    gp = Part("Gun")
    with gp.frame(g_piv, pitch=-0.24):
        # Outer armored box-beam LLM cage + twin 6-cell GMLRS pods inside
        gp.box("paint", (-1.28, 0.0, -0.35), (1.28, 1.16, 3.65), bevel=bv)
        for sx in (-1, 1):
            gp.box("metal_dark", (sx * 0.60 - 0.50, 0.10, 3.60), (sx * 0.60 + 0.50, 1.04, 3.70))
            if not lod:
                for ry in (0.34, 0.78):
                    for cx in (-0.32, 0.0, 0.32):
                        gp.cyl("dark", (sx * 0.60 + cx, ry, 3.67), 0.115, 0.05, seg=12, axis="z")
    muz_pt = (0.0, g_piv[1] + 1.35, g_piv[2] + 3.55)
    rig.add("Gun", "Turret", g_piv, gp)
    rig.add("Muzzle", "Gun", muz_pt, None)
    return rig


# =============================================================================
# 10–29. WHEELED PODDED PRECISION MLRS (`HIMARS`, `PULS`, `CHUNMOO`, `ASTROS`, `PINAKA`, `FATH`)
# =============================================================================

POD_MLRS_SPECS = {
    "himars__m142_himars": {"axles": 3, "pods": 1, "idf": False},
    "himars__himars": {"axles": 3, "pods": 1, "idf": False},
    "mlrs__m142_himars": {"axles": 3, "pods": 1, "idf": False},
    "himars__puls": {"axles": 4, "pods": 2, "idf": True},
    "mlrs__puls": {"axles": 4, "pods": 2, "idf": True},
    "himars__europuls": {"axles": 4, "pods": 2, "idf": False},
    "mlrs__lynx": {"axles": 3, "pods": 2, "idf": True},
    "mlrs__k239_chunmoo": {"axles": 4, "pods": 2, "idf": False},
    "mlrs__k239_chunmoo_korean": {"axles": 4, "pods": 2, "idf": False},
    "himars__chunmoo_guided_cgr_080": {"axles": 4, "pods": 2, "idf": False},
    "himars__pch_191": {"axles": 4, "pods": 2, "idf": False, "east": True},
    "himars__trlg_230": {"axles": 4, "pods": 2, "idf": False},
    "himars__guided_rocket_launcher": {"axles": 4, "pods": 2, "idf": False},
    "mlrs__astros_ii": {"axles": 3, "pods": 2, "astros": True},
    "mlrs__astros_ii_mk6": {"axles": 3, "pods": 2, "astros": True},
    "mlrs__astros_ii_rm_70": {"axles": 4, "pods": 2, "astros": True},
    "mlrs__pinaka": {"axles": 4, "pods": 2, "east": True},
    "himars__guided_pinaka": {"axles": 4, "pods": 2, "east": True},
    "himars__fath_360_launcher": {"axles": 3, "pods": 2, "east": True},
    "himars__fatah_ii": {"axles": 4, "pods": 2, "east": True},
}


def build_pod_mlrs_rig(slug: str, lod: int = 0) -> VehicleRig:
    rig = VehicleRig(lod=lod)
    cfg = POD_MLRS_SPECS[slug]
    is_8x8 = cfg["axles"] == 4
    axles = [-2.95, -1.55, 1.55, 2.95] if is_8x8 else [-2.15, -0.80, 2.15]
    wr, tw, wx = (0.56 if is_8x8 else 0.53), 0.39, 1.15
    z0, z1, hx = (-4.10 if is_8x8 else -3.45), (4.05 if is_8x8 else 3.45), 1.25
    bv = 0.016 if not lod else 0.0

    hp = Part("Hull")
    hp.box("metal_dark", (-0.54, 0.72, z0), (0.54, 1.18, z1 - 0.12), bevel=bv)
    hp.box("paint", (-hx, 1.18, z0), (hx, 1.38, 0.90), bevel=bv)
    # Armored tactical cab forward
    cab_z0 = 1.15 if is_8x8 else 0.92
    hp.profile_x(
        "paint",
        [(cab_z0, 1.16), (z1 - 0.08, 1.16), (z1, 1.78), (z1 - 0.28, 2.58), (cab_z0, 2.58)],
        -hx, hx, bevel=bv, ao_y=(0.65, 2.75),
    )
    if not lod:
        # Rear hydraulic stabilizer jacks + 3-pane ballistic cab glass
        for sx in (-1, 1):
            hp.cyl("metal_dark", (sx * (hx - 0.08), 0.38, z0 + 0.22), 0.08, 0.92, seg=8)
            hp.box("glass", (sx * 0.56 - 0.38, 1.98, z1 - 0.28), (sx * 0.56 + 0.38, 2.40, z1 - 0.06), tint=GLASS_ARMOUR)
            if cfg.get("idf"):
                add_idf_chevron_x(hp, sx * (hx + 0.008), 1.66, cab_z0 + 0.65, sx)
            elif not cfg.get("east"):
                add_nato_diamond(hp, sx * (hx + 0.008), 1.66, cab_z0 + 0.65, sx, size=0.12)

    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
    hub = "eastern" if cfg.get("east") else "western"
    for side_lbl, sx in (("L", -1), ("R", 1)):
        for i, az in enumerate(axles):
            wp = (sx * wx, wr, az)
            rig.add(f"Wheel_{side_lbl}{i}", f"LOD{lod}", wp, build_offroad_tyre(f"Wheel_{side_lbl}{i}", wp, lod, sx, r=wr, w=tw, hub_style=hub, lugs=20))

    tz = -1.95 if is_8x8 else -1.55
    t_piv = (0.0, 1.40, tz)
    tp = Part("Turret")
    tp.cyl("metal_dark", (0.0, 1.38, tz), 0.84, 0.22, seg=18 if not lod else 10)
    tp.box("paint", (-0.96, 1.58, tz - 1.15), (0.96, 1.84, tz + 0.95), bevel=bv)
    rig.add("Turret", "Hull", t_piv, tp)

    g_piv = (0.0, 1.84, tz - 0.95)
    gp = Part("Gun")
    with gp.frame(g_piv, pitch=-0.28):
        if cfg["pods"] == 1:
            # M142 HIMARS signature single 6-tube GMLRS pod + overhead resupply crane boom!
            gp.box("paint", (-0.68, 0.0, -0.25), (0.68, 1.14, 3.45), bevel=bv)
            gp.box("metal_dark", (-0.58, 0.10, 3.40), (0.58, 0.98, 3.50))
            if not lod:
                for ry in (0.34, 0.74):
                    for cx in (-0.34, 0.0, 0.34):
                        gp.cyl("dark", (cx, ry, 3.47), 0.115, 0.05, seg=12, axis="z")
        else:
            # Twin-pod PULS / Chunmoo / Astros / Pinaka precision launcher!
            for sx in (-1, 1):
                gp.box("paint", (sx * 0.58 - 0.52, 0.0, -0.25), (sx * 0.58 + 0.52, 1.06, 3.55), bevel=bv)
                gp.box("metal_dark", (sx * 0.58 - 0.46, 0.08, 3.50), (sx * 0.58 + 0.46, 0.98, 3.60))
                if not lod:
                    for ry in (0.32, 0.72):
                        for cx in (-0.28, 0.0, 0.28):
                            gp.cyl("dark", (sx * 0.58 + cx, ry, 3.57), 0.105, 0.05, seg=10, axis="z")
    muz_pt = (0.0, g_piv[1] + 1.48, g_piv[2] + 3.42)
    rig.add("Gun", "Turret", g_piv, gp)
    rig.add("Muzzle", "Gun", muz_pt, None)
    return rig


# =============================================================================
# 30–43. MULTI-TUBE 122MM GRAD & HEAVY 300MM / 600MM ROCKET ARTILLERY
# =============================================================================

TUBE_MLRS_SPECS = {
    "mlrs__bm_21_grad": "grad_6x6",
    "mlrs__bm_21_badr_rockets": "grad_6x6",
    "mlrs__bm_21_sakr": "grad_6x6",
    "mlrs__bm_21_taka": "grad_6x6",
    "mlrs__t_122_sakarya": "sakarya_6x6",
    "mlrs__bm_30_smerch": "smerch_8x8",
    "himars__tornado_s": "smerch_8x8",
    "mlrs__bm_27_himars": "smerch_8x8",
    "mlrs__phl_03": "smerch_8x8",
    "mlrs__a_100_fatah_1": "smerch_8x8",
    "mlrs__fajr_5": "fajr_6x6",
    "mlrs__kn_25_m1991": "kn25_8x8",
    "himars__kn_25_600_mm_guided": "kn25_8x8",
    "heavyRocket__heavy_rocket_launcher": "smerch_8x8",
}


def build_tube_mlrs_rig(slug: str, lod: int = 0) -> VehicleRig:
    rig = VehicleRig(lod=lod)
    kind = TUBE_MLRS_SPECS[slug]
    is_8x8 = kind.endswith("8x8")
    axles = [-3.25, -1.75, 1.65, 3.15] if is_8x8 else [-2.15, -0.80, 2.15]
    wr, tw, wx = (0.58 if is_8x8 else 0.52), (0.42 if is_8x8 else 0.36), (1.18 if is_8x8 else 1.10)
    z0, z1, hx = (-4.55 if is_8x8 else -3.45), (4.45 if is_8x8 else 3.45), (1.28 if is_8x8 else 1.18)
    bv = 0.016 if not lod else 0.0

    hp = Part("Hull")
    hp.box("metal_dark", (-0.56, 0.72, z0), (0.56, 1.18, z1 - 0.12), bevel=bv)
    hp.box("paint", (-hx, 1.18, z0), (hx, 1.36, 0.85), bevel=bv)

    if kind == "grad_6x6":
        # Classic Soviet Ural-4320 hooded off-road 6x6 cab!
        hp.box("paint", (-hx + 0.18, 1.16, 2.05), (hx - 0.18, 1.92, z1), bevel=bv)
        hp.box("paint", (-hx + 0.04, 1.16, 0.85), (hx - 0.04, 2.46, 2.08), bevel=bv)
        if not lod:
            for sx in (-1, 1):
                hp.box("glass", (sx * 0.48 - 0.36, 1.92, 1.98), (sx * 0.48 + 0.36, 2.32, 2.10), tint=GLASS_ARMOUR)
    elif is_8x8:
        # MAZ-543M / MZKT / Taian 8x8 heavy TEL cab + mid engine compartment!
        hp.profile_x(
            "paint",
            [(2.15, 1.18), (z1 - 0.10, 1.18), (z1, 1.82), (z1 - 0.32, 2.58), (2.15, 2.58)],
            -hx, hx, bevel=bv, ao_y=(0.65, 2.75),
        )
        hp.box("metal_dark", (-hx + 0.08, 1.22, 0.75), (hx - 0.08, 2.28, 2.10), bevel=bv)
        if not lod:
            for sx in (-1, 1):
                hp.box("glass", (sx * 0.62 - 0.42, 1.96, z1 - 0.32), (sx * 0.62 + 0.42, 2.40, z1 - 0.08), tint=GLASS_ARMOUR)
    else:
        # Flat-front military cab (`Sakarya` / `Fajr-5`)
        hp.box("paint", (-hx, 1.16, 1.15), (hx, 2.52, z1), bevel=bv)
        if not lod:
            for sx in (-1, 1):
                hp.box("glass", (sx * 0.52 - 0.40, 1.94, z1 - 0.10), (sx * 0.52 + 0.40, 2.36, z1 + 0.02), tint=GLASS_ARMOUR)

    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
    for side_lbl, sx in (("L", -1), ("R", 1)):
        for i, az in enumerate(axles):
            wp = (sx * wx, wr, az)
            rig.add(f"Wheel_{side_lbl}{i}", f"LOD{lod}", wp, build_offroad_tyre(f"Wheel_{side_lbl}{i}", wp, lod, sx, r=wr, w=tw, hub_style="eastern", lugs=20))

    tz = -2.20 if is_8x8 else -1.65
    t_piv = (0.0, 1.38, tz)
    tp = Part("Turret")
    tp.cyl("metal_dark", (0.0, 1.36, tz), 0.86 if is_8x8 else 0.68, 0.26, seg=18 if not lod else 10)
    tp.box("paint", (-0.82, 1.60, tz - 0.85), (0.82, 1.92, tz + 0.85), bevel=bv)
    rig.add("Turret", "Hull", t_piv, tp)

    g_piv = (0.0, 1.92, tz - 0.65)
    gp = Part("Gun")
    with gp.frame(g_piv, pitch=-0.30):
        if kind in ("grad_6x6", "sakarya_6x6"):
            # 40-tube 122mm BM-21 Grad / T-122 multi-tube bank
            gp.box("paint", (-0.92, 0.0, -0.55), (0.92, 0.62, 2.65), bevel=bv)
            if not lod:
                for ry in (0.12, 0.26, 0.40, 0.54):
                    for ci in range(10):
                        cx = -0.78 + ci * (1.56 / 9.0)
                        gp.tube_axis("metal_dark", (cx, ry, 2.45), (cx, ry, 2.82), 0.068, 0.048, seg=8)
            muz_d = 2.82
        elif kind == "kn25_8x8":
            # DPRK KN-25 600mm super-large 4-tube Guided MLRS (`2x2` huge tubes!)
            gp.box("metal_dark", (-1.10, -0.05, -0.85), (1.10, 0.20, 4.15), bevel=bv)
            for ry in (0.42, 1.04):
                for sx in (-1, 1):
                    gp.cyl("paint", (sx * 0.46, ry, -0.80), 0.30, 5.15, seg=16 if not lod else 10, axis="z")
                    gp.tube_axis("metal_dark", (sx * 0.46, ry, 4.25), (sx * 0.46, ry, 4.42), 0.31, 0.24, seg=14 if not lod else 8)
            muz_d = 4.42
        else:
            # 12-tube 300mm BM-30 Smerch / Tornado-S / PHL-03 heavy rocket bundle!
            gp.box("paint", (-1.06, -0.04, -0.85), (1.06, 0.96, 3.85), bevel=bv)
            for ry, xs in ((0.24, (-0.75, -0.25, 0.25, 0.75)), (0.68, (-0.75, -0.25, 0.25, 0.75)), (1.08, (-0.50, -0.16, 0.16, 0.50))):
                for cx in xs:
                    gp.cyl("paint", (cx, ry, 3.55), 0.155, 0.95, seg=12 if not lod else 8, axis="z")
                    if not lod:
                        gp.tube_axis("metal_dark", (cx, ry, 4.42), (cx, ry, 4.55), 0.162, 0.125, seg=10)
            muz_d = 4.55

    muz_pt = (0.0, g_piv[1] + math.sin(0.30) * muz_d + 0.45, g_piv[2] + math.cos(0.30) * muz_d)
    rig.add("Gun", "Turret", g_piv, gp)
    rig.add("Muzzle", "Gun", muz_pt, None)
    return rig


# =============================================================================
# 44–54. COASTAL ANTI-SHIP MISSILE BATTERIES, BRAHMOS & DF-17 HYPERSONIC TELS
# =============================================================================

COASTAL_HYPERSONIC_SLUGS = [
    "coastalASM__nmesis",
    "coastalASM__nsm_coastal_defence_system",
    "coastalASM__rk_360mc_neptune",
    "coastalASM__type_12_ssm",
    "coastalASM__type_25_ssm",
    "coastalASM__yj_62_coastal_battery",
    "coastalASM__ghader_coastal_battery",
    "coastalASM__k_300p_bastion_p",
    "brahmos__brahmos_battery",
    "df17__df_17_launcher",
    "df17__type_25_hvgp",
]


def build_coastal_or_hypersonic_rig(slug: str, lod: int = 0) -> VehicleRig:
    rig = VehicleRig(lod=lod)
    bv = 0.016 if not lod else 0.0

    # Special Case: USMC NMESIS unmanned 4x4 ROGUE-Fires JLTV w/ twin NSM stealth canisters!
    if slug == "coastalASM__nmesis":
        axles = [-1.68, 1.68]
        wr, tw, wx = 0.52, 0.36, 1.02
        z0, z1, hx = -2.65, 2.60, 1.14
        hp = Part("Hull")
        hp.profile_x(
            "paint",
            [(z0 + 0.18, 0.58), (z1 - 0.35, 0.58), (z1, 1.24), (z1 - 0.95, 1.62), (0.65, 1.62), (0.55, 1.28), (z0, 1.28)],
            -hx, hx, bevel=bv, ao_y=(0.50, 2.2),
        )
        if not lod:
            hp.box("metal_dark", (-0.68, 0.78, z1 - 0.03), (0.68, 1.18, z1 + 0.02))
            hp.box("paint", (-0.34, 1.62, 0.95), (0.34, 1.88, 1.55), bevel=0.01)  # Unmanned EO/LIDAR mast pod
        rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
        for side_lbl, sx in (("L", -1), ("R", 1)):
            for i, az in enumerate(axles):
                wp = (sx * wx, wr, az)
                rig.add(f"Wheel_{side_lbl}{i}", f"LOD{lod}", wp, build_offroad_tyre(f"Wheel_{side_lbl}{i}", wp, lod, sx, r=wr, w=tw, hub_style="western", lugs=20))

        tz = -0.85
        t_piv = (0.0, 1.30, tz)
        tp = Part("Turret")
        tp.cyl("metal_dark", (0.0, 1.28, tz), 0.62, 0.18, seg=16 if not lod else 10)
        rig.add("Turret", "Hull", t_piv, tp)

        g_piv = (0.0, 1.48, tz - 0.75)
        gp = Part("Gun")
        with gp.frame(g_piv, pitch=-0.34):
            for sx in (-1, 1):
                gp.box("paint", (sx * 0.54 - 0.42, 0.0, -0.35), (sx * 0.54 + 0.42, 0.78, 3.25), bevel=bv)
                gp.box("metal_dark", (sx * 0.54 - 0.38, 0.04, 3.20), (sx * 0.54 + 0.38, 0.74, 3.30))
        muz_pt = (0.0, g_piv[1] + 1.42, g_piv[2] + 3.05)
        rig.add("Gun", "Turret", g_piv, gp)
        rig.add("Muzzle", "Gun", muz_pt, None)
        return rig

    is_df17 = slug.startswith("df17__")
    is_supersonic = slug in ("coastalASM__k_300p_bastion_p", "brahmos__brahmos_battery")
    axles = [-3.65, -2.25, -0.85, 1.85, 3.25] if is_df17 else [-3.10, -1.65, 1.65, 3.10]
    wr, tw, wx = 0.58, 0.42, 1.20
    z0, z1, hx = (-4.65 if is_df17 else -4.35), (4.55 if is_df17 else 4.25), 1.32

    hp = Part("Hull")
    hp.box("metal_dark", (-0.58, 0.74, z0), (0.58, 1.22, z1 - 0.12), bevel=bv)
    hp.box("paint", (-hx, 1.22, z0), (hx, 1.44, 1.15), bevel=bv)
    # Split/armored strategic TEL cab forward + generator/C2 shelter behind cab
    hp.profile_x(
        "paint",
        [(2.25, 1.20), (z1 - 0.10, 1.20), (z1, 1.84), (z1 - 0.32, 2.62), (2.25, 2.62)],
        -hx, hx, bevel=bv, ao_y=(0.65, 2.85),
    )
    hp.box("paint", (-hx + 0.06, 1.44, 0.95), (hx - 0.06, 2.48, 2.18), bevel=bv)
    if not lod:
        for sx in (-1, 1):
            hp.box("glass", (sx * 0.64 - 0.44, 1.98, z1 - 0.32), (sx * 0.64 + 0.44, 2.42, z1 - 0.08), tint=GLASS_ARMOUR)

    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
    hub = "western" if slug in ("coastalASM__nsm_coastal_defence_system", "coastalASM__type_12_ssm", "coastalASM__type_25_ssm", "df17__type_25_hvgp") else "eastern"
    for side_lbl, sx in (("L", -1), ("R", 1)):
        for i, az in enumerate(axles):
            wp = (sx * wx, wr, az)
            rig.add(f"Wheel_{side_lbl}{i}", f"LOD{lod}", wp, build_offroad_tyre(f"Wheel_{side_lbl}{i}", wp, lod, sx, r=wr, w=tw, hub_style=hub, lugs=22))

    tz = -1.95
    t_piv = (0.0, 1.46, tz)
    tp = Part("Turret")
    tp.cyl("metal_dark", (0.0, 1.44, tz), 0.92, 0.22, seg=18 if not lod else 10)
    tp.box("paint", (-1.05, 1.64, tz - 1.35), (1.05, 1.90, tz + 1.15), bevel=bv)
    rig.add("Turret", "Hull", t_piv, tp)

    g_piv = (0.0, 1.90, tz - 1.45)
    gp = Part("Gun")
    if is_df17:
        # DF-17 / Type 25 Hypersonic Glide Vehicle erector cradle + faceted wedge-nose HGV shroud!
        with gp.frame(g_piv, pitch=-0.26):
            gp.box("metal_dark", (-0.82, -0.05, -0.45), (0.82, 0.32, 4.85), bevel=bv)
            gp.cyl("paint", (0.0, 0.72, -0.40), 0.56, 3.85, seg=18 if not lod else 10, axis="z")
            # Faceted hypersonic boost-glide warhead nosecone!
            gp.cyl("paint", (0.0, 0.72, 3.45), 0.56, 1.95, seg=6, r2=0.06, axis="z")
        muz_pt = (0.0, g_piv[1] + 1.95, g_piv[2] + 5.15)
    elif is_supersonic:
        # Bastion-P / BrahMos massive twin/triple cylindrical supersonic cruise missile tubes!
        with gp.frame(g_piv, pitch=-0.34):
            gp.box("metal_dark", (-1.12, -0.05, -0.35), (1.12, 0.26, 4.45), bevel=bv)
            xs = (-0.68, 0.0, 0.68) if "brahmos" in slug else (-0.56, 0.56)
            for cx in xs:
                gp.cyl("paint", (cx, 0.68, -0.30), 0.36 if len(xs) == 2 else 0.30, 5.05, seg=16 if not lod else 10, axis="z")
                gp.cyl("metal_dark", (cx, 0.68, 4.72), 0.37 if len(xs) == 2 else 0.31, 0.14, seg=16 if not lod else 10, axis="z")
        muz_pt = (0.0, g_piv[1] + 2.15, g_piv[2] + 4.55)
    else:
        # Quad (`2x2`) Coastal Anti-Ship Missile Canister Cluster (`Neptune`, `Type 12`, `NSM`, `YJ-62`, `Ghader`)
        cyl_tubes = slug in ("coastalASM__rk_360mc_neptune", "coastalASM__yj_62_coastal_battery")
        with gp.frame(g_piv, pitch=-0.32):
            gp.box("metal_dark", (-1.04, -0.05, -0.35), (1.04, 0.24, 3.95), bevel=bv)
            for ry in (0.48, 1.16):
                for sx in (-1, 1):
                    if cyl_tubes:
                        gp.cyl("paint", (sx * 0.52, ry, -0.25), 0.28, 4.45, seg=14 if not lod else 8, axis="z")
                    else:
                        gp.box("paint", (sx * 0.52 - 0.36, ry - 0.28, -0.25), (sx * 0.52 + 0.36, ry + 0.28, 4.20), bevel=bv)
        muz_pt = (0.0, g_piv[1] + 1.98, g_piv[2] + 4.05)

    rig.add("Gun", "Turret", g_piv, gp)
    rig.add("Muzzle", "Gun", muz_pt, None)
    return rig


ALL_SLUGS = (
    M270_SLUGS
    + ["tos1a__tos_1a_solntsepyok"]
    + list(POD_MLRS_SPECS.keys())
    + list(TUBE_MLRS_SPECS.keys())
    + COASTAL_HYPERSONIC_SLUGS
)


def build_rig(slug: str, lod: int) -> VehicleRig:
    if slug in M270_SLUGS or slug == "tos1a__tos_1a_solntsepyok":
        return build_m270_or_tos1a_rig(slug, lod)
    if slug in POD_MLRS_SPECS:
        return build_pod_mlrs_rig(slug, lod)
    if slug in TUBE_MLRS_SPECS:
        return build_tube_mlrs_rig(slug, lod)
    return build_coastal_or_hypersonic_rig(slug, lod)


def export_one(slug: str, out_dir: str):
    init_scene()
    export_vehicle(
        os.path.join(out_dir, f"{slug}.glb"),
        build_rig(slug, 0),
        build_rig(slug, 1),
        turret_offset=(4.0, 0.0, -0.6),
        ring_radius=0.78,
    )


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
    out_dir = os.path.join(repo_root, "native", "godot", "assets", "art", "vehicles")
    os.makedirs(out_dir, exist_ok=True)
    targets = ALL_SLUGS if ("--all" in argv or not argv) else [s for s in argv if not s.startswith("--")]
    for slug in targets:
        export_one(slug, out_dir)


if __name__ == "__main__":
    main()
