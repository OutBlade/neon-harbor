class_name MeshBatch
extends RefCounted
## Merges hundreds of static primitives into one mesh per material.
## This is the difference between ~2500 draw calls and ~30.
## Supports boxes (with arbitrary rotation), wedges (ramps) and
## cylinders/cones. Triangle winding is auto-oriented against the face
## normal, so emitted faces can never come out inside-out.

var _groups: Dictionary = {}

func box(mat: Material, size: Vector3, pos: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	_push(mat, ["box", size, pos, basis])

func wedge(mat: Material, size: Vector3, pos: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	# Ramp: full height along the local -Z edge, sloping to zero at +Z.
	_push(mat, ["wedge", size, pos, basis])

func cyl(mat: Material, r_top: float, r_bot: float, h: float, pos: Vector3, segments: int = 10) -> void:
	_push(mat, ["cyl", Vector3(r_top, h, r_bot), pos, segments])

func _push(mat: Material, entry: Array) -> void:
	if not _groups.has(mat):
		_groups[mat] = []
	_groups[mat].append(entry)

func commit(parent: Node3D) -> void:
	for mat in _groups:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for entry in _groups[mat]:
			match entry[0]:
				"box":
					_emit_box(st, entry[1], entry[2], entry[3])
				"wedge":
					_emit_wedge(st, entry[1], entry[2], entry[3])
				"cyl":
					_emit_cyl(st, entry[1], entry[2], entry[3])
		var mesh := st.commit()
		mesh.surface_set_material(0, mat)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		parent.add_child(mi)
	_groups.clear()

static func _tri(st: SurfaceTool, n: Vector3, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Godot front faces wind clockwise as seen from the normal side, i.e.
	# the geometric cross product of a clockwise triangle points AWAY from
	# the viewer. Flip the emitted order if it disagrees with n.
	if (b - a).cross(c - a).dot(n) > 0.0:
		var tmp := b
		b = c
		c = tmp
	st.set_normal(n)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

static func _quad(st: SurfaceTool, n: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, p4: Vector3) -> void:
	_tri(st, n, p1, p2, p3)
	_tri(st, n, p1, p3, p4)

static func _emit_box(st: SurfaceTool, size: Vector3, pos: Vector3, basis: Basis) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK],
		[Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT],
		[Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT],
		[Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]
	for f in faces:
		var n: Vector3 = (basis * f[0]).normalized()
		var u: Vector3 = (f[1] as Vector3) * h
		var v: Vector3 = (f[2] as Vector3) * h
		var c: Vector3 = (f[0] as Vector3) * h
		var p1 := pos + basis * (c - u - v)
		var p2 := pos + basis * (c + u - v)
		var p3 := pos + basis * (c + u + v)
		var p4 := pos + basis * (c - u + v)
		_quad(st, n, p1, p2, p3, p4)

static func _emit_wedge(st: SurfaceTool, size: Vector3, pos: Vector3, basis: Basis) -> void:
	# Local shape: rectangular footprint, full height along the -Z edge,
	# sloping down to the floor at +Z. Ridge runs along X.
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var b1 := Vector3(-hx, -hy, -hz)
	var b2 := Vector3(hx, -hy, -hz)
	var b3 := Vector3(hx, -hy, hz)
	var b4 := Vector3(-hx, -hy, hz)
	var t1 := Vector3(-hx, hy, -hz)
	var t2 := Vector3(hx, hy, -hz)
	var slope_n := (basis * Vector3(0, size.z, size.y)).normalized()
	var w: Array[Vector3] = []
	for p: Vector3 in [b1, b2, b3, b4, t1, t2]:
		w.append(pos + basis * p)
	_quad(st, (basis * Vector3.DOWN).normalized(), w[0], w[1], w[2], w[3])     # base
	_quad(st, (basis * Vector3.FORWARD).normalized(), w[0], w[1], w[5], w[4])  # back wall (-z)
	_quad(st, slope_n, w[4], w[5], w[2], w[3])                                  # slope
	_tri(st, (basis * Vector3.LEFT).normalized(), w[0], w[3], w[4])             # side -x
	_tri(st, (basis * Vector3.RIGHT).normalized(), w[1], w[2], w[5])            # side +x

static func _emit_cyl(st: SurfaceTool, dims: Vector3, pos: Vector3, segments: int) -> void:
	var rt := dims.x
	var rb := dims.z
	var hh := dims.y * 0.5
	var seg := maxi(segments, 5)
	for i in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var bt0 := pos + d0 * rb + Vector3(0, -hh, 0)
		var bt1 := pos + d1 * rb + Vector3(0, -hh, 0)
		var tt0 := pos + d0 * rt + Vector3(0, hh, 0)
		var tt1 := pos + d1 * rt + Vector3(0, hh, 0)
		var mid := (d0 + d1).normalized()
		# Side normal accounts for taper (cones lean it upward).
		var n := Vector3(mid.x * dims.y, rb - rt, mid.z * dims.y).normalized()
		_quad(st, n, bt0, bt1, tt1, tt0)
		if rt > 0.001:
			_tri(st, Vector3.UP, pos + Vector3(0, hh, 0), tt0, tt1)
		if rb > 0.001:
			_tri(st, Vector3.DOWN, pos + Vector3(0, -hh, 0), bt0, bt1)
