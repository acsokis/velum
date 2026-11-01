extends RefCounted
## One connected physical copper graph; every leaf terminates at a component socket.
const PITCH = 3.5
const OFFSET = 0.82*PITCH
var game
var packets: Array[Dictionary] = []
var markers: MultiMeshInstance3D
var received = 0
var impacts = 0
var trails: Array[Vector3] = []
var graph = AStar3D.new()
var cells: Dictionary = {}
var edges: Dictionary = {}
var anchors: Array[Vector2i] = []
var terminals: Array[Vector3] = []
var trace_builder: SurfaceTool
var channel_builder: SurfaceTool
var leaf_count = 0

func junction(p: Vector3) -> Vector3:
	return surface(Vector3(roundf((p.x-OFFSET)/PITCH)*PITCH+OFFSET,0,roundf((p.z-OFFSET)/PITCH)*PITCH+OFFSET))
func surface(p: Vector3) -> Vector3:
	return Vector3(p.x,game.height_at(p.x,p.z)+0.065,p.z)
func setup(owner_game):
	game = owner_game
	markers = MultiMeshInstance3D.new();markers.name = "RainSignalPackets"
	markers.multimesh = MultiMesh.new();markers.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	markers.multimesh.instance_count = 96;markers.multimesh.visible_instance_count = 0
	var ball = SphereMesh.new();ball.radius = 0.095;ball.height = 0.19;ball.radial_segments = 8;ball.rings = 4
	var material = game.world_art.material(Color("59ffc7"),0.3,0.5)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED;ball.material = material
	markers.multimesh.mesh = ball;markers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child(markers)
	build_network()

func cell_at(p: Vector3) -> Vector2i:
	return Vector2i(roundi((p.x-OFFSET)/PITCH),roundi((p.z-OFFSET)/PITCH))
func cell_point(cell: Vector2i) -> Vector3:
	return surface(Vector3(cell.x*PITCH+OFFSET,0,cell.y*PITCH+OFFSET))
func add_cell(cell: Vector2i) -> int:
	if not cells.has(cell):
		var id = cells.size();cells[cell] = id;graph.add_point(id,cell_point(cell))
	return cells[cell]

func build_network():
	trace_builder = SurfaceTool.new();trace_builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	channel_builder = SurfaceTool.new();channel_builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	terminals.append(Vector3(3,0,0)) # Egg condenser / power root.
	for plant in game.world_art.plants: terminals.append(plant.node.position)
	for resource in game.resources: terminals.append(resource.node.position)
	for prop in game.world_art.props: terminals.append(prop.position)
	for endpoint in terminals:
		var cell = cell_at(endpoint);add_cell(cell)
		if not anchors.is_empty():
			var nearest = anchors[0];var distance = INF
			for previous in anchors:
				var d = abs(cell.x-previous.x)+abs(cell.y-previous.y)
				if d < distance: nearest = previous;distance = d
			var cursor = cell
			while cursor != nearest:
				var next = cursor
				if cursor.x != nearest.x: next.x += 1 if nearest.x > cursor.x else -1
				else: next.y += 1 if nearest.y > cursor.y else -1
				var a = add_cell(cursor);var b = add_cell(next)
				var key = "%d:%d" % [mini(a,b),maxi(a,b)]
				if not edges.has(key):
					edges[key] = true;graph.connect_points(a,b)
					draw_route(surface_route([cell_point(cursor),cell_point(next)]))
				cursor = next
		anchors.append(cell)
		var j = cell_point(cell)
		draw_route(surface_route([j,Vector3(endpoint.x,j.y,j.z),endpoint]))
	var trace_material = game.world_art.copper.duplicate();trace_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for entry in [[trace_builder,trace_material,"ConnectedCopperTraces"],[channel_builder,game.world_art.plastic,"EtchedTraceChannels"]]:
		var mesh = MeshInstance3D.new();mesh.name = entry[2];mesh.mesh = entry[0].commit();mesh.material_override = entry[1]
		mesh.gi_mode = GeometryInstance3D.GI_MODE_STATIC;mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;game.add_child(mesh)
	# A persistent socket remains after unplugging a collectible, so copper never ends in empty space.
	var sockets = MultiMeshInstance3D.new();sockets.name = "CircuitSockets";sockets.multimesh = MultiMesh.new()
	sockets.multimesh.transform_format = MultiMesh.TRANSFORM_3D;sockets.multimesh.instance_count = terminals.size()
	var socket = CylinderMesh.new();socket.top_radius = 0.17;socket.bottom_radius = 0.17;socket.height = 0.035;socket.radial_segments = 12;socket.material = game.world_art.solder
	sockets.multimesh.mesh = socket;sockets.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;game.add_child(sockets)
	for i in range(terminals.size()): sockets.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,surface(terminals[i])))
	for cell in cells:
		if graph.get_point_connections(cells[cell]).size() == 1:
			leaf_count += 1
			if cell not in anchors: push_error("Circuit leaf without a component socket")
	print("VELUM_CIRCUIT nodes=",cells.size()," edges=",edges.size()," sockets=",terminals.size()," leaves=",leaf_count)

