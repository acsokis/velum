extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var game = load("res://main.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false);game.hatched = true;game.shell.hide();game.menu.hide()
	await process_frame
	var fx = game.visual_fx
	if fx == null: push_error("GPU visual FX required");quit(1);return
	fx.dof_enabled = true;fx.spectral_enabled = true;fx.aperture = 12
	game.camera.top_level = true;game.camera.far = 550
	game.camera.position = Vector3(138,8,138);game.camera.look_at(Vector3(165,-14,100))
	for i in range(45): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://runtime/fft-underworld.png")
	game.camera.position = Vector3(0,5,0);game.camera.look_at(Vector3(5,60,-20))
	for i in range(20): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://runtime/fft-sky.png")
	game.camera.position = Vector3(0,2.5,6);game.camera.look_at(Vector3(0,2,-20))
	for i in range(20): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://runtime/triangle-dof.png")
	if fx.field.revision < 2 or not fx.dof.visible: push_error("FX did not update");quit(1);return
	fx.dof_enabled = false;fx._process(0)
	if fx.dof.visible: push_error("DOF toggle failed");quit(1);return
	game.weather.flashes = false;fx._process(0)
	if fx.gel.material_override.get_shader_parameter("discharges"): push_error("Discharge opt-out failed");quit(1);return
	print("VELUM_VISUAL_FX_PASS fft_revisions=",fx.field.revision," triangular_dof_toggle=true discharge_optout=true")
	quit(0)
