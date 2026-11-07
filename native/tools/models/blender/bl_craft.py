"""Blender 5.2 LTS modelling & hierarchical glTF export toolkit for DOMINION Air & Naval units (Tiers P5-P7).

Coordinates match the game and bl_vehicle.py: metres, +x right, +y up, +z front,
lowest point at y = 0 in the .glb (ships carry a `Waterline` marker node at `y = draft`
and `Hull_Bow` at `z = length * 0.5` so `scripts/craft_models.gd` seats every hull
at its true waterline and RTS length).
"""
import json
import math
import os
import sys
import bpy
import bmesh
from mathutils import Vector, Matrix

THIS_DIR = os.path.dirname(os.path.abspath(__file__))
if THIS_DIR not in sys.path:
    sys.path.insert(0, THIS_DIR)

from bl_kit import P
import bl_vehicle as bv

# Extend preview palette for Blender studio renders & glTF material slot names
bv.PREVIEW.update({
    "hull_red": (0.44, 0.13, 0.10),
    "deck": (0.19, 0.21, 0.23),
    "radome": (0.74, 0.75, 0.73),
    "white": (0.88, 0.89, 0.88),
})

SPECS_PATH = os.path.join(THIS_DIR, "craft_specs.json")


def load_specs():
    with open(SPECS_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def clear_scene_fast():
    """Fast scene wipe between batch exports in a single Blender process."""
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)


def _signed_pow(v, p):
    return math.copysign(abs(v) ** p, v)


def _hermite_stations(sections, subdiv=3):
    """Monotone-safe cubic Hermite interpolation of [(z, cy, rx, ry), ...] along z."""
    n = len(sections)
    if n < 2 or subdiv <= 1:
        return [tuple(float(v) for v in s) for s in sections]
    zs = [float(s[0]) for s in sections]
    vals = [[float(s[1]), float(s[2]), float(s[3])] for s in sections]
    hs = [zs[i + 1] - zs[i] for i in range(n - 1)]
    slopes = []
    for i in range(n - 1):
        h = hs[i] if abs(hs[i]) > 1e-6 else 1e-6
        slopes.append([(vals[i + 1][k] - vals[i][k]) / h for k in range(3)])
    tangents = [[0.0, 0.0, 0.0] for _ in range(n)]
    tangents[0] = list(slopes[0])
    tangents[-1] = list(slopes[-1])
    for i in range(1, n - 1):
        for k in range(3):
            u, v = slopes[i - 1][k], slopes[i][k]
            if u * v > 0.0 and abs(hs[i - 1]) > 1e-6 and abs(hs[i]) > 1e-6:
                tangents[i][k] = (hs[i - 1] + hs[i]) / (hs[i - 1] / u + hs[i] / v)
    out = []
    for i in range(n - 1):
        h = hs[i]
        for step in range(subdiv):
            t = step / subdiv
            h00 = 2 * t ** 3 - 3 * t ** 2 + 1
            h10 = t ** 3 - 2 * t ** 2 + t
            h01 = -2 * t ** 3 + 3 * t ** 2
            h11 = t ** 3 - t ** 2
            row = [zs[i] + t * h]
            for k in range(3):
                val = h00 * vals[i][k] + h10 * h * tangents[i][k] + h01 * vals[i + 1][k] + h11 * h * tangents[i + 1][k]
                if k >= 1:
                    val = max(0.003, val)
                row.append(val)
            out.append(tuple(row))
    out.append(tuple(float(v) for v in sections[-1]))
    return out


