"""A humanoid rig for the Blender-made people: bones, rigid skinning, and a pose solver that keys global bone rotations.

Game coordinates (metres, y up, the character faces +z, stands on y 0). The character's right hand is on -x. The mesh is built with
the Model primitives of bl_kit while `rig.bone` names the bone the parts belong to (every vertex gets weight 1 on that bone: rigid
skinning, which reads well at strategy distance, with overlapping joint caps hiding the seams).

Poses are given as global rotations of each bone away from its rest pose (a quaternion or a (axis, degrees) pair in game axes); the
solver turns them into the local rotations the armature needs, down the chain, and keys them. Positions are keyed for the hips only.
"""
import math
import bpy
import bmesh
from mathutils import Vector, Matrix, Quaternion
from bl_kit import Model, P, _uvs, PREVIEW

# name: (parent, head, tail) in game coordinates; the right side is -x
H = 0.95
BONES = {
    "hips": (None, (0, H, 0), (0, H + 0.12, 0)),
    "spine": ("hips", (0, H + 0.1, 0), (0, 1.32, 0)),
    "chest": ("spine", (0, 1.32, 0), (0, 1.52, 0)),
    "neck": ("chest", (0, 1.52, 0), (0, 1.63, 0)),
    "head": ("neck", (0, 1.63, 0), (0, 1.85, 0)),
    "weapon": ("chest", (-0.12, 1.44, 0.1), (-0.12, 1.44, 0.5)),
}
for side, sx in (("R", -1), ("L", 1)):
    BONES["upperarm_" + side] = ("chest", (sx * 0.21, 1.46, 0), (sx * 0.23, 1.18, 0))
    BONES["forearm_" + side] = ("upperarm_" + side, (sx * 0.23, 1.18, 0), (sx * 0.23, 0.93, 0))
    BONES["hand_" + side] = ("forearm_" + side, (sx * 0.23, 0.93, 0), (sx * 0.23, 0.8, 0))
    BONES["thigh_" + side] = ("hips", (sx * 0.1, H, 0), (sx * 0.1, 0.53, 0))
    BONES["shin_" + side] = ("thigh_" + side, (sx * 0.1, 0.53, 0), (sx * 0.1, 0.1, 0))
    BONES["foot_" + side] = ("shin_" + side, (sx * 0.1, 0.1, 0), (sx * 0.1, 0.03, 0.17))
ORDER = list(BONES.keys())
UPARM, FORE, LEN_U, LEN_F = None, None, 0.28, 0.25


def gdir(a, b):
    return (Vector(P(*b)) - Vector(P(*a))).normalized()


