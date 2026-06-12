class_name Prop
extends RigidBody3D
## Breakable street furniture: trash cans, mailboxes, hot dog carts
## and fire hydrants. Ram one and it bursts into bouncing debris.
## Carts launch hot dogs. Hydrants geyser.

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
			# Galvanized can: ribbed drum, rolled rim, domed lid + handle.
			var galv := _metal(Color(0.30, 0.33, 0.36), 0.7, 0.45)
			_mesh_cyl_mat(0.38, 0.34, 1.0, Vector3(0, 0.5, 0), galv)
			_mesh_cyl_mat(0.40, 0.40, 0.05, Vector3(0, 0.28, 0), galv)
			_mesh_cyl_mat(0.40, 0.40, 0.05, Vector3(0, 0.62, 0), galv)
			_mesh_cyl_mat(0.42, 0.42, 0.06, Vector3(0, 1.0, 0), galv)
			var lid := _metal(Color(0.24, 0.26, 0.29), 0.7, 0.5)
			_mesh_cyl_mat(0.12, 0.43, 0.12, Vector3(0, 1.08, 0), lid)
			_mesh_box(Vector3(0.16, 0.05, 0.05), Vector3(0, 1.17, 0), Color(0.2, 0.21, 0.23))
		"mailbox":
			var box := BoxShape3D.new()
			box.size = Vector3(0.5, 1.2, 0.5)
			cs.shape = box
			cs.position = Vector3(0, 0.6, 0)
			add_child(cs)
			# Relay box: rounded top, drop slot, stubby legs.
			var blue := _metal(Color(0.10, 0.22, 0.55), 0.4, 0.45)
			_mesh_box_mat(Vector3(0.5, 0.62, 0.5), Vector3(0, 0.81, 0), blue)
			var top := MeshInstance3D.new()
			var tm := CylinderMesh.new()
			tm.top_radius = 0.25
			tm.bottom_radius = 0.25
			tm.height = 0.5
			tm.material = blue
			top.mesh = tm
			top.rotation.z = PI / 2.0
			top.position = Vector3(0, 1.12, 0)
			add_child(top)
			_mesh_box(Vector3(0.34, 0.05, 0.06), Vector3(0, 1.02, 0.25), Color(0.05, 0.08, 0.18))
			_mesh_box(Vector3(0.3, 0.12, 0.02), Vector3(0, 0.78, 0.26), Color(0.75, 0.75, 0.7))
			for lx: float in [-0.16, 0.16]:
				_mesh_box(Vector3(0.1, 0.5, 0.1), Vector3(lx, 0.25, 0), Color(0.15, 0.15, 0.17))
		"hydrant":
			var cyl2 := CylinderShape3D.new()
			cyl2.radius = 0.25
			cyl2.height = 0.9
			cs.shape = cyl2
			cs.position = Vector3(0, 0.45, 0)
			add_child(cs)
			mass = 60.0  # hydrants do not yield politely
			var red := _metal(Color(0.62, 0.10, 0.08), 0.35, 0.5)
			var cap := _metal(Color(0.72, 0.68, 0.60), 0.5, 0.45)
			_mesh_cyl_mat(0.20, 0.24, 0.55, Vector3(0, 0.38, 0), red)     # barrel
			_mesh_cyl_mat(0.28, 0.28, 0.07, Vector3(0, 0.10, 0), red)     # flange
			_mesh_cyl_mat(0.16, 0.20, 0.18, Vector3(0, 0.72, 0), red)     # dome base
			var dome := MeshInstance3D.new()
			var dm := SphereMesh.new()
			dm.radius = 0.15
			dm.height = 0.3
			dm.material = red
			dome.mesh = dm
			dome.position = Vector3(0, 0.84, 0)
			add_child(dome)
			_mesh_cyl_mat(0.05, 0.05, 0.10, Vector3(0, 0.95, 0), cap)     # bonnet nut
			# Side nozzles and chained caps.
			for side: float in [-1.0, 1.0]:
				var noz := MeshInstance3D.new()
				var nm := CylinderMesh.new()
				nm.top_radius = 0.09
				nm.bottom_radius = 0.09
				nm.height = 0.16
				nm.material = cap
				noz.mesh = nm
				noz.rotation.z = PI / 2.0
				noz.position = Vector3(side * 0.26, 0.5, 0)
				add_child(noz)
			var front := MeshInstance3D.new()
			var fm := CylinderMesh.new()
			fm.top_radius = 0.11
			fm.bottom_radius = 0.11
			fm.height = 0.16
			fm.material = cap
			front.mesh = fm
			front.rotation.x = PI / 2.0
			front.position = Vector3(0, 0.45, 0.26)
			add_child(front)
		"cart":
			var box := BoxShape3D.new()
			box.size = Vector3(1.6, 1.2, 0.9)
			cs.shape = box
			cs.position = Vector3(0, 0.6, 0)
			add_child(cs)
			# Stainless cart: body, griddle lid, wheels, sneeze guard,
			# condiment bottles and the umbrella. The works.
			var steel := _metal(Color(0.68, 0.66, 0.62), 0.8, 0.3)
			_mesh_box_mat(Vector3(1.6, 0.8, 0.9), Vector3(0, 0.6, 0), steel)
			_mesh_box(Vector3(1.7, 0.06, 1.0), Vector3(0, 1.05, 0), Color(0.6, 0.1, 0.1))
			_mesh_box(Vector3(0.7, 0.04, 0.5), Vector3(-0.35, 1.09, 0), Color(0.2, 0.2, 0.22))
			# Sneeze guard: a glass pane over the griddle.
			var glass := StandardMaterial3D.new()
			glass.albedo_color = Color(0.7, 0.8, 0.85, 0.3)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.metallic = 0.6
			glass.roughness = 0.1
			_mesh_box_mat(Vector3(0.7, 0.3, 0.02), Vector3(-0.35, 1.25, 0.2), glass)
			# Condiments. Mustard and ketchup, the eternal duo.
			_mesh_box(Vector3(0.08, 0.18, 0.08), Vector3(0.5, 1.17, 0.25), Color(0.85, 0.7, 0.1))
			_mesh_box(Vector3(0.08, 0.18, 0.08), Vector3(0.62, 1.17, 0.25), Color(0.7, 0.1, 0.08))
			# Cart wheels.
			var tire := StandardMaterial3D.new()
			tire.albedo_color = Color(0.08, 0.08, 0.08)
			for wx: float in [-0.55, 0.55]:
				var wheel := MeshInstance3D.new()
				var wm := CylinderMesh.new()
				wm.top_radius = 0.22
				wm.bottom_radius = 0.22
				wm.height = 0.08
				wm.material = tire
				wheel.mesh = wm
				wheel.rotation.z = PI / 2.0
				wheel.position = Vector3(wx, 0.22, 0.46)
				add_child(wheel)
			# Umbrella: striped canopy with a scalloped rim.
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
			var rim := MeshInstance3D.new()
			var rm := CylinderMesh.new()
			rm.top_radius = 1.1
			rm.bottom_radius = 1.05
			rm.height = 0.08
			var rmm := StandardMaterial3D.new()
			rmm.albedo_color = Color(0.95, 0.9, 0.85)
			rm.material = rmm
			rim.mesh = rm
			rim.position = Vector3(0, 1.83, 0)
			add_child(rim)
			_mesh_box(Vector3(0.06, 1.1, 0.06), Vector3(0, 1.5, 0), Color(0.3, 0.3, 0.32))

