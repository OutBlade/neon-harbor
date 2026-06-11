class_name Car
extends VehicleBody3D
## Arcade vehicle built from primitives. Drivable by the player,
## extended by TrafficCar and PoliceCar for AI control.

var kind := "sedan"
var color := Color(0.6, 0.1, 0.1)
var is_player := false
var driver: Player = null
var power := 4200.0
var top_speed := 26.0
var engine_audio: AudioStreamPlayer3D
var flip_timer := 0.0
var enter_cooldown := 0.0
var headlights: Array = []
var head_beam: SpotLight3D
var tail_mat: StandardMaterial3D
var wheels: Array = []
var smoke: GPUParticles3D
var air_time := 0.0
var stunt_slowmo := false

func setup(kind_: String, color_: Color) -> void:
	kind = kind_
	color = color_

func _ready() -> void:
	add_to_group("cars")
	mass = 780.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.35, 0)
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_impact)
	can_sleep = true
	if kind == "sports":
		power = 5600.0
		top_speed = 34.0
	elif kind == "police":
		power = 5200.0
		top_speed = 31.0
		color = Color(0.08, 0.08, 0.1)
	_build_body()
	_build_wheels()
	engine_audio = AudioStreamPlayer3D.new()
	engine_audio.stream = Game.sound.stream("engine")
	engine_audio.unit_size = 6.0
	engine_audio.max_db = -3.0
	add_child(engine_audio)
	_build_smoke()

func _build_smoke() -> void:
	smoke = GPUParticles3D.new()
	smoke.amount = 36
	smoke.lifetime = 0.8
	smoke.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 35.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0, 1.2, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	smoke.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.7, 0.7, 0.75, 0.35)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = m
	smoke.draw_pass_1 = quad
	smoke.position = Vector3(0, 0.3, 1.6)
	add_child(smoke)

func _build_body() -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.95, 0.95, 4.3)
	cs.shape = shape
	cs.position = Vector3(0, 0.78, 0)
	add_child(cs)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.metallic = 0.6
	paint.roughness = 0.35
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.08, 0.1, 0.13)
	glass.metallic = 0.8
	glass.roughness = 0.1
	var low_h := 0.5 if kind == "sports" else 0.6
	_box(Vector3(1.95, low_h, 4.3), Vector3(0, 0.35 + low_h / 2.0, 0), paint)
	_box(Vector3(1.7, 0.45, 2.0), Vector3(0, 0.35 + low_h + 0.22, 0.15), glass)
	# Headlights and tail lights.
	var head := _light_mat(Color(1.0, 0.95, 0.8), 4.0)
	tail_mat = _light_mat(Color(1.0, 0.1, 0.1), 3.0)
	headlights.append(_box(Vector3(0.45, 0.15, 0.08), Vector3(-0.6, 0.62, -2.16), head))
	headlights.append(_box(Vector3(0.45, 0.15, 0.08), Vector3(0.6, 0.62, -2.16), head))
	_box(Vector3(0.45, 0.12, 0.08), Vector3(-0.6, 0.62, 2.16), tail_mat)
	_box(Vector3(0.45, 0.12, 0.08), Vector3(0.6, 0.62, 2.16), tail_mat)
	if kind == "sports":
		# Neon underglow, because of course.
		var glow_col: Color = CityGen.NEON_PALETTE[randi() % CityGen.NEON_PALETTE.size()]
		_box(Vector3(1.6, 0.05, 3.4), Vector3(0, 0.22, 0), _light_mat(glow_col, 3.5))
	# Real headlight beam, enabled only while the player drives this car.
	head_beam = SpotLight3D.new()
	head_beam.position = Vector3(0, 1.1, -1.8)
	head_beam.rotation_degrees = Vector3(-14, 180, 0)
	head_beam.spot_range = 34.0
	head_beam.spot_angle = 38.0
	head_beam.light_energy = 4.0
	head_beam.light_color = Color(1.0, 0.95, 0.85)
	head_beam.visible = false
	add_child(head_beam)
	if kind == "police":
		_box(Vector3(1.6, 0.18, 0.5), Vector3(0, 1.32, 0.1), _light_mat(Color(0.9, 0.9, 1.0), 0.5))
		_box(Vector3(0.6, 0.3, 4.2), Vector3(0, 0.7, 0), _light_mat(Color(1, 1, 1), 0.8))

