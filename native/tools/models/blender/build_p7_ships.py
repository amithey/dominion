"""Blender 5.2 LTS generator for Tier P7 — All 163 Warships, Aircraft Carriers, Amphibious Ships & Submarines
(`native/godot/assets/art/ships/`).

Every model includes `LOD0`, `LOD1`, `Wreck`, plus exact `Waterline` (`y = draft`) and `Hull_Bow` (`z = L * 0.5`)
reference nodes under `LOD0` for exact waterline seating and RTS length scaling in `scripts/craft_models.gd`.
All `carrier__*` vessels also include `DeckPlane0..4` nodes on the flight deck for `scripts/war_tools.gd`.
"""
import math
import os
import sys

THIS_DIR = os.path.dirname(os.path.abspath(__file__))
if THIS_DIR not in sys.path:
    sys.path.insert(0, THIS_DIR)

import bl_vehicle as bv
import bl_craft as bc

OUT_DIR = os.path.abspath(os.path.join(THIS_DIR, "..", "..", "..", "godot", "assets", "art", "ships"))


def _sheer_at(z_world, L, bow_sheer):
    zn = z_world / max(1.0, L)
    return max(0.0, (zn - 0.20) / 0.30) ** 1.35 * bow_sheer


def _build_submarine_lod(s, lod=0):
    rig = bv.VehicleRig(lod=lod)
    slug = s["slug"]
    d = s.get("details", {})
    L = float(s["length"])
    B = float(s["beam"])
    draft = float(s["draft"])
    cy = B * 0.5
    hull = bc.CraftPart("Hull", seed=hash(slug) & 0xFFFF)

    prof = d.get("body_profile", [
        (-0.46, 0.06), (-0.38, 0.27), (-0.26, 0.45), (-0.10, 0.50),
        (0.16, 0.50), (0.33, 0.47), (0.43, 0.34), (0.48, 0.17), (0.50, 0.015),
    ])
    sections = [(float(z) * L, cy, max(0.04, B * float(r)), max(0.04, B * float(r))) for z, r in prof]

    def sub_role(z, th):
        # Anechoic dark upper hull, dark boot stripe, anti-fouling red lower belly
        y_est = cy + (B * 0.48) * math.cos(th)
        if y_est < B * 0.30:
            return "hull_red"
        if y_est < B * 0.36:
            return "dark"
        return "paint"

    hull.loft_shell("paint", sections, seg=14 if lod else 36, subdiv=1 if lod else 3,
                    role_fn=sub_role, ao_y=(0.0, B * 1.35, 0.72))

    # Sail (conning tower / fin)
    sz = float(d.get("sail_z", 0.08)) * L
    slen = float(d.get("sail_length", L * 0.15))
    sh = float(d.get("sail_height", B * 0.70))
    sbase = B * 0.88
    if d.get("faceted_sail"):
        hull.chamfer_house(0.0, sbase, sz, B * 0.30, sh, slen, taper=0.58, roof_deck=False, lod=lod)
    else:
        # Smooth hydrodynamic sail with leading-edge fillet
        hull.loft_shell("paint", [
            (sz - slen * 0.50, sbase + sh * 0.48, B * 0.03, sh * 0.44),
            (sz - slen * 0.32, sbase + sh * 0.50, B * 0.14, sh * 0.52),
            (sz + slen * 0.28, sbase + sh * 0.50, B * 0.15, sh * 0.52),
            (sz + slen * 0.50, sbase + sh * 0.46, B * 0.035, sh * 0.42),
        ], seg=10 if lod else 22, subdiv=1 if lod else 2, ao_y=(sbase, sbase + sh * 1.1, 0.80))

    # Sail bridge cockpit recess, national pennant & periscope/optronics masts
    top_s = sbase + sh
    for sgn in (-1, 1):
        hull.box("markings", (sgn * B * 0.145, sbase + sh * 0.42, sz - slen * 0.10),
                 (sgn * B * 0.162, sbase + sh * 0.62, sz + slen * 0.12))
    if not lod:
        for pi in range(3):
            pz = sz + (pi - 1.0) * slen * 0.18
            ph = B * (0.28 - pi * 0.04)
            hull.cyl("metal_dark", (0.0, top_s - 0.15, pz), max(0.04, B * 0.016), ph + 0.15, seg=8)
            hull.box("glass", (-B * 0.03, top_s + ph - 0.04, pz), (B * 0.03, top_s + ph + 0.04, pz + B * 0.06))

    # SSBN / VLS Ballistic/Cruise Missile Turtleback Deck & Silo Hatches
    m_cells = int(d.get("missile_cells", 0))
    if m_cells > 0:
        mpitch = float(d.get("missile_pitch", L * 0.028))
        mstart = float(d.get("missile_start", sz - slen * 0.72))
        rows = math.ceil(m_cells / 2)
        mroof = B * (0.88 + float(d.get("missile_deck_height", 0.18)))
        z_mid = mstart - (rows - 1) * mpitch * 0.5
        hull.chamfer_house(0.0, B * 0.82, z_mid, B * 0.72, mroof - B * 0.82, rows * mpitch + mpitch * 0.8,
                           taper=0.92, roof_deck=False, lod=lod)
        if not lod:
            mrad = B * float(d.get("missile_radius", 0.10))
            for i in range(m_cells):
                mx = (-1.0 if i % 2 == 0 else 1.0) * B * 0.19
                mz = mstart - (i // 2) * mpitch
                hull.cyl("metal_dark", (mx, mroof - 0.02, mz), mrad, 0.07, seg=12)

    # Bow or Fairwater (Sail) Diving Planes
    fplanes = d.get("foreplanes", "bow")
    if fplanes != "none":
        py = (sbase + sh * 0.46) if fplanes == "sail" else (cy + B * 0.06)
        pz = sz + slen * 0.08 if fplanes == "sail" else L * 0.27
        proot = B * (0.11 if fplanes == "sail" else 0.38)
        pspan = B * (0.62 if fplanes == "sail" else 0.80)
        for m_x in (False, True):
            hull.airfoil_wing("paint", [
                (proot, py, pz + L * 0.018, pz - L * 0.018),
                (pspan, py, pz + L * 0.004, pz - L * 0.016),
            ], chord_steps=5, span_steps=1, thickness=0.09, mirror_x=m_x)

    # Stern Control Surfaces (Cruciform or X-Tail)
    angles = (45.0, 135.0, 225.0, 315.0) if d.get("x_tail") else (0.0, 90.0, 180.0, 270.0)
    tz_s = -L * 0.41
    for deg in angles:
        with hull.frame((0.0, cy, 0.0), roll=math.radians(deg)):
            hull.airfoil_wing("paint", [
                (B * 0.08, 0.0, tz_s + L * 0.026, tz_s - L * 0.034),
                (B * 0.49, 0.0, tz_s - L * 0.002, tz_s - L * 0.030),
            ], chord_steps=5, span_steps=1, thickness=0.09)

    # Multi-blade Skewed Screw Propeller(s) & Optional Pumpjet Shroud
    n_prop = int(d.get("propellers", 1))
    pr = B * float(d.get("prop_radius", 0.30))
    pblades = int(d.get("prop_blades", 7))
    for i in range(n_prop):
        px = (i - (n_prop - 1) * 0.5) * B * 0.60
        pz_p = -L * 0.482
        hull.cyl("metal_dark", (px, cy, pz_p - 0.35), pr * 0.22, 0.72, seg=8 if lod else 16, r2=pr * 0.08, axis="z")
        with hull.frame((px, cy, pz_p), pitch=math.pi * 0.5):
            hull.rotor_hub_and_blades(pr, pblades, lod=lod, chord=pr * 0.18, yellow_tips=False)
        if d.get("pumpjet"):
            hull.tube_axis("paint", (px, cy, pz_p - 0.48), (px, cy, pz_p + 0.42), pr * 1.12, pr * 0.98, seg=12 if lod else 26)

    rig.add("Hull", rig.root_name, (0.0, 0.0, 0.0), hull)

    # Surface-search Radar mast on Sail (`Radar` node spins when surfaced)
    rz_s = sz - slen * 0.24
    ry_s = top_s + B * 0.22
    rad = bc.CraftPart("Radar", seed=81)
    rad.cyl("metal_dark", (0.0, top_s - 0.12, rz_s), max(0.04, B * 0.018), B * 0.34 + 0.12, seg=8)
    rad.box("metal_dark", (-B * 0.10, ry_s, rz_s - B * 0.025), (B * 0.10, ry_s + B * 0.055, rz_s + B * 0.025))
    rig.add("Radar", "Hull", (0.0, ry_s, rz_s), rad)
    return rig


def _build_surface_ship_lod(s, lod=0):
    rig = bv.VehicleRig(lod=lod)
    slug = s["slug"]
    d = s.get("details", {})
    L = float(s["length"])
    B = float(s["beam"])
    hull_B = float(d.get("hull_beam", B))
    draft = float(s["draft"])
    freeboard = float(s["freeboard"])
    D = draft + freeboard
    bow_sheer = float(d.get("bow_sheer", 1.7))
    unmanned = bool(d.get("unmanned", False))
    av_deck = bool(d.get("aviation_deck", False))
    is_carrier = slug.startswith("carrier__")

    hull = bc.CraftPart("Hull", seed=hash(slug) & 0xFFFF)
    prof = d.get("hull_profile", [
        (-0.50, 0.65), (-0.45, 0.80), (-0.30, 0.96), (-0.10, 1.00),
        (0.12, 1.00), (0.30, 0.86), (0.41, 0.55), (0.48, 0.18), (0.50, 0.012),
    ])

    # ------------------------------------------------------------ 1. Flared Naval Hull (Monohull or Wave-Piercing Catamaran)
    if d.get("catamaran"):
        demi = float(d.get("demi_beam", B * 0.24))
        for sgn in (-1, 1):
            with hull.frame((sgn * (B - demi) * 0.5, 0.0, 0.0)):
                hull.naval_hull(L, demi, draft, freeboard, prof, bow_sheer=bow_sheer * 0.6, lod=lod, bulb=False)
        hull.chamfer_house(0.0, D - 0.85, -L * 0.06, B - 0.35, 0.90, L * 0.84, taper=0.98, roof_deck=True, lod=lod)
    else:
        hull.naval_hull(L, hull_B, draft, freeboard, prof, bow_sheer=bow_sheer, lod=lod, bulb=(L >= 80.0))

    # Hull bow pennant number / national stripe (`markings`) & anchors/bollards
    if not unmanned:
        zp = L * 0.37
        yp = D * 0.68
        # Interpolate half-width at z=0.37
        wf_p = 0.68
        for sgn in (-1, 1):
            px = sgn * (hull_B * 0.5 * wf_p * 0.92)
            hull.box("markings", (px - 0.06, yp - min(0.65, freeboard * 0.22), zp - min(1.8, L * 0.025)),
                     (px + 0.06, yp + min(0.65, freeboard * 0.22), zp + min(1.8, L * 0.025)))
            if not lod and not av_deck and L >= 35.0:
                # Anchor hawse & foredeck bollards
                hull.pipe("metal_dark", (px * 0.96, yp + 0.2, L * 0.41), (px * 0.93, yp - 0.5, L * 0.405), 0.14, seg=6)
                for bz in (L * 0.39, -L * 0.43):
                    hull.cyl("metal_dark", (sgn * hull_B * 0.26, D + (_sheer_at(bz, L, bow_sheer) if bz > 0 else 0.0), bz), 0.16, 0.48, seg=8)

    # ------------------------------------------------------------ 2. Superstructure Deckhouses, Bridge, Hangar & Boats
    for idx, item in enumerate(d.get("houses", [])):
        hx, hz, hw, hl, hh, hbase, htaper = [float(v) for v in item]
        y0 = D + hbase
        hull.chamfer_house(hx, y0, hz, hw, hh, hl, taper=htaper, roof_deck=True, lod=lod)
        if idx == 0 and not unmanned:
            # Framed Bridge Windows + Sun-Glare Visor Brow + Bridge Wings
            wy = y0 + hh * 0.72
            z_front = hz + 0.5 * hl * (1.0 - (1.0 - htaper) * 0.72)
            n_win = 4 if lod else 8
            win_span = hw * htaper * 0.72
            for wi in range(n_win):
                wx = hx - win_span * 0.5 + win_span * (wi + 0.5) / n_win
                ww = (win_span / n_win) * 0.38
                hull.box("glass", (wx - ww, wy - 0.28, z_front - 0.06), (wx + ww, wy + 0.30, z_front + 0.08))
            if not lod:
                hull.box("paint", (hx - win_span * 0.56, wy + 0.30, z_front - 0.12),
                         (hx + win_span * 0.56, wy + 0.42, z_front + 0.24), bevel=0.02)
                # White SATCOM radome spheres atop bridge/superstructure
                if L >= 65.0:
                    sr_d = min(0.95, hw * 0.12)
                    for sgn in (-1, 1):
                        hull.cyl("paint", (hx + sgn * hw * 0.24, y0 + hh, hz - hl * 0.18), sr_d * 0.45, 0.35, seg=8)
                        hull.dome("radome", (hx + sgn * hw * 0.24, y0 + hh + 0.32, hz - hl * 0.18), sr_d, sr_d * 1.05, seg=12, rings=3)
                    hull.dome("radome", (hx + sgn * hw * 0.24, y0 + hh + 0.32, hz - hl * 0.18), sr_d, -sr_d * 0.45, seg=12, rings=2)

    # Helicopter Hangar Shutters & Aft Helipad Markings (on non-carrier combatants)
    if d.get("hangar", True) and not av_deck and L >= 50.0:
        h_z = float(d.get("hangar_z", -L * 0.24))
        n_doors = int(d.get("hangar_doors", 1))
        for di in range(n_doors):
            dx = (di - (n_doors - 1) * 0.5) * hull_B * 0.30
            hull.box("metal_dark", (dx - hull_B * 0.12, D + 0.15, h_z - 0.12),
                     (dx + hull_B * 0.12, D + 4.35, h_z + 0.12))
    if d.get("flight_deck", True) and not av_deck and L >= 50.0:
        fz = -L * 0.37
        fy = D + float(d.get("aviation_y", 0.0)) + 0.04
        fr = min(hull_B * 0.32, L * 0.055)
        hull.tube_axis("white", (0, fy - 0.02, fz), (0, fy + 0.03, fz), fr, fr * 0.89, seg=12 if lod else 24)
        for sx_h in (-fr * 0.28, fr * 0.28):
            hull.box("white", (sx_h - 0.08, fy - 0.01, fz - fr * 0.38), (sx_h + 0.08, fy + 0.03, fz + fr * 0.38))
        hull.box("white", (-fr * 0.28, fy - 0.01, fz - 0.08), (fr * 0.28, fy + 0.03, fz + 0.08))

    # Amidships RHIB boats & liferaft canisters
    if not av_deck and not unmanned and not lod and L >= 55.0:
        for sgn in (-1, 1):
            bx = sgn * hull_B * 0.39
            hull.chamfer_house(bx, D + 0.25, -L * 0.08, 1.65, 0.60, 5.4, taper=0.80, role="rubber", roof_deck=False, lod=1)
            hull.box("paint", (bx - 0.45, D + 0.82, -L * 0.08 - 0.8), (bx + 0.45, D + 1.25, -L * 0.08 + 0.6), bevel=0.05)
            for li in range(4):
                hull.cyl("white", (bx - 0.38, D + 1.05, L * 0.01 + li * 1.35), 0.32, 0.76, seg=10, axis="x")

    # ------------------------------------------------------------ 3. Exhaust Funnels, Masts & Fixed Phased-Array Radars
    for fx, fz, fw, fl, fh, fbase in d.get("funnels", []):
        fx, fz, fw, fl, fh, fbase = float(fx), float(fz), float(fw), float(fl), float(fh), float(fbase)
        hull.chamfer_house(fx, D + fbase, fz, fw, fh, fl, taper=0.76, roof_deck=False, lod=lod)
        hull.chamfer_house(fx, D + fbase + fh - 0.05, fz, fw * 0.72, 0.45, fl * 0.72, taper=0.88, role="dark", roof_deck=False, lod=1)
        if not lod:
            for ui in (-0.18, 0.18):
                hull.cyl("metal_dark", (fx, D + fbase + fh + 0.15, fz + fl * ui), min(fw, fl) * 0.18, 0.45, seg=10)

    # Static Masts & Fixed SPY / APAR / MF-STAR / Type 346 Phased-Array Faces
    masts = d.get("masts", [])
    mast_offs = d.get("mast_offsets", [0.0] * len(masts))
    spin_pivot = None
    spin_style = "bar"
    spin_w = 3.0

    for mi, (mz, mh, mstyle, mw) in enumerate(masts):
        mz, mh, mw = float(mz), float(mh), float(mw)
        mx = float(mast_offs[mi]) if mi < len(mast_offs) else 0.0
        if unmanned:
            hull.cyl("metal_dark", (mx, D + 0.2, mz), 0.06, max(0.8, mh - 0.2), seg=8)
            if mi == 0:
                spin_pivot = (mx, D + mh, mz)
                spin_style, spin_w = "usv", 0.35
            continue
        roofs = [float(a[5]) + float(a[4]) for a in d.get("houses", []) if abs(mx - float(a[0])) <= float(a[2]) * 0.55 and abs(mz - float(a[1])) <= float(a[3]) * 0.55]
        mbase = D + max(roofs, default=0.1) - 0.10
        mtop = max(mbase + 1.2, D + mh)
        hull.chamfer_house(mx, mbase, mz, mw * 0.52, mtop - mbase, mw * 0.62, taper=0.48, roof_deck=False, lod=lod)
        # Yardarms
        for yy in ((mtop - 1.0,) if lod else (mtop - 3.6, mtop - 1.0)):
            if yy > mbase + 0.6:
                hull.pipe("paint", (mx - mw * 0.85, yy, mz), (mx + mw * 0.85, yy, mz), 0.11, seg=6)
        if mstyle == "enclosed":
            hull.cyl("radome", (mx, mtop - 0.15, mz), mw * 0.52, 3.1, seg=10 if lod else 20, r2=mw * 0.42)
        elif mstyle == "sphere":
            hull.dome("radome", (mx, mtop + mw * 0.35, mz), mw * 0.55, mw * 0.60, seg=12 if lod else 20, rings=3)
            hull.dome("radome", (mx, mtop + mw * 0.35, mz), mw * 0.55, -mw * 0.45, seg=12 if lod else 20, rings=2)
        elif mi == 0:
            spin_pivot = (mx, mtop, mz)
            spin_style, spin_w = mstyle, mw
        else:
            hull.box("metal_dark", (mx - mw * 0.48, mtop, mz - 0.22), (mx + mw * 0.48, mtop + 0.85, mz + 0.22))

    if d.get("fixed_arrays"):
        faz, fay, faw = [float(v) for v in d["fixed_arrays"]]
        ay_c = D + fay
        hull.chamfer_house(0.0, ay_c - faw * 0.24, faz, faw * 0.92, faw * 0.48, faw * 0.92, taper=0.92, roof_deck=True, lod=lod)
        # Four octagonal AESA radar panels angled at 45 deg
        pr_a = faw * 0.20
        for s_x in (-1, 1):
            for s_z in (-1, 1):
                yaw_a = math.atan2(s_x, s_z)
                hull.box("metal_dark",
                         (s_x * faw * 0.32 - pr_a, ay_c - pr_a * 0.85, faz + s_z * faw * 0.32 - 0.08),
                         (s_x * faw * 0.32 + pr_a, ay_c + pr_a * 0.85, faz + s_z * faw * 0.32 + 0.08),
                         yaw=yaw_a, bevel=0.04)

    # ------------------------------------------------------------ 4. VLS Cells, Anti-Ship Canisters & CIWS / SAM Mounts
    for vz, vcols, vrows, vpitch, vyoff in d.get("vls", []):
        vz, vcols, vrows, vpitch, vyoff = float(vz), int(vcols), int(vrows), float(vpitch), float(vyoff)
        vy = D + vyoff + (_sheer_at(vz, L, bow_sheer) if vyoff == 0.0 and vz > 0 else 0.0)
        vw = vcols * vpitch + 0.28
        vl = vrows * vpitch + 0.28
        hull.box("paint", (-vw * 0.5, vy - 0.15, vz - vl * 0.5), (vw * 0.5, vy + 0.18, vz + vl * 0.5), bevel=0.03)
        if not lod:
            for c_i in range(vcols):
                for r_i in range(vrows):
                    cx = (c_i - (vcols - 1) * 0.5) * vpitch
                    cz = vz + (r_i - (vrows - 1) * 0.5) * vpitch
                    if d.get("vls_carousel"):
                        hull.cyl("metal_dark", (cx, vy + 0.14, cz), vpitch * 0.40, 0.10, seg=10)
                    else:
                        hs = vpitch * 0.40
                        hull.box("metal_dark", (cx - hs, vy + 0.16, cz - hs), (cx + hs, vy + 0.24, cz + hs))

    for cz_c, cyoff_c, c_cnt in d.get("canisters", []):
        cz_c, cyoff_c, c_cnt = float(cz_c), float(cyoff_c), int(c_cnt)
        cy_c = D + cyoff_c
        for sgn in (-1, 1):
            hull.box("metal_dark", (sgn * 0.6, cy_c, cz_c - c_cnt * 0.38), (sgn * 3.4, cy_c + 1.1, cz_c + c_cnt * 0.38))
            for j in range(c_cnt):
                jz = cz_c + (j - (c_cnt - 1) * 0.5) * 0.76
                hull.pipe("paint", (sgn * 0.4, cy_c + 0.9, jz), (sgn * 4.1, cy_c + 2.45, jz), 0.32, seg=8 if lod else 12)
                hull.pipe("metal_dark", (sgn * 4.1, cy_c + 2.45, jz), (sgn * 4.22, cy_c + 2.50, jz), 0.29, seg=8 if lod else 12)

    ciws_list = d.get("ciws", [])
    ciws_styles = d.get("ciws_styles", [d.get("ciws_style", "phalanx")] * len(ciws_list))
    for ci, (cx_w, cz_w, cy_w) in enumerate(ciws_list):
        cx_w, cz_w, cy_w = float(cx_w), float(cz_w), float(cy_w)
        cstyle = ciws_styles[ci] if ci < len(ciws_styles) else "phalanx"
        wy_c = D + cy_w
        hull.cyl("paint", (cx_w, wy_c - 0.1, cz_w), 0.72, 1.05, seg=8 if lod else 14)
        if cstyle in ("ram", "crotale"):
            hull.box("paint", (cx_w - 0.95, wy_c + 0.9, cz_w - 0.95), (cx_w + 0.95, wy_c + 2.35, cz_w + 0.95), bevel=0.06)
            hull.box("metal_dark", (cx_w - 0.78, wy_c + 1.08, cz_w + 0.90), (cx_w + 0.78, wy_c + 2.18, cz_w + 1.04))
        else:
            # Iconic Phalanx "R2-D2" white radome + 20mm Gatling barrel
            hull.box("paint", (cx_w - 0.65, wy_c + 0.9, cz_w - 0.55), (cx_w + 0.65, wy_c + 1.85, cz_w + 0.55), bevel=0.04)
            hull.cyl("radome", (cx_w, wy_c + 1.82, cz_w), 0.50, 1.05, seg=10 if lod else 16)
            hull.dome("radome", (cx_w, wy_c + 2.85, cz_w), 0.50, 0.45, seg=10 if lod else 16, rings=3)
            hull.pipe("metal_dark", (cx_w, wy_c + 1.42, cz_w + 0.45), (cx_w, wy_c + 1.42, cz_w + 2.05), 0.10, seg=8)

    # Secondary Guns (if ship has multiple turrets;Gun #0 is articulated `Turret` node below!)
    guns = d.get("guns", [])
    for gi in range(1, len(guns)):
        g = guns[gi]
        gx, gz, gcal, glen = float(g[0]), float(g[1]), float(g[2]), float(g[3])
        gbase = float(g[4]) if len(g) > 4 else 0.0
        gaft = bool(g[5]) if len(g) > 5 else (gz < 0)
        gy = D + gbase + (_sheer_at(gz, L, bow_sheer) if gbase == 0.0 and gz > 0 else 0.0)
        big = gcal >= 100.0
        hull.cyl("metal_dark", (gx, gy - 0.1, gz), 1.55 if big else 0.98, 0.42, seg=10 if lod else 18)
        hull.chamfer_house(gx, gy + 0.28, gz, 3.0 if big else 2.0, 2.1 if big else 1.55, 3.3 if big else 2.2, taper=0.56, roof_deck=False, lod=lod)
        sgn_g = -1.0 if gaft else 1.0
        hull.tube_axis("metal_dark", (gx, gy + (1.45 if big else 1.15), gz + sgn_g * 0.6),
                       (gx, gy + (1.45 if big else 1.15), gz + sgn_g * (0.6 + glen)),
                       max(0.08, gcal / 1000.0 * 0.72), max(0.04, gcal / 1000.0 * 0.38), seg=8 if lod else 14)

    # ------------------------------------------------------------ 5. Amphibious Well-Deck Ramp & Carrier Flight Deck
    if d.get("landing"):
        bow_r = bool(d.get("bow_ramp", False))
        rz_l = L * 0.50 if bow_r else -L * 0.50
        rh_l = float(d.get("ramp_height", min(6.0, freeboard + 1.0)))
        hull.box("metal_dark", (-hull_B * 0.20, draft + 0.20, rz_l - 0.18),
                 (hull_B * 0.20, draft + 0.20 + rh_l, rz_l + 0.18), bevel=0.03)

    if av_deck:
        W_deck = float(d.get("deck_beam", B))
        y_av = D + float(d.get("aviation_y", 0.0))
        if d.get("deck_outline"):
            poly = [(float(px) * W_deck, float(pz) * L) for px, pz in d["deck_outline"]]
            hull.prism_y("paint", poly, y_av - 0.75, y_av - 0.05, ao_y=(D, y_av, 0.80))
            hull.prism_y("deck", poly, y_av - 0.05, y_av + 0.04)
        else:
            hull.chamfer_house(0.0, y_av - 0.72, -L * 0.01, W_deck, 0.72, L * 0.96, taper=0.995, role="paint", roof_deck=False, lod=lod)
            hull.chamfer_house(0.0, y_av - 0.04, -L * 0.01, W_deck * 0.985, 0.08, L * 0.95, taper=0.998, role="deck", roof_deck=False, lod=lod)

        # Sponsons & Aircraft Elevators
        for sx_s, sz_s, sw_s, sl_s in d.get("sponsons", []):
            sx_s, sz_s, sw_s, sl_s = float(sx_s), float(sz_s), float(sw_s), float(sl_s)
            hull.box("paint", (sx_s - sw_s * 0.5, y_av - 0.70, sz_s - sl_s * 0.5),
                     (sx_s + sw_s * 0.5, y_av - 0.02, sz_s + sl_s * 0.5), bevel=0.04)
        for ex_e, ez_e in d.get("elevators", []):
            ex_e, ez_e = float(ex_e), float(ez_e)
            ew_e = min(15.0, W_deck * 0.26)
            el_e = L * 0.072
            hull.box("deck", (ex_e - ew_e * 0.5, y_av - 0.35, ez_e - el_e * 0.5),
                     (ex_e + ew_e * 0.5, y_av + 0.03, ez_e + el_e * 0.5), tint=(0.88, 0.90, 0.92))
            hull.box("white", (ex_e - ew_e * 0.5, y_av + 0.02, ez_e - el_e * 0.5),
                     (ex_e - ew_e * 0.5 + 0.22, y_av + 0.055, ez_e + el_e * 0.5))

        # Flight Deck Runway Stripes, Angled Deck Stripes, Catapult Tracks & Bow Ski-Jump!
        xx_r = -W_deck * 0.12
        r_len = L * (0.68 if d.get("deck_outline") else 0.80)
        for rx_s in (xx_r - W_deck * 0.15, xx_r + W_deck * 0.15):
            hull.box("white", (rx_s - 0.14, y_av + 0.03, -r_len * 0.5), (rx_s + 0.14, y_av + 0.06, r_len * 0.5))
        n_dash = 7 if lod else 16
        for di in range(n_dash):
            dz = -r_len * 0.46 + r_len * 0.90 * (di / max(1, n_dash - 1))
            hull.box("white", (xx_r - 0.12, y_av + 0.03, dz - 1.8), (xx_r + 0.12, y_av + 0.06, dz + 1.8))

        if d.get("angled_deck"):
            th_a = math.radians(float(d["angled_deck"]))
            for sgn_a in (-1, 1):
                hull.box("white", (-W_deck * 0.10 + sgn_a * W_deck * 0.075 - 0.14, y_av + 0.035, -L * 0.33),
                         (-W_deck * 0.10 + sgn_a * W_deck * 0.075 + 0.14, y_av + 0.065, L * 0.07), yaw=th_a)

        for cat in d.get("catapults", []):
            cx_c, cz_c = float(cat[0]), float(cat[1])
            clen = float(cat[2]) if len(cat) > 2 else L * 0.20
            cth = math.radians(float(cat[3]) if len(cat) > 3 else 0.0)
            hull.box("metal_dark", (cx_c - 0.16, y_av + 0.03, cz_c - clen * 0.5),
                     (cx_c + 0.16, y_av + 0.065, cz_c + clen * 0.5), yaw=cth)

        if d.get("ski_jump"):
            sj_w = W_deck * 0.42
            sj_z0 = L * 0.30
            sj_len = L * 0.175
            steps = 4 if lod else 10
            for j in range(steps):
                t0, t1 = j / steps, (j + 1) / steps
                za, zb = sj_z0 + sj_len * t0, sj_z0 + sj_len * t1
                ya, yb = y_av + (t0 ** 2) * 3.4, y_av + (t1 ** 2) * 3.4
                hull.prism_x("paint", [(y_av - 0.15, za), (y_av - 0.15, zb), (yb - 0.05, zb), (ya - 0.05, za)],
                             xx_r - sj_w * 0.5, xx_r + sj_w * 0.5)
                hull.prism_x("deck", [(ya - 0.05, za), (yb - 0.05, zb), (yb + 0.04, zb), (ya + 0.04, za)],
                             xx_r - sj_w * 0.49, xx_r + sj_w * 0.49)

    rig.add("Hull", rig.root_name, (0.0, 0.0, 0.0), hull)

    # ------------------------------------------------------------ 6. Articulated Primary Bow Turret (`Turret` -> `Gun` -> `Muzzle`)
    if guns:
        g0 = guns[0]
        gx, gz, gcal, glen = float(g0[0]), float(g0[1]), float(g0[2]), float(g0[3])
        gbase = float(g0[4]) if len(g0) > 4 else 0.0
        gaft = bool(g0[5]) if len(g0) > 5 else False
        gy = D + gbase + (_sheer_at(gz, L, bow_sheer) if gbase == 0.0 and gz > 0 else 0.0)
        big = gcal >= 100.0
        tp = (gx, gy + 0.18, gz)
        tur = bc.CraftPart("Turret", seed=91)
        tur.cyl("metal_dark", (gx, gy - 0.10, gz), 1.65 if big else 1.02, 0.42, seg=10 if lod else 20)
        tur.chamfer_house(gx, gy + 0.28, gz, 3.1 if big else 2.1, 2.20 if big else 1.65, 3.4 if big else 2.3,
                          taper=0.54, roof_deck=False, lod=lod)
        rig.add("Turret", "Hull", tp, tur)

        sgn_g = -1.0 if gaft else 1.0
        gp = (gx, gy + (1.52 if big else 1.22), gz + sgn_g * 0.45)
        gun = bc.CraftPart("Gun", seed=92)
        n_bar = int(d.get("gun_barrels", 1))
        for bi in range(n_bar):
            bx_o = (0.0 if n_bar == 1 else (-0.24 if bi == 0 else 0.24))
            gun.tube_axis("metal_dark", (gp[0] + bx_o, gp[1], gp[2]),
                          (gp[0] + bx_o, gp[1], gp[2] + sgn_g * glen),
                          max(0.08, gcal / 1000.0 * 0.72), max(0.04, gcal / 1000.0 * 0.36), seg=8 if lod else 14)
        rig.add("Gun", "Turret", gp, gun)
        rig.add("Muzzle", "Gun", (gp[0], gp[1], gp[2] + sgn_g * glen), None)

    # ------------------------------------------------------------ 7. Articulated Spinning Search Radar (`Radar` node)
    if spin_pivot is not None:
        rx_m, ry_m, rz_m = spin_pivot
        rad = bc.CraftPart("Radar", seed=95)
        if spin_style == "usv":
            rad.cyl("radome", (rx_m, ry_m, rz_m), 0.18, 0.26, seg=10)
            rad.box("glass", (rx_m - 0.09, ry_m + 0.06, rz_m + 0.14), (rx_m + 0.09, ry_m + 0.18, rz_m + 0.20))
        elif spin_style == "panel":
            # SMART-L / SAMPSON / EMPAR rotating planar array
            rad.cyl("metal_dark", (rx_m, ry_m - 0.1, rz_m), 0.55, 0.35, seg=10)
            rad.box("metal_dark", (rx_m - spin_w * 0.5, ry_m + 0.22, rz_m - 0.28),
                    (rx_m + spin_w * 0.5, ry_m + 2.10, rz_m + 0.28), yaw=0.0, pitch=-0.12, bevel=0.05)
        else:
            # Slotted waveguide / open-lattice search radar scanner bar
            rad.cyl("metal_dark", (rx_m, ry_m - 0.08, rz_m), 0.38, 0.32, seg=8)
            rad.box("white", (rx_m - spin_w * 0.5, ry_m + 0.22, rz_m - 0.18),
                    (rx_m + spin_w * 0.5, ry_m + 0.82, rz_m + 0.18), bevel=0.03)
        rig.add("Radar", "Hull", spin_pivot, rad)

    return rig


def _carrier_deck_nodes(s):
    """Build 5 `DeckPlane0..4` parked aircraft/UCAV nodes on a carrier's flight deck for `war_tools.gd`."""
    slug = s["slug"]
    d = s.get("details", {})
    L = float(s["length"])
    B = float(s["beam"])
    W_deck = float(d.get("deck_beam", B))
    y_av = float(s["draft"]) + float(s["freeboard"]) + float(d.get("aviation_y", 0.0)) + 0.05
    is_drone_carrier = any(k in slug for k in ("drone_carrier", "anadolu", "bagheri", "sriwijaya"))
    style = "drone" if is_drone_carrier else "f35"

    # Park along starboard/aft deck clear of runway & island
    nodes = []
    spots = [
        (W_deck * 0.24, -L * 0.36),
        (W_deck * 0.24, -L * 0.26),
        (-W_deck * 0.30, -L * 0.28),
        (-W_deck * 0.30, -L * 0.16),
        (W_deck * 0.22, L * 0.24),
    ]
    for i, (px, pz) in enumerate(spots):
        dp = bc.make_carrier_deck_plane(style=style, idx=i)
        # Rotate slightly inward toward runway
        with_part = bc.CraftPart(f"DeckPlane{i}", seed=300 + i)
        yaw = -0.45 if px > 0 else 0.45
        with with_part.frame((px, y_av, pz), yaw=yaw):
            for ri, rname in enumerate(dp.roles):
                sub = dp.bm.copy()
                kill = [f for f in sub.faces if f.material_index != ri]
                if kill:
                    import bmesh
                    bmesh.ops.delete(sub, geom=kill, context="FACES")
                if sub.faces:
                    with_part.add(rname, sub, None)
                sub.free()
        dp.bm.free()
        nodes.append((f"DeckPlane{i}", "Hull", (px, y_av, pz), with_part))
    return nodes


def build_one(spec):
    slug = spec["slug"]
    out_path = os.path.join(OUT_DIR, f"{slug}.glb")
    d = spec.get("details", {})
    L = float(spec["length"])
    draft = float(spec["draft"])

    if d.get("submarine") or spec.get("family") == "submarine":
        lod0 = _build_submarine_lod(spec, lod=0)
        lod1 = _build_submarine_lod(spec, lod=1)
    else:
        lod0 = _build_surface_ship_lod(spec, lod=0)
        lod1 = _build_surface_ship_lod(spec, lod=1)

    extra = [
        ("Waterline", "Hull", (0.0, draft, 0.0), None),
        ("Hull_Bow", "Hull", (0.0, draft, L * 0.5), None),
    ]
    if slug.startswith("carrier__"):
        extra.extend(_carrier_deck_nodes(spec))

    bc.export_craft(out_path, lod0, lod1, extra_lod0_nodes=extra, wreck_roll=22.0)


def main():
    bv.init_scene()
    specs = bc.load_specs()["P7"]
    only = [a for a in sys.argv[sys.argv.index("--") + 1:] if not a.startswith("-")] if "--" in sys.argv else []
    keys = [k for k in sorted(specs) if not only or any(o in k for o in only)]
    print(f"Building {len(keys)} P7 naval ships & submarines in Blender 5.2 LTS...")
    for k in keys:
        build_one(specs[k])
    print(f"P7 COMPLETE: {len(keys)} / {len(specs)} naval vessels exported to {OUT_DIR}")


if __name__ == "__main__":
    main()
