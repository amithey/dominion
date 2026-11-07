"""Blender modelling & hierarchical glTF export kit for DOMINION armoured vehicles.

Run a vehicle builder inside Blender:
    blender -b -P native/tools/models/blender/build_abrams.py -- <out.glb>

Coordinates match the game and bl_kit.py: metres, +x right, +y up, +z front,
standing on y = 0. Parts are authored in world game coordinates on named pivot
nodes (Hull, Turret, Gun, Muzzle, Wheel_L0..6, Sprocket_L/R, Idler_L/R,
Roller_L0..2, Track_L/R, hatches, optics, RWS, smoke launchers, antennas),
localized to each pivot on export, dressed per material role by
scripts/vehicle_models.gd, and shaded with vertex-colour AO/panel contrast by
shaders/vehicle.gdshader.
"""
import math
import random
import bpy
import bmesh
from mathutils import Vector, Matrix
from bl_kit import P, hexc

PREVIEW = {
    "paint": (0.42, 0.39, 0.28),
    "metal_dark": (0.14, 0.14, 0.15),
    "metal": (0.32, 0.33, 0.35),
    "rubber": (0.05, 0.05, 0.055),
    "glass": (0.06, 0.16, 0.22),
    "canvas": (0.38, 0.36, 0.26),
    "wood": (0.36, 0.23, 0.13),
    "dark": (0.02, 0.02, 0.025),
    "markings": (0.22, 0.45, 0.88),
}

# Canonical shader track path (must match native/godot/shaders/vehicle.gdshader)
T_HALF = 3.23
T_R = 0.57
T_Y = 0.65
T_LEN = 4.0 * T_HALF + 2.0 * math.pi * T_R


def track_sample(u):
    """Sample (y, z), outward normal (ny, nz), and forward tangent (ty, tz) on the canonical loop."""
    s = (u % 1.0) * T_LEN
    straight = 2.0 * T_HALF
    arc = math.pi * T_R
    if s < straight:
        return (T_Y - T_R, -T_HALF + s), (-1.0, 0.0), (0.0, 1.0)
    s -= straight
    if s < arc:
        a = -math.pi * 0.5 + s / T_R
        return (T_Y + T_R * math.sin(a), T_HALF + T_R * math.cos(a)), (math.sin(a), math.cos(a)), (math.cos(a), -math.sin(a))
    s -= arc
    if s < straight:
        return (T_Y + T_R, T_HALF - s), (1.0, 0.0), (0.0, -1.0)
    s -= straight
    a = math.pi * 0.5 + s / T_R
    return (T_Y + T_R * math.sin(a), -T_HALF + T_R * math.cos(a)), (math.sin(a), math.cos(a)), (math.cos(a), -math.sin(a))


class _Frame:
    def __init__(self, part, matrix):
        self.part, self.matrix = part, matrix

    def __enter__(self):
        self.part.stack.append(self.matrix)

    def __exit__(self, *args):
        self.part.stack.pop()


