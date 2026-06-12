class_name Cat
extends Node3D
## One of five golden cats hidden around the city. Pet for cash and glory.
## Now a proper sitting cat: haunches, chest, tilted head, wrapped tail
## that sways, ears with inner triangles, whiskers and emerald eyes.

var index := 0
var bob_t := 0.0
var meow_cooldown := 0.0
var visual: Node3D
var head: Node3D
var tail: Node3D

func setup(index_: int) -> void:
	index = index_

func _ready() -> void:
	add_to_group("cats")
	visual = Node3D.new()
	add_child(visual)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.6, 0.45, 0.1)
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.8, 0.25)
	gold.emission_energy_multiplier = 1.6
	gold.metallic = 0.7
	gold.roughness = 0.3
	var dark_gold := StandardMaterial3D.new()
	dark_gold.albedo_color = Color(0.45, 0.32, 0.07)
	dark_gold.emission_enabled = true
	dark_gold.emission = Color(0.8, 0.6, 0.15)
	dark_gold.emission_energy_multiplier = 1.1
	dark_gold.metallic = 0.7
	dark_gold.roughness = 0.35
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color(0.05, 0.2, 0.08)
	eye.emission_enabled = true
	eye.emission = Color(0.3, 1.0, 0.4)
	eye.emission_energy_multiplier = 3.0
	# Sitting pose: haunches at the back, chest rising to the front.
	_part(Vector3(0.34, 0.30, 0.30), Vector3(-0.10, 0.20, 0), gold)    # haunches
	_part(Vector3(0.26, 0.34, 0.24), Vector3(0.10, 0.26, 0), gold)     # chest
	# Front legs planted ahead of the chest.
	_part(Vector3(0.07, 0.24, 0.07), Vector3(0.20, 0.12, 0.07), gold)
	_part(Vector3(0.07, 0.24, 0.07), Vector3(0.20, 0.12, -0.07), gold)
	_part(Vector3(0.08, 0.05, 0.10), Vector3(0.22, 0.03, 0.07), dark_gold)  # paw
	_part(Vector3(0.08, 0.05, 0.10), Vector3(0.22, 0.03, -0.07), dark_gold) # paw
	# Head group so it can tilt curiously.
	head = Node3D.new()
	head.position = Vector3(0.16, 0.52, 0)
	visual.add_child(head)
	_hpart(Vector3(0.20, 0.18, 0.18), Vector3(0, 0, 0), gold)
	_hpart(Vector3(0.08, 0.06, 0.10), Vector3(0.12, -0.04, 0), dark_gold)   # muzzle
	# Ears: outer + inner.
	for ez: float in [-0.06, 0.06]:
		_hpart(Vector3(0.05, 0.09, 0.05), Vector3(0.02, 0.12, ez), gold)
		_hpart(Vector3(0.02, 0.05, 0.03), Vector3(0.045, 0.11, ez), dark_gold)
	# Emerald eyes.
	_hpart_mat(Vector3(0.02, 0.04, 0.04), Vector3(0.105, 0.03, 0.05), eye)
	_hpart_mat(Vector3(0.02, 0.04, 0.04), Vector3(0.105, 0.03, -0.05), eye)
	# Whiskers: thin pale boxes.
	var whisker := StandardMaterial3D.new()
	whisker.albedo_color = Color(0.95, 0.92, 0.8)
	for wz: float in [-1.0, 1.0]:
		for wy: float in [-0.06, -0.03]:
			var w := MeshInstance3D.new()
			var wm := BoxMesh.new()
			wm.size = Vector3(0.005, 0.005, 0.12)
			wm.material = whisker
			w.mesh = wm
			w.position = Vector3(0.13, wy, wz * 0.12)
			w.rotation.y = wz * -0.3
			head.add_child(w)
	# Tail wraps around the haunches and sways.
	tail = Node3D.new()
	tail.position = Vector3(-0.26, 0.10, 0.10)
	visual.add_child(tail)
	var t1 := MeshInstance3D.new()
	var t1m := BoxMesh.new()
	t1m.size = Vector3(0.07, 0.07, 0.30)
	t1m.material = gold
	t1.mesh = t1m
	t1.position = Vector3(0, 0, 0.12)
	tail.add_child(t1)
	var t2 := MeshInstance3D.new()
	var t2m := BoxMesh.new()
	t2m.size = Vector3(0.06, 0.06, 0.16)
	t2m.material = dark_gold
	t2.mesh = t2m
	t2.position = Vector3(0.04, 0.04, 0.28)
	t2.rotation.x = -0.5
	tail.add_child(t2)
	if Game.cats_petted.has(index):
		visual.scale = Vector3(0.85, 0.85, 0.85)

func _part(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	visual.add_child(mi)

func _hpart(size: Vector3, pos: Vector3, mat: Material) -> void:
	_hpart_mat(size, pos, mat)

func _hpart_mat(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	head.add_child(mi)

func _process(delta: float) -> void:
	bob_t += delta
	visual.position.y = absf(sin(bob_t * 2.2)) * 0.05
	visual.rotation.y = sin(bob_t * 0.4) * 0.6
	head.rotation.z = sin(bob_t * 0.9) * 0.12          # curious tilt
	tail.rotation.y = sin(bob_t * 1.6) * 0.35          # sway
	# An occasional hint meow when the player is close but has not found it.
	meow_cooldown -= delta
	if meow_cooldown <= 0.0 and not Game.cats_petted.has(index) and Game.player != null:
		if global_position.distance_to(Game.player_position()) < 14.0:
			meow_cooldown = 5.0
			var p := AudioStreamPlayer3D.new()
			p.stream = Game.sound.stream("meow")
			p.unit_size = 8.0
			p.bus = "SFX"
			add_child(p)
			p.play()
			p.finished.connect(p.queue_free)
		else:
			meow_cooldown = 1.0

func pet() -> void:
	Game.pet_cat(index)
	visual.scale = Vector3(0.85, 0.85, 0.85)
	var tw := create_tween()
	tw.tween_property(visual, "position:y", 0.5, 0.15)
	tw.tween_property(visual, "position:y", 0.0, 0.2)
