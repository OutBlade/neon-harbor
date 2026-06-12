class_name Heli
extends Car
## Arcade helicopter. Space climbs, Shift descends, WASD moves relative
## to the camera, the airframe leans into travel. Nose is local +Z.

var rotor: Node3D
var tail_rotor: MeshInstance3D
var spool := 0.0

func _ready() -> void:
	super()
	mass = 1100.0
	linear_damp = 1.1
	angular_damp = 3.0
	can_sleep = false

func _build_body() -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.7, 1.5, 4.6)
	cs.shape = shape
	cs.position = Vector3(0, 1.0, -0.4)
	add_child(cs)
	var body := StandardMaterial3D.new()
	body.albedo_color = Color(0.95, 0.55, 0.1)
	body.metallic = 0.4
	body.roughness = 0.35
	paint_mat = body
	tail_mat = _light_mat(Color(1.0, 0.1, 0.1), 2.0)
	# Fuselage, canopy, tail boom and fin.
	_box(Vector3(1.5, 1.2, 3.0), Vector3(0, 1.1, 0.3), body)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.3, 0.5, 0.6, 0.45)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic = 0.7
	glass.roughness = 0.08
	var canopy := _box(Vector3(1.3, 0.8, 1.0), Vector3(0, 1.25, 1.55), glass)
	canopy.rotation.x = 0.25
	_box(Vector3(1.52, 0.18, 3.0), Vector3(0, 0.55, 0.3), _light_mat(Color(0.9, 0.9, 0.95), 0.4))
	_box(Vector3(0.34, 0.34, 2.6), Vector3(0, 1.35, -2.4), body)
	_box(Vector3(0.08, 0.9, 0.6), Vector3(0, 1.9, -3.5), body)
	# Skids.
	var skid := _light_mat(Color(0.2, 0.2, 0.24), 0.2)
	for sx: float in [-0.75, 0.75]:
		_box(Vector3(0.1, 0.1, 3.0), Vector3(sx, 0.1, 0.2), skid)
		_box(Vector3(0.08, 0.45, 0.08), Vector3(sx, 0.4, 1.0), skid)
		_box(Vector3(0.08, 0.45, 0.08), Vector3(sx, 0.4, -0.6), skid)
	# Nav lights and tail beacon.
	_box(Vector3(0.1, 0.06, 0.1), Vector3(-0.8, 1.2, 0.3), _light_mat(Color(1, 0.1, 0.1), 3.0))
	_box(Vector3(0.1, 0.06, 0.1), Vector3(0.8, 1.2, 0.3), _light_mat(Color(0.1, 1, 0.2), 3.0))
	_box(Vector3(0.08, 0.08, 0.08), Vector3(0, 2.35, -3.5), tail_mat)
	# Main rotor on a mast, plus the tail rotor.
	_box(Vector3(0.16, 0.4, 0.16), Vector3(0, 1.85, 0), skid)
	rotor = Node3D.new()
	rotor.position = Vector3(0, 2.05, 0)
	add_child(rotor)
	var blade := StandardMaterial3D.new()
	blade.albedo_color = Color(0.12, 0.12, 0.14)
	for ang: float in [0.0, PI / 2.0]:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.34, 0.04, 5.6)
		bm.material = blade
		b.mesh = bm
		b.rotation.y = ang
		rotor.add_child(b)
	tail_rotor = MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.04, 1.1, 0.12)
	tm.material = blade
	tail_rotor.mesh = tm
	tail_rotor.position = Vector3(0.1, 1.9, -3.6)
	add_child(tail_rotor)
	head_beam = SpotLight3D.new()
	head_beam.position = Vector3(0, 0.6, 1.6)
	head_beam.rotation_degrees = Vector3(-35, 180, 0)
	head_beam.spot_range = 55.0
	head_beam.spot_angle = 35.0
	head_beam.light_energy = 6.0
	head_beam.visible = false
	add_child(head_beam)

func _build_wheels() -> void:
	pass  # rotors outrank wheels

func _physics_process(delta: float) -> void:
	enter_cooldown = maxf(enter_cooldown - delta, 0.0)
	var spin := 4.0 + spool * 30.0
	rotor.rotation.y += spin * delta
	tail_rotor.rotation.x += spin * 1.6 * delta
	if is_player:
		spool = move_toward(spool, 1.0, delta * 0.45)
		# Collective: hover force plus climb and descend input.
		var climb := 0.0
		if Input.is_action_pressed("jump"):
			climb = 1.0
		elif Input.is_action_pressed("sprint"):
			climb = -1.0
		var hover := mass * 12.0 * spool
		var ceiling_fade := clampf((85.0 - global_position.y) / 10.0, 0.0, 1.0)
		apply_central_force(Vector3.UP * (hover + climb * mass * 7.0 * ceiling_fade))
		# Camera relative planar movement.
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var yaw: float = Game.camera_rig.yaw if Game.camera_rig != null else 0.0
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		var right := Vector3(-fwd.z, 0, fwd.x)
		var dir := (right * input.x + fwd * -input.y) * spool
		if dir.length() > 1.0:
			dir = dir.normalized()
		if linear_velocity.length() < 30.0:
			apply_central_force(dir * mass * 10.0)
		# Lean into travel and yaw the nose toward it.
		var lean_target := Vector3.UP - dir * 0.32
		apply_torque(global_transform.basis.y.cross(lean_target.normalized()) * mass * 10.0)
		if dir.length() > 0.4:
			var target_yaw := atan2(dir.x, dir.z)
			var err := wrapf(target_yaw - global_transform.basis.get_euler().y, -PI, PI)
			apply_torque(Vector3.UP * err * mass * 5.0)
		if Input.is_action_just_pressed("radio"):
			Game.notify.emit("Radio: " + Game.sound.next_station())
		if Input.is_action_just_pressed("interact") and enter_cooldown <= 0.0:
			exit()
	else:
		spool = move_toward(spool, 0.0, delta * 0.4)
		apply_torque(global_transform.basis.y.cross(Vector3.UP) * mass * 6.0)
	if engine_audio != null:
		engine_audio.pitch_scale = 0.7 + spool * 0.9
		if spool > 0.05 and not engine_audio.playing:
			engine_audio.play()
		elif spool <= 0.05 and engine_audio.playing:
			engine_audio.stop()

func exit() -> void:
	if driver == null:
		return
	# Landing first is strongly encouraged by gravity.
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.5, 0),
		global_position + Vector3(0, -1.6, 0))
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit or linear_velocity.length() > 3.0:
		Game.notify.emit("Land first. The rotor agrees")
		return
	var player := driver
	driver = null
	is_player = false
	head_beam.visible = false
	player.visible = true
	player.teleport(global_position + global_transform.basis.x * -2.2 + Vector3(0, 0.4, 0))
	Game.player_car = null
	Game.camera_rig.set_target(player, false)
	Game.player_state_changed.emit()