class CraftPart(bv.Part):
    """Extended BMesh builder for smooth lofted airframes, airfoils, rotors, and flared naval hulls."""

    def add_multi(self, bm, face_roles, face_tints=None, ao_y=None, jitter=0.0):
        """Append a single welded `bm` whose faces carry per-face role names & tints so smooth normals weld across rings."""
        for r in set(face_roles):
            self._role_idx(r)
        role_to_idx = {r: self._role_idx(r) for r in set(face_roles)}

        tmp = bm.copy()
        mat = None
        for f in reversed(self.stack):
            mat = f if mat is None else f @ mat
        if mat is not None:
            bmesh.ops.transform(tmp, matrix=mat, verts=tmp.verts)
        bmesh.ops.recalc_face_normals(tmp, faces=list(tmp.faces))

        tmesh = bpy.data.meshes.new("_tmp_multi")
        tmp.to_mesh(tmesh)
        tmp.free()

        f0 = len(self.bm.faces)
        self.bm.from_mesh(tmesh)
        bpy.data.meshes.remove(tmesh)

        self.bm.faces.ensure_lookup_table()
        cl = self.bm.loops.layers.float_color.get("Color")
        ul = self.bm.loops.layers.uv.get("UVMap")

        new_faces = self.bm.faces[f0:]
        for idx, f in enumerate(new_faces):
            rname = face_roles[idx] if idx < len(face_roles) else "paint"
            f.material_index = role_to_idx[rname]
            tint = face_tints[idx] if (face_tints is not None and idx < len(face_tints)) else (1.0, 1.0, 1.0)
            k = 1.0 + self.rng.uniform(-jitter, jitter) if jitter else 1.0
            n = f.normal
            ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
            # Subtle belly/underside ambient shadow in vertex colour
            belly_shade = 0.90 + 0.10 * max(-1.0, min(1.0, n.z))
            for l in f.loops:
                p = l.vert.co
                vy = p.z
                ao = 1.0
                if ao_y is not None:
                    y_lo, y_hi = ao_y[0], ao_y[1]
                    k_lo = ao_y[2] if len(ao_y) > 2 else 0.74
                    t = max(0.0, min(1.0, (vy - y_lo) / max(1e-4, y_hi - y_lo)))
                    ao = k_lo + (1.0 - k_lo) * t
                s = k * ao * belly_shade
                l[cl] = (tint[0] * s, tint[1] * s, tint[2] * s, 1.0)
                if az >= ax and az >= ay:
                    l[ul].uv = (p.x, p.y)
                elif ax >= ay:
                    l[ul].uv = (p.y, p.z)
                else:
                    l[ul].uv = (p.x, p.z)

    def loft_shell(self, role, sections, seg=28, subdiv=3, cross_power=1.0,
                   cap_start=True, cap_end=True, chine=0.0, role_fn=None,
                   tint=(1.0, 1.0, 1.0), ao_y=None, jitter=0.012, hermite=True):
        """Smooth welded longitudinal shell through `(z, cy, rx, ry)` stations.
        `chine > 0` widens and sharpens lateral stealth chines (F-35/F-22/J-20/Su-57/UCAVs)."""
        samples = _hermite_stations(sections, subdiv=subdiv) if hermite else [tuple(float(v) for v in s) for s in sections]
        bm = bmesh.new()
        rings = []
        for z, cy, rx, ry in samples:
            ring = []
            for i in range(seg):
                th = math.tau * i / seg
                sx = _signed_pow(math.sin(th), cross_power)
                sy = _signed_pow(math.cos(th), cross_power)
                if chine > 0.0:
                    # Stealth chine pinch near horizontal equator (cos(th) ~ 0)
                    eq = (1.0 - abs(math.cos(th))) ** 2.2
                    sx *= (1.0 + chine * eq)
                ring.append(bm.verts.new(P(rx * sx, cy + ry * sy, z)))
            rings.append(ring)

        face_roles = []
        face_tints = []
        if cap_start and len(rings[0]) >= 3:
            bm.faces.new(list(reversed(rings[0])))
            face_roles.append(role)
            face_tints.append(tint)
        if cap_end and len(rings[-1]) >= 3:
            bm.faces.new(list(rings[-1]))
            r_end = role_fn(samples[-1][0], 0.0) if role_fn else role
            face_roles.append(r_end)
            face_tints.append(tint)

        for j in range(len(rings) - 1):
            r0, r1 = rings[j], rings[j + 1]
            z_mid = 0.5 * (samples[j][0] + samples[j + 1][0])
            for i in range(seg):
                k = (i + 1) % seg
                th = math.tau * (i + 0.5) / seg
                f = bm.faces.new((r0[i], r0[k], r1[k], r1[i]))
                sel_role = role_fn(z_mid, th) if role_fn else role
                face_roles.append(sel_role)
                # Subtle panel variation along fuselage stations
                st_mod = 0.985 if (j % 3 == 1 and sel_role == "paint") else 1.0
                face_tints.append((tint[0] * st_mod, tint[1] * st_mod, tint[2] * st_mod))

        self.add_multi(bm, face_roles, face_tints, ao_y=ao_y, jitter=jitter)
        bm.free()

    def airfoil_wing(self, role, stations, chord_steps=8, span_steps=2, thickness=0.085,
                     mirror_x=False, vertical_cant_deg=None, tint=(1.0, 1.0, 1.0), ao_y=None, tip_role=None):
        """Welded NACA airfoil surface through `stations = [(span_u, offset_v, le_z, te_z), ...]`.
        If `vertical_cant_deg` is None: horizontal wing along +X (`mirror_x=True` mirrors to -X).
        If `vertical_cant_deg` is float: vertical fin rising from first station `(x0, y0, le0, te0)` with cant in deg."""
        chords = [i / (chord_steps - 1) for i in range(chord_steps)]
        prof = [(t, 1.0) for t in chords] + [(t, -1.0) for t in reversed(chords[1:-1])]

        dense = []
        for a, b in zip(stations, stations[1:]):
            steps = max(1, span_steps)
            for s_i in range(steps):
                t = s_i / steps
                dense.append(tuple(a[k] * (1.0 - t) + b[k] * t for k in range(4)))
        dense.append(tuple(stations[-1]))

        bm = bmesh.new()
        rings = []
        if vertical_cant_deg is not None:
            cant = math.radians(vertical_cant_deg)
            ca, sa = math.cos(cant), math.sin(cant)
            for u, base_x, le, te in dense:
                c = max(0.015, le - te)
                ring = []
                for t, side in prof:
                    th = 5.0 * thickness * (0.2969 * math.sqrt(max(0.0, t)) - 0.1260 * t - 0.3516 * t * t + 0.2843 * t ** 3 - 0.1036 * t ** 4) * c
                    # u is height along fin, side*th is normal to fin
                    vx = base_x + u * sa + side * th * ca
                    vy = u * ca - side * th * sa
                    vz = le - t * c
                    ring.append(bm.verts.new(P(vx, vy, vz)))
                rings.append(ring)
        else:
            sgn = -1.0 if mirror_x else 1.0
            for x, y, le, te in dense:
                c = max(0.015, le - te)
                ring = []
                for t, side in prof:
                    th = 5.0 * thickness * (0.2969 * math.sqrt(max(0.0, t)) - 0.1260 * t - 0.3516 * t * t + 0.2843 * t ** 3 - 0.1036 * t ** 4) * c
                    ring.append(bm.verts.new(P(sgn * x, y + side * th, le - t * c)))
                rings.append(ring)

        face_roles = []
        face_tints = []
        n_p = len(prof)
        if len(rings[0]) >= 3:
            bm.faces.new(list(reversed(rings[0])) if not mirror_x else list(rings[0]))
            face_roles.append(role)
            face_tints.append(tint)
        if len(rings[-1]) >= 3:
            bm.faces.new(list(rings[-1]) if not mirror_x else list(reversed(rings[-1])))
            face_roles.append(tip_role or role)
            face_tints.append(tint)

        for j in range(len(rings) - 1):
            r0, r1 = rings[j], rings[j + 1]
            is_tip = tip_role is not None and j == len(rings) - 2
            f_role = tip_role if is_tip else role
            for i in range(n_p):
                k = (i + 1) % n_p
                verts = (r0[i], r1[i], r1[k], r0[k]) if mirror_x else (r0[i], r0[k], r1[k], r1[i])
                bm.faces.new(verts)
                face_roles.append(f_role)
                face_tints.append(tint)

        self.add_multi(bm, face_roles, face_tints, ao_y=ao_y, jitter=0.008)
        bm.free()

    def intake_duct(self, x0, y0, z_front, x1, y1, z_back, w, h, wall=0.065, roundness=0.0, role="paint"):
        """Recessed jet engine air intake duct with dark compressor/splitter interior."""
        n = 16 if roundness > 0.4 else 8
        bm = bmesh.new()

        def make_ring(cx, cy, cz, rw, rh):
            pts = []
            if roundness > 0.4:
                for i in range(n):
                    a = math.tau * i / n
                    pts.append(bm.verts.new(P(cx + 0.5 * rw * math.sin(a), cy + 0.5 * rh * math.cos(a), cz)))
            else:
                hw, hh = 0.5 * rw, 0.5 * rh
                ch = min(hw, hh) * 0.22
                corners = [
                    (-hw, -hh + ch), (-hw + ch, -hh), (hw - ch, -hh), (hw, -hh + ch),
                    (hw, hh - ch), (hw - ch, hh), (-hw + ch, hh), (-hw, hh - ch),
                ]
                for dx, dy in corners:
                    pts.append(bm.verts.new(P(cx + dx, cy + dy, cz)))
            return pts

        ro_f = make_ring(x0, y0, z_front, w, h)
        ro_b = make_ring(x1, y1, z_back, w * 0.92, h * 0.92)
        ri_f = make_ring(x0, y0, z_front, max(0.08, w - 2 * wall), max(0.08, h - 2 * wall))
        ri_b = make_ring(x1, y1, z_front - min(abs(z_front - z_back) * 0.72, 1.35), max(0.06, w * 0.84 - 2 * wall), max(0.06, h * 0.84 - 2 * wall))
        m = len(ro_f)
        roles = []
        for i in range(m):
            j = (i + 1) % m
            bm.faces.new((ro_f[i], ro_b[i], ro_b[j], ro_f[j])); roles.append(role)
            bm.faces.new((ro_f[i], ro_f[j], ri_f[j], ri_f[i])); roles.append("metal_dark")
            bm.faces.new((ri_f[i], ri_f[j], ri_b[j], ri_b[i])); roles.append("dark")
        bm.faces.new(list(ro_b)); roles.append(role)
        bm.faces.new(list(ri_b)); roles.append("dark")
        self.add_multi(bm, roles, jitter=0.01)
        bm.free()

    def exhaust_nozzle(self, cx, cy, z_base, z_tip, r_base, r_tip, seg=18, petals=True):
        """Detailed turbofan/afterburner exhaust nozzle with turkey-feather petals and deep turbine core."""
        self.tube_axis("metal_dark", (cx, cy, z_base), (cx, cy, z_tip), r_base, r_tip * 0.78, seg=seg, r_out2=r_tip, tint=(0.82, 0.80, 0.78))
        z_core = z_base + abs(z_base - z_tip) * 0.35
        self.cyl("dark", (cx, cy, min(z_tip, z_base) + abs(z_base - z_tip) * 0.45), r_tip * 0.76, 0.08, seg=max(8, seg - 4), axis="z")
        if petals and seg >= 12:
            n_pet = 12
            L = abs(z_base - z_tip)
            for i in range(n_pet):
                a = math.tau * i / n_pet
                px = cx + math.cos(a) * (r_base * 0.96)
                py = cy + math.sin(a) * (r_base * 0.96)
                qx = cx + math.cos(a) * (r_tip * 0.99)
                qy = cy + math.sin(a) * (r_tip * 0.99)
                self.pipe("metal", (px, py, z_base), (qx, qy, z_tip), max(0.014, r_base * 0.055), seg=5, tint=(0.70, 0.68, 0.65))

    def rotor_hub_and_blades(self, radius, blades, lod=0, chord=None, phase=0.0, root_frac=0.13, yellow_tips=True):
        """Articulated helicopter main/tail rotor head (swashplate, pitch links, cuffs) + airfoil blades in local space around (0,0,0)."""
        chord = chord or max(0.22, radius * 0.062)
        seg_hub = 8 if lod else 20
        hub_r = max(0.13, radius * 0.045)
        # Central hub Forging, swashplate & aerodynamic cap
        self.cyl("metal_dark", (0, -0.18, 0), hub_r * 0.75, 0.34, seg=seg_hub)
        self.cyl("metal", (0, -0.11, 0), hub_r * 1.12, 0.06, seg=seg_hub)
        self.cyl("metal_dark", (0, 0.02, 0), hub_r * 1.18, 0.09, seg=seg_hub)
        if not lod:
            self.dome("paint", (0, 0.11, 0), hub_r * 0.95, hub_r * 0.55, seg=14, rings=3)

        for i in range(blades):
            ang = phase + math.tau * i / blades
            with self.frame((0, 0, 0), yaw=ang):
                # Blade grip cuff & lead-lag damper + pitch link
                r_cuff = radius * max(0.15, root_frac + 0.02)
                self.pipe("metal_dark", (hub_r * 0.65, 0.04, 0), (r_cuff, 0.03, 0), max(0.032, chord * 0.18), seg=6 if lod else 8)
                if not lod:
                    self.pipe("metal", (hub_r * 0.85, -0.09, chord * 0.16), (hub_r * 1.35, 0.03, chord * 0.16), 0.022, seg=6)
                    self.box("metal_dark", (r_cuff * 0.68, -0.01, -chord * 0.24), (r_cuff * 1.02, 0.07, chord * 0.24), bevel=0.008)
                # Swept-tip NACA rotor blade
                tip_split = radius * 0.93
                s0 = (radius * root_frac, 0.03, chord * 0.46, -chord * 0.54)
                s1 = (radius * 0.82, 0.035, chord * 0.48, -chord * 0.52)
                s2 = (tip_split, 0.032, chord * 0.40 - radius * 0.015, -chord * 0.48 - radius * 0.015)
                s3 = (radius, 0.028, chord * 0.12 - radius * 0.042, -chord * 0.42 - radius * 0.042)
                if lod:
                    self.airfoil_wing("paint", [s0, s3], chord_steps=4, span_steps=1, thickness=0.09, tint=(0.35, 0.37, 0.36))
                else:
                    self.airfoil_wing("paint", [s0, s1, s2, s3], chord_steps=7, span_steps=2, thickness=0.09,
                                      tint=(0.36, 0.38, 0.37), tip_role="white" if yellow_tips else "paint")

    def wheel_aircraft(self, center, radius, width=None, lod=0, dual=False):
        """Sculpted aircraft landing-gear tyre & alloy brake hub."""
        w = width or max(0.15, radius * 0.56)
        hw = w * 0.5
        offsets = (-w * 0.68, w * 0.68) if dual else (0.0,)
        for dx in offsets:
            cx, cy, cz = center[0] + dx, center[1], center[2]
            rim = radius * 0.54
            prof = [
                (-hw, 0.0, "metal", 0.85),
                (-hw, rim, "rubber", 0.90),
                (-hw * 0.78, radius * 0.96, "rubber", 0.98),
                (-hw * 0.42, radius, "rubber", 1.0),
                (hw * 0.42, radius, "rubber", 1.0),
                (hw * 0.78, radius * 0.96, "rubber", 0.98),
                (hw, rim, "metal", 0.88),
                (hw, 0.0, "metal_dark", 0.75),
            ]
            self.lathe_x((cx, cy, cz), prof, seg=8 if lod else 18)

    def naval_hull(self, L, B, draft, freeboard, profile, bow_sheer=1.7, lod=0, bulb=True):
        """Multi-station flared naval hull with red oxide antifouling below `draft`, dark boot-topping stripe,
        flared grey topsides, non-skid weather deck, and optional bulbous bow + twin stern skegs."""
        D = draft + freeboard
        n_st = 11 if lod else 37
        zs = sorted(set([float(p[0]) for p in profile] + [-0.5 + i / (n_st - 1) for i in range(n_st)]))
        p_z = [float(p[0]) for p in profile]
        p_w = [float(p[1]) for p in profile]

        def interp_w(z_norm):
            if z_norm <= p_z[0]:
                return p_w[0]
            if z_norm >= p_z[-1]:
                return p_w[-1]
            for i in range(len(p_z) - 1):
                if p_z[i] <= z_norm <= p_z[i + 1]:
                    t = (z_norm - p_z[i]) / max(1e-6, p_z[i + 1] - p_z[i])
                    return p_w[i] * (1.0 - t) + p_w[i + 1] * t
            return 1.0

        boot_lo = max(0.08, draft * 0.86)
        boot_hi = min(D - 0.12, draft * 1.08)

        bm = bmesh.new()
        rings = []
        deck_l = []
        deck_r = []
        for zn in zs:
            wf = max(0.010, interp_w(zn))
            hw = 0.5 * B * wf
            sheer = max(0.0, (zn - 0.20) / 0.30) ** 1.35 * bow_sheer
            top_y = D + sheer
            # Rise of keel near stern & bow
            rise = draft * 0.82 * (max(0.0, (abs(zn) - 0.27) / 0.23) ** 2.0)
            rake_top = max(0.0, (zn - 0.32) / 0.18) ** 1.6 * (L * 0.042)

            def st_pt(x_frac, y_raw):
                t_y = y_raw / max(0.1, top_y)
                yy = y_raw + rise * (1.0 - t_y)
                zz = zn * L + rake_top * t_y - max(0.0, (zn - 0.36) / 0.14) * L * 0.028 * (1.0 - t_y)
                return bm.verts.new(P(hw * x_frac, max(0.0, yy), zz))

            # 12-point cross-section from starboard deck edge -> keel -> port deck edge
            ring = [
                st_pt(1.00, top_y),
                st_pt(0.97, max(boot_hi + 0.08, top_y * 0.68)),
                st_pt(0.91, boot_hi),
                st_pt(0.88, boot_lo),
                st_pt(0.72, draft * 0.32),
                st_pt(0.30, 0.0),
                st_pt(-0.30, 0.0),
                st_pt(-0.72, draft * 0.32),
                st_pt(-0.88, boot_lo),
                st_pt(-0.91, boot_hi),
                st_pt(-0.97, max(boot_hi + 0.08, top_y * 0.68)),
                st_pt(-1.00, top_y),
            ]
            rings.append(ring)
            deck_r.append(ring[0])
            deck_l.append(ring[11])

        # Band roles for the 11 strips around each ring:
        # 0..1: starboard topside ('paint'), 2: starboard boot-top ('dark'), 3..7: underwater hull ('hull_red'),
        # 8: port boot-top ('dark'), 9..10: port topside ('paint')
        strip_roles = ["paint", "paint", "dark", "hull_red", "hull_red", "hull_red", "hull_red", "hull_red", "dark", "paint", "paint"]
        face_roles = []
        face_tints = []

        for j in range(len(rings) - 1):
            r0, r1 = rings[j], rings[j + 1]
            for s_i in range(11):
                bm.faces.new((r0[s_i], r0[s_i + 1], r1[s_i + 1], r1[s_i]))
                face_roles.append(strip_roles[s_i])
                face_tints.append((1.0, 1.0, 1.0))
            # Weather deck quad between port & starboard sheer edges
            bm.faces.new((deck_r[j], deck_r[j + 1], deck_l[j + 1], deck_l[j]))
            face_roles.append("deck")
            face_tints.append((1.0, 1.0, 1.0))

        # Transom stern & stem closures (5 symmetric quad strips from deck 0..11 down to keel 5..6)
        for s_i in range(5):
            a0, a1 = rings[0][s_i], rings[0][s_i + 1]
            b1, b0 = rings[0][11 - s_i - 1], rings[0][11 - s_i]
            bm.faces.new((a0, b0, b1, a1))
            face_roles.append("paint" if s_i < 2 else ("dark" if s_i == 2 else "hull_red"))
            face_tints.append((0.92, 0.92, 0.92))

            ca0, ca1 = rings[-1][s_i], rings[-1][s_i + 1]
            cb1, cb0 = rings[-1][11 - s_i - 1], rings[-1][11 - s_i]
            bm.faces.new((ca0, ca1, cb1, cb0))
            face_roles.append("paint" if s_i < 2 else ("dark" if s_i == 2 else "hull_red"))
            face_tints.append((0.96, 0.96, 0.96))

        self.add_multi(bm, face_roles, face_tints, ao_y=(0.0, D * 1.15, 0.72), jitter=0.01)
        bm.free()

        # Bulbous bow & twin rudders on major surface ships
        if bulb and L >= 75.0:
            rb = min(B * 0.13, draft * 0.34)
            by = max(rb + 0.04, draft * 0.38)
            self.loft_shell("hull_red", [
                (L * 0.40, by, rb * 0.55, rb * 0.55),
                (L * 0.46, by, rb, rb * 0.92),
                (L * 0.502, by + rb * 0.08, rb * 0.72, rb * 0.72),
                (L * 0.515, by + rb * 0.12, rb * 0.16, rb * 0.16),
            ], seg=8 if lod else 16, subdiv=1 if lod else 2, ao_y=(0.0, D, 0.75))
        if not lod and L >= 45.0:
            rud_h = max(0.6, draft * 0.42)
            for side in (-1, 1):
                rx = side * B * 0.16
                self.box("hull_red", (rx - 0.09, max(0.06, draft * 0.12), -L * 0.46),
                         (rx + 0.09, max(0.06, draft * 0.12) + rud_h, -L * 0.42), bevel=0.03)
            # Forecastle breakwater V-shield
            bw_y = D + bow_sheer * 0.42
            for side in (-1, 1):
                self.box("paint", (side * B * 0.14 - B * 0.13, bw_y - 0.1, L * 0.35),
                         (side * B * 0.14 + B * 0.13, bw_y + 0.55, L * 0.356),
                         yaw=side * 0.32, bevel=0.03)

    def chamfer_house(self, x, y, z, w, h, l, taper=0.84, role="paint", roof_deck=True, lod=0):
        """Sloped stealth superstructure block with chamfered corners and dark non-skid weather roof."""
        def oct_pts(sc):
            a, b = 0.5 * w * sc, 0.5 * l * sc
            c = min(a, b) * 0.18
            return [
                (x - a, z - b + c), (x - a + c, z - b), (x + a - c, z - b), (x + a, z - b + c),
                (x + a, z + b - c), (x + a - c, z + b), (x - a + c, z + b), (x - a, z + b - c),
            ]
        self.prism_y(role, oct_pts(1.0), y, y + h, top_xz=oct_pts(taper),
                     bevel=0.0 if lod else min(0.10, h * 0.06), ao_y=(y, y + h * 1.2, 0.84))
        if roof_deck and not lod and w * taper > 1.2 and l * taper > 1.2:
            self.prism_y("deck", oct_pts(taper * 0.94), y + h - 0.02, y + h + 0.04)


