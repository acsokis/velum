extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var game = load("res://main.tscn").instantiate();root.add_child(game)
	game.hatched = true;game.shell.hide();game.menu.hide()
	Engine.max_fps = 0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var samples: Array[float] = [];var previous = Time.get_ticks_usec()
	for frame in range(840):
		await process_frame
		var now = Time.get_ticks_usec();var ms = (now-previous)/1000.0;previous = now
		game.yaw = sin(frame*0.009)*2.3;game.pitch = sin(frame*0.017)*0.28
		if frame >= 120: samples.append(ms)
	samples.sort();var total = 0.0
	for sample in samples: total += sample
	var result = {"seed":game.WORLD_SEED,"renderer":RenderingServer.get_current_rendering_method(),"viewport":str(game.get_window().size),"scale":game.get_viewport().scaling_3d_scale,"frames":samples.size(),"average_fps":1000.0/(total/samples.size()),"median_ms":samples[samples.size()/2],"p95_ms":samples[int(samples.size()*0.95)],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"scope":"stationary rotating camera, active ecology/weather/FFT/DOF, not full traversal"}
	var file = FileAccess.open("res://runtime/scene-performance.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
	print("VELUM_PERFORMANCE_FEATURES sdfgi=",game.world_environment.environment.sdfgi_enabled," volumetric=",game.world_environment.environment.volumetric_fog_enabled," dof=",game.visual_fx.dof.visible," fft_revisions=",game.visual_fx.field.revision)
	print("VELUM_SCENE_PERFORMANCE ",JSON.stringify(result));quit(0)
