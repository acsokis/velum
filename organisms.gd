extends RefCounted
## Original procedural organisms. Every luminous reservoir is linked to ecological state.
var game: Node3D
var shell_material: StandardMaterial3D
var alloy: StandardMaterial3D
var membrane: StandardMaterial3D

func setup(owner_game):
	game = owner_game
	shell_material = game.world_art.material(Color("d2ccb1"),0.42,0.25)
	alloy = game.world_art.material(Color("253c37"),0.3,0.85)
	membrane = game.world_art.material(Color(0.13,0.58,0.48,0.48),0.22,0.15)
	membrane.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func sphere(parent: Node3D, pos: Vector3, size: Vector3, material: Material):
	var mesh = SphereMesh.new();mesh.radius = 1;mesh.height = 2
	return game.mesh_at(parent,mesh,pos,size,material)

func create(index: int, position: Vector3, hover_override = -1) -> Dictionary:
	position = game.navigation.safe_spawn(position)
	var hover = index % 3 == 0 if hover_override < 0 else hover_override == 1
	var body = CharacterBody3D.new();game.add_child(body)
	body.collision_layer = 2;body.collision_mask = 3 # Agents collide with terrain/agents and yield to the player.
	body.name = "CoolantSkimmer" if hover else "ConductorRoller"
	body.position = position;body.position.y = game.height_at(position.x,position.z)+(1.35 if hover else 0.7)
	var collision = CollisionShape3D.new();var shape = SphereShape3D.new();shape.radius = 0.68
	collision.shape = shape;body.add_child(collision)
	var rig = Node3D.new();body.add_child(rig)
	var drum = Node3D.new();rig.add_child(drum)
	var liquid = ShaderMaterial.new();liquid.shader = load("res://shaders/working_fluid.gdshader")
	var anatomy = build_mass(drum,liquid)
	var tank: MeshInstance3D = anatomy.tank
	var core: MeshInstance3D = anatomy.core
	var jets: Array[MeshInstance3D] = []
	if hover:
		# No struts or feet: three gimballed nozzles carry the whole organism.
		for j in range(3):
			var a = j*TAU/3
			var p = Vector3(sin(a)*0.62,-0.23,cos(a)*0.62)
			game.world_art.lead(rig,Vector3(0,-0.1,0),p,0.08,alloy)
			game.world_art.cylinder(rig,p,0.20,0.23,shell_material)
			var exhaust = CylinderMesh.new();exhaust.top_radius = 0.11;exhaust.bottom_radius = 0.035;exhaust.height = 0.45
			jets.append(game.mesh_at(rig,exhaust,p+Vector3(0,-0.34,0),Vector3.ONE,liquid))
	batch_drum(drum,[tank,core,anatomy.body])
	var movement_rng = RandomNumberGenerator.new();movement_rng.seed = game.WORLD_SEED+index*1741
	var c = {"node":body,"rig":rig,"drum":drum,"tank":tank,"core":core,"skin":anatomy.skin,"liquid":liquid,"jets":jets,"hover":hover,"target":index*3,"carried":0.0,"phase":float(index),"charge":0.8,"coolant":0.8,"heat":0.15,"travel":0.0,"roll":0.0,"delivered":0,"collecting":true,"rng":movement_rng,"steer":Vector3.FORWARD,"avoid":0.0,"stuck":0.0,"turns":0,"maneuver":0.0,"maneuver_duration":1.0,"flips":0,"hover_goal":1.35,"hover_timer":0.0}
	game.set_dynamic_geometry(body)
	c.target = game.navigation.select_target(c.target)
	c["path"] = PackedVector2Array();c["path_index"] = 0;c["path_target"] = -1;c["route_clock"] = 0.0
	c["disabled"] = 0.0;c["salvage_cooldown"] = 0.0;c["attack_clock"] = 3.0
	c["flow_clock"] = float(index)*0.37
	return c

func profile(t: float, a: float) -> Vector3:
	var radius = pow(maxf(0,sin(t*PI)),0.62)*(0.55+0.19*cos(t*TAU-1.0))
	var belly = exp(-pow((t-0.30)/0.19,2))
	return Vector3(cos(a)*radius*0.94,-0.68+t*2.06,sin(a)*radius*1.08-belly*0.23)

