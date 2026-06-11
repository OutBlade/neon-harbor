class_name UITheme
extends RefCounted
## The Neon Harbor design system: one Theme used by every menu and panel.
## Dark glass surfaces, cyan idle accents, magenta on hover.

const CYAN := Color(0.25, 0.92, 1.0)
const MAGENTA := Color(1.0, 0.2, 0.6)

static var _cached: Theme = null

static func build() -> Theme:
	if _cached != null:
		return _cached
	var t := Theme.new()
	# Buttons: dark glass with a neon edge that answers the cursor.
	t.set_stylebox("normal", "Button", _sb(Color(0.02, 0.03, 0.1, 0.9), Color(CYAN.r, CYAN.g, CYAN.b, 0.45)))
	t.set_stylebox("hover", "Button", _sb(Color(0.06, 0.08, 0.18, 0.95), MAGENTA))
	t.set_stylebox("pressed", "Button", _sb(Color(0.1, 0.25, 0.35, 0.95), CYAN))
	t.set_stylebox("disabled", "Button", _sb(Color(0.02, 0.02, 0.06, 0.7), Color(0.4, 0.4, 0.5, 0.3)))
	var focus := _sb(Color(0, 0, 0, 0), CYAN)
	focus.draw_center = false
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", Color(0.85, 0.95, 1.0))
	t.set_color("font_hover_color", "Button", Color(1.0, 0.8, 0.92))
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.6))
	# Sliders: thin cyan channel with a bright fill.
	var channel := _sb(Color(0.02, 0.03, 0.1, 0.9), Color(CYAN.r, CYAN.g, CYAN.b, 0.3))
	channel.content_margin_top = 3.0
	channel.content_margin_bottom = 3.0
	t.set_stylebox("slider", "HSlider", channel)
	var fill := _sb(Color(CYAN.r, CYAN.g, CYAN.b, 0.65), CYAN)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", _sb(MAGENTA * Color(1, 1, 1, 0.7), MAGENTA))
	return _commit(t)

static func _commit(t: Theme) -> Theme:
	_cached = t
	return t

static func _sb(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb
