class_name MissionManager
extends Node3D
## Mission flow: a yellow start beacon marks the next job. Drive or walk into
## it to begin. Cyan beacons mark objectives. After the campaign, endless
## courier jobs keep paying.

signal all_completed

var cg: CityGen
var missions: Array = []
var current: Dictionary = {}
var active := false
var stage := 0
var time_left := -1.0
var start_marker: Area3D = null
var objective_markers: Array = []
var boost_car: Car = null
var passenger: Pedestrian = null
var speed_hold := 0.0
var courier_count := 0

func setup(citygen: CityGen) -> void:
	cg = citygen
	var L := func(k: int) -> float: return CityGen.line(k)
	missions = [
		{
			"id": "package", "title": "PACKAGE RUN", "reward": 350, "type": "delivery",
			"brief": "Grab the package. Do not ask what is inside. Especially do not smell it.",
			"start": Vector3(40, 0, 24), "pickup": Vector3(-120, 0, -97),
			"drop": Vector3(0, 0, 237), "time": 95.0,
		},
		{
			"id": "race", "title": "NEON SPRINT", "reward": 500, "type": "race",
			"brief": "Five checkpoints, one car, zero respect for traffic law.",
			"start": Vector3(L.call(2), 0, 236), "time": 95.0,
			"checkpoints": [
				Vector3(L.call(1), 0, L.call(8)), Vector3(L.call(1), 0, L.call(4)),
				Vector3(L.call(4), 0, L.call(2)), Vector3(L.call(8), 0, L.call(4)),
				Vector3(L.call(8), 0, L.call(8)),
			],
		},
		{
			"id": "taxi", "title": "NIGHT CAB", "reward": 450, "type": "taxi",
			"brief": "Pick up the fare. He is late for a meeting he refuses to describe.",
			"start": Vector3(10, 0, 46), "pickup": Vector3(140, 0, -72),
			"drop": Vector3(-93, 0, -144), "time": 100.0,
		},
		{
			"id": "boost", "title": "HOT WHEELS", "reward": 600, "type": "boost",
			"brief": "A gold Vesper GT is parked uptown. It is not yours. Yet. Bring it to the docks.",
			"start": Vector3(-72, 0, 143), "car_pos": Vector3(168, 0, -99),
		},
		{
			"id": "rooftop", "title": "ROOFTOP CACHE", "reward": 400, "type": "rooftop",
			"brief": "A cache sits on the freight warehouse roof. Crates are a staircase if you believe in yourself.",
			"start": Vector3(-72, 0, 99),
		},
		{
			"id": "speed", "title": "NIGHT RIDER", "reward": 700, "type": "speed",
			"brief": "Hold 85 km/h for six seconds. Your insurance is not real anyway.",
			"start": Vector3(144, 0, 236),
		},
	]
	_place_next_start()

func _next_mission() -> Dictionary:
	for m in missions:
		if not Game.missions_done.has(m["id"]):
			return m
	return {}

func _place_next_start() -> void:
	_clear_start()
	var m := _next_mission()
	if m.is_empty():
		# Campaign done: endless courier jobs from the plaza.
		m = _make_courier()
	start_marker = _marker(m["start"], Color(1.0, 0.85, 0.2), 3.5, _on_start_entered)
	if Game.hud != null:
		Game.hud.set_mission("NEXT JOB: " + m["title"], "Get to the yellow beacon", -1.0)

func _make_courier() -> Dictionary:
	var a := CityGen.random_node(Game.rng)
	var b := CityGen.random_node(Game.rng)
	return {
		"id": "courier", "title": "COURIER RUN %d" % (courier_count + 1),
		"reward": 250 + courier_count * 50, "type": "delivery",
		"brief": "Another parcel, another payday.",
		"start": cg.spawn_point + Vector3(6, -1.2, 6),
		"pickup": CityGen.node_pos(a.x, a.y) + Vector3(2.6, 0, 0),
		"drop": CityGen.node_pos(b.x, b.y) + Vector3(-2.6, 0, 0),
		"time": 85.0,
	}

# ------------------------------------------------------------ flow

func _on_start_entered(body: Node3D) -> void:
	if active or not _is_player(body):
		return
	var m := _next_mission()
	if m.is_empty():
		m = _make_courier()
	current = m
	active = true
	stage = 0
	speed_hold = 0.0
	time_left = m.get("time", -1.0)
	_clear_start()
	Game.sound.play_ui("pickup")
	Game.notify.emit(m["brief"])
	match m["type"]:
		"delivery":
			_objective(m["pickup"], "Pick up the package")
		"race":
			_objective(m["checkpoints"][0], "Checkpoint 1 of 5. Cars only", 5.0)
		"taxi":
			passenger = Pedestrian.new()
			add_child(passenger)
			passenger.global_position = m["pickup"] + Vector3(0, 0.4, 0)
			_objective(m["pickup"], "Pick up the fare")
		"boost":
			boost_car = Car.new()
			boost_car.setup("sports", Color(0.95, 0.78, 0.1))
			add_child(boost_car)
			boost_car.global_position = m["car_pos"] + Vector3(0, 0.7, 0)
			CityGen.add_blip(boost_car, Color(1.0, 0.85, 0.2), 3.2)
			_set_ui("Steal the gold Vesper GT")
		"rooftop":
			_objective(cg.warehouse_roof + Vector3(0, -0.4, 0), "Reach the cache on the roof", 2.5)
		"speed":
			_set_ui("Get a car to 85 km/h and hold it")

