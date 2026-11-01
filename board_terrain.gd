extends RefCounted
## Walkable overlapping PCB slabs, not a displaced heightfield.
const VERSION = 2
var plates: Array[Dictionary] = []
var ramps: Array[Dictionary] = []
var seed_value = 0
var spatial_plates: Dictionary = {}
var shared_surface: ShaderMaterial

func configure(seed_number: int):
	seed_value = seed_number
	plates.clear(); ramps.clear()
	var r = RandomNumberGenerator.new()
	r.seed = seed_number ^ 0xB04D
	plates.append({"center":Vector2.ZERO,"size":Vector2(240,240),"top":0.0,"thickness":1.0,"yaw":0.0,"layer":0})
	var stacks = [
		[Vector2(0,0),Vector2(44,46),1,0.0],
		[Vector2(-36,-24),Vector2(42,46),3,0.0],
		[Vector2(32,-20),Vector2(38,46),4,0.0],
		[Vector2(0,-53),Vector2(50,34),6,0.0],
		[Vector2(52,-59),Vector2(45,43),8,0.0],
		[Vector2(-60,-62),Vector2(46,42),9,0.0],
		[Vector2(6,50),Vector2(50,42),2,0.0],
		[Vector2(-75,36),Vector2(43,36),5,0.10],
		[Vector2(65,38),Vector2(44,36),4,-0.13],
		[Vector2(-25,-95),Vector2(42,29),7,0.08],
		[Vector2(85,-15),Vector2(34,35),3,-0.12],
		[Vector2(-89,-13),Vector2(36,31),4,0.06]
	]
	for stack in stacks:
		for i in range(stack[2]):
			var top_layer = i == stack[2]-1
			var shift = Vector2.ZERO if top_layer else Vector2(r.randf_range(-0.35,0.35),r.randf_range(-0.35,0.35))
			var angle = float(stack[3])+(0.0 if top_layer else r.randf_range(-0.018,0.018))
			plates.append({"center":stack[0]+shift,"size":stack[1],"top":(i+1)*0.75,"thickness":0.75,"yaw":angle,"layer":i+1})
	add_ramp(Vector3(-29,0,6),Vector3(-22.5,0.75,6),5)
	add_ramp(Vector3(-6,0.75,-16),Vector3(-14.5,2.25,-16),5)
	add_ramp(Vector3(4,0.75,-8),Vector3(12.5,3.0,-8),5)
	add_ramp(Vector3(0,0.75,-16),Vector3(0,4.5,-35.5),6)
	add_ramp(Vector3(16,4.5,-53),Vector3(29,6.0,-53),5)
	add_ramp(Vector3(-43,2.25,-28),Vector3(-43,6.75,-40.5),5)
	add_ramp(Vector3(6,0.75,15),Vector3(6,1.5,28.5),5)
	build_spatial_index()

func build_spatial_index():
	spatial_plates.clear()
	for index in range(plates.size()):
		var plate = plates[index]
		var half: Vector2 = plate.size*0.5
		var extent = Vector2(absf(cos(plate.yaw))*half.x+absf(sin(plate.yaw))*half.y,absf(sin(plate.yaw))*half.x+absf(cos(plate.yaw))*half.y)
		var first = Vector2i(floori((plate.center.x-extent.x)/16),floori((plate.center.y-extent.y)/16))
		var last = Vector2i(floori((plate.center.x+extent.x)/16),floori((plate.center.y+extent.y)/16))
		for x in range(first.x,last.x+1):
			for z in range(first.y,last.y+1):
				var key = Vector2i(x,z)
				if not spatial_plates.has(key): spatial_plates[key] = []
				spatial_plates[key].append(index)

func add_ramp(a: Vector3,b: Vector3,width: float):
	ramps.append({"a":a,"b":b,"width":width,"lip":1.8})

func map_snapshot() -> Array:
	var result = []
	for p in plates:
		result.append({"x":p.center.x,"z":p.center.y,"w":p.size.x,"d":p.size.y,"h":p.top,"yaw":p.yaw})
	return result

func height_at(x: float,z: float) -> float:
	var p = Vector2(x,z)
	var height = 0.0
	for index in spatial_plates.get(Vector2i(floori(x/16),floori(z/16)),[]):
		var plate = plates[index]
		var q = (p-plate.center).rotated(plate.yaw)
		if absf(q.x) <= plate.size.x*0.5 and absf(q.y) <= plate.size.y*0.5:
			height = maxf(height,plate.top)
	for ramp in ramps:
		var a = Vector2(ramp.a.x,ramp.a.z)
		var delta = Vector2(ramp.b.x-ramp.a.x,ramp.b.z-ramp.a.z)
		var along = (p-a).dot(delta.normalized())
		var across = absf((p-a).cross(delta.normalized()))
		if along >= 0 and along <= delta.length()+ramp.lip and across <= ramp.width*0.5:
			height = maxf(height,lerpf(ramp.a.y,ramp.b.y,clampf(along/delta.length(),0,1))+0.045)
	return height