def make_carrier_deck_plane(style="f35", idx=0):
    """Build a crisp miniature carrier aircraft/UCAV `CraftPart` to park as `DeckPlane0..4` on a carrier deck."""
    p = CraftPart(f"DeckPlane{idx}", seed=300 + idx)
    if style == "drone":
        # Bayraktar TB3 / Mojave naval UCAV with folded wings
        p.loft_shell("paint", [(-3.8, 0.85, 0.24, 0.22), (-1.2, 0.9, 0.42, 0.36), (1.8, 0.88, 0.38, 0.32), (4.1, 0.78, 0.10, 0.10)], seg=12, subdiv=1)
        p.dome("radome", (0, 0.96, 2.2), 0.30, 0.24, seg=10, rings=2)
        for s in (-1, 1):
            p.box("paint", (s * 1.9, 0.86, -0.5), (s * 0.35, 0.96, 0.55), bevel=0.02)
            # Folded outer wing panel
            p.box("paint", (s * 1.92, 0.90, -0.45), (s * 2.04, 2.65, 0.42), bevel=0.02)
            p.box("paint", (s * 0.75, 0.88, -3.9), (s * 0.05, 1.85, -3.1), yaw=0.0, bevel=0.02)
    else:
        # Naval stealth strike fighter (F-35C/B / Rafale M silhouette, ~15.5m real scale)
        p.loft_shell("paint", [
            (-7.4, 1.35, 0.55, 0.48), (-5.2, 1.40, 1.05, 0.75), (-1.0, 1.42, 1.12, 0.82),
            (2.8, 1.38, 0.82, 0.68), (5.8, 1.28, 0.42, 0.38), (7.8, 1.18, 0.08, 0.08),
        ], seg=14, subdiv=1, chine=0.22)
        p.loft_shell("glass", [(1.2, 1.92, 0.42, 0.34), (3.1, 1.98, 0.45, 0.40), (4.8, 1.72, 0.22, 0.18)], seg=10, subdiv=1)
        p.exhaust_nozzle(0.0, 1.35, -7.2, -7.85, 0.54, 0.44, seg=12, petals=False)
        for s in (-1, 1):
            p.airfoil_wing("paint", [(0.9, 1.38, 1.8, -4.6), (4.1, 1.38, -0.8, -4.5)], chord_steps=5, span_steps=1, mirror_x=(s < 0))
            # Folded carrier wingtips + canted twin tails
            p.box("paint", (s * 4.08, 1.38, -3.9), (s * 4.20, 2.85, -1.2), bevel=0.02)
            with p.frame((0.0, 1.38, 0.0)):
                p.airfoil_wing("paint", [(0.0, s * 1.15, -4.3, -6.9), (2.05, s * 1.15, -5.6, -7.2)],
                               chord_steps=4, span_steps=1, vertical_cant_deg=s * 18.0)
            p.box("markings", (s * 2.5, 1.45, -2.6), (s * 3.1, 1.49, -2.0))
        for gx, gz in ((0.0, 4.2), (-1.65, -1.6), (1.65, -1.6)):
            p.pipe("metal_dark", (gx, 1.2, gz), (gx, 0.32, gz), 0.08, seg=6)
            p.wheel_aircraft((gx, 0.32, gz), 0.32, lod=1)
    # Shift up so y_min = 0 relative to deck pivot
    return p


