class_name TrafficCar
extends Car
## Civilian car that drives lawful laps of the road grid:
## straight on green vibes, random turns at intersections, brakes for obstacles.

var node_k := 0
var node_l := 0
var dir := Vector2i(1, 0)
var target := Vector3.ZERO
var stuck_timer := 0.0
var reversing := 0.0
var relocate_check := 0.0

func _ready() -> void:
	super()
	add_to_group("traffic")
	CityGen.add_blip(self, Color(0.55, 0.55, 0.6), 1.8)

func place_on_grid(k: int, l: int, d: Vector2i) -> void:
	node_k = k
	node_l = l
	dir = d
	var fwd := Vector3(d.x, 0, d.y)
	var right := Vector3(-d.y, 0, d.x)
	position = CityGen.node_pos(k, l) + right * 2.6 + fwd * 6.0 + Vector3(0, 0.7, 0)
	rotation.y = atan2(-fwd.x, -fwd.z)
	_advance()

func _advance() -> void:
	# Pick the next intersection; never U-turn, stay on the grid.
	var options: Array[Vector2i] = []
	for cand in [dir, Vector2i(dir.y, dir.x), Vector2i(-dir.y, -dir.x)]:
		var nk: int = node_k + cand.x
		var nl: int = node_l + cand.y
		if nk >= 0 and nk <= CityGen.N and nl >= 0 and nl <= CityGen.N:
			options.append(cand)
			if cand == dir:
				options.append(cand)  # bias toward going straight
	if options.is_empty():
		dir = -dir
	else:
		dir = options[Game.rng.randi_range(0, options.size() - 1)]
	node_k += dir.x
	node_l += dir.y
	var fwd := Vector3(dir.x, 0, dir.y)
	var right := Vector3(-dir.y, 0, dir.x)
	target = CityGen.node_pos(node_k, node_l) + right * 2.6 + fwd * 2.0

func _ai_control(delta: float) -> void:
	if driver != null:
		return
	if reversing > 0.0:
		reversing -= delta
		steering = 0.0
		engine_force = -power * 0.4
		brake = 0.0
		return
	if global_position.distance_to(target) < 7.0:
		_advance()
	steer_towards(target, 8.5, delta)
	# Stuck recovery: briefly reverse if wedged.
	if linear_velocity.length() < 0.4 and engine_force > 0.0:
		stuck_timer += delta
		if stuck_timer > 3.0:
			stuck_timer = 0.0
			reversing = 1.2
			_play_oneshot("horn")
	else:
		stuck_timer = maxf(stuck_timer - delta, 0.0)
	# Relocate when far from the player to keep streets lively.
	relocate_check += delta
	if relocate_check > 3.0:
		relocate_check = 0.0
		if global_position.distance_to(Game.player_position()) > 260.0:
			var node := CityGen.random_node(Game.rng)
			var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			place_on_grid(node.x, node.y, dirs[Game.rng.randi_range(0, 3)])
