extends RefCounted
## Natural population and autonomous encounters share placement, but not implicit budgets.
const LOCAL_LIMIT = 9
const GLOBAL_NATURAL_LIMIT = 18
const HARD_LIMIT = 28
var game
var rng = RandomNumberGenerator.new()
var clock = 0.0
var sequence = 9
var accumulator = 0.0
var tethers: Array[Dictionary] = []
var definitions: Array[Dictionary] = []

func setup(owner_game):
	game = owner_game;rng.seed = game.WORLD_SEED ^ 0x5A71
	tethers = [{"id":"shell-01","position":Vector3.ZERO}]
	definitions = [
		{"id":"reclaimer_den","position":game.navigation.safe_spawn(Vector3(-34,0,-12)),"limit":2,"creatures_consume_natural":false,"nest_consumes_natural":false,"toughness":1.6,"hover":false,"last":-100.0},
		{"id":"charged_warden","position":game.navigation.safe_spawn(Vector3(32,3,-22)),"limit":1,"creatures_consume_natural":true,"nest_consumes_natural":false,"toughness":2.5,"hover":true,"last":-100.0}
	]
	for definition in definitions:
		var nest = Node3D.new();nest.name = definition.id;game.add_child(nest);nest.position = definition.position
		definition["nest"] = nest
		for side in [-1,1]:
			game.world_art.box(nest,Vector3(side*1.25,0.35,0),Vector3(0.45,0.7,2.8),game.world_art.alloy)
		game.world_art.box(nest,Vector3(0,0.12,0),Vector3(2.5,0.22,2.5),game.world_art.oxide)
		game.world_art.cylinder(nest,Vector3(0,0.4,0),0.55,0.55,game.mat(Color("58cba5"),0.5))

func nearest_tether(position: Vector3) -> Dictionary:
	var best = tethers[0]
	for tether in tethers:
		if tether.position.distance_squared_to(position) < best.position.distance_squared_to(position): best = tether
	return best

func natural_count(position: Vector3, radius = INF) -> int:
	var count = 0
	for creature in game.creatures:
		if creature.get("counts_natural",true) and creature.node.position.distance_to(position) <= radius: count += 1
	for definition in definitions:
		if definition.nest_consumes_natural and definition.position.distance_to(position) <= radius: count += 1
	return count

func placement(wish: Vector3, tether: Dictionary, minimum_distance = 8.0) -> Vector3:
	var point = game.navigation.safe_spawn(wish)
	if Vector2(point.x-tether.position.x,point.z-tether.position.z).length() < minimum_distance: return Vector3.INF
	for creature in game.creatures:
		if creature.node.position.distance_to(point+Vector3.UP) < 2.6: return Vector3.INF
	return point

func add_natural(index: int, wish: Vector3):
	var point = placement(wish,nearest_tether(wish),0)
	if not point.is_finite():
		for attempt in range(20):
			point = placement(wish+Vector3(rng.randf_range(-8,8),0,rng.randf_range(-8,8)),nearest_tether(wish),0)
			if point.is_finite(): break
	if not point.is_finite(): return
	var hover = rng.randf() < (0.18 if point.x < 0 else 0.55)
	var creature = game.organisms.create(index,point,1 if hover else 0)
	creature["origin"] = "natural";creature["encounter"] = "";creature["counts_natural"] = true;creature["tether"] = nearest_tether(point).id
	creature["toughness"] = 1.0;creature["shell_integrity"] = 100.0;creature["far_time"] = 0.0
	game.creatures.append(creature)

func encounter_count(id: String) -> int:
	var count = 0
	for creature in game.creatures:
		if creature.get("encounter","") == id: count += 1
	return count