func surface_material(shader: Shader, index: int) -> ShaderMaterial:
	if shared_surface != null: return shared_surface
	var material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("board_offset",Vector2(posmod(seed_value-714219,997),posmod(seed_value-714219,991)))
	shared_surface = material
	return material

func make_box(parent: Node3D,name_value: String,size: Vector3,pos: Vector3,yaw: float,material: Material) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	n.name = name_value
	var mesh = BoxMesh.new(); mesh.size = size
	n.mesh = mesh; n.material_override = material
	n.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	n.position = pos; n.rotation.y = yaw
	n.set_meta("pcb_solid",true)
	parent.add_child(n)
	var body = StaticBody3D.new()
	n.add_child(body)
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new(); box.size = size
	shape.shape = box; body.add_child(shape)
	return n

func build(parent: Node3D):
	var shader = Shader.new()
	shader.code = FileAccess.get_file_as_string("res://shaders/pcb_ground.gdshader")
	for i in range(plates.size()):
		var p = plates[i]
		make_box(parent,"SurveyTerrain" if i == 0 else "PCBSlab_%02d" % i,
			Vector3(p.size.x,p.thickness,p.size.y),Vector3(p.center.x,p.top-p.thickness*0.5,p.center.y),p.yaw,surface_material(shader,i))
	for i in range(ramps.size()):
		build_ramp(parent,ramps[i],shader,i)
	var combined = SurfaceTool.new();combined.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parent.get_children():
		if part is MeshInstance3D and (part.has_meta("pcb_solid") or part.has_meta("pcb_ramp")):
			combined.append_from(part.mesh,0,part.transform)
			part.mesh = null # Keep each physical collider and its stable transform.
	combined.index()
	var merged = MeshInstance3D.new();merged.name = "ConnectedTerrainSurface";merged.mesh = combined.commit()
	merged.material_override = shared_surface;merged.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	merged.set_meta("pcb_merged",true);parent.add_child(merged)

func triangle(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,normal: Vector3):
	if (c-a).cross(b-a).dot(normal) < 0:
		var swap = b; b = c; c = swap
	for p in [a,b,c]:
		st.set_normal(normal); st.set_uv(Vector2(p.x,p.z)/12.0); st.add_vertex(p)

func build_ramp(parent: Node3D,r: Dictionary,shader: Shader,index: int):
	var a: Vector3 = r.a+Vector3.UP*0.045
	var b: Vector3 = r.b+Vector3.UP*0.045
	var forward = Vector3(b.x-a.x,0,b.z-a.z).normalized()
	var side = forward.cross(Vector3.UP)*r.width*0.5
	var v = [a-side,a+side,b+side,b-side]
	for i in range(4): v.append(Vector3(v[i].x,a.y-0.20,v[i].z))
	var slope = (b.y-a.y)/Vector2(b.x-a.x,b.z-a.z).length()
	var up = Vector3(-forward.x*slope,1,-forward.z*slope).normalized()
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	triangle(st,v[0],v[1],v[2],up); triangle(st,v[0],v[2],v[3],up)
	triangle(st,v[4],v[6],v[5],Vector3.DOWN); triangle(st,v[4],v[7],v[6],Vector3.DOWN)
	for i in range(4):
		var j = (i+1)%4
		var normal = Vector3((v[i]+v[j]).x-(a+b).x,(0.0),(v[i]+v[j]).z-(a+b).z).normalized()
		if normal.length() < 0.1: normal = -forward
		triangle(st,v[i],v[j],v[j+4],normal); triangle(st,v[i],v[j+4],v[i+4],normal)
	st.index(); st.generate_tangents()
	var mesh = MeshInstance3D.new()
	mesh.name = "PCBBridge_%02d" % index
	mesh.mesh = st.commit(); mesh.material_override = surface_material(shader,100+index)
	mesh.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	mesh.set_meta("pcb_ramp",true)
	parent.add_child(mesh)
	var body = StaticBody3D.new(); mesh.add_child(body)
	var collision = CollisionShape3D.new()
	var shape = ConvexPolygonShape3D.new(); shape.points = PackedVector3Array(v)
	collision.shape = shape; body.add_child(collision)
	make_box(parent,"PCBBridgeLip_%02d" % index,Vector3(r.width,0.20,r.lip+0.1),
		b+forward*r.lip*0.5-Vector3.UP*0.10,atan2(-forward.x,-forward.z),surface_material(shader,200+index))
