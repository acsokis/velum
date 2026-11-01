extends Node3D
## Bounded, collidable shoreline cells; the main terrain and mission routes stay protected.
const SEA_LEVEL = -0.65
const CELL = 4.0
const MAX_ERODED = 24
var game
var cells: Array[Dictionary] = []
var outer: Array[int] = []
var plants: Array[Dictionary] = []
var blocks: MultiMeshInstance3D
var spikes: MultiMeshInstance3D
var sponges: MultiMeshInstance3D
var solid: StaticBody3D
var clock = 0.0
var tick_clock = 0.0
var erosion_clock = 0.0
var eroded = 0
var restored = 0
var rng = RandomNumberGenerator.new()
var wet_growth = 0.0
var growth_probe = BoxShape3D.new()

func setup(owner_game):
	game = owner_game;name = "LivingShore";rng.seed = game.WORLD_SEED ^ 0xC0457
	solid = StaticBody3D.new();add_child(solid)
	var transforms: Array[Transform3D] = []
	for x in range(64):
		for z in range(64):
			var p = Vector3(-126+x*CELL,0,-126+z*CELL)
			if maxf(absf(p.x),absf(p.z)) < 120: continue
			var exposed = maxf(absf(p.x),absf(p.z)) > 124
			p.y = -0.52 if exposed else -0.45
			var normal = Vector3(signf(p.x),0,0) if absf(p.x) >= absf(p.z) else Vector3(0,0,signf(p.z))
			var collider = CollisionShape3D.new();var shape = BoxShape3D.new();shape.size = Vector3(4,0.8,4)
			collider.shape = shape;collider.position = p;solid.add_child(collider)
			cells.append({"position":p,"normal":normal,"present":true,"outer":exposed,"collider":collider})
			transforms.append(Transform3D(Basis.IDENTITY,p))
			if exposed: outer.append(cells.size()-1)
	var material = game.mat(Color("3c6856"));material.roughness = 0.85
	var cube = BoxMesh.new();cube.size = Vector3(3.98,0.8,3.98)
	blocks = instances(cube,material,transforms.size())
	for i in range(cells.size()): blocks.multimesh.set_instance_transform(i,transforms[i])
	var quad = QuadMesh.new();quad.size = Vector2(4.05,1.8)
	var surge = ShaderMaterial.new();surge.shader = load("res://shaders/coast_surge.gdshader")
	spikes = instances(quad,surge,outer.size())
	var sponge_material = ShaderMaterial.new();sponge_material.shader = load("res://shaders/coast_sponge.gdshader")
	sponges = instances(sponge_mesh(),sponge_material,16)
	for side in range(4):
		for i in range(4):
			var normal = [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK][side]
			var tangent: Vector3 = normal.cross(Vector3.UP)
			var p: Vector3 = normal*121.5+tangent*(-90+i*60);p.y = -0.05
			var collider = CollisionShape3D.new();var shape = BoxShape3D.new();shape.size = Vector3(1.55,0.08,1.55)
			collider.shape = shape;collider.position = p+Vector3.UP*0.04;collider.disabled = true;solid.add_child(collider)
			plants.append({"position":p,"growth":0.06,"clock":0.0,"repairs":0,"collider":collider})
			sponges.multimesh.set_instance_transform(plants.size()-1,Transform3D(Basis.IDENTITY,p))
	update_spikes()

func instances(mesh: Mesh, material: Material, count: int) -> MultiMeshInstance3D:
	var result = MultiMeshInstance3D.new();var multi = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D;multi.use_custom_data = true;multi.mesh = mesh;multi.instance_count = count
	result.multimesh = multi;result.material_override = material;result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(result);return result

func sponge_mesh() -> ArrayMesh:
	var st = SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cube = BoxMesh.new();cube.size = Vector3(0.32,0.28,0.32)
	for y in range(5):
		for x in range(-2,3):
			for z in range(-2,3):
				if x*x+z*z > (3 if y in [0,4] else 6) or posmod(x+z+y,3) == 0: continue
				st.append_from(cube,0,Transform3D(Basis.IDENTITY,Vector3(x*0.31,0.14+y*0.25,z*0.31)))
	st.index();return st.commit()

