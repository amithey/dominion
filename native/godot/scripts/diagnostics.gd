extends RefCounted
## For testers: when something goes wrong, one button (Help > Report a problem) writes everything a developer needs
## to `user://logs/report.txt`, copies it to the clipboard and opens the folder: the version, the machine, the
## settings, the match and the last messages. The engine's own log (user://logs/godot.log, kept for five runs:
## project.godot [debug]) lies beside it and holds any script error.

const BuildInfo := preload("res://scripts/build_info.gd")

## The text of the report for the running game `w` (a world, or null on the main menu).
static func report(w: Node = null) -> String:
	var lines := PackedStringArray()
	lines.append("DOMINION problem report")
	lines.append("Version: %s" % BuildInfo.full())
	lines.append("Time: %s" % Time.get_datetime_string_from_system())
	lines.append("System: %s %s, %d logical processors" % [OS.get_name(), OS.get_version(), OS.get_processor_count()])
	lines.append("Video: %s, %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version()])
	lines.append("Window: %s, %d FPS" % [str(DisplayServer.window_get_size()), int(Engine.get_frames_per_second())])
	if w != null:
		lines.append("Quality: %s, UI scale %.2f" % [str(w.get("quality")), float(w.get("ui_scale") if w.get("ui_scale") != null else 1.0)])
		if w.get("map") != null and w.get("ai") != null and w.ai != null and not w.ai.nations.is_empty():
			lines.append("Match: %s, %d nations, difficulty %s, game time %d s" % [str(w.match_config.get("map", "?")), w.map.nations.size(), str(w.match_difficulty), int(w.game_time)])
			lines.append("Your nation: %s" % w.diplomacy.name_of(0))
			lines.append("Units %d, buildings %d" % [w.units.size(), w.buildings.size()])
		if w.get("hud") != null and w.hud != null and w.hud.get("notice_log") != null:
			lines.append("")
			lines.append("Last messages:")
			for t in (w.hud.notice_log as Array).slice(-40):
				lines.append("  " + str(t))
	lines.append("")
	lines.append("Please describe what you were doing, and attach this file and godot.log from the same folder.")
	return "\n".join(lines)

## Writes the report, copies it, opens the folder. Returns the path.
static func send(w: Node = null) -> String:
	DirAccess.make_dir_recursive_absolute("user://logs")
	var text := report(w)
	var f := FileAccess.open("user://logs/report.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
	if DisplayServer.get_name() != "headless":
		DisplayServer.clipboard_set(text)
	var folder := ProjectSettings.globalize_path("user://logs")
	if DisplayServer.get_name() != "headless":
		OS.shell_open(folder)
	return folder
