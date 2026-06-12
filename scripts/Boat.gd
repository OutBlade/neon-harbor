class_name Boat
extends Car
## Harbor speedboat. Custom buoyancy physics, no wheels, neon trim.
## The nose is local +Z like every other vehicle.

const FLOAT_Y := -0.45

var bob_t := 0.0

func _ready() -> void:
	super()
	mass = 900.0
	linear_damp = 0.7
	angular_damp = 2.4
	can_sleep = false

func _build_body() -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 1.1, 6.0)
	cs.shape = shape
	cs.position = Vector3(0, 0.6, 0)
	add_child(cs)
	var hull := StandardMaterial3D.new()
	hull.albedo_color = Color(0.9, 0.9, 0.94)
	hull.metallic = 0.3
	hull.roughness = 0.35
	paint_mat = hull
	tail_mat = _light_mat(Color(1.0, 0.1, 0.1), 2.0)
	_box(Vector3(2.4, 0.7, 5.6), Vector3(0, 0.55, -0.2), hull)
	# Bow wedge.
	var bow := _box(Vector3(2.0, 0.5, 1.6), Vector3(0, 0.62, 2.8), hull)
	bow.rotation.x = 0.22
	# Deck, windscreen and seats.
	_box(Vector3(2.1, 0.1, 3.0), Vector3(0, 0.95, -0.6), _light_mat(Color(0.5, 0.35, 0.2), 0.3))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.4, 0.6, 0.7, 0.4)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var screen := _box(Vector3(1.8, 0.5, 0.06), Vector3(0, 1.25, 1.1), glass)
	screen.rotation.x = -0.35
	_box(Vector3(0.7, 0.4, 0.7), Vector3(-0.5, 1.1, 0.0), _light_mat(Color(0.2, 0.2, 0.25), 0.2))
	_box(Vector3(0.7, 0.4, 0.7), Vector3(0.5, 1.1, 0.0), _light_mat(Color(0.2, 0.2, 0.25), 0.2))
	# Neon waterline trim and stern light.
	var trim_col: Color = CityGen.NEON_PALETTE[randi() % CityGen.NEON_PALETTE.size()]
	_box(Vector3(2.46, 0.08, 5.6), Vector3(0, 0.35, -0.2), _light_mat(trim_col, 3.0))
	_box(Vector3(0.4, 0.12, 0.08), Vector3(0, 1.0, -3.0), tail_mat)
	head_beam = SpotLight3D.new()
	head_beam.position = Vector3(0, 1.2, 2.6)
	head_beam.rotation_degrees = Vector3(-10, 180, 0)
	head_beam.spot_range = 42.0
	head_beam.spot_angle = 38.0
	head_beam.light_energy = 5.0
	head_beam.visible = false
	add_child(head_beam)

func _build_wheels() -> void:
	pass  # boats: famously zero wheels

func _physics_process(delta: float) -> void:
	enter_cooldown = maxf(enter_cooldown - delta, 0.0)
	bob_t += delta
	# Spring buoyancy toward the waterline with a gentle bob.
	var target_y := FLOAT_Y + sin(bob_t * 1.3 + position.x * 0.1) * 0.05
	var lift := (target_y - global_position.y) * mass * 16.0 - linear_velocity.y * mass * 3.5
	apply_central_force(Vector3(0, lift, 0))
	# Keep the deck level.
	apply_torque(global_transform.basis.y.cross(Vector3.UP) * mass * 8.0)
	if is_player:
		var throttle := Input.get_axis("move_back", "move_forward")
		var steer := Input.get_axis("move_right", "move_left")
		if linear_velocity.length() < 24.0:
			var thrust := global_transform.basis.z * throttle * mass * 14.0
			apply_central_force(Vector3(thrust.x, 0, thrust.z))
		apply_torque(Vector3.UP * steer * mass * 5.0 * clampf(forward_speed() / 6.0, -1.0, 1.0))
		if Input.is_action_just_pressed("radio"):
			Game.notify.emit("Radio: " + Game.sound.next_station())
		if Input.is_action_just_pressed("horn"):
			_play_oneshot(["horn", "clown", "airhorn"][Game.horn_style])
		if Input.is_action_just_pressed("interact") and enter_cooldown <= 0.0:
			exit()
	_update_engine_audio()

func exit() -> void:
	if driver == null:
		return
	# Only step off near the promenade, otherwise that is just swimming.
	var dock_z := CityGen.N * CityGen.PITCH / 2.0 + 2.5
	if global_position.z > dock_z + 9.0:
		Game.notify.emit("Too far from the dock to get out")
		return
	var player := driver
	driver = null
	is_player = false
	head_beam.visible = false
	player.visible = true
	player.teleport(Vector3(clampf(global_position.x, -230.0, 230.0), 0.6, dock_z - 2.0))
	Game.player_car = null
	Game.camera_rig.set_target(player, false)
	Game.player_state_changed.emit()