func _light_mat(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.1, 0.1)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m

func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	add_child(mi)
	return mi

func _build_wheels() -> void:
	var tire := StandardMaterial3D.new()
	tire.albedo_color = Color(0.05, 0.05, 0.05)
	for w in [
		[Vector3(-0.85, 0.4, -1.4), true], [Vector3(0.85, 0.4, -1.4), true],
		[Vector3(-0.85, 0.4, 1.4), false], [Vector3(0.85, 0.4, 1.4), false],
	]:
		var wheel := VehicleWheel3D.new()
		wheel.position = w[0]
		wheel.use_as_steering = w[1]
		wheel.use_as_traction = not w[1]
		wheel.wheel_radius = 0.37
		wheel.wheel_rest_length = 0.18
		wheel.suspension_travel = 0.25
		wheel.suspension_stiffness = 45.0
		wheel.wheel_friction_slip = 3.2
		add_child(wheel)
		wheels.append(wheel)
		var mi := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.37
		mesh.bottom_radius = 0.37
		mesh.height = 0.26
		mesh.material = tire
		mi.mesh = mesh
		mi.rotation.z = PI / 2.0
		wheel.add_child(mi)

func forward_speed() -> float:
	return linear_velocity.dot(-global_transform.basis.z)

func _physics_process(delta: float) -> void:
	enter_cooldown = maxf(enter_cooldown - delta, 0.0)
	if is_player:
		_player_control(delta)
		_stunt_tracking(delta)
	else:
		_ai_control(delta)
	if tail_mat != null:
		tail_mat.emission_energy_multiplier = 6.5 if brake > 4.0 else 3.0
	_update_engine_audio()
	_flip_recovery(delta)

func _stunt_tracking(delta: float) -> void:
	var grounded := false
	for w in wheels:
		if w.is_in_contact():
			grounded = true
			break
	if not grounded and linear_velocity.length() > 6.0:
		air_time += delta
		if air_time > 0.45 and not stunt_slowmo:
			stunt_slowmo = true
			Engine.time_scale = 0.55
	elif grounded:
		if stunt_slowmo:
			Engine.time_scale = 1.0
			stunt_slowmo = false
		if air_time > 0.7 and global_position.y > -0.5:
			var bonus := int(air_time * 130.0)
			Game.add_money(bonus)
			Game.notify.emit("STUNT BONUS! %.1f seconds of air" % air_time)
			Game.sound.play_ui("jingle")
		air_time = 0.0

func _player_control(delta: float) -> void:
	if not Game.playing:
		engine_force = 0.0
		brake = 30.0
		return
	var throttle := Input.get_axis("move_back", "move_forward")
	var steer_in := Input.get_axis("move_right", "move_left")
	var speed := forward_speed()
	engine_force = 0.0
	brake = 0.0
	if throttle > 0.0:
		if linear_velocity.length() < top_speed:
			engine_force = throttle * power
	elif throttle < 0.0:
		if speed > 1.5:
			brake = 45.0
		else:
			engine_force = throttle * power * 0.5
	var handbraking := Input.is_action_pressed("handbrake")
	if handbraking:
		brake = 70.0
	smoke.emitting = handbraking and linear_velocity.length() > 6.0
	var max_steer := lerpf(0.52, 0.16, clampf(absf(speed) / 28.0, 0.0, 1.0))
	steering = lerpf(steering, steer_in * max_steer, 7.0 * delta)
	if Input.is_action_just_pressed("horn"):
		_honk()
	if Input.is_action_just_pressed("horn_cycle"):
		Game.horn_style = (Game.horn_style + 1) % 3
		Game.notify.emit("Horn: " + ["FACTORY", "CLOWN", "AIRHORN"][Game.horn_style])
	if Input.is_action_just_pressed("radio"):
		Game.notify.emit("Radio: " + Game.sound.next_station())
	if Input.is_action_just_pressed("interact") and enter_cooldown <= 0.0 and linear_velocity.length() < 4.0:
		exit()

