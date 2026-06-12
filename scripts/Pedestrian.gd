class_name Pedestrian
extends CharacterBody3D
## Night city pedestrian. Walks laps around a block's sidewalk,
## flees from danger, goes down if clipped by a car.
## Randomized look: skin tone, hair, outfit, sometimes a beanie.

const WALK := 1.7
const FLEE := 4.8

const SKIN_TONES: Array[Color] = [
	Color(0.85, 0.65, 0.5), Color(0.7, 0.5, 0.36), Color(0.5, 0.35, 0.25), Color(0.92, 0.74, 0.6),
]
const HAIR_COLORS: Array[Color] = [
	Color(0.08, 0.07, 0.06), Color(0.25, 0.16, 0.08), Color(0.5, 0.45, 0.4),
	Color(0.12, 0.1, 0.1), Color(0.55, 0.2, 0.45),
]

var corners: Array[Vector3] = []
var corner_idx := 0
var flee_timer := 0.0
var flee_dir := Vector3.ZERO
var dance_timer := 0.0
var dead := false
var flying := false
var fly_vel := Vector3.ZERO
var visual: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var walk_phase := 0.0

func _ready() -> void:
	add_to_group("peds")
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.55
	cs.shape = cap
	cs.position = Vector3(0, 0.8, 0)
	add_child(cs)
	visual = Node3D.new()
	add_child(visual)
	var skin: Color = SKIN_TONES[Game.rng.randi_range(0, SKIN_TONES.size() - 1)]
	var shirt := Color.from_hsv(Game.rng.randf(), 0.5, Game.rng.randf_range(0.3, 0.8))
	var pants := Color(0.12, 0.12, 0.16) if Game.rng.randf() < 0.6 else Color(0.16, 0.13, 0.1)
	# Torso and head.
	_part(Vector3(0.45, 0.55, 0.26), Vector3(0, 1.05, 0), shirt)
	_part(Vector3(0.26, 0.26, 0.24), Vector3(0, 1.5, 0), skin)
	# Hair, or a beanie for the fashionable.
	if Game.rng.randf() < 0.25:
		var beanie := Color.from_hsv(Game.rng.randf(), 0.6, 0.5)
		_part(Vector3(0.28, 0.1, 0.26), Vector3(0, 1.66, 0), beanie)
	else:
		var hair: Color = HAIR_COLORS[Game.rng.randi_range(0, HAIR_COLORS.size() - 1)]
		_part(Vector3(0.28, 0.1, 0.26), Vector3(0, 1.65, -0.01), hair)
		_part(Vector3(0.28, 0.14, 0.08), Vector3(0, 1.54, -0.1), hair)
	# Articulated limbs swing while walking.
	arm_l = _limb(Vector3(-0.29, 1.3, 0), Vector3(0.13, 0.45, 0.16), shirt, skin)
	arm_r = _limb(Vector3(0.29, 1.3, 0), Vector3(0.13, 0.45, 0.16), shirt, skin)
	leg_l = _limb(Vector3(-0.11, 0.78, 0), Vector3(0.16, 0.55, 0.18), pants, Color(0.1, 0.1, 0.11))
	leg_r = _limb(Vector3(0.11, 0.78, 0), Vector3(0.16, 0.55, 0.18), pants, Color(0.1, 0.1, 0.11))

