extends SceneTree
var w: Node
var errors: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, words: String) -> void:
	checks += 1
	print(("ok " if ok else "FAIL ") + words)
	if not ok: errors.append(words)
func frames(n := 5) -> void:
	for i in range(n): await process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/un-session-" + name + ".png")
func run() -> void:
	set_meta("match_config", {"map":"island", "players":4, "nation":0, "opening":"light"})
	change_scene_to_file("res://world.tscn")
	for i in range(12000):
		await create_timer(0.01).timeout
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene; break
	if w == null: quit(1); return
	if w.menu._root == null: w.menu.setup(w)
	root.size = Vector2i(1280,800)
	w.start_match("easy"); w.menu.close()
	w.set_physics_process(false); w.ai.set_physics_process(false)
	preload("res://tools/test_kit.gd").quiet(w, ["un"])
	w.ui_scale = 1.0; w.apply_ui_scale()
	var u = w.un
	u.current = null; u.assembly_current = null
	u.queue.clear(); u.record.clear(); u.assembly_record.clear(); u.assembly_queue.clear()
	var session = w.hud._un_sessions
	session.refresh()
	check(not session.invitation.visible, "No invented invitation before a UN session")
	var dr: Dictionary = u.table("player", 3, -1, 0, "reported conduct", "economic")
	u._open(dr); session.refresh()
	check(session.invitation.visible and session.pending.size() == 1, "Council invitation persists outside the short notice feed")
	await capture("invitation")
	w.game_time += 5; session.refresh()
	check(session.invitation.visible, "Invitation survives the transient notice lifetime")
	session.join_button.pressed.emit()
	check(session.screen.visible and not session.invitation.visible, "Invitation enters a separate chamber")
	check(w.hud.modal_input_active(), "Chamber blocks map commands and camera input")
	check(not paused, "Entering the chamber does not stop campaign time")
	check(session.effect.text.contains("30%"), "Briefing explains the actual economic effect")
	check(session.ballots.yes.disabled and session.eligibility.text.contains("Consultations"), "Consultations explain why voting is not yet available")
	session.cast("yes")
	check(dr.player_choice == "", "Opening or clicking during consultation never casts a vote")
	await capture("consultations")
	u._to_vote(); session.refresh()
	check(not session.ballots.yes.disabled, "Ballot opens when authoritative Council phase changes")
	check(session.ballots.no.text.contains("VETO"), "Permanent Council seat clearly labels veto")
	var electorate: Array = dr.electorate.duplicate()
	dr.electorate.erase(0); session.refresh()
	check(session.ballots.yes.disabled and session.eligibility.text.contains("no Council seat"), "Country without a seat can attend but cannot cast Council ballots")
	dr.electorate = electorate; session.refresh()
	session.ballots.yes.pressed.emit()
	check(dr.player_choice == "yes" and u.player_vote == "yes", "Yes button records a real Council ballot")
	check(session.choice_label.text.contains("YES"), "Recorded vote is visibly confirmed")
	session.ballots.abstain.pressed.emit()
	check(dr.player_choice == "abstain", "Ballot may be changed before the deadline")
	await frames()
	for b in session.ballots.values():
		check(root.get_visible_rect().encloses(b.get_global_rect()), "Ballot button stays inside laptop viewport")
	await capture("council")
	session.close()
	check(not w.hud.modal_input_active() and session.invitation.visible, "Returning restores map input and preserves active session access")
	w.hud.toggle_panel("un")
	check(session.screen.visible, "UN navigation and U shortcut enter the pending conference")
	session.close()
	w.hud.toggle_panel("un", true)
	check(w.hud.side_mode == "un", "UN affairs hub remains available during an active session")
	w.hud._show_side("")
	w.game_time = float(dr.closes)
	session.open_session(); session.cast("yes")
	check(dr.player_choice == "abstain" and session.ballots.yes.disabled, "Expired ballot is blocked even before UN settlement")
	u._close(); session.refresh()
	check(session.result_label.text.contains("DECISION") and session.ballots.yes.disabled, "Live conference transitions to the recorded result")
	await frames()
	check(session.result_label.visible and root.get_visible_rect().encloses(session.result_label.get_global_rect()), "Final decision stays visible without scrolling the briefing")
	await capture("decision")
	session.close()
	check(not session.invitation.visible, "Reading a decision acknowledges its invitation")
	# Do not attend another session: its outcome must still remain actionable.
	var next: Dictionary = u.table("player", 2, -1, 0, "reported conduct", "condemn")
	u._open(next); u._to_vote(); u._close(); session.refresh()
	check(session.invitation.visible and session.join_button.text.contains("Read decision"), "Missed session leaves a readable decision")
	session.open_session(); session.close()
	# Chapter VI parties must abstain regardless of permanent status.
	var cf: Dictionary = u.table("player", 0, 1, 0, "war", "ceasefire")
	u._open(cf); u._to_vote(); session.open_session()
	check(session.ballots.yes.disabled and session.choice_label.text.contains("Required ballot"), "Chapter VI party sees mandatory abstention")
	session.cast("no")
	check(cf.player_choice == "", "Conference cannot bypass a party's abstention")
	u.current = null; session.close()
	# Assembly uses its own authoritative ballot and no veto.
	u._assembly(next); u._update_assembly()
	session.refresh(); session.open_session("assembly")
	check(not session.ballots.yes.disabled and not session.ballots.no.text.contains("VETO"), "Assembly has a separate ballot without veto")
	check(session.effect.text.contains("non-binding") and session.rule.text.contains("Two-thirds"), "Assembly explains recommendations and threshold")
	session.cast("no")
	check(u.assembly_current.player_choice == "no" and u.player_vote == "", "Assembly choice does not overwrite Council choice")
	var old_status = w.map.nations[0].get("un", "member")
	w.map.nations[0].un = "observer"; session.refresh()
	check(session.ballots.yes.disabled and session.eligibility.text.contains("observer"), "Observers can attend but cannot vote")
	w.map.nations[0].un = old_status
	var old_arrears: float = u.arrears
	var old_history: Array = u._dues_history.duplicate()
	u._dues_history = [100.0, 100.0]
	u.arrears = maxf(100000, u.assessment * 2); session.refresh()
	check(session.ballots.yes.disabled and session.eligibility.text.contains("dues"), "Unpaid dues explain Assembly vote suspension")
	u.arrears = old_arrears; u._dues_history = old_history; session.refresh()
	await capture("assembly")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(u.capture()))
	u.restore(saved)
	session.refresh()
	check(session.choice_label.text.contains("NO") and not session.ballots.yes.disabled, "Saved Assembly ballot is restored into the conference")
	u._finish_assembly(); session.refresh()
	check(session.result_label.text.contains("DECISION"), "Assembly result replaces the ballot in the attended session")
	session.close()
	# Both chambers remain independently accessible when sessions overlap.
	u._open(u.table("player", 3, -1, 0, "conduct", "statement"))
	u._assembly(next); u._update_assembly(); session.refresh()
	check(session.pending.size() == 2, "Concurrent Council and Assembly both have invitations")
	check(session.pending[0].chamber == "assembly", "Open uncast Assembly ballot takes priority over Council consultations")
	session.open_session("council"); u._to_vote(); session.refresh()
	check(session.ballots.no.text.contains("OBJECT") and not session.ballots.no.text.contains("VETO"), "Statement objection is distinguished from formal veto")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE; escape.pressed = true
	session._input(escape)
	check(not session.screen.visible and not w.hud.modal_input_active(), "Escape returns to the game without opening pause menu")
	root.size = Vector2i(1024,720)
	session.open_session("assembly"); await frames(8)
	for b in session.ballots.values():
		check(root.get_visible_rect().encloses(b.get_global_rect()), "Ballot remains accessible on a smaller viewport")
	await capture("compact")
	session.close()
	print("UN_SESSION PASS %d" % checks if errors.is_empty() else "UN_SESSION FAIL: " + str(errors))
	quit(0 if errors.is_empty() else 1)
