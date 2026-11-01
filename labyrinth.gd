extends RefCounted
## Streamed logical labyrinth. One 198 m PCB chamber is resident at a time.
const SIDE = 9
const CELLS = 11
const CELL = 18.0
const DIRS = [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
var game
var section = Vector2i.ZERO
var epoch = 0
var passages: Dictionary = {}
var walls: Array[Dictionary] = []
var wall_cells: Dictionary = {}
var root: Node3D
var collected: Array = []
var escaped = false
var cooldown = 0.0
var guidance_key = ""
var guidance_text = ""
var coolant_material: ShaderMaterial
var flow_clock = 0.0
var protected_bounds: Dictionary = {}
var modules = {Vector2i(2,2):"PSU",Vector2i(6,2):"RAM",Vector2i(6,6):"LIQUID COOLER",Vector2i(4,4):"SoC"}

func generate_graph(seed_value: int, side: int) -> Dictionary:
	var r = RandomNumberGenerator.new();r.seed = seed_value
	var graph: Dictionary = {Vector2i.ZERO:[]}
	var stack: Array[Vector2i] = [Vector2i.ZERO]
	while not stack.is_empty():
		var p = stack.back();var choices: Array[Vector2i] = []
		for d in DIRS:
			var q = p+d
			if q.x >= 0 and q.y >= 0 and q.x < side and q.y < side and not graph.has(q): choices.append(q)
		if choices.is_empty(): stack.pop_back();continue
		var q = choices[r.randi_range(0,choices.size()-1)]
		graph[p].append(q);graph[q] = [p];stack.append(q)
	return graph

func setup(owner_game):
	game = owner_game
	passages = generate_graph(game.WORLD_SEED,SIDE)
	epoch = int(Time.get_unix_time_from_system()*1000)

func local_graph() -> Dictionary:
	return generate_graph(game.WORLD_SEED+section.x*7919+section.y*104729+epoch*31,CELLS)

func rebuild():
	if protected_bounds.is_empty():
		for mesh in game.world_art.root.find_children("*","MeshInstance3D",true,false):
			if mesh.mesh == null: continue
			var bounds: AABB = (mesh.global_transform*mesh.get_aabb()).grow(0.18)
			for x in range(floori(bounds.position.x/8),floori(bounds.end.x/8)+1):
				for z in range(floori(bounds.position.z/8),floori(bounds.end.z/8)+1):
					var key = Vector2i(x,z)
					if not protected_bounds.has(key): protected_bounds[key] = []
					protected_bounds[key].append(bounds)
	if root != null: root.free()
	root = Node3D.new();root.name = "StreamedLabyrinthSection";game.add_child(root);walls.clear()
	var graph = local_graph()
	var material = ShaderMaterial.new();material.shader = load("res://shaders/cooling_wall.gdshader")
	material.set_shader_parameter("procedural_offset",Vector2(posmod(game.WORLD_SEED,997)+section.x*17,posmod(game.WORLD_SEED,991)+section.y*13))
	for x in range(CELLS):
		for z in range(CELLS):
			var p = Vector2i(x,z);var center = Vector2((x-5)*CELL,(z-5)*CELL)
			if x == 0: add_wall(center+Vector2(-9,0),Vector2(0.8,18),material)
			if z == 0: add_wall(center+Vector2(0,-9),Vector2(18,0.8),material)
			if not graph[p].has(p+Vector2i.RIGHT):
				if x != 10 or not passages[section].has(section+Vector2i.RIGHT) or z != 5: add_wall(center+Vector2(9,0),Vector2(0.8,18),material)
			if not graph[p].has(p+Vector2i.DOWN):
				if z != 10 or not passages[section].has(section+Vector2i.DOWN) or x != 5: add_wall(center+Vector2(0,9),Vector2(18,0.8),material)
	# Left/up external gates replace their boundary segments.
	for i in range(walls.size()-1,-1,-1):
		var w = walls[i]
		if (w.center == Vector2(-99,0) and passages[section].has(section+Vector2i.LEFT)) or (w.center == Vector2(0,-99) and passages[section].has(section+Vector2i.UP)):
			w.body.free();walls.remove_at(i)
	var instances = MultiMeshInstance3D.new();var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D;multimesh.instance_count = walls.size()
	var box = BoxMesh.new();box.size = Vector3.ONE;box.material = material;multimesh.mesh = box
	for i in range(walls.size()):
		var w = walls[i]
		multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(w.size.x,w.height,w.size.y)),w.body.position))
	instances.multimesh = multimesh;root.add_child(instances)
	build_wall_cooling()
	wall_cells.clear()
	for wall in walls:
		var first = (wall.center-wall.size*0.5-Vector2.ONE*1.2)/CELL
		var last = (wall.center+wall.size*0.5+Vector2.ONE*1.2)/CELL
		for x in range(floori(first.x),floori(last.x)+1):
			for z in range(floori(first.y),floori(last.y)+1):
				var key = Vector2i(x,z)
				if not wall_cells.has(key): wall_cells[key] = []
				wall_cells[key].append(wall)
	var label = Label3D.new();label.text = "VELUM // %02d:%02d\n%s\n[E] interface" % [section.x,section.y,modules.get(section,"ROUTING CHAMBER")]
	label.position = Vector3(0,game.height_at(0,-5)+3.2,-5);label.font_size = 44;label.pixel_size = 0.002;root.add_child(label)
	# Physical interface, visible from the central checkpoint.
	var pedestal = CylinderMesh.new();pedestal.top_radius = 0.7;pedestal.bottom_radius = 1;pedestal.height = 1.8
	game.mesh_at(root,pedestal,Vector3(0,game.height_at(0,-3)+0.9,-3),Vector3.ONE,game.mat(Color("63bfa9"),0.4))
	build_module()
	for next in passages[section]:
		var direction: Vector2i = next-section
		var gate_label = Label3D.new();gate_label.text = "BUS GATE\n%d:%d" % [next.x,next.y]
		gate_label.position = Vector3(direction.x*97,4,direction.y*97)
		gate_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED;gate_label.font_size = 40;gate_label.pixel_size = 0.009
		root.add_child(gate_label)
	if game.graphics != null: game.graphics.refresh_section_gi()

