extends CanvasLayer
## Native graphics/display controls. Settings live beside the project on D:.
const RESOLUTIONS = [Vector2i(1280,720),Vector2i(1280,800),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(3840,2160)]
var game
var env: Environment
var sun: DirectionalLight3D
var popup: PanelContainer
var resolution: OptionButton
var mode: OptionButton
var preset: OptionButton
var upscaler: OptionButton
var scale_slider: HSlider
var checks: Dictionary = {}
var status: Label
var confirm: Button
var settings = {"width":1280,"height":800,"mode":0,"preset":2,"upscaler":"native","scale":1.0,"gi":true,"gi_mode":"sdfgi","fog":true,"ssao":true,"ssil":true,"ssr":true,"glow":true,"vsync":true,"fg":false,"auto_scale":true}
var previous: Dictionary = {}
var confirm_remaining = 0.0
var dlss_mode = -1
var fg_property = false
var framegen_verified = false
var native_queries: Dictionary = {}
var test_mode = false
var fg_last = false
var config_path = ""
var streamline
var gi_method: OptionButton
var voxel_probe: VoxelGI
var voxel_baking = false
var voxel_cache = ""
var generation_delay = 4
var web_scale = 0.75
var frame_ms = 16.67
var performance_clock = 0.0
var performance_samples: Array[float] = []

func setup(owner_game):
	game = owner_game
	if OS.has_feature("web"): settings.preset = 0;settings.scale = 0.75
	env = game.world_environment.environment
	sun = game.directional_sun
	layer = 25
	test_mode = game.smoke or game.terrain_test or game.visual_test
	config_path = game.runtime_dir.path_join("graphics.cfg")
	voxel_cache = game.runtime_dir.path_join("voxel-gi-%d-circuits5-godot%d.res" % [game.WORLD_SEED,Engine.get_version_info().minor])
	if ClassDB.class_has_integer_constant("Viewport","SCALING_3D_MODE_DLSS"):
		dlss_mode = ClassDB.class_get_integer_constant("Viewport","SCALING_3D_MODE_DLSS")
	for p in game.get_viewport().get_property_list():
		if p.name == "frame_generation": fg_property = true
	if Engine.has_singleton("Streamline"):
		streamline = Engine.get_singleton("Streamline")
		var dlss_supported = streamline.call("get_capability",ClassDB.class_get_integer_constant("Streamline","STREAMLINE_CAPABILITY_DLSS"))
		var fg_supported = streamline.call("get_capability",ClassDB.class_get_integer_constant("Streamline","STREAMLINE_CAPABILITY_DLSS_G"))
		if not dlss_supported: dlss_mode = -1
		fg_property = fg_property and bool(fg_supported)
		print("VELUM_STREAMLINE_CAPABILITIES DLSS=",dlss_supported," FG=",fg_supported)
		config_path = game.runtime_dir.path_join("graphics-rtx.cfg")
		var native_dir = OS.get_executable_path().get_base_dir()
		var validation_path = native_dir.path_join("validated.json")
		if FileAccess.file_exists(validation_path):
			var validation = JSON.parse_string(FileAccess.get_file_as_string(validation_path))
			if validation is Dictionary and validation.get("frame_generation_verified",false):
				framegen_verified = str(validation.get("packageSha256","")).to_upper() == FileAccess.get_sha256(native_dir.path_join("VELUM.pck")).to_upper()
	for method in RenderingServer.get_method_list():
		var key = str(method.name)
		if ("dlss" in key.to_lower() or "frame_generation" in key.to_lower()) and key.begins_with("is_"):
			native_queries[key] = true
	settings["rtx_voxel_default"] = false
	if not test_mode: read_settings()
	if dlss_mode >= 0 and not settings.rtx_voxel_default:
		settings.gi = true;settings.gi_mode = "voxel";settings.upscaler = "dlss_quality";settings.rtx_voxel_default = true
	if dlss_mode >= 0 and not FileAccess.file_exists(config_path):
		settings.upscaler = "dlss_quality";settings.fg = fg_property and framegen_verified
		if settings.fg: settings.mode = 1
	if dlss_mode < 0 and str(settings.upscaler).begins_with("dlss"): settings.upscaler = "native"
	if not fg_property: settings.fg = false
	if not framegen_verified and not game.dlss_test: settings.fg = false
	if settings.fg: settings.vsync = false
	if game.dlss_test:
		settings.upscaler = "native";settings.fg = false;settings.vsync = false
		if "--fg-fullscreen" in OS.get_cmdline_user_args(): settings.mode = 1
	if "--rtx-safe" in OS.get_cmdline_user_args():
		for key in ["gi","fog","ssao","ssil","ssr","glow"]: settings[key] = false
		settings.preset = 0
	if "--gi-voxel" in OS.get_cmdline_user_args(): settings.gi_mode = "voxel"
	build_ui()
	if dlss_mode >= 0 and not test_mode: write_settings()
	var startup = settings.duplicate(true)
	if str(settings.upscaler).begins_with("dlss"): startup.upscaler = "native"
	apply_render(startup)
	if not test_mode or game.dlss_test or game.voxel_test: apply_display(settings)
	finish_startup.call_deferred()
	print("VELUM_GRAPHICS_API DLSS=",dlss_mode >= 0," FG=",fg_property," support_queries=",native_queries.keys())
	print("VELUM_GRAPHICS_PROFILE gi=",settings.gi_mode," upscaler=",settings.upscaler," fog=",settings.fog)

