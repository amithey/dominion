extends SceneTree
## Verifies the dynamic 3-state audio, unit-specific engines, weapon/blast SFX, and organic ambience.

var failures := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		print("ok   %s" % msg)
	else:
		failures += 1
		printerr("FAIL %s" % msg)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	set_meta("match_config", {"map": "island", "players": 2, "nation": 0, "opening": "light", "style": "sandbox"})
	change_scene_to_file("res://world.tscn")
	var w: Node = null
	for _i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("easy")
	w.menu.close()
	preload("res://tools/test_kit.gd").quiet(w)

	var au: Node = w.audio
	check(au != null, "world.audio initialized")
	for key in ["rifle_1", "mg_burst", "cannon", "artillery_fire", "missile_launch", "explosion_1", "explosion_3", "nuke_blast", "siren_short", "engine_loop", "tank_loop", "jet_loop", "heli_loop", "ship_loop", "wind_loop", "surf_loop"]:
		check(au._streams.has(key) and au._streams[key] != null, "audio stream loaded: %s" % key)

	# 3-state adaptive music
	check(au._tension_music != null and au._tension_music.stream != null, "tension_loop stream loaded on Music bus")
	au.set_war_state(false, 5)
	au._battle_hold = 0.0
	au._battle_mix = 0.0
	au._war_tension = 0.0
	au._process(0.1)
	check(au._music.volume_db > -10.0 and au._tension_music.volume_db < -40.0, "peace state plays calm music")

	au.set_war_state(true, 2)
	for _i in range(60):
		au._process(0.1)
	check(au._war_tension > 0.9 and au._tension_music.volume_db > -18.0, "war state smoothly brings in tension music")

	au.play("missile_launch", au._focus)
	check(au._battle_hold > 0.0, "nearby missile_launch triggers battle music hold")
	for _i in range(70):
		au._process(0.1)
	check(au._battle_mix > 0.9 and au._battle_music.volume_db > -18.0, "active battle crossfades to battle_music")

	# Unit-specific engines
	var dummy := Node3D.new()
	w.add_child(dummy)
	var e_tank: AudioStreamPlayer3D = au.add_engine(dummy, "tank")
	var e_jet: AudioStreamPlayer3D = au.add_engine(dummy, "jet")
	var e_heli: AudioStreamPlayer3D = au.add_engine(dummy, "heli")
	var e_ship: AudioStreamPlayer3D = au.add_engine(dummy, "ship")
	check(e_tank.stream == au._streams.tank_loop, "tank uses tank_loop")
	check(e_jet.stream == au._streams.jet_loop, "jet uses jet_loop")
	check(e_heli.stream == au._streams.heli_loop, "heli uses heli_loop")
	check(e_ship.stream == au._streams.ship_loop, "ship uses ship_loop")
	dummy.queue_free()

	# Organic ambience players
	var amb: Node = w.ambience
	check(amb._city_player.stream != null and amb._city_player.stream.get_length() > 8.0, "city ambience uses long organic WAV")
	check(amb._crisis_player.stream != null and amb._crisis_player.stream.get_length() > 8.0, "battle ambience uses long organic WAV (no 2s siren)")
	check(amb._strat_player.stream != null and amb._strat_player.stream.get_length() > 8.0, "war-room ambience uses long organic WAV (no 880Hz beep)")
	check(amb._nature_player != null and amb._nature_player.stream != null, "nature ambience player initialized")

	print("\n==========================================")
	print("AUDIO_OVERHAUL: %d failures" % failures)
	print("AUDIO_OVERHAUL %s" % ("PASS" if failures == 0 else "FAIL"))
	print("==========================================")
	quit(1 if failures > 0 else 0)
