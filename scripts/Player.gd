class_name Player
extends CharacterBody3D
## Third-person on-foot character. Built entirely from primitives.

signal wasted(reason: String)

const WALK := 4.6
const SPRINT := 7.6
const JUMP := 5.2
const GRAVITY := 14.0

var body_visual: Node3D
var nearest_car: VehicleBody3D = null

func _ready() -> void:
	add_to_group("player")
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	add_child(cs)
	_build_visual()
	CityGen.add_blip(self, Color(0.2, 1.0, 1.0), 3.4)

func _build_visual() -> void:
	body_visual = Node3D.new()
	add_child(body_visual)
	var jacket := _part(Vector3(0.55, 0.62, 0.3), Vector3(0, 1.12, 0), Color(0.15, 0.12, 0.25))
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.1, 0.1, 0.1)
	glow.emission_enabled = true
	glow.emission = Color(0.14, 0.9, 1.0)
	glow.emission_energy_multiplier = 2.5
	var stripe := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.57, 0.08, 0.32)
	sm.material = glow
	stripe.mesh = sm
	stripe.position = Vector3(0, 1.3, 0)
	body_visual.add_child(stripe)
	jacket.name = "Jacket"
	_part(Vector3(0.3, 0.3, 0.28), Vector3(0, 1.62, 0), Color(0.85, 0.65, 0.5))   # head
	_part(Vector3(0.2, 0.55, 0.22), Vector3(-0.16, 0.42, 0), Color(0.1, 0.1, 0.14)) # legs
	_part(Vector3(0.2, 0.55, 0.22), Vector3(0.16, 0.42, 0), Color(0.1, 0.1, 0.14))

func _part(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	mesh.material = m
	mi.mesh = mesh
	mi.position = pos
	body_visual.add_child(mi)
	return mi

func _physics_process(delta: float) -> void:
	if Game.player_car != null or not Game.playing:
		return
	if global_position.y < -1.4:
		wasted.emit("SOAKED")
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw: float = Game.camera_rig.yaw if Game.camera_rig != null else 0.0
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(-fwd.z, 0, fwd.x)
	var dir := (right * input.x + fwd * -input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	var speed := SPRINT if Input.is_action_pressed("sprint") else WALK
	velocity.x = move_toward(velocity.x, dir.x * speed, 30.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 30.0 * delta)
	move_and_slide()
	# Face the direction of travel, lean slightly while running.
	var flat := Vector3(velocity.x, 0, velocity.z)
	if flat.length() > 0.5:
		body_visual.rotation.y = lerp_angle(body_visual.rotation.y, atan2(-flat.x, -flat.z), 10.0 * delta)
		body_visual.rotation.x = lerpf(body_visual.rotation.x, -0.08 * flat.length() / SPRINT, 6.0 * delta)
	else:
		body_visual.rotation.x = lerpf(body_visual.rotation.x, 0.0, 6.0 * delta)
	_update_car_prompt()
	if Input.is_action_just_pressed("interact") and nearest_car != null:
		nearest_car.enter(self)

func _update_car_prompt() -> void:
	nearest_car = null
	var best := 4.0
	for car in get_tree().get_nodes_in_group("cars"):
		var d: float = car.global_position.distance_to(global_position)
		if d < best:
			best = d
			nearest_car = car
	if Game.hud != null:
		Game.hud.set_prompt("Press E to enter the car" if nearest_car != null else "")

func hit_by_car(car: VehicleBody3D) -> void:
	if Game.player_car == car:
		return
	var impact := car.linear_velocity.length()
	if impact > 9.0:
		wasted.emit("WASTED")
	elif impact > 2.0:
		velocity += car.linear_velocity * 1.1 + Vector3(0, 3.0, 0)

func teleport(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
