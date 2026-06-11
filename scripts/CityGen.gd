class_name CityGen
extends Node3D
## Procedurally builds the entire night city: roads, blocks, buildings,
## neon signage, streetlights, parks, the harbor waterfront and spawn points.
## Deterministic seed so everyone gets the same city.

const N := 10                 # blocks per side
const PITCH := 48.0           # distance between block centers
const SLAB := 38.0            # sidewalk slab size, roads fill the gaps
const CURB_H := 0.3
const CITY_SEED := 20260611

const NEON_PALETTE: Array[Color] = [
	Color(1.0, 0.18, 0.58), Color(0.14, 0.9, 1.0), Color(0.71, 0.29, 1.0),
	Color(1.0, 0.7, 0.13), Color(0.5, 1.0, 0.35), Color(1.0, 0.3, 0.2),
]
const SIGN_NAMES: Array[String] = [
	"NOODLE BAR", "HOTEL LUX", "CLUB VOLT", "PAWN SHOP", "RAMEN 24H",
	"CYBER CAFE", "MOTORS", "LIQUOR", "THE GRID", "NEON DINER",
	"ARCADE", "KARAOKE STAR", "BODEGA", "GARAGE 3", "HARBOR INN",
	"VINYL", "TATTOO", "SUSHI GO", "FIRST BANK", "CINEMA ROYAL",
]
const CAR_COLORS: Array[Color] = [
	Color(0.7, 0.1, 0.12), Color(0.12, 0.3, 0.7), Color(0.75, 0.75, 0.78),
	Color(0.15, 0.15, 0.17), Color(0.7, 0.5, 0.1), Color(0.25, 0.5, 0.25),
	Color(0.5, 0.2, 0.5), Color(0.9, 0.9, 0.9),
]

var rng := RandomNumberGenerator.new()
var spawn_point := Vector3.ZERO
var station_point := Vector3.ZERO
var hospital_point := Vector3.ZERO
var warehouse_roof := Vector3.ZERO
var dock_point := Vector3.ZERO
var light_budget := 44
var building_mats: Array = []
var sign_count := 0

static func line(k: int) -> float:
	return -N * PITCH / 2.0 + k * PITCH

static func node_pos(k: int, l: int) -> Vector3:
	return Vector3(line(k), 0.0, line(l))

static func random_node(r: RandomNumberGenerator) -> Vector2i:
	return Vector2i(r.randi_range(0, N), r.randi_range(0, N))

func block_center(i: int, j: int) -> Vector3:
	var off := -(N - 1) * PITCH / 2.0
	return Vector3(off + i * PITCH, 0.0, off + j * PITCH)

func build() -> void:
	rng.seed = CITY_SEED
	_make_building_mats()
	_environment()
	_ground_and_water()
	_lane_dashes()
	_perimeter_walls()
	var center := N / 2
	for i in N:
		for j in N:
			if i == center and j == center:
				_plaza(i, j)
			elif i == 3 and j == 7:
				_warehouse_block(i, j)
			elif rng.randf() < 0.08:
				_park(i, j)
			else:
				_block(i, j)
	_parked_cars()
	spawn_point = block_center(center, center) + Vector3(0, CURB_H + 1.2, SLAB / 2.0 - 2.0)
	station_point = block_center(center, center - 1) + Vector3(0, CURB_H + 1.2, 0)
	hospital_point = block_center(center + 1, center) + Vector3(0, CURB_H + 1.2, 0)
	dock_point = Vector3(line(2), 0.5, line(N) + 2.0)

# ------------------------------------------------------------ environment

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.012, 0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.28, 0.45)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.05, 0.12)
	env.fog_density = 0.0035
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.light_energy = 0.35
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 90.0
	moon.rotation_degrees = Vector3(-55, 35, 0)
	add_child(moon)

