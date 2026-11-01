extends RefCounted
## Cosmetic, seeded server-case ecology. Never advances the gameplay RNG.
var host: Node3D
var root: Node3D
var art_rng = RandomNumberGenerator.new()
var plants: Array[Dictionary] = []
var props: Array[Node3D] = []
var batch_count = 0
var batched_sources = 0
var plastic: StandardMaterial3D
var copper: StandardMaterial3D
var alloy: StandardMaterial3D
var solder: StandardMaterial3D
var oxide: StandardMaterial3D
var web_material: StandardMaterial3D
var label_material: StandardMaterial3D

func setup(parent: Node3D):
	host = parent
	art_rng.seed = 714219 ^ 0x5E4B
	root = Node3D.new()
	root.name = "ServerInteriorArt"
	host.add_child(root)
	plastic = material(Color("171d19"),0.78,0.10)
	copper = material(Color("9c6939"),0.54,0.68)
	alloy = material(Color("96998a"),0.62,0.70)
	solder = material(Color("767a69"),0.48,0.75)
	oxide = material(Color("294a3d"),0.85,0.18)
	web_material = material(Color(0.64,0.61,0.46,0.32),1.0,0.0)
	web_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	web_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	label_material = material(Color("a5ac98"),1,0)
	label_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	label_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	label_material.albedo_texture = component_label_texture()
	label_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

func component_label_texture() -> ImageTexture:
	var glyphs = {
		"V":["10001","10001","10001","10001","10001","01010","00100"],
		"L":["10000","10000","10000","10000","10000","10000","11111"],
		"M":["10001","11011","10101","10101","10001","10001","10001"],
		"7":["11111","00001","00010","00100","01000","01000","01000"],
		"1":["00100","01100","00100","00100","00100","00100","01110"],
		"4":["00010","00110","01010","10010","11111","00010","00010"],
		"G":["01110","10001","10000","10111","10001","10001","01110"],
		"S":["01111","10000","10000","01110","00001","00001","11110"],
		"D":["11110","10001","10001","10001","10001","10001","11110"],
		"-":["00000","00000","00000","11111","00000","00000","00000"]}
	var image = Image.create(128,64,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
	for line in [["VLM-714",23,10],["G S D",35,36]]:
		var text: String = line[0]
		for i in range(text.length()):
			if not glyphs.has(text[i]): continue
			for y in range(7):
				for x in range(5):
					if glyphs[text[i]][y][x] == "1":
						for yy in range(2):
							for xx in range(2): image.set_pixel(line[1]+i*12+x*2+xx,line[2]+y*2+yy,Color.WHITE)
	return ImageTexture.create_from_image(image)

func material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

func box(parent: Node3D, pos: Vector3, size: Vector3, m: Material) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	return host.mesh_at(parent,mesh,pos,Vector3.ONE,m)

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, m: Material) -> MeshInstance3D:
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	return host.mesh_at(parent,mesh,pos,Vector3.ONE,m)

func lead(parent: Node3D, a: Vector3, b: Vector3, radius: float, m: Material):
	var delta = b-a
	if delta.length() < 0.001: return
	var n = cylinder(parent,(a+b)*0.5,radius,delta.length(),m)
	n.basis = Basis(Quaternion(Vector3.UP,delta.normalized()))

func supported_position(position: Vector3, radius: float) -> Vector3:
	# Reserve a level footprint; contacts should meet a board instead of cutting a cliff.
	for ring in range(15):
		for direction in range(8 if ring > 0 else 1):
			var angle = direction*TAU/8
			var p = position+Vector3(cos(angle),0,sin(angle))*ring
			var height: float = host.height_at(p.x,p.z)
			var supported = true
			for side in range(8):
				var a = side*TAU/8
				if absf(host.height_at(p.x+cos(a)*radius,p.z+sin(a)*radius)-height) > 0.12: supported = false;break
			if supported: return Vector3(p.x,height,p.z)
	return Vector3(position.x,host.height_at(position.x,position.z),position.z)

