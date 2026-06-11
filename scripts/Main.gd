extends Node3D
## Entry point: main menu over a live city flyover, then the open world session.
## Also maintains traffic, pedestrians and police pressure.

enum State { MENU, PLAYING }

var state := State.MENU
var city: CityGen
var missions: MissionManager
var menu_camera: Camera3D
var menu_ui: CanvasLayer
var pause_ui: CanvasLayer
var controls_panel: PanelContainer
var stats_panel: PanelContainer
var settings_menu: SettingsMenu
var updater: Updater
var update_button: Button
var orbit_t := 0.0
var tick := 0.0
var won := false
var prev_stars := 0

const COP_BANTER: Array[String] = [
	"Dispatch: suspect is driving like a shopping cart",
	"Unit 3: he honked the clown horn at me. Requesting emotional backup",
	"Dispatch: be advised, suspect just hit a hot dog cart. Mustard everywhere",
	"Unit 7: I am not going into the harbor again",
	"Dispatch: suspect described as a glowing rectangle",
	"Unit 12: he is doing the thing with the ramp again",
	"Dispatch: all units, bring napkins",
	"Unit 5: my car is also a rectangle. This is very confusing",
	"Dispatch: whoever keeps petting cats on duty, stop it",
	"Unit 9: the pigeons saw everything. They refuse to talk",
]

func _ready() -> void:
	add_to_group("main")
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.reset_session()
	city = CityGen.new()
	add_child(city)
	city.build()
	Game.world = self
	menu_camera = Camera3D.new()
	menu_camera.cull_mask = 1
	menu_camera.far = 900.0
	add_child(menu_camera)
	menu_camera.current = true
	_build_vignette()
	_build_menu()
	_build_pause_ui()
	settings_menu = SettingsMenu.new()
	add_child(settings_menu)
	updater = Updater.new()
	add_child(updater)
	updater.update_available.connect(_on_update_available)
	updater.status.connect(func(text: String) -> void: Game.notify.emit(text))
	if bool(Game.setting("auto_update")):
		updater.check()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if "--autoshot" in OS.get_cmdline_user_args():
		_autoshot()

func _on_update_available(version: String) -> void:
	update_button.text = "UPDATE TO v" + version
	update_button.visible = true

func _process(delta: float) -> void:
	if state == State.MENU:
		orbit_t += delta * 0.06
		var center := Vector3(0, 0, 0)
		menu_camera.global_position = center + Vector3(cos(orbit_t) * 170.0, 95.0, sin(orbit_t) * 170.0)
		menu_camera.look_at(center + Vector3(0, 8, 0), Vector3.UP)
		return
	if get_tree().paused:
		return
	tick += delta
	if tick >= 1.0:
		tick = 0.0
		_maintain_police()
		_maintain_traffic()
		_maintain_peds()

func _unhandled_input(event: InputEvent) -> void:
	if state != State.PLAYING:
		return
	if event.is_action_pressed("pause"):
		_toggle_pause()

# ------------------------------------------------------------ session

func start_game() -> void:
	state = State.PLAYING
	menu_ui.visible = false
	var player := Player.new()
	add_child(player)
	player.global_position = city.spawn_point
	player.wasted.connect(on_player_wasted)
	Game.player = player
	var rig := CameraRig.new()
	add_child(rig)
	Game.camera_rig = rig
	rig.set_target(player, false)
	menu_camera.current = false
	rig.camera.current = true
	var hud := HUD.new()
	add_child(hud)
	Game.hud = hud
	missions = MissionManager.new()
	add_child(missions)
	missions.setup(city)
	missions.all_completed.connect(_on_campaign_done)
	prev_stars = 0
	Game.heat_changed.connect(_on_stars_changed)
	Game.playing = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.notify.emit("Welcome to Neon Harbor. Find the yellow beacon")
	for i in _traffic_target():
		_spawn_traffic_car()
	for i in _ped_target():
		_spawn_ped()

func _traffic_target() -> int:
	return [6, 12, 18][int(Game.setting("traffic"))]

func _ped_target() -> int:
	return [16, 34, 50][int(Game.setting("peds"))]

