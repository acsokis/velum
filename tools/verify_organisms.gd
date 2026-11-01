extends SceneTree
var game
func _initialize():
	call_deferred("run")
func check(value: bool, message: String):
	if not value: push_error(message);quit(1)
	return value
func run():
	game = load("res://main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false)
	var p = Vector3(85,game.height_at(85,85),85)
	var roller: Dictionary = game.creatures.filter(func(c): return not c.hover)[0]
	var hover: Dictionary = game.creatures.filter(func(c): return c.hover)[0]
	game.resources[0].node.position = p+Vector3(0,0,-5)
	game.resources[1].node.position = p+Vector3(0,0,-9)
	game.resources[1].cooldown = 50
	roller.node.position = p+Vector3(0,0.72,0);roller.target = 0
	hover.node.position = p+Vector3(5,1.35,0);hover.target = 0
	if not check(roller.jets.size() == 0 and hover.jets.size() == 3,"Legless locomotion types"): return
	var min_clearance = 100.0;var max_clearance = -100.0
	for i in range(720):
		await physics_frame
		game.time += 1.0/60
		game.organisms.step(roller,1.0/60);game.organisms.step(hover,1.0/60)
		if i > 60:
			var clearance: float = roller.node.position.y-game.height_at(roller.node.position.x,roller.node.position.z)
			min_clearance = minf(min_clearance,clearance);max_clearance = maxf(max_clearance,clearance)
	if not check(min_clearance > 0.60 and max_clearance < 0.80,"Roller must contact floor, not levitate: %f..%f" % [min_clearance,max_clearance]): return
	if not check(roller.travel > 4 and absf(roller.roll-roller.travel/0.70) < 0.001,"Distance-driven rolling"): return
	if not check(roller.delivered > 0 and game.resources[1].cooldown < 50,"Actual transported regeneration"): return
	var hover_clearance: float = hover.node.position.y-game.height_at(hover.node.position.x,hover.node.position.z)
	if not check(hover_clearance > 1.1 and hover_clearance < 3.0,"Randomized thruster ground following"): return
	if not check(roller.coolant < 1 and roller.charge > 0 and hover.heat > 0.15,"Functional reservoirs"): return
	if not check(roller.liquid is ShaderMaterial and roller.flow_clock > 0,"Animated coolant material advances with simulation"): return
	if not check(is_equal_approx(float(roller.liquid.get_shader_parameter("coolant")),float(roller.coolant)) or absf(float(roller.liquid.get_shader_parameter("coolant"))-roller.coolant) < 0.01,"Visible fluid follows reservoir state"): return
	var running_clock: float = roller.flow_clock
	roller.disabled = 1;game.organisms.step(roller,0.1)
	if not check(roller.flow_clock-running_clock < 0.01,"Unplugged pump slows fluid circulation"): return
	roller.disabled = 0
	game.weather.clock = 27;game.weather.weather_kind = 3;game.weather.strength = 1;game.weather.target_strength = 1;game.weather.remaining = 100;game.weather._process(0)
	if not check(game.weather.strength > 0.9 and game.weather.rain.visible and game.weather.inscription.visible,"Matrix weather / inscription discharge"): return
	game.weather.flashes = false;game.weather._process(0)
	if not check(not game.weather.inscription.visible and game.weather.overlay.color.a == 0,"Flash opt-out"): return
	game.weather.enabled = false;game.weather._process(0)
	if not check(not game.weather.rain.visible,"Weather opt-out"): return
	game.weather.enabled = true;game.weather.flashes = true;game.weather._process(0)
	if DisplayServer.get_name() != "headless":
		game.hatched = true;game.shell.visible = false;game.menu.hide()
		roller.node.position = p+Vector3(-1,0.70,0)
		hover.node.position = p+Vector3(1.5,1.35,-1)
		roller.rig.rotation.y = PI;hover.rig.rotation.y = PI
		game.camera.global_position = p+Vector3(0,2.1,5)
		game.camera.look_at(p+Vector3(0,0.85,0))
		for i in range(12): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://runtime/organisms.png")
	print("VELUM_ORGANISMS_PASS grounded_roller=",min_clearance,"..",max_clearance," travel=",roller.travel," deliveries=",roller.delivered," hover_clearance=",hover_clearance)
	quit(0)
