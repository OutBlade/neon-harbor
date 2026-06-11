class_name Prop
extends RigidBody3D
## Breakable street furniture: trash cans, mailboxes and hot dog carts.
## Ram one and it bursts into bouncing debris. Carts launch hot dogs.

var kind := "trash"
var broken := false

func setup(kind_: String) -> void:
	kind = kind_

func _ready() -> void:
	mass = 16.0
	contact_monitor = true
	max_contacts_reported = 3
	body_entered.connect(_on_hit)
	can_sleep = true
	var cs := CollisionShape3D.new()
	match kind:
		"trash":
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.4
			cyl.height = 1.0
			cs.shape = cyl
			cs.position = Vector3(0, 0.5, 0)
			add_child(cs)
			_mesh_cyl(0.4, 1.0, Vector3(0, 0.5, 0), Color(0.18, 0.2, 0.22))
			_mesh_cyl(0.44, 0.08, Vector3(0, 1.02, 0), Color(0.12, 0.13, 0.15))
		"mailbox":
			var box := BoxShape3D.new()
			box.size = Vector3(0.5, 1.2, 0.5)
			cs.shape = box
			cs.position = Vector3(0, 0.6, 0)
			add_child(cs)
			_mesh_box(Vector3(0.5, 0.7, 0.5), Vector3(0, 0.85, 0), Color(0.1, 0.25, 0.6))
			_mesh_box(Vector3(0.12, 0.5, 0.12), Vector3(0, 0.25, 0), Color(0.15, 0.15, 0.17))
		"cart":
			var box := BoxShape3D.new()
			box.size = Vector3(1.6, 1.2, 0.9)
			cs.shape = box
			cs.position = Vector3(0, 0.6, 0)
			add_child(cs)
			_mesh_box(Vector3(1.6, 0.8, 0.9), Vector3(0, 0.6, 0), Color(0.75, 0.72, 0.68))
			_mesh_box(Vector3(1.7, 0.06, 1.0), Vector3(0, 1.05, 0), Color(0.6, 0.1, 0.1))
			# Umbrella, the universal hot dog cart signifier.
			var um := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 1.1
			cone.height = 0.5
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.9, 0.25, 0.2)
			m.emission_enabled = true
			m.emission = Color(0.9, 0.3, 0.2)
			m.emission_energy_multiplier = 0.7
			cone.material = m
			um.mesh = cone
			um.position = Vector3(0, 2.1, 0)
			add_child(um)
			_mesh_box(Vector3(0.06, 1.1, 0.06), Vector3(0, 1.5, 0), Color(0.3, 0.3, 0.32))

func _mesh_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	mesh.material = m
	mi.mesh = mesh
	mi.position = pos
	add_child(mi)

func _mesh_cyl(radius: float, height: float, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	mesh.material = m
	mi.mesh = mesh
	mi.position = pos
	add_child(mi)

func _on_hit(body: Node) -> void:
	if broken or not body is VehicleBody3D:
		return
	if body.linear_velocity.length() < 6.0:
		return
	broken = true
	var vel: Vector3 = body.linear_velocity
	var parent := get_parent()
	var count := 7 if kind == "cart" else 5
	for i in count:
		var bit := RigidBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.22, 0.22, 0.22)
		cs.shape = shape
		bit.add_child(cs)
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		var m := StandardMaterial3D.new()
		if kind == "cart" and i >= 2:
			# Flying hot dogs.
			mesh.size = Vector3(0.12, 0.12, 0.42)
			m.albedo_color = Color(0.85, 0.45, 0.25)
			m.emission_enabled = true
			m.emission = Color(0.85, 0.45, 0.25)
			m.emission_energy_multiplier = 0.5
		else:
			mesh.size = Vector3(0.22, 0.22, 0.22)
			m.albedo_color = Color(0.3, 0.3, 0.32)
		mesh.material = m
		mi.mesh = mesh
		bit.add_child(mi)
		bit.mass = 1.0
		bit.position = global_position + Vector3(randf_range(-0.4, 0.4), 0.8 + randf() * 0.6, randf_range(-0.4, 0.4))
		parent.add_child(bit)
		bit.linear_velocity = vel * 0.5 + Vector3(randf_range(-3, 3), randf_range(4, 9), randf_range(-3, 3))
		bit.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		var t := get_tree().create_timer(6.0)
		t.timeout.connect(func() -> void:
			if is_instance_valid(bit):
				bit.queue_free())
	var p := AudioStreamPlayer3D.new()
	p.stream = Game.sound.stream("clang")
	p.unit_size = 12.0
	p.bus = "SFX"
	p.position = global_position
	parent.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	if body == Game.player_car:
		if kind == "cart":
			Game.notify.emit("Hot dogs everywhere. The vendor saw nothing")
		elif kind == "trash" and Game.rng.randf() < 0.3:
			Game.add_money(5)
			Game.notify.emit("Found $5 in the trash. Do not ask")
	queue_free()
