extends Node
## Autoload singleton: global state, wanted heat, input map, save data.

signal money_changed(value: int)
signal heat_changed(stars: int)
signal notify(text: String)
signal player_state_changed

const SAVE_PATH := "user://neon_harbor_save.json"
const MAX_HEAT := 5.0

var money: int = 0:
	set(v):
		money = maxi(v, 0)
		money_changed.emit(money)

var heat: float = 0.0
var stars: int = 0
var missions_done: Array = []
var total_busts: int = 0
var total_wrecks: int = 0

var player: CharacterBody3D = null
var player_car: VehicleBody3D = null
var camera_rig: Node3D = null
var world: Node3D = null
var hud: CanvasLayer = null
var sound: Node = null
var playing: bool = false

var rng := RandomNumberGenerator.new()

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	_register_inputs()

func _ready() -> void:
	sound = preload("res://scripts/SoundBank.gd").new()
	sound.name = "SoundBank"
	add_child(sound)
	load_game()

func _process(delta: float) -> void:
	if not playing:
		return
	# Heat decays when no police car is close to the player.
	if heat > 0.0 and not _police_nearby():
		set_heat(heat - delta * 0.12)

func _police_nearby() -> bool:
	var target := player_position()
	for cop in get_tree().get_nodes_in_group("police"):
		if cop.global_position.distance_to(target) < 45.0:
			return true
	return false

func player_position() -> Vector3:
	if player_car != null:
		return player_car.global_position
	if player != null:
		return player.global_position
	return Vector3.ZERO

func player_speed() -> float:
	if player_car != null:
		return player_car.linear_velocity.length()
	if player != null:
		return player.velocity.length()
	return 0.0

func add_heat(amount: float) -> void:
	set_heat(heat + amount)

func set_heat(value: float) -> void:
	heat = clampf(value, 0.0, MAX_HEAT)
	var s := int(floor(heat))
	if s != stars:
		stars = s
		heat_changed.emit(stars)

func add_money(amount: int) -> void:
	money += amount
	if amount > 0:
		notify.emit("+$%d" % amount)

func mission_completed(id: String) -> void:
	if not missions_done.has(id):
		missions_done.append(id)
	save_game()

func reset_session() -> void:
	heat = 0.0
	stars = 0
	player = null
	player_car = null
	world = null
	hud = null
	playing = false

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"money": money,
		"missions_done": missions_done,
		"total_busts": total_busts,
		"total_wrecks": total_wrecks,
	}))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	money = int(data.get("money", 0))
	missions_done = data.get("missions_done", [])
	total_busts = int(data.get("total_busts", 0))
	total_wrecks = int(data.get("total_wrecks", 0))

func wipe_save() -> void:
	money = 0
	missions_done = []
	total_busts = 0
	total_wrecks = 0
	save_game()

# ---------------------------------------------------------------- input map

func _register_inputs() -> void:
	_key("move_forward", KEY_W);  _axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_key("move_back", KEY_S);     _axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_key("move_left", KEY_A);     _axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_key("move_right", KEY_D);    _axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_key("move_forward", KEY_UP)
	_key("move_back", KEY_DOWN)
	_key("move_left", KEY_LEFT)
	_key("move_right", KEY_RIGHT)
	_key("jump", KEY_SPACE);      _btn("jump", JOY_BUTTON_A)
	_key("sprint", KEY_SHIFT);    _btn("sprint", JOY_BUTTON_LEFT_SHOULDER)
	_key("interact", KEY_E);      _btn("interact", JOY_BUTTON_X)
	_key("handbrake", KEY_SPACE); _btn("handbrake", JOY_BUTTON_B)
	_key("horn", KEY_H);          _btn("horn", JOY_BUTTON_Y)
	_key("pause", KEY_ESCAPE);    _btn("pause", JOY_BUTTON_START)
	_key("toggle_minimap", KEY_M)

func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

func _key(action: String, key: Key) -> void:
	_ensure(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)

func _btn(action: String, button: JoyButton) -> void:
	_ensure(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)

func _axis(action: String, axis: JoyAxis, value: float) -> void:
	_ensure(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)