class Part:
    """Accumulates bmesh geometry across material roles in game coordinates for one articulated vehicle node."""

    def __init__(self, name, seed=11):
        self.name = name
        self.bm = bmesh.new()
        self.col_layer = self.bm.loops.layers.float_color.new("Color")
        self.uv_layer = self.bm.loops.layers.uv.new("UVMap")
        self.roles = []
        self.stack = []
        self.rng = random.Random(seed)
        self._cache = {}

    def _role_idx(self, role):
        if role not in self.roles:
            self.roles.append(role)
        return self.roles.index(role)

    def frame(self, pos=(0, 0, 0), yaw=0.0, pitch=0.0, roll=0.0):
        """Local coordinate frame in game space: translate to `pos`, yaw about +Y, pitch about +X, roll about +Z."""
        m = (Matrix.Translation(P(*pos))
             @ Matrix.Rotation(yaw, 4, "Z")
             @ Matrix.Rotation(pitch, 4, "X")
             @ Matrix.Rotation(-roll, 4, "Y"))
        return _Frame(self, m)

    def add(self, role, src, matrix=None, tint=(1.0, 1.0, 1.0), jitter=0.0, ao_y=None, custom_uv=None):
        """Append a Blender-space bmesh to `role` with optional vertex-colour tint, face jitter, and vertical AO."""
        ri = self._role_idx(role)
        tmp = src.copy()
        for f in reversed(self.stack):
            matrix = f if matrix is None else f @ matrix
        if matrix is not None:
            bmesh.ops.transform(tmp, matrix=matrix, verts=tmp.verts)
        bmesh.ops.recalc_face_normals(tmp, faces=list(tmp.faces))

        tmesh = bpy.data.meshes.new("_tmp")
        tmp.to_mesh(tmesh)
        tmp.free()

        f0 = len(self.bm.faces)
        self.bm.from_mesh(tmesh)
        bpy.data.meshes.remove(tmesh)

        self.bm.faces.ensure_lookup_table()
        cl = self.bm.loops.layers.float_color.get("Color")
        ul = self.bm.loops.layers.uv.get("UVMap")

        for f in self.bm.faces[f0:]:
            f.material_index = ri
            k = 1.0 + self.rng.uniform(-jitter, jitter) if jitter else 1.0
            n = f.normal
            ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
            for l in f.loops:
                p = l.vert.co
                vy = p.z  # game Y is Blender Z
                ao = 1.0
                if ao_y is not None:
                    if len(ao_y) == 2:
                        y_lo, y_hi, k_lo = ao_y[0], ao_y[1], 0.72
                    else:
                        y_lo, y_hi, k_lo = ao_y
                    t = max(0.0, min(1.0, (vy - y_lo) / max(1e-4, y_hi - y_lo)))
                    ao = k_lo + (1.0 - k_lo) * t
                l[cl] = (tint[0] * k * ao, tint[1] * k * ao, tint[2] * k * ao, 1.0)
                if custom_uv is not None:
                    l[ul].uv = custom_uv(p)
                else:
                    if az >= ax and az >= ay:
                        l[ul].uv = (p.x, p.y)
                    elif ax >= ay:
                        l[ul].uv = (p.y, p.z)
                    else:
                        l[ul].uv = (p.x, p.z)

    # ------------------------------------------------------------ primitives
    def box(self, role, lo, hi, bevel=0.0, seg=1, yaw=0.0, pitch=0.0, tint=(1, 1, 1), jitter=0.0, ao_y=None):
        """Box from game `lo` to `hi` (auto-sorted per axis) with optional edge bevel and local rotation."""
        x0, x1 = (lo[0], hi[0]) if lo[0] <= hi[0] else (hi[0], lo[0])
        y0, y1 = (lo[1], hi[1]) if lo[1] <= hi[1] else (hi[1], lo[1])
        z0, z1 = (lo[2], hi[2]) if lo[2] <= hi[2] else (hi[2], lo[2])
        sx, sy, sz = x1 - x0, y1 - y0, z1 - z0
        if sx <= 1e-5 or sy <= 1e-5 or sz <= 1e-5:
            return
        key = ("box", round(sx, 4), round(sy, 4), round(sz, 4), round(bevel, 4), seg)
        if key not in self._cache:
            bm = bmesh.new()
            bmesh.ops.create_cube(bm, size=1.0)
            for v in bm.verts:
                v.co = Vector((v.co.x * sx, v.co.y * sz, v.co.z * sy))
            if bevel > 0.0:
                b = min(bevel, sx * 0.42, sy * 0.42, sz * 0.42)
                bmesh.ops.bevel(bm, geom=list(bm.edges), offset=b, segments=seg, affect="EDGES", profile=0.55)
            self._cache[key] = bm
        cx, cy, cz = (x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5
        m = Matrix.Translation(P(cx, cy, cz))
        if yaw:
            m = m @ Matrix.Rotation(yaw, 4, "Z")
        if pitch:
            m = m @ Matrix.Rotation(pitch, 4, "X")
        self.add(role, self._cache[key], m, tint=tint, jitter=jitter, ao_y=ao_y)

    def cyl(self, role, base, r, h, seg=14, r2=None, bevel=0.0, tint=(1, 1, 1), cap=True, axis="y"):
        """Cylinder or frustum starting at game point `base` along `axis` ('y' default, 'x', or 'z')."""
        if axis == "z":
            return self.pipe(role, base, (base[0], base[1], base[2] + h), r, seg=seg, r2=r2, tint=tint, cap=cap, bevel=bevel)
        if axis == "x":
            return self.pipe(role, base, (base[0] + h, base[1], base[2]), r, seg=seg, r2=r2, tint=tint, cap=cap, bevel=bevel)
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=cap, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=abs(h))
        if bevel > 0.0 and cap:
            rim_edges = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > 0.8]
            if rim_edges:
                bmesh.ops.bevel(bm, geom=rim_edges, offset=min(bevel, r * 0.35, abs(h) * 0.35), segments=1, affect="EDGES")
        self.add(role, bm, Matrix.Translation(P(base[0], base[1] + h * 0.5, base[2])), tint=tint)
        bm.free()

    def dome(self, role, base, r, h, seg=12, rings=4, tint=(1, 1, 1)):
        """Armoured hemisphere/dome standing on `base` with radius `r` and height `h`."""
        for i in range(rings):
            a0 = (math.pi * 0.5) * (i / rings)
            a1 = (math.pi * 0.5) * ((i + 1) / rings)
            y0 = base[1] + h * math.sin(a0)
            y1 = base[1] + h * math.sin(a1)
            r0 = r * math.cos(a0)
            r1 = max(0.004, r * math.cos(a1))
            self.cyl(role, (base[0], y0, base[2]), r0, y1 - y0, seg=seg, r2=r1, tint=tint)

    def wedge(self, role, lo, hi, axis="y", slope_dir="+x", bevel=0.0, tint=(1, 1, 1)):
        """Right-triangular sloped armour shoulder between `lo` and `hi`."""
        x0, x1 = (lo[0], hi[0]) if lo[0] <= hi[0] else (hi[0], lo[0])
        y0, y1 = (lo[1], hi[1]) if lo[1] <= hi[1] else (hi[1], lo[1])
        z0, z1 = (lo[2], hi[2]) if lo[2] <= hi[2] else (hi[2], lo[2])
        if slope_dir == "-x":
            pts = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1)]
        elif slope_dir == "+x":
            pts = [(x0, y0, z0), (x1, y0, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x0, y1, z1)]
        elif slope_dir == "+z":
            pts = [(x0, y0, z0), (x1, y0, z0), (x0, y0, z1), (x1, y0, z1), (x0, y1, z0), (x1, y1, z0)]
        else:
            pts = [(x0, y0, z0), (x1, y0, z0), (x0, y0, z1), (x1, y0, z1), (x0, y1, z1), (x1, y1, z1)]
        self.hull(role, pts, bevel=bevel, tint=tint)

    def profile_x(self, role, zy_pts, x0, x1, bevel=0.0, seg=1, tint=(1, 1, 1), ao_y=None):
        """Extrude a closed 2D `(z, y)` side-elevation profile along X from `x0` to `x1`."""
        xa, xb = (x0, x1) if x0 <= x1 else (x1, x0)
        return self.prism_x(role, [(y, z) for z, y in zy_pts], xa, xb, bevel=bevel, seg=seg, tint=tint, ao_y=ao_y)

    def frustum_xz(self, role, bot_xz, top_xz, y0, y1, bevel=0.0, seg=1, tint=(1, 1, 1), ao_y=None):
        """Loft a closed polygon `bot_xz` at `y0` to `top_xz` at `y1`."""
        return self.prism_y(role, bot_xz, y0, y1, top_xz=top_xz, bevel=bevel, seg=seg, tint=tint, ao_y=ao_y)

    def pipe(self, role, a, b, r, seg=10, r2=None, tint=(1, 1, 1), cap=True, bevel=0.0):
        """Cylinder or frustum between two game points `a` and `b`."""
        pa, pb = P(*a), P(*b)
        d = pb - pa
        if d.length < 1e-5:
            return
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=cap, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=d.length)
        if bevel > 0.0 and cap:
            rim_edges = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > 0.8]
            if rim_edges:
                bmesh.ops.bevel(bm, geom=rim_edges, offset=min(bevel, r * 0.3, d.length * 0.3), segments=1, affect="EDGES")
        rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
        self.add(role, bm, Matrix.Translation((pa + pb) * 0.5) @ rot, tint=tint)
        bm.free()

    def tube_axis(self, role, a, b, r_out, r_in, seg=16, r_out2=None, tint=(1, 1, 1), axis=None):
        """Hollow thick-walled pipe/annulus between game points `a` and `b` (for gun muzzles, collars, sights)."""
        pa, pb = P(*a), P(*b)
        d = pb - pa
        L = d.length
        if L < 1e-5:
            return
        ro2 = r_out if r_out2 is None else r_out2
        bm = bmesh.new()
        ring = lambda r, z: [bm.verts.new(Vector((math.cos(math.tau * i / seg) * r, math.sin(math.tau * i / seg) * r, z))) for i in range(seg)]
        ob, ot = ring(r_out, -L * 0.5), ring(ro2, L * 0.5)
        ib, it = ring(r_in, -L * 0.5), ring(r_in, L * 0.5)
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((ob[i], ob[j], ot[j], ot[i]))
            bm.faces.new((ib[j], ib[i], it[i], it[j]))
            bm.faces.new((ot[i], ot[j], it[j], it[i]))
            bm.faces.new((ob[j], ob[i], ib[i], ib[j]))
        rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
        self.add(role, bm, Matrix.Translation((pa + pb) * 0.5) @ rot, tint=tint)
        bm.free()

    def hull(self, role, points, bevel=0.0, seg=1, tint=(1, 1, 1), jitter=0.0, ao_y=None):
        """Convex solid through game `points` with optional edge chamfer."""
        bm = bmesh.new()
        verts = [bm.verts.new(P(*p)) for p in points]
        bmesh.ops.convex_hull(bm, input=verts)
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(2.0), verts=list(bm.verts), edges=list(bm.edges))
        if bevel > 0.0:
            sharp = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(18.0)]
            if sharp:
                bmesh.ops.bevel(bm, geom=sharp, offset=bevel, segments=seg, affect="EDGES", profile=0.55)
        self.add(role, bm, None, tint=tint, jitter=jitter, ao_y=ao_y)
        bm.free()

    def prism_x(self, role, yz_pts, x0, x1, bevel=0.0, seg=1, tint=(1, 1, 1), ao_y=None):
        """Extrude a closed 2D `(y, z)` profile along X from `x0` to `x1`."""
        bm = bmesh.new()
        v0 = [bm.verts.new(P(x0, y, z)) for y, z in yz_pts]
        v1 = [bm.verts.new(P(x1, y, z)) for y, z in yz_pts]
        n = len(yz_pts)
        bm.faces.new(v0)
        bm.faces.new(list(reversed(v1)))
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((v0[i], v0[j], v1[j], v1[i]))
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        if bevel > 0.0:
            sharp = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(20.0)]
            if sharp:
                bmesh.ops.bevel(bm, geom=sharp, offset=bevel, segments=seg, affect="EDGES", profile=0.55)
        self.add(role, bm, None, tint=tint, ao_y=ao_y)
        bm.free()

    def prism_y(self, role, xz_pts, y0, y1, top_xz=None, bevel=0.0, seg=1, tint=(1, 1, 1), ao_y=None):
        """Closed armour block lofted from bottom polygon `xz_pts` at `y0` to `top_xz` (or `xz_pts`) at `y1`, with chamfer."""
        top = xz_pts if top_xz is None else top_xz
        assert len(xz_pts) == len(top)
        bm = bmesh.new()
        vb = [bm.verts.new(P(x, y0, z)) for x, z in xz_pts]
        vt = [bm.verts.new(P(x, y1, z)) for x, z in top]
        n = len(xz_pts)
        bm.faces.new(vb)
        bm.faces.new(list(reversed(vt)))
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((vb[i], vb[j], vt[j], vt[i]))
        bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) == 4 and not self._planar(f)])
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        if bevel > 0.0:
            sharp = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(22.0)]
            if sharp:
                bmesh.ops.bevel(bm, geom=sharp, offset=bevel, segments=seg, affect="EDGES", profile=0.55)
        self.add(role, bm, None, tint=tint, ao_y=ao_y)
        bm.free()

    @staticmethod
    def _planar(face):
        vs = [v.co for v in face.verts]
        if len(vs) < 4:
            return True
        n = (vs[1] - vs[0]).cross(vs[2] - vs[0])
        if n.length < 1e-7:
            return True
        return abs((vs[3] - vs[0]).dot(n.normalized())) < 1e-4

    def lathe_x(self, center, profile, seg=16, tint=(1, 1, 1)):
        """Revolve a multi-role wheel/hub profile around the X-axis at `center`.
        `profile` is a list of `(dx, radius, role_after_here, tint_multiplier)` starting and ending at `radius = 0`."""
        cx, cy, cz = center
        for (x0, r0, role, k0), (x1, r1, _, _) in zip(profile, profile[1:]):
            if abs(x1 - x0) < 1e-6 and abs(r1 - r0) < 1e-6:
                continue
            bm = bmesh.new()
            ring0 = [bm.verts.new(P(cx + x0, cy, cz))] * seg if r0 < 1e-6 else [
                bm.verts.new(P(cx + x0, cy + r0 * math.cos(math.tau * i / seg), cz + r0 * math.sin(math.tau * i / seg)))
                for i in range(seg)
            ]
            ring1 = [bm.verts.new(P(cx + x1, cy, cz))] * seg if r1 < 1e-6 else [
                bm.verts.new(P(cx + x1, cy + r1 * math.cos(math.tau * i / seg), cz + r1 * math.sin(math.tau * i / seg)))
                for i in range(seg)
            ]
            for i in range(seg):
                j = (i + 1) % seg
                vs = []
                for v in (ring0[i], ring0[j], ring1[j], ring1[i]):
                    if v not in vs:
                        vs.append(v)
                if len(vs) >= 3:
                    try:
                        bm.faces.new(vs)
                    except ValueError:
                        pass
            bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
            t = tuple(c * k0 for c in tint)
            self.add(role, bm, None, tint=t)
            bm.free()

    def decal_quad(self, role, p0, p1, p2, p3, outward=None, tint=(1, 1, 1)):
        """Single quad decal (e.g., tactical chevron arm) guaranteed to face `outward` in game space."""
        bm = bmesh.new()
        vs = [bm.verts.new(P(*p)) for p in (p0, p1, p2, p3)]
        f = bm.faces.new(vs)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        if outward is not None:
            out_bl = Vector((outward[0], -outward[2], outward[1]))
            if f.normal.dot(out_bl) < 0.0:
                f.normal_flip()
        # Add directly without recalc_face_normals flipping single open face back!
        ri = self._role_idx(role)
        tmesh = bpy.data.meshes.new("_tmp_decal")
        bm.to_mesh(tmesh)
        bm.free()
        f0 = len(self.bm.faces)
        self.bm.from_mesh(tmesh)
        bpy.data.meshes.remove(tmesh)
        self.bm.faces.ensure_lookup_table()
        cl = self.bm.loops.layers.float_color.get("Color")
        ul = self.bm.loops.layers.uv.get("UVMap")
        for nf in self.bm.faces[f0:]:
            nf.material_index = ri
            for l in nf.loops:
                l[cl] = (*tint, 1.0)
                l[ul].uv = (l.vert.co.y, l.vert.co.z)

    def build_track(self, x_center, lod=0, width=0.635):
        """Build 3D T158 'Bigfoot' heavy track links around the canonical TrackPath with exact longitudinal UV.x in [0..1]."""
        segs = 24 if lod else 68
        thick = 0.052
        hw = width * 0.5

        # 1. Continuous inner/side dark steel band with exact seam U=0..1
        bm_band = bmesh.new()
        uv_map = {}
        rings_out = []
        rings_in = []
        for i in range(segs + 1):
            u = i / segs
            (py, pz), (ny, nz), _ = track_sample(u)
            vo_l = bm_band.verts.new(P(x_center - hw * 0.92, py, pz))
            vo_r = bm_band.verts.new(P(x_center + hw * 0.92, py, pz))
            vi_l = bm_band.verts.new(P(x_center - hw * 0.92, py - ny * thick, pz - nz * thick))
            vi_r = bm_band.verts.new(P(x_center + hw * 0.92, py - ny * thick, pz - nz * thick))
            rings_out.append((vo_l, vo_r, u))
            rings_in.append((vi_l, vi_r, u))
            for v, vx in ((vo_l, 0.0), (vo_r, width), (vi_l, 0.0), (vi_r, width)):
                uv_map[v.index] = (u, vx)

        for i in range(segs):
            ol0, or0, u0 = rings_out[i]
            ol1, or1, u1 = rings_out[i + 1]
            il0, ir0, _ = rings_in[i]
            il1, ir1, _ = rings_in[i + 1]
            bm_band.faces.new((ol0, ol1, or1, or0))
            bm_band.faces.new((ir0, ir1, il1, il0))
            bm_band.faces.new((ol0, or0 if False else ol1, il1, il0))
            bm_band.faces.new((or1, or0, ir0, ir1))

        # Add band with exact per-loop u0/u1
        self._add_track_bm("metal_dark", bm_band, x_center, width, segs_band=True, tint=(0.48, 0.47, 0.45))
        bm_band.free()

        # 2. Individual T158 track shoes: steel shoe plate + outer end-connectors + twin octagonal rubber pads + inner guide tooth
        pads = 14 if lod else 72
        pitch = T_LEN / 72.0
        for i in range(pads):
            u = (i + 0.5) / pads
            (py, pz), (ny, nz), (ty, tz) = track_sample(u)

            def shoe_box(role, x0, x1, n0, n1, t0, t1, tint):
                bm = bmesh.new()
                pts = []
                for xx in (x0, x1):
                    for nn in (n0, n1):
                        for tt in (t0, t1):
                            pts.append(bm.verts.new(P(x_center + xx, py + ny * nn + ty * tt, pz + nz * nn + tz * tt)))
                # 8 corners: 0..3 at x0, 4..7 at x1
                bm.faces.new((pts[0], pts[1], pts[3], pts[2]))
                bm.faces.new((pts[4], pts[6], pts[7], pts[5]))
                bm.faces.new((pts[0], pts[4], pts[5], pts[1]))
                bm.faces.new((pts[2], pts[3], pts[7], pts[6]))
                bm.faces.new((pts[1], pts[5], pts[7], pts[3]))
                bm.faces.new((pts[0], pts[2], pts[6], pts[4]))
                bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
                self._add_shoe_bm(role, bm, u, x_center, py, pz, ty, tz, width, tint)
                bm.free()

            lp = pitch * (3.6 if lod else 0.78) * 0.5
            # Main steel link body
            shoe_box("metal_dark", -hw * 0.94, hw * 0.94, -0.005, 0.036, -lp, lp, (0.68, 0.67, 0.65))
            if not lod:
                # Outer steel end-connectors (brighter worn steel edges that make tracks pop!)
                ec_t = pitch * 0.34
                for sx in (-1, 1):
                    shoe_box("metal", sx * (hw * 0.89), sx * (hw * 1.03), -0.012, 0.044, lp * 0.55, lp * 0.55 + ec_t, (0.95, 0.94, 0.92))
                # Twin T158 rubber road pads (split left/right with central groove)
                for sx in (-1, 1):
                    shoe_box("rubber", sx * 0.045, sx * (hw * 0.82), 0.034, 0.072, -lp * 0.76, lp * 0.76, (0.95, 0.95, 0.98))
                # Inner center guide horn (rides between the dual road wheels!)
                shoe_box("metal", -0.024, 0.024, -0.125, -0.045, -lp * 0.48, lp * 0.48, (0.85, 0.85, 0.88))
            else:
                shoe_box("rubber", -hw * 0.80, hw * 0.80, 0.034, 0.072, -lp * 0.78, lp * 0.78, (0.95, 0.95, 0.98))

        # Seat lowest track pad vertex right on y = 0.000
        self.bm.verts.ensure_lookup_table()
        if self.bm.verts:
            min_y = min(v.co.z for v in self.bm.verts)
            if abs(min_y) > 1e-5:
                for v in self.bm.verts:
                    v.co.z -= min_y

    def _add_track_bm(self, role, bm_band, x_center, width, segs_band=True, tint=(1, 1, 1)):
        """Add the continuous loop band with seam-clean U=0..1 across segments."""
        ri = self._role_idx(role)
        bmesh.ops.recalc_face_normals(bm_band, faces=list(bm_band.faces))
        segs = len(bm_band.faces) // 4
        tmesh = bpy.data.meshes.new("_tband")
        bm_band.to_mesh(tmesh)
        f0 = len(self.bm.faces)
        self.bm.from_mesh(tmesh)
        bpy.data.meshes.remove(tmesh)
        self.bm.faces.ensure_lookup_table()
        cl = self.bm.loops.layers.float_color.get("Color")
        ul = self.bm.loops.layers.uv.get("UVMap")
        for idx, f in enumerate(self.bm.faces[f0:]):
            f.material_index = ri
            seg_i = idx // 4
            u0, u1 = seg_i / segs, (seg_i + 1) / segs
            # Map each loop's (y,z) to whichever endpoint (u0 or u1) is closer
            (y0, z0), _, _ = track_sample(u0)
            (y1, z1), _, _ = track_sample(u1)
            for l in f.loops:
                l[cl] = (*tint, 1.0)
                vy, vz = l.vert.co.z, -l.vert.co.y
                d0 = (vy - y0) ** 2 + (vz - z0) ** 2
                d1 = (vy - y1) ** 2 + (vz - z1) ** 2
                u = u0 if d0 <= d1 else u1
                v = l.vert.co.x - x_center + width * 0.5
                l[ul].uv = (u, v)

    def _add_shoe_bm(self, role, bm_shoe, u_center, x_center, py, pz, ty, tz, width, tint):
        def uv_fn(co):
            vy, vz = co.z, -co.y
            along = (vy - py) * ty + (vz - pz) * tz
            return (u_center + along / T_LEN, co.x - x_center + width * 0.5)
        self.add(role, bm_shoe, None, tint=tint, custom_uv=uv_fn)


