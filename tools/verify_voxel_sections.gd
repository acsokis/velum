extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var game = load("res://main.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	game.graphics.settings.gi = true;game.graphics.settings.gi_mode = "voxel";game.graphics.apply_render(game.graphics.settings)
	var start = Time.get_ticks_msec()
	while game.graphics.voxel_baking:
		await process_frame
		if Time.get_ticks_msec()-start > 60000: push_error("Initial voxel bake timeout");quit(1);return
	var initial = hash(game.graphics.voxel_probe.data.get_data_cells())
	game.labyrinth.transition(game.labyrinth.passages[game.labyrinth.section][0])
	if not game.graphics.voxel_baking: push_error("Section change did not schedule GI rebuild");quit(1);return
	while game.graphics.voxel_baking:
		await process_frame
		if Time.get_ticks_msec()-start > 120000: push_error("Section voxel bake timeout");quit(1);return
	if not game.graphics.voxel_probe.visible or hash(game.graphics.voxel_probe.data.get_data_cells()) == initial: push_error("New section retained stale voxel cells");quit(1);return
	print("VELUM_VOXEL_SECTION_PASS fresh_initial_bake=true section_rebake=true visible=true")
	quit(0)
