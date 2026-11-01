extends Node
var game
var field = preload("res://spectral_field.gd").new()
var elapsed = 0.0
var update_clock = 0.0
var dof: MeshInstance3D
var gel: MeshInstance3D
var dof_enabled = true
var spectral_enabled = true
var aperture = 8.0
var target_fps = 144
var spectral_blend = 1.0
var last_revision = 1
var last_completion = 0.0
var blend_duration = 0.1667

func setup(owner_game):
	game = owner_game
	if OS.has_feature("web"):
		target_fps = 60;dof_enabled = false
	field.setup(game.WORLD_SEED)
	game.atmosphere_material.set_shader_parameter("spectral_field",field.texture)
	game.atmosphere_material.set_shader_parameter("spectral_previous",field.previous_texture)
	game.atmosphere_material.set_shader_parameter("spectral_enabled",true)
	var surface = PlaneMesh.new();surface.size = Vector2(320,320)
	surface.subdivide_width = 47 if OS.has_feature("web") else 95;surface.subdivide_depth = surface.subdivide_width
	var gel_material = ShaderMaterial.new();gel_material.shader = load("res://shaders/spectral_gel.gdshader");gel_material.set_shader_parameter("spectral_field",field.texture)
	gel_material.set_shader_parameter("spectral_previous",field.previous_texture)
	gel = game.mesh_at(game,surface,Vector3(0,-0.65,0),Vector3.ONE,gel_material);gel.name = "SpectralUnderworld"
	gel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad = QuadMesh.new();quad.size = Vector2(2,2)
	# Screen texture excludes transparency: run before glass/fluid and labels so they remain visible.
	var dof_material = ShaderMaterial.new();dof_material.shader = load("res://shaders/triangle_dof.gdshader");dof_material.render_priority = -128
	dof_material.set_shader_parameter("sample_count",8 if OS.has_feature("web") else 15)
	dof = game.mesh_at(game.camera,quad,Vector3(0,0,-1),Vector3.ONE,dof_material);dof.name = "TriangularBokeh";dof.extra_cull_margin = 16384
	dof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cfg = ConfigFile.new()
	if cfg.load(game.runtime_dir.path_join("visual-fx.cfg")) == OK:
		dof_enabled = cfg.get_value("fx","dof",dof_enabled);spectral_enabled = cfg.get_value("fx","spectral",true);aperture = clampf(cfg.get_value("fx","aperture",8.0),0,18)
		target_fps = clampi(int(cfg.get_value("fx","target_fps",target_fps)),60,144)
	if not game.dlss_test: Engine.max_fps = target_fps
	var box = game.menu.find_child("LinkContent",true,false)
	var row = HFlowContainer.new();box.add_child(row)
	var toggle = CheckButton.new();toggle.text = "Triangle bokeh DOF";toggle.button_pressed = dof_enabled;row.add_child(toggle)
	toggle.toggled.connect(func(value): dof_enabled = value;save_preferences())
	var waves = CheckButton.new();waves.text = "FFT sky / gel";waves.button_pressed = spectral_enabled;row.add_child(waves)
	waves.toggled.connect(func(value): spectral_enabled = value;save_preferences())
	var label = Label.new();label.text = "Bokeh aperture";box.add_child(label)
	var slider = HSlider.new();slider.min_value = 0;slider.max_value = 18;slider.step = 1;slider.value = aperture;box.add_child(slider)
	slider.value_changed.connect(func(value): aperture = value;save_preferences())
	var target = OptionButton.new()
	for fps in [60,90,120,144]:
		target.add_item("Frame budget: %d FPS" % fps,fps)
		if fps == target_fps: target.select(target.item_count-1)
	box.add_child(target)
	target.item_selected.connect(func(index): target_fps = target.get_item_id(index);Engine.max_fps = target_fps;save_preferences())

func save_preferences():
	var cfg = ConfigFile.new();cfg.set_value("fx","dof",dof_enabled);cfg.set_value("fx","spectral",spectral_enabled);cfg.set_value("fx","aperture",aperture)
	cfg.set_value("fx","target_fps",target_fps)
	cfg.save(game.runtime_dir.path_join("visual-fx.cfg"))

func _process(delta):
	if game == null: return
	elapsed += delta;update_clock += delta
	# Follow the view without moving the world-space wave phase. The distant field dissolves into haze.
	gel.position.x = floor(game.camera.global_position.x/16)*16
	gel.position.z = floor(game.camera.global_position.z/16)*16
	gel.material_override.set_shader_parameter("view_origin",game.camera.global_position)
	if spectral_enabled:
		if not field.busy and update_clock >= (0.1667 if OS.has_feature("web") else 0.1):
			update_clock = 0;field.begin_update(elapsed)
		field.process_budget(350 if OS.has_feature("web") else 500)
		if field.revision != last_revision:
			last_revision = field.revision;spectral_blend = 0
			blend_duration = maxf(0.1,elapsed-last_completion);last_completion = elapsed
		spectral_blend = minf(1,spectral_blend+delta/blend_duration)
	game.atmosphere_material.set_shader_parameter("spectral_blend",spectral_blend)
	gel.material_override.set_shader_parameter("spectral_blend",spectral_blend)
	game.atmosphere_material.set_shader_parameter("spectral_enabled",spectral_enabled)
	gel.visible = spectral_enabled
	gel.material_override.set_shader_parameter("discharges",game.weather.flashes and game.weather.enabled)
	dof.visible = dof_enabled and aperture > 0 and game.weather.post_enabled
	dof.material_override.set_shader_parameter("aperture",aperture)