func draw_route(points: PackedVector3Array):
	var last_side = Vector3.RIGHT
	for i in range(points.size()-1):
		var a: Vector3 = points[i];var b: Vector3 = points[i+1]
		if a.distance_squared_to(b) < 0.00001: continue
		var direction = (b-a).normalized()
		var side = direction.cross(Vector3.UP).normalized()
		if side.length_squared() < 0.1: side = last_side
		else: last_side = side
		for entry in [[trace_builder,0.055,0.008],[channel_builder,0.095,0.0]]:
			var st: SurfaceTool = entry[0];var width: float = entry[1]
			var normal = side.cross(direction).normalized()
			var shift: Vector3 = normal*float(entry[2])
			var corners = [a-side*width+shift,a+side*width+shift,b+side*width+shift,b-side*width+shift]
			for index in [0,2,1,0,3,2]:
				st.set_normal(normal);st.add_vertex(corners[index])

func surface_route(corners: Array) -> PackedVector3Array:
	var route = PackedVector3Array()
	for i in range(corners.size()-1):
		var first: Vector3 = corners[i];var last: Vector3 = corners[i+1]
		var steps = maxi(1,ceili(Vector2(last.x-first.x,last.z-first.z).length()/0.45))
		for step_index in range(steps+1):
			var p = surface(first.lerp(last,float(step_index)/steps))
			if not route.is_empty() and absf(p.y-route[-1].y) > 0.3:
				var low = route[-1];var high = p
				for attempt in range(10):
					var middle = surface((low+high)*0.5)
					if absf(middle.y-route[-1].y) < 0.3: low = middle
					else: high = middle
				var edge = (low+high)*0.5
				route.append(Vector3(edge.x,route[-1].y,edge.z));route.append(Vector3(edge.x,p.y,edge.z))
			if route.is_empty() or route[-1].distance_squared_to(p) > 0.00001: route.append(p)
	return route

func path_between(start: Vector3, destination: Vector3) -> PackedVector3Array:
	var a = graph.get_closest_point(surface(start));var b = cells[cell_at(destination)]
	var points = graph.get_point_path(a,b);var corners: Array = []
	for point in points: corners.append(point)
	var end = cell_point(cell_at(destination));corners.append(Vector3(destination.x,end.y,end.z));corners.append(destination)
	return surface_route(corners)

func impact(position: Vector3):
	if packets.size() >= 16 or game.world_art.plants.is_empty(): return
	var best = 0;var distance = INF
	for i in range(game.world_art.plants.size()):
		var d: float = game.world_art.plants[i].node.position.distance_squared_to(position)
		if d < distance: best = i;distance = d
	var destination: Vector3 = game.world_art.plants[best].node.position
	var route = path_between(position,destination)
	packets.append({"points":route,"segment":0,"position":route[0],"target":best,"trail":[surface(position)]})
	impacts += 1

func step(delta: float):
	var count = 0
	for i in range(packets.size()-1,-1,-1):
		var packet = packets[i];var remaining = delta*9.0
		while remaining > 0 and packet.segment < packet.points.size()-1:
			var next: Vector3 = packet.points[packet.segment+1]
			var length: float = packet.position.distance_to(next)
			if length <= remaining:
				packet.position = next;remaining -= length;packet.segment += 1
			else:
				packet.position = packet.position.move_toward(next,remaining);remaining = 0
		packet.trail.push_front(packet.position)
		if packet.trail.size() > 5: packet.trail.pop_back()
		for point in packet.trail:
			if count >= 96: break
			markers.multimesh.set_instance_transform(count,Transform3D(Basis.IDENTITY,point));count += 1
		if packet.segment == packet.points.size()-1:
			var plant = game.world_art.plants[packet.target]
			plant.energy = minf(1,plant.energy+0.08);plant.received += 1;received += 1
			# Plant discharge accelerates the nearest harvestable deposit.
			var nearest: Dictionary = game.resources[0]
			for resource in game.resources:
				if resource.node.position.distance_squared_to(plant.node.position) < nearest.node.position.distance_squared_to(plant.node.position): nearest = resource
			nearest.charge = minf(1,nearest.charge+0.025);nearest.cooldown = maxf(0,nearest.cooldown-1.5)
			packets.remove_at(i)
	markers.multimesh.visible_instance_count = count