func _honk() -> void:
	_play_oneshot(["horn", "clown", "airhorn"][Game.horn_style])
	# Honking startles everyone on the sidewalk nearby.
	for ped in get_tree().get_nodes_in_group("peds"):
		if ped.global_position.distance_to(global_position) < 12.0:
			ped.scare(global_position)

func _ai_control(_delta: float) -> void:
	engine_force = 0.0
	brake = 8.0

func steer_towards(target_pos: Vector3, speed_target: float, delta: float) -> void:
	var local := to_local(target_pos)
	var desired := clampf(atan2(-local.x, -local.z), -0.55, 0.55)
	steering = lerpf(steering, desired, 6.0 * delta)
	var speed := forward_speed()
	engine_force = 0.0
	brake = 0.0
	if _obstacle_ahead():
		brake = 35.0
	elif speed < speed_target:
		engine_force = power * 0.75
	elif speed > speed_target + 4.0:
		brake = 10.0

func _obstacle_ahead() -> bool:
	var from := global_position + Vector3(0, 0.7, 0) - global_transform.basis.z * 2.4
	var ahead := 5.0 + forward_speed() * 0.7
	var to := from - global_transform.basis.z * ahead
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.collider is PhysicsBody3D and not hit.collider is StaticBody3D:
		return true
	return false

func _update_engine_audio() -> void:
	var active := is_player or forward_speed() > 0.5
	if active and not engine_audio.playing:
		engine_audio.play()
	elif not active and engine_audio.playing:
		engine_audio.stop()
	if engine_audio.playing:
		engine_audio.pitch_scale = clampf(0.75 + linear_velocity.length() / 26.0, 0.75, 2.2)

func _flip_recovery(delta: float) -> void:
	if global_transform.basis.y.y < 0.15 and linear_velocity.length() < 2.0:
		flip_timer += delta
		if flip_timer > 2.0:
			flip_timer = 0.0
			rotation.x = 0.0
			rotation.z = 0.0
			position.y += 1.2
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
	else:
		flip_timer = 0.0

func _on_impact(body: Node) -> void:
	var impact := linear_velocity.length()
	if body is Player:
		body.hit_by_car(self)
		return
	if impact > 7.0:
		_play_oneshot("crash")
		_spawn_sparks()
	if is_player and impact > 8.0:
		if body.is_in_group("police"):
			Game.add_heat(0.7)
		elif body.is_in_group("cars"):
			Game.add_heat(0.35)

func _spawn_sparks() -> void:
	var sparks := GPUParticles3D.new()
	sparks.amount = 24
	sparks.lifetime = 0.5
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 70.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 10.0
	pm.gravity = Vector3(0, -22, 0)
	sparks.process_material = pm
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.85, 0.4)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.8, 0.3)
	m.emission_energy_multiplier = 4.0
	mesh.material = m
	sparks.draw_pass_1 = mesh
	sparks.position = Vector3(0, 0.6, -1.8 if forward_speed() > 0.0 else 1.8)
	add_child(sparks)
	sparks.emitting = true
	var t := get_tree().create_timer(1.2)
	t.timeout.connect(func() -> void:
		if is_instance_valid(sparks):
			sparks.queue_free())

func _play_oneshot(name_: String) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = Game.sound.stream(name_)
	p.unit_size = 10.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

# ------------------------------------------------------------ enter and exit

func enter(player: Player) -> void:
	if driver != null:
		return
	driver = player
	is_player = true
	enter_cooldown = 0.5
	head_beam.visible = true
	if Game.hud != null:
		Game.hud.set_prompt("")
	player.visible = false
	player.global_position = global_position + Vector3(0, 0.5, 0)
	Game.player_car = self
	Game.camera_rig.set_target(self, true)
	Game.player_state_changed.emit()
	sleeping = false

func exit() -> void:
	if driver == null:
		return
	var player := driver
	driver = null
	is_player = false
	head_beam.visible = false
	engine_force = 0.0
	brake = 12.0
	player.visible = true
	player.teleport(global_position + global_transform.basis.x * -2.0 + Vector3(0, 0.6, 0))
	Game.player_car = null
	Game.camera_rig.set_target(player, false)
	Game.player_state_changed.emit()
