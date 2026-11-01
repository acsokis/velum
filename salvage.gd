extends RefCounted
## Deliberate component recovery: connector, solder joint, or destructive extraction.
const TOOLS = ["UNPLUG", "DESOLDER", "RIP"]
var game
var tool = 0
var target: Dictionary = {}
var progress = 0.0
var duration = 1.0
var recovered = 0

func setup(owner_game): game = owner_game
func cycle():
	tool = (tool+1)%TOOLS.size();cancel();game.notify("SALVAGE TOOL • "+TOOLS[tool]+" • Hold E on a scanned component.")
func cancel(): target = {};progress = 0
func acquire() -> Dictionary:
	var best: Dictionary = {};var distance = 3.5
	for resource in game.resources:
		var d: float = game.player.position.distance_to(resource.node.position)
		if resource.cooldown <= 0 and d < distance: best = {"type":"resource","data":resource,"node":resource.node};distance = d
	for creature in game.creatures:
		var d: float = game.player.position.distance_to(creature.node.position)
		if creature.salvage_cooldown <= 0 and d < distance: best = {"type":"creature","data":creature,"node":creature.node};distance = d
	return best
func begin() -> bool:
	if not game.hatched: return false
	target = acquire();progress = 0
	if target.is_empty(): game.notify("No component in 3.5m. Scan [3], select tool [T], hold E.");return false
	if target.type == "resource":
		var required = 1 if target.data.kind == "ceramic" else 0
		if tool != required and tool != 2:
			game.notify("%s connection: choose %s [T], or RIP with structural damage." % [target.data.kind,TOOLS[required]]);cancel();return false
		duration = [0.7,2.0,0.8][tool]
	elif tool == 1:
		game.notify("Live organism: UNPLUG its coolant valve, or RIP its shell.");cancel();return false
	else: duration = (1.2 if tool == 0 else 1.8)*target.data.get("toughness",1.0)
	if tool == 1 and game.energy < 6: game.notify("Desoldering requires 6 energy.");cancel();return false
	return true
func tick(delta: float, held: bool):
	if target.is_empty(): return
	if not held or game.menu.visible or not is_instance_valid(target.node) or target.node.position.distance_to(game.player.position) > 3.7:
		cancel();return
	progress += delta
	if progress >= duration: complete()
func complete() -> bool:
	if target.is_empty(): return false
	var selected = target;target = {};progress = 0
	if selected.type == "resource":
		if selected.data.cooldown > 0: return false
		if tool == 1:
			if game.energy < 6: return false
			game.energy -= 6;game.temperature += 1.2
		if not game.gather(selected.data): return false
		if tool == 2:
			game.integrity = maxf(1,game.integrity-5);game.fluid = maxf(0,game.fluid-2);selected.data.cooldown = 75
	else:
		var creature: Dictionary = selected.data
		if creature.salvage_cooldown > 0: return false
		if tool == 0:
			game.fluid = minf(100,game.fluid+minf(12,creature.coolant*12))
			creature.coolant = maxf(0.05,creature.coolant-0.4);creature.charge = maxf(0.05,creature.charge-0.2)
			creature.disabled = 14;creature.salvage_cooldown = 24
			game.notify("COOLANT VALVE UNPLUGGED • Organism interrupted for 14s. Fluid recovered.")
		else:
			game.integrity = maxf(1,game.integrity-5);game.ceramic += 1
			creature.shell_integrity = creature.get("shell_integrity",100.0)-40;creature.disabled = 6;creature.salvage_cooldown = 8
			if creature.shell_integrity <= 0:
				game.ceramic += 1;game.fiber += 1;game.spawning.despawn(creature)
			game.notify("SHELL EXTRACTED • Ceramic recovered. Forced extraction costs integrity.")
	recovered += 1
	return true
func status() -> String:
	return "Tool %s [T] • Hold E%s" % [TOOLS[tool]," • %.0f%%" % (progress/duration*100) if not target.is_empty() else ""]
