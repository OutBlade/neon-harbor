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
var park_centers: Array = []
var environment: Environment
var blinkers: Array = []
var blink_on := true
var blink_t := 0.0
var flickers: Array = []
var holo: Node3D = null

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
	add_to_group("city")
	rng.seed = CITY_SEED
	_make_building_mats()
	_environment()
	_ground_and_water()
	_lane_dashes()
	_crosswalks()
	_curbs()
	_skyline()
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
	_ramps()
	_beach_balls()
	_cats()
	_pigeons()
	spawn_point = block_center(center, center) + Vector3(0, CURB_H + 1.2, SLAB / 2.0 - 2.0)
	station_point = block_center(center, center - 1) + Vector3(0, CURB_H + 1.2, 0)
	hospital_point = block_center(center + 1, center) + Vector3(0, CURB_H + 1.2, 0)
	dock_point = Vector3(line(2), 0.5, line(N) + 2.0)

# ------------------------------------------------------------ environment

func _environment() -> void:
	var env := Environment.new()
	environment = env
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type sky;
// Night sky: horizon glow, hashed star field, a moon with a soft halo.
void sky() {
	vec3 dir = EYEDIR;
	float h = clamp(dir.y, -1.0, 1.0);
	vec3 horizon = vec3(0.10, 0.03, 0.16);
	vec3 zenith = vec3(0.004, 0.004, 0.018);
	vec3 col = mix(horizon, zenith, clamp(h * 2.4 + 0.12, 0.0, 1.0));
	if (h > 0.02) {
		vec3 cell = floor(dir * 170.0);
		float star = fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
		float tw = 0.75 + 0.25 * sin(TIME * 2.0 + star * 40.0);
		if (star > 0.997) {
			col += vec3(0.75, 0.85, 1.0) * (star - 0.997) * 300.0 * tw;
		}
	}
	vec3 moon_dir = normalize(vec3(0.45, 0.55, -0.6));
	float md = dot(dir, moon_dir);
	col += vec3(0.85, 0.9, 1.0) * smoothstep(0.9991, 0.9995, md) * 1.6;
	col += vec3(0.35, 0.4, 0.65) * smoothstep(0.995, 0.9995, md) * 0.16;
	COLOR = col;
}
"""
	sky_mat.shader = shader
	sky.sky_material = sky_mat
	env.sky = sky
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
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	apply_quality(Game.fancy_graphics)

func apply_quality(fancy: bool) -> void:
	# FANCY adds screen space reflections for the wet street look.
	environment.ssr_enabled = fancy
	environment.ssr_max_steps = 32
	environment.glow_intensity = 0.7 if fancy else 0.55
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.light_energy = 0.35
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 90.0
	moon.rotation_degrees = Vector3(-55, 35, 0)
	add_child(moon)

func _ground_and_water() -> void:
	# Rain-slick asphalt: low roughness so SSR mirrors the neon at night.
	var road_mat := _mat(Color(0.045, 0.045, 0.055))
	road_mat.roughness = 0.22
	road_mat.metallic = 0.45
	var half := N * PITCH / 2.0
	# Asphalt base covers the city footprint, stops where the harbor begins.
	var ground_depth := half * 2.0 + 80.0
	var ground := _static_box(self, Vector3(half * 2.0 + 80.0, 2.0, ground_depth),
		Vector3(0, -1.0, (half + 4.0) - ground_depth / 2.0), road_mat)
	ground.name = "Ground"
	# Harbor water south of the city, animated swell shader.
	var water_mat := ShaderMaterial.new()
	var ws := Shader.new()
	ws.code = """
