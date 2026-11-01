extends Node3D
## VELUM bounded first playable. All meshes are original procedural placeholder art.
var WORLD_SEED = 714219
var runtime_dir = ""
var web_qa = false
var web_screen_clock = 0.0
var rng = RandomNumberGenerator.new()
var player: CharacterBody3D
var camera: Camera3D
var shell: Node3D
var terminal: Node3D
var screen: SubViewport
var terminal_label: Label
var hud: Label
var notice: Label
var menu: PanelContainer
var menu_text: RichTextLabel
var input_line: LineEdit
var probe: Camera3D
var probe_view: SubViewport
var probe_image: TextureRect
var map_view: Control
var http: HTTPRequest
var poll: HTTPRequest
var auth = ""
var time = 0.0
var sync_time = 0.0
var hatched = false
var hatch_time = -1.0
var energy = 85.0
var fluid = 80.0
var temperature = 36.0
var integrity = 100.0
var ceramic = 0
var fiber = 0
var upgrade = false
var resources: Array[Dictionary] = []
var creatures: Array[Dictionary] = []
var organisms = preload("res://organisms.gd").new()
var navigation = preload("res://navigation.gd").new()
var spawning = preload("res://spawning.gd").new()
var salvage = preload("res://salvage.gd").new()
var weather
var messages: Array = []
var mount = 0
var panel = 0
var portrait = true
var tilt = 0.0
var pivot = 0.0
var yaw = 0.0
var pitch = 0.0
var probe_angle = 0.0
var dnd = false
var private_preview = false
var selected_channel = "global"
var last_notice = -10.0
var online = false
var server_state: Dictionary = {}
var command_ack = 0
var paused = false
var smoke = false
var smoke_stage = 0
var smoke_clock = 0.0
var probe_jpeg = ""
var newest_message = 0
var unread_messages = 0
var visual_test = false
var visual_stage = 0
var visual_clock = 0.0
var sky_test = false
var interior_test = false
var smoke_start_position = Vector3.ZERO
var smoke_move_started = 0.0
var terminal_display: MeshInstance3D
var last_portrait = true
var notification_sound = false
var notification_popups = true
var audio_player: AudioStreamPlayer
var last_message_popup = -10.0
var popup_group = 0
var world_art: RefCounted
var board_terrain: RefCounted
var terrain_test = false
var terrain_test_case = -1
var terrain_test_clock = 0.0
var world_environment: WorldEnvironment
var atmosphere_material: ShaderMaterial
var web_dome: MeshInstance3D
var directional_sun: DirectionalLight3D
var graphics
var graphics_test = false
var dlss_test = false
var voxel_test = false
var labyrinth
var labyrinth_enabled = false
var visual_fx
var procedural_detail
var coast
var last_dlss_report = 0.0
const MOUNTS = ["Handheld", "Left wrist", "Right wrist", "Left forearm", "Right forearm", "Dock", "Detached inspection"]
const PANELS = ["STATUS", "LOCAL MAP", "SCANNER", "PROBE", "MESSAGES", "PAIRING"]

func _ready():
	if OS.has_feature("web"):
		set_physics_process(false);set_process(false);set_process_input(false);set_process_unhandled_input(false)
		web_loading("Forming the landscape")
		await get_tree().process_frame
	if OS.has_feature("web") and bool(JavaScriptBridge.eval("location.hash === '#render-benchmark'")):
		set_physics_process(false);set_process(false);set_process_unhandled_input(false)
		var benchmark = load("res://render_benchmark.gd").new();add_child(benchmark);return
	runtime_dir = OS.get_environment("VELUM_DATA_DIR")
	if OS.has_feature("web"): runtime_dir = "user://velum"
	if OS.has_feature("web"): web_qa = bool(JavaScriptBridge.eval("location.hash === '#qa'"))
	if runtime_dir == "": runtime_dir = ProjectSettings.globalize_path("res://runtime")
	DirAccess.make_dir_recursive_absolute(runtime_dir)
	smoke = "--smoke" in OS.get_cmdline_user_args()
	sky_test = "--sky-test" in OS.get_cmdline_user_args()
	interior_test = "--interior-test" in OS.get_cmdline_user_args()
	terrain_test = "--terrain-test" in OS.get_cmdline_user_args()
	graphics_test = "--graphics-test" in OS.get_cmdline_user_args()
	dlss_test = "--dlss-test" in OS.get_cmdline_user_args()
	voxel_test = "--voxel-test" in OS.get_cmdline_user_args()
	# Leave presentation headroom during FG validation, rather than saturating the display with native frames.
	if dlss_test: Engine.max_fps = 60
	visual_test = "--visual-test" in OS.get_cmdline_user_args() or sky_test or interior_test or graphics_test or dlss_test or voxel_test
	labyrinth_enabled = "--maze-test" in OS.get_cmdline_user_args() or ((DisplayServer.get_name() != "headless") and not (smoke or terrain_test or visual_test) and not "--survey" in OS.get_cmdline_user_args())
	if "--demo" in OS.get_cmdline_user_args(): hatch_time = 0
	configure_seed()
	rng.seed = WORLD_SEED
	make_environment()
	if dlss_test: print("VELUM_BOOT environment")
	make_world()
	if OS.has_feature("web"):
		web_loading("Awakening the ecosystem")
		await get_tree().process_frame
	if dlss_test: print("VELUM_BOOT world")
	make_player()
	if dlss_test: print("VELUM_BOOT player")
	make_terminal()
	if dlss_test: print("VELUM_BOOT terminal")
	make_ui()
	salvage.setup(self)
	if dlss_test: print("VELUM_BOOT ui")
	graphics = load("res://graphics.gd").new()
	add_child(graphics)
	graphics.setup(self)
	make_notification_audio()
	make_network()
	weather = load("res://weather.gd").new();add_child(weather);weather.setup(self)
	procedural_detail = load("res://procedural_detail.gd").new();add_child(procedural_detail);procedural_detail.setup(self)
	coast = load("res://coast.gd").new();add_child(coast);coast.setup(self)
	if DisplayServer.get_name() != "headless":
		visual_fx = load("res://visual_fx.gd").new();add_child(visual_fx);visual_fx.setup(self)
	if terrain_test:
		hatched = true
		shell.visible = false
	if not OS.has_feature("web") and not smoke and not visual_test and not "--demo" in OS.get_cmdline_user_args():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	notify("SHELL // Press E to hatch. "+(labyrinth.status() if labyrinth != null else "A bounded survey sector awaits."))
	if OS.has_feature("web"):
		web_loading("Preparing light and atmosphere")
		for i in range(12): await get_tree().process_frame
		set_physics_process(true);set_process(true);set_process_input(true);set_process_unhandled_input(true)
		JavaScriptBridge.eval("window.dispatchEvent(new Event('velum-ready'));")

func web_loading(message: String):
	if OS.has_feature("web"): JavaScriptBridge.eval("window.dispatchEvent(new CustomEvent('velum-loading',{detail:"+JSON.stringify(message)+"}));")