func read_settings():
	var cfg = ConfigFile.new()
	if cfg.load(config_path) != OK: return
	for key in settings:
		var value = cfg.get_value("graphics",key,settings[key])
		if typeof(value) == typeof(settings[key]): settings[key] = value
	settings.width = clampi(settings.width,960,7680)
	settings.height = clampi(settings.height,540,4320)
	settings.mode = clampi(settings.mode,0,2)
	settings.preset = clampi(settings.preset,0,3)
	settings.scale = clampf(settings.scale,0.4 if OS.has_feature("web") else 0.5,1.0)
	if not ["sdfgi","voxel"].has(settings.gi_mode): settings.gi_mode = "sdfgi"

func finish_startup():
	if DisplayServer.get_name() == "headless": return
	for i in range(4): await RenderingServer.frame_post_draw
	if not test_mode or game.dlss_test or game.voxel_test: apply_display(settings)
	apply_render(settings)

func write_settings():
	if test_mode: return
	var cfg = ConfigFile.new()
	for key in settings: cfg.set_value("graphics",key,settings[key])
	var error = cfg.save(config_path)
	if error != OK: status.text = "Could not save graphics settings: "+error_string(error)

func row(box: VBoxContainer,title: String,control: Control):
	var line = HBoxContainer.new()
	var label = Label.new();label.text = title;label.custom_minimum_size.x = 260
	line.add_child(label);line.add_child(control)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(line)