shader_type spatial;
void fragment() {
	vec2 uv = UV * 70.0;
	float w = sin(uv.x * 3.1 + TIME * 1.1) * 0.5 + sin(uv.y * 4.3 - TIME * 0.8) * 0.3;
	w += sin((uv.x + uv.y) * 6.0 + TIME * 1.7) * 0.2;
	ALBEDO = vec3(0.012, 0.05, 0.09);
	ROUGHNESS = 0.06;
	METALLIC = 0.55;
	EMISSION = vec3(0.02, 0.22, 0.32) * (0.45 + 0.3 * w);
}
"""
	water_mat.shader = ws
	var water := MeshInstance3D.new()
	var wmesh := BoxMesh.new()
	wmesh.size = Vector3(half * 2.0 + 80.0, 0.2, 220.0)
	wmesh.material = water_mat
	water.mesh = wmesh
	water.position = Vector3(0, -1.1, half + 4.0 + 110.0)
	water.name = "Water"
	add_child(water)
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

func _crosswalks() -> void:
	# Zebra crossings on all four arms of every intersection.
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bar := BoxMesh.new()
	bar.size = Vector3(1.7, 0.025, 0.55)
	bar.material = _mat(Color(0.5, 0.5, 0.46), Color(0.45, 0.45, 0.4), 0.45)
	mm.mesh = bar
	var rot90 := Basis.from_euler(Vector3(0, PI / 2.0, 0))
	var xf: Array[Transform3D] = []
	for k in N + 1:
		for l in N + 1:
			var c := node_pos(k, l)
			for i in range(-4, 5):
				xf.append(Transform3D(Basis.IDENTITY, c + Vector3(7.5, 0.03, float(i))))
				xf.append(Transform3D(Basis.IDENTITY, c + Vector3(-7.5, 0.03, float(i))))
				xf.append(Transform3D(rot90, c + Vector3(float(i), 0.03, 7.5)))
				xf.append(Transform3D(rot90, c + Vector3(float(i), 0.03, -7.5)))
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	add_child(inst)

func _curbs() -> void:
	# Light curb edging around every block so streets read at a glance.
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var strip := BoxMesh.new()
	strip.size = Vector3(SLAB, 0.06, 0.28)
	strip.material = _mat(Color(0.32, 0.32, 0.36))
	mm.mesh = strip
	var rot90 := Basis.from_euler(Vector3(0, PI / 2.0, 0))
	var xf: Array[Transform3D] = []
	var e := SLAB / 2.0 - 0.14
	for i in N:
		for j in N:
			var c := block_center(i, j) + Vector3(0, CURB_H + 0.03, 0)
			xf.append(Transform3D(Basis.IDENTITY, c + Vector3(0, 0, e)))
			xf.append(Transform3D(Basis.IDENTITY, c + Vector3(0, 0, -e)))
			xf.append(Transform3D(rot90, c + Vector3(e, 0, 0)))
			xf.append(Transform3D(rot90, c + Vector3(-e, 0, 0)))
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	add_child(inst)

func _skyline() -> void:
	# A distant ring of silhouette towers so the horizon is never empty,
	# including across the harbor where the fog eats them beautifully.
	var r2 := RandomNumberGenerator.new()
	r2.seed = CITY_SEED + 7
	for i in 64:
		var ang := TAU * float(i) / 64.0 + r2.randf_range(-0.04, 0.04)
		var dist := r2.randf_range(380.0, 540.0)
		var w := r2.randf_range(25.0, 60.0)
		var h := r2.randf_range(50.0, 160.0)
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(w, h, w)
		mesh.material = building_mats[r2.randi_range(0, building_mats.size() - 1)]
		mi.mesh = mesh
		mi.position = Vector3(cos(ang) * dist, h / 2.0 - 6.0, sin(ang) * dist)
		add_child(mi)

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
	# Breakable street furniture along the sidewalks.
	for n in rng.randi_range(1, 3):
		var kinds := ["trash", "trash", "mailbox", "cart"]
		var prop := Prop.new()
		prop.setup(kinds[rng.randi_range(0, kinds.size() - 1)])
		var along := rng.randf_range(-14.0, 14.0)
		var edge := SLAB / 2.0 - 1.0
		var offsets := [Vector3(along, 0, edge), Vector3(along, 0, -edge),
			Vector3(edge, 0, along), Vector3(-edge, 0, along)]
		prop.position = c + offsets[rng.randi_range(0, 3)] + Vector3(0, CURB_H + 0.15, 0)
		add_child(prop)

func _building(base: Vector3) -> void:
	var w := rng.randf_range(10.0, 15.0)
	var d := rng.randf_range(10.0, 15.0)
	var floors := rng.randi_range(3, 14)
	var h := floors * 4.0
	var mat: StandardMaterial3D = building_mats[rng.randi_range(0, building_mats.size() - 1)]
	# Tall towers get a stepped silhouette of shrinking tiers.
	var tiers: Array = [[w, d, h]]
	if floors >= 9:
		tiers = [[w, d, h * 0.55], [w * 0.72, d * 0.72, h * 0.3], [w * 0.5, d * 0.5, h * 0.15]]
	var y := CURB_H
	var first_body: StaticBody3D = null
	var top: StaticBody3D = null
	for t in tiers:
		var th: float = t[2]
		top = _static_box(self, Vector3(t[0], th, t[1]), base + Vector3(0, y + th / 2.0, 0), mat)
		if first_body == null:
			first_body = top
		y += th
	var tw: float = tiers[-1][0]
	var td: float = tiers[-1][1]
	var th_top: float = tiers[-1][2]
	# Dark roof cap so rooftops read correctly from above.
	var roof_mat := _mat(Color(0.13, 0.13, 0.15))
	_box(top, Vector3(tw + 0.2, 0.4, td + 0.2), Vector3(0, th_top / 2.0 + 0.2, 0), roof_mat)
	# Neon roofline trim on some towers.
	if rng.randf() < 0.45:
		var neon: Color = NEON_PALETTE[rng.randi_range(0, NEON_PALETTE.size() - 1)]
		var trim := _mat(Color(0.05, 0.05, 0.07), neon, 3.6)
		var ty := th_top / 2.0 - 0.3
		_box(top, Vector3(tw + 0.3, 0.25, 0.25), Vector3(0, ty, td / 2.0 + 0.1), trim)
		_box(top, Vector3(tw + 0.3, 0.25, 0.25), Vector3(0, ty, -td / 2.0 - 0.1), trim)
		_box(top, Vector3(0.25, 0.25, td + 0.3), Vector3(tw / 2.0 + 0.1, ty, 0), trim)
		_box(top, Vector3(0.25, 0.25, td + 0.3), Vector3(-tw / 2.0 - 0.1, ty, 0), trim)
	# Antenna with a blinking aircraft beacon on the tallest towers.
	if h >= 40.0 and rng.randf() < 0.6:
		var pole := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.05
		pm.bottom_radius = 0.09
		pm.height = 5.0
		pm.material = _mat(Color(0.2, 0.2, 0.22))
		pole.mesh = pm
		pole.position = base + Vector3(0, CURB_H + h + 2.5, 0)
		add_child(pole)
		var beacon := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.25
		bm.height = 0.5
		bm.material = _mat(Color(0.2, 0.02, 0.02), Color(1.0, 0.1, 0.1), 5.0)
		beacon.mesh = bm
		beacon.position = base + Vector3(0, CURB_H + h + 5.1, 0)
		add_child(beacon)
		blinkers.append(beacon)
	# Storefront sign facing the nearest road.
	if sign_count < 60 and rng.randf() < 0.6:
		var t1h: float = tiers[0][2]
		_sign(first_body, w, d, t1h)

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
	# A few signs have a loose wire somewhere.
	if rng.randf() < 0.22:
		flickers.append({"node": holder, "t": rng.randf_range(1.0, 5.0)})

func _park(i: int, j: int) -> void:
	var c := _slab(i, j, Color(0.05, 0.12, 0.06))
	park_centers.append(c)
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
	# Rotating holographic welcome sign above the monument.
	holo = Node3D.new()
	holo.position = c + Vector3(0, CURB_H + 12.0, 0)
	add_child(holo)
	for side in [0.0, PI]:
		var label := Label3D.new()
		label.text = "WELCOME TO NEON HARBOR"
		label.font_size = 96
		label.pixel_size = 0.014
		label.modulate = Color(0.4, 1.5, 1.8, 0.85)
		label.rotation.y = side
		holo.add_child(label)

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
			# Fake volumetric cone under the lamp head.
			var cone := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.12
			cm.bottom_radius = 2.3
			cm.height = 4.6
			var conem := StandardMaterial3D.new()
			conem.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			conem.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			conem.albedo_color = Color(1.0, 0.85, 0.55, 0.06)
			conem.emission_enabled = true
			conem.emission = Color(1.0, 0.85, 0.55)
			conem.emission_energy_multiplier = 0.3
			conem.cull_mode = BaseMaterial3D.CULL_DISABLED
			cm.material = conem
			cone.mesh = cm
			cone.position = p + Vector3(0, CURB_H + 2.8, 0)
			add_child(cone)

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

# ------------------------------------------------------------ fun stuff

func _ramps() -> void:
	# Road ramps for stunt bonuses, plus two aimed straight at the harbor
	# through the railing gaps. Those are a personality test.
	var defs := [
		[Vector3(line(2) + 2.6, 0, 60.0), 0.0],
		[Vector3(line(8) - 2.6, 0, -60.0), PI],
		[Vector3(60.0, 0, line(3) - 2.6), PI / 2.0],
		[Vector3(-60.0, 0, line(7) + 2.6), -PI / 2.0],
		[Vector3(line(5) + 2.6, 0, -130.0), 0.0],
		[Vector3(-130.0, 0, line(5) - 2.6), PI / 2.0],
		[Vector3(line(4), 0, 237.0), PI],
		[Vector3(line(7), 0, 237.0), PI],
	]
	for r in defs:
		_ramp(r[0], r[1])

func _ramp(pos: Vector3, yaw: float) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = yaw
	add_child(body)
	var holder := Node3D.new()
	holder.rotation.x = 0.20
	holder.position = Vector3(0, 0.8, 0)
	body.add_child(holder)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(7.0, 0.5, 12.0)
	cs.shape = shape
	holder.add_child(cs)
	var mat := _mat(Color(0.12, 0.12, 0.14))
	mat.roughness = 0.4
	_box(holder, Vector3(7.0, 0.5, 12.0), Vector3.ZERO, mat)
	var stripe := _mat(Color(0.1, 0.05, 0.02), Color(1.0, 0.55, 0.1), 2.8)
	_box(holder, Vector3(6.6, 0.06, 0.8), Vector3(0, 0.28, -2.0), stripe)
	_box(holder, Vector3(6.6, 0.06, 0.8), Vector3(0, 0.28, -4.5), stripe)

func _beach_balls() -> void:
	var c := block_center(N / 2, N / 2)
	var spots: Array = [c + Vector3(6, 2, -6), c + Vector3(-7, 2, 5)]
	for pc in park_centers:
		spots.append(pc + Vector3(rng.randf_range(-8, 8), 2, rng.randf_range(-8, 8)))
	var colors := [Color(0.2, 0.9, 1.0), Color(1.0, 0.4, 0.7), Color(1.0, 0.85, 0.3), Color(0.5, 1.0, 0.4)]
	for i in mini(spots.size(), 7):
		var ball := RigidBody3D.new()
		ball.mass = 4.0
		var pm := PhysicsMaterial.new()
		pm.bounce = 0.82
		pm.friction = 0.6
		ball.physics_material_override = pm
		var cs := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 1.5
		cs.shape = sphere
		ball.add_child(cs)
		var mi := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 1.5
		mesh.height = 3.0
		var col: Color = colors[i % colors.size()]
		mesh.material = _mat(col * 0.25, col, 1.6)
		mi.mesh = mesh
		ball.add_child(mi)
		ball.position = spots[i]
		add_child(ball)

func _cats() -> void:
	var c := block_center(N / 2, N / 2)
	var park_spot: Vector3 = park_centers[0] + Vector3(6, CURB_H, 3) if park_centers.size() > 0 \
		else c + Vector3(-12, CURB_H, 12)
	var spots := [
		c + Vector3(2.6, CURB_H + 0.5, -2.6),
		warehouse_roof + Vector3(3.0, -0.7, 2.0),
		Vector3(line(8) - 3.0, 0.4, line(N) - 2.5),
		park_spot,
		block_center(1, 1) + Vector3(15.5, CURB_H, 15.5),
	]
	for i in 5:
		var cat := Cat.new()
		cat.setup(i)
		cat.position = spots[i]
		add_child(cat)

func _pigeons() -> void:
	for i in 14:
		spawn_pigeon_flock(block_center(rng.randi_range(0, N - 1), rng.randi_range(0, N - 1)))

func spawn_pigeon_flock(near: Vector3) -> void:
	var flock := PigeonFlock.new()
	flock.position = near + Vector3(rng.randf_range(-15, 15), CURB_H, rng.randf_range(-15, 15))
	add_child(flock)

func _process(delta: float) -> void:
	if holo != null:
		holo.rotation.y += delta * 0.5
	# Aircraft beacons blink in unison, neon signs flicker individually.
	blink_t += delta
	if blink_t > 0.7:
		blink_t = 0.0
		blink_on = not blink_on
		for b in blinkers:
			if is_instance_valid(b):
				b.visible = blink_on
	for f in flickers:
		f["t"] -= delta
		if f["t"] <= 0.0:
			var node: Node3D = f["node"]
			if is_instance_valid(node):
				node.visible = not node.visible
				f["t"] = rng.randf_range(0.04, 0.18) if node.visible == false else rng.randf_range(1.5, 6.0)

# ------------------------------------------------------------ helpers

func _make_building_mats() -> void:
	for v in 8:
		var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
		img.fill(Color(0.01, 0.01, 0.02))
		var warm := rng.randf() < 0.5
		if v % 3 == 2:
			# Office towers: full horizontal light bands on some floors.
			for cy in range(0, 32, 4):
				if rng.randf() < 0.35:
					var bb := rng.randf_range(0.35, 0.7)
					var bc := Color(bb, bb * 0.9, bb * 0.7) if warm else Color(bb * 0.65, bb * 0.85, bb)
					for px in 32:
						for py in 2:
							img.set_pixel(px, cy + 1 + py, bc)
		else:
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