func mat(color: Color, emission = 0.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.38
	m.metallic = 0.35
	if emission > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m

func configure_seed():
	var value = "714219"
	var args = OS.get_cmdline_user_args()
	var test_run = smoke or terrain_test or visual_test or "--maze-test" in args or DisplayServer.get_name() == "headless"
	if not test_run:
		var cfg = ConfigFile.new()
		if cfg.load(runtime_dir.path_join("world.cfg")) == OK: value = str(cfg.get_value("world","seed",714219))
	for arg in args:
		if arg.begins_with("--seed="): value = arg.trim_prefix("--seed=")
	if OS.has_feature("web"):
		var query = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('seed') || ''"))
		if query.is_valid_int(): value = query
	if ProjectSettings.has_meta("velum_seed"): value = str(ProjectSettings.get_meta("velum_seed"))
	if value.is_valid_int(): WORLD_SEED = clampi(int(value),1,2147483647)

func mesh_at(parent: Node3D, mesh: Mesh, pos: Vector3, scale_v: Vector3, material: Material) -> MeshInstance3D:
	if OS.has_feature("web"):
		if mesh is SphereMesh: mesh.radial_segments = 16;mesh.rings = 8
		elif mesh is CylinderMesh: mesh.radial_segments = 12
		elif mesh is TorusMesh: mesh.rings = 24;mesh.ring_segments = 12
	var n = MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = material
	n.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	parent.add_child(n)
	n.position = pos
	n.scale = scale_v
	return n

func height_at(x: float, z: float) -> float:
	if board_terrain == null:
		board_terrain = load("res://board_terrain.gd").new()
		board_terrain.configure(WORLD_SEED)
	return board_terrain.height_at(x,z)

func make_environment():
	var env = WorldEnvironment.new()
	world_environment = env
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_SKY
	var sky_shader = Shader.new()
	sky_shader.code = FileAccess.get_file_as_string("res://shaders/tech_sky.gdshader")
	if OS.has_feature("web"):
		sky_shader.code = sky_shader.code.replace("use_half_res_pass, ","")
		sky_shader.code = sky_shader.code.replace("i < 4", "i < 2")
	var sky_material = ShaderMaterial.new()
	sky_material.shader = sky_shader
	sky_material.set_shader_parameter("web_profile",OS.has_feature("web"))
	atmosphere_material = sky_material
	var procedural_sky = Sky.new()
	procedural_sky.sky_material = sky_material
	procedural_sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL if OS.has_feature("web") else Sky.PROCESS_MODE_REALTIME
	procedural_sky.radiance_size = Sky.RADIANCE_SIZE_32 if OS.has_feature("web") else Sky.RADIANCE_SIZE_256
	env.environment.sky = procedural_sky
	if OS.has_feature("web"):
		# Animated cable/cloud art does not need to rebuild six reflection faces every frame.
		var dome_shader = Shader.new()
		dome_shader.code = sky_shader.code.get_slice("void sky()",0).replace("shader_type sky;","shader_type spatial;").replace("render_mode disable_fog;","render_mode unshaded, cull_front, depth_draw_never, shadows_disabled, fog_disabled;")+FileAccess.get_file_as_string("res://shaders/web_dome.gdshaderinc")
		atmosphere_material = ShaderMaterial.new();atmosphere_material.shader = dome_shader
		var dome = SphereMesh.new();dome.radius = 1;dome.height = 2;dome.radial_segments = 64;dome.rings = 32
		web_dome = mesh_at(self,dome,Vector3.ZERO,Vector3.ONE*80,atmosphere_material)
		web_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var light_sky = ProceduralSkyMaterial.new();light_sky.sky_top_color = Color("182b34");light_sky.sky_horizon_color = Color("666451")
		procedural_sky.sky_material = light_sky;procedural_sky.process_mode = Sky.PROCESS_MODE_QUALITY
	atmosphere_material.set_shader_parameter("procedural_offset",Vector2(posmod(WORLD_SEED-714219,997),posmod(WORLD_SEED-714219,991)))
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("a5ac82")
	env.environment.ambient_light_energy = 0.58
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.glow_enabled = true
	env.environment.fog_enabled = true
	env.environment.fog_light_color = Color("4e5140")
	env.environment.fog_density = 0.007
	env.environment.fog_sky_affect = 0.0
	add_child(env)
	var sun = DirectionalLight3D.new()
	directional_sun = sun
	# Match illumination/shadow direction to the fusion aperture in the sky shader.
	sun.rotation = Basis.looking_at(-Vector3(-80,65,-140).normalized()).get_euler()
	sun.light_color = Color("e5cc95")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.shadow_normal_bias = 2.0
	add_child(sun)
	for position in [Vector3(14,15,-13),Vector3(-20,13,-20),Vector3(34,16,-38)]:
		var spot = SpotLight3D.new()
		spot.position = position
		spot.basis = Basis.looking_at(Vector3(0,-1,-0.22).normalized())
		spot.light_color = Color("73d8b0") if position.x > 0 else Color("e0a65e")
		spot.light_energy = 4.0
		spot.spot_range = 28
		spot.spot_angle = 30
		spot.shadow_enabled = true
		spot.light_volumetric_fog_energy = 1.8
		add_child(spot)
	# Preserve the old sky's 220 RNG draws so existing seeded resource IDs stay in place.
	# Celestial objects now live at infinity in the shader, rather than on nearby mesh spheres.
	for i in range(220): rng.randf()

func make_world():
	world_art = load("res://world_art.gd").new()
	world_art.setup(self)
	height_at(0,0) # Initialize the independent, deterministic board layout.
	board_terrain.build(self)
	if labyrinth_enabled:
		labyrinth = load("res://labyrinth.gd").new();labyrinth.setup(self)
	var ceramic_mat = mat(Color("d5d8cb"))
	ceramic_mat.roughness = 0.65
	ceramic_mat.metallic = 0.12
	var vein_mat = mat(Color("3de8bc"), 1.4)
	for i in range(130):
		var x = rng.randf_range(-110,110)
		var z = rng.randf_range(-110,110)
		if Vector2(x,z).length() < 9:
			continue
		var p = Vector3(x,height_at(x,z),z)
		if x < 0:
			var old_scale = Vector3(rng.randf_range(1,4),rng.randf_range(2,8),rng.randf_range(1,3))
			var lean = rng.randf_range(-25,25)
			world_art.capacitor(p,old_scale,lean)
		else:
			var h = rng.randf_range(5,15)
			world_art.transistor_tree(p,h)
	for i in range(38):
		var p = Vector3(rng.randf_range(-65,65),0,rng.randf_range(-65,65))
		if i < 4:
			p = Vector3(-2+i*2,0,-5)
		if labyrinth != null:
			p.x = roundf(p.x/18.0)*18.0+clampf(p.x-roundf(p.x/18.0)*18.0,-5,5)
			p.z = roundf(p.z/18.0)*18.0+clampf(p.z-roundf(p.z/18.0)*18.0,-5,5)
		var kind = "ceramic" if i % 2 == 0 else "fiber"
		p.y = height_at(p.x,p.z)+(0.25 if kind == "ceramic" else 0.45)
		var resource_mesh: Mesh = BoxMesh.new() if kind == "ceramic" else TorusMesh.new()
		var n = mesh_at(self, resource_mesh, p, Vector3(0.8,0.5,0.65) if kind == "ceramic" else Vector3(0.5,0.7,0.5), ceramic_mat if kind == "ceramic" else vein_mat)
		if kind == "ceramic":
			for side in [-1,1]: world_art.box(n,Vector3(side*0.43,0,0),Vector3(0.18,1.02,1.02),world_art.solder)
		set_dynamic_geometry(n)
		resources.append({"id":i,"node":n,"kind":kind,"charge":1.0,"cooldown":0.0})
	world_art.decorate()
	if labyrinth != null: labyrinth.rebuild()
	navigation.setup(self)
	organisms.setup(self)
	navigation.index_resources()
	spawning.setup(self)
	for i in range(9):
		spawning.add_natural(i,Vector3(rng.randf_range(-35,35),0,rng.randf_range(-35,35)))
	# Dock is anchored in world coordinates, independent of camera movement.
	mesh_at(self, CylinderMesh.new(), Vector3(3,height_at(3,0)+0.55,0), Vector3(0.7,0.55,0.7), ceramic_mat)
	world_art.batch_static_geometry()

func make_player():
	player = CharacterBody3D.new()
	player.floor_snap_length = 0.4
	player.floor_constant_speed = true
	player.floor_max_angle = deg_to_rad(58)
	add_child(player)
	player.position = Vector3(0,height_at(0,0)+1,0)
	var collider = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	collider.shape = capsule
	player.add_child(collider)
	camera = Camera3D.new()
	player.add_child(camera)
	camera.position.y = 0.65
	camera.fov = 78
	camera.current = true
	if DisplayServer.get_name() != "headless" and not smoke:
		world_art.make_dust(player)
	shell = Node3D.new()
	add_child(shell)
	shell.position = player.position
	for i in range(8):
		var a = i*TAU/8
		var petal = mesh_at(shell, SphereMesh.new(), Vector3(sin(a)*0.85,0,cos(a)*0.85), Vector3(0.65,1.55,0.35), mat(Color("c4d3ce")))
		petal.rotation.y = a
		mesh_at(petal, CylinderMesh.new(), Vector3(0,0,0.2), Vector3(0.025,0.8,0.025), mat(Color("6affd7"),2))
	set_dynamic_geometry(shell)

func set_dynamic_geometry(node: Node):
	if node is MeshInstance3D: node.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	for child in node.get_children(): set_dynamic_geometry(child)

func make_terminal():
	terminal = Node3D.new()
	add_child(terminal)
	mesh_at(terminal, BoxMesh.new(), Vector3.ZERO, Vector3(0.36,0.53,0.035), mat(Color("d0d7cc")))
	mesh_at(terminal, BoxMesh.new(), Vector3(0,-0.23,0.03), Vector3(0.12,0.012,0.015), mat(Color("4bffc5"),2))
	screen = SubViewport.new()
	screen.size = Vector2i(480,720)
	screen.transparent_bg = false
	screen.render_target_update_mode = SubViewport.UPDATE_ONCE if OS.has_feature("web") else SubViewport.UPDATE_ALWAYS
	add_child(screen)
	var bg = ColorRect.new()
	bg.color = Color("071920")
	bg.size = Vector2(480,720)
	screen.add_child(bg)
	terminal_label = Label.new()
	terminal_label.position = Vector2(24,22)
	terminal_label.size = Vector2(432,670)
	terminal_label.add_theme_font_size_override("font_size",24)
	terminal_label.add_theme_color_override("font_color",Color("a0f6dc"))
	terminal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen.add_child(terminal_label)
	var plane = QuadMesh.new()
	plane.size = Vector2(0.33,0.49)
	var display_mat = StandardMaterial3D.new()
	display_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	display_mat.albedo_texture = screen.get_texture()
	terminal_display = mesh_at(terminal,plane,Vector3(0,0,0.022),Vector3.ONE,display_mat)
	probe_view = SubViewport.new()
	probe_view.size = Vector2i(480,270)
	probe_view.own_world_3d = false
	probe_view.render_target_update_mode = SubViewport.UPDATE_DISABLED if OS.has_feature("web") else SubViewport.UPDATE_ALWAYS
	add_child(probe_view)
	probe = Camera3D.new()
	probe_view.add_child(probe)
	probe.current = true
	probe_image = TextureRect.new()
	probe_image.position = Vector2(15,280)
	probe_image.size = Vector2(450,253)
	probe_image.texture = probe_view.get_texture()
	probe_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.add_child(probe_image)
	map_view = Control.new()
	map_view.position = Vector2(30,250)
	map_view.size = Vector2(420,420)
	screen.add_child(map_view)
	map_view.draw.connect(draw_map)
	set_dynamic_geometry(terminal)

func make_ui():
	var canvas = CanvasLayer.new()
	add_child(canvas)
	hud = Label.new()
	hud.position = Vector2(28,22)
	hud.add_theme_font_size_override("font_size",19)
	canvas.add_child(hud)
	notice = Label.new()
	notice.position = Vector2(28,205 if labyrinth != null else 140)
	notice.add_theme_color_override("font_color",Color("a0f6dc"))
	canvas.add_child(notice)
	var controls = Label.new()
	controls.position = Vector2(28,720)
	controls.text = "WASD move · Mouse look · E hatch / hold to salvage · T tool · C grow · F refill · Tab LINK\n1–6 panels · M mount · O orientation · Q/R probe · F5 save · F9 load · F10 graphics"
	if OS.has_feature("web"): controls.text = "WASD / mouse or drag • E hatch / hold salvage • T tool • C grow • Tab LINK\nK save • L load • 1–6 panels • M mount • O orientation • F10 graphics • [ / ] scale • P quality"
	canvas.add_child(controls)
	var cross = Label.new()
	cross.text = "+"
	cross.position = Vector2(635,390)
	canvas.add_child(cross)
	menu = PanelContainer.new()
	menu.position = Vector2(570,100)
	menu.size = Vector2(660,580)
	menu.visible = false
	canvas.add_child(menu)
	var box = VBoxContainer.new()
	box.name = "LinkContent"
	var scroll = ScrollContainer.new();scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(scroll);scroll.add_child(box);box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_text = RichTextLabel.new()
	menu_text.custom_minimum_size = Vector2(640,300)
	box.add_child(menu_text)
	var buttons = HFlowContainer.new()
	box.add_child(buttons)
	var graphics_button = Button.new()
	graphics_button.text = "Graphics / Display"
	graphics_button.pressed.connect(func(): graphics.toggle())
	buttons.add_child(graphics_button)
	for title in ["Save", "Load"]:
		var save_button = Button.new();save_button.text = title
		save_button.pressed.connect(save_game if title == "Save" else load_game)
		buttons.add_child(save_button)
	for p in range(6):
		var b = Button.new()
		b.text = PANELS[p]
		b.pressed.connect(func(): panel = p)
		buttons.add_child(b)
	for title in ["Pair code", "Approve READ", "Approve CONTROL", "Revoke all", "DND", "Hide previews", "Sound", "Pop-ups", "Open message", "Reply", "Dismiss", "Mark read", "Mute last sender", "Block last sender", "Report last message"]:
		var b = Button.new()
		b.text = title
		b.pressed.connect(func(): host_action(title))
		buttons.add_child(b)
	var channel = OptionButton.new()
	for ch in ["global","local","party","direct"]:
		channel.add_item(ch)
	channel.item_selected.connect(func(i): selected_channel = ["global","local","party","direct"][i])
	box.add_child(channel)
	input_line = LineEdit.new()
	input_line.placeholder_text = "Native game chat • direct: player-id: message • no moderation backend"
	input_line.text_submitted.connect(send_chat)
	box.add_child(input_line)
	var help = Label.new()
	help.text = "External services: TWITCH MOCK / DISCORD MOCK — disconnected.\nTab releases cursor. Gameplay continues. No automatic focus capture."
	box.add_child(help)

func make_network():
	if OS.get_environment("VELUM_LINK_DISABLED") == "1": return
	# Native host credentials never ship inside a browser bundle.
	if OS.has_feature("web"): return
	if not smoke and not terrain_test and FileAccess.file_exists(runtime_dir.path_join("host.key")):
		auth = FileAccess.get_file_as_string(runtime_dir.path_join("host.key")).strip_edges()
	http = HTTPRequest.new()
	add_child(http)
	http.timeout = 2
	http.request_completed.connect(func(_r, code, _h, body):
		online = code == 200
		if code == 403 and FileAccess.file_exists(runtime_dir.path_join("host.key")):
			var refreshed = FileAccess.get_file_as_string(runtime_dir.path_join("host.key")).strip_edges()
			if refreshed != auth:
				auth = refreshed
				command_ack = 0
				newest_message = 0
		if code == 200:
			var data = JSON.parse_string(body.get_string_from_utf8())
			if data is Dictionary:
				server_state = data
				messages = data.get("messages",[])
				unread_messages = 0
				for message in messages:
					var read_key = "direct:"+str(message.sender) if message.channel == "direct" else str(message.channel)
					if message.sender != "shell-01" and int(message.id) > int(data.get("reads",{}).get(read_key,0)):
						unread_messages += 1
					if int(message.id) > newest_message and message.sender != "shell-01":
						if not data.get("preferences",{}).get("muted",[]).has(message.sender):
							notify_message(message)
					newest_message = maxi(newest_message,int(message.id))
				for cmd in data.get("commands",[]):
					if int(cmd.id) > command_ack:
						apply_command(cmd)
						command_ack = int(cmd.id)
	)
	poll = HTTPRequest.new()
	add_child(poll)
	poll.timeout = 2

func host_request(path: String, body: Dictionary = {}):
	if auth == "":
		return
	if poll.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	poll.request("http://127.0.0.1:8787/host/"+path,["Content-Type: application/json","Authorization: Bearer "+auth],HTTPClient.METHOD_POST,JSON.stringify(body))

func host_action(title):
	match title:
		"Pair code": host_request("code")
		"Approve READ", "Approve CONTROL":
			var pending = server_state.get("pending",[])
			if not pending.is_empty():
				host_request("approve",{"id":pending[0].id,"permission":"control" if title == "Approve CONTROL" else "read"})
		"Revoke all": host_request("revoke",{"id":"all"})
		"DND": dnd = not dnd
		"Hide previews": private_preview = not private_preview
		"Sound": notification_sound = not notification_sound
		"Pop-ups": notification_popups = not notification_popups
		"Open message": panel = 4; host_request("read")
		"Dismiss": notice.text = ""
		"Reply":
			if not messages.is_empty():
				selected_channel = "direct"
				input_line.text = str(messages[-1].sender)+": "
				input_line.grab_focus()
		"Mark read": host_request("read")
		"Mute last sender", "Block last sender":
			if not messages.is_empty():
				var key = "muted" if title == "Mute last sender" else "blocked"
				var current: Array = server_state.get("preferences",{}).get(key,[]).duplicate()
				current.append(messages[-1].sender)
				host_request("preferences",{key:current})
		"Report last message":
			if not messages.is_empty():
				host_request("report",{"id":messages[-1].id,"reason":"Player report"})
				notify("Report stored in volatile local memory. No moderation backend.")

func send_chat(text):
	if text.strip_edges() == "": return
	var to = ""
	if selected_channel == "direct":
		var split = text.split(":",true,1)
		if split.size() != 2:
			notify("Direct messages require player-id: message")
			return
		to = split[0].strip_edges()
		text = split[1].strip_edges()
	host_request("chat",{"channel":selected_channel,"text":text,"to":to})
	input_line.clear()

func apply_command(cmd):
	match cmd.get("action", ""):
		"panel": panel = clampi(int(cmd.get("value",0)),0,5)
		"probe": probe_angle += clampf(float(cmd.get("value",0)),-0.3,0.3)
		"mount": mount = (mount+1)%MOUNTS.size()

func _unhandled_input(event):
	if OS.has_feature("web") and event is InputEventMouseButton and event.pressed and not menu.visible and not graphics.popup.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if visual_test or smoke or terrain_test: return
	if event is InputEventKey and event.pressed and not event.echo:
		if OS.has_feature("web") and event.physical_keycode in [KEY_P,KEY_BRACKETLEFT,KEY_BRACKETRIGHT] and not input_line.has_focus():
			graphics.web_shortcut(event.physical_keycode);return
		if event.physical_keycode == KEY_F10:
			graphics.toggle();return
		if event.physical_keycode == KEY_ENTER and event.alt_pressed:
			graphics.settings.mode = 1 if graphics.settings.mode == 0 else 0
			graphics.apply_display(graphics.settings);graphics.write_settings();return
		if event.physical_keycode == KEY_ESCAPE and graphics.popup.visible:
			graphics.toggle();return
	if graphics != null and graphics.popup.visible: return
	if event is InputEventMouseMotion and hatched and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or (OS.has_feature("web") and event.button_mask & MOUSE_BUTTON_MASK_LEFT and not menu.visible and not graphics.popup.visible)):
		yaw -= event.relative.x*0.0025
		pitch = clampf(pitch-event.relative.y*0.0025,-1.3,1.3)
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_E:
			if not hatched and hatch_time < 0: hatch_time = 0
			elif hatched:
				if labyrinth == null or not labyrinth.interact(): salvage.begin()
		KEY_T: salvage.cycle()
		KEY_TAB:
			menu.visible = not menu.visible
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if menu.visible else Input.MOUSE_MODE_CAPTURED
		KEY_ESCAPE:
			menu.visible = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		KEY_C: craft()
		KEY_F: refill()
		KEY_M: mount = (mount+1)%MOUNTS.size()
		KEY_O: portrait = not portrait
		KEY_F5: save_game()
		KEY_F9: load_game()
		KEY_K:
			if OS.has_feature("web"): save_game()
		KEY_L:
			if OS.has_feature("web"): load_game()
		KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6: panel = event.physical_keycode-KEY_1