func _on_stars_changed(stars: int) -> void:
	if stars > prev_stars and Game.playing:
		Game.notify.emit(COP_BANTER[Game.rng.randi_range(0, COP_BANTER.size() - 1)])
	prev_stars = stars

func _on_campaign_done() -> void:
	if won:
		return
	won = true
	Game.hud.show_big("CITY OWNED", HUD.GOLD)
	Game.notify.emit("Campaign complete. Courier jobs pay forever")

func on_player_busted() -> void:
	if not Game.playing:
		return
	Game.total_busts += 1
	Game.sound.play_ui("fail")
	Game.slowmo(0.35, 0.9)
	Game.camera_rig.cine_t = 1.5
	Game.hud.show_big("BUSTED", HUD.RED)
	if missions != null:
		missions.on_player_caught()
	var fine := mini(150, Game.money)
	Game.money -= fine
	Game.notify.emit("Fine paid: $%d" % fine)
	_respawn_at(city.station_point)

func on_player_wasted(reason: String) -> void:
	if not Game.playing:
		return
	Game.total_wrecks += 1
	Game.sound.play_ui("fail")
	Game.slowmo(0.35, 0.9)
	Game.camera_rig.cine_t = 1.5
	Game.hud.show_big(reason, HUD.RED)
	if missions != null:
		missions.on_player_caught()
	var fine := mini(100, Game.money)
	Game.money -= fine
	_respawn_at(city.hospital_point)

func _respawn_at(pos: Vector3) -> void:
	Game.set_heat(0.0)
	if Game.player_car != null:
		Game.player_car.exit()
	Game.player.teleport(pos)
	Game.save_game()

# ------------------------------------------------------------ world upkeep

func _maintain_police() -> void:
	var cops := get_tree().get_nodes_in_group("police")
	var active_cops := 0
	for cop in cops:
		if not cop.leaving:
			active_cops += 1
	var want := Game.stars
	if active_cops < want:
		for i in want - active_cops:
			_spawn_police()
	elif active_cops > want:
		for cop in cops:
			if active_cops <= want:
				break
			if not cop.leaving and cop != Game.player_car:
				cop.leaving = true
				cop.siren.stop()
				active_cops -= 1

func _spawn_police() -> void:
	var p := Game.player_position()
	for attempt in 10:
		var node := CityGen.random_node(Game.rng)
		var pos := CityGen.node_pos(node.x, node.y)
		var d := pos.distance_to(p)
		if d > 80.0 and d < 190.0:
			var cop := PoliceCar.new()
			add_child(cop)
			cop.global_position = pos + Vector3(2.6, 0.7, 0)
			cop.look_at(Vector3(p.x, 0.7, p.z), Vector3.UP)
			return

func _maintain_traffic() -> void:
	var count := get_tree().get_nodes_in_group("traffic").size()
	for i in _traffic_target() - count:
		_spawn_traffic_car()

func _spawn_traffic_car() -> void:
	var p := Game.player_position()
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for attempt in 10:
		var node := CityGen.random_node(Game.rng)
		var pos := CityGen.node_pos(node.x, node.y)
		if pos.distance_to(p) > 55.0:
			var car := TrafficCar.new()
			var kind := "taxi" if Game.rng.randf() < 0.22 else "sedan"
			car.setup(kind, CityGen.CAR_COLORS[Game.rng.randi_range(0, CityGen.CAR_COLORS.size() - 1)])
			add_child(car)
			car.place_on_grid(node.x, node.y, dirs[Game.rng.randi_range(0, 3)])
			return

func _maintain_peds() -> void:
	var peds := get_tree().get_nodes_in_group("peds")
	var p := Game.player_position()
	var alive := 0
	for ped in peds:
		if ped.dead:
			continue
		alive += 1
		if ped.global_position.distance_to(p) > 230.0:
			ped.assign_block(_block_near_player())
	for i in _ped_target() - alive:
		_spawn_ped()
	# Keep the pigeon population thriving.
	var flocks := get_tree().get_nodes_in_group("pigeons").size()
	for i in 10 - flocks:
		city.spawn_pigeon_flock(_block_near_player())