func _ground_and_water() -> void:
	var road_mat := _mat(Color(0.045, 0.045, 0.055))
	road_mat.roughness = 0.9
	var half := N * PITCH / 2.0
	# Asphalt base covers the city footprint, stops where the harbor begins.
	var ground_depth := half * 2.0 + 80.0
	var ground := _static_box(self, Vector3(half * 2.0 + 80.0, 2.0, ground_depth),
		Vector3(0, -1.0, (half + 4.0) - ground_depth / 2.0), road_mat)
	ground.name = "Ground"
	# Harbor water south of the city.
	var water_mat := _mat(Color(0.02, 0.06, 0.1), Color(0.05, 0.35, 0.5), 0.9)
	water_mat.roughness = 0.05
	water_mat.metallic = 0.6
	var water := _box(self, Vector3(half * 2.0 + 80.0, 0.2, 220.0),
		Vector3(0, -1.1, half + 4.0 + 110.0), water_mat)
	water.name = "Water"
	# Seabed so vehicles that fly in come to rest before the rescue teleport.
	var seabed := StaticBody3D.new()
	var sc := CollisionShape3D.new()
	var sb := BoxShape3D.new()
	sb.size = Vector3(half * 2.0 + 80.0, 2.0, 220.0)
	sc.shape = sb
	seabed.add_child(sc)
	seabed.position = Vector3(0, -6.0, half + 4.0 + 110.0)
	add_child(seabed)
	# Promenade railing with a neon strip along the waterfront.
	var rail_mat := _mat(Color(0.1, 0.1, 0.12), Color(0.14, 0.9, 1.0), 2.5)
	for k in N:
		var x := (line(k) + line(k + 1)) / 2.0
		_static_box(self, Vector3(PITCH - 10.0, 1.0, 0.3), Vector3(x, 0.5, half + 3.6), rail_mat)