func build_module():
	var kind: String = modules.get(section,"")
	if kind == "" and section != Vector2i(8,8): return
	var ceramic = game.mat(Color("9aa69b"))
	var conductor = game.mat(Color("be985b"))
	var glow = game.mat(Color("53cabb") if kind != "PSU" else Color("e5ad53"),0.65)
	# Overhead assemblies leave all walkable paths and salvage sockets clear.
	for side in [-1,1]:
		var arm = BoxMesh.new();arm.size = Vector3(0.35,0.35,8)
		game.mesh_at(root,arm,Vector3(side*5,4.5,0),Vector3.ONE,conductor)
		for i in range(6):
			var p = Vector3(side*4.5,5.2,-3+i*1.2)
			if kind == "PSU":
				var capacitor = CylinderMesh.new();capacitor.top_radius = 0.48;capacitor.bottom_radius = 0.48;capacitor.height = 2.4
				game.mesh_at(root,capacitor,p,Vector3.ONE,ceramic)
			elif kind == "LIQUID COOLER":
				var loop = TorusMesh.new();loop.inner_radius = 0.65;loop.outer_radius = 0.9
				game.mesh_at(root,loop,p,Vector3.ONE,glow)
			else:
				var bank = BoxMesh.new();bank.size = Vector3(0.3,2.2,0.8) if kind == "RAM" else Vector3(0.8,0.7,0.8)
				game.mesh_at(root,bank,p,Vector3.ONE,ceramic)
	var core = BoxMesh.new();core.size = Vector3(4,0.7,4)
	game.mesh_at(root,core,Vector3(0,6,-3),Vector3.ONE,glow)

func build_wall_cooling():
	coolant_material = ShaderMaterial.new();coolant_material.shader = load("res://shaders/working_fluid.gdshader")
	coolant_material.set_shader_parameter("instanced_paths",true)
	var glass = game.mat(Color(0.32,0.58,0.51,0.16));glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA;glass.roughness = 0.14
	var metal = game.mat(Color("6c7d73"));metal.metallic = 0.8;metal.roughness = 0.34
	var fluid_transforms: Array[Transform3D] = [];var glass_transforms: Array[Transform3D] = []
	var fin_transforms: Array[Transform3D] = [];var data: Array[Color] = []
	var window_transforms: Array[Transform3D] = []
	for wall in walls:
		var along = Vector3.FORWARD if wall.size.x < wall.size.y else Vector3.RIGHT
		var normal = Vector3.RIGHT if wall.size.x < wall.size.y else Vector3.BACK
		var center = Vector3(wall.center.x,wall.base,wall.center.y)
		for side in [-1,1]:
			var base = center+normal*side*0.56
			var span = maxf(wall.size.x,wall.size.y)*0.5-0.15
			var corners = [base-along*span+Vector3.UP*0.13,base+along*span+Vector3.UP*0.13,base+along*span+Vector3.UP*0.46,base-along*span+Vector3.UP*0.46]
			var offset = 0.0
			for i in range(4):
				var a: Vector3 = corners[i];var b: Vector3 = corners[(i+1)%4];var length = a.distance_to(b)
				var rotation = Basis(Quaternion(Vector3.UP,(b-a).normalized()))
				fluid_transforms.append(Transform3D(rotation.scaled_local(Vector3(0.035,length,0.035)),(a+b)*0.5))
				glass_transforms.append(Transform3D(rotation.scaled_local(Vector3(0.055,length,0.055)),(a+b)*0.5))
				data.append(Color(length,offset,0,0));offset += length
			for i in range(4):
				var dimensions = Vector3(0.18,0.22,0.06) if wall.size.x < wall.size.y else Vector3(0.06,0.22,0.18)
				fin_transforms.append(Transform3D(Basis.IDENTITY.scaled(dimensions),base+along*lerpf(-span*0.75,span*0.75,i/3.0)+Vector3.UP*0.29))
	var tube = CylinderMesh.new();tube.top_radius = 1;tube.bottom_radius = 1;tube.height = 1;tube.radial_segments = 8
	add_instances("FlowingCoolant",tube,coolant_material,fluid_transforms,data)
	add_instances("TranslucentChannels",tube,glass,glass_transforms,[])
	var fin = BoxMesh.new();fin.size = Vector3.ONE
	add_instances("CoolingFins",fin,metal,fin_transforms,[])
	add_instances("ContainmentWindows",fin,glass,window_transforms,[])