func build_mass(drum: Node3D, liquid: Material) -> Dictionary:
	var st = SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_smooth_group(0)
	for y in range(24):
		for j in range(32):
			var a = profile(y/24.0,j*TAU/32);var b = profile((y+1)/24.0,j*TAU/32)
			var c = profile((y+1)/24.0,(j+1)*TAU/32);var d = profile(y/24.0,(j+1)*TAU/32)
			for triangle in [[a,d,c],[a,c,b]]:
				if (triangle[2]-triangle[0]).cross(triangle[1]-triangle[0]).length_squared() < 0.0000001: continue
				for vertex in triangle: st.add_vertex(vertex)
	st.index();st.generate_normals()
	var skin = ShaderMaterial.new();skin.shader = load("res://shaders/organism_skin.gdshader")
	var body = game.mesh_at(drum,st.commit(),Vector3.ZERO,Vector3.ONE,skin)
	# An optical eye, not a decorative fantasy eyeball.
	var amber = game.world_art.material(Color("ebbc55"),0.16,0.6)
	amber.emission_enabled = true;amber.emission = Color("e3a63c");amber.emission_energy_multiplier = 0.35
	sphere(drum,Vector3(0.02,1.22,-0.25),Vector3(0.20,0.23,0.17),alloy)
	sphere(drum,Vector3(0.02,1.23,-0.37),Vector3(0.145,0.17,0.07),amber)
	sphere(drum,Vector3(0.03,1.22,-0.435),Vector3(0.025,0.10,0.012),alloy)
	# The mouth-like aperture is a filter and coolant intake; ceramic shutters replace teeth.
	sphere(drum,Vector3(0,0.78,-0.41),Vector3(0.35,0.42,0.10),alloy)
	sphere(drum,Vector3(0,0.75,-0.49),Vector3(0.25,0.30,0.03),alloy)
	for j in range(5):
		game.world_art.box(drum,Vector3(0,0.58+j*0.09,-0.535),Vector3(0.36,0.027,0.035),shell_material)
	for j in range(9):
		var a = j*TAU/9
		var valve = sphere(drum,Vector3(sin(a)*0.30,0.78+cos(a)*0.36,-0.49),Vector3(0.065,0.10,0.06),shell_material)
		valve.rotation.z = -a
	# A broad asymmetric belly window reveals the working-fluid bladder.
	var tank = sphere(drum,Vector3(0.05,-0.07,-0.94),Vector3(0.46,0.46,0.10),membrane)
	var core = sphere(drum,Vector3(0.05,-0.08,-0.98),Vector3(0.34,0.30,0.07),liquid)
	for side in [-1,1]:
		var path = [Vector3(side*0.36,-0.28,-0.70),Vector3(side*0.47,0.12,-0.60),Vector3(side*0.31,0.43,-0.42),Vector3(side*0.12,0.53,-0.45)]
		for i in range(path.size()-1): game.world_art.lead(drum,path[i],path[i+1],0.045,liquid)
	return {"body":body,"skin":skin,"tank":tank,"core":core}

func batch_drum(drum: Node3D, excluded: Array):
	var groups = {}
	for source in drum.get_children():
		if not source is MeshInstance3D or source in excluded: continue
		var key = source.material_override.get_instance_id()
		if not groups.has(key):
			var st = SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = {"st":st,"material":source.material_override}
		groups[key].st.append_from(source.mesh,0,source.transform)
		source.mesh = null
		source.queue_free()
	for key in groups:
		var mesh = MeshInstance3D.new();mesh.mesh = groups[key].st.commit();mesh.material_override = groups[key].material
		drum.add_child(mesh)

