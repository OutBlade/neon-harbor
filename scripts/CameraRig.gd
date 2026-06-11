class_name CameraRig
extends Node3D
## Orbiting third-person camera with wall avoidance.
## Follows the player on foot or the current car, auto-aligns while driving.

var yaw := 0.0
var pitch := -0.28
var target: Node3D = null
var drive_mode := false
var manual_timer := 0.0
var cine_t := 0.0
var camera: Camera3D
var rain: GPUParticles3D
var motes: GPUParticles3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.far = 800.0
	camera.cull_mask = 1
	add_child(camera)
	camera.current = true
	top_level = true
	_build_rain()

func _build_rain() -> void:
	# Rain follows the camera position but falls in world space.
	rain = GPUParticles3D.new()
	rain.add_to_group("rain")
	rain.amount = 650
	rain.lifetime = 0.9
	rain.emitting = Game.fancy_graphics
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(26, 1, 26)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 2.0
	pm.initial_velocity_min = 24.0
	pm.initial_velocity_max = 30.0
	pm.gravity = Vector3(0, -12, 0)
	rain.process_material = pm
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.015, 0.55, 0.015)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.6, 0.7, 0.9, 0.32)
	mesh.material = m
	rain.draw_pass_1 = mesh
	rain.visibility_aabb = AABB(Vector3(-40, -25, -40), Vector3(80, 50, 80))
	rain.top_level = true
	add_child(rain)
	# Slow glowing motes drifting in the night air.
	motes = GPUParticles3D.new()
	motes.amount = 90
	motes.lifetime = 7.0
	var mpm := ParticleProcessMaterial.new()
	mpm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mpm.emission_box_extents = Vector3(18, 7, 18)
	mpm.direction = Vector3(0, 1, 0)
	mpm.spread = 180.0
	mpm.initial_velocity_min = 0.1
	mpm.initial_velocity_max = 0.5
	mpm.gravity = Vector3(0, 0.12, 0)
	motes.process_material = mpm
	var mq := QuadMesh.new()
	mq.size = Vector2(0.05, 0.05)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mm.albedo_color = Color(1.0, 0.85, 0.6, 0.5)
	mm.emission_enabled = true
	mm.emission = Color(1.0, 0.8, 0.5)
	mm.emission_energy_multiplier = 1.3
	mq.material = mm
	motes.draw_pass_1 = mq
	motes.visibility_aabb = AABB(Vector3(-30, -15, -30), Vector3(60, 30, 60))
	motes.top_level = true
	add_child(motes)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s := 0.0028 * float(Game.setting("sensitivity"))
		var dy: float = event.relative.y * (-1.0 if bool(Game.setting("invert_y")) else 1.0)
		yaw -= event.relative.x * s
		pitch = clampf(pitch - dy * s, -1.1, 0.45)
		manual_timer = 1.6

func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if rain != null:
		rain.global_position = global_position + Vector3(0, 14, 0)
	if motes != null:
		motes.global_position = global_position
	manual_timer = maxf(manual_timer - delta, 0.0)
	if cine_t > 0.0:
		# Slow dramatic orbit for WASTED and BUSTED moments.
		cine_t -= delta
		yaw += delta * 1.4
		pitch = lerpf(pitch, -0.45, 3.0 * delta)
	elif drive_mode and manual_timer <= 0.0:
		# Settle in behind the car's heading (nose is local +Z).
		var car_yaw: float = target.global_transform.basis.get_euler().y
		yaw = lerp_angle(yaw, car_yaw + PI, 2.2 * delta)
		pitch = lerpf(pitch, -0.22, 2.0 * delta)
	if drive_mode and target is RigidBody3D:
		var spd: float = target.linear_velocity.length()
		camera.fov = lerpf(camera.fov, 72.0 + 16.0 * clampf(spd / 34.0, 0.0, 1.0), 4.0 * delta)
	else:
		camera.fov = lerpf(camera.fov, 72.0, 4.0 * delta)
	var pivot: Vector3 = target.global_position + Vector3(0, 2.6 if drive_mode else 1.6, 0)
	var dist := 8.2 if drive_mode else 4.3
	var offset := Basis(Vector3.UP, yaw) * (Basis(Vector3.RIGHT, pitch) * Vector3(0, 0, dist))
	var desired := pivot + offset
	var query := PhysicsRayQueryParameters3D.create(pivot, desired)
	if target is CollisionObject3D:
		query.exclude = [target.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		desired = hit.position + (pivot - desired).normalized() * 0.35
	global_position = global_position.lerp(desired, minf(14.0 * delta, 1.0))
	look_at(pivot, Vector3.UP)

func set_target(node: Node3D, driving: bool) -> void:
	target = node
	drive_mode = driving
	if node != null:
		global_position = node.global_position + Vector3(0, 3, 6)
