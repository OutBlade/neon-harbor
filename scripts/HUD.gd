class_name HUD
extends CanvasLayer
## In-game interface: cash, wanted stars, mission panel, toasts,
## speedometer, interaction prompt and a live minimap.

const CYAN := Color(0.25, 0.92, 1.0)
const GOLD := Color(1.0, 0.85, 0.3)
const RED := Color(1.0, 0.25, 0.25)

var money_label: Label
var stars_label: Label
var mission_title: Label
var mission_obj: Label
var mission_timer: Label
var speed_label: Label
var prompt_label: Label
var big_label: Label
var toast_box: VBoxContainer
var map_container: SubViewportContainer
var map_camera: Camera3D

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	money_label = _label(root, 30, GOLD)
	money_label.position = Vector2(20, 14)
	stars_label = _label(root, 34, RED)
	stars_label.position = Vector2(20, 52)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.08, 0.65)
	sb.border_color = CYAN
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	mission_title = _label(vb, 22, GOLD)
	mission_obj = _label(vb, 17, Color.WHITE)
	mission_timer = _label(vb, 20, CYAN)
	panel.position = Vector2(0, 10)
	panel.reset_size()

	toast_box = VBoxContainer.new()
	toast_box.position = Vector2(20, 110)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)

	speed_label = _label(root, 30, CYAN)
	speed_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	speed_label.position = Vector2(-200, -60)

	prompt_label = _label(root, 22, Color.WHITE)
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-150, -140)

	big_label = _label(root, 64, GOLD)
	big_label.set_anchors_preset(Control.PRESET_CENTER)
	big_label.position = Vector2(-300, -60)
	big_label.size = Vector2(600, 120)
	big_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_label.modulate.a = 0.0

	var hint := _label(root, 13, Color(1, 1, 1, 0.45))
	hint.text = "WASD move and drive    E enter or exit    Space jump or handbrake    Shift sprint    H horn    M map    Esc pause"
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-360, -34)

	_build_minimap(root)

	Game.money_changed.connect(func(v: int) -> void: money_label.text = "$ %d" % v)
	Game.heat_changed.connect(_on_heat)
	Game.notify.connect(toast)
	money_label.text = "$ %d" % Game.money
	_on_heat(Game.stars)
	set_mission("", "", -1.0)

func _label(parent: Node, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _build_minimap(root: Control) -> void:
	map_container = SubViewportContainer.new()
	map_container.stretch = true
	map_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	map_container.position = Vector2(16, -236)
	map_container.size = Vector2(220, 220)
	map_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_container.self_modulate = Color(1, 1, 1, 0.92)
	root.add_child(map_container)
	var vp := SubViewport.new()
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	map_container.add_child(vp)
	map_camera = Camera3D.new()
	map_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	map_camera.size = 230.0
	map_camera.cull_mask = 3
	map_camera.rotation_degrees = Vector3(-90, 0, 0)
	map_camera.far = 400.0
	vp.add_child(map_camera)

func _process(_delta: float) -> void:
	if map_camera != null:
		var p := Game.player_position()
		map_camera.global_position = Vector3(p.x, 180.0, p.z)
	if Game.player_car != null:
		speed_label.text = "%d km/h" % int(Game.player_car.linear_velocity.length() * 3.6)
		speed_label.visible = true
	else:
		speed_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_minimap"):
		map_container.visible = not map_container.visible

func _on_heat(stars: int) -> void:
	stars_label.text = "WANTED " + "*".repeat(stars) if stars > 0 else ""

func set_mission(title: String, objective: String, t: float) -> void:
	mission_title.text = title
	mission_obj.text = objective
	mission_title.visible = title != ""
	mission_obj.visible = objective != ""
	update_mission_timer(t)

func update_mission_timer(t: float) -> void:
	mission_timer.visible = t > 0.0
	if t > 0.0:
		mission_timer.text = "%d:%02d" % [int(t) / 60, int(t) % 60]

func set_prompt(text: String) -> void:
	prompt_label.text = text

func show_big(text: String, color: Color) -> void:
	big_label.text = text
	big_label.add_theme_color_override("font_color", color)
	big_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(big_label, "modulate:a", 0.0, 1.2)

func toast(text: String) -> void:
	var l := _label(toast_box, 17, Color(1, 1, 1, 0.95))
	l.text = text
	if toast_box.get_child_count() > 5:
		toast_box.get_child(0).queue_free()
	var tw := create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)
