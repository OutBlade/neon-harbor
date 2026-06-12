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
var light_budget := 56
var building_mats: Array = []
var sign_count := 0
var vsign_count := 0
var billboard_count := 0
var park_centers: Array = []
var environment: Environment
var moon_light: DirectionalLight3D
var blinkers: Array = []
var blink_on := true
var blink_t := 0.0
var flickers: Array = []
var holo: Node3D = null
var bb := MeshBatch.new()
var _mat_cache: Dictionary = {}
var pole_transforms: Array[Transform3D] = []
var arm_transforms: Array[Transform3D] = []
var cone_transforms: Array[Transform3D] = []
var spray_points: Array[Vector3] = []
var train_cars: Array = []
var train_t := 0.0

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
	_boats_and_helis()
	_ramps()
	_beach_balls()
	_cats()
	_pigeons()
	_spray_shops()
	_monorail()
	_commit_batches()
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
// Night sky: gradient with sodium city-glow horizon, two layers of
// twinkling tinted stars, a faint milky way band, slow drifting high
// clouds lit from below, and a cratered moon with a two-stage halo.
float hash13(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.13 + vec2(7.3);
		a *= 0.5;
	}
	return v;
}
void sky() {
	vec3 dir = EYEDIR;
	float h = clamp(dir.y, -1.0, 1.0);
	vec3 horizon = vec3(0.085, 0.035, 0.15);
	vec3 zenith = vec3(0.004, 0.005, 0.020);
	vec3 col = mix(horizon, zenith, clamp(h * 2.2 + 0.10, 0.0, 1.0));
	// Neon city glow hugging the skyline.
	col += vec3(0.13, 0.05, 0.15) * pow(clamp(1.0 - abs(h), 0.0, 1.0), 7.0);
	if (h > 0.0) {
		// Fine stars with per-star tint and twinkle.
		vec3 cell = floor(dir * 230.0);
		float star = hash13(cell);
		if (star > 0.9965) {
			float tw = 0.7 + 0.3 * sin(TIME * 1.7 + star * 40.0);
			vec3 tint = mix(vec3(0.6, 0.7, 1.0), vec3(1.0, 0.85, 0.7), hash13(cell + 19.0));
			col += tint * (star - 0.9965) * 240.0 * tw;
		}
		// A sparse layer of brighter stars.
		vec3 cell2 = floor(dir * 90.0);
		float star2 = hash13(cell2 + 7.0);
		if (star2 > 0.9985) {
			col += vec3(0.8, 0.9, 1.0) * (star2 - 0.9985) * 420.0;
		}
		// Faint milky way band across the zenith.
		float band = exp(-12.0 * abs(dot(dir, normalize(vec3(0.6, 0.25, -0.4)))));
		col += vec3(0.10, 0.12, 0.22) * band * (0.30 + 0.45 * fbm(dir.xz * 6.0 + vec2(3.0, 1.0)));
		// Slow drifting high clouds, lit faintly from the city below.
		float cl = fbm(dir.xz / (0.22 + h) * 1.3 + vec2(TIME * 0.004, TIME * 0.001));
		float cm = smoothstep(0.55, 0.85, cl) * clamp(h * 3.0, 0.0, 1.0);
		col = mix(col, vec3(0.055, 0.045, 0.10), cm * 0.65);
	}
	// Moon: cratered disc with limb shading.
	vec3 moon_dir = normalize(vec3(0.45, 0.55, -0.6));
	float md = dot(dir, moon_dir);
	float disc = smoothstep(0.99962, 0.99982, md);
	if (disc > 0.0) {
		float crater = fbm(dir.xz * 260.0);
		float limb = smoothstep(0.99962, 0.99996, md);
		vec3 moon_col = vec3(0.82, 0.85, 0.95) * (0.62 + 0.30 * crater) * (0.75 + 0.25 * limb);
		col = mix(col, moon_col, disc);
	}
	col += vec3(0.30, 0.35, 0.60) * pow(max(md, 0.0), 900.0) * 0.45;
	col += vec3(0.10, 0.13, 0.26) * pow(max(md, 0.0), 110.0) * 0.20;
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
	env.glow_intensity = 0.8
	env.glow_bloom = 0.06
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.05, 0.12)
	env.fog_density = 0.0035
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.04
	env.tonemap_exposure = 1.18
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# One moon, created once. apply_quality only retunes it.
	# (Previously a fresh DirectionalLight3D was added on every quality
	# change, stacking moons each time settings were touched.)
	moon_light = DirectionalLight3D.new()
	moon_light.light_color = Color(0.6, 0.7, 1.0)
	moon_light.light_energy = 0.35
	moon_light.shadow_enabled = true
	moon_light.directional_shadow_max_distance = 90.0
	moon_light.rotation_degrees = Vector3(-55, 35, 0)
	add_child(moon_light)
	apply_quality(Game.fancy_graphics)

func apply_quality(fancy: bool) -> void:
	# FANCY: screen space reflections for the wet street look, ambient
	# occlusion + indirect light so edges ground themselves, and volumetric
	# fog so neon signs, street lamps and headlights shaft through the damp
	# air. FAST keeps the flat fog and fake light cones only.
	environment.ssr_enabled = fancy
	environment.ssr_max_steps = 48
	environment.ssao_enabled = fancy
	environment.ssao_intensity = 1.6
	environment.ssil_enabled = fancy
	environment.ssil_intensity = 1.1
	environment.glow_intensity = 0.8 if fancy else 0.55
	environment.volumetric_fog_enabled = fancy
	environment.volumetric_fog_density = 0.012
	environment.volumetric_fog_albedo = Color(0.5, 0.55, 0.75)
	environment.volumetric_fog_anisotropy = 0.55
	environment.volumetric_fog_length = 110.0
	environment.volumetric_fog_sky_affect = 0.0
	if moon_light != null:
		moon_light.directional_shadow_max_distance = 140.0 if fancy else 90.0
		moon_light.light_energy = 0.4 if fancy else 0.35