func transistor_tree(pos: Vector3, height: float):
	pos = supported_position(pos,3.8)
	var tree = Node3D.new()
	tree.name = "TransistorTree"
	root.add_child(tree)
	tree.position = pos
	plants.append({"node":tree,"energy":0.35,"received":0,"support_radius":3.8})
	var crown_y = height * 0.70
	var width = clampf(height * 0.28,1.4,3.4)
	var body_h = height * 0.27
	var rain_shape = BoxShape3D.new();rain_shape.size = Vector3(width,body_h,0.70)
	rain_collider(tree,Vector3(0,crown_y,0),rain_shape)
	# Three articulated copper leads grow out of solder joints into a TO-220-like crown.
	for i in range(3):
		var side = float(i-1)
		var foot = Vector3(side*width*0.75,0,0.7 if i == 1 else -0.45)
		foot.y = host.height_at(pos.x+foot.x,pos.z+foot.z)-pos.y+0.08
		var bend = Vector3(side*width*0.40,crown_y*0.40,foot.z*0.35)
		var neck = Vector3(side*width*0.26,crown_y-body_h*0.50,0)
		lead(tree,foot,bend,0.10,copper)
		lead(tree,bend,neck,0.09,copper)
		host.mesh_at(tree,SphereMesh.new(),foot,Vector3(0.7,0.20,0.7),solder)
	box(tree,Vector3(0,crown_y,0),Vector3(width,body_h,0.70),plastic)
	box(tree,Vector3(0,crown_y+body_h*0.45,-0.18),Vector3(width*0.86,body_h*0.90,0.16),alloy)
	# The mounting eye and stacked heat-sink fins read as a machine-organism canopy.
	var eye = TorusMesh.new()
	eye.inner_radius = 0.17
	eye.outer_radius = 0.29
	var ring = host.mesh_at(tree,eye,Vector3(0,crown_y+body_h*0.82,-0.02),Vector3.ONE,alloy)
	ring.rotation.x = PI/2
	for i in range(5):
		box(tree,Vector3(0,crown_y-body_h*0.32+i*body_h*0.16,-0.50),Vector3(width*1.16,0.07,0.60),plastic)
	var label_quad = QuadMesh.new();label_quad.size = Vector2(width*0.86,body_h*0.75)
	var label = host.mesh_at(tree,label_quad,Vector3(0,crown_y,0.36),Vector3.ONE,label_material)
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for side in [-1,1]:
		var joint = Vector3(side*width*0.35,crown_y*0.55,0)
		var tip = Vector3(side*width*0.98,crown_y*0.66,0.1)
		lead(tree,joint,tip,0.055,copper)
		box(tree,tip,Vector3(0.50,0.75,0.35),oxide)
	if height > 8 and art_rng.randf() > 0.6:
		cobweb(pos+Vector3(-width*0.8,crown_y*0.55,0),pos+Vector3(width*0.8,crown_y*0.55,0),pos+Vector3(0,0.5,0.15))
	return tree

func capacitor(pos: Vector3, old_scale: Vector3, lean: float):
	pos = supported_position(pos,old_scale.x*0.42+0.8)
	var n = Node3D.new()
	n.name = "CapacitorGrowth"
	root.add_child(n)
	n.position = pos
	plants.append({"node":n,"energy":0.35,"received":0,"support_radius":old_scale.x*0.42+0.8})
	n.rotation_degrees.z = lean * 0.30
	var h = old_scale.y
	var radius = old_scale.x * 0.42
	var rain_shape = CylinderShape3D.new();rain_shape.radius = radius;rain_shape.height = h
	rain_collider(n,Vector3(0,h*0.5,0),rain_shape)
	cylinder(n,Vector3(0,h*0.5,0),radius,h,oxide)
	cylinder(n,Vector3(0,h+0.03,0),radius*0.94,0.09,alloy)
	box(n,Vector3(0,h+0.09,0),Vector3(radius*1.2,0.015,0.04),plastic)
	box(n,Vector3(0,h+0.09,0),Vector3(0.04,0.015,radius*1.2),plastic)
	box(n,Vector3(radius*0.95,h*0.5,0),Vector3(0.035,h*0.87,radius*0.32),alloy)
	for side in [-1,1]:
		lead(n,Vector3(side*radius*0.45,0,0),Vector3(side*radius*0.45,-0.40,0),0.08,copper)
	return n

func cobweb(a: Vector3,b: Vector3,c: Vector3):
	var center = (a+b+c)/3.0+Vector3.DOWN*0.30
	var perimeter: Array[Vector3] = []
	for i in range(4): perimeter.append(a.lerp(b,i/4.0))
	for i in range(4): perimeter.append(b.lerp(c,i/4.0))
	for i in range(4): perimeter.append(c.lerp(a,i/4.0))
	var mesh = SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_LINES);mesh.set_material(web_material)
	for p in perimeter:
		mesh.add_vertex(center)
		mesh.add_vertex(p)
	for ring in range(1,9):
		for i in range(perimeter.size()):
			var t = ring/9.0
			var p = center.lerp(perimeter[i],t)
			var q = center.lerp(perimeter[(i+1)%perimeter.size()],t)
			var middle = (p+q)*0.5+Vector3.DOWN*0.10
			mesh.add_vertex(p);mesh.add_vertex(middle)
			mesh.add_vertex(middle);mesh.add_vertex(q)
	var n = MeshInstance3D.new()
	n.name = "DustCobweb"
	n.mesh = mesh.commit()
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(n)

