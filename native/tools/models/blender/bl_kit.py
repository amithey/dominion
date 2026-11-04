"""Modelling kit for the Blender-made DOMINION buildings (run inside Blender: blender -b -P build_X.py).

Coordinates are the game's: metres, x right, y up, z towards the front of the building. Blender is Z-up with the front
at -Y, so every point goes through P(). Parts are collected per ROLE (a material name the game dresses with the shared
PBR sets: native/godot/scripts/building_models.gd), merged into one mesh per role, given UVs in metres (a texture tile
keeps its real size on every face), smoothed by angle, and exported as a .glb with no textures inside.

Real Blender tools are used where they earn their keep: bmesh bevels for the chamfered concrete edges, boolean cuts for
splayed firing ports and vision slits, height-field meshes for the earth and the camouflage net, curves for wire.
"""
import math
import random
import bpy
import bmesh
from mathutils import Vector, Matrix, Quaternion

# role -> preview colour (the game replaces it with the role's PBR material)
PREVIEW = {
    "wall_concrete": (0.55, 0.55, 0.53), "camo": (0.30, 0.36, 0.22), "earth": (0.30, 0.22, 0.14), "turf": (0.45, 0.40, 0.20),
    "gravel": (0.45, 0.43, 0.40), "asphalt": (0.12, 0.12, 0.13), "wood": (0.35, 0.27, 0.18), "metal": (0.5, 0.52, 0.54),
    "steel_dark": (0.12, 0.14, 0.15), "sandbag": (0.62, 0.55, 0.40), "hazard": (0.85, 0.65, 0.1), "net": (0.20, 0.27, 0.15),
    "dark": (0.02, 0.02, 0.02), "glow_warm": (1.0, 0.85, 0.55), "glow_red": (1.0, 0.2, 0.15), "banner": (0.8, 0.8, 0.8),
    "glow_green": (0.4, 1.0, 0.4), "olive_paint": (0.30, 0.34, 0.22),
    "cladding": (0.8, 0.82, 0.84), "glass": (0.12, 0.2, 0.26), "glow_cyan": (0.6, 0.85, 1.0), "pavers": (0.6, 0.6, 0.58),
    "paint": (0.8, 0.8, 0.8), "stone": (0.7, 0.66, 0.58), "plaster": (0.8, 0.75, 0.62), "brick": (0.55, 0.28, 0.2), "roof_slate": (0.25, 0.27, 0.3), "roof_tile": (0.6, 0.3, 0.2), "copper": (0.3, 0.55, 0.5), "gold": (0.85, 0.65, 0.2), "glow_dim": (0.45, 0.75, 1.0), "leaf": (0.2, 0.4, 0.15), "solar": (0.05, 0.09, 0.16),
}


def P(x, y, z):
    """A game point as a Blender vector."""
    return Vector((x, -z, y))


def _hull(points):
    bm = bmesh.new()
    verts = [bm.verts.new(P(*p)) for p in points]
    bmesh.ops.convex_hull(bm, input=verts)
    return bm


