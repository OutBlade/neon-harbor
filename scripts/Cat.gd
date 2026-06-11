class_name Cat
extends Node3D
## One of five golden cats hidden around the city. Pet for cash and glory.

var index := 0
var bob_t := 0.0
var meow_cooldown := 0.0
var visual: Node3D

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
	_part(Vector3(0.4, 0.22, 0.22), Vector3(0, 0.16, 0), gold)        # body
	_part(Vector3(0.18, 0.18, 0.16), Vector3(0.24, 0.32, 0), gold)    # head
	_part(Vector3(0.05, 0.08, 0.04), Vector3(0.3, 0.45, 0.05), gold)  # ear
	_part(Vector3(0.05, 0.08, 0.04), Vector3(0.3, 0.45, -0.05), gold) # ear
	_part(Vector3(0.3, 0.05, 0.05), Vector3(-0.3, 0.3, 0), gold)      # tail
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

func _process(delta: float) -> void:
	bob_t += delta
	visual.position.y = absf(sin(bob_t * 2.2)) * 0.08
	visual.rotation.y = sin(bob_t * 0.4) * 0.6
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