func step(c: Dictionary, delta: float):
	var body: CharacterBody3D = c.node
	c.flow_clock += delta*(0.08+c.coolant*0.25+c.heat*0.12)*(0.08 if c.disabled > 0 else 1.0)
	c.liquid.set_shader_parameter("flow_clock",c.flow_clock)
	c.liquid.set_shader_parameter("coolant",c.coolant)
	c.liquid.set_shader_parameter("charge",c.charge)
	c.liquid.set_shader_parameter("heat",c.heat)
	c.salvage_cooldown = maxf(0,c.salvage_cooldown-delta)
	c.disabled = maxf(0,c.disabled-delta)
	if c.disabled > 0:
		body.velocity = Vector3.ZERO
		return
	if c.get("encounter","") == "charged_warden" and game.hatched and game.player != null and body.position.distance_to(game.player.position) < 4.0:
		c.attack_clock -= delta
		if c.attack_clock <= 0:
			c.attack_clock = 2.0;game.integrity = maxf(0,game.integrity-3);game.energy = maxf(0,game.energy-2)
			game.notify("WARDEN DISCHARGE • Unplug its coolant valve to interrupt [T / hold E].")
	c.target = game.navigation.select_target(c.target)
	var resource: Dictionary = game.resources[int(c.target)%game.resources.size()]
	var offset: Vector3 = resource.node.position-body.position;offset.y = 0
	var direction = offset.normalized()
	if not c.hover:
		c.route_clock -= delta
		if c.path_target != c.target or c.route_clock < 0:
			c.path = game.navigation.route(body.position,resource.node.position);c.path_index = 0;c.path_target = c.target;c.route_clock = 3.0+fposmod(c.phase*0.367,1.2)
		while c.path_index < c.path.size() and Vector2(body.position.x,body.position.z).distance_to(c.path[c.path_index]) < 0.55: c.path_index += 1
		if c.path_index < c.path.size():
			var waypoint: Vector2 = c.path[c.path_index]
			var routed = Vector3(waypoint.x-body.position.x,0,waypoint.y-body.position.z).normalized()
			if c.path_index == 0 and routed.dot(direction) < 0.8: c.turns += 1
			direction = routed
	var speed = (2.15 if c.hover else 1.65)*(0.65+0.35*c.charge)
	var ground: float = game.height_at(body.position.x,body.position.z)
	if not c.hover:
		if game.player != null:
			var away = body.position-game.player.position;away.y = 0
			if away.length() < 2.4 and away.length() > 0.05:
				c.steer = away.normalized();c.avoid = 0.7
		c.avoid = maxf(0,c.avoid-delta)
		if c.avoid > 0: direction = c.steer
		# A roller can use the PCB ramps, but cannot climb a vertical board edge.
		var found = false
		for angle in [0.0,0.7,-0.7,1.4,-1.4,2.1,-2.1,PI]:
			var candidate = direction.rotated(Vector3.UP,angle)
			var safe = true
			for side in [-0.62,0.0,0.62]:
				var ahead = body.position+candidate*1.4+candidate.cross(Vector3.UP)*side
				if absf(game.height_at(ahead.x,ahead.z)-ground) > 0.62 or not game.navigation.is_safe(ahead) or absf(ahead.x) > 114 or absf(ahead.z) > 114:
					safe = false;break
			if safe and not body.test_move(body.global_transform,candidate*0.75):
				if angle != 0:
					c.steer = candidate;c.avoid = c.rng.randf_range(1.4,3.0);c.turns += 1
				direction = candidate;found = true;break
		if not found: speed = 0
	var before = body.position
	body.velocity.x = direction.x*speed;body.velocity.z = direction.z*speed
	if c.hover:
		c.hover_timer -= delta
		if c.hover_timer <= 0:
			c.hover_timer = c.rng.randf_range(2.5,6.0);c.hover_goal = c.rng.randf_range(1.3,2.65)
		var ahead = body.position+direction*2.5
		var obstacle = maxf(ground,game.height_at(ahead.x,ahead.z))
		if obstacle+0.95 > body.position.y and c.maneuver <= 0:
			c.maneuver_duration = c.rng.randf_range(1.0,1.7);c.maneuver = c.maneuver_duration;c.flips += 1
		c.maneuver = maxf(0,c.maneuver-delta)
		var clearance = obstacle+c.hover_goal+sin(game.time*1.2+c.phase)*0.12
		body.velocity.y = clampf((clearance-body.position.y)*3,-2.0,3.5)
		if clearance-body.position.y > 0.6:
			body.velocity.x *= 0.12;body.velocity.z *= 0.12
	else:
		body.velocity.y -= 18*delta
		body.floor_snap_length = 0.4
	body.move_and_slide()
	var distance = Vector2(body.position.x-before.x,body.position.z-before.z).length()
	if not c.hover:
		c.stuck = c.stuck+delta if distance < speed*delta*0.12 else maxf(0,c.stuck-delta*2)
		if c.stuck > 0.45:
			c.steer = direction.rotated(Vector3.UP,c.rng.randf_range(2.0,4.2));c.avoid = 3.0;c.stuck = 0;c.turns += 1
			# Abandon an inaccessible destination; carrying organisms retain their cargo.
			c.target = (int(c.target)+5)%game.resources.size()
	c.travel += distance;c.roll += distance/0.70
	c.rig.rotation.y = lerp_angle(c.rig.rotation.y,atan2(-direction.x,-direction.z),minf(1,delta*4))
	if not c.hover:
		# A cohesive soft mass rolls its contact wave, without rigid wheels or ground penetration.
		c.drum.rotation.z = sin(c.roll*0.8)*0.07
		c.skin.set_shader_parameter("roll_phase",c.roll)
		c.tank.scale = Vector3(0.46,0.45+sin(c.roll*3)*0.015,0.10)
	else:
		c.rig.rotation.z = sin(game.time*1.8+c.phase)*0.035
		c.drum.rotation.z = TAU*(1-c.maneuver/c.maneuver_duration) if c.maneuver > 0 else 0.0
		c.rig.rotation.x = lerpf(c.rig.rotation.x,clampf(-body.velocity.y*0.10,-0.35,0.35),minf(1,delta*5))
		for jet in c.jets: jet.scale.y = 0.75+absf(body.velocity.y)*0.2+sin(game.time*23+c.phase)*0.08
	c.charge = clampf(c.charge-delta*(0.002 if c.hover else 0.0007),0.05,1)
	c.heat = move_toward(c.heat,0.2+body.velocity.length()*0.1,delta*0.08*c.coolant)
	c.coolant = maxf(0.15,c.coolant-delta*0.0005)
	if offset.length() < 1.7:
		if c.collecting:
			if resource.cooldown <= 0 and resource.charge > 0.05:
				var amount = minf(0.3,resource.charge)
				resource.charge -= amount;c.carried += amount;c.charge = minf(1,c.charge+amount)
				c.coolant = minf(1,c.coolant+0.12)
				c.collecting = false
			c.target = (int(c.target)+1)%game.resources.size()
		else:
			# Transport happens in space: regeneration is applied only at the destination.
			resource.cooldown = maxf(0,resource.cooldown-c.carried*40)
			resource.charge = minf(1,resource.charge+c.carried*0.5)
			c.carried = 0.0;c.delivered += 1;c.collecting = true
			c.target = (int(c.target)+7)%game.resources.size()
	c.core.scale = Vector3(0.34,0.18+c.carried*0.35,0.07)
	c.skin.set_shader_parameter("charge",c.charge)
