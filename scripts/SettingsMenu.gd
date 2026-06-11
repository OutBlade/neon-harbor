class_name SettingsMenu
extends CanvasLayer
## In-game settings panel, reachable from the main menu and the pause menu.
## Every change applies instantly and is written to the save file.

var rows: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	visible = false
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.01, 0.01, 0.06, 0.94)
	sb.border_color = Color(0.25, 0.92, 1.0)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 30.0
	sb.content_margin_right = 30.0
	sb.content_margin_top = 18.0
	sb.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-240, -300)
	root.add_child(panel)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	rows.custom_minimum_size = Vector2(480, 0)
	panel.add_child(rows)
	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.25, 0.92, 1.0))
	rows.add_child(title)
	_cycle("GRAPHICS", "fancy", ["FAST", "FANCY"], [false, true])
	_cycle("FULLSCREEN", "fullscreen", ["OFF", "ON"], [false, true])
	_cycle("VSYNC", "vsync", ["OFF", "ON"], [false, true])
	_cycle("RAIN", "rain", ["OFF", "ON"], [false, true])
	_cycle("GLOW", "glow", ["OFF", "ON"], [false, true])
	_cycle("FPS COUNTER", "fps_counter", ["OFF", "ON"], [false, true])
	_slider("MASTER VOLUME", "master_vol", 0.0, 1.0)
	_slider("MUSIC VOLUME", "music_vol", 0.0, 1.0)
	_slider("SFX VOLUME", "sfx_vol", 0.0, 1.0)
	_slider("MOUSE SENSITIVITY", "sensitivity", 0.3, 2.5)
	_cycle("INVERT Y", "invert_y", ["OFF", "ON"], [false, true])
	_cycle("TRAFFIC", "traffic", ["LOW", "NORMAL", "HIGH"], [0, 1, 2])
	_cycle("PEDESTRIANS", "peds", ["LOW", "NORMAL", "HIGH"], [0, 1, 2])
	_cycle("MINIMAP", "minimap", ["OFF", "ON"], [false, true])
	_cycle("AUTO UPDATE", "auto_update", ["OFF", "ON"], [false, true])
	var close := Button.new()
	close.text = "CLOSE"
	close.add_theme_font_size_override("font_size", 22)
	close.pressed.connect(func() -> void:
		Game.sound.play_ui("click")
		visible = false)
	rows.add_child(close)

func _row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	l.add_theme_font_size_override("font_size", 17)
	l.custom_minimum_size = Vector2(240, 0)
	row.add_child(l)
	rows.add_child(row)
	return row

func _cycle(label_text: String, key: String, names: Array, values: Array) -> void:
	var row := _row(label_text)
	var b := Button.new()
	b.add_theme_font_size_override("font_size", 17)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var idx := maxi(values.find(Game.settings[key]), 0)
	b.text = names[idx]
	b.pressed.connect(func() -> void:
		idx = (idx + 1) % values.size()
		b.text = names[idx]
		Game.settings[key] = values[idx]
		Game.sound.play_ui("click")
		Game.apply_settings())
	row.add_child(b)

func _slider(label_text: String, key: String, vmin: float, vmax: float) -> void:
	var row := _row(label_text)
	var s := HSlider.new()
	s.min_value = vmin
	s.max_value = vmax
	s.step = 0.05
	s.value = float(Game.settings[key])
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(0, 26)
	s.value_changed.connect(func(v: float) -> void:
		Game.settings[key] = v
		Game.apply_settings())
	row.add_child(s)

func open() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
