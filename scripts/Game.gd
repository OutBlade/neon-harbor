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
var cats_petted: Array = []
var horn_style: int = 0

const DEFAULT_SETTINGS := {
	"fancy": true,
	"fullscreen": false,
	"vsync": true,
	"rain": true,
	"glow": true,
	"fps_counter": false,
	"master_vol": 1.0,
	"music_vol": 0.8,
	"sfx_vol": 1.0,
	"sensitivity": 1.0,
	"invert_y": false,
	"traffic": 1,
	"peds": 1,
	"minimap": true,
	"auto_update": true,
}
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()

var fancy_graphics: bool:
	get:
		return settings["fancy"]
	set(v):
		settings["fancy"] = v

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
	_setup_audio_buses()

func _ready() -> void:
	sound = preload("res://scripts/SoundBank.gd").new()
	sound.name = "SoundBank"
	add_child(sound)
	load_game()
	apply_settings.call_deferred()

func _setup_audio_buses() -> void:
	AudioServer.add_bus()
	AudioServer.set_bus_name(1, "Music")
	AudioServer.add_bus()
	AudioServer.set_bus_name(2, "SFX")

func setting(key: String) -> Variant:
	return settings.get(key, DEFAULT_SETTINGS.get(key))

func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(settings["master_vol"]), 0.0001)))
	AudioServer.set_bus_volume_db(1, linear_to_db(maxf(float(settings["music_vol"]), 0.0001)))
	AudioServer.set_bus_volume_db(2, linear_to_db(maxf(float(settings["sfx_vol"]), 0.0001)))
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if settings["vsync"] else DisplayServer.VSYNC_DISABLED)
	var is_fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if bool(settings["fullscreen"]) != is_fs:
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED)
	for city in get_tree().get_nodes_in_group("city"):
		city.apply_quality(bool(settings["fancy"]))
		city.environment.glow_enabled = bool(settings["glow"])
	for rain in get_tree().get_nodes_in_group("rain"):
		rain.emitting = bool(settings["fancy"]) and bool(settings["rain"])
	if hud != null:
		hud.apply_settings()
	save_game()

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

func pet_cat(index: int) -> void:
	if cats_petted.has(index):
		notify.emit("This cat has already been petted. It remembers")
		return
	cats_petted.append(index)
	sound.play_ui("meow")
	add_money(100)
	notify.emit("Cat petted. %d of 5 found" % cats_petted.size())
	if cats_petted.size() >= 5:
		notify.emit("All cats petted. You are unstoppable now")
		add_money(500)
	save_game()

func slowmo(scale: float, duration: float) -> void:
	Engine.time_scale = scale
	var t := get_tree().create_timer(duration, true, false, true)
	t.timeout.connect(func() -> void: Engine.time_scale = 1.0)

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
		"cats_petted": cats_petted,
		"settings": settings,
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
	cats_petted = data.get("cats_petted", [])
	var saved: Variant = data.get("settings", {})
	if typeof(saved) == TYPE_DICTIONARY:
		for k in DEFAULT_SETTINGS:
			settings[k] = saved.get(k, DEFAULT_SETTINGS[k])
	elif data.has("fancy_graphics"):
		settings["fancy"] = bool(data.get("fancy_graphics", true))

func wipe_save() -> void:
	money = 0
	missions_done = []
	total_busts = 0
	total_wrecks = 0
	cats_petted = []
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
	_key("radio", KEY_R);         _btn("radio", JOY_BUTTON_DPAD_RIGHT)
	_key("horn_cycle", KEY_J)

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