func _physics_process(delta):
	time += delta
	if web_dome != null: web_dome.position = camera.global_position
	if hatch_time >= 0 and not hatched:
		hatch_time += delta
		for i in range(shell.get_child_count()):
			var petal = shell.get_child(i)
			var a = i*TAU/8
			petal.position = Vector3(sin(a)*(0.85+hatch_time),-hatch_time*0.4,cos(a)*(0.85+hatch_time))
		if hatch_time > 2.5:
			hatched = true
			notify("SHELL RELEASED // Gather ceramic and conductive fiber. Grow a thermal membrane [C].")
	if hatched:
		player.rotation.y = yaw
		camera.rotation.x = pitch
		var axis = Vector2.ZERO
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or (OS.has_feature("web") and not menu.visible and not graphics.popup.visible and not input_line.has_focus()):
			axis = Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		if smoke and smoke_stage == 2: axis = Vector2(0,-1)
		if terrain_test and terrain_test_case >= 0: axis = Vector2(0,-1)
		var dir = player.basis * Vector3(axis.x,0,axis.y).normalized()
		var speed = 7.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 4.0
		player.velocity.x = dir.x*speed
		player.velocity.z = dir.z*speed
		player.velocity.y -= 18*delta
		if player.is_on_floor() and Input.is_physical_key_pressed(KEY_SPACE) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			player.velocity.y = 6
		player.move_and_slide()
		player.position.x = clampf(player.position.x,-127,127)
		player.position.z = clampf(player.position.z,-127,127)
		if coast != null and player.position.y < -3.5: coast.rescue_player()
		var ambient = 14.0 if player.position.x < 0 else 46.0
		temperature = move_toward(temperature,ambient,delta*(0.08 if upgrade else 0.22))
		energy = maxf(0,energy-delta*(0.035+axis.length()*0.035))
		fluid = maxf(0,fluid-delta*(0.018 if upgrade else 0.04))
		if energy <= 0 or fluid <= 0 or temperature < 18 or temperature > 43:
			integrity = maxf(0,integrity-delta*0.5)
		if integrity <= 0:
			player.position = Vector3(0,3,0)
			integrity = 60; energy = 45; fluid = 45; temperature = 36
			notify("EMERGENCY RECONSTITUTION // Returned to shell. Resources retained.")
	update_ecology(delta)
	if labyrinth != null: labyrinth.step(delta)
	if not smoke and not terrain_test and not visual_test: salvage.tick(delta,Input.is_physical_key_pressed(KEY_E))
	update_terminal(delta)
	update_ui()
	if labyrinth != null: hud.text += "\n"+labyrinth.status()
	if labyrinth != null: hud.text = hud.text.replace("SURVEY SECTOR 01","RECONFIGURING LABYRINTH")
	sync_time += delta
	if sync_time > 0.5:
		sync_time = 0
		if web_qa:
			var qa = snapshot()
			qa["notice"] = notice.text;qa["yaw"] = yaw;qa["menu"] = menu.visible
			qa["salvage"] = {"tool":salvage.tool,"progress":salvage.progress,"duration":salvage.duration,"recovered":salvage.recovered}
			qa["music_playing"] = weather.audio.playing
			JavaScriptBridge.eval("window.velumState = "+JSON.stringify(qa)+";")
		if not smoke and not terrain_test and auth == "" and FileAccess.file_exists(runtime_dir.path_join("host.key")):
			auth = FileAccess.get_file_as_string(runtime_dir.path_join("host.key")).strip_edges()
		if not OS.has_feature("web") and DisplayServer.get_name() != "headless":
			var image = probe_view.get_texture().get_image()
			if image != null and not image.is_empty():
				probe_jpeg = Marshalls.raw_to_base64(image.save_jpg_to_buffer(0.6))
		if http != null and http.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED and auth != "":
			var payload = snapshot()
			payload["boards"] = board_terrain.map_snapshot()
			payload["probeImage"] = probe_jpeg
			http.request("http://127.0.0.1:8787/host/state",["Content-Type: application/json","Authorization: Bearer "+auth],HTTPClient.METHOD_POST,JSON.stringify(payload))
	if smoke: smoke_test(delta)
	if visual_test: visual_check(delta)
	if terrain_test: board_walk_check(delta)