func emit_encounter(id: String) -> bool:
	var definition: Dictionary = {}
	for entry in definitions:
		if entry.id == id: definition = entry;break
	if definition.is_empty() or game.creatures.size() >= HARD_LIMIT: return false
	if encounter_count(id) >= definition.limit: return false
	var tether = nearest_tether(definition.position)
	if definition.creatures_consume_natural and (natural_count(tether.position,60) >= LOCAL_LIMIT or natural_count(Vector3.ZERO) >= GLOBAL_NATURAL_LIMIT): return false
	var point = Vector3.INF
	for attempt in range(12):
		point = placement(definition.position+Vector3(rng.randf_range(-5,5),0,rng.randf_range(-5,5)),tether,6)
		if point.is_finite(): break
	if not point.is_finite(): return false
	var creature = game.organisms.create(sequence,point,1 if definition.hover else 0);sequence += 1
	creature["origin"] = "autonomous";creature["encounter"] = id;creature["counts_natural"] = definition.creatures_consume_natural
	creature["tether"] = tether.id;creature["toughness"] = definition.toughness;creature["shell_integrity"] = 100*definition.toughness;creature["far_time"] = 0.0
	game.creatures.append(creature);definition.last = clock
	return true

func despawn(creature: Dictionary):
	game.creatures.erase(creature);creature.node.queue_free()

func tick(delta: float):
	clock += delta;accumulator += delta
	if accumulator < 1 or game.player == null: return
	var elapsed = accumulator;accumulator = 0
	tethers[0].position = game.player.position
	for i in range(game.creatures.size()-1,-1,-1):
		var creature = game.creatures[i];var tether = nearest_tether(creature.node.position)
		creature.far_time = creature.get("far_time",0.0)+elapsed if creature.node.position.distance_to(tether.position) > 80 else 0.0
		if creature.far_time > 12: despawn(creature)
	if not game.hatched: return
	# Encounter reservations are evaluated before natural refill, avoiding budget starvation.
	for definition in definitions:
		var tether = nearest_tether(definition.position)
		if tether.position.distance_to(definition.position) < 40 and tether.position.length() > 12 and clock-definition.last > 35:
			emit_encounter(definition.id)
	for tether in tethers:
		if natural_count(tether.position,60) >= LOCAL_LIMIT or natural_count(Vector3.ZERO) >= GLOBAL_NATURAL_LIMIT or game.creatures.size() >= HARD_LIMIT: continue
		for attempt in range(10):
			var a = rng.randf()*TAU;var distance = rng.randf_range(18,42)
			var point = placement(tether.position+Vector3(sin(a)*distance,0,cos(a)*distance),tether)
			if point.is_finite(): add_natural(sequence,point);sequence += 1;break

func report() -> String:
	var autonomous = 0
	for creature in game.creatures:
		if creature.get("origin","") == "autonomous": autonomous += 1
	return "Natural budget %d/%d local • Autonomous %d\nReclaimer den: 2 max, separate budget\nCharged warden: 1 max, consumes natural budget" % [natural_count(game.player.position,60),LOCAL_LIMIT,autonomous]

func snapshot_state() -> Dictionary:
	var population: Array = []
	for creature in game.creatures:
		var record = {"id":int(creature.phase),"x":creature.node.position.x,"y":creature.node.position.y,"z":creature.node.position.z}
		for key in ["hover","target","carried","charge","coolant","heat","disabled","salvage_cooldown","origin","encounter","counts_natural","tether","toughness","shell_integrity"]: record[key] = creature.get(key)
		population.append(record)
	var encounters = {}
	for definition in definitions: encounters[definition.id] = definition.last
	return {"creatures":population,"sequence":sequence,"clock":clock,"rng":str(rng.state),"encounters":encounters}

func restore_state(state: Dictionary):
	if not state.get("creatures") is Array: return
	for creature in game.creatures: creature.node.queue_free()
	game.creatures.clear()
	for record in state.creatures.slice(0,HARD_LIMIT):
		if not record is Dictionary: continue
		var point = Vector3(record.get("x",0),record.get("y",0),record.get("z",0))
		if not point.is_finite(): continue
		var creature = game.organisms.create(int(record.get("id",0)),point,1 if record.get("hover",false) else 0)
		for key in ["target","carried","charge","coolant","heat","disabled","salvage_cooldown","origin","encounter","counts_natural","tether","toughness","shell_integrity"]:
			if record.has(key): creature[key] = record[key]
		creature["far_time"] = 0.0;game.creatures.append(creature)
	sequence = maxi(9,int(state.get("sequence",sequence)));clock = maxf(0,float(state.get("clock",clock)))
	if state.has("rng"): rng.state = int(state.rng)
	for definition in definitions: definition.last = float(state.get("encounters",{}).get(definition.id,-100))
