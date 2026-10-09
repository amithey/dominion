extends SceneTree
const Ambience := preload("res://scripts/ambience.gd")
class AmbienceWorld extends Node3D:
	var game_time := 200.0
	var cam_focus := Vector3.ZERO
	var map := {"seaLevel":0.0}
	var buildings: Array = []
	var effects = null
	func height_at(_x: float, _z: float) -> float: return 0.0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	print(("ok " if ok else "FAIL ") + text)
	if not ok: failures += 1
func run() -> void:
	var w := AmbienceWorld.new(); root.add_child(w)
	var camera := Camera3D.new(); w.add_child(camera); camera.current = true
	camera.position = Vector3(0,60,60); camera.look_at(Vector3.ZERO)
	# A prior winter scene must not leave snow in a newly loaded summer.
	RenderingServer.global_shader_parameter_set("winter", 1.0)
	var a := Ambience.new(w); w.add_child(a)
	a.update(0.0)
	# Godot's global getter is editor-only. Inspect a shader probe instead.
	var probe := ColorRect.new(); root.add_child(probe); probe.position = Vector2(10,10); probe.size = Vector2(64,64)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; global uniform float winter; void fragment() { COLOR = vec4(vec3(winter), 1.0); }"
	var material := ShaderMaterial.new(); material.shader = shader; probe.material = material
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var snow: float = root.get_texture().get_image().get_pixel(20,20).r
	check(snow < 0.05, "a new summer scene resets snow left by the preceding winter scene (%.2f)" % snow)
	# A single building can contain several stacks: cap the inner loop too.
	for n in range(2):
		var site := Node3D.new(); w.add_child(site)
		for i in range(20):
			var marker := Marker3D.new(); marker.name = "SmokeIndustry%d" % i; site.add_child(marker)
		w.buildings.append({"dead":false,"built":true,"root":site,"supplied":true})
	a._update_plumes()
	check(a.plumes() <= Ambience.MAX_PLUMES, "smoke budget holds across multiple stacks per building (%d / %d)" % [a.plumes(), Ambience.MAX_PLUMES])
	print("AMBIENCE_REGRESSION: 2 checks, %d failures" % failures)
	quit(0 if failures == 0 else 1)
