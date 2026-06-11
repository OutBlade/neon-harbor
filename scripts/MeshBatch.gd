class_name MeshBatch
extends RefCounted
## Merges hundreds of static boxes into one mesh per material.
## This is the difference between ~2500 draw calls and ~30.

var _groups: Dictionary = {}

func box(mat: Material, size: Vector3, pos: Vector3) -> void:
	if not _groups.has(mat):
		_groups[mat] = []
	_groups[mat].append([size, pos])

func commit(parent: Node3D) -> void:
	for mat in _groups:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for entry in _groups[mat]:
			_emit_box(st, entry[0], entry[1])
		var mesh := st.commit()
		mesh.surface_set_material(0, mat)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		parent.add_child(mi)
	_groups.clear()

static func _emit_box(st: SurfaceTool, size: Vector3, pos: Vector3) -> void:
	var h := size * 0.5
	# normal, tangent u, tangent v for each face.
	var faces := [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK],
		[Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT],
		[Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT],
		[Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var c := pos + n * h
		var uu: Vector3 = u * h
		var vv: Vector3 = v * h
		var p1 := c - uu - vv
		var p2 := c + uu - vv
		var p3 := c + uu + vv
		var p4 := c - uu + vv
		st.set_normal(n)
		# Godot front faces wind clockwise.
		st.add_vertex(p1)
		st.add_vertex(p3)
		st.add_vertex(p2)
		st.set_normal(n)
		st.add_vertex(p1)
		st.add_vertex(p4)
		st.add_vertex(p3)
