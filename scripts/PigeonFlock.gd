class_name PigeonFlock
extends Node3D
## Four pigeons loitering on the sidewalk. They scatter when approached
## and occasionally leave a comment on your windshield.

var pigeons: Array = []
var flying := false
var fly_t := 0.0
var check_t := 0.0

func _ready() -> void:
	add_to_group("pigeons")
	var gray := StandardMaterial3D.new()
	gray.albedo_color = Color(0.55, 0.55, 0.6)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.3, 0.32, 0.4)
	# Iridescent neck patch, the pigeon signature.
	var irid := StandardMaterial3D.new()
	irid.albedo_color = Color(0.25, 0.45, 0.4)
	irid.metallic = 0.8
	irid.roughness = 0.25
	var beak := StandardMaterial3D.new()
	beak.albedo_color = Color(0.8, 0.6, 0.3)
	for i in 4:
		var bird := Node3D.new()
		bird.position = Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2))
		bird.rotation.y = randf() * TAU
		add_child(bird)
		_part(bird, Vector3(0.16, 0.14, 0.24), Vector3(0, 0.12, 0), gray)
		_part(bird, Vector3(0.09, 0.07, 0.08), Vector3(0, 0.16, 0.13), irid)   # neck
		_part(bird, Vector3(0.1, 0.1, 0.1), Vector3(0, 0.24, 0.14), dark)      # head
		_part(bird, Vector3(0.03, 0.025, 0.06), Vector3(0, 0.235, 0.21), beak) # beak
		_part(bird, Vector3(0.12, 0.03, 0.14), Vector3(0, 0.12, -0.15), dark)  # tail fan
		var w1 := _part(bird, Vector3(0.2, 0.02, 0.14), Vector3(-0.12, 0.16, 0), dark)
		var w2 := _part(bird, Vector3(0.2, 0.02, 0.14), Vector3(0.12, 0.16, 0), dark)
		# Matchstick legs.
		_part(bird, Vector3(0.015, 0.06, 0.015), Vector3(-0.04, 0.025, 0), beak)
		_part(bird, Vector3(0.015, 0.06, 0.015), Vector3(0.04, 0.025, 0), beak)
		pigeons.append({"node": bird, "w1": w1, "w2": w2,
			"dir": Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()})
	Game.limit_visibility(self, 80.0)

func _part(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	return mi

func _process(delta: float) -> void:
	if flying:
		fly_t += delta
		for p in pigeons:
			var bird: Node3D = p["node"]
			bird.position += (p["dir"] * 9.0 + Vector3(0, 5.5, 0)) * delta
			var flap := sin(fly_t * 22.0) * 0.9
			p["w1"].rotation.z = flap
			p["w2"].rotation.z = -flap
		if fly_t > 3.0:
			queue_free()
		return
	# Idle hop shuffle.
	for p in pigeons:
		var bird: Node3D = p["node"]
		bird.position.y = absf(sin(Time.get_ticks_msec() / 180.0 + bird.position.x * 7.0)) * 0.05
	check_t -= delta
	if check_t > 0.0 or not Game.playing:
		return
	check_t = 0.3
	var threat := Game.player_position()
	var d := global_position.distance_to(threat)
	var fast_car := Game.player_car != null and Game.player_speed() > 5.0
	if d < 6.0 or (fast_car and d < 12.0):
		_scatter(fast_car)

func _scatter(by_car: bool) -> void:
	flying = true
	for p in pigeons:
		p["dir"] = (p["node"].global_position - Game.player_position())
		p["dir"].y = 0.0
		p["dir"] = p["dir"].normalized() if p["dir"].length() > 0.1 else Vector3.FORWARD
	var snd := AudioStreamPlayer3D.new()
	snd.stream = Game.sound.stream("flutter")
	snd.unit_size = 8.0
	snd.bus = "SFX"
	add_child(snd)
	snd.play()
	if by_car and Game.rng.randf() < 0.22:
		Game.notify.emit("A pigeon decorated your windshield. No refunds")
