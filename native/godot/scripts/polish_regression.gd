extends RefCounted

static func run(w: Node,campaign: bool) -> void:
	w.set_physics_process(false)
	var errors: Array[String] = []
	if campaign:
		if w.map.nations.size()!=2 or w.map.nations[0].name!="Verdant Union" or w.ai.nations.size()!=1:
			errors.append("Campaign participant/leader selection failed")
		if w.units.any(func(u):return u.owner>1) or w.buildings.any(func(b):return b.owner>1):
			errors.append("Inactive nations remained in the world")
		var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(w.MAP_PATH))
		var n := int(original.grid.size)
		if w.map.grid.heightsCm[120*n+40] != original.grid.heightsCm[120*n+n-41]:
			errors.append("Mirrored map did not transform terrain")
		var data: Dictionary = w.saves.capture()
		var decoded: Dictionary = JSON.parse_string(JSON.stringify(data))
		if w.MatchSetup.normalize(decoded.match_config) != w.match_config:
			errors.append("JSON numeric types changed the campaign identity")
		w.saves.restore(data)
		if data.match_config.nation!=2 or w.map.nations.size()!=2:
			errors.append("Campaign setup missing from save")
	else:
		var tank: Dictionary = w.spawn_unit("tank",w.start,0)
		var rifle: Dictionary = w.spawn_unit("soldier",w.start+Vector3(4,0,0),1)
		var rocket: Dictionary = w.spawn_unit("rocketSoldier",w.start+Vector3(6,0,0),1)
		if w.effectiveness(rifle,tank)!=0 or w.effectiveness(rocket,tank)<=0:
			errors.append("Anti-armour weapon roles failed")
		tank.hp = tank.max_hp*0.5
		tank.moving = false
		tank.enemy = null
		w.economy.res.money = 5000.0
		w.Repairs.request(w,[tank])
		var before: float = tank.hp
		var money: float = w.economy.res.money
		w.Repairs.update(w,1.0)
		if tank.hp<=before or w.economy.res.money>=money:
			errors.append("Repair must heal and charge money")
		tank.last_hit = w.game_time
		before = tank.hp
		w.Repairs.update(w,1.0)
		if tank.hp!=before:
			errors.append("Repair continued under fire")
		w.order_bombard([tank],w.start+Vector3(15,0,0))
		w.order_move([tank],w.start,true)
		if tank.has("ground_attack") or tank.enemy!=null:
			errors.append("Ctrl attack-move did not replace bombardment")
		w.diplomacy.make_peace(0,1)
		w.diplomacy.set_score(0,1,0)
		for u in w.units:
			u.selected = false
		tank.selected = true
		w.update_camera(0.1)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_RIGHT
		click.pressed = true
		click.position = w.camera.unproject_position(rifle.node.position+Vector3.UP)
		click.alt_pressed = true
		w._unhandled_input(click)
		if w.hud._letter_box == null or tank.has("ground_attack"):
			errors.append("Alt bombard must wait for authorization")
		else:
			if "--capture-polish" in OS.get_cmdline_user_args():
				await w.capture_view("res://build/strike-warning.png",tank.node.position,90.0,0.8,30)
			for button in w.hud._letter_box.find_children("*","Button",true,false):
				if button.text=="Cancel":
					button.pressed.emit()
		if w.hostile(0,1) or tank.has("ground_attack"):
			errors.append("Cancelling a strike changed relations or issued an order")
		click.alt_pressed = false
		click.ctrl_pressed = true
		w._unhandled_input(click)
		if tank.target==null or tank.enemy!=null or not tank.attack_move:
			errors.append("Ctrl+right click on an enemy must stay attack-move")
		w.engagement.begin(1,"limited")
		if w.diplomacy.at_war(0,1) or not w.hostile(0,1):
			errors.append("Limited operation must permit defence without full war")
		w.order_attack([tank],rifle)
		w.damage(rifle,1.0,tank)
		if w.diplomacy.at_war(0,1):
			errors.append("Limited strike forced war")
		w.engagement.policy = "war"
		var issued := [false]
		w.engagement.authorize(1,func():issued[0]=true)
		if w.hud._letter_box==null or issued[0]:
			errors.append("Escalating an active operation must require confirmation")
		else:
			for button in w.hud._letter_box.find_children("*","Button",true,false):
				if button.text=="Cancel":
					button.pressed.emit()
		w.engagement.policy = "limited"
		w.game_time += 91
		w.engagement.update()
		if w.hostile(0,1) or tank.enemy!=null:
			errors.append("Limited operation did not expire")
		w.engagement.begin(1,"war")
		if not w.diplomacy.at_war(0,1):
			errors.append("Full war selection failed")
		var navigator = preload("res://scripts/naval_navigation.gd").new()
		navigator.setup(w)
		w.naval_navigation = navigator
		var coast: Vector3 = navigator.point(navigator.nearest(w.start))
		var sea = w.water_near(coast+Vector3(50,0,50),160)
		if sea==null:
			errors.append("No naval fixture")
		else:
			var ship: Dictionary = w.spawn_unit("destroyer",coast,0)
			ship.heading = atan2(w.start.x-coast.x,w.start.z-coast.z) # bow faces the shore
			w.order_move([ship],sea)
			var distance := 0.0
			for i in range(1800):
				var old: Vector3 = ship.node.position
				w.move_craft(ship,0.1)
				if ship.moving and ship.dust!=null and not ship.dust.emitting:
					errors.append("Moving ship lost its wake")
					break
				distance += old.distance_to(ship.node.position)
				if not w.is_water(ship.node.position):
					errors.append("Ship crossed land")
					break
				if ship.target==null:
					break
			if distance<10 or ship.target!=null:
				errors.append("Ship failed to escape the coast and arrive (%.1fm)" % distance)
			w.order_move([ship],w.start) # land clicks resolve to a safe offshore berth
			for i in range(2400):
				w.move_craft(ship,0.1)
				if ship.target==null:
					break
			if ship.target!=null or not w.is_water(ship.node.position):
				errors.append("Coastal destination failed to resolve safely")
		# View outline follows actual camera rays after a half-turn, never a guessed wedge.
		var minimap = preload("res://scripts/minimap.gd").new()
		minimap.world = w
		minimap.size = Vector2(200,200)
		w.cam_yaw = 0
		w.update_camera(0.1)
		var outline: PackedVector2Array = minimap.camera_outline()
		w.cam_yaw = PI
		w.update_camera(0.1)
		var turned: PackedVector2Array = minimap.camera_outline()
		if outline.size()!=4 or turned.size()!=4 or outline[0].distance_to(turned[0])<1:
			errors.append("Minimap view failed to rotate")
		minimap.free()
	for kind in ["AudioStreamPlayer","AudioStreamPlayer3D"]:
		for player in w.find_children("*",kind,true,false):
			player.stop()
	await w.get_tree().create_timer(0.15).timeout
	await w.get_tree().process_frame
	await w.get_tree().process_frame
	print("CAMPAIGN_TEST" if campaign else "POLISH_TEST"," PASS" if errors.is_empty() else " FAIL", " ",errors)
	w.get_tree().quit(0 if errors.is_empty() else 1)
