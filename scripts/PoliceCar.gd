class_name PoliceCar
extends Car
## Pursuit unit. Chases the player while there is heat, tries to box them in,
## busts the player when they are cornered and slow.

var bust_timer := 0.0
var flash_timer := 0.0
var flash_state := false
var leaving := false
var siren: AudioStreamPlayer3D
var bar_red: MeshInstance3D
var bar_blue: MeshInstance3D
var flash_light: OmniLight3D

func _init() -> void:
	setup("police", Color(0.08, 0.08, 0.1))

func _ready() -> void:
	super()
	add_to_group("police")
	var bar_y := 2.05 if kind == "swat" else 1.42
	bar_red = _box(Vector3(0.5, 0.16, 0.4), Vector3(-0.45, bar_y, 0.1), _light_mat(Color(1, 0.05, 0.05), 5.0))
	bar_blue = _box(Vector3(0.5, 0.16, 0.4), Vector3(0.45, bar_y, 0.1), _light_mat(Color(0.1, 0.2, 1), 5.0))
	flash_light = OmniLight3D.new()
	flash_light.position = Vector3(0, 1.8, 0)
	flash_light.omni_range = 10.0
	flash_light.light_energy = 2.0
	add_child(flash_light)
	siren = AudioStreamPlayer3D.new()
	siren.stream = Game.sound.stream("siren")
	siren.unit_size = 14.0
	siren.bus = "SFX"
	add_child(siren)
	siren.play()
	CityGen.add_blip(self, Color(1.0, 0.15, 0.15), 3.0)

func _physics_process(delta: float) -> void:
	super(delta)
	flash_timer += delta
	if flash_timer > 0.35:
		flash_timer = 0.0
		flash_state = not flash_state
		bar_red.visible = flash_state
		bar_blue.visible = not flash_state
		flash_light.light_color = Color(1, 0.1, 0.1) if flash_state else Color(0.15, 0.25, 1)

func _ai_control(delta: float) -> void:
	if driver != null:
		return
	if Game.stars <= 0 and not leaving:
		leaving = true
		siren.stop()
	if leaving:
		# Drive off and despawn once out of sight.
		engine_force = power * 0.4
		steering = lerpf(steering, 0.1, 2.0 * delta)
		if global_position.distance_to(Game.player_position()) > 130.0:
			queue_free()
		return
	var target := Game.player_position()
	var dist := global_position.distance_to(target)
	steer_towards(target, 19.0 if dist > 25.0 else 13.0, delta)
	# Never brake for the player; ramming is the job.
	if _obstacle_ahead() and dist < 14.0:
		brake = 0.0
		engine_force = power * 0.75
	if dist < 6.0 and Game.player_speed() < 2.0:
		bust_timer += delta
		if bust_timer > 1.3:
			bust_timer = 0.0
			get_tree().call_group("main", "on_player_busted")
	else:
		bust_timer = maxf(bust_timer - delta, 0.0)