func _part(size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	mesh.material = m
	mi.mesh = mesh
	mi.position = pos
	visual.add_child(mi)

func _limb(pivot_pos: Vector3, size: Vector3, color: Color, tip_color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	visual.add_child(pivot)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	mesh.material = m
	mi.mesh = mesh
	mi.position = Vector3(0, -size.y / 2.0 - 0.02, 0)
	pivot.add_child(mi)
	var tip := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(size.x - 0.02, 0.1, size.z + 0.06)
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = tip_color
	tm.material = tmat
	tip.mesh = tm
	tip.position = Vector3(0, -size.y - 0.06, 0.02)
	pivot.add_child(tip)
	return pivot

func assign_block(block_center: Vector3) -> void:
	var r := CityGen.SLAB / 2.0 - 1.4
	corners = [
		block_center + Vector3(-r, 0, -r), block_center + Vector3(r, 0, -r),
		block_center + Vector3(r, 0, r), block_center + Vector3(-r, 0, r),
	]
	corner_idx = Game.rng.randi_range(0, 3)
	position = corners[corner_idx] + Vector3(0, CityGen.CURB_H + 0.1, 0)

func _physics_process(delta: float) -> void:
	if flying:
		# Comedy ragdoll arc: pure kinematics, collisions are off.
		global_position += fly_vel * delta
		fly_vel.y -= 22.0 * delta
		visual.rotation.x += 9.0 * delta
		if global_position.y <= 0.4:
			global_position.y = 0.4
			flying = false
			visual.rotation.x = -PI / 2.0
			visual.position.y = 0.25
		return
	if dead:
		return
	if not is_on_floor():
		velocity.y -= 12.0 * delta
	if dance_timer > 0.0:
		# Airhorn approved. Spin and bounce, arms in the air.
		dance_timer -= delta
		visual.rotation.y += 9.0 * delta
		arm_l.rotation.x = lerpf(arm_l.rotation.x, -2.8, 10.0 * delta)
		arm_r.rotation.x = lerpf(arm_r.rotation.x, -2.8, 10.0 * delta)
		if is_on_floor():
			velocity.y = 2.6
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	var dir := Vector3.ZERO
	if flee_timer > 0.0:
		flee_timer -= delta
		dir = flee_dir
		velocity.x = dir.x * FLEE
		velocity.z = dir.z * FLEE
	else:
		if corners.is_empty():
			return
		var target := corners[corner_idx]
		var to_target := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
		if to_target.length() < 1.0:
			corner_idx = (corner_idx + 1) % 4
		else:
			dir = to_target.normalized()
		velocity.x = dir.x * WALK
		velocity.z = dir.z * WALK
	move_and_slide()
	if dir.length() > 0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-dir.x, -dir.z), 8.0 * delta)
	_animate_limbs(delta)
	# Detect getting hit by a moving vehicle.
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if other is VehicleBody3D and other.linear_velocity.length() > 4.0:
			die(other)

func _animate_limbs(delta: float) -> void:
	var flat_speed := Vector3(velocity.x, 0, velocity.z).length()
	if flat_speed > 0.3:
		walk_phase += flat_speed * delta * 2.8
		var amp := 0.6 * clampf(flat_speed / FLEE, 0.35, 1.0)
		var s := sin(walk_phase)
		arm_l.rotation.x = s * amp
		arm_r.rotation.x = -s * amp
		leg_l.rotation.x = -s * amp
		leg_r.rotation.x = s * amp
	else:
		for limb: Node3D in [arm_l, arm_r, leg_l, leg_r]:
			limb.rotation.x = lerpf(limb.rotation.x, 0.0, 8.0 * delta)

func dance() -> void:
	if dead:
		return
	dance_timer = 3.2
	_exclaim()

func scare(from: Vector3) -> void:
	if dead:
		return
	flee_dir = (global_position - from)
	flee_dir.y = 0.0
	flee_dir = flee_dir.normalized()
	flee_timer = 4.0
	if is_on_floor():
		velocity.y = 3.5
	_exclaim()

func _exclaim() -> void:
	if get_node_or_null("Exclaim") != null:
		return
	var mark := Label3D.new()
	mark.name = "Exclaim"
	mark.text = "!"
	mark.font_size = 140
	mark.pixel_size = 0.01
	mark.modulate = Color(1.0, 0.9, 0.2)
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mark.position = Vector3(0, 2.3, 0)
	add_child(mark)
	var t := get_tree().create_timer(0.9)
	t.timeout.connect(func() -> void:
		if is_instance_valid(mark):
			mark.queue_free())

func die(car: VehicleBody3D) -> void:
	if dead:
		return
	dead = true
	if car.is_player:
		Game.add_heat(1.0)
		Game.notify.emit("Hit and run! The heat is on")
		if car.linear_velocity.length() > 12.0:
			Game.notify.emit("AIRTIME! That one is going to trend")
	# Launch into a spinning ragdoll arc.
	flying = true
	fly_vel = car.linear_velocity * 1.3 + Vector3(randf_range(-2, 2), 7.5, randf_range(-2, 2))
	var p := AudioStreamPlayer3D.new()
	p.stream = Game.sound.stream("clang")
	p.volume_db = -10.0
	p.unit_size = 8.0
	p.bus = "SFX"
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
	# Scatter nearby witnesses.
	for ped in get_tree().get_nodes_in_group("peds"):
		if ped != self and ped.global_position.distance_to(global_position) < 12.0:
			ped.scare(global_position)
	await get_tree().create_timer(6.0).timeout
	if is_instance_valid(self):
		queue_free()
