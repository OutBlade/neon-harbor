class_name CameraRig
extends Node3D
## Orbiting third-person camera with wall avoidance.
## Follows the player on foot or the current car, auto-aligns while driving.

var yaw := 0.0
var pitch := -0.28
var target: Node3D = null
var drive_mode := false
var manual_timer := 0.0
var camera: Camera3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.far = 800.0
	camera.cull_mask = 1
	add_child(camera)
	camera.current = true
	top_level = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0028
		pitch = clampf(pitch - event.relative.y * 0.0028, -1.1, 0.45)
		manual_timer = 1.6

func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	manual_timer = maxf(manual_timer - delta, 0.0)
	if drive_mode and manual_timer <= 0.0:
		# Settle in behind the car's heading.
		var car_yaw: float = target.global_transform.basis.get_euler().y
		yaw = lerp_angle(yaw, car_yaw, 2.2 * delta)
		pitch = lerpf(pitch, -0.22, 2.0 * delta)
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
