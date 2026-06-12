class_name RaceSystem
extends Node3D
## Three street races. Drive into a purple ring to start, hit every
## checkpoint, beat the par time for a bonus. Best times persist.

var mm: MissionManager
var races: Array = []
var active := -1
var cp := 0
var t := 0.0
var cp_marker: Node3D = null
var countdown := false

func setup(missions: MissionManager) -> void:
	mm = missions
	var L := func(k: int) -> float: return CityGen.line(k)
	races = [
		{
			"name": "HARBOR LOOP", "par": 55.0, "prize": 700,
			"start": Vector3(L.call(5) + 2.6, 0, 236.0),
			"checkpoints": [
				Vector3(L.call(8), 0, L.call(9)), Vector3(L.call(9), 0, L.call(5)),
				Vector3(L.call(6), 0, L.call(3)), Vector3(L.call(3), 0, L.call(5)),
				Vector3(L.call(2), 0, L.call(9)), Vector3(L.call(5) + 2.6, 0, 236.0),
			],
		},
		{
			"name": "UPTOWN SCRAMBLE", "par": 65.0, "prize": 900,
			"start": Vector3(L.call(2) + 2.6, 0, L.call(1)),
			"checkpoints": [
				Vector3(L.call(5), 0, L.call(2)), Vector3(L.call(8), 0, L.call(1)),
				Vector3(L.call(9), 0, L.call(4)), Vector3(L.call(5), 0, L.call(5)),
				Vector3(L.call(1), 0, L.call(4)), Vector3(L.call(2) + 2.6, 0, L.call(1)),
			],
		},
		{
			"name": "FULL TOUR", "par": 110.0, "prize": 1500,
			"start": Vector3(L.call(9) - 2.6, 0, L.call(5)),
			"checkpoints": [
				Vector3(L.call(9), 0, L.call(1)), Vector3(L.call(5), 0, L.call(0)),
				Vector3(L.call(1), 0, L.call(1)), Vector3(L.call(0), 0, L.call(5)),
				Vector3(L.call(1), 0, L.call(9)), Vector3(L.call(5), 0, 236.0),
				Vector3(L.call(9), 0, L.call(9)), Vector3(L.call(9) - 2.6, 0, L.call(5)),
			],
		},
	]
	for r in races:
		var ring := _ring(r["start"], Color(0.75, 0.3, 1.0), 4.0)
		var label := Label3D.new()
		label.text = "STREET RACE: " + r["name"]
		label.font_size = 72
		label.pixel_size = 0.012
		label.modulate = Color(1.3, 0.6, 1.8)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = r["start"] + Vector3(0, 5.5, 0)
		add_child(label)
		r["ring"] = ring

func _ring(pos: Vector3, col: Color, radius: float) -> Node3D:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.5
	torus.outer_radius = radius
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.05, 0.05)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 3.4
	torus.material = m
	ring.mesh = torus
	ring.position = pos + Vector3(0, 0.4, 0)
	add_child(ring)
	CityGen.add_blip(ring, col, 2.6)
	return ring

func _physics_process(delta: float) -> void:
	if not Game.playing or countdown:
		return
	if active == -1:
		if Game.player_car == null or mm.active or Game.player_car.kind in ["boat", "heli"]:
			return
		for i in races.size():
			var r: Dictionary = races[i]
			if Game.player_car.global_position.distance_to(r["start"]) < 5.0 \
					and Game.player_speed() < 3.0:
				_begin(i)
				return
	else:
		t += delta
		var r: Dictionary = races[active]
		if Game.player_car == null:
			Game.notify.emit("Race abandoned. The car was the whole point")
			_cleanup()
			return
		Game.hud.set_mission("RACE: " + r["name"],
			"Checkpoint %d of %d    %.1f s   (par %.0f s)" % [cp + 1, r["checkpoints"].size(), t, r["par"]], -1.0)
		if cp_marker != null and Game.player_car.global_position.distance_to(cp_marker.global_position) < 6.5:
			Game.sound.play_ui("pickup")
			cp += 1
			if cp >= r["checkpoints"].size():
				_finish(r)
			else:
				_place_cp(r)

func _begin(i: int) -> void:
	countdown = true
	active = i
	cp = 0
	t = 0.0
	var r: Dictionary = races[i]
	Game.notify.emit("RACE: %s. Get ready" % r["name"])
	for n in [3, 2, 1]:
		Game.sound.play_ui("click")
		Game.hud.show_big(str(n), Color(0.75, 0.3, 1.0))
		await get_tree().create_timer(0.9).timeout
	Game.hud.show_big("GO", Color(0.3, 1.0, 0.5))
	Game.sound.play_ui("jingle")
	countdown = false
	_place_cp(r)

func _place_cp(r: Dictionary) -> void:
	if cp_marker != null and is_instance_valid(cp_marker):
		cp_marker.queue_free()
	cp_marker = _ring(r["checkpoints"][cp], Color(0.2, 0.95, 1.0), 5.0)

func _finish(r: Dictionary) -> void:
	var prize: int = r["prize"]
	var msg := "RACE FINISHED in %.1f s." % t
	if t <= r["par"]:
		prize += 500
		msg += " Under par, +$500"
	Game.add_money(prize)
	var best: float = float(Game.race_best.get(r["name"], 9999.0))
	if t < best:
		Game.race_best[r["name"]] = t
		msg += " NEW BEST TIME"
	Game.save_game()
	Game.sound.play_ui("jingle")
	Game.hud.show_big("FINISHED", Color(0.3, 1.0, 0.5))
	Game.notify.emit(msg)
	_cleanup()

func _cleanup() -> void:
	if cp_marker != null and is_instance_valid(cp_marker):
		cp_marker.queue_free()
	cp_marker = null
	active = -1
	mm._place_next_start()
