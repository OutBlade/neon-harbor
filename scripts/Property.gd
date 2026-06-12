class_name Property
extends Node3D
## A buyable business. Walk up, press E, collect passive income while
## you play. The neon harbor economy is surprisingly liquid.

var prop_name := ""
var price := 0
var income := 0
var label: Label3D

func setup(name_: String, price_: int, income_: int) -> void:
	prop_name = name_
	price = price_
	income = income_

func _ready() -> void:
	add_to_group("shops")
	var owned := Game.owned_props.has(prop_name)
	var col := Color(0.3, 1.0, 0.5) if owned else Color(1.0, 0.85, 0.2)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.6
	torus.outer_radius = 2.0
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.05, 0.05)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 3.0
	torus.material = m
	ring.mesh = torus
	ring.position = Vector3(0, 0.35, 0)
	add_child(ring)
	label = Label3D.new()
	label.font_size = 64
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 4.2, 0)
	add_child(label)
	_refresh()
	CityGen.add_blip(self, col, 2.2)

func _refresh() -> void:
	if Game.owned_props.has(prop_name):
		label.text = "%s\nOWNED  +$%d/min" % [prop_name, income]
		label.modulate = Color(0.5, 1.6, 0.8)
	else:
		label.text = "%s\nFOR SALE  $%d" % [prop_name, price]
		label.modulate = Color(1.6, 1.3, 0.4)

func prompt_text() -> String:
	if Game.owned_props.has(prop_name):
		return ""
	return "Press E to buy %s for $%d" % [prop_name, price]

func try_buy() -> void:
	if Game.owned_props.has(prop_name):
		return
	if Game.money < price:
		Game.notify.emit("You need $%d for %s" % [price, prop_name])
		return
	Game.money -= price
	Game.money_changed.emit(Game.money)
	Game.owned_props.append(prop_name)
	Game.sound.play_ui("jingle")
	Game.notify.emit("%s is yours. It pays $%d a minute" % [prop_name, income])
	Game.save_game()
	_refresh()