func _noise_tex(frequency: float) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = CITY_SEED
	noise.frequency = frequency
	noise.fractal_octaves = 4
	return ImageTexture.create_from_image(noise.get_image(128, 128))

func _ground_and_water() -> void:
	# Rain-slick asphalt. A noise roughness mask carves mirror-flat puddle
	# patches into damp matte asphalt so SSR reflections pool in puddles
	# instead of coating the whole street evenly.
	var road_mat := _mat(Color(0.085, 0.085, 0.105))
	road_mat.roughness = 0.55
	road_mat.roughness_texture = _noise_tex(0.045)
	road_mat.metallic = 0.5
	road_mat.metallic_specular = 0.65
	road_mat.albedo_texture = _noise_tex(0.06)
	road_mat.uv1_triplanar = true
	road_mat.uv1_scale = Vector3(0.35, 0.35, 0.35)
	var half := N * PITCH / 2.0
	# Asphalt base covers the city footprint, stops where the harbor begins.
	var ground_depth := half * 2.0 + 80.0
	var ground := _static_box(self, Vector3(half * 2.0 + 80.0, 2.0, ground_depth),
		Vector3(0, -1.0, (half + 4.0) - ground_depth / 2.0), road_mat)
	ground.name = "Ground"
	# Harbor water: subdivided plane with real rolling swell displaced in
	# the vertex shader, finite-difference normals, fresnel sheen and a
	# specular glint streak aimed at the moon.
	var water_mat := ShaderMaterial.new()
	var ws := Shader.new()
	ws.code = """
shader_type spatial;
float hgt(vec2 p, float t) {
	float w = sin(p.x * 1.3 + t) * 0.45;
	w += sin(p.y * 1.7 - t * 0.7) * 0.30;
	w += sin((p.x + p.y) * 2.6 + t * 1.6) * 0.18;
	w += sin((p.x - p.y * 1.4) * 4.1 - t * 2.2) * 0.08;
	return w;
}
void vertex() {
	vec2 p = VERTEX.xz * 0.16;
	float e = 0.18;
	float h0 = hgt(p, TIME);
	float hx = hgt(p + vec2(e, 0.0), TIME);
	float hz = hgt(p + vec2(0.0, e), TIME);
	VERTEX.y += h0 * 0.26;
	NORMAL = normalize(vec3(-(hx - h0) / e * 0.042, 1.0, -(hz - h0) / e * 0.042));
}
void fragment() {
	ALBEDO = vec3(0.010, 0.040, 0.075);
	METALLIC = 0.9;
	ROUGHNESS = 0.05;
	SPECULAR = 0.6;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = vec3(0.012, 0.10, 0.155) * 0.35 + vec3(0.05, 0.28, 0.42) * fres * 0.55;
	vec3 moon_vs = normalize((VIEW_MATRIX * vec4(normalize(vec3(0.45, 0.55, -0.6)), 0.0)).xyz);
	vec3 rdir = reflect(-VIEW, NORMAL);
	float g = pow(max(dot(rdir, moon_vs), 0.0), 480.0);
	EMISSION += vec3(0.65, 0.75, 1.0) * g * 1.1;
}
"""
	water_mat.shader = ws
	var water := MeshInstance3D.new()
	var wmesh := PlaneMesh.new()
	wmesh.size = Vector2(half * 2.0 + 80.0, 220.0)
	wmesh.subdivide_width = 56
	wmesh.subdivide_depth = 26
	wmesh.material = water_mat
	water.mesh = wmesh
	water.position = Vector3(0, -1.0, half + 4.0 + 110.0)
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
	# Promenade railing: posts and twin rails, top rail carries the neon.
	var rail_mat := _mat(Color(0.1, 0.1, 0.12), Color(0.14, 0.9, 1.0), 2.5)
	var post_mat := _mat(Color(0.12, 0.12, 0.15))
	for k in N:
		var x := (line(k) + line(k + 1)) / 2.0
		bb.box(rail_mat, Vector3(PITCH - 10.0, 0.14, 0.16), Vector3(x, 1.0, half + 3.6))
		bb.box(post_mat, Vector3(PITCH - 10.0, 0.08, 0.10), Vector3(x, 0.55, half + 3.6))
		var px := x - (PITCH - 10.0) / 2.0
		while px <= x + (PITCH - 10.0) / 2.0 + 0.1:
			bb.box(post_mat, Vector3(0.12, 1.0, 0.12), Vector3(px, 0.5, half + 3.6))
			px += 4.75
		# Collision matches the old solid railing.
		var body := StaticBody3D.new()
		var cs2 := CollisionShape3D.new()
		var shape2 := BoxShape3D.new()
		shape2.size = Vector3(PITCH - 10.0, 1.0, 0.3)
		cs2.shape = shape2
		body.add_child(cs2)
		body.position = Vector3(x, 0.5, half + 3.6)
		add_child(body)
	# Mooring bollards along the waterfront.
	var bollard := _mat(Color(0.16, 0.14, 0.12))
	for k in N * 2:
		var bx := line(0) + 6.0 + float(k) * (N * PITCH - 12.0) / float(N * 2 - 1)
		bb.cyl(bollard, 0.16, 0.20, 0.55, Vector3(bx, 0.28, half + 2.2), 8)

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
	var beacon_mat := _mat(Color(0.2, 0.02, 0.02), Color(1.0, 0.12, 0.1), 4.0)
	for i in 64:
		var ang := TAU * float(i) / 64.0 + r2.randf_range(-0.04, 0.04)
		var dist := r2.randf_range(380.0, 540.0)
		var w := r2.randf_range(25.0, 60.0)
		var h := r2.randf_range(50.0, 160.0)
		var p := Vector3(cos(ang) * dist, h / 2.0 - 6.0, sin(ang) * dist)
		bb.box(building_mats[r2.randi_range(0, building_mats.size() - 1)], Vector3(w, h, w), p)
		# Stepped crowns break up the taller silhouettes.
		if h > 100.0 and r2.randf() < 0.6:
			bb.box(building_mats[r2.randi_range(0, building_mats.size() - 1)],
				Vector3(w * 0.55, h * 0.25, w * 0.55), p + Vector3(0, h * 0.55, 0))
		# Steady aviation beacons dot the distant skyline.
		if r2.randf() < 0.4:
			bb.box(beacon_mat, Vector3(0.9, 0.9, 0.9), Vector3(p.x, p.y + h / 2.0 + 0.5, p.z))

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
	if mat.albedo_texture == null:
		# Concrete grain. Doubling albedo compensates the texture multiply.
		mat.albedo_texture = _noise_tex(0.12)
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.8, 0.8, 0.8)
		mat.albedo_color = Color(minf(color.r * 2.0, 1.0), minf(color.g * 2.0, 1.0), minf(color.b * 2.0, 1.0))
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
		var kinds := ["trash", "trash", "mailbox", "cart", "hydrant"]
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
	# Tall towers get a stepped silhouette of shrinking tiers; some
	# mid-rises get a single setback so not every roofline is flat.
	var tiers: Array = [[w, d, h]]
	if floors >= 9:
		tiers = [[w, d, h * 0.55], [w * 0.72, d * 0.72, h * 0.3], [w * 0.5, d * 0.5, h * 0.15]]
	elif floors >= 6 and rng.randf() < 0.5:
		tiers = [[w, d, h * 0.7], [w * 0.78, d * 0.78, h * 0.3]]
	var y := CURB_H
	var first_body: StaticBody3D = null
	var parapet_mat := _mat(Color(0.10, 0.10, 0.12))
	for t in tiers:
		var th: float = t[2]
		var body := _static_box(self, Vector3(t[0], th, t[1]), base + Vector3(0, y + th / 2.0, 0), mat)
		if first_body == null:
			first_body = body
		y += th
		# Parapet lip crowns every tier so setbacks read from the street.
		var pw: float = t[0]
		var pd: float = t[1]
		bb.box(parapet_mat, Vector3(pw + 0.34, 0.38, 0.24), base + Vector3(0, y + 0.10, pd / 2.0 + 0.05))
		bb.box(parapet_mat, Vector3(pw + 0.34, 0.38, 0.24), base + Vector3(0, y + 0.10, -pd / 2.0 - 0.05))
		bb.box(parapet_mat, Vector3(0.24, 0.38, pd + 0.34), base + Vector3(pw / 2.0 + 0.05, y + 0.10, 0))
		bb.box(parapet_mat, Vector3(0.24, 0.38, pd + 0.34), base + Vector3(-pw / 2.0 - 0.05, y + 0.10, 0))
	# Occluder so towers hide whatever is behind them at street level.
	var occ := OccluderInstance3D.new()
	var occ_box := BoxOccluder3D.new()
	occ_box.size = Vector3(w * 0.9, float(tiers[0][2]), d * 0.9)
	occ.occluder = occ_box
	occ.position = base + Vector3(0, CURB_H + float(tiers[0][2]) / 2.0, 0)
	add_child(occ)
	_storefront(base, w, d)
	var tw: float = tiers[-1][0]
	var td: float = tiers[-1][1]
	# Dark roof cap so rooftops read correctly from above.
	var roof_mat := _mat(Color(0.13, 0.13, 0.15))
	bb.box(roof_mat, Vector3(tw + 0.2, 0.4, td + 0.2), base + Vector3(0, y + 0.2, 0))
	_roof_clutter(base, tw, td, y + 0.4, floors)
	if floors >= 5 and rng.randf() < 0.30:
		_fire_escape(base, w, d, float(tiers[0][2]))
	# Neon roofline trim on some towers.
	if rng.randf() < 0.45:
		var neon: Color = NEON_PALETTE[rng.randi_range(0, NEON_PALETTE.size() - 1)]
		var trim := _mat(Color(0.05, 0.05, 0.07), neon, 3.6)
		var ty := y - 0.3
		bb.box(trim, Vector3(tw + 0.3, 0.25, 0.25), base + Vector3(0, ty, td / 2.0 + 0.1))
		bb.box(trim, Vector3(tw + 0.3, 0.25, 0.25), base + Vector3(0, ty, -td / 2.0 - 0.1))
		bb.box(trim, Vector3(0.25, 0.25, td + 0.3), base + Vector3(tw / 2.0 + 0.1, ty, 0))
		bb.box(trim, Vector3(0.25, 0.25, td + 0.3), base + Vector3(-tw / 2.0 - 0.1, ty, 0))
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
	# Rooftop billboard on a few of the tall towers.
	if floors >= 10 and billboard_count < 8 and rng.randf() < 0.3:
		_billboard(base + Vector3(0, y + 0.4, 0), tw)
	# Vertical neon sign hugging a corner of some mid-rises.
	if vsign_count < 12 and floors >= 5 and rng.randf() < 0.22:
		_vertical_sign(first_body, w, d, float(tiers[0][2]))
	# Storefront sign facing the nearest road.
	if sign_count < 60 and rng.randf() < 0.6:
		var t1h: float = tiers[0][2]
		_sign(first_body, w, d, t1h)

