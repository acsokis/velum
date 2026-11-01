extends SceneTree

func _initialize():
	call_deferred("run")
func run():
	var game = load("res://main.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false);game.set_process(false)
	var reversed_faces = 0
	var solid_meshes = 0
	var ramp_meshes = 0
	var checked_faces = 0
	var save_positions_match = true
	var negative_scale_meshes = 0
	var nodes: Array[Node] = [game]
	while not nodes.is_empty():
		var node = nodes.pop_back()
		if node is MeshInstance3D and node.transform.basis.determinant() <= 0:
			negative_scale_meshes += 1
		if node is MeshInstance3D and node.has_meta("pcb_solid"): solid_meshes += 1
		if node is MeshInstance3D and node.has_meta("pcb_ramp"): ramp_meshes += 1
		if node is MeshInstance3D and node.mesh != null and (node.has_meta("pcb_solid") or node.has_meta("pcb_ramp") or node.has_meta("pcb_merged")):
			var arrays = node.mesh.surface_get_arrays(0)
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for i in range(0,indices.size(),3):
				var a = vertices[indices[i]]
				var b = vertices[indices[i+1]]
				var c = vertices[indices[i+2]]
				var face = (c-a).cross(b-a)
				if face.length_squared() < 0.00000001: continue
				var normal = normals[indices[i]]+normals[indices[i+1]]+normals[indices[i+2]]
				if face.dot(normal) <= 0: reversed_faces += 1
				checked_faces += 1
		for child in node.get_children(): nodes.append(child)
	if FileAccess.file_exists("res://runtime/smoke-save.json"):
		var saved = JSON.parse_string(FileAccess.get_file_as_string("res://runtime/smoke-save.json"))
		for r in saved.resources:
			var current = game.resources[int(r.id)].node.position
			if absf(current.x-r.x)>0.001 or absf(current.z-r.z)>0.001:
				save_positions_match = false
	print("PCB_GEOMETRY_AUDIT solid_meshes=%d ramps=%d faces=%d reversed_faces=%d saved_xz_match=%s negative_scale_meshes=%d" % [solid_meshes,ramp_meshes,checked_faces,reversed_faces,save_positions_match,negative_scale_meshes])
	game.free()
	quit(0 if solid_meshes > 40 and ramp_meshes == 7 and checked_faces > 800 and reversed_faces == 0 and save_positions_match and negative_scale_meshes == 0 else 1)