func rain_collider(parent: Node3D, position: Vector3, shape: Shape3D):
	var area = Area3D.new();area.name = "RainSurface";area.collision_layer = 4;area.collision_mask = 0
	area.monitoring = false;area.monitorable = false;area.position = position;parent.add_child(area)
	var collision = CollisionShape3D.new();collision.shape = shape;area.add_child(collision)

func small_component(pos: Vector3,kind: String):
	pos = supported_position(pos,1.6)
	var n = Node3D.new()
	props.append(n)
	n.name = "Component_"+kind
	n.set_meta("component_kind",kind)
	root.add_child(n)
	n.position = pos
	n.rotation.y = art_rng.randf_range(-PI,PI)
	var enamel = material(Color("8c805b"),0.82,0.10)
	match kind:
		"resistor", "diode", "fuse":
			lead(n,Vector3(-1.4,0.08,0),Vector3(-0.55,0.55,0),0.045,alloy)
			lead(n,Vector3(0.55,0.55,0),Vector3(1.4,0.08,0),0.045,alloy)
			var body = cylinder(n,Vector3(0,0.55,0),0.23,1.25,plastic if kind == "diode" else enamel)
			body.rotation.z = PI/2
			for i in range(1 if kind == "diode" else 4):
				var band = cylinder(n,Vector3(-0.4+i*0.22,0.55,0),0.24,0.08,alloy if i%2 == 0 else copper)
				band.rotation.z = PI/2
			if kind == "fuse":
				box(n,Vector3(0,0.55,0),Vector3(0.7,0.11,0.12),copper)
		"inductor":
			cylinder(n,Vector3(0,0.65,0),0.44,1.3,plastic)
			var loop = TorusMesh.new();loop.inner_radius = 0.42;loop.outer_radius = 0.59
			for i in range(9): host.mesh_at(n,loop,Vector3(0,0.15+i*0.14,0),Vector3.ONE,copper)
			for side in [-1,1]: lead(n,Vector3(side*0.65,0.05,0),Vector3(side*0.5,0.65,0),0.055,alloy)
		"led":
			var glow = material(Color("c46c32"),0.35,0.1)
			glow.emission_enabled = true;glow.emission = Color("a84f24");glow.emission_energy_multiplier = 0.4
			cylinder(n,Vector3(0,0.70,0),0.32,0.65,glow)
			host.mesh_at(n,SphereMesh.new(),Vector3(0,1.02,0),Vector3(0.64,0.42,0.64),glow)
			for side in [-1,1]: lead(n,Vector3(side*0.16,0,0),Vector3(side*0.16,0.65,0),0.035,alloy)
		"crystal":
			var crystal = box(n,Vector3(0,0.65,0),Vector3(1.1,1.2,0.40),alloy)
			crystal.rotation.z = 0.16
			for side in [-1,1]: lead(n,Vector3(side*0.28,0,0),Vector3(side*0.28,0.45,0),0.045,alloy)
		"connector":
			box(n,Vector3(0,0.28,0),Vector3(2.3,0.5,0.9),plastic)
			for i in range(6):
				box(n,Vector3(-0.9+i*0.36,0.82,0),Vector3(0.11,0.9,0.11),copper)
		"relay":
			box(n,Vector3(0,0.85,0),Vector3(1.4,1.6,1.1),oxide)
			box(n,Vector3(0,1.7,0),Vector3(1.46,0.1,1.16),plastic)
			for side in [-1,1]:
				for i in range(3): box(n,Vector3(-0.45+i*0.45,0.12,side*0.65),Vector3(0.12,0.15,0.4),alloy)
		"ceramic":
			box(n,Vector3(0,0.30,0),Vector3(0.85,0.5,0.45),enamel)
			for side in [-1,1]: box(n,Vector3(side*0.38,0.30,0),Vector3(0.20,0.52,0.47),solder)
		"trim_pot":
			box(n,Vector3(0,0.4,0),Vector3(1.05,0.75,1.05),oxide)
			cylinder(n,Vector3(0,0.83,0),0.32,0.15,alloy)
			box(n,Vector3(0,0.92,0),Vector3(0.44,0.025,0.075),plastic)
		"ic":
			box(n,Vector3(0,0.32,0),Vector3(1.8,0.5,0.8),plastic)
			for i in range(6):
				for side in [-1,1]: box(n,Vector3(-0.7+i*0.28,0.12,side*0.53),Vector3(0.09,0.12,0.4),alloy)

