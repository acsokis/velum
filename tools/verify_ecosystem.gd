extends SceneTree
var game
func _initialize(): call_deferred("run")
func check(value: bool, message: String) -> bool:
	if not value: push_error(message);quit(1)
	return value
func run():
	game = load("res://main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.weather.set_process(false)
	if not check(game.world_art.batched_sources > 3000 and game.world_art.batch_count < 600,"Static component batching"): return
	await physics_frame
	var roller: Dictionary = game.creatures.filter(func(c): return not c.hover)[0];var hover: Dictionary = game.creatures.filter(func(c): return c.hover)[0]
	roller.node.position = Vector3(11.6,game.height_at(11.6,-20)+0.70,-20);roller.target = 0
	hover.node.position = Vector3(11.6,game.height_at(11.6,-17)+1.35,-17);hover.target = 1
	game.resources[0].node.position = Vector3(30,3,-20)
	game.resources[1].node.position = Vector3(30,3,-17)
	var crossed = false;var max_y = 0.0;var moved = roller.travel
	for i in range(720):
		await physics_frame
		game.time += 1.0/60
		game.organisms.step(roller,1.0/60);game.organisms.step(hover,1.0/60)
		if hover.node.position.x > 14: crossed = true
		max_y = maxf(max_y,hover.node.position.y)
	if not check(roller.turns > 0 and roller.travel-moved > 6,"Roller changes direction instead of sticking to board side"): return
	if not check(crossed and hover.flips > 0 and max_y > 4,"Skimmer climbs real PCB wall with thrust maneuver"): return
	var network = game.weather.signals
	network.impact(Vector3(1,game.height_at(1,-5),-5))
	if not check(network.packets.size() == 1,"Rain creates routed packet"): return
	var packet: Dictionary = network.packets[0];var target: Dictionary = game.world_art.plants[packet.target]
	var energy_before: float = target.energy
	var length = 0.0
	for i in range(1,packet.points.size()):
		var segment: Vector3 = packet.points[i]-packet.points[i-1]
		if not check(absf(segment.x) < 0.001 or absf(segment.z) < 0.001,"Signal follows axis-aligned PCB buses / spurs"): return
		length += segment.length()
	network.step(length/18)
	if not check(is_equal_approx(target.energy,energy_before),"No energy before packet arrives"): return
	network.step(length/9+1)
	if not check(network.received == 1 and target.energy > energy_before,"Actual plant energy delivery"): return
	var weather = game.weather
	weather.rng.seed = 123456;var kinds = {};var durations = {}
	for i in range(30):
		weather.choose_weather();kinds[weather.weather_kind] = true;durations[weather.remaining] = true
	if not check(kinds.size() == 5 and durations.size() > 20,"Random weather kinds and durations"): return
	var saved: Dictionary = weather.snapshot_state()
	weather.choose_weather();var expected: Dictionary = weather.snapshot_state()
	weather.restore_state(saved);weather.choose_weather()
	if not check(weather.weather_kind == expected.kind and is_equal_approx(weather.remaining,expected.remaining),"Weather RNG save/restore continuity"): return
	weather.strength = 0;weather.day_time = 0.5;weather.update_daylight();var noon: float = game.directional_sun.light_energy
	weather.day_time = 0;weather.update_daylight()
	if not check(noon > 1 and game.directional_sun.light_energy < 0.2,"Day/night lighting"): return
	weather.weather_kind = 3;weather.target_strength = 1;weather.strength = 1;weather.enabled = true;weather.flashes = true;weather.clock = 27
	weather._process(0)
	if not check(weather.rain.visible and weather.inscription.visible,"Storm render state"): return
	weather.flashes = false;weather._process(0)
	if not check(not weather.inscription.visible,"Flash opt-out"): return
	weather.enabled = false;weather._process(0)
	if not check(not weather.rain.visible,"Weather opt-out"): return
	if DisplayServer.get_name() != "headless":
		game.hatched = true;game.shell.visible = false
		game.camera.global_position = Vector3(6,5,10);game.camera.look_at(Vector3(0,5,-18))
		for scene in [["sunrise",0.26,0],["sunset-storm",0.74,1],["night",0.03,0.3]]:
			weather.day_time = scene[1];weather.strength = scene[2];weather.enabled = true;weather.flashes = true
			weather._process(0)
			for i in range(8): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://runtime/ecosystem-"+scene[0]+".png")
	print("VELUM_ECOSYSTEM_PASS roller_turns=",roller.turns," roller_travel=",roller.travel-moved," hover_crossed=",crossed," flips=",hover.flips," peak=",max_y," packet_route=",length," received=",network.received," random_weather=",kinds.size()," batches=",game.world_art.batch_count)
	quit(0)
