extends SceneTree
func _initialize():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var pack = PCKPacker.new()
	var error = pack.pck_start("res://build/VELUM.pck")
	if error != OK:
		push_error(error_string(error)); quit(1); return
	var sources = ["project.godot","main.tscn","game.gd","graphics.gd","world_art.gd","organisms.gd","weather.gd","signal_network.gd","thermal_atmosphere.gd","navigation.gd","spawning.gd","salvage.gd","board_terrain.gd","render_benchmark.gd","shaders/tech_sky.gdshader","shaders/pcb_ground.gdshader","shaders/signal_rain.gdshader","shaders/atmosphere_post.gdshader","shaders/organism_skin.gdshader","shaders/heat_mist.gdshader","shaders/web_dome.gdshaderinc","assets/audio/dark-horse.ogg","assets/audio/CREDITS.md"]
	sources.append_array(["labyrinth.gd","shaders/thermal_volume.gdshader"])
	sources.append_array(["shaders/working_fluid.gdshader","shaders/cooling_wall.gdshader"])
	sources.append_array(["visual_fx.gd","spectral_field.gd","shaders/spectral_gel.gdshader","shaders/triangle_dof.gdshader"])
	sources.append("procedural_detail.gd")
	for source in sources:
		error = pack.add_file("res://"+source,"res://"+source)
		if error != OK:
			push_error(error_string(error)); quit(1); return
	error = pack.add_file("res://.godot/global_script_class_cache.cfg","res://tools/empty_script_cache.cfg")
	if error != OK:
		push_error(error_string(error));quit(1);return
	error = pack.flush()
	if error != OK:
		push_error(error_string(error)); quit(1); return
	print("VELUM_PACK_PASS • ",sources.size()," allowlisted files + empty exported script cache • no runtime secrets")
	quit(0)
