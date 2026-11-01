extends SceneTree
var game
func _initialize(): call_deferred("run")
func check(value: bool, message: String) -> bool:
	if not value: push_error(message);quit(1)
	return value
func run():
	game = load("res://main.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false);game.set_process(false);game.weather.set_process(false)
	await physics_frame
	var population = game.spawning
	if not check(not game.weather.sound and not game.weather.audio.playing,"Music is OFF on every startup"): return
	if not check(game.creatures.size() == 9 and population.natural_count(Vector3.ZERO) == 9,"Initial natural budget"): return
	if not check(not population.emit_encounter("charged_warden"),"Counted encounter respects full natural budget"): return
	if not check(population.emit_encounter("reclaimer_den") and population.emit_encounter("reclaimer_den"),"Separate autonomous budget"): return
	if not check(population.natural_count(Vector3.ZERO) == 9 and not population.emit_encounter("reclaimer_den"),"Separate encounter hard cap"): return
	population.despawn(game.creatures[0])
	if not check(population.emit_encounter("charged_warden") and population.natural_count(Vector3.ZERO) == 9,"Counted encounter consumes released slot"): return
	for creature in game.creatures:
		if not check(game.navigation.is_safe(creature.node.position),"All natural/autonomous placements in connected clearance network"): return
	population.tethers.append({"id":"qa-second-player","position":population.definitions[0].position})
	if not check(population.nearest_tether(population.definitions[0].position).id == "qa-second-player","Nearest-player tether selection"): return
	population.tethers.pop_back()
	var saved_population: Dictionary = population.snapshot_state()
	population.restore_state(saved_population)
	if not check(game.creatures.size() == 11 and population.encounter_count("charged_warden") == 1,"Population save/restore preserves origins and caps"): return
	var network = game.weather.signals
	for cell in network.cells:
		var id: int = network.cells[cell]
		if not check(not network.graph.get_id_path(0,id).is_empty(),"Every circuit node connects to condenser"): return
		if network.graph.get_point_connections(id).size() == 1:
			if not check(cell in network.anchors,"Every circuit leaf has a component socket"): return
	game.weather.strength = 1;game.weather.clock = 27
	var valid_drops = 0
	for i in range(100):
		var drop = {"ready":false};game.weather.spawn_drop(drop)
		if drop.ready:
			valid_drops += 1
			if not check(drop.cloud_cover > 0.55 and is_equal_approx(drop.birth.y,game.weather.cloud_altitude),"Rain is born inside cloud-covered 35m layer"): return
	if not check(valid_drops > 0,"Cloud emitter can rain"): return
	game.weather.heat_mist.step(0.6)
	if not check(game.weather.heat_mist.vapor_strength > 0,"Local warm-source condensation"): return
	if not check(game.weather.audio.stream != null and game.weather.audio.stream.get_length() > 30,"Licensed music decodes as a full recording"): return
	game.hatched = true;game.menu.hide();game.player.position = game.resources[0].node.position+Vector3(0,0.6,0)
	var recovery = game.salvage;recovery.tool = 1;var energy_before = game.energy
	recovery.target = {"type":"resource","data":game.resources[0],"node":game.resources[0].node}
	if not check(recovery.complete() and game.ceramic == 1 and game.temperature > 36,"Desoldering recovers ceramic and produces heat"): return
	game.player.position = game.resources[1].node.position+Vector3(0,0.6,0);recovery.tool = 0
	recovery.target = {"type":"resource","data":game.resources[1],"node":game.resources[1].node}
	if not check(recovery.complete() and game.fiber == 1,"Connector unplugging"): return
	recovery.tool = 2;var structure = game.integrity
	game.player.position = game.resources[2].node.position+Vector3(0,0.6,0)
	recovery.target = {"type":"resource","data":game.resources[2],"node":game.resources[2].node}
	if not check(recovery.complete() and game.integrity < structure and game.resources[2].cooldown == 75,"RIP extraction has integrity and regrowth costs"): return
	var warden: Dictionary = game.creatures.filter(func(c): return c.get("encounter","") == "charged_warden")[0]
	recovery.tool = 0;recovery.target = {"type":"creature","data":warden,"node":warden.node}
	if not check(recovery.complete() and warden.disabled == 14 and warden.shell_integrity == 250,"Tough warden has a working interruptible valve"): return
	print("VELUM_SYSTEMS_PASS natural=9 autonomous=3 counted_warden=1 safe_nodes=",game.navigation.points.size()," circuit_nodes=",network.cells.size()," sockets=",network.terminals.size()," valid_cloud_drops=",valid_drops," music_seconds=",game.weather.audio.stream.get_length()," salvage_modes=3")
	quit(0)