func update_ecology(delta):
	if not smoke and not terrain_test and not visual_test: spawning.tick(delta)
	for r in resources:
		if r.cooldown > 0:
			r.cooldown = maxf(0,r.cooldown-delta)
			r.node.visible = r.cooldown <= 0
			r.charge = minf(1,r.charge+delta*0.02)
	for c in creatures:
		organisms.step(c,delta)

func update_terminal(delta):
	if OS.has_feature("web"):
		web_screen_clock += delta
		if web_screen_clock > 0.10:
			web_screen_clock = 0
			screen.render_target_update_mode = SubViewport.UPDATE_ONCE
			if panel == 3: probe_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	if portrait != last_portrait:
		last_portrait = portrait
		screen.size = Vector2i(480,720) if portrait else Vector2i(720,480)
		screen.get_child(0).size = Vector2(screen.size)
		terminal_label.size = Vector2(432,670) if portrait else Vector2(320,430)
		terminal_display.mesh.size = Vector2(0.33,0.49) if portrait else Vector2(0.49,0.33)
		terminal_display.rotation.z = 0 if portrait else -PI/2
		probe_image.position = Vector2(15,280) if portrait else Vector2(350,150)
		probe_image.size = Vector2(450,253) if portrait else Vector2(350,197)
		map_view.position = Vector2(30,250) if portrait else Vector2(360,80)
		map_view.scale = Vector2.ONE if portrait else Vector2.ONE*0.75
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or (OS.has_feature("web") and not menu.visible and not graphics.popup.visible):
		tilt = clampf(tilt+(float(Input.is_physical_key_pressed(KEY_UP))-float(Input.is_physical_key_pressed(KEY_DOWN)))*delta,-0.55,0.55)
		pivot = clampf(pivot+(float(Input.is_physical_key_pressed(KEY_LEFT))-float(Input.is_physical_key_pressed(KEY_RIGHT)))*delta,-0.7,0.7)
		probe_angle += (float(Input.is_physical_key_pressed(KEY_R))-float(Input.is_physical_key_pressed(KEY_Q)))*delta
	var offsets = [Vector3(0.35,-0.25,-0.8),Vector3(-0.36,-0.3,-0.78),Vector3(0.36,-0.3,-0.78),Vector3(-0.35,-0.38,-0.95),Vector3(0.35,-0.38,-0.95),Vector3.ZERO,Vector3(0,-0.05,-0.7)]
	var target = camera.global_transform * Transform3D(Basis.from_euler(Vector3(tilt,pivot,0 if portrait else PI/2)),offsets[mount])
	if mount == 5:
		target = Transform3D(Basis.from_euler(Vector3(-0.4,pivot,0 if portrait else PI/2)),Vector3(3,height_at(3,0)+1.35,0))
	terminal.global_transform = terminal.global_transform.interpolate_with(target,1-exp(-delta*12))
	terminal.visible = hatched
	probe.position = player.position+Vector3(sin(probe_angle)*8,10,cos(probe_angle)*8)
	probe.look_at(player.position)
	probe_image.visible = panel == 3
	map_view.visible = panel == 1
	map_view.queue_redraw()