def build_craft_wreck(lod0_rig, list_roll_deg=11.0, pitch_deg=-3.5):
    """Create a scorched, damaged static `Wreck` mesh grounded at `y >= 0` from `lod0_rig`."""
    wreck = CraftPart("Wreck", seed=199)
    rot = Matrix.Rotation(math.radians(pitch_deg), 4, "X") @ Matrix.Rotation(math.radians(list_roll_deg), 4, "Y")
    collected = []
    for node in lod0_rig.nodes:
        if node["name"].startswith("DeckPlane"):
            continue
        part = node["part"]
        if part is None or not part.bm.faces:
            continue
        for f_idx, role in enumerate(part.roles):
            if role in ("glass", "markings", "white"):
                continue
            target = "rubber" if role == "rubber" else ("dark" if role == "dark" else "metal_dark")
            sub = part.bm.copy()
            kill = [f for f in sub.faces if f.material_index != f_idx]
            if kill:
                bmesh.ops.delete(sub, geom=kill, context="FACES")
            if not sub.faces:
                sub.free()
                continue
            bmesh.ops.transform(sub, matrix=rot, verts=list(sub.verts))
            collected.append((target, sub))
    if collected:
        min_z = min(v.co.z for _, b in collected for v in b.verts)
        shift = Matrix.Translation(Vector((0.0, 0.0, -min_z + 0.01)))
        for target, sub in collected:
            wreck.add(target, sub, shift, tint=(0.38, 0.35, 0.33), jitter=0.05)
            sub.free()
    return wreck


