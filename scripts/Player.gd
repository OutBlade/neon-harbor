class_name Player
extends CharacterBody3D
## Third-person on-foot character. Built entirely from primitives,
## with articulated arms and legs that swing as you move.

signal wasted(reason: String)

const WALK := 4.6
const SPRINT := 7.6
const JUMP := 5.2
const GRAVITY := 14.0

var body_visual: Node3D
var nearest_car: VehicleBody3D = null
var nearest_cat: Node3D = null
var nearest_shop: Node3D = null
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var walk_phase := 0.0

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
	var jacket_col := Color(0.15, 0.12, 0.25)
	var skin := Color(0.85, 0.65, 0.5)
	var jacket := _part(Vector3(0.55, 0.62, 0.3), Vector3(0, 1.12, 0), jacket_col)
	jacket.name = "Jacket"
	# Collar and the glowing chest stripe.
	_part(Vector3(0.42, 0.08, 0.26), Vector3(0, 1.46, 0), Color(0.10, 0.08, 0.18))
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
	# Head: skin, swept hair, a faint cyan visor.
	_part(Vector3(0.3, 0.3, 0.28), Vector3(0, 1.62, 0), skin)
	_part(Vector3(0.32, 0.13, 0.3), Vector3(0, 1.78, -0.02), Color(0.08, 0.07, 0.1))
	_part(Vector3(0.32, 0.16, 0.1), Vector3(0, 1.66, -0.12), Color(0.08, 0.07, 0.1))
	var visor := MeshInstance3D.new()
	var vm := BoxMesh.new()
	vm.size = Vector3(0.26, 0.05, 0.02)
	var visor_mat := StandardMaterial3D.new()
	visor_mat.albedo_color = Color(0.05, 0.05, 0.08)
	visor_mat.emission_enabled = true
	visor_mat.emission = Color(0.14, 0.9, 1.0)
	visor_mat.emission_energy_multiplier = 1.2
	vm.material = visor_mat
	visor.mesh = vm
	visor.position = Vector3(0, 1.64, 0.15)
	body_visual.add_child(visor)
	# Articulated limbs: pivot at the joint, mesh hangs below it.
	arm_l = _limb(Vector3(-0.36, 1.4, 0), Vector3(0.16, 0.5, 0.2), jacket_col, skin, 0.13)
	arm_r = _limb(Vector3(0.36, 1.4, 0), Vector3(0.16, 0.5, 0.2), jacket_col, skin, 0.13)
	leg_l = _limb(Vector3(-0.16, 0.85, 0), Vector3(0.2, 0.6, 0.22), Color(0.1, 0.1, 0.14), Color.BLACK, 0.0)
	leg_r = _limb(Vector3(0.16, 0.85, 0), Vector3(0.2, 0.6, 0.22), Color(0.1, 0.1, 0.14), Color.BLACK, 0.0)
	for leg: Node3D in [leg_l, leg_r]:
		var shoe := MeshInstance3D.new()
		var shm := BoxMesh.new()
		shm.size = Vector3(0.21, 0.1, 0.3)
		var shoe_mat := StandardMaterial3D.new()
		shoe_mat.albedo_color = Color(0.85, 0.85, 0.88)
		shm.material = shoe_mat
		shoe.mesh = shm
		shoe.position = Vector3(0, -0.66, 0.04)
		leg.add_child(shoe)

func _limb(pivot_pos: Vector3, size: Vector3, color: Color, tip_color: Color, tip: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	body_visual.add_child(pivot)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	mesh.material = m
	mi.mesh = mesh
	mi.position = Vector3(0, -size.y / 2.0 - 0.02, 0)
	pivot.add_child(mi)
	if tip > 0.0:
		# Hand poking out of the sleeve.
		var hand := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(tip, tip, tip)
		var hmat := StandardMaterial3D.new()
		hmat.albedo_color = tip_color
		hm.material = hmat
		hand.mesh = hm
		hand.position = Vector3(0, -size.y - 0.06, 0)
		pivot.add_child(hand)
	return pivot

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
	_animate_limbs(flat.length(), delta)
	_update_car_prompt()
	if Input.is_action_just_pressed("interact"):
		if nearest_cat != null:
			nearest_cat.pet()
		elif nearest_shop != null:
			nearest_shop.try_buy()
		elif nearest_car != null:
			nearest_car.enter(self)

func _animate_limbs(flat_speed: float, delta: float) -> void:
	# Procedural gait: limbs swing with stride, settle when idle,
	# arms trail back during a jump.
	if not is_on_floor():
		arm_l.rotation.x = lerpf(arm_l.rotation.x, -0.9, 8.0 * delta)
		arm_r.rotation.x = lerpf(arm_r.rotation.x, -0.9, 8.0 * delta)
		leg_l.rotation.x = lerpf(leg_l.rotation.x, 0.5, 8.0 * delta)
		leg_r.rotation.x = lerpf(leg_r.rotation.x, -0.3, 8.0 * delta)
		return
	if flat_speed > 0.5:
		walk_phase += flat_speed * delta * 2.4
		var amp := 0.75 * clampf(flat_speed / SPRINT, 0.3, 1.0)
		var s := sin(walk_phase)
		arm_l.rotation.x = s * amp
		arm_r.rotation.x = -s * amp
		leg_l.rotation.x = -s * amp * 0.9
		leg_r.rotation.x = s * amp * 0.9
	else:
		for limb: Node3D in [arm_l, arm_r, leg_l, leg_r]:
			limb.rotation.x = lerpf(limb.rotation.x, 0.0, 10.0 * delta)

func _update_car_prompt() -> void:
	nearest_car = null
	nearest_cat = null
	var best := 4.0
	for car in get_tree().get_nodes_in_group("cars"):
		var d: float = car.global_position.distance_to(global_position)
		if d < best:
			best = d
			nearest_car = car
	var best_cat := 2.6
	for cat in get_tree().get_nodes_in_group("cats"):
		var d: float = cat.global_position.distance_to(global_position)
		if d < best_cat:
			best_cat = d
			nearest_cat = cat
	nearest_shop = null
	var best_shop := 3.2
	for shop in get_tree().get_nodes_in_group("shops"):
		var d: float = shop.global_position.distance_to(global_position)
		if d < best_shop and shop.prompt_text() != "":
			best_shop = d
			nearest_shop = shop
	if Game.hud != null:
		if nearest_cat != null:
			Game.hud.set_prompt("Press E to pet the cat")
		elif nearest_shop != null:
			Game.hud.set_prompt(nearest_shop.prompt_text())
		else:
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