func panel_text() -> String:
	var text = "VELUM / LINK\n"+PANELS[panel]+"  •  "+MOUNTS[mount]+"\n────────────────────\n"
	if OS.has_feature("web"): text = text.replace("────────────────────","--------------------")
	match panel:
		0: text += "ENERGY  %.1f %%\nTEMP  %.1f °C\nWORKING FLUID  %.1f %%\nINTEGRITY  %.1f %%\n\nCERAMIC  %d\nFIBER  %d\nMEMBRANE  %s\n\n%s\nBounded sector 240 × 240 m\nSeed %d" % [energy,temperature,fluid,integrity,ceramic,fiber,"GROWN" if upgrade else "C: 2 ceramic + 2 fiber", "CAPACITOR FLATS" if player.position.x < 0 else "TRANSISTOR GROVE",WORLD_SEED]
		1: text += "LIVE POSITION\nX %.1f  Z %.1f\n240 m survey sector\nCyan: resource • White: shell" % [player.position.x,player.position.z]
		2:
			text += "LOCAL SCANNER / 20 m\n"
			for r in resources:
				var distance = player.position.distance_to(r.node.position)
				if distance < 20:
					text += "\n%s %.1fm  %s" % [r.kind,distance,"regenerating" if r.cooldown > 0 else "ready"]
			text += "\n\n"+spawning.report()+"\nCharge → reservoir → transported deposit\nValves: UNPLUG to interrupt / RIP to recover shell"
			for c in creatures:
				if c.node.position.distance_to(player.position) < 10:
					text += "\n%s: charge %.0f%% / coolant %.0f%% / cargo %.2f / deliveries %d" % [c.node.name,c.charge*100,c.coolant*100,c.carried,c.delivered]
		3: text += "PROBE 01 / LIVE RENDER\nQ / R orbit control\nCamera follows movable probe"
		4:
			text += "NATIVE GAME CHAT • %d unread\nNo moderation backend\n" % unread_messages
			for m in messages.slice(maxi(0,messages.size()-6)):
				text += "\n[%s] %s %s: %s (%s)" % [m.get("channel",""),str(m.get("timestamp","")).substr(11,8),m.get("sender",""),m.get("text","") if private_preview else "[hidden]",m.get("status","")]
		5:
			text += "SERVER %s\nCODE %s\nExpires in 120 seconds\nPending approval: %d\nConnected sessions: %d\n\nTab → Pair code / Approve\nRead-only is default.\nLAN requires HTTPS setup." % ["ONLINE" if online else "OFFLINE",server_state.get("code","—"),server_state.get("pending",[]).size(),server_state.get("devices",[]).size()]
	return text