func _block_near_player() -> Vector3:
	var p := Game.player_position()
	var best := city.block_center(0, 0)
	var best_d := 1e9
	for attempt in 6:
		var c := city.block_center(Game.rng.randi_range(0, CityGen.N - 1), Game.rng.randi_range(0, CityGen.N - 1))
		var d := c.distance_to(p)
		if d < best_d and d > 30.0 and d < 160.0:
			best = c
			best_d = d
	return best

func _spawn_ped() -> void:
	var ped := Pedestrian.new()
	add_child(ped)
	ped.assign_block(_block_near_player() if Game.playing else city.block_center(
		Game.rng.randi_range(0, CityGen.N - 1), Game.rng.randi_range(0, CityGen.N - 1)))

# ------------------------------------------------------------ menus

func _build_vignette() -> void:
	# Subtle cinematic edge darkening under all UI.
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tfloat d = length(UV - vec2(0.5));\n\tCOLOR = vec4(0.0, 0.0, 0.02, smoothstep(0.42, 0.95, d) * 0.5);\n}\n"
	var m := ShaderMaterial.new()
	m.shader = sh
	rect.material = m
	layer.add_child(rect)

func _build_menu() -> void:
	menu_ui = CanvasLayer.new()
	add_child(menu_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.build()
	menu_ui.add_child(root)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.01, 0.01, 0.05, 0.72)
	sb.set_corner_radius_all(12)
	sb.border_color = Color(1.0, 0.2, 0.6, 0.85)
	sb.border_width_left = 3
	sb.content_margin_left = 40.0
	sb.content_margin_right = 40.0
	sb.content_margin_top = 30.0
	sb.content_margin_bottom = 30.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	panel.position = Vector2(60, -220)
	root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "NEON HARBOR"
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.6))
	title.add_theme_color_override("font_outline_color", Color(0.45, 0.05, 0.25, 0.8))
	title.add_theme_constant_override("outline_size", 8)
	vb.add_child(title)
	var pulse := title.create_tween().set_loops()
	pulse.tween_property(title, "modulate:a", 0.72, 1.3).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(title, "modulate:a", 1.0, 1.3).set_trans(Tween.TRANS_SINE)
	var sub := Label.new()
	sub.text = "an open world night city sandbox"
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", HUD.CYAN)
	vb.add_child(sub)
	var stats := Label.new()
	stats.text = "Saved cash $%d    Jobs done %d of 6" % [Game.money, Game.missions_done.size()]
	stats.add_theme_font_size_override("font_size", 14)
	stats.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	vb.add_child(stats)
	_menu_button(vb, "START GAME", func() -> void:
		Game.sound.play_ui("click")
		start_game())
	_menu_button(vb, "SETTINGS", func() -> void:
		Game.sound.play_ui("click")
		settings_menu.open())
	_menu_button(vb, "CONTROLS", func() -> void:
		Game.sound.play_ui("click")
		controls_panel.visible = not controls_panel.visible)
	_menu_button(vb, "STATS", func() -> void:
		Game.sound.play_ui("click")
		_refresh_stats()
		stats_panel.visible = not stats_panel.visible)
	_menu_button(vb, "RESET SAVE", func() -> void:
		Game.sound.play_ui("click")
		Game.wipe_save()
		stats.text = "Saved cash $0    Jobs done 0 of 6")
	_menu_button(vb, "QUIT", func() -> void: get_tree().quit())
	update_button = Button.new()
	update_button.visible = false
	update_button.add_theme_font_size_override("font_size", 24)
	update_button.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	update_button.pressed.connect(func() -> void:
		Game.sound.play_ui("click")
		update_button.text = "DOWNLOADING..."
		update_button.disabled = true
		updater.download_and_install())
	vb.add_child(update_button)
	var version := Label.new()
	version.text = "v" + str(ProjectSettings.get_setting("application/config/version", "?"))
	version.add_theme_font_size_override("font_size", 13)
	version.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	vb.add_child(version)
	controls_panel = _make_controls_panel()
	root.add_child(controls_panel)
	stats_panel = _make_stats_panel()
	root.add_child(stats_panel)