class Rig(Model):
    def __init__(self, name):
        super().__init__(name)
        self.bone = "hips"
        self.arm_obj = None
        self.rest = {}          # bone -> 3x3 armature-space rest orientation
        self.restpos = {}       # bone -> head position (Blender)
        self.local = {}         # bone -> current local rotation (3x3)
        self.build_armature()

    # ------------------------------------------------------------ armature
    def build_armature(self):
        arm = bpy.data.armatures.new("Armature")
        obj = bpy.data.objects.new("Armature", arm)
        bpy.context.scene.collection.objects.link(obj)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode="EDIT")
        for name in ORDER:
            parent, head, tail = BONES[name]
            eb = arm.edit_bones.new(name)
            eb.head = P(*head)
            eb.tail = P(*tail)
            eb.roll = 0.0
            if parent:
                eb.parent = arm.edit_bones[parent]
        bpy.ops.object.mode_set(mode="OBJECT")
        self.arm_obj = obj
        for name in ORDER:
            b = arm.bones[name]
            self.rest[name] = b.matrix_local.to_3x3().copy()
            self.restpos[name] = Vector(P(*BONES[name][1]))
        for pb in obj.pose.bones:
            pb.rotation_mode = "QUATERNION"

    # ------------------------------------------------------------ skinning
    def _acc(self, role):
        if role not in self.parts:
            bm = bmesh.new()
            bm.loops.layers.float_color.new("Color")
            bm.verts.layers.deform.verify()
            self.parts[role] = bm
        return self.parts[role]

    def add(self, role, src, matrix=None, tint=(1, 1, 1), jitter=0.0):
        role = self.role_map.get(role, role)
        acc = self._acc(role)
        n0 = len(acc.verts)
        super().add(role, src, matrix, tint, jitter)
        acc = self.parts[role]
        dl = acc.verts.layers.deform.verify()
        acc.verts.ensure_lookup_table()
        gi = ORDER.index(self.bone)
        for v in acc.verts[n0:]:
            v[dl][gi] = 1.0

    # ------------------------------------------------------------ export
    def export(self, out_path, actions=True):
        scene = bpy.context.scene
        objs = []
        for role, bm in self.parts.items():
            if not bm.faces:
                continue
            _uvs(bm)
            ang = math.radians(35.0)
            for e in bm.edges:
                e.smooth = True
                if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > ang:
                    e.smooth = False
            for f in bm.faces:
                f.smooth = True
            mesh = bpy.data.meshes.new(role)
            bm.to_mesh(mesh)
            if mesh.color_attributes:
                mesh.color_attributes.active_color = mesh.color_attributes[0]
                mesh.color_attributes.render_color_index = 0
            obj = bpy.data.objects.new(role, mesh)
            scene.collection.objects.link(obj)
            for name in ORDER:
                obj.vertex_groups.new(name=name)
            mat = bpy.data.materials.new(role)
            mat.use_nodes = True
            col = PREVIEW.get(role, (0.5, 0.5, 0.5))
            mat.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (*col, 1.0)
            obj.data.materials.append(mat)
            obj.parent = self.arm_obj
            mod = obj.modifiers.new("Armature", "ARMATURE")
            mod.object = self.arm_obj
            objs.append(obj)
        bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
        bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", export_apply=False, export_yup=True,
                                  export_materials="EXPORT", export_image_format="NONE", export_texcoords=True,
                                  export_normals=True, export_vertex_color="ACTIVE", export_cameras=False, export_lights=False,
                                  export_animations=actions, export_animation_mode="ACTIONS", export_skins=True)
        print("RIG %s: %d parts, %d actions -> %s" % (self.name, len(objs), len(bpy.data.actions), out_path))

    # ------------------------------------------------------------ posing
    def _global(self, name, q):
        """The global rotation (3x3, armature space) of a bone given its delta q from rest (a Quaternion in armature space)."""
        return q.to_matrix() @ self.rest[name]

    def key_pose(self, action_name, frame, delta, hips_pos=None):
        """Key one frame: `delta` maps bone -> Quaternion (global rotation away from rest; missing bones stay at rest)."""
        obj = self.arm_obj
        act = bpy.data.actions.get(action_name)
        if act is None:
            act = bpy.data.actions.new(action_name)
            act.use_fake_user = True
        if obj.animation_data is None:
            obj.animation_data_create()
        obj.animation_data.action = act
        glob = {}
        for name in ORDER:                                     # parents first (ORDER is topologically sorted)
            parent = BONES[name][0]
            q = delta.get(name, Quaternion())
            Gd = q.to_matrix() @ self.rest[name]                # the wanted global orientation
            if parent is None:
                Gp_rest = Matrix.Identity(3)
                Gp_pose = Matrix.Identity(3)
                base = self.rest[name]
            else:
                Gp_pose = glob[parent]
                base = Gp_pose @ self.rest[parent].inverted() @ self.rest[name]
            L = base.inverted() @ Gd
            glob[name] = Gd
            pb = obj.pose.bones[name]
            pb.rotation_quaternion = L.to_quaternion()
            pb.keyframe_insert("rotation_quaternion", frame=frame)
        hp = obj.pose.bones["hips"]
        off = Vector((0, 0, 0)) if hips_pos is None else Vector(P(*hips_pos))
        hp.location = self.rest["hips"].inverted() @ off
        hp.keyframe_insert("location", frame=frame)
        self.glob = glob

    # ------------------------------------------------------------ forward kinematics on points
    def fk(self, D, off=(0, 0, 0)):
        """Posed head of every bone (Blender vectors) given the global deltas D (bone -> Quaternion) and the hips offset (game vector)."""
        heads = {}
        o = Vector(P(*off))
        for name in ORDER:
            parent = BONES[name][0]
            rest_h = self.restpos[name]
            if parent is None:
                heads[name] = rest_h + o
            else:
                q = D.get(parent, Quaternion())
                heads[name] = heads[parent] + q.to_matrix() @ (rest_h - self.restpos[parent])
        return heads

    def attach(self, heads, D, bone, game_point):
        """Where a point fixed to `bone` (given at rest, game coordinates) is once posed, as a game coordinate tuple."""
        q = D.get(bone, Quaternion())
        p = heads[bone] + q.to_matrix() @ (Vector(P(*game_point)) - self.restpos[bone])
        return (p.x, p.z, -p.y)

    def pose_arms(self, D, off, targets):
        """Add the arm deltas to D so each wrist reaches targets {'R': (bone, rest point), 'L': ...}; the shoulders follow the chest."""
        heads = self.fk(D, off)
        for side, (bone, pt) in targets.items():
            T = self.attach(heads, D, bone, pt)
            shoulder = heads["upperarm_" + side]
            D.update(self.solve_arm(side, T, shoulder=shoulder))
        return D

    def solve_arm(self, side, target, shoulder=None, pole_out=0.5):
        """Two-bone IK for an arm: returns {upperarm_X, forearm_X, hand_X} deltas so the wrist reaches `target` (a game point)."""
        shoulder = Vector(P(*BONES["upperarm_" + side][1])) if shoulder is None else shoulder
        T = Vector(P(*target))
        a, b = LEN_U, LEN_F
        d = T - shoulder
        dist = min(max(d.length, abs(a - b) + 0.01), a + b - 0.005)
        dn = d.normalized()
        cosA = (a * a + dist * dist - b * b) / (2 * a * dist)
        ang = math.acos(max(-1.0, min(1.0, cosA)))
        side_sign = -1 if side == "R" else 1
        hint = Vector(P(side_sign * pole_out, -1.0, -0.15))      # the elbow goes down and out
        perp = (hint - dn * hint.dot(dn)).normalized()
        elbow = shoulder + dn * (a * math.cos(ang)) + perp * (a * math.sin(ang))
        out = {}
        rest_u = gdir(BONES["upperarm_" + side][1], BONES["upperarm_" + side][2])
        rest_f = gdir(BONES["forearm_" + side][1], BONES["forearm_" + side][2])
        out["upperarm_" + side] = rest_u.rotation_difference((elbow - shoulder).normalized())
        out["forearm_" + side] = rest_f.rotation_difference((T - elbow).normalized())
        return out