func update_ui():
	hud.text = "V E L U M    /    SURVEY SECTOR 01\nEnergy %03.0f   Fluid %03.0f   Integrity %03.0f   %.1f °C\n%s  |  %s" % [energy,fluid,integrity,temperature,"CAPACITOR FLATS" if player.position.x < 0 else "TRANSISTOR GROVE","LINK online" if online else "LINK offline • single-screen play available"]
	if weather != null: hud.text += "\n%02d:%02d • %s • signal intakes %d" % [int(weather.day_time*24),int(fmod(weather.day_time*1440,60)),weather.phase_name,weather.signals.received]
	if hatched: hud.text += "\n"+salvage.status()
	terminal_label.text = panel_text()
	if menu.visible:
		menu_text.text = panel_text()+"\n\nPending: "+JSON.stringify(server_state.get("pending",[]))+"\nDevices: "+JSON.stringify(server_state.get("devices",[]))
	if time-last_notice > 8: notice.text = ""

func draw_map():
	map_view.draw_rect(Rect2(Vector2.ZERO,Vector2(420,420)),Color("10303b"))
	map_view.draw_rect(Rect2(Vector2.ZERO,Vector2(210,420)),Color("54656b"))
	for plate in board_terrain.plates.slice(1):
		var points = PackedVector2Array()
		for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			points.append((plate.center+(corner*plate.size*0.5).rotated(-plate.yaw))*1.75+Vector2(210,210))
		map_view.draw_colored_polygon(points,Color("1a3f2a").lerp(Color("76934e"),plate.top/6.75))
		points.append(points[0])
		map_view.draw_polyline(points,Color("b39b54"),1.0)
	for ramp in board_terrain.ramps:
		map_view.draw_line(Vector2(ramp.a.x,ramp.a.z)*1.75+Vector2(210,210),Vector2(ramp.b.x,ramp.b.z)*1.75+Vector2(210,210),Color("d4be72"),2.0)
	for r in resources:
		var p: Vector3 = r.node.position
		map_view.draw_circle(Vector2(p.x,p.z)*1.75+Vector2(210,210),3,Color("5be9bb") if r.cooldown <= 0 else Color("48555b"))
	map_view.draw_circle(Vector2(210,210),5,Color.WHITE)
	map_view.draw_circle(Vector2(player.position.x,player.position.z)*1.75+Vector2(210,210),7,Color("ffbf73"))
	if labyrinth != null:
		for wall in labyrinth.walls:
			map_view.draw_rect(Rect2((wall.center-wall.size*0.5)*1.75+Vector2(210,210),wall.size*1.75),Color("bdad6c"))
		labyrinth.draw_network(map_view)

func gather(chosen: Dictionary = {}):
	var best: Dictionary = {}
	var distance = 3.5
	for r in resources:
		if not chosen.is_empty() and r.id != chosen.id: continue
		var d = player.position.distance_to(r.node.position)
		if d < distance and r.cooldown <= 0:
			best = r; distance = d
	if best.is_empty():
		notify("No harvestable material within 3.5 m. Use scanner [3].")
		return false
	if best.kind == "ceramic": ceramic += 1
	else: fiber += 1
	energy = minf(100,energy+best.charge*8)
	best.cooldown = 45.0
	best.node.visible = false
	if procedural_detail != null: procedural_detail.burst(best.node.position)
	notify("%s recovered • socket remains connected to the circuit." % best.kind)
	return true

func craft():
	if not hatched: return false
	if upgrade:
		notify("Thermal membrane already grown."); return false
	if ceramic < 2 or fiber < 2:
		notify("Membrane requires 2 ceramic + 2 conductive fiber."); return false
	ceramic -= 2; fiber -= 2; upgrade = true
	notify("THERMAL MEMBRANE GROWN // Reduced temperature drift and fluid consumption.")
	return true

func refill():
	if player.position.length() < 9 and hatched:
		fluid = minf(100,fluid+25); energy = minf(100,energy+15)
		notify("Shell condenser: working fluid and solar charge restored.")
	else: notify("Return to shell condenser to refill [F].")

func notify(text):
	if dnd: return
	if notice: notice.text = text
	last_notice = time

func make_notification_audio():
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var samples = PackedByteArray()
	samples.resize(4410)
	for i in range(2205):
		samples.encode_s16(i*2,int(sin(TAU*660*i/22050.0)*1200*(1-i/2205.0)))
	wav.data = samples
	audio_player = AudioStreamPlayer.new()
	audio_player.stream = wav
	add_child(audio_player)

func notify_message(message):
	if dnd: return
	popup_group = popup_group+1 if time-last_message_popup < 5 else 1
	last_message_popup = time
	if notification_popups:
		notify("VELUM / %s • %d new • %s" % [message.sender,popup_group,str(message.text) if private_preview else "Preview hidden"])
	if notification_sound and popup_group == 1:
		audio_player.play()

func snapshot() -> Dictionary:
	var nodes = []
	for r in resources:
		nodes.append({"id":r.id,"kind":r.kind,"x":r.node.position.x,"z":r.node.position.z,"cooldown":r.cooldown,"charge":r.charge})
	return {"seed":WORLD_SEED,"hatched":hatched,"x":player.position.x,"y":player.position.y,"z":player.position.z,"energy":energy,"fluid":fluid,"temperature":temperature,"integrity":integrity,"ceramic":ceramic,"fiber":fiber,"upgrade":upgrade,"mount":mount,"panel":panel,"portrait":portrait,"tilt":tilt,"pivot":pivot,"probe":probe_angle,"resources":nodes,"ack":command_ack,"labyrinth":labyrinth.snapshot() if labyrinth != null else {},"sector":"81 streamed labyrinth sections; 198m resident chamber; not a seamless planet" if labyrinth != null else "Bounded 240m prototype; not a seamless planet"}

func save_game():
	var f = FileAccess.open(runtime_dir.path_join("smoke-save.json" if smoke else "save-%d.json" % WORLD_SEED),FileAccess.WRITE)
	if f == null:
		notify("Save failed: "+error_string(FileAccess.get_open_error())); return false
	var state = snapshot()
	state["terrain_version"] = 2
	if labyrinth != null: state["labyrinth"] = labyrinth.snapshot()
	if weather != null: state["weather"] = weather.snapshot_state()
	state["population"] = spawning.snapshot_state()
	if coast != null: state["coast"] = coast.snapshot_state()
	f.store_string(JSON.stringify(state))
	f.close()
	notify("Saved in browser storage." if OS.has_feature("web") else "Saved locally on D: • sessions and credentials excluded.")
	return true

func load_game():
	var save_path = runtime_dir.path_join("smoke-save.json" if smoke else "save-%d.json" % WORLD_SEED)
	if not smoke and not FileAccess.file_exists(save_path): save_path = runtime_dir.path_join("save.json")
	if not FileAccess.file_exists(save_path):
		notify("No save yet."); return false
	var s = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not s is Dictionary: return false
	if s.get("seed") != WORLD_SEED:
		notify("This save belongs to seed %s. Select that world seed before loading." % str(s.get("seed","unknown")));return false
	player.position = Vector3(s.x,s.y,s.z)
	if int(s.get("terrain_version",1)) < 2 or player.position.y < height_at(s.x,s.z)+0.80:
		player.position.y = height_at(s.x,s.z)+0.95
	player.velocity = Vector3.ZERO
	energy = clampf(s.energy,0,100); fluid = clampf(s.fluid,0,100)
	temperature = clampf(s.temperature,-20,90); integrity = clampf(s.integrity,0,100)
	ceramic = maxi(0,int(s.ceramic)); fiber = maxi(0,int(s.fiber)); upgrade = s.upgrade
	hatched = s.hatched
	shell.visible = not hatched
	mount = clampi(int(s.mount),0,6); panel = clampi(int(s.panel),0,5)
	portrait = s.portrait; tilt = clampf(s.tilt,-0.55,0.55); pivot = clampf(s.pivot,-0.7,0.7)
	probe_angle = s.probe
	salvage.cancel()
	if weather != null and s.get("weather") is Dictionary: weather.restore_state(s.weather)
	if coast != null: coast.restore_state(s.get("coast",{}))
	for r in s.resources:
		if int(r.id) < resources.size():
			resources[int(r.id)].cooldown = maxf(0,r.cooldown)
			resources[int(r.id)].charge = clampf(r.charge,0,1)
			resources[int(r.id)].node.visible = r.cooldown <= 0
	if s.get("population") is Dictionary: spawning.restore_state(s.population)
	if labyrinth != null:
		labyrinth.restore(s.get("labyrinth",{}))
		navigation.usable.clear();navigation.points.clear();navigation.reachable_resources.clear();navigation.setup(self);navigation.index_resources()
		for c in creatures:
			c.node.position = navigation.safe_spawn(c.node.position)+Vector3(0,1,0);c.path = PackedVector2Array();c.path_index = 0
	notify("Save restored.")
	return true