class VehicleRig:
    """Collects articulated pivot hierarchy for one LOD state (LOD0 or LOD1)."""

    def __init__(self, lod=0):
        self.lod = lod
        self.root_name = f"LOD{lod}"
        self.nodes = []
        self.pivots = {self.root_name: (0.0, 0.0, 0.0)}

    def add(self, name, parent, pivot=(0.0, 0.0, 0.0), part=None, mesh_scale=None):
        assert name not in self.pivots, f"Duplicate node {name}"
        self.pivots[name] = tuple(float(v) for v in pivot)
        self.nodes.append({
            "name": name,
            "parent": parent,
            "pivot": self.pivots[name],
            "part": part,
            "mesh_scale": mesh_scale,
        })
        return part


def _ensure_material(role):
    mat = bpy.data.materials.get(role)
    if mat is None:
        mat = bpy.data.materials.new(role)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        col = PREVIEW.get(role, (0.5, 0.5, 0.5))
        bsdf.inputs["Base Color"].default_value = (*col, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.08 if role == "glass" else 0.78
        bsdf.inputs["Metallic"].default_value = 0.5 if role in ("glass", "metal", "metal_dark") else 0.0
    return mat


def _part_to_mesh_obj(part, obj_name, origin_game, smooth_angle=34.0):
    """Convert `Part` into a multi-material Blender Mesh object localized around `origin_game`."""
    bm = part.bm.copy()
    bmesh.ops.translate(bm, vec=-P(*origin_game), verts=list(bm.verts))
    ang = math.radians(smooth_angle)
    for e in bm.edges:
        e.smooth = True
        if len(e.link_faces) == 2:
            if e.calc_face_angle(0.0) > ang or e.link_faces[0].material_index != e.link_faces[1].material_index:
                e.smooth = False
    for f in bm.faces:
        f.smooth = True

    mesh = bpy.data.meshes.new(obj_name)
    bm.to_mesh(mesh)
    bm.free()

    if mesh.color_attributes:
        mesh.color_attributes.active_color = mesh.color_attributes[0]
        mesh.color_attributes.render_color_index = 0

    for role in part.roles:
        mesh.materials.append(_ensure_material(role))

    obj = bpy.data.objects.new(obj_name, mesh)
    return obj


def build_offroad_tyre(name, wp, lod, side, r=0.56, w=0.38, hub_style="western", lugs=22):
    """Sculpted heavy military off-road pneumatic tyre (Michelin XZL / KAMA) with CTIS hub & 3D shoulder tread blocks."""
    p = Part(name)
    s = side
    hw = w * 0.5
    rc = r - 0.018  # carcass radius; tread blocks reach exact `r`
    rim_r = r * 0.54
    with p.frame(wp):
        if lod:
            prof = [
                (-hw, 0.0, "metal_dark", 0.55),
                (-hw, rim_r, "rubber", 0.90),
                (-hw * 0.92, r, "rubber", 1.0),
                (hw * 0.92, r, "rubber", 1.0),
                (hw, rim_r, "paint", 0.85),
                (hw, 0.0, "paint", 0.85),
            ]
            p.lathe_x((0, 0, 0), prof, seg=10)
            return p

        # Asymmetric outer rim dish & bulging sidewall profile (s > 0 = right side, +X outward)
        prof_r = [
            (-hw * 0.92, 0.0, "metal_dark", 0.42),
            (-hw * 0.92, rim_r * 0.86, "metal_dark", 0.50),
            (-hw * 0.98, rim_r, "rubber", 0.86),
            (-hw * 1.03, r * 0.78, "rubber", 0.94),
            (-hw * 0.90, rc, "rubber", 0.98),
            (hw * 0.90, rc, "rubber", 0.98),
            (hw * 1.03, r * 0.78, "rubber", 0.95),
            (hw * 0.98, rim_r, "paint", 0.84),
            (hw * 0.86, rim_r * 0.92, "paint", 0.72),
            (hw * 0.68, rim_r * 0.58, "paint", 0.76),
            (hw * 0.80, rim_r * 0.36, "paint", 0.90),
            (hw * 0.80, 0.0, "paint", 0.90),
        ]
        if s < 0:
            prof = []
            for i in range(len(prof_r) - 1, -1, -1):
                x_cur, r_cur, _, _ = prof_r[i]
                rp = prof_r[i - 1][2] if i > 0 else "paint"
                kp = prof_r[i - 1][3] if i > 0 else 0.9
                prof.append((-x_cur, r_cur, rp, kp))
            p.lathe_x((0, 0, 0), prof, seg=20)
        else:
            p.lathe_x((0, 0, 0), prof_r, seg=20)

        # Central Tyre Inflation System (CTIS) armoured hub cap + lug bolt ring
        p.pipe("paint", (s * hw * 0.74, 0, 0), (s * hw * 0.98, 0, 0), rim_r * 0.34, seg=12, r2=rim_r * 0.25, bevel=0.008)
        p.pipe("metal_dark", (s * hw * 0.96, 0, 0), (s * hw * 1.03, 0, 0), rim_r * 0.13, seg=8)
        n_bolts = 8 if hub_style == "eastern" else 10
        for b in range(n_bolts):
            ba = math.tau * b / n_bolts
            by, bz = rim_r * 0.72 * math.cos(ba), rim_r * 0.72 * math.sin(ba)
            p.pipe("metal_dark", (s * hw * 0.80, by, bz), (s * hw * 0.90, by, bz), 0.018, seg=6)
        if hub_style == "eastern":
            # Soviet/Russian BTR CTIS armoured air-pipe guard across wheel face
            p.box("paint", (s * hw * 0.82, -0.022, -rim_r * 0.80), (s * hw * 0.99, 0.022, 0.02), bevel=0.005, tint=(0.94, 0.94, 0.92))

        # Sculpted alternating 3D off-road chevron/block tread lugs around circumference
        lug_arc = (math.tau * r / lugs) * 0.34
        for i in range(lugs):
            a = math.tau * i / lugs
            with p.frame((0.0, 0.0, 0.0), pitch=a):
                if i % 2 == 0:
                    p.box("rubber", (-hw * 0.88, rc - 0.004, -lug_arc), (-0.02, r, lug_arc), bevel=0.004, tint=(1.04, 1.04, 1.06))
                    p.box("rubber", (0.02, rc - 0.004, -lug_arc * 0.75), (hw * 0.88, r, lug_arc * 0.95), bevel=0.004, tint=(1.04, 1.04, 1.06))
                else:
                    p.box("rubber", (-hw * 0.88, rc - 0.004, -lug_arc * 0.75), (-0.02, r, lug_arc * 0.95), bevel=0.004, tint=(1.02, 1.02, 1.04))
                    p.box("rubber", (0.02, rc - 0.004, -lug_arc), (hw * 0.88, r, lug_arc), bevel=0.004, tint=(1.02, 1.02, 1.04))
    return p


def build_wreck_from_lod0(lod0_rig, turret_offset=(4.6, 0.0, -0.3), ring_radius=0.96):
    """Create a scorched, battle-damaged static Wreck Part from LOD0 with physically detached turret beside the hull."""
    wreck = Part("Wreck", seed=99)
    parent_map = {n["name"]: n["parent"] for n in lod0_rig.nodes}

    def is_turret_branch(name):
        cur = name
        while cur in parent_map:
            if cur == "Turret":
                return True
            cur = parent_map[cur]
        return False

    has_turret = "Turret" in lod0_rig.pivots
    turret_pivot = P(*lod0_rig.pivots.get("Turret", (0.0, 1.5, 0.15)))
    # Tossed turret rotation & placement beside the hull
    rot_turret = Matrix.Rotation(math.radians(52), 4, "Z") @ Matrix.Rotation(math.radians(24), 4, "Y") @ Matrix.Rotation(math.radians(-18), 4, "X")
    turret_parts_bm = []

    for node in lod0_rig.nodes:
        part = node["part"]
        if part is None or not part.bm.faces or node["name"] == "Turret_Ring":
            continue
        # Copy each role face into scorched metal_dark / rubber
        for f_idx_role, role in enumerate(part.roles):
            if role in ("glass", "markings"):
                continue
            target_role = "rubber" if role == "rubber" else ("dark" if role == "dark" else "metal_dark")
            sub = part.bm.copy()
            kill = [f for f in sub.faces if f.material_index != f_idx_role]
            if kill:
                bmesh.ops.delete(sub, geom=kill, context="FACES")
            if not sub.faces:
                sub.free()
                continue
            if node["mesh_scale"] is not None:
                sx, sy, sz = node["mesh_scale"]
                npiv = P(*node["pivot"])
                bmesh.ops.translate(sub, vec=-npiv, verts=list(sub.verts))
                bmesh.ops.scale(sub, vec=Vector((sx, sz, sy)), verts=list(sub.verts))
                bmesh.ops.translate(sub, vec=npiv, verts=list(sub.verts))
            if has_turret and is_turret_branch(node["name"]):
                bmesh.ops.translate(sub, vec=-turret_pivot, verts=list(sub.verts))
                bmesh.ops.transform(sub, matrix=rot_turret, verts=list(sub.verts))
                turret_parts_bm.append((target_role, sub))
            else:
                wreck.add(target_role, sub, None, tint=(0.42, 0.39, 0.36), jitter=0.06)
                sub.free()

    # Ground the detached turret assembly cleanly on y >= 0
    if turret_parts_bm:
        min_z = min(v.co.z for _, b in turret_parts_bm for v in b.verts)
        shift = P(turret_offset[0], 0.0, turret_offset[2]) + Vector((0.0, 0.0, -min_z + 0.02))
        for role, sub in turret_parts_bm:
            wreck.add(role, sub, Matrix.Translation(shift), tint=(0.38, 0.35, 0.33), jitter=0.06)
            sub.free()

    # Blackened open turret-ring pit on the hull deck
    if has_turret and ring_radius > 0.05:
        tp = lod0_rig.pivots["Turret"]
        wreck.cyl("dark", (tp[0], tp[1] - 0.10, tp[2]), ring_radius, 0.15, seg=20, tint=(0.3, 0.3, 0.3))
        wreck.tube_axis("metal_dark", (tp[0], tp[1] - 0.05, tp[2]), (tp[0], tp[1] + 0.07, tp[2]), ring_radius * 1.12, ring_radius * 0.98, seg=20, tint=(0.35, 0.32, 0.30))
    return wreck


def init_scene():
    """Reset Blender to an empty factory scene before building vehicle rigs."""
    bpy.ops.wm.read_factory_settings(use_empty=True)


def export_vehicle(out_path, lod0_rig, lod1_rig, wreck_part=None, turret_offset=(4.6, 0.0, -0.3), ring_radius=0.96):
    """Assemble LOD0, LOD1 and Wreck in the Blender scene and export a game-ready GLB."""
    scene = bpy.context.scene
    col = scene.collection

    for rig in (lod0_rig, lod1_rig):
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
                mobj = _part_to_mesh_obj(part, mesh_name, pivot)
                mobj.parent = piv_obj
                if node["mesh_scale"] is not None:
                    sx, sy, sz = node["mesh_scale"]
                    mobj.scale = (sx, sz, sy)
                col.objects.link(mobj)

    if wreck_part is None:
        wreck_part = build_wreck_from_lod0(lod0_rig, turret_offset=turret_offset, ring_radius=ring_radius)
    wobj = _part_to_mesh_obj(wreck_part, "Wreck", (0.0, 0.0, 0.0))
    col.objects.link(wobj)

    # Free source bmeshes
    for rig in (lod0_rig, lod1_rig):
        for node in rig.nodes:
            if node["part"] is not None:
                node["part"].bm.free()
    wreck_part.bm.free()

    bpy.context.view_layer.update()
    tris_lod0 = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == "MESH" and not o.name.endswith("_LOD1") and o.name != "Wreck")
    tris_lod1 = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == "MESH" and o.name.endswith("_LOD1"))
    tris_wreck = len(wobj.data.polygons)

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
    print(f"VEHICLE {out_path}: LOD0={tris_lod0} polys, LOD1={tris_lod1} polys, Wreck={tris_wreck} polys")