func build_ui():
	popup = PanelContainer.new()
	popup.name = "GraphicsMenu"
	popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	popup.offset_left = -380;popup.offset_top = -380
	popup.offset_right = 380;popup.offset_bottom = 380
	popup.custom_minimum_size = Vector2(760,760)
	popup.visible = false
	add_child(popup)
	var style = StyleBoxFlat.new();style.bg_color = Color("0a1b21");style.border_color = Color("76cbb0")
	style.set_border_width_all(1);style.set_content_margin_all(22);style.set_corner_radius_all(9)
	popup.add_theme_stylebox_override("panel",style)
	var box = VBoxContainer.new();box.add_theme_constant_override("separation",4);popup.add_child(box)
	var heading = Label.new();heading.text = "VELUM / GRAPHICS";heading.add_theme_font_size_override("font_size",25);box.add_child(heading)
	var hint = Label.new();hint.text = "F10 graphics • Alt+Enter fullscreen • Display changes revert after 15s unless kept.";hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hint.custom_minimum_size.x=690;box.add_child(hint)
	resolution = OptionButton.new()
	for size in RESOLUTIONS:
		resolution.add_item("%d × %d" % [size.x,size.y]);resolution.set_item_metadata(resolution.item_count-1,size)
	row(box,"Window resolution",resolution)
	mode = OptionButton.new()
	for label in ["Windowed","Borderless fullscreen","Exclusive fullscreen"]: mode.add_item(label)
	mode.item_selected.connect(func(_i): resolution.disabled = mode.selected != 0;update_fg_control())
	row(box,"Display mode",mode)
	preset = OptionButton.new()
	for label in ["Low","Balanced","High / full GI","Ultra / full GI"]: preset.add_item(label)
	preset.item_selected.connect(select_preset)
	row(box,"Quality preset",preset)
	gi_method = OptionButton.new()
	gi_method.add_item("SDFGI / cascaded dynamic GI");gi_method.set_item_metadata(0,"sdfgi")
	gi_method.add_item("VoxelGI / baked 512-cell volume");gi_method.set_item_metadata(1,"voxel")
	row(box,"Global illumination method",gi_method)
	upscaler = OptionButton.new()
	for entry in [["Native + TAA","native"],["FSR 2 Quality","fsr2_quality"],["FSR 2 Balanced","fsr2_balanced"],["FSR 2 Performance","fsr2_performance"]]:
		upscaler.add_item(entry[0]);upscaler.set_item_metadata(upscaler.item_count-1,entry[1])
	if dlss_mode >= 0:
		for entry in [["DLAA (DLSS native)","dlss_native"],["DLSS Quality","dlss_quality"],["DLSS Balanced","dlss_balanced"],["DLSS Performance","dlss_performance"]]:
			upscaler.add_item(entry[0]);upscaler.set_item_metadata(upscaler.item_count-1,entry[1])
	row(box,"Upscaling / antialiasing",upscaler)
	upscaler.item_selected.connect(func(_i): update_fg_control())
	scale_slider = HSlider.new();scale_slider.min_value=0.4 if OS.has_feature("web") else 0.5;scale_slider.max_value=1.0;scale_slider.step=0.05
	row(box,"3D render scale (native mode)",scale_slider)
	var grid = GridContainer.new();grid.columns = 3;box.add_child(grid)
	for entry in [["gi","GI enabled"],["fog","Volumetric fog"],["ssao","SSAO"],["ssil","SSIL"],["ssr","SSR reflections"],["glow","Bloom / glow"],["vsync","VSync"],["fg","DLSS Frame Generation"],["auto_scale","Web adaptive render scale"]]:
		var check = CheckButton.new();check.text = entry[1];checks[entry[0]] = check;grid.add_child(check)
	checks.fg.disabled = not fg_property
	checks.fg.toggled.connect(func(enabled):
		checks.vsync.disabled = enabled
		if enabled: checks.vsync.button_pressed = false
	)
	var support = Label.new()
	support.text = "DLSS / FG: NVIDIA engine integration detected" if dlss_mode >= 0 else "DLSS / FG unavailable in stock Godot; FSR 2 is a separate supported upscaler."
	if dlss_mode >= 0 and not framegen_verified: support.text = "Native DLSS available. Frame Generation is unverified for this build and disabled."
	support.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;support.custom_minimum_size.x = 690;box.add_child(support)
	var fs_hint = Label.new();fs_hint.text = "Fullscreen uses monitor output resolution. Upscaling / render scale controls internal 3D resolution.";fs_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(fs_hint)
	status = Label.new();status.custom_minimum_size=Vector2(690,55);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(status)
	var buttons = HBoxContainer.new();box.add_child(buttons)
	for title in ["Apply","Keep display","Revert","Close"]:
		var button = Button.new();button.text = title;buttons.add_child(button)
		match title:
			"Apply": button.pressed.connect(apply_from_ui)
			"Keep display": confirm = button;button.pressed.connect(keep_display)
			"Revert": button.pressed.connect(revert_display)
			"Close": button.pressed.connect(toggle)
	refresh_ui()
	if OS.has_feature("web"):
		support.text = "WebGL 2 profile: native desktop GI, volumetrics, DLSS and FG are unavailable."
		gi_method.disabled = true;upscaler.disabled = true
		for i in range(preset.item_count): preset.set_item_text(i,["Web performance","Web balanced","Web quality","Web ultra"][i])
		resolution.disabled = true;mode.disabled = true;scale_slider.editable = true
		for key in ["gi","fog","ssao","ssil","ssr","glow","fg"]: checks[key].disabled = true
	else: checks.auto_scale.disabled = true

func refresh_ui():
	for i in range(resolution.item_count):
		var size: Vector2i = resolution.get_item_metadata(i)
		if size == Vector2i(settings.width,settings.height): resolution.select(i)
	mode.select(settings.mode);preset.select(settings.preset);scale_slider.value=settings.scale
	gi_method.select(1 if settings.gi_mode == "voxel" else 0)
	resolution.disabled = mode.selected != 0
	for i in range(upscaler.item_count):
		if upscaler.get_item_metadata(i) == settings.upscaler: upscaler.select(i)
	for key in checks: checks[key].button_pressed = settings[key]
	update_fg_control()
	confirm.disabled = confirm_remaining <= 0
	if OS.has_feature("web"): resolution.disabled = true;mode.disabled = true