func add_instances(label: String, mesh: Mesh, material: Material, transforms: Array[Transform3D], data: Array):
	var instance = MultiMeshInstance3D.new();instance.name = label
	var multi = MultiMesh.new();multi.transform_format = MultiMesh.TRANSFORM_3D;multi.use_custom_data = not data.is_empty();multi.mesh = mesh;multi.instance_count = transforms.size()
	for i in range(transforms.size()):
		multi.set_instance_transform(i,transforms[i])
		if not data.is_empty(): multi.set_instance_custom_data(i,data[i])
	instance.multimesh = multi;instance.material_override = material;root.add_child(instance)

func add_wall(center: Vector2, size: Vector2, material: Material):
	var along = Vector2.DOWN if size.x < size.y else Vector2.RIGHT
	for i in range(6):
		var p = center+along*(-7.5+i*3)
		# Leave gates, ramps, steep slab edges and living components clear in every revision.
		if (absf(p.x)>98 and absf(p.y)<9 and passages[section].has(section+Vector2i(-1 if p.x<0 else 1,0))) or (absf(p.y)>98 and absf(p.x)<9 and passages[section].has(section+Vector2i(0,-1 if p.y<0 else 1))): continue
		var blocked = false
		for plant in game.world_art.plants:
			if Vector2(plant.node.position.x,plant.node.position.z).distance_to(p) < 5.4: blocked = true;break
		for prop in game.world_art.props:
			if Vector2(prop.position.x,prop.position.z).distance_to(p) < 2.6: blocked = true;break
		for resource in game.resources:
			if Vector2(resource.node.position.x,resource.node.position.z).distance_to(p) < 2.5: blocked = true;break
		for ramp in game.board_terrain.ramps:
			var a = Vector2(ramp.a.x,ramp.a.z);var b = Vector2(ramp.b.x,ramp.b.z)
			if Geometry2D.get_closest_point_to_segment(p,a,b).distance_to(p) < ramp.width*0.5+2: blocked = true;break
		if blocked: continue
		var low = INF;var high = -INF
		for distance in [-1.5,-0.75,0,0.75,1.5]:
			for side in [-0.55,0,0.55]:
				var q = p+along*distance+Vector2(-along.y,along.x)*side
				var h: float = game.height_at(q.x,q.y);low = minf(low,h);high = maxf(high,h)
		if high-low > 0.12: continue
		var segment = Vector2(0.8,2.98) if size.x < size.y else Vector2(2.98,0.8)
		var height = high-low+0.59
		var proposed = AABB(Vector3(p.x-segment.x*0.5-0.25,low-0.04,p.y-segment.y*0.5-0.25),Vector3(segment.x+0.5,height+0.1,segment.y+0.5))
		for x in range(floori(proposed.position.x/8),floori(proposed.end.x/8)+1):
			for z in range(floori(proposed.position.z/8),floori(proposed.end.z/8)+1):
				for bounds in protected_bounds.get(Vector2i(x,z),[]):
					if proposed.intersects(bounds): blocked = true;break
		if blocked: continue
		var body = StaticBody3D.new();body.position = Vector3(p.x,low-0.04+height*0.5,p.y);root.add_child(body)
		var shape = BoxShape3D.new();shape.size = Vector3(segment.x,height,segment.y)
		var collision = CollisionShape3D.new();collision.shape = shape;body.add_child(collision)
		walls.append({"center":p,"size":segment,"body":body,"base":low-0.04,"height":height})

