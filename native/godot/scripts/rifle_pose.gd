extends SkeletonModifier3D
## Holds a long gun in both hands. The soldier model's clips (Soldier.glb:
## idle, walk, run) are unarmed, so a rifle fixed to the right hand followed a
## hanging or swinging arm and pointed at the ground, or backwards. The rifle
## now rides on the chest (world.dress_realistic), and after each animated
## pose this modifier turns the arms to hold it: at the low ready while
## standing or moving, shouldered and level while firing (`aiming`). The legs,
## hips and head keep their animation.
##
## Directions are in the body's own frame (right, up, forward), measured from
## the pose itself (shoulders and spine), so they hold whatever the clip does.

var aiming := false
var gun: Node3D             # a child of the skeleton, placed here every frame
var gun_basis := Basis()     # the gun turned muzzle along +Z and sized
var gun_centre := Vector3.ZERO
var gun_length := 90.0

# [bone, low ready, shouldered]; each a direction (right, up, forward) for the
# bone to point along (a Mixamo bone's +Y runs toward its child).
const POSE := [
	["mixamorig_RightArm", Vector3(0.25, -0.9, 0.2), Vector3(0.75, -0.45, 0.35)],
	["mixamorig_RightForeArm", Vector3(-0.35, -0.2, 0.9), Vector3(-0.62, 0.12, 0.78)],
	["mixamorig_LeftArm", Vector3(-0.15, -0.88, 0.4), Vector3(-0.3, -0.5, 0.8)],
	["mixamorig_LeftForeArm", Vector3(0.5, -0.12, 0.85), Vector3(0.35, 0.12, 0.93)],
]

var _bones := []

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if _bones.is_empty():
		for b in POSE:
			_bones.append(sk.find_bone(b[0]))
		_bones.append(sk.find_bone("mixamorig_RightArm"))
		_bones.append(sk.find_bone("mixamorig_LeftArm"))
		_bones.append(sk.find_bone("mixamorig_Spine2"))
		_bones.append(sk.find_bone("mixamorig_Hips"))
	if _bones.has(-1):
		return
	var right := (sk.get_bone_global_pose(_bones[4]).origin - sk.get_bone_global_pose(_bones[5]).origin).normalized()
	var up := (sk.get_bone_global_pose(_bones[6]).origin - sk.get_bone_global_pose(_bones[7]).origin).normalized()
	right = (right - up * right.dot(up)).normalized()
	var forward := up.cross(right)
	for i in range(POSE.size()):
		var bone: int = _bones[i]
		var want: Vector3 = POSE[i][2] if aiming else POSE[i][1]
		var dir := (right * want.x + up * want.y + forward * want.z).normalized()
		var global := sk.get_bone_global_pose(bone)
		var now := global.basis.y.normalized()
		var turn := Quaternion(now, dir) if now.dot(dir) > -0.999 else Quaternion(global.basis.x.normalized(), PI)
		var target := Basis(turn) * global.basis
		var parent := sk.get_bone_parent(bone)
		var parent_basis: Basis = sk.get_bone_global_pose(parent).basis if parent >= 0 else Basis()
		sk.set_bone_pose_rotation(bone, (parent_basis.inverse() * target).get_rotation_quaternion())
	if gun == null:
		return
	# The rifle in the same frame: across the body, muzzle low and to the left
	# at the ready; level in the shoulder when firing.
	var chest := sk.get_bone_global_pose(_bones[6]).origin
	var frame := Basis(-right, up, forward)  # right-handed, muzzle (+Z) forward
	var tilt: Basis
	var grip: Vector3
	if aiming:
		tilt = Basis(Vector3.RIGHT, -0.03)
		grip = chest + right * 11.0 + up * 6.0 + forward * 16.0
	else:
		tilt = Basis(Vector3.UP, -0.4) * Basis(Vector3.RIGHT, 0.5)
		grip = chest + right * 8.0 - up * 20.0 + forward * 24.0
	var basis := frame * tilt * gun_basis
	var muzzle := (frame * tilt * Vector3(0, 0, 1)).normalized()
	var centre := grip + muzzle * gun_length * 0.14
	gun.transform = Transform3D(basis, centre - basis * gun_centre)
