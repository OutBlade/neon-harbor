class_name HUD
extends CanvasLayer
## In-game interface: cash, wanted stars, mission panel, toasts,
## speedometer, interaction prompt and a live minimap.

const CYAN := Color(0.25, 0.92, 1.0)
const GOLD := Color(1.0, 0.85, 0.3)
const RED := Color(1.0, 0.25, 0.25)

var money_label: Label
var stars_label: Label
var cats_label: Label
var fps_label: Label
var mission_title: Label
var mission_obj: Label
var mission_timer: Label
var speed_label: Label
var prompt_label: Label
var big_label: Label
var toast_box: VBoxContainer
var map_container: SubViewportContainer
var map_frame: Panel
var map_camera: Camera3D
var map_vp: SubViewport
var map_tick := 0
var nitro_bg: ColorRect
var nitro_fill: ColorRect

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	money_label = _label(root, 30, GOLD)
	money_label.position = Vector2(20, 14)
	stars_label = _label(root, 34, RED)
	stars_label.position = Vector2(20, 52)
	cats_label = _label(root, 16, GOLD)
	cats_label.position = Vector2(20, 96)

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
	toast_box.position = Vector2(20, 126)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)

	speed_label = _label(root, 30, CYAN)
	speed_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	speed_label.position = Vector2(-200, -60)

	fps_label = _label(root, 16, Color(0.6, 1.0, 0.6))
	fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	fps_label.position = Vector2(-110, 12)

	nitro_bg = ColorRect.new()
	nitro_bg.color = Color(0.05, 0.08, 0.15, 0.8)
	nitro_bg.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	nitro_bg.position = Vector2(-200, -26)
	nitro_bg.size = Vector2(150, 10)
	nitro_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(nitro_bg)
	nitro_fill = ColorRect.new()
	nitro_fill.color = Color(0.3, 0.95, 1.0)
	nitro_fill.position = Vector2(2, 2)
	nitro_fill.size = Vector2(146, 6)
	nitro_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nitro_bg.add_child(nitro_fill)

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
	hint.text = "WASD move    E enter/exit    Shift nitro    Space jump/handbrake    H horn  J style  R radio    P photo    M map    Esc pause"
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-360, -34)

	_build_minimap(root)

	Game.money_changed.connect(func(v: int) -> void: money_label.text = "$ %d" % v)
	Game.heat_changed.connect(_on_heat)
	Game.notify.connect(toast)
	money_label.text = "$ %d" % Game.money
	_on_heat(Game.stars)
	set_mission("", "", -1.0)
	apply_settings()

func apply_settings() -> void:
	fps_label.visible = bool(Game.setting("fps_counter"))
	if not fps_label.visible:
		fps_label.text = ""
	map_container.visible = bool(Game.setting("minimap"))
	map_frame.visible = map_container.visible

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
	# Neon frame behind the map.
	map_frame = Panel.new()
	var frame := map_frame
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0.02, 0.03, 0.1, 0.9)
	fsb.border_color = CYAN
	fsb.set_border_width_all(2)
	fsb.set_corner_radius_all(8)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	frame.position = Vector2(11, -241)
	frame.size = Vector2(230, 230)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	map_container = SubViewportContainer.new()
	map_container.stretch = true
	map_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	map_container.position = Vector2(16, -236)
	map_container.size = Vector2(220, 220)
	map_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_container.self_modulate = Color(1, 1, 1, 0.92)
	root.add_child(map_container)
	var vp := SubViewport.new()
	map_vp = vp
	# Throttled: the map redraws at a quarter of the frame rate.
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
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
	cats_label.text = "CATS %d/5" % Game.cats_petted.size() if Game.cats_petted.size() > 0 else ""
	if fps_label.visible:
		fps_label.text = "%d FPS" % int(Engine.get_frames_per_second())
	if Game.player_car != null:
		speed_label.text = "%d km/h" % int(Game.player_car.linear_velocity.length() * 3.6)
		speed_label.visible = true
		nitro_bg.visible = true
		nitro_fill.size.x = 146.0 * clampf(Game.player_car.nitro, 0.0, 1.0)
		nitro_fill.color = Color(1.0, 0.6, 0.15) if Game.player_car.boosting else Color(0.3, 0.95, 1.0)
	else:
		speed_label.visible = false
		nitro_bg.visible = false
	map_tick += 1
	if map_container.visible and map_tick % 4 == 0:
		map_vp.render_target_update_mode = SubViewport.UPDATE_ONCE

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_minimap"):
		map_container.visible = not map_container.visible
		map_frame.visible = map_container.visible

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