func clear_at(x: float,z: float) -> bool:
	if absf(x) > 97 or absf(z) > 97: return false
	for wall in wall_cells.get(Vector2i(floori(x/CELL),floori(z/CELL)),[]):
		if absf(x-wall.center.x) < wall.size.x*0.5+1.2 and absf(z-wall.center.y) < wall.size.y*0.5+1.2: return false
	return true

func transition(destination: Vector2i):
	if not passages[section].has(destination): return false
	section = destination;epoch += 1
	rebuild()
	game.player.position = Vector3(0,game.height_at(0,0)+1,0);game.player.velocity = Vector3.ZERO
	game.navigation.usable.clear();game.navigation.points.clear();game.navigation.reachable_resources.clear();game.navigation.setup(game);game.navigation.index_resources()
	for c in game.creatures:
		c.node.position = game.navigation.safe_spawn(c.node.position)+Vector3(0,1,0);c.path = PackedVector2Array();c.path_index = 0
	cooldown = 2.0;game.notify(status());return true

func step(delta: float):
	flow_clock += delta*0.22
	if coolant_material != null: coolant_material.set_shader_parameter("flow_clock",flow_clock)
	cooldown = maxf(0,cooldown-delta)
	if not game.hatched or cooldown > 0: return
	var p: Vector3 = game.player.position
	for d in DIRS:
		if p.x*d.x+p.z*d.y > 100 and absf(p.x*d.y-p.z*d.x) < 8:
			transition(section+d);return

func interact() -> bool:
	if game.player.position.distance_to(Vector3(0,game.height_at(0,-3)+1,-3)) > 4: return false
	var module_name: String = modules.get(section,"")
	if module_name != "":
		if module_name == "SoC" and collected.size() < 3: game.notify("SoC locked // authenticate PSU, RAM and LIQUID COOLER first.");return true
		if not collected.has(module_name): collected.append(module_name)
	if section == Vector2i(8,8) and collected.has("SoC"): escaped = true
	game.notify(status());return true

func status() -> String:
	return "ESCAPED // Core recovered" if escaped else "LABYRINTH %d:%d / 81 // %s // Modules %d/4 // %s" % [section.x,section.y,str(modules.get(section,"ROUTING")),collected.size(),guidance()]

func guidance() -> String:
	var key = str(section)+str(collected)
	if key == guidance_key: return guidance_text
	guidance_key = key;guidance_text = compute_guidance()
	return guidance_text

func compute_guidance() -> String:
	var target = Vector2i(8,8)
	for candidate in modules:
		if not collected.has(modules[candidate]): target = candidate;break
	if target == section: return "Interface at central checkpoint [E]"
	var queue = [section];var previous = {section:section}
	while not queue.is_empty():
		var p = queue.pop_front()
		if p == target: break
		for next in passages[p]:
			if not previous.has(next): previous[next] = p;queue.append(next)
	var next = target
	while previous[next] != section: next = previous[next]
	var direction: Vector2i = next-section
	var gate = "EAST +X" if direction.x > 0 else ("WEST -X" if direction.x < 0 else ("SOUTH +Z" if direction.y > 0 else "NORTH -Z"))
	return "Target %d:%d // gate %s" % [target.x,target.y,gate]

func draw_network(canvas: Control):
	var origin = Vector2(310,18);var spacing = 10.0
	canvas.draw_rect(Rect2(origin-Vector2(7,7),Vector2(95,95)),Color(0.02,0.05,0.06,0.92))
	for p in passages:
		var point = origin+Vector2(p)*spacing
		for next in passages[p]: canvas.draw_line(point,origin+Vector2(next)*spacing,Color("506e65"),1)
		if modules.has(p) or p == Vector2i(8,8): canvas.draw_circle(point,2.5,Color("87dca2") if collected.has(modules.get(p,"")) else Color("d6ac65"))
	canvas.draw_circle(origin+Vector2(section)*spacing,3.5,Color.WHITE)

func snapshot() -> Dictionary:
	return {"x":section.x,"z":section.y,"epoch":epoch,"modules":collected.duplicate(),"escaped":escaped}

func restore(state: Dictionary):
	section = Vector2i(clampi(int(state.get("x",0)),0,8),clampi(int(state.get("z",0)),0,8))
	epoch = int(state.get("epoch",epoch))+1;collected = state.get("modules",[]).duplicate();escaped = state.get("escaped",false)
	# Loading reconfigures the section and resumes at its protected central checkpoint.
	rebuild();game.player.position = Vector3(0,game.height_at(0,0)+1,0);game.player.velocity = Vector3.ZERO
