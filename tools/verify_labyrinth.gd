extends SceneTree
var failures = 0
func check(value: bool, message: String):
	if not value: failures += 1;push_error(message)
	else: print("MAZE_PASS ",message)
func _initialize(): call_deferred("run")
func run():
	var helper = load("res://labyrinth.gd").new()
	for seed_value in range(24):
		var graph = helper.generate_graph(seed_value,9)
		var seen = {Vector2i.ZERO:true};var queue = [Vector2i.ZERO]
		while not queue.is_empty():
			var p = queue.pop_front()
			for next in graph[p]:
				if not seen.has(next): seen[next] = true;queue.append(next)
		check(seen.size() == 81 and graph == helper.generate_graph(seed_value,9),"connected reproducible graph seed "+str(seed_value))
	var game = load("res://main.tscn").instantiate();root.add_child(game)
	await process_frame
	check(game.labyrinth != null,"actual game starts labyrinth")
	var maze = game.labyrinth
	check(maze.clear_at(0,0) and game.board_terrain.plates.size() > 50 and game.board_terrain.ramps.size() == 7,"layered terrain and ramps retained in maze")
	var unsupported = 0
	for plant in game.world_art.plants:
		var p: Vector3 = plant.node.position
		for side in range(8):
			var a = side*TAU/8
			if absf(game.height_at(p.x+cos(a)*plant.support_radius,p.z+sin(a)*plant.support_radius)-p.y) > 0.13: unsupported += 1
	check(unsupported == 0,"plant footprints supported without cutting through slab edges")
	check(maze.root.get_node("FlowingCoolant").multimesh.instance_count == maze.walls.size()*8,"closed coolant loops on both wall faces")
	var initial_flow: float = maze.flow_clock;maze.step(0.5)
	check(maze.flow_clock > initial_flow and float(maze.coolant_material.get_shader_parameter("flow_clock")) > initial_flow,"wall coolant advances")
	game.hatched = true;game.shell.visible = false
	var origin = maze.section;var next = maze.passages[origin][0]
	game.player.position = Vector3((next.x-origin.x)*101,1,(next.y-origin.y)*101)
	maze.step(0.1)
	check(maze.section == next and game.player.position.distance_to(Vector3(0,game.height_at(0,0)+1,0)) < 0.01,"physical portal crossing streams next section and safe checkpoint")
	var state = maze.snapshot();var old_epoch = maze.epoch
	var old_layout = maze.local_graph()
	maze.restore(state)
	check(maze.epoch == old_epoch+1 and maze.section == next,"load changes section revision and retains logical location")
	check(old_layout != maze.local_graph(),"section revision changes interior passages")
	for r in game.resources: check(maze.clear_at(r.node.position.x,r.node.position.z),"resource socket clear "+str(r.id))
	for target in [Vector2i(2,2),Vector2i(6,2),Vector2i(6,6),Vector2i(4,4),Vector2i(8,8)]:
		maze.section = target;game.player.position = Vector3(0,1,-3);maze.interact()
	check(maze.escaped and maze.collected.size() == 4,"PSU RAM cooler SoC then escape mission")
	game.smoke = true
	check(game.save_game(),"isolated maze save writes")
	maze.collected.clear();maze.escaped = false
	check(game.load_game() and maze.escaped and maze.collected.size() == 4,"actual save/load retains mission and reconfigures safely")
	var vapor = game.weather.heat_mist
	vapor.emit_wake(Vector3.ZERO,Vector3(3,0,0))
	check(vapor.airflow_at(Vector3(0,0,1)).length() > 0.1,"moving actor injects airflow")
	vapor.wakes[0].age = 12
	check(vapor.airflow_at(Vector3(0,0,1)).length() < 0.01,"wake dissipates")
	game.set_physics_process(false)
	# Actual CharacterBody movement must be stopped by a resident maze wall.
	maze.rebuild()
	await physics_frame
	var wall = maze.walls[0]
	var across = Vector3.RIGHT if wall.size.x < wall.size.y else Vector3.BACK
	var standing = Vector3(wall.center.x,wall.base+0.04+0.95,wall.center.y)
	game.player.position = standing-across*3
	for i in range(40):
		await physics_frame
		game.player.velocity = across*8+Vector3.DOWN;game.player.move_and_slide()
	check((game.player.position-Vector3(wall.center.x,1,wall.center.y)).dot(across) < -0.5,"actual player cannot cross solid maze bulkhead")
	game.player.position = standing-across*1.2;game.player.velocity = across*4+Vector3.UP*6
	for i in range(60):
		await physics_frame
		game.player.velocity.x = across.x*4;game.player.velocity.z = across.z*4;game.player.velocity.y -= 18.0/60
		game.player.move_and_slide()
	check((game.player.position-standing).dot(across) > 0.9,"ordinary jump clears low cooling wall")
	var gate_destination = maze.passages[maze.section][0]
	var gate_direction: Vector2i = gate_destination-maze.section
	var outward = Vector3(gate_direction.x,0,gate_direction.y)
	game.player.position = outward*91+Vector3.UP
	for i in range(85):
		await physics_frame
		game.player.velocity = outward*8+Vector3.DOWN;game.player.move_and_slide()
	check(game.player.position.dot(outward) > 100,"actual player walks through open perimeter gate")
	maze.cooldown = 0;maze.step(0.1)
	check(maze.section == gate_destination,"walked gate triggers section transition")
	if "--maze-render" in OS.get_cmdline_user_args():
		maze.section = Vector2i(4,4);maze.rebuild()
		game.player.position = Vector3(0,game.height_at(0,6)+1,6);game.camera.rotation.x = -0.08
		check(vapor.fog.size() == 6 and vapor.fog[0].material is ShaderMaterial,"native froxel volumes use wake shader")
		for i in range(45): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://runtime/labyrinth-render.png")
		game.camera.top_level = true;game.camera.position = Vector3(20,24,35);game.camera.look_at(Vector3(0,1,-25))
		for i in range(8): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://runtime/terrain-restored.png")
	print("VELUM_MAZE_TEST failures=",failures)
	quit(1 if failures else 0)