func update_fg_control():
	var dlss_selected = str(upscaler.get_item_metadata(upscaler.selected)).begins_with("dlss")
	checks.fg.disabled = not fg_property or not framegen_verified or not dlss_selected or mode.selected == 0
	checks.fg.tooltip_text = "FG remains disabled until generated frames are verified for this exact package. DLSS works independently."
	scale_slider.editable = str(upscaler.get_item_metadata(upscaler.selected)) == "native"
	if not dlss_selected or mode.selected == 0 or not framegen_verified: checks.fg.button_pressed = false

func select_preset(index: int):
	checks.gi.button_pressed = index >= 2
	checks.fog.button_pressed = index >= 1
	checks.ssao.button_pressed = index >= 1
	checks.ssil.button_pressed = index >= 2
	checks.ssr.button_pressed = index >= 2
	checks.glow.button_pressed = index >= 1

func apply_from_ui():
	var candidate = settings.duplicate(true)
	var size: Vector2i = resolution.get_item_metadata(resolution.selected)
	candidate.width=size.x;candidate.height=size.y;candidate.mode=mode.selected
	candidate.preset=preset.selected;candidate.upscaler=upscaler.get_item_metadata(upscaler.selected);candidate.scale=float(scale_slider.value)
	candidate.gi_mode = gi_method.get_item_metadata(gi_method.selected)
	for key in checks: candidate[key]=checks[key].button_pressed
	if candidate.fg: candidate.vsync = false
	var display_changed = candidate.mode != settings.mode or candidate.width != settings.width or candidate.height != settings.height
	if display_changed:
		previous = settings.duplicate(true);confirm_remaining = 15.0
	settings = candidate
	set_framegen(false)
	apply_render(settings)
	if display_changed: apply_display(settings)
	else: write_settings()
	refresh_ui()

func apply_display(s: Dictionary):
	if OS.has_feature("web"): return # Browser owns canvas size and fullscreen permission.
	if DisplayServer.get_name() == "headless": return
	set_framegen(false)
	var window = game.get_window()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	window.mode = Window.MODE_WINDOWED
	window.borderless = false
	var usable = DisplayServer.screen_get_usable_rect(window.current_screen)
	window.size = Vector2i(mini(s.width,usable.size.x-30),mini(s.height,usable.size.y-50))
	window.position = usable.position+(usable.size-window.size)/2
	if s.mode == 1:
		window.mode = Window.MODE_FULLSCREEN
	elif s.mode == 2:
		window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if s.vsync else DisplayServer.VSYNC_DISABLED)