func _make_stats_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.01, 0.01, 0.05, 0.88)
	sb.border_color = Color(1.0, 0.85, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 30.0
	sb.content_margin_right = 30.0
	sb.content_margin_top = 20.0
	sb.content_margin_bottom = 20.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-160, -140)
	panel.visible = false
	var l := Label.new()
	l.name = "StatsText"
	l.add_theme_font_size_override("font_size", 19)
	panel.add_child(l)
	return panel

func _refresh_stats() -> void:
	var l: Label = stats_panel.get_node("StatsText")
	l.text = "CAREER RECORD\n\nCash on hand: $%d\nStory jobs done: %d of 6\nGolden cats petted: %d of 5\nTimes busted: %d\nTimes wrecked: %d\n\nThe harbor remembers everything." % [
		Game.money, Game.missions_done.size(), Game.cats_petted.size(),
		Game.total_busts, Game.total_wrecks]

func _menu_button(parent: Node, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(action)
	parent.add_child(b)

func _make_controls_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.01, 0.01, 0.05, 0.85)
	sb.border_color = HUD.CYAN
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 30.0
	sb.content_margin_right = 30.0
	sb.content_margin_top = 20.0
	sb.content_margin_bottom = 20.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-180, -180)
	panel.visible = false
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 18)
	l.text = "ON FOOT\n  WASD or left stick: move\n  Shift: sprint\n  Space: jump\n  E: enter a car\n\nDRIVING\n  W / S: throttle and brake\n  A / D: steer\n  Space: handbrake\n  H: horn\n  E: get out\n\nGENERAL\n  Mouse: camera\n  M: toggle minimap\n  Esc: pause\n\nGamepad works too. Stay out of the harbor."
	panel.add_child(l)
	return panel

func _build_pause_ui() -> void:
	pause_ui = CanvasLayer.new()
	pause_ui.visible = false
	add_child(pause_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.build()
	pause_ui.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.position = Vector2(-110, -120)
	root.add_child(vb)
	var t := Label.new()
	t.text = "PAUSED"
	t.add_theme_font_size_override("font_size", 44)
	t.add_theme_color_override("font_color", HUD.CYAN)
	vb.add_child(t)
	_menu_button(vb, "RESUME", _toggle_pause)
	_menu_button(vb, "SETTINGS", func() -> void:
		Game.sound.play_ui("click")
		settings_menu.open())
	_menu_button(vb, "QUIT TO MENU", func() -> void:
		get_tree().paused = false
		Game.save_game()
		Game.reset_session()
		get_tree().reload_current_scene())
	_menu_button(vb, "QUIT GAME", func() -> void:
		Game.save_game()
		get_tree().quit())

func _toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	pause_ui.visible = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED

# ------------------------------------------------------------ autoshot mode

func _autoshot() -> void:
	# Automated proof run: plays itself and saves screenshots, then quits.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	await get_tree().create_timer(1.5).timeout
	await _snap("shot1_menu")
	start_game()
	await get_tree().create_timer(1.2).timeout
	await _snap("shot2_street")
	Input.action_press("move_forward")
	await get_tree().create_timer(1.6).timeout
	Input.action_release("move_forward")
	await _snap("shot3_onfoot")
	var best: Car = null
	var best_d := 1e9
	for car in get_tree().get_nodes_in_group("cars"):
		var d: float = car.global_position.distance_to(Game.player.global_position)
		if d < best_d:
			best_d = d
			best = car
	if best != null:
		best.enter(Game.player)
	await get_tree().create_timer(0.5).timeout
	Input.action_press("move_forward")
	await get_tree().create_timer(3.2).timeout
	await _snap("shot4_driving")
	Game.add_heat(2.2)
	await get_tree().create_timer(3.0).timeout
	await _snap("shot5_police")
	Input.action_release("move_forward")
	print("AUTOSHOT COMPLETE")
	get_tree().quit()

func _snap(name_: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://shots/%s.png" % name_)
	print("saved shot: %s  FPS: %d" % [name_, int(Engine.get_frames_per_second())])