func _process(delta: float) -> void:
	if not Game.playing or not active:
		return
	if time_left > 0.0:
		time_left -= delta
		if time_left <= 0.0:
			fail("Out of time")
			return
	match current.get("type", ""):
		"boost":
			if stage == 0 and Game.player_car == boost_car and boost_car != null:
				stage = 1
				Game.add_heat(2.0)
				Game.notify.emit("Silent alarm! Lose the heat or outrun it")
				_objective(cg.dock_point, "Deliver the GT to the dock ramp", 4.0)
		"speed":
			var kmh := Game.player_speed() * 3.6
			if Game.player_car != null and kmh >= 85.0:
				speed_hold += delta
				_set_ui("Hold it! %.1f s of 6" % speed_hold)
				if speed_hold >= 6.0:
					complete()
			else:
				if speed_hold > 0.0:
					_set_ui("Dropped it. Back to 85 km/h")
				speed_hold = 0.0
	_update_timer_ui()

func _on_objective_entered(body: Node3D) -> void:
	if not active or not _is_player(body):
		return
	var t: String = current.get("type", "")
	if t == "race" and Game.player_car == null:
		return
	match t:
		"delivery":
			if stage == 0:
				stage = 1
				Game.sound.play_ui("pickup")
				_objective(current["drop"], "Deliver to the cyan beacon")
			else:
				complete()
		"race":
			stage += 1
			Game.sound.play_ui("pickup")
			var cps: Array = current["checkpoints"]
			if stage >= cps.size():
				complete()
			else:
				_objective(cps[stage], "Checkpoint %d of 5" % (stage + 1), 5.0)
		"taxi":
			if stage == 0:
				stage = 1
				if passenger != null:
					passenger.queue_free()
					passenger = null
				Game.sound.play_ui("pickup")
				_objective(current["drop"], "Take the fare to the cyan beacon")
			else:
				complete()
		"boost":
			if stage == 1 and Game.player_car == boost_car:
				complete()
		"rooftop":
			if body == Game.player:
				complete()

func complete() -> void:
	active = false
	_clear_objectives()
	Game.sound.play_ui("jingle")
	Game.add_money(current["reward"])
	Game.notify.emit("MISSION PASSED: " + current["title"])
	if Game.hud != null:
		Game.hud.show_big("MISSION PASSED", Color(0.3, 1.0, 0.5))
	if current["id"] == "courier":
		courier_count += 1
	else:
		Game.mission_completed(current["id"])
		if _next_mission().is_empty():
			all_completed.emit()
	boost_car = null
	current = {}
	await get_tree().create_timer(2.0).timeout
	_place_next_start()

func fail(reason: String) -> void:
	if not active:
		return
	active = false
	_clear_objectives()
	if passenger != null:
		passenger.queue_free()
		passenger = null
	Game.sound.play_ui("fail")
	if Game.hud != null:
		Game.hud.show_big("MISSION FAILED", Color(1.0, 0.25, 0.25))
	Game.notify.emit(reason)
	current = {}
	await get_tree().create_timer(2.0).timeout
	_place_next_start()

func on_player_caught() -> void:
	fail("The job fell through")

# ------------------------------------------------------------ markers and ui

func _is_player(body: Node3D) -> bool:
	return body == Game.player or (Game.player_car != null and body == Game.player_car)

func _marker(pos: Vector3, color: Color, radius: float, callback: Callable) -> Area3D:
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 5.0
	cs.shape = cyl
	cs.position = Vector3(0, 2.0, 0)
	area.add_child(cs)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.5
	torus.outer_radius = radius
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.05, 0.05, 0.05)
	rm.emission_enabled = true
	rm.emission = color
	rm.emission_energy_multiplier = 3.5
	torus.material = rm
	ring.mesh = torus
	ring.position = Vector3(0, 0.4, 0)
	area.add_child(ring)
	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 70.0, 0.6)
	var beam_mat := StandardMaterial3D.new()
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.albedo_color = Color(color.r, color.g, color.b, 0.25)
	beam_mat.emission_enabled = true
	beam_mat.emission = color
	beam_mat.emission_energy_multiplier = 1.6
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = beam_mat
	beam.mesh = bm
	beam.position = Vector3(0, 35.0, 0)
	area.add_child(beam)
	CityGen.add_blip(area, color, 3.5)
	area.position = pos
	area.body_entered.connect(callback)
	add_child(area)
	return area

func _objective(pos: Vector3, text: String, radius: float = 3.0) -> void:
	_clear_objectives()
	objective_markers.append(_marker(pos, Color(0.15, 0.9, 1.0), radius, _on_objective_entered))
	_set_ui(text)

func _set_ui(objective: String) -> void:
	if Game.hud != null and not current.is_empty():
		Game.hud.set_mission(current["title"], objective, time_left)

func _update_timer_ui() -> void:
	if Game.hud != null:
		Game.hud.update_mission_timer(time_left)

func _clear_objectives() -> void:
	for m in objective_markers:
		if is_instance_valid(m):
			m.queue_free()
	objective_markers = []

func _clear_start() -> void:
	if start_marker != null and is_instance_valid(start_marker):
		start_marker.queue_free()
	start_marker = null