func apply_render(s: Dictionary):
	if OS.has_feature("web"):
		env.sdfgi_enabled = false
		env.volumetric_fog_enabled = false
		env.ssao_enabled = false;env.ssil_enabled = false;env.ssr_enabled = false
		env.fog_enabled = true;env.fog_density = 0.007
		sun.shadow_enabled = s.preset > 0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if s.preset >= 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = 65 if s.preset < 2 else 100
		game.camera.far = 100 if s.preset < 2 else 160
		for light in game.get_children():
			if light is SpotLight3D: light.shadow_enabled = false
		game.get_viewport().msaa_3d = Viewport.MSAA_DISABLED if s.preset == 0 else Viewport.MSAA_2X
		web_scale = float(s.scale)
		game.get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		game.get_viewport().scaling_3d_scale = web_scale
		return
	if DisplayServer.get_name() == "headless": return
	generation_delay = 4
	set_framegen(false)
	var ultra = s.preset == 3
	env.sdfgi_enabled = s.gi and (s.gi_mode != "voxel" or voxel_baking)
	if voxel_probe != null: voxel_probe.visible = s.gi and s.gi_mode == "voxel" and voxel_probe.data != null
	if s.gi and s.gi_mode == "voxel": ensure_voxel_gi()
	env.sdfgi_cascades = 6 if ultra else 4
	env.sdfgi_min_cell_size = 0.22 if ultra else 0.35
	env.sdfgi_use_occlusion = true
	env.sdfgi_bounce_feedback = 0.45
	env.sdfgi_energy = 1.0
	env.sdfgi_read_sky_light = true
	env.ssao_enabled = s.ssao;env.ssao_radius = 1.5;env.ssao_intensity = 1.2
	env.ssil_enabled = s.ssil;env.ssil_radius = 4.0;env.ssil_intensity = 0.65
	env.ssr_enabled = s.ssr;env.ssr_max_steps = 96 if ultra else 64
	env.glow_enabled = s.glow
	env.volumetric_fog_enabled = s.fog
	env.volumetric_fog_density = 0.010
	env.volumetric_fog_albedo = Color("b1b49a")
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 100 if ultra else 80
	env.volumetric_fog_gi_inject = 0.75
	env.volumetric_fog_ambient_inject = 0.3
	env.volumetric_fog_sky_affect = 0.15
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.fog_density = 0.0015 if s.fog else 0.007
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.22
	sun.directional_shadow_split_3 = 0.52
	sun.directional_shadow_max_distance = 150 if ultra else 110
	sun.light_volumetric_fog_energy = 1.2
	var viewport = game.get_viewport()
	var key = str(s.upscaler)
	var factor = float(s.scale)
	if key.ends_with("quality"): factor = 0.667
	elif key.ends_with("balanced"): factor = 0.588
	elif key.ends_with("performance"): factor = 0.5
	elif key == "dlss_native": factor = 1.0
	viewport.use_taa = false
	ProjectSettings.set_setting("rendering/scaling_3d/mode",Viewport.SCALING_3D_MODE_FSR2 if key.begins_with("fsr2") else (dlss_mode if key.begins_with("dlss") and dlss_mode >= 0 else Viewport.SCALING_3D_MODE_BILINEAR))
	ProjectSettings.set_setting("rendering/scaling_3d/scale",factor)
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/use_taa",key == "native")
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if key.begins_with("fsr2") else (dlss_mode if key.begins_with("dlss") and dlss_mode >= 0 else Viewport.SCALING_3D_MODE_BILINEAR)
	viewport.scaling_3d_scale = factor
	viewport.use_taa = key == "native"
	viewport.use_debanding = true
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if s.vsync else DisplayServer.VSYNC_DISABLED)

func ensure_voxel_gi():
	if voxel_probe != null: return
	voxel_probe = VoxelGI.new()
	voxel_probe.name = "VELUM_VoxelGI_512"
	voxel_probe.subdiv = VoxelGI.SUBDIV_512
	voxel_probe.size = Vector3(248,64,248)
	game.add_child(voxel_probe)
	voxel_probe.position = Vector3(0,24,0)
	voxel_probe.visible = false
	if game.labyrinth == null and FileAccess.file_exists(voxel_cache):
		voxel_probe.data = ResourceLoader.load(voxel_cache)
		if voxel_probe.data != null:
			voxel_probe.visible = true;env.sdfgi_enabled = false
			return
	voxel_baking = true
	env.sdfgi_enabled = true
	bake_voxel_gi.call_deferred()

func bake_voxel_gi():
	# Let the render thread actually present FG-off frames before a blocking cache bake.
	for i in range(3): await RenderingServer.frame_post_draw
	print("VELUM_VOXELGI_BAKE_BEGIN subdivision=512 extent=248x64x248")
	voxel_probe.bake(game)
	if voxel_probe.data != null:
		voxel_probe.data.use_two_bounces = true
		voxel_probe.data.energy = 1.0
		var error = ResourceSaver.save(voxel_probe.data,voxel_cache) if game.labyrinth == null else OK
		print("VELUM_VOXELGI_BAKE_COMPLETE cells_bytes=",voxel_probe.data.get_data_cells().size()," cache_status=",error_string(error))
	voxel_baking = false
	generation_delay = 4
	voxel_probe.visible = bool(settings.gi) and settings.gi_mode == "voxel" and voxel_probe.data != null
	env.sdfgi_enabled = bool(settings.gi) and (settings.gi_mode != "voxel" or voxel_probe.data == null)

func refresh_section_gi():
	if not settings.gi or settings.gi_mode != "voxel" or voxel_baking or OS.has_feature("web"): return
	if voxel_probe == null: ensure_voxel_gi();return
	voxel_probe.visible = false;voxel_baking = true;env.sdfgi_enabled = true
	bake_voxel_gi.call_deferred()

func keep_display():
	confirm_remaining = 0;previous.clear();write_settings();refresh_ui()

func revert_display():
	if previous.is_empty(): return
	settings = previous.duplicate(true);previous.clear();confirm_remaining = 0
	apply_render(settings);apply_display(settings);refresh_ui()