class Model:
    def __init__(self, name):
        self.name = name
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.parts = {}
        self.rng = random.Random(7)
        self._cache = {}
        self.stack = []
        self.markers = []
        self.role_map = {}      # a role drawn as another (a regional style swaps slate for tile, say)
        self.role_tint = {}     # a colour multiplied into every part of a role

    # ------------------------------------------------------------ accumulation
    def _acc(self, role):
        if role not in self.parts:
            bm = bmesh.new()
            bm.loops.layers.float_color.new("Color")
            self.parts[role] = bm
        return self.parts[role]

    def add(self, role, src, matrix=None, tint=(1, 1, 1), jitter=0.0):
        """Append a bmesh (in Blender space) to a role, transformed by matrix and tinted."""
        role = self.role_map.get(role, role)
        if role in self.role_tint:
            tint = tuple(a * b for a, b in zip(tint, self.role_tint[role]))
        acc = self._acc(role)
        tmp = src.copy()
        for f in reversed(self.stack):
            matrix = f if matrix is None else f @ matrix
        if matrix is not None:
            bmesh.ops.transform(tmp, matrix=matrix, verts=tmp.verts)
        mesh = bpy.data.meshes.new("t")
        tmp.to_mesh(mesh)
        tmp.free()
        n0 = len(acc.faces)
        acc.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
        acc.faces.ensure_lookup_table()
        layer = acc.loops.layers.float_color.get("Color")
        for f in acc.faces[n0:]:
            k = 1.0 + self.rng.uniform(-jitter, jitter) if jitter else 1.0
            for l in f.loops:
                l[layer] = (tint[0] * k, tint[1] * k, tint[2] * k, 1.0)

    def add_object(self, role, obj, tint=(1, 1, 1)):
        """A Blender object with modifiers: evaluate them, bring the result in world space, append."""
        dg = bpy.context.evaluated_depsgraph_get()
        ev = obj.evaluated_get(dg)
        mesh = bpy.data.meshes.new_from_object(ev)
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
        self.add(role, bm, obj.matrix_world.copy(), tint)
        bm.free()

    def marker(self, name, pos):
        """An empty node the game reads (Smoke_Industry_0 ... for chimney smoke), at a game point."""
        self.markers.append((name, P(*pos)))

    def frame(self, pos=(0, 0, 0), yaw=0.0, pitch=0.0):
        """`with m.frame(pos, yaw, pitch):` everything inside is placed relative to pos, turned about the up axis, then tipped about x."""
        return _Frame(self, Matrix.Translation(P(*pos)) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(pitch, 4, "X"))

    # ------------------------------------------------------------ primitives
    def box(self, role, lo, hi, bevel=0.0, seg=2, yaw=0.0, tint=(1, 1, 1), about=None):
        """An axis-aligned box from lo to hi (game coords), chamfered by `bevel`, turned `yaw` about `about` (default its centre)."""
        key = ("box", round(hi[0] - lo[0], 4), round(hi[1] - lo[1], 4), round(hi[2] - lo[2], 4), bevel, seg)
        if key not in self._cache:
            bm = bmesh.new()
            bmesh.ops.create_cube(bm, size=1.0)
            for v in bm.verts:
                v.co = Vector((v.co.x * (hi[0] - lo[0]), v.co.y * (hi[2] - lo[2]), v.co.z * (hi[1] - lo[1])))
            if bevel > 0.0:
                b = min(bevel, (hi[0] - lo[0]) * 0.45, (hi[1] - lo[1]) * 0.45, (hi[2] - lo[2]) * 0.45)
                bmesh.ops.bevel(bm, geom=list(bm.edges), offset=b, segments=seg, affect="EDGES", profile=0.6)
            self._cache[key] = bm
        centre = ((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2)
        m = Matrix.Translation(P(*centre))
        if yaw:
            c = P(*(about if about else centre))
            m = Matrix.Translation(c) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Translation(-c) @ m
        self.add(role, self._cache[key], m, tint)

    def cyl(self, role, base, r, h, seg=12, r2=None, tint=(1, 1, 1), cap=True):
        """A vertical cylinder or cone frustum standing on `base`."""
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=cap, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=h)
        self.add(role, bm, Matrix.Translation(P(base[0], base[1] + h / 2, base[2])) , tint)
        bm.free()

    def pipe(self, role, a, b, r, seg=8, tint=(1, 1, 1), r2=None):
        """A cylinder between two game points."""
        pa, pb = P(*a), P(*b)
        d = pb - pa
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=d.length)
        rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
        self.add(role, bm, Matrix.Translation((pa + pb) / 2) @ rot, tint)
        bm.free()

    def dome(self, role, c, r, h, seg=14, rings=5, tint=(1, 1, 1)):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings * 2, radius=1.0)
        for v in list(bm.verts):
            if v.co.z < -1e-4:
                bm.verts.remove(v)
        for v in bm.verts:
            v.co = Vector((v.co.x * r, v.co.y * r, v.co.z * h))
        self.add(role, bm, Matrix.Translation(P(*c)), tint)
        bm.free()

    def geodome(self, role, c, r, h, freq=2, tint=(1, 1, 1), jitter=0.06):
        """A geodesic dome (a radome): flat triangular panels, each a touch different in tone, seams between them."""
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=freq, radius=1.0)
        for v in list(bm.verts):
            if v.co.z < -0.01:
                bm.verts.remove(v)
        for v in bm.verts:
            v.co = Vector((v.co.x * r, v.co.y * r, max(v.co.z, 0.0) * h))
        for f in bm.faces:
            f.material_index = 1
        self.add(role, bm, Matrix.Translation(P(*c)), tint, jitter)
        bm.free()

    def tube(self, role, base, r_out, r_in, h, seg=16, tint=(1, 1, 1)):
        """A vertical ring (a fan housing, a pipe flange): walls inside and out, flat top and bottom."""
        bm = bmesh.new()
        ring = lambda r, z: [bm.verts.new(Vector((math.cos(math.tau * i / seg) * r, math.sin(math.tau * i / seg) * r, z))) for i in range(seg)]
        ob, ot, ib, it = ring(r_out, 0.0), ring(r_out, h), ring(r_in, 0.0), ring(r_in, h)
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((ob[i], ob[j], ot[j], ot[i]))
            bm.faces.new((ib[j], ib[i], it[i], it[j]))
            bm.faces.new((ot[i], ot[j], it[j], it[i]))
            bm.faces.new((ob[j], ob[i], ib[i], ib[j]))
        self.add(role, bm, Matrix.Translation(P(*base)), tint)
        bm.free()

    def lathe(self, role, base, profile, seg=24, tint=(1, 1, 1)):
        """A solid of revolution about the vertical axis at base: profile is a closed polygon of (radius, height) that
        starts and ends on the axis (radius 0): dishes, domes, nose cones, flared bowls."""
        bm = bmesh.new()
        rings = []
        for r, y in profile:
            if r < 1e-6:
                rings.append([bm.verts.new(Vector((0, 0, y)))] * seg)
            else:
                rings.append([bm.verts.new(Vector((math.cos(math.tau * j / seg) * r, math.sin(math.tau * j / seg) * r, y))) for j in range(seg)])
        for i in range(len(profile) - 1):
            for j in range(seg):
                k = (j + 1) % seg
                vs = []
                for v in (rings[i][j], rings[i][k], rings[i + 1][k], rings[i + 1][j]):
                    if v not in vs:
                        vs.append(v)
                if len(vs) >= 3:
                    try:
                        bm.faces.new(vs)
                    except ValueError:
                        pass
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        self.add(role, bm, Matrix.Translation(P(*base)), tint)
        bm.free()

    def loft(self, role, stations, outward_from=None, inward=False, tint=(1, 1, 1), jitter=0.0):
        """A skinned surface through stations (each a list of game points, all the same length): quads between
        neighbours. Faces are turned to look away from `outward_from` (or towards it when `inward`)."""
        bm = bmesh.new()
        rows = [[bm.verts.new(P(*p)) for p in st] for st in stations]
        for i in range(len(rows) - 1):
            for j in range(len(rows[i]) - 1):
                try:
                    f = bm.faces.new((rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]))
                except ValueError:
                    continue
                if outward_from is not None:
                    d = f.calc_center_median() - P(*outward_from)
                    if (f.normal.dot(d) < 0) != inward:
                        f.normal_flip()
        self.add(role, bm, None, tint, jitter)
        bm.free()

    def vault(self, role, cx, z0, z1, hw, y0, rise, seg=12, thick=0.0, tint=(1, 1, 1)):
        """A barrel vault (a hangar, a hall roof) along z from z0 to z1: half an ellipse from y0 up by `rise`. With `thick`
        an inner skin is added so it reads from inside."""
        arc = lambda r_, up: [(cx + (hw + r_) * math.sin(-math.pi / 2 + math.pi * k / seg), y0 + (rise + up) * math.cos(-math.pi / 2 + math.pi * k / seg), 0) for k in range(seg + 1)]
        outer = arc(0.0, 0.0)
        mid = ((z0 + z1) / 2)
        self.loft(role, [[(x, y, z0) for x, y, _ in outer], [(x, y, z1) for x, y, _ in outer]], outward_from=(cx, y0, mid), tint=tint)
        if thick:
            inner = arc(-thick, -thick)
            self.loft(role, [[(x, y, z0) for x, y, _ in inner], [(x, y, z1) for x, y, _ in inner]], outward_from=(cx, y0, mid), inward=True, tint=tint)

    def hull(self, role, points, tint=(1, 1, 1)):
        """The convex solid through some game points (wedges, frusta, teeth)."""
        bm = _hull(points)
        self.add(role, bm, None, tint)
        bm.free()

    def grid(self, role, x0, x1, z0, z1, height, nx=24, nz=12, tint=(1, 1, 1), base=0.0):
        """A height-field surface over x0..x1, z0..z1: height(x, z) metres above `base`."""
        bm = bmesh.new()
        rows = []
        for j in range(nz + 1):
            z = z1 + (z0 - z1) * j / nz          # by = -z ascends with j
            row = []
            for i in range(nx + 1):
                x = x0 + (x1 - x0) * i / nx
                row.append(bm.verts.new(P(x, base + height(x, z), z)))
            rows.append(row)
        for j in range(nz):
            for i in range(nx):
                try:
                    bm.faces.new((rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]))
                except ValueError:
                    pass
        self.add(role, bm, None, tint)
        bm.free()

    def polygon(self, role, pts, y, thick=0.02, tint=(1, 1, 1)):
        """A flat slab with a polygonal outline (x, z pairs) at height y."""
        bm = bmesh.new()
        lo = [bm.verts.new(P(x, y, z)) for x, z in pts]
        f = bm.faces.new(lo)
        if f.normal.z < 0:
            f.normal_flip()
        res = bmesh.ops.extrude_face_region(bm, geom=[f])
        vs = [e for e in res["geom"] if isinstance(e, bmesh.types.BMVert)]
        bmesh.ops.translate(bm, vec=Vector((0, 0, thick)), verts=vs)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        self.add(role, bm, None, tint)
        bm.free()

    # ------------------------------------------------------------ booleans
    def cut_box(self, role, lo, hi, cutters, bevel=0.0, seg=2, tint=(1, 1, 1)):
        """A box with holes: each cutter is a list of game points (their convex hull is subtracted)."""
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co = Vector((v.co.x * (hi[0] - lo[0]), v.co.y * (hi[2] - lo[2]), v.co.z * (hi[1] - lo[1])))
        if bevel > 0.0:
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=seg, affect="EDGES", profile=0.6)
        centre = ((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2)
        mesh = bpy.data.meshes.new("wall")
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new("wall", mesh)
        obj.location = P(*centre)
        bpy.context.scene.collection.objects.link(obj)
        tools = []
        for pts in cutters:
            cb = _hull(pts)
            cm = bpy.data.meshes.new("cut")
            cb.to_mesh(cm)
            cb.free()
            co = bpy.data.objects.new("cut", cm)
            bpy.context.scene.collection.objects.link(co)
            mod = obj.modifiers.new("b", "BOOLEAN")
            mod.operation = "DIFFERENCE"
            mod.solver = "EXACT"
            mod.object = co
            tools.append(co)
        bpy.context.view_layer.update()
        self.add_object(role, obj, tint)
        for t in tools + [obj]:
            bpy.data.objects.remove(t, do_unlink=True)

    # ------------------------------------------------------------ wire
    def wire(self, role, pts, r=0.012, seg=4, tint=(1, 1, 1)):
        """A thin wire along a polyline of game points, built as a bevelled curve."""
        cu = bpy.data.curves.new("w", "CURVE")
        cu.dimensions = "3D"
        cu.bevel_depth = r
        cu.bevel_resolution = max(0, seg // 2 - 1)
        sp = cu.splines.new("POLY")
        sp.points.add(len(pts) - 1)
        for p, q in zip(sp.points, pts):
            v = P(*q)
            p.co = (v.x, v.y, v.z, 1.0)
        obj = bpy.data.objects.new("w", cu)
        bpy.context.scene.collection.objects.link(obj)
        bpy.context.view_layer.update()
        self.add_object(role, obj, tint)
        bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.curves.remove(cu)

    # ------------------------------------------------------------ finish
    def finish(self, out_path, smooth_angle=38.0):
        scene = bpy.context.scene
        for role, bm in self.parts.items():
            if not bm.faces:
                continue
            _uvs(bm)
            ang = math.radians(smooth_angle)
            for e in bm.edges:
                e.smooth = True
                if len(e.link_faces) == 2 and (e.calc_face_angle(0.0) > ang or (e.link_faces[0].material_index == 1 and e.link_faces[1].material_index == 1)):
                    e.smooth = False
            for f in bm.faces:
                f.material_index = 0
            for f in bm.faces:
                f.smooth = True
            mesh = bpy.data.meshes.new(role)
            bm.to_mesh(mesh)
            if mesh.color_attributes:
                mesh.color_attributes.active_color = mesh.color_attributes[0]
                mesh.color_attributes.render_color_index = 0
            obj = bpy.data.objects.new(role, mesh)
            scene.collection.objects.link(obj)
            mat = bpy.data.materials.new(role)
            mat.use_nodes = True
            bsdf = mat.node_tree.nodes.get("Principled BSDF")
            col = PREVIEW.get(role, (0.5, 0.5, 0.5))
            bsdf.inputs["Base Color"].default_value = (*col, 1.0)
            if role.startswith("glow"):
                bsdf.inputs["Emission Color"].default_value = (*col, 1.0)
                bsdf.inputs["Emission Strength"].default_value = 2.0
            obj.data.materials.append(mat)
        for name, pos in self.markers:
            e = bpy.data.objects.new(name, None)
            e.location = pos
            scene.collection.objects.link(e)
        bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", export_apply=True, export_yup=True,
                                  export_materials="EXPORT", export_image_format="NONE", export_texcoords=True,
                                  export_normals=True, export_vertex_color="ACTIVE", export_cameras=False, export_lights=False)
        tris = sum(len(b.faces) for b in self.parts.values())
        print("MODEL %s: %d roles, %d faces -> %s" % (self.name, len(self.parts), tris, out_path))


class _Frame:
    def __init__(self, model, matrix):
        self.model, self.matrix = model, matrix

    def __enter__(self):
        self.model.stack.append(self.matrix)

    def __exit__(self, *a):
        self.model.stack.pop()


def hexc(h, k=1.0):
    """A sRGB hex colour as the linear tint the game multiplies a role's colour by."""
    h = h.lstrip("#")
    out = []
    for i in (0, 2, 4):
        v = int(h[i:i + 2], 16) / 255.0
        out.append(k * (v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4))
    return tuple(out)


def _uvs(bm):
    """UVs in metres: each face is projected along its dominant axis."""
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        n = f.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        for l in f.loops:
            p = l.vert.co
            if az >= ax and az >= ay:
                u, v = p.x, p.y
            elif ax >= ay:
                u, v = p.y, p.z
            else:
                u, v = p.x, p.z
            l[uv].uv = (u, v)