func decorate():
	var families = ["resistor","diode","fuse","inductor","led","crystal","connector","relay","ceramic","trim_pot","ic"]
	for i in range(132):
		var x = art_rng.randf_range(-105,105)
		var z = art_rng.randf_range(-105,105)
		if Vector2(x,z).length() < 7: continue
		small_component(Vector3(x,host.height_at(x,z),z),families[i%families.size()])
	# Deliberate foreground composition, independent of saved resource positions.
	var first = Vector3(8,host.height_at(8,-13),-13)
	var second = Vector3(16,host.height_at(16,-18),-18)
	transistor_tree(first,9)
	transistor_tree(second,12)
	cobweb(first+Vector3(-1,4,0),second+Vector3(-1,7,0),first+Vector3(1,0.3,0))
	cobweb(first+Vector3(-1,5,0),first+Vector3(1,5,0),first+Vector3(0,2,0.2))
	for i in range(9):
		var x = -105.0+i*25.0
		var z = -100.0+art_rng.randf_range(-5,5)
		var h = art_rng.randf_range(18,32)
		var base = supported_position(Vector3(x,host.height_at(x,z),z),5.5)
		box(root,base+Vector3(0,h*0.5,0),Vector3(8,h,3),plastic)
		for fin in range(9):
			box(root,base+Vector3(-3.6+fin*0.9,h*0.5,2),Vector3(0.15,h,4),alloy)
	for i in range(12):
		var x = art_rng.randf_range(-70,70)
		var z = art_rng.randf_range(-70,70)
		if Vector2(x,z).length() < 15: continue
		var p = supported_position(Vector3(x,host.height_at(x,z),z),2.6)+Vector3.UP*0.18
		box(root,p,Vector3(4,0.35,2.2),plastic)
		for pin in range(8):
			for side in [-1,1]:
				box(root,p+Vector3(-1.6+pin*0.45,-0.12,side*1.25),Vector3(0.16,0.12,0.5),copper)

func make_dust(parent: Node3D) -> GPUParticles3D:
	var particles = GPUParticles3D.new()
	particles.name = "SuspendedServerDust"
	particles.amount = 220 if OS.has_feature("web") else 900
	particles.lifetime = 35
	particles.preprocess = 8
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-42,-16,-42),Vector3(84,40,84))
	var process = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(30,12,30)
	process.direction = Vector3(1,-0.08,0.3)
	process.spread = 35
	process.gravity = Vector3(0,-0.002,0)
	process.initial_velocity_min = 0.04
	process.initial_velocity_max = 0.16
	process.scale_min = 0.35
	process.scale_max = 1.0
	particles.process_material = process
	var gradient = Gradient.new()
	gradient.set_color(0,Color(0.8,0.75,0.57,0.55))
	gradient.set_color(1,Color(0.8,0.75,0.57,0))
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 16;texture.height = 16
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5);texture.fill_to = Vector2(1,0.5)
	var m = material(Color.WHITE,1,0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = texture
	var quad = QuadMesh.new()
	quad.size = Vector2(0.05,0.05)
	quad.material = m
	particles.draw_pass_1 = quad
	parent.add_child(particles)
	particles.position.y = 6
	return particles

func batch_static_geometry():
	# Spatial/material batches keep culling, while avoiding thousands of component draw calls.
	var groups: Dictionary = {}
	for n in root.find_children("*","MeshInstance3D",true,false):
		if n.mesh == null: continue
		for surface in range(n.mesh.get_surface_count()):
			var material: Material = n.get_active_material(surface)
			if material == null: continue
			# Shared 48 m tiles halve native material batches while retaining local culling.
			var cell_size = 48.0
			var cell = Vector2i(floori(n.global_position.x/cell_size),floori(n.global_position.z/cell_size))
			var primitive = n.mesh.surface_get_primitive_type(surface) if n.mesh is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES
			var key = "%s/%d/%d/%d" % [material.get_instance_id(),cell.x,cell.y,primitive]
			if not groups.has(key):
				var st = SurfaceTool.new();st.begin(primitive)
				groups[key] = {"st":st,"material":material}
			groups[key].st.append_from(n.mesh,surface,root.global_transform.affine_inverse()*n.global_transform)
		batched_sources += 1
		n.mesh = null
		n.queue_free()
	for key in groups:
		var instance = MeshInstance3D.new();instance.name = "ComponentBatch_%d" % batch_count
		instance.mesh = groups[key].st.commit();instance.material_override = groups[key].material
		instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC;root.add_child(instance);batch_count += 1
		if groups[key].material == label_material or (OS.has_feature("web") and groups[key].material in [copper,alloy,solder,web_material]): instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	print("VELUM_COMPONENT_BATCHES sources=",batched_sources," batches=",batch_count)