func set_framegen(enabled: bool):
	if fg_property and enabled != fg_last:
		if enabled: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		if enabled and streamline != null:
			streamline.call("set_parameter",ClassDB.class_get_integer_constant("Streamline","STREAMLINE_PARAM_REFLEX_MODE"),1.0)
		game.get_viewport().set("frame_generation",enabled)
		fg_last = enabled

func toggle():
	popup.visible = not popup.visible
	if popup.visible: refresh_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if popup.visible or game.menu.visible else Input.MOUSE_MODE_CAPTURED

func _process(delta):
	if game == null: return
	if OS.has_feature("web"):
		frame_ms = lerpf(frame_ms,minf(delta*1000,250),0.04)
		performance_clock += delta;performance_samples.append(delta*1000)
		if performance_samples.size() > 600: performance_samples.pop_front()
		if performance_clock > 1.5:
			performance_clock = 0
			if settings.auto_scale and not popup.visible and game.get_window().has_focus():
				var budget = 1000.0/(game.visual_fx.target_fps if game.visual_fx != null else 60)
				if frame_ms > budget*1.11: web_scale = maxf(0.4,web_scale-0.05)
				elif frame_ms < budget*0.78: web_scale = minf(float(settings.scale),web_scale+0.025)
				game.get_viewport().scaling_3d_scale = web_scale
			if game.web_qa: JavaScriptBridge.eval("window.velumPerformance="+JSON.stringify(performance_snapshot())+";")
	if generation_delay > 0: generation_delay -= 1
	if confirm_remaining > 0:
		confirm_remaining -= delta
		if confirm_remaining <= 0: revert_display()
	if popup.visible:
		var size = game.get_window().size
		var render_size = Vector2i(Vector2(size)*game.get_viewport().scaling_3d_scale)
		var gi_label = "SDFGI (%d cascades)" % env.sdfgi_cascades if env.sdfgi_enabled else ("VoxelGI" if voxel_probe != null and voxel_probe.visible else "OFF")
		status.text = "Output %d × %d • Internal 3D ≈ %d × %d\nGI %s • Volumetric %s • 4 shadow cascades%s" % [size.x,size.y,render_size.x,render_size.y,gi_label,"ON" if env.volumetric_fog_enabled else "OFF"," • Keep display: %ds" % ceili(confirm_remaining) if confirm_remaining > 0 else ""]
		if voxel_baking: status.text += "\nPreparing VoxelGI cache…"
		elif voxel_probe != null and voxel_probe.visible: status.text += " • VoxelGI 512 / two bounces"
		if OS.has_feature("web"): status.text = "WEBGL 2 • %.1f FPS / %.1f ms • scale %.0f%%\n3D ≈ %d × %d • adaptive %s / target %d FPS\nNative GI / volumetrics / DLSS / FG unavailable." % [1000/maxf(1,frame_ms),frame_ms,web_scale*100,size.x*web_scale,size.y*web_scale,"ON" if settings.auto_scale else "OFF",game.visual_fx.target_fps if game.visual_fx != null else 60]
	set_framegen(bool(settings.fg) and (framegen_verified or game.dlss_test) and settings.mode != 0 and str(settings.upscaler).begins_with("dlss") and not popup.visible and not game.menu.visible and not voxel_baking and generation_delay <= 0 and confirm_remaining <= 0 and (not test_mode or game.dlss_test))

func performance_snapshot() -> Dictionary:
	var sorted = performance_samples.duplicate();sorted.sort()
	return {"fps":Engine.get_frames_per_second(),"frame_ms":frame_ms,"p95_ms":sorted[mini(sorted.size()-1,int(sorted.size()*0.95))] if not sorted.is_empty() else 0,"scale":web_scale,"viewport_scale":game.get_viewport().scaling_3d_scale,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"frames":Engine.get_frames_drawn(),"preset":settings.preset,"max_fps":Engine.max_fps}

func web_shortcut(key: int):
	if key == KEY_P: settings.preset = (int(settings.preset)+1)%4
	else:
		settings.auto_scale = false
		settings.scale = clampf(float(settings.scale)+(0.1 if key == KEY_BRACKETRIGHT else -0.1),0.4,1.0)
	apply_render(settings);write_settings();refresh_ui()
	game.notify("WEB • quality %d / render %.0f%% • F10 controls" % [settings.preset,settings.scale*100])
