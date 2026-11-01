extends RefCounted
## Terrain clearance graph: only the connected, non-leaf survey network is usable.
const CELL = 1.5
const REGION = Rect2i(-75,-75,151,151)
var game
var grid = AStarGrid2D.new()
var usable: Dictionary = {}
var points: Array[Vector2i] = []
var rng = RandomNumberGenerator.new()
var reachable_resources: Array[int] = []

func setup(owner_game):
	game = owner_game;rng.seed = game.WORLD_SEED ^ 0xA61
	grid.region = REGION;grid.cell_size = Vector2(CELL,CELL);grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER;grid.update()
	var candidates: Dictionary = {}
	for x in range(REGION.position.x,REGION.end.x):
		for z in range(REGION.position.y,REGION.end.y):
			var h: float = game.height_at(x*CELL,z*CELL)
			var safe = true
			if game.labyrinth != null and not game.labyrinth.clear_at(x*CELL,z*CELL): continue
			for offset in [Vector2(1.05,0),Vector2(-1.05,0),Vector2(0,1.05),Vector2(0,-1.05)]:
				if absf(game.height_at(x*CELL+offset.x,z*CELL+offset.y)-h) > 0.43: safe = false;break
			if safe: candidates[Vector2i(x,z)] = h
	# Keep only the network connected to the hatch. Isolated board-top pockets are excluded.
	var queue: Array[Vector2i] = [Vector2i.ZERO];usable[Vector2i.ZERO] = true
	var cursor = 0
	while cursor < queue.size():
		var current = queue[cursor];cursor += 1
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next = current+offset
			if candidates.has(next) and not usable.has(next) and absf(candidates[next]-candidates[current]) < 0.63:
				usable[next] = true;queue.append(next)
	# Remove leaf corridors iteratively, so rollers are not assigned a cul-de-sac target.
	var changed = true
	while changed:
		changed = false;var remove: Array[Vector2i] = []
		for current in usable:
			var degree = 0
			for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				if usable.has(current+offset): degree += 1
			if degree < 2: remove.append(current)
		for current in remove: usable.erase(current);changed = true
	for x in range(REGION.position.x,REGION.end.x):
		for z in range(REGION.position.y,REGION.end.y): grid.set_point_solid(Vector2i(x,z),not usable.has(Vector2i(x,z)))
	for point in usable: points.append(point)
	print("VELUM_NAVIGATION connected_clearance_nodes=",points.size())

func world_point(cell: Vector2i) -> Vector3:
	return Vector3(cell.x*CELL,game.height_at(cell.x*CELL,cell.y*CELL),cell.y*CELL)
func is_safe(position: Vector3) -> bool:
	return usable.has(Vector2i(roundi(position.x/CELL),roundi(position.z/CELL)))
func closest_cell(position: Vector3) -> Vector2i:
	var start = Vector2i(roundi(position.x/CELL),roundi(position.z/CELL))
	for radius in range(12):
		var best = start;var distance = INF
		for x in range(-radius,radius+1):
			for z in range(-radius,radius+1):
				var cell = start+Vector2i(x,z)
				if not usable.has(cell): continue
				var d = world_point(cell).distance_squared_to(position)
				if d < distance: best = cell;distance = d
		if distance < INF: return best
	return points[rng.randi_range(0,points.size()-1)]
func safe_spawn(position: Vector3) -> Vector3:
	return world_point(closest_cell(position))
func index_resources():
	for i in range(game.resources.size()):
		var position: Vector3 = game.resources[i].node.position
		var nearest = world_point(closest_cell(position))
		if nearest.distance_to(position) < 2.0 and absf(nearest.y-position.y) < 0.55: reachable_resources.append(i)
func select_target(proposed: int) -> int:
	if proposed in reachable_resources: return proposed
	return reachable_resources[rng.randi_range(0,reachable_resources.size()-1)]
func route(start: Vector3, destination: Vector3) -> PackedVector2Array:
	return grid.get_point_path(closest_cell(start),closest_cell(destination))