func smoke_test(delta):
	smoke_clock += delta
	if smoke_stage == 0:
		hatch_time = 0; smoke_stage = 1
	elif smoke_stage == 1 and hatched:
		if not runtime_check(resources.size() == 38 and creatures.size() == 9,"Seeded ecology counts"): return
		for i in range(4):
			player.position = resources[i].node.position+Vector3(0,0.7,0)
			if not runtime_check(gather(),"Gather resource "+str(i)): return
		if not runtime_check(craft() and upgrade,"Grow thermal membrane"): return
		if not runtime_check(save_game(),"Save playable state"): return
		var old_energy = energy
		energy = 1
		if not runtime_check(load_game() and absf(energy-old_energy)<0.01,"Load and restore energy"): return
		# Exercise legacy-save migration using the isolated smoke save, never the player's save.
		var legacy = JSON.parse_string(FileAccess.get_file_as_string(runtime_dir.path_join("smoke-save.json")))
		legacy.erase("terrain_version")
		legacy["y"] = -20.0
		var legacy_file = FileAccess.open(runtime_dir.path_join("smoke-save.json"),FileAccess.WRITE)
		legacy_file.store_string(JSON.stringify(legacy));legacy_file.close()
		if not runtime_check(load_game() and player.position.y >= height_at(player.position.x,player.position.z)+0.90,"Legacy save relocation"): return
		if not runtime_check(save_game(),"Save migrated state"): return
		var independent_layout = load("res://board_terrain.gd").new()
		independent_layout.configure(WORLD_SEED)
		for i in range(12):
			if not runtime_check(absf(height_at(i*4,i*7)-independent_layout.height_at(i*4,i*7)) < 0.00001,"Reproducible board layout"): return
		smoke_start_position = player.position
		smoke_move_started = smoke_clock
		smoke_stage = 2
	elif smoke_stage == 2 and smoke_clock-smoke_move_started > 3:
		var moved = Vector2(player.position.x-smoke_start_position.x,player.position.z-smoke_start_position.z).length()
		if moved <= 2:
			for i in range(player.get_slide_collision_count()):
				var collision = player.get_slide_collision(i)
				print("COLLISION ",collision.get_normal()," ",collision.get_position()," ",collision.get_collider())
			push_error("VELUM movement test failed: " + str(moved) + " start=" + str(smoke_start_position) + " end=" + str(player.position) + " grounded=" + str(player.is_on_floor()))
			get_tree().quit(1)
			return
		for i in range(7):
			mount = i; update_terminal(0.1)
			if not runtime_check(terminal.global_transform.origin.is_finite(),"Terminal mount transform"): return
		portrait = false; update_terminal(0.1)
		panel = 3; update_terminal(0.1)
		if not runtime_check(probe_image.visible and fluid < 80 and energy < 100 and temperature != 36,"Probe and survival update"): return
		print("VELUM_SMOKE_PASS hatch movement gather survival craft save load reproducible-terrain mounts landscape probe ecology")
		get_tree().quit(0)

func visual_check(delta):
	visual_clock += delta
	if voxel_test:
		voxel_visual_check()
		return
	if graphics_test:
		graphics_visual_check()
		return
	if dlss_test:
		dlss_visual_check()
		return
	if interior_test:
		interior_visual_check()
		return
	if sky_test:
		sky_visual_check()
		return
	if visual_stage == 0 and visual_clock > 1:
		capture_frame("01-egg.png")
		hatch_time = 0
		visual_stage = 1
	elif visual_stage == 1 and visual_clock > 5:
		capture_frame("02-hatched-status.png")
		panel = 1
		visual_stage = 2
	elif visual_stage == 2 and visual_clock > 7:
		capture_frame("03-live-map.png")
		panel = 3
		visual_stage = 3
	elif visual_stage == 3 and visual_clock > 9:
		capture_frame("04-probe.png")
		portrait = false
		menu.visible = true
		panel = 5
		visual_stage = 4
	elif visual_stage == 4 and visual_clock > 11:
		capture_frame("05-pairing.png")
		print("VELUM_VISUAL_PASS • five actual DX12 rendered frames saved")
		get_tree().quit(0)

func sky_visual_check():
	if visual_stage == 0 and visual_clock > 1:
		hatch_time = 0
		pitch = deg_to_rad(25)
		visual_stage = 1
	elif visual_stage == 1 and visual_clock > 5:
		capture_frame("sky-01-clouds.png")
		visual_stage = 2
	elif visual_stage == 2 and visual_clock > 8:
		capture_frame("sky-02-motion.png")
		pitch = deg_to_rad(-12)
		yaw = 0.45
		visual_stage = 3
	elif visual_stage == 3 and visual_clock > 10:
		capture_frame("sky-03-ground-normals.png")
		visual_stage = 4
	elif visual_stage == 4 and visual_clock > 12:
		print("VELUM_SKY_VISUAL_PASS • procedural sky / animated tech clouds / terrain normals")
		get_tree().quit(0)

func capture_frame(name):
	var image = get_viewport().get_texture().get_image()
	if image != null:
		var error = image.save_png(runtime_dir.path_join(name))
		assert(error == OK)

func interior_view(pos: Vector3,target: Vector3):
	player.position = pos
	player.velocity = Vector3.ZERO
	var direction = target-(pos+Vector3(0,0.65,0))
	yaw = atan2(-direction.x,-direction.z)
	pitch = atan2(direction.y,Vector2(direction.x,direction.z).length())

func begin_board_walk_case(index: int):
	terrain_test_case = index
	terrain_test_clock = 0
	var ramp = board_terrain.ramps[index]
	player.position = ramp.a+Vector3.UP*0.95
	player.velocity = Vector3.ZERO
	yaw = atan2(-(ramp.b.x-ramp.a.x),-(ramp.b.z-ramp.a.z))
	pitch = 0

func board_walk_check(delta):
	if terrain_test_case < 0:
		begin_board_walk_case(0)
		return
	terrain_test_clock += delta
	var ramp = board_terrain.ramps[terrain_test_case]
	var a = Vector2(ramp.a.x,ramp.a.z)
	var b = Vector2(ramp.b.x,ramp.b.z)
	var along = (Vector2(player.position.x,player.position.z)-a).dot((b-a).normalized())
	if along > a.distance_to(b)+1.1:
		if player.position.y < ramp.b.y+0.75:
			push_error("PCB ramp ended below upper board: "+str(terrain_test_case)); get_tree().quit(1); return
		print("PCB_RAMP_PASS ",terrain_test_case," height=",snappedf(player.position.y,0.01))
		if terrain_test_case+1 == board_terrain.ramps.size():
			print("VELUM_BOARD_TRAVERSAL_PASS all seven physical ramps reached their upper board")
			get_tree().quit(0)
		else: begin_board_walk_case(terrain_test_case+1)
	elif terrain_test_clock > a.distance_to(b)/4.0+4.0:
		push_error("PCB ramp blocked: %d at %s, progress %.2f" % [terrain_test_case,str(player.position),along])
		get_tree().quit(1)