func _lane_dashes() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var dash := BoxMesh.new()
	dash.size = Vector3(0.25, 0.04, 2.0)
	dash.material = _mat(Color(0.4, 0.4, 0.38), Color(0.75, 0.75, 0.65), 1.0)
	mm.mesh = dash
	var dashes: Array[Transform3D] = []
	var half := N * PITCH / 2.0
	for k in N + 1:
		var c := line(k)
		var d := -half + 2.0
		while d < half - 2.0:
			dashes.append(Transform3D(Basis.IDENTITY, Vector3(c, 0.03, d)))
			dashes.append(Transform3D(Basis.from_euler(Vector3(0, PI / 2.0, 0)), Vector3(d, 0.03, c)))
			d += 6.0
	mm.instance_count = dashes.size()
	for i in dashes.size():
		mm.set_instance_transform(i, dashes[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	add_child(inst)

func _perimeter_walls() -> void:
	var wall_mat := _mat(Color(0.06, 0.06, 0.1), Color(0.71, 0.29, 1.0), 1.8)
	var half := N * PITCH / 2.0 + 6.0
	var len := half * 2.0 + 8.0
	_static_box(self, Vector3(len, 3.0, 1.0), Vector3(0, 1.5, -half), wall_mat)
	_static_box(self, Vector3(1.0, 3.0, len + 240.0), Vector3(-half, 1.5, 120), wall_mat)
	_static_box(self, Vector3(1.0, 3.0, len + 240.0), Vector3(half, 1.5, 120), wall_mat)

# ------------------------------------------------------------ city blocks

func _slab(i: int, j: int, color: Color) -> Vector3:
	var c := block_center(i, j)
	var mat := _mat(color)
	mat.roughness = 0.85
	_static_box(self, Vector3(SLAB, CURB_H * 2.0, SLAB), Vector3(c.x, 0.0, c.z), mat)
	_streetlights(c)
	return c

func _block(i: int, j: int) -> void:
	var c := _slab(i, j, Color(0.10, 0.10, 0.12))
	var lots := [Vector2(-9.0, -9.0), Vector2(9.0, -9.0), Vector2(-9.0, 9.0), Vector2(9.0, 9.0)]
	for lot in lots:
		if rng.randf() < 0.78:
			_building(c + Vector3(lot.x, 0, lot.y))

func _building(base: Vector3) -> void:
	var w := rng.randf_range(10.0, 15.0)
	var d := rng.randf_range(10.0, 15.0)
	var floors := rng.randi_range(3, 14)
	var h := floors * 4.0
	var mat: StandardMaterial3D = building_mats[rng.randi_range(0, building_mats.size() - 1)]
	var body := _static_box(self, Vector3(w, h, d), base + Vector3(0, CURB_H + h / 2.0, 0), mat)
	# Dark roof cap so rooftops read correctly from above.
	var roof_mat := _mat(Color(0.13, 0.13, 0.15))
	_box(body, Vector3(w + 0.2, 0.4, d + 0.2), Vector3(0, h / 2.0 + 0.2, 0), roof_mat)
	# Neon roofline trim on some towers.
	if rng.randf() < 0.42:
		var neon: Color = NEON_PALETTE[rng.randi_range(0, NEON_PALETTE.size() - 1)]
		var trim := _mat(Color(0.05, 0.05, 0.07), neon, 3.6)
		var y := h / 2.0 - 0.3
		_box(body, Vector3(w + 0.3, 0.25, 0.25), Vector3(0, y, d / 2.0 + 0.1), trim)
		_box(body, Vector3(w + 0.3, 0.25, 0.25), Vector3(0, y, -d / 2.0 - 0.1), trim)
		_box(body, Vector3(0.25, 0.25, d + 0.3), Vector3(w / 2.0 + 0.1, y, 0), trim)
		_box(body, Vector3(0.25, 0.25, d + 0.3), Vector3(-w / 2.0 - 0.1, y, 0), trim)
	# Storefront sign facing the nearest road.
	if sign_count < 52 and rng.randf() < 0.55:
		_sign(body, w, d, h)

func _sign(body: StaticBody3D, w: float, d: float, h: float) -> void:
	sign_count += 1
	var neon: Color = NEON_PALETTE[rng.randi_range(0, NEON_PALETTE.size() - 1)]
	var text: String = SIGN_NAMES[rng.randi_range(0, SIGN_NAMES.size() - 1)]
	var sw := minf(w - 2.0, 1.1 * text.length())
	var sy := rng.randf_range(5.0, minf(h - 2.0, 11.0))
	var face := rng.randi_range(0, 3)
	var positions := [
		Vector3(0, sy, d / 2.0 + 0.15), Vector3(0, sy, -d / 2.0 - 0.15),
		Vector3(w / 2.0 + 0.15, sy, 0), Vector3(-w / 2.0 - 0.15, sy, 0),
	]
	var rots := [0.0, PI, -PI / 2.0, PI / 2.0]
	var holder := Node3D.new()
	holder.position = positions[face]
	holder.rotation.y = rots[face]
	body.add_child(holder)
	var back := _mat(Color(0.03, 0.03, 0.04), neon * 0.5, 1.2)
	_box(holder, Vector3(sw, 1.4, 0.12), Vector3.ZERO, back)
	var label := Label3D.new()
	label.text = text
	label.font_size = 110
	label.pixel_size = 0.01
	label.modulate = Color(neon.r * 1.6, neon.g * 1.6, neon.b * 1.6)
	label.position = Vector3(0, 0, 0.09)
	holder.add_child(label)

func _park(i: int, j: int) -> void:
	var c := _slab(i, j, Color(0.05, 0.12, 0.06))
	var trunk_mat := _mat(Color(0.2, 0.14, 0.08))
	var leaf_mat := _mat(Color(0.04, 0.16, 0.08))
	for t in rng.randi_range(6, 10):
		var p := c + Vector3(rng.randf_range(-14, 14), CURB_H, rng.randf_range(-14, 14))
		var trunk := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.18
		tm.bottom_radius = 0.25
		tm.height = 1.6
		tm.material = trunk_mat
		trunk.mesh = tm
		trunk.position = p + Vector3(0, 0.8, 0)
		add_child(trunk)
		var crown := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = rng.randf_range(1.4, 2.2)
		cm.height = rng.randf_range(2.6, 4.0)
		cm.material = leaf_mat
		crown.mesh = cm
		crown.position = p + Vector3(0, 1.6 + cm.height / 2.0, 0)
		add_child(crown)

func _plaza(i: int, j: int) -> void:
	var c := _slab(i, j, Color(0.12, 0.11, 0.14))
	# Glowing monument column in the middle of the spawn plaza.
	var glow := _mat(Color(0.05, 0.05, 0.08), Color(0.14, 0.9, 1.0), 4.0)
	_static_box(self, Vector3(2.2, 9.0, 2.2), c + Vector3(0, CURB_H + 4.5, 0), glow)
	var ring := _mat(Color(0.08, 0.08, 0.1), Color(1.0, 0.18, 0.58), 3.0)
	_static_box(self, Vector3(6.0, 0.5, 6.0), c + Vector3(0, CURB_H + 0.25, 0), ring)

func _warehouse_block(i: int, j: int) -> void:
	var c := _slab(i, j, Color(0.10, 0.10, 0.12))
	var mat := _mat(Color(0.12, 0.09, 0.07), Color(1.0, 0.7, 0.13), 0.4)
	var h := 6.0
	_static_box(self, Vector3(26.0, h, 20.0), c + Vector3(0, CURB_H + h / 2.0, 0), mat)
	warehouse_roof = c + Vector3(0, CURB_H + h + 1.0, 0)
	# Crate staircase up to the roof.
	var crate := _mat(Color(0.25, 0.18, 0.1))
	var base := c + Vector3(14.5, CURB_H, 6.0)
	for s in 5:
		var size := Vector3(2.4, 1.2 * (s + 1), 2.4)
		_static_box(self, size, base + Vector3(0, size.y / 2.0, -s * 2.5), crate)
	var label := Label3D.new()
	label.text = "HARBOR FREIGHT CO"
	label.font_size = 140
	label.pixel_size = 0.012
	label.modulate = Color(1.6, 1.1, 0.2)
	label.position = c + Vector3(0, CURB_H + h - 1.0, 10.2)
	add_child(label)

func _streetlights(c: Vector3) -> void:
	var pole_mat := _mat(Color(0.15, 0.15, 0.17))
	var head_mat := _mat(Color(0.2, 0.2, 0.18), Color(1.0, 0.85, 0.55), 2.6)
	for corner: Vector3 in [Vector3(-1, 0, -1), Vector3(1, 0, 1)]:
		var p := c + corner * (SLAB / 2.0 - 0.8)
		var pole := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.07
		pm.bottom_radius = 0.1
		pm.height = 5.0
		pm.material = pole_mat
		pole.mesh = pm
		pole.position = p + Vector3(0, CURB_H + 2.5, 0)
		add_child(pole)
		_box(self, Vector3(0.5, 0.18, 0.5), p + Vector3(0, CURB_H + 5.1, 0), head_mat)
		if light_budget > 0 and rng.randf() < 0.55:
			light_budget -= 1
			var lamp := OmniLight3D.new()
			lamp.light_color = Color(1.0, 0.83, 0.55)
			lamp.light_energy = 1.6
			lamp.omni_range = 14.0
			lamp.position = p + Vector3(0, CURB_H + 4.6, 0)
			lamp.distance_fade_enabled = true
			lamp.distance_fade_begin = 120.0
			add_child(lamp)

func _parked_cars() -> void:
	var car_script := preload("res://scripts/Car.gd")
	# Guaranteed starter car right next to the spawn plaza.
	var center := N / 2
	var c := block_center(center, center)
	var spots: Array = [[c + Vector3(8.0, 0.0, SLAB / 2.0 + 3.2), 0.0, "sedan"]]
	for n in 26:
		var bi := rng.randi_range(0, N - 1)
		var bj := rng.randi_range(0, N - 1)
		var bc := block_center(bi, bj)
		var side := rng.randi_range(0, 3)
		var kind := "sports" if rng.randf() < 0.18 else "sedan"
		match side:
			0: spots.append([bc + Vector3(rng.randf_range(-12, 12), 0, SLAB / 2.0 + 3.2), 0.0, kind])
			1: spots.append([bc + Vector3(rng.randf_range(-12, 12), 0, -SLAB / 2.0 - 3.2), PI, kind])
			2: spots.append([bc + Vector3(SLAB / 2.0 + 3.2, 0, rng.randf_range(-12, 12)), PI / 2.0, kind])
			3: spots.append([bc + Vector3(-SLAB / 2.0 - 3.2, 0, rng.randf_range(-12, 12)), -PI / 2.0, kind])
	for s in spots:
		var car: VehicleBody3D = car_script.new()
		car.setup(s[2], CAR_COLORS[rng.randi_range(0, CAR_COLORS.size() - 1)])
		car.position = s[0] + Vector3(0, 0.7, 0)
		car.rotation.y = s[1]
		add_child(car)

# ------------------------------------------------------------ helpers

func _make_building_mats() -> void:
	for v in 8:
		var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
		img.fill(Color(0.01, 0.01, 0.02))
		var warm := rng.randf() < 0.5
		for cy in range(0, 32, 4):
			for cx in range(0, 32, 4):
				if rng.randf() < 0.42:
					var b := rng.randf_range(0.5, 1.0)
					var col := Color(b, b * 0.85, b * 0.6) if warm else Color(b * 0.7, b * 0.9, b)
					for px in 2:
						for py in 2:
							img.set_pixel(cx + 1 + px, cy + 1 + py, col)
		var tex := ImageTexture.create_from_image(img)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.05, 0.055, 0.085)
		mat.roughness = 0.7
		mat.emission_enabled = true
		# Emission operator is ADD: keep the color black so only the
		# window texture emits, otherwise whole facades glow white.
		mat.emission = Color(0, 0, 0)
		mat.emission_energy_multiplier = 2.3
		mat.emission_texture = tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.07, 0.07, 0.07)
		building_mats.append(mat)

func _mat(albedo: Color, emiss: Color = Color.BLACK, energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emiss
		m.emission_energy_multiplier = energy
	return m

func _box(parent: Node, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	return mi

func _static_box(parent: Node, size: Vector3, pos: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	body.add_child(mi)
	body.position = pos
	parent.add_child(body)
	return body

static func add_blip(node: Node3D, color: Color, radius: float = 3.0) -> MeshInstance3D:
	var blip := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	mesh.material = m
	blip.mesh = mesh
	blip.layers = 2
	blip.position = Vector3(0, 40, 0)
	node.add_child(blip)
	return blip