func occupied(index: int) -> bool:
	var c = cells[index]
	var query = PhysicsShapeQueryParameters3D.new();query.shape = c.collider.shape
	query.transform = Transform3D(Basis.IDENTITY,c.position);query.collision_mask = 3;query.margin = 0.06
	query.exclude = [solid.get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func set_present(index: int, present: bool) -> bool:
	if index < 0 or index >= cells.size() or not cells[index].outer: return false
	if cells[index].present == present: return true
	# Never remove support under an actor or regrow a body through one.
	if occupied(index): return false
	cells[index].present = present;cells[index].collider.set_deferred("disabled",not present)
	blocks.multimesh.set_instance_transform(index,Transform3D(Basis.IDENTITY if present else Basis.IDENTITY.scaled(Vector3.ZERO),cells[index].position))
	update_spikes();return true

func missing_count() -> int:
	var count = 0
	for index in outer:
		if not cells[index].present: count += 1
	return count

func erode_one() -> bool:
	if missing_count() >= MAX_ERODED: return false
	var start = rng.randi_range(0,outer.size()-1)
	for offset in range(outer.size()):
		var index = outer[(start+offset)%outer.size()]
		if cells[index].present and set_present(index,false): eroded += 1;return true
	return false

func repair_near(plant: Dictionary) -> bool:
	var best = -1;var distance = 48.0*48.0
	for index in outer:
		if cells[index].present: continue
		var d: float = cells[index].position.distance_squared_to(plant.position)
		if d < distance and not occupied(index): distance = d;best = index
	if best < 0 or not set_present(best,true): return false
	plant.repairs += 1;restored += 1;return true

func update_spikes():
	for i in range(outer.size()):
		var c = cells[outer[i]]
		var p: Vector3 = c.position+c.normal*(2.03 if c.present else -2.03);p.y = SEA_LEVEL+1.3
		var basis = Basis(Vector3.UP,atan2(c.normal.x,c.normal.z))
		spikes.multimesh.set_instance_transform(i,Transform3D(basis,p))
		spikes.multimesh.set_instance_custom_data(i,Color(float(i)/outer.size(),1.0 if c.present else 0.65,0,1))

func step(delta: float):
	clock += delta;erosion_clock += delta;tick_clock += delta
	if erosion_clock >= 4.0:
		erosion_clock = fmod(erosion_clock,4.0);erode_one()
	if tick_clock < 0.1: return
	var elapsed = tick_clock;tick_clock = 0
	wet_growth = 0
	for i in range(plants.size()):
		var plant = plants[i]
		var wet = game.weather.rain_active() and game.weather.cloud_coverage(plant.position) > 0.55
		var growth = move_toward(plant.growth,1.0 if wet else 0.06,elapsed*(0.3 if wet else 0.08))
		var height = maxf(0.08,growth*1.28)
		if growth > plant.growth and growth > 0.15:
			growth_probe.size = Vector3(1.55,height,1.55)
			var query = PhysicsShapeQueryParameters3D.new();query.shape = growth_probe;query.collision_mask = 3
			query.transform = Transform3D(Basis.IDENTITY,plant.position+Vector3.UP*height*0.5);query.exclude = [solid.get_rid()]
			if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): growth = plant.growth;height = maxf(0.08,growth*1.28)
		plant.growth = growth
		plant.collider.shape.set_deferred("size",Vector3(1.55,height,1.55))
		plant.collider.set_deferred("position",plant.position+Vector3.UP*height*0.5)
		plant.collider.set_deferred("disabled",growth < 0.15)
		plant.clock = plant.clock+elapsed if wet else 0.0
		if plant.clock >= 2.0: plant.clock = 0.0;repair_near(plant)
		sponges.multimesh.set_instance_custom_data(i,Color(plant.growth,1.0 if wet else 0.0,fposmod(i*0.37,1),1))
		wet_growth = maxf(wet_growth,plant.growth)
	spikes.material_override.set_shader_parameter("surge_clock",clock)
	spikes.material_override.set_shader_parameter("flashes",game.weather.flashes)

func _physics_process(delta): step(delta)

func rescue_player():
	var p: Vector3 = game.player.position
	if absf(p.x) > absf(p.z): p = Vector3(signf(p.x)*121.5,1.1,clampf(p.z,-117,117))
	else: p = Vector3(clampf(p.x,-117,117),1.1,signf(p.z)*121.5)
	game.player.position = p;game.player.velocity = Vector3.ZERO
	game.energy = maxf(0,game.energy-3);game.notify("Shore recovery // Returned to solid ground.")

func snapshot_state() -> Dictionary:
	var missing = []
	for index in outer:
		if not cells[index].present: missing.append(index)
	return {"version":1,"missing":missing,"rng":str(rng.state),"clock":clock,"erosion_clock":erosion_clock,"eroded":eroded,"restored":restored}

func restore_state(state: Dictionary):
	var missing = state.get("missing",[])
	if not missing is Array: return
	var valid = []
	for item in missing:
		if (item is int or item is float) and int(item) in outer and not int(item) in valid and valid.size() < MAX_ERODED: valid.append(int(item))
	for index in outer: set_present(index,not index in valid)
	clock = maxf(0,float(state.get("clock",0)));erosion_clock = clampf(float(state.get("erosion_clock",0)),0,4)
	eroded = maxi(0,int(state.get("eroded",0)));restored = maxi(0,int(state.get("restored",0)))
	if state.has("rng"): rng.state = int(state.rng)