func interior_visual_check():
	if visual_stage == 0 and visual_clock > 1:
		hatch_time = 0
		pitch = deg_to_rad(25)
		visual_stage = 1
	elif visual_stage == 1 and visual_clock > 5:
		capture_frame("interior-01-chassis-sky.png")
		interior_view(Vector3(4,height_at(4,-6)+1.0,-6),Vector3(9,height_at(8,-13)+4.4,-13))
		visual_stage = 2
	elif visual_stage == 2 and visual_clock > 8:
		capture_frame("interior-02-transistor-web.png")
		interior_view(Vector3(0,height_at(0,0)+1.0,0),Vector3(-6,height_at(-6,-8),-8))
		visual_stage = 3
	elif visual_stage == 3 and visual_clock > 11:
		capture_frame("interior-03-pcb-ground.png")
		camera.top_level = true
		camera.position = Vector3(15,24,40)
		camera.look_at(Vector3(0,1,-35))
		pitch = camera.rotation.x
		panel = 1
		visual_stage = 4
	elif visual_stage == 4 and visual_clock > 13:
		capture_frame("interior-04-stacked-boards.png")
		print("VELUM_INTERIOR_VISUAL_PASS • stacked PCB slabs / component ecology / cable canopy / live board map")
		get_tree().quit(0)

func graphics_visual_check():
	if visual_stage == 0 and visual_clock > 1:
		hatch_time = 0
		graphics.toggle()
		visual_stage = 1
	elif visual_stage == 1 and visual_clock > 4:
		if not runtime_check(world_environment.environment.sdfgi_enabled and world_environment.environment.volumetric_fog_enabled and directional_sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,"High GI/fog/shadow configuration"): return
		capture_frame("graphics-01-menu.png")
		graphics.resolution.select(2)
		graphics.mode.select(0)
		graphics.preset.select(3);graphics.select_preset(3)
		graphics.upscaler.select(1)
		graphics.apply_from_ui()
		if not runtime_check(graphics.confirm_remaining > 0,"Display confirmation timer"): return
		visual_stage = 2
	elif visual_stage == 2 and visual_clock > 6:
		print("GRAPHICS_WINDOW_STATE mode=",get_window().mode," size=",get_window().size," scaling=",get_viewport().scaling_3d_mode," pending=",graphics.confirm_remaining)
		if get_window().mode != Window.MODE_WINDOWED or DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED or get_viewport().scaling_3d_mode != Viewport.SCALING_3D_MODE_FSR2:
			push_error("Window/upscaler state did not match applied settings");get_tree().quit(1);return
		if not runtime_check(world_environment.environment.sdfgi_cascades == 6,"Ultra SDFGI six cascades"): return
		capture_frame("graphics-02-window-fsr2.png")
		graphics._process(16.0)
		if not runtime_check(graphics.confirm_remaining <= 0 and graphics.settings.width == 1280,"Automatic display rollback"): return
		print("VELUM_DISPLAY_REVERT_PASS")
		graphics.mode.select(1);graphics.apply_from_ui();graphics.keep_display()
		visual_stage = 3
	elif visual_stage == 3 and visual_clock > 8:
		if not runtime_check(get_window().mode == Window.MODE_FULLSCREEN and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,"Borderless fullscreen"): return
		capture_frame("graphics-03-borderless.png")
		graphics.mode.select(2);graphics.apply_from_ui();graphics.keep_display()
		visual_stage = 4
	elif visual_stage == 4 and visual_clock > 10:
		if not runtime_check(get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,"Exclusive fullscreen"): return
		capture_frame("graphics-04-exclusive.png")
		graphics.mode.select(0);graphics.apply_from_ui();graphics.keep_display()
		visual_stage = 5
	elif visual_stage == 5 and visual_clock > 12:
		var original_path = graphics.config_path
		graphics.config_path = runtime_dir.path_join("graphics-test.cfg")
		graphics.test_mode = false
		graphics.write_settings()
		graphics.settings.scale = 0.5
		graphics.read_settings()
		if not runtime_check(is_equal_approx(graphics.settings.scale,1.0),"Graphics settings persistence"): return
		graphics.test_mode = true;graphics.config_path = original_path
		capture_frame("graphics-05-restored.png")
		print("VELUM_GRAPHICS_RUNTIME_PASS GI volumetric 4-cascade shadows window resolution borderless exclusive FSR2 auto-revert persisted-test-settings")
		get_tree().quit(0)

func dlss_visual_check():
	if visual_stage == 1 and hatched:
		yaw = sin(visual_clock*0.35)*0.55
		pitch = sin(visual_clock*0.21)*0.12
	if visual_stage == 0 and visual_clock > 1:
		hatch_time = 0
		if graphics.dlss_mode < 0:
			push_error("DLSS unavailable on current engine/runtime/hardware")
			get_tree().quit(2);return
		graphics.settings.upscaler = "dlss_quality"
		graphics.settings.fg = graphics.fg_property and not "--sr-only" in OS.get_cmdline_user_args()
		graphics.apply_render(graphics.settings)
		get_window().grab_focus()
		visual_stage = 1
	elif visual_stage == 1 and visual_clock > 20:
		var diagnostic = graphics.streamline.call("get_diagnostics") if graphics.streamline.has_method("get_diagnostics") else {}
		if visual_clock-last_dlss_report > 1:
			last_dlss_report = visual_clock
			print("VELUM_DLSS_DIAGNOSTICS focus=",get_window().has_focus()," output=",get_window().size," ",JSON.stringify(diagnostic))
		var require_fg = graphics.fg_property and not "--sr-only" in OS.get_cmdline_user_args()
		if int(diagnostic.get("sr_frames",0)) > 0 and (not require_fg or (int(diagnostic.get("fg_extra_frames",0)) > 0 and int(diagnostic.get("fg_status",-1)) == 0)):
			if "--gi-voxel" in OS.get_cmdline_user_args():
				if not runtime_check(graphics.voxel_probe != null and graphics.voxel_probe.data != null and graphics.voxel_probe.visible,"VoxelGI must be active during DLSS/FG test"): return
			capture_frame("graphics-06-dlss-fg.png")
			print("VELUM_DLSS_RUNTIME_PASS SR=true FG=",require_fg)
			get_tree().quit(0)
		elif visual_clock > 45:
			push_error("DLSS/FG render counters did not confirm active rendering")
			get_tree().quit(1)

func voxel_visual_check():
	if visual_stage == 0 and visual_clock > 1:
		hatch_time = 0
		graphics.settings.gi_mode = "voxel"
		graphics.apply_render(graphics.settings)
		visual_stage = 1
	elif visual_stage == 1 and not graphics.voxel_baking and graphics.voxel_probe != null and visual_clock > 6:
		if graphics.voxel_probe.data == null:
			push_error("VoxelGI bake produced no data");get_tree().quit(1);return
		var cells = graphics.voxel_probe.data.get_data_cells().size()
		if not runtime_check(cells > 0 and graphics.voxel_probe.visible and not world_environment.environment.sdfgi_enabled,"VoxelGI data/render mode"): return
		capture_frame("graphics-07-voxelgi.png")
		print("VELUM_VOXELGI_RUNTIME_PASS subdiv=512 two_bounces=true cells_bytes=",cells)
		get_tree().quit(0)

func runtime_check(condition: bool,message: String) -> bool:
	if not condition:
		push_error("VELUM_TEST_FAIL "+message)
		get_tree().quit(1)
	return condition