func _enter_tree() -> void:
	ready.connect(func() -> void: Game.limit_visibility(self, 95.0), CONNECT_ONE_SHOT)

func _metal(albedo: Color, metallic: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.metallic = metallic
	m.roughness = rough
	return m

func _mesh_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	_mesh_box_mat(size, pos, m)

func _mesh_box_mat(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	add_child(mi)

func _mesh_cyl(radius: float, height: float, pos: Vector3, color: Color) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	_mesh_cyl_mat(radius, radius, height, pos, m)

func _mesh_cyl_mat(r_top: float, r_bot: float, height: float, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bot
	mesh.height = height
	mesh.material = mat
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
	if kind == "hydrant":
		_geyser(parent)
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
		elif kind == "hydrant":
			mesh.size = Vector3(0.18, 0.18, 0.18)
			m.albedo_color = Color(0.62, 0.10, 0.08)
			m.metallic = 0.35
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
		elif kind == "hydrant":
			Game.notify.emit("Free car wash, courtesy of the city")
		elif kind == "trash" and Game.rng.randf() < 0.3:
			Game.add_money(5)
			Game.notify.emit("Found $5 in the trash. Do not ask")
	queue_free()

func _geyser(parent: Node) -> void:
	# Snapped hydrant: a water column erupts for a few seconds.
	var water := GPUParticles3D.new()
	water.amount = 160
	water.lifetime = 1.3
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 7.0
	pm.initial_velocity_min = 13.0
	pm.initial_velocity_max = 17.0
	pm.gravity = Vector3(0, -16, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.1
	water.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.35, 0.35)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(0.65, 0.8, 0.95, 0.55)
	quad.material = m
	water.draw_pass_1 = quad
	water.position = global_position
	parent.add_child(water)
	water.emitting = true
	var t := get_tree().create_timer(5.0)
	t.timeout.connect(func() -> void:
		if is_instance_valid(water):
			water.queue_free())