func _storefront(base: Vector3, w: float, d: float) -> void:
	# Ground floor: a recessed glass band glowing warm from the inside,
	# corner pilasters grounding the tower, and a neon awning over a door.
	var glass := _mat(Color(0.03, 0.05, 0.06), Color(0.55, 0.5, 0.38), 0.9)
	glass.metallic = 0.7
	glass.roughness = 0.15
	var pilaster := _mat(Color(0.085, 0.085, 0.10))
	var y := CURB_H
	bb.box(glass, Vector3(w * 0.84, 2.6, 0.16), base + Vector3(0, y + 1.6, d / 2.0 + 0.07))
	bb.box(glass, Vector3(w * 0.84, 2.6, 0.16), base + Vector3(0, y + 1.6, -d / 2.0 - 0.07))
	bb.box(glass, Vector3(0.16, 2.6, d * 0.84), base + Vector3(w / 2.0 + 0.07, y + 1.6, 0))
	bb.box(glass, Vector3(0.16, 2.6, d * 0.84), base + Vector3(-w / 2.0 - 0.07, y + 1.6, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			bb.box(pilaster, Vector3(0.6, 4.2, 0.6),
				base + Vector3(sx * (w / 2.0 - 0.1), y + 2.1, sz * (d / 2.0 - 0.1)))
	# Awning wedge over one storefront, tinted from the neon palette.
	var neon: Color = NEON_PALETTE[rng.randi_range(0, NEON_PALETTE.size() - 1)]
	var awn := _mat(Color(neon.r * 0.30, neon.g * 0.30, neon.b * 0.30), neon, 0.5)
	var face := rng.randi_range(0, 3)
	var yaws := [0.0, PI, -PI / 2.0, PI / 2.0]
	var outs := [Vector3(0, 0, d / 2.0), Vector3(0, 0, -d / 2.0), Vector3(w / 2.0, 0, 0), Vector3(-w / 2.0, 0, 0)]
	var out: Vector3 = outs[face]
	var fwd := out.normalized()
	var b := Basis(Vector3.UP, yaws[face])
	bb.wedge(awn, Vector3(3.4, 0.55, 1.1), base + out + fwd * 0.55 + Vector3(0, y + 3.0, 0), b)

func _roof_clutter(base: Vector3, tw: float, td: float, roof_y: float, floors: int) -> void:
	# AC units, a roof-access bulkhead, sometimes a classic water tank.
	var box_mat := _mat(Color(0.17, 0.17, 0.19))
	var dark := _mat(Color(0.10, 0.10, 0.11))
	for n in rng.randi_range(1, 3):
		var p := base + Vector3(rng.randf_range(-tw / 2.0 + 1.2, tw / 2.0 - 1.2), roof_y + 0.38,
			rng.randf_range(-td / 2.0 + 1.2, td / 2.0 - 1.2))
		bb.box(box_mat, Vector3(1.3, 0.75, 1.05), p)
		bb.box(dark, Vector3(1.0, 0.06, 0.8), p + Vector3(0, 0.42, 0))
	bb.box(box_mat, Vector3(1.9, 1.15, 1.5),
		base + Vector3(tw / 2.0 - 1.3, roof_y + 0.58, td / 2.0 - 1.1))
	if floors >= 8 and rng.randf() < 0.35:
		var tank_p := base + Vector3(-tw / 2.0 + 1.7, roof_y + 2.1, -td / 2.0 + 1.7)
		var tank_mat := _mat(Color(0.20, 0.15, 0.11))
		bb.cyl(tank_mat, 1.0, 1.0, 2.0, tank_p, 10)
		bb.cyl(tank_mat, 0.06, 1.05, 0.8, tank_p + Vector3(0, 1.4, 0), 10)
		for leg in 4:
			var a := TAU * float(leg) / 4.0 + PI / 4.0
			bb.box(dark, Vector3(0.14, 1.6, 0.14), tank_p + Vector3(cos(a) * 0.7, -1.6, sin(a) * 0.7))

func _fire_escape(base: Vector3, w: float, d: float, tier_h: float) -> void:
	# Zigzag steel escape bolted to one facade: a platform every floor,
	# angled stair runs between them. All batched, free at runtime.
	var steel := _mat(Color(0.07, 0.07, 0.085))
	steel.metallic = 0.6
	steel.roughness = 0.5
	var face := rng.randi_range(0, 3)
	var yaws := [0.0, PI, -PI / 2.0, PI / 2.0]
	var outs := [Vector3(0, 0, d / 2.0), Vector3(0, 0, -d / 2.0), Vector3(w / 2.0, 0, 0), Vector3(-w / 2.0, 0, 0)]
	var fwd := (outs[face] as Vector3).normalized()
	var b := Basis(Vector3.UP, yaws[face])
	var side := b * Vector3.RIGHT
	var floor_y := CURB_H + 5.0
	var k := 0
	while floor_y < CURB_H + tier_h - 2.0:
		var p := base + (outs[face] as Vector3) + fwd * 0.65 + Vector3(0, floor_y, 0)
		bb.box(steel, Vector3(4.2, 0.08, 1.1), p, b)
		bb.box(steel, Vector3(4.2, 0.06, 0.05), p + fwd * 0.5 + Vector3(0, 0.5, 0), b)
		bb.box(steel, Vector3(0.05, 0.5, 0.05), p + fwd * 0.5 + side * 2.0 + Vector3(0, 0.25, 0), b)
		bb.box(steel, Vector3(0.05, 0.5, 0.05), p + fwd * 0.5 + side * -2.0 + Vector3(0, 0.25, 0), b)
		# Diagonal stair run up to the next platform, alternating sides.
		var dirn := 1.0 if k % 2 == 0 else -1.0
		var stair_b := b * Basis(Vector3.FORWARD, dirn * 0.55)
		bb.box(steel, Vector3(2.6, 0.07, 0.9), p + side * dirn * 1.0 + Vector3(0, 2.0, 0), stair_b)
		floor_y += 4.0
		k += 1

func _billboard(top: Vector3, tw: float) -> void:
	billboard_count += 1
	var frame := _mat(Color(0.10, 0.10, 0.12))
	var neon: Color = NEON_PALETTE[rng.randi_range(0, NEON_PALETTE.size() - 1)]
	var panel := _mat(Color(0.04, 0.04, 0.06), neon * 0.45, 1.6)
	var wdt := minf(tw - 1.0, 7.0)
	var yaw: float = [0.0, PI / 2.0][rng.randi_range(0, 1)]
	var b := Basis(Vector3.UP, yaw)
	bb.box(frame, Vector3(0.18, 2.6, 0.18), top + b * Vector3(-wdt / 2.0 + 0.5, 1.3, 0), b)
	bb.box(frame, Vector3(0.18, 2.6, 0.18), top + b * Vector3(wdt / 2.0 - 0.5, 1.3, 0), b)
	bb.box(panel, Vector3(wdt, 2.6, 0.22), top + b * Vector3(0, 3.4, 0), b)
	var text: String = SIGN_NAMES[rng.randi_range(0, SIGN_NAMES.size() - 1)]
	for s in [[0.16, 0.0], [-0.16, PI]]:
		var label := Label3D.new()
		label.text = text
		label.font_size = 120
		label.pixel_size = 0.012
		label.modulate = Color(neon.r * 1.7, neon.g * 1.7, neon.b * 1.7)
		label.position = top + b * Vector3(0, 3.4, s[0])
		label.rotation.y = yaw + s[1]
		add_child(label)

func _vertical_sign(body: StaticBody3D, w: float, d: float, h: float) -> void:
	# Classic stacked-letter blade sign on a building corner.
	vsign_count += 1
	var neon: Color = NEON_PALETTE[rng.randi_range(0, NEON_PALETTE.size() - 1)]
	var names := ["RAMEN", "HOTEL", "VOLT", "PAWN", "SUSHI", "VINYL", "BANK", "MOTEL"]
	var text: String = names[rng.randi_range(0, names.size() - 1)]
	var face := rng.randi_range(0, 3)
	var yaws := [0.0, PI, -PI / 2.0, PI / 2.0]
	var outs := [Vector3(w / 2.0 - 1.0, 0, d / 2.0 + 0.5), Vector3(-w / 2.0 + 1.0, 0, -d / 2.0 - 0.5),
		Vector3(w / 2.0 + 0.5, 0, d / 2.0 - 1.0), Vector3(-w / 2.0 - 0.5, 0, -d / 2.0 + 1.0)]
	var sh := clampf(1.35 * float(text.length()) + 1.0, 4.0, h - 6.0)
	var holder := Node3D.new()
	holder.position = (outs[face] as Vector3) + Vector3(0, 4.0 + sh / 2.0 - h / 2.0, 0)
	holder.rotation.y = yaws[face]
	body.add_child(holder)
	var back := _mat(Color(0.03, 0.03, 0.04), neon * 0.5, 1.2)
	_box(holder, Vector3(1.3, sh, 0.3), Vector3.ZERO, back)
	var vtext := ""
	for i in text.length():
		vtext += text[i]
		if i < text.length() - 1:
			vtext += "\n"
	var label := Label3D.new()
	label.text = vtext
	label.font_size = 100
	label.pixel_size = 0.011
	label.modulate = Color(neon.r * 1.6, neon.g * 1.6, neon.b * 1.6)
	label.position = Vector3(0, 0, 0.18)
	holder.add_child(label)
	if rng.randf() < 0.3:
		flickers.append({"node": holder, "t": rng.randf_range(1.0, 5.0)})

func _sign(body: StaticBody3D, w: float, d: float, h: float) -> void:
	sign_count += 1
	var neon: Color = NEON_PALETTE[rng.randi_range(0, NEON_PALETTE.size() - 1)]
	var text: String = SIGN_NAMES[rng.randi_range(0, SIGN_NAMES.size() - 1)]
	var sw := minf(w - 2.0, 1.1 * text.length())
	# Height measured from the ground, then converted to body-local space
	# so the sign always lands on the facade.
	var sy := rng.randf_range(4.5, maxf(minf(h - 1.5, 11.0), 5.0)) - h / 2.0
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
	# Mounting brackets tie the sign to the facade.
	var bracket := _mat(Color(0.12, 0.12, 0.14))
	_box(holder, Vector3(0.10, 0.10, 0.30), Vector3(-sw / 2.0 + 0.4, 0.5, -0.15), bracket)
	_box(holder, Vector3(0.10, 0.10, 0.30), Vector3(sw / 2.0 - 0.4, 0.5, -0.15), bracket)
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
	# Batched trees: tapered trunk, two stacked foliage cones with hue
	# variation, so every park reads as a grove instead of traffic cones.
	var trunk_mat := _mat(Color(0.16, 0.11, 0.07))
	var leaf_mats := [
		_mat(Color(0.035, 0.14, 0.07)), _mat(Color(0.05, 0.16, 0.06)), _mat(Color(0.03, 0.12, 0.09)),
	]
	for t in rng.randi_range(7, 11):
		var p := c + Vector3(rng.randf_range(-14, 14), CURB_H, rng.randf_range(-14, 14))
		var trunk_h := rng.randf_range(1.5, 2.2)
		bb.cyl(trunk_mat, 0.14, 0.24, trunk_h, p + Vector3(0, trunk_h / 2.0, 0), 7)
		var leaf: StandardMaterial3D = leaf_mats[rng.randi_range(0, leaf_mats.size() - 1)]
		var r1 := rng.randf_range(1.5, 2.3)
		var h1 := rng.randf_range(2.0, 2.8)
		bb.cyl(leaf, r1 * 0.45, r1, h1, p + Vector3(0, trunk_h + h1 / 2.0 - 0.2, 0), 8)
		bb.cyl(leaf, 0.0, r1 * 0.62, h1 * 0.8, p + Vector3(0, trunk_h + h1 + h1 * 0.4 - 0.5, 0), 8)
	# Park benches.
	var bench := _mat(Color(0.16, 0.12, 0.08))
	var bench_leg := _mat(Color(0.10, 0.10, 0.11))
	for bn in 3:
		var bp := c + Vector3(rng.randf_range(-12, 12), CURB_H, rng.randf_range(-12, 12))
		var bbs := Basis(Vector3.UP, rng.randf() * TAU)
		bb.box(bench, Vector3(1.7, 0.07, 0.45), bp + Vector3(0, 0.45, 0), bbs)
		bb.box(bench, Vector3(1.7, 0.42, 0.07), bp + bbs * Vector3(0, 0.72, -0.24), bbs)
		bb.box(bench_leg, Vector3(0.08, 0.42, 0.4), bp + bbs * Vector3(-0.7, 0.21, 0), bbs)
		bb.box(bench_leg, Vector3(0.08, 0.42, 0.4), bp + bbs * Vector3(0.7, 0.21, 0), bbs)

func _plaza(i: int, j: int) -> void:
	var c := _slab(i, j, Color(0.12, 0.11, 0.14))
	# Monument: stone step, neon ring plinth, glowing column, halo tori.
	var stone := _mat(Color(0.16, 0.15, 0.19))
	_static_box(self, Vector3(9.0, 0.3, 9.0), c + Vector3(0, CURB_H + 0.15, 0), stone)
	var ring := _mat(Color(0.08, 0.08, 0.1), Color(1.0, 0.18, 0.58), 3.0)
	_static_box(self, Vector3(6.0, 0.5, 6.0), c + Vector3(0, CURB_H + 0.25, 0), ring)
	var glow := _mat(Color(0.05, 0.05, 0.08), Color(0.14, 0.9, 1.0), 4.0)
	_static_box(self, Vector3(2.2, 9.0, 2.2), c + Vector3(0, CURB_H + 4.5, 0), glow)
	var halo_mat := _mat(Color(0.05, 0.05, 0.07), Color(1.0, 0.18, 0.58), 3.4)
	for hy: float in [3.2, 5.6, 8.0]:
		var halo := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 1.9
		torus.outer_radius = 2.15
		torus.material = halo_mat
		halo.mesh = torus
		halo.position = c + Vector3(0, CURB_H + hy, 0)
		add_child(halo)
	# Rotating holographic welcome sign above the monument.
	holo = Node3D.new()
	holo.position = c + Vector3(0, CURB_H + 12.0, 0)
	add_child(holo)
	for side: float in [0.0, PI]:
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
	# Corrugation ribs, loading door and roof vents sell the shed.
	var rib := _mat(Color(0.09, 0.07, 0.055))
	var x := -12.0
	while x <= 12.0:
		bb.box(rib, Vector3(0.18, h - 0.6, 0.14), c + Vector3(x, CURB_H + h / 2.0, 10.05))
		bb.box(rib, Vector3(0.18, h - 0.6, 0.14), c + Vector3(x, CURB_H + h / 2.0, -10.05))
		x += 2.0
	var door := _mat(Color(0.16, 0.13, 0.10))
	bb.box(door, Vector3(5.0, 4.2, 0.18), c + Vector3(-6.0, CURB_H + 2.1, 10.08))
	bb.box(rib, Vector3(5.4, 0.3, 0.3), c + Vector3(-6.0, CURB_H + 4.4, 10.1))
	var vent := _mat(Color(0.17, 0.17, 0.19))
	for vx: float in [-8.0, 0.0, 8.0]:
		bb.cyl(vent, 0.45, 0.55, 1.0, c + Vector3(vx, CURB_H + h + 0.5, -4.0), 8)
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
	# Proper cobra-head lights: pole, an arm reaching over the road, the
	# luminaire at the arm tip, and a fake light cone under it.
	var head_mat := _mat(Color(0.2, 0.2, 0.18), Color(1.0, 0.85, 0.55), 2.6)
	for corner: Vector3 in [Vector3(-1, 0, -1), Vector3(1, 0, 1)]:
		var p := c + corner * (SLAB / 2.0 - 0.8)
		var dirh := Vector3(corner.x, 0, corner.z).normalized()
		var yaw := atan2(dirh.x, dirh.z)
		pole_transforms.append(Transform3D(Basis.IDENTITY, p + Vector3(0, CURB_H + 2.5, 0)))
		arm_transforms.append(Transform3D(Basis(Vector3.UP, yaw), p + dirh * 0.75 + Vector3(0, CURB_H + 5.0, 0)))
		bb.box(head_mat, Vector3(0.5, 0.16, 0.7), p + dirh * 1.5 + Vector3(0, CURB_H + 4.95, 0), Basis(Vector3.UP, yaw))
		if light_budget > 0 and rng.randf() < 0.55:
			light_budget -= 1
			var lamp := OmniLight3D.new()
			lamp.light_color = Color(1.0, 0.83, 0.55)
			lamp.light_energy = 1.6
			lamp.omni_range = 14.0
			lamp.position = p + dirh * 1.4 + Vector3(0, CURB_H + 4.6, 0)
			lamp.distance_fade_enabled = true
			lamp.distance_fade_begin = 120.0
			add_child(lamp)
			# Fake volumetric cone under the luminaire (instanced later).
			cone_transforms.append(Transform3D(Basis.IDENTITY, p + dirh * 1.4 + Vector3(0, CURB_H + 2.8, 0)))

func _parked_cars() -> void:
	var car_script := preload("res://scripts/Car.gd")
	# Guaranteed starter car right next to the spawn plaza.
	var center := N / 2
	var c := block_center(center, center)
	# Parked parallel to the curb, nose pointing with the nearest lane.
	var spots: Array = [[c + Vector3(8.0, 0.0, SLAB / 2.0 + 3.2), -PI / 2.0, "sedan"]]
	for n in 26:
		var bi := rng.randi_range(0, N - 1)
		var bj := rng.randi_range(0, N - 1)
		var bc := block_center(bi, bj)
		var side := rng.randi_range(0, 3)
		var kind := "sports" if rng.randf() < 0.18 else "sedan"
		match side:
			0: spots.append([bc + Vector3(rng.randf_range(-12, 12), 0, SLAB / 2.0 + 3.2), -PI / 2.0, kind])
			1: spots.append([bc + Vector3(rng.randf_range(-12, 12), 0, -SLAB / 2.0 - 3.2), PI / 2.0, kind])
			2: spots.append([bc + Vector3(SLAB / 2.0 + 3.2, 0, rng.randf_range(-12, 12)), 0.0, kind])
			3: spots.append([bc + Vector3(-SLAB / 2.0 - 3.2, 0, rng.randf_range(-12, 12)), PI, kind])
	for s in spots:
		var car: VehicleBody3D = car_script.new()
		car.setup(s[2], CAR_COLORS[rng.randi_range(0, CAR_COLORS.size() - 1)])
		car.position = s[0] + Vector3(0, 0.7, 0)
		car.rotation.y = s[1]
		add_child(car)

func _boats_and_helis() -> void:
	# Speedboats moored along the promenade.
	var half := N * PITCH / 2.0
	for x: float in [line(3), line(5) + 12.0, line(8)]:
		var boat := Boat.new()
		boat.setup("boat", Color(0.9, 0.9, 0.94))
		boat.position = Vector3(x, -0.4, half + 12.0)
		boat.rotation.y = PI
		add_child(boat)
		add_blip(boat, Color(0.3, 0.8, 1.0), 2.4)
	# One helicopter on the warehouse roof, one on a dock helipad.
	var pad_mat := _mat(Color(0.14, 0.14, 0.16))
	var ring_mat := _mat(Color(0.05, 0.05, 0.06), Color(1.0, 0.85, 0.2), 2.2)
	var dock_pad := Vector3(line(9), 0.0, half - 14.0)
	bb.box(pad_mat, Vector3(10.0, 0.3, 10.0), dock_pad + Vector3(0, 0.15, 0))
	bb.box(ring_mat, Vector3(7.0, 0.06, 0.5), dock_pad + Vector3(0, 0.34, 3.0))
	bb.box(ring_mat, Vector3(7.0, 0.06, 0.5), dock_pad + Vector3(0, 0.34, -3.0))
	bb.box(ring_mat, Vector3(0.5, 0.06, 6.5), dock_pad + Vector3(0, 0.34, 0))
	for spot: Vector3 in [warehouse_roof + Vector3(-4.0, -0.6, -3.0), dock_pad + Vector3(0, 0.5, 0)]:
		var heli := Heli.new()
		heli.setup("heli", Color(0.95, 0.55, 0.1))
		heli.position = spot
		add_child(heli)
		add_blip(heli, Color(1.0, 0.6, 0.1), 2.8)

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
	# Neon edge rails so the lip reads at speed in the dark.
	_box(holder, Vector3(0.14, 0.34, 12.0), Vector3(-3.45, 0.3, 0), stripe)
	_box(holder, Vector3(0.14, 0.34, 12.0), Vector3(3.45, 0.3, 0), stripe)

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
	# Monorail circles the city forever.
	train_t += delta * 16.0
	for i in train_cars.size():
		var car: Node3D = train_cars[i]
		var p := train_t - float(i) * 8.6
		var pos := _rail_pos(p)
		var dir := _rail_pos(p + 2.0) - pos
		car.position = pos
		if dir.length() > 0.01:
			car.rotation.y = atan2(-dir.x, -dir.z)
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

func _commit_batches() -> void:
	bb.commit(self)
	# Streetlight poles, one instanced draw.
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.07
	pole_mesh.bottom_radius = 0.1
	pole_mesh.height = 5.0
	pole_mesh.material = _mat(Color(0.15, 0.15, 0.17))
	_multi(pole_mesh, pole_transforms)
	# Streetlight arms, one instanced draw.
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.11, 0.11, 1.7)
	arm_mesh.material = _mat(Color(0.15, 0.15, 0.17))
	_multi(arm_mesh, arm_transforms)
	# Lamp light cones, one instanced draw.
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.12
	cone_mesh.bottom_radius = 2.3
	cone_mesh.height = 4.6
	var conem := StandardMaterial3D.new()
	conem.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	conem.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	conem.albedo_color = Color(1.0, 0.85, 0.55, 0.06)
	conem.emission_enabled = true
	conem.emission = Color(1.0, 0.85, 0.55)
	conem.emission_energy_multiplier = 0.3
	conem.cull_mode = BaseMaterial3D.CULL_DISABLED
	cone_mesh.material = conem
	_multi(cone_mesh, cone_transforms)

func _multi(mesh: Mesh, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	add_child(inst)

func _spray_shops() -> void:
	# Pay N Spray: drive in hot, drive out invisible (for a fee).
	var spots := [
		Vector3(line(1) + 5.0, 0, line(2) + 5.0),
		Vector3(line(9) - 5.0, 0, line(8) - 5.0),
		Vector3(line(5) + 5.0, 0, line(9) - 5.0),
	]
	var ring_mat := _mat(Color(0.05, 0.05, 0.07), Color(1.0, 0.18, 0.58), 3.2)
	for s: Vector3 in spots:
		spray_points.append(s)
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 4.2
		torus.outer_radius = 4.8
		torus.material = ring_mat
		ring.mesh = torus
		ring.position = s + Vector3(0, 0.3, 0)
		add_child(ring)
		var label := Label3D.new()
		label.text = "PAY N SPRAY  $300"
		label.font_size = 96
		label.pixel_size = 0.012
		label.modulate = Color(1.6, 0.4, 1.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = s + Vector3(0, 6.5, 0)
		add_child(label)
		CityGen.add_blip(ring, Color(1.0, 0.18, 0.58), 2.4)

func _monorail() -> void:
	# Elevated monorail loop above the outer ring road.
	var beam_mat := _mat(Color(0.1, 0.1, 0.14), Color(0.14, 0.9, 1.0), 0.8)
	var half := N * PITCH / 2.0
	var y := 11.0
	bb.box(beam_mat, Vector3(half * 2.0 + 2.0, 0.5, 1.2), Vector3(0, y, -half))
	bb.box(beam_mat, Vector3(half * 2.0 + 2.0, 0.5, 1.2), Vector3(0, y, half))
	bb.box(beam_mat, Vector3(1.2, 0.5, half * 2.0 + 2.0), Vector3(-half, y, 0))
	bb.box(beam_mat, Vector3(1.2, 0.5, half * 2.0 + 2.0), Vector3(half, y, 0))
	var pillar_mat := _mat(Color(0.12, 0.12, 0.15))
	var k := -half
	while k <= half:
		# Tapered pillars with a wide foot read better than plain posts.
		for pp: Vector3 in [Vector3(k, 0, -half), Vector3(k, 0, half), Vector3(-half, 0, k), Vector3(half, 0, k)]:
			bb.box(pillar_mat, Vector3(0.8, y, 0.8), pp + Vector3(0, y / 2.0, 0))
			bb.box(pillar_mat, Vector3(1.6, 0.5, 1.6), pp + Vector3(0, 0.25, 0))
			bb.box(pillar_mat, Vector3(1.5, 0.4, 1.8), pp + Vector3(0, y - 0.45, 0))
		k += 48.0
	_build_train()

func _build_train() -> void:
	# Sleeker consist: skirted shell, rounded roof line, door seams,
	# glowing window band, wedge nose with a headlight, red tail.
	var shell := _mat(Color(0.82, 0.85, 0.92))
	shell.metallic = 0.55
	shell.roughness = 0.35
	var win := _mat(Color(0.05, 0.08, 0.1), Color(0.9, 0.95, 1.0), 1.8)
	var nose := _mat(Color(0.1, 0.1, 0.12), Color(0.14, 0.9, 1.0), 2.5)
	var dark := _mat(Color(0.10, 0.10, 0.12))
	var tail := _mat(Color(0.15, 0.03, 0.03), Color(1.0, 0.1, 0.1), 3.0)
	for i in 3:
		var car := Node3D.new()
		add_child(car)
		_box(car, Vector3(2.2, 1.7, 7.0), Vector3(0, 1.25, 0), shell)
		_box(car, Vector3(2.0, 0.28, 6.6), Vector3(0, 2.2, 0), dark)       # roof cap
		_box(car, Vector3(2.3, 0.35, 7.0), Vector3(0, 0.42, 0), dark)      # underskirt
		_box(car, Vector3(2.26, 0.6, 5.8), Vector3(0, 1.55, 0), win)       # window band
		for dz: float in [-1.8, 1.8]:
			_box(car, Vector3(2.24, 1.2, 0.07), Vector3(0, 1.1, dz), dark)  # door seams
		for dz: float in [-2.6, 2.6]:
			_box(car, Vector3(1.6, 0.35, 0.9), Vector3(0, 0.25, dz), dark)  # bogies
		if i == 0:
			var wedge := MeshBatch.new()
			wedge.wedge(shell, Vector3(2.2, 1.4, 1.0), Vector3(0, 1.1, -3.9), Basis(Vector3.UP, PI))
			wedge.commit(car)
			_box(car, Vector3(1.6, 0.32, 0.16), Vector3(0, 0.85, -4.32), nose)
		if i == 2:
			_box(car, Vector3(1.6, 0.25, 0.12), Vector3(0, 1.0, 3.55), tail)
		train_cars.append(car)

func _rail_pos(p: float) -> Vector3:
	var half := N * PITCH / 2.0
	var l := half * 2.0
	p = fposmod(p, 4.0 * l)
	var edge := int(p / l)
	var t := p - edge * l
	match edge:
		0: return Vector3(-half + t, 11.4, -half)
		1: return Vector3(half, 11.4, -half + t)
		2: return Vector3(half - t, 11.4, half)
		_: return Vector3(-half, 11.4, half - t)

# ------------------------------------------------------------ helpers

func _make_building_mats() -> void:
	# Facade variety: cool glass, warm concrete, brick — each with its own
	# window pattern baked into an emission texture.
	var facade_tints := [
		Color(0.05, 0.055, 0.085), Color(0.065, 0.06, 0.052), Color(0.085, 0.05, 0.045),
		Color(0.045, 0.05, 0.07), Color(0.06, 0.065, 0.08), Color(0.07, 0.055, 0.06),
		Color(0.05, 0.06, 0.065), Color(0.055, 0.05, 0.08),
	]
	for v in 8:
		var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
		img.fill(Color(0.01, 0.01, 0.02))
		var warm := rng.randf() < 0.5
		if v % 3 == 2:
			# Office towers: thin lit strips on some floors, kept dim so
			# they read as windows rather than painted stripes.
			for cy in range(0, 32, 4):
				if rng.randf() < 0.3:
					var bb2 := rng.randf_range(0.18, 0.34)
					var bc := Color(bb2, bb2 * 0.9, bb2 * 0.72) if warm else Color(bb2 * 0.65, bb2 * 0.85, bb2)
					for px in 32:
						if px % 5 != 0:
							img.set_pixel(px, cy + 2, bc)
		else:
			for cy in range(0, 32, 4):
				for cx in range(0, 32, 4):
					if rng.randf() < 0.42:
						var b := rng.randf_range(0.5, 1.0)
						# Occasional odd-colored window: a TV left on.
						var col := Color(b, b * 0.85, b * 0.6) if warm else Color(b * 0.7, b * 0.9, b)
						if rng.randf() < 0.04:
							col = Color(b * 0.5, b * 0.9, b * 0.7)
						for px in 2:
							for py in 2:
								img.set_pixel(cx + 1 + px, cy + 1 + py, col)
		var tex := ImageTexture.create_from_image(img)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = facade_tints[v]
		mat.roughness = rng.randf_range(0.55, 0.85)
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
	# Cached: identical look = identical material instance, so MeshBatch
	# can merge everything that shares it into one surface.
	var key := "%s|%s|%.2f" % [albedo.to_html(), emiss.to_html(), energy]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emiss
		m.emission_energy_multiplier = energy
	_mat_cache[key] = m
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
	# Collision is its own node; the visual goes into the merged batch.
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	parent.add_child(body)
	bb.box(mat, size, pos)
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