def export_craft(out_path, lod0_rig, lod1_rig, extra_lod0_nodes=None, wreck_roll=9.0):
    """Assemble `LOD0`, `LOD1`, and `Wreck` in Blender and export a game-ready `.glb`.
    `extra_lod0_nodes` is an optional list of `(name, parent_name, pivot_tuple, part_or_None)` (e.g. `Waterline`, `DeckPlane0..4`)."""
    clear_scene_fast()
    scene = bpy.context.scene
    col = scene.collection

    if extra_lod0_nodes:
        for name, parent, piv, part in extra_lod0_nodes:
            if name not in lod0_rig.pivots:
                lod0_rig.add(name, parent, piv, part)
    else:
        # Seat every aircraft, rotorcraft, UAV & loiterer cleanly on y = 0.000
        zs = [v.co.z for node in lod0_rig.nodes if node["part"] is not None for v in node["part"].bm.verts]
        if zs:
            min_z = min(zs)
            if abs(min_z) > 0.002:
                dy = -min_z
                for rig in (lod0_rig, lod1_rig):
                    for k, pv in list(rig.pivots.items()):
                        if k != rig.root_name:
                            rig.pivots[k] = (pv[0], pv[1] + dy, pv[2])
                    for node in rig.nodes:
                        pv = node["pivot"]
                        node["pivot"] = (pv[0], pv[1] + dy, pv[2])
                        if node["part"] is not None and node["part"].bm.verts:
                            bmesh.ops.translate(node["part"].bm, vec=Vector((0.0, 0.0, dy)), verts=list(node["part"].bm.verts))

    for rig in (lod0_rig, lod1_rig):
        # DeckPlane0..4 and Waterline/Hull_Bow keep exact names on LOD0 so Godot finds them directly
        suffix = "_LOD1" if rig.lod == 1 else ""
        root_empty = bpy.data.objects.new(rig.root_name, None)
        col.objects.link(root_empty)
        objs_by_name = {rig.root_name: root_empty}

        for node in rig.nodes:
            name = node["name"]
            parent_name = node["parent"]
            pivot = node["pivot"]
            parent_pivot = rig.pivots[parent_name]
            local_loc = P(*pivot) - P(*parent_pivot)

            piv_obj = bpy.data.objects.new(name + suffix, None)
            piv_obj.location = local_loc
            piv_obj.parent = objs_by_name[parent_name]
            col.objects.link(piv_obj)
            objs_by_name[name] = piv_obj

            part = node["part"]
            if part is not None and len(part.bm.faces) > 0:
                mesh_name = f"{name}_Mesh{suffix}"
                mobj = bv._part_to_mesh_obj(part, mesh_name, pivot, smooth_angle=38.0)
                mobj.parent = piv_obj
                col.objects.link(mobj)

    wreck_part = build_craft_wreck(lod0_rig, list_roll_deg=wreck_roll)
    wobj = bv._part_to_mesh_obj(wreck_part, "Wreck", (0.0, 0.0, 0.0), smooth_angle=34.0)
    col.objects.link(wobj)

    # Free bmeshes
    for rig in (lod0_rig, lod1_rig):
        for node in rig.nodes:
            if node["part"] is not None:
                node["part"].bm.free()
    wreck_part.bm.free()

    bpy.context.view_layer.update()
    tris_lod0 = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == "MESH" and not o.name.endswith("_LOD1") and o.name != "Wreck")
    tris_lod1 = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == "MESH" and o.name.endswith("_LOD1"))
    tris_wreck = len(wobj.data.polygons)

    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    import time
    for attempt in range(5):
        try:
            bpy.ops.export_scene.gltf(
                filepath=out_path,
                export_format="GLB",
                export_apply=False,
                export_yup=True,
                export_materials="EXPORT",
                export_image_format="NONE",
                export_texcoords=True,
                export_normals=True,
                export_vertex_color="ACTIVE",
                export_cameras=False,
                export_lights=False,
            )
            break
        except RuntimeError:
            if attempt == 4:
                raise
            time.sleep(0.35 * (attempt + 1))
    print(f"CRAFT {os.path.basename(out_path)}: LOD0={tris_lod0} polys, LOD1={tris_lod1} polys, Wreck={tris_wreck} polys")
    return tris_lod0, tris_lod1, tris_wreck
