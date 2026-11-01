extends CanvasLayer
## Signal weather is fictional. Music is a credited CC0 chiptune recording.
var game
var clock = 0.0
var strength = 0.0
var flashes = true
var sound = false
var music_volume = 0.12
var enabled = true
var rain: MultiMeshInstance3D
var rain_material: ShaderMaterial
var inscription: Label3D
var overlay: ColorRect
var audio: AudioStreamPlayer
var phase_name = "QUIET BUS"
var rng = RandomNumberGenerator.new()
var rain_rng = RandomNumberGenerator.new()
var day_time = 0.28
var day_seconds = 1080.0
var remaining = 18.0
var weather_kind = 0
var target_strength = 0.0
var transitions = 0
var post_enabled = true
var post: ColorRect
var signals = preload("res://signal_network.gd").new()
var drops: Array[Dictionary] = []
var impact_budget = 0.0
var qa_timer = 0.0
var cloud_altitude = 35.0
var heat_mist
var daylight_timer = 1.0
var solar_energy = 1.25
var cloud_amount = 0.18
var rain_delay = 0.0
var wind = Vector3(0.6,0,0.22)
var wind_target = Vector3(0.6,0,0.22)
var wind_offset = Vector2.ZERO
var dust_materials: Array[ParticleProcessMaterial] = []
var wind_clock = 0.0
var atmosphere_sound = true
var atmosphere_volume = 0.24
var wind_audio: AudioStreamPlayer
var rain_audio: AudioStreamPlayer

func setup(owner_game):
	game = owner_game;layer = -2
	for emitter in game.find_children("*","GPUParticles3D",true,false):
		if emitter.process_material is ParticleProcessMaterial: dust_materials.append(emitter.process_material)
	rng.seed = game.WORLD_SEED ^ int(Time.get_unix_time_from_system())
	rain_rng.seed = rng.seed ^ 0xC10D
	var cfg = ConfigFile.new()
	if cfg.load(game.runtime_dir.path_join("weather.cfg")) == OK:
		flashes = cfg.get_value("weather","flashes",true);enabled = cfg.get_value("weather","enabled",true)
		post_enabled = cfg.get_value("weather","post_enabled",true)
		music_volume = clampf(float(cfg.get_value("weather","music_volume",0.12)),0,1)
		atmosphere_sound = cfg.get_value("weather","atmosphere_sound",true)
		atmosphere_volume = clampf(float(cfg.get_value("weather","atmosphere_volume",0.24)),0,1)
	signals.setup(game)
	rain = MultiMeshInstance3D.new();rain.name = "SignalRain"
	rain.multimesh = MultiMesh.new();rain.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var quad = QuadMesh.new();quad.size = Vector2(0.10,1.6)
	rain_material = ShaderMaterial.new();rain_material.shader = load("res://shaders/signal_rain.gdshader");quad.material = rain_material
	rain.multimesh.mesh = quad;rain.multimesh.instance_count = 96 if OS.has_feature("web") else 180
	for i in range(rain.multimesh.instance_count): drops.append({"position":Vector3.ZERO,"hit":Vector3.ZERO,"ready":false})
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child(rain)
	inscription = Label3D.new();inscription.font_size = 100;inscription.pixel_size = 0.018
	inscription.billboard = BaseMaterial3D.BILLBOARD_ENABLED;inscription.no_depth_test = false
	inscription.modulate = Color(0.35,1,0.7,0);game.add_child(inscription)
	overlay = ColorRect.new();overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.08,0.4,0.28,0);add_child(overlay)
	post = ColorRect.new();post.mouse_filter = Control.MOUSE_FILTER_IGNORE;post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var post_material = ShaderMaterial.new();post_material.shader = load("res://shaders/atmosphere_post.gdshader");post.material = post_material
	add_child(post)
	heat_mist = load("res://thermal_atmosphere.gd").new();heat_mist.setup(game,self)
	audio = AudioStreamPlayer.new()
	audio.stream = load("res://assets/audio/dark-horse.ogg") if OS.has_feature("web") else AudioStreamOggVorbis.load_from_file("res://assets/audio/dark-horse.ogg")
	if audio.stream != null: audio.stream.loop = true
	audio.volume_db = linear_to_db(maxf(0.0001,music_volume*0.5));add_child(audio)
	if sound and DisplayServer.get_name() != "headless": audio.play()
	wind_audio = AudioStreamPlayer.new();rain_audio = AudioStreamPlayer.new()
	wind_audio.stream = load("res://assets/audio/wind.wav") if OS.has_feature("web") else AudioStreamWAV.load_from_file("res://assets/audio/wind.wav")
	if wind_audio.stream != null:
		wind_audio.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wind_audio.stream.loop_end = int(wind_audio.stream.get_length()*wind_audio.stream.mix_rate)
	rain_audio.stream = load("res://assets/audio/rain.ogg") if OS.has_feature("web") else AudioStreamOggVorbis.load_from_file("res://assets/audio/rain.ogg")
	if rain_audio.stream != null: rain_audio.stream.loop = true
	add_child(wind_audio);add_child(rain_audio)
	# Accessible controls stay in the existing terminal; they never capture gameplay focus.
	var box: VBoxContainer = game.menu.find_child("LinkContent",true,false)
	var row = HFlowContainer.new();box.add_child(row)
	for entry in [["Weather", "enabled"],["Signal flashes", "flashes"],["Chiptune music", "sound"],["Atmosphere FX", "post_enabled"]]:
		var button = CheckButton.new();button.text = entry[0];button.button_pressed = get(entry[1]);row.add_child(button)
		button.toggled.connect(func(value):
			set(entry[1],value)
			if entry[1] == "sound":
				if value: audio.play()
				else: audio.stop()
			var prefs = ConfigFile.new()
			for key in ["enabled","flashes","sound","post_enabled"]: prefs.set_value("weather",key,get(key))
			prefs.set_value("weather","music_volume",music_volume)
			prefs.save(game.runtime_dir.path_join("weather.cfg"))
		)
	var music_label = Label.new();music_label.text = "Music volume";box.add_child(music_label)
	var volume = HSlider.new();volume.min_value = 0;volume.max_value = 1;volume.step = 0.01;volume.value = music_volume;box.add_child(volume)
	volume.value_changed.connect(func(value):
		music_volume = value;audio.volume_db = linear_to_db(maxf(0.0001,value*0.5))
		var prefs = ConfigFile.new();prefs.load(game.runtime_dir.path_join("weather.cfg"))
		prefs.set_value("weather","music_volume",music_volume);prefs.save(game.runtime_dir.path_join("weather.cfg"))
	)
	var ambience = CheckButton.new();ambience.text = "Wind / rain ambience (CC0)";ambience.button_pressed = atmosphere_sound;box.add_child(ambience)
	ambience.toggled.connect(func(value): atmosphere_sound = value;save_ambience())
	var ambience_volume = HSlider.new();ambience_volume.min_value = 0;ambience_volume.max_value = 1;ambience_volume.step = 0.01;ambience_volume.value = atmosphere_volume;box.add_child(ambience_volume)
	ambience_volume.value_changed.connect(func(value): atmosphere_volume = value;save_ambience())

func save_ambience():
	var prefs = ConfigFile.new();prefs.load(game.runtime_dir.path_join("weather.cfg"))
	prefs.set_value("weather","atmosphere_sound",atmosphere_sound);prefs.set_value("weather","atmosphere_volume",atmosphere_volume)
	prefs.save(game.runtime_dir.path_join("weather.cfg"))

func update_ambience():
	if DisplayServer.get_name() == "headless": return
	var gains = [clampf(wind.length()/5.0,0.08,0.65),strength*0.65 if rain_active() else 0.0]
	for i in range(2):
		var player: AudioStreamPlayer = [wind_audio,rain_audio][i]
		var gain: float = gains[i]*atmosphere_volume if atmosphere_sound and game.hatched else 0.0
		player.volume_db = linear_to_db(maxf(0.0001,gain))
		if gain > 0.001 and not player.playing: player.play()
		elif gain <= 0.001 and player.playing: player.stop()

func _process(delta):
	if game == null: return
	clock += delta
	day_time = fposmod(day_time+delta/day_seconds,1.0)
	remaining -= delta
	if remaining <= 0: choose_weather()
	strength = move_toward(strength,target_strength if enabled else 0.0,delta*0.075)
	rain_delay = maxf(0,rain_delay-delta)
	var cloud_target = [0.0,0.78,0.60,1.0,0.32][weather_kind] if enabled else 0.0
	cloud_amount = move_toward(cloud_amount,cloud_target,delta*0.035)
	wind = wind.lerp(wind_target,1-exp(-delta*0.25))
	wind_offset += Vector2(wind.x,wind.z)*delta
	wind_clock += delta
	if wind_clock >= 1.0/30.0:
		wind_clock = 0
		for dust in dust_materials: dust.gravity = Vector3(0,0.025,0)+wind*0.06
		update_ambience()
	phase_name = ["QUIET BUS","MATRIX CONDENSATION","ION DRIZZLE","PACKET STORM","STATIC MIST"][weather_kind]
	if not enabled: phase_name = "WEATHER OFF"
	daylight_timer += delta
	if daylight_timer > 0.25 or delta == 0: daylight_timer = 0;update_daylight()
	heat_mist.step(delta)
	update_rain(delta)
	signals.step(delta)
	rain.visible = rain_active();rain_material.set_shader_parameter("strength",strength)
	# One low-frequency, eased discharge every 13 seconds, never a rapid strobe.
	var pulse = pow(maxf(0,1-absf(fmod(clock,13.0)-1.0)/0.7),2)*strength if flashes and enabled else 0.0
	inscription.text = "0x714 // CRC LOST\nRECONSTRUCTING SKY" if int(clock/13)%2 == 0 else "SIGNAL SHEAR\n[ WORLD BUS RESYNC ]"
	inscription.position = game.player.position+Vector3(sin(clock*0.04)*8,13,-22)
	inscription.modulate.a = pulse*0.7
	inscription.visible = pulse > 0.01
	inscription.outline_modulate = Color(0.01,0.04,0.025,pulse*0.5)
	overlay.color.a = pulse*0.055
	game.atmosphere_material.set_shader_parameter("signal_storm",pulse)
	game.atmosphere_material.set_shader_parameter("signal_glitch",strength if flashes and fmod(clock,17.0) < 0.45 else 0.0)
	game.directional_sun.light_energy = solar_energy+pulse*0.65
	post.visible = post_enabled
	post.material.set_shader_parameter("storm",strength if enabled else 0)
	# Cloud-local glitches must not independently distort the clear sky or screen.
	post.material.set_shader_parameter("glitch",0.0)
	qa_timer += delta
	if game.web_qa and qa_timer > 0.5:
		qa_timer = 0
		JavaScriptBridge.eval("window.velumWeather="+JSON.stringify({"phase":phase_name,"strength":strength,"sound":sound,"flashes":flashes,"day":day_time,"impacts":signals.impacts,"delivered":signals.received})+";")

func choose_weather():
	var next = rng.randi_range(0,4)
	if next == weather_kind: next = (next+1)%5
	weather_kind = next;remaining = rng.randf_range(28,85);transitions += 1
	target_strength = [0.0,0.72,0.40,1.0,0.25][weather_kind]*rng.randf_range(0.75,1.0)
	rain_delay = 22.0 if weather_kind in [1,2,3] else 0.0
	var angle = rng.randf()*TAU
	wind_target = Vector3(cos(angle),0,sin(angle))*rng.randf_range(0.4,1.3+target_strength*3.5)

func rain_active() -> bool:
	return enabled and strength > 0.02 and weather_kind in [1,2,3] and rain_delay <= 0

func update_daylight():
	var angle = (day_time-0.25)*TAU
	var elevation = sin(angle)
	var sun_vector = Vector3(cos(angle)*0.75,elevation,sin(angle+0.7)*0.55).normalized()
	var daylight = smoothstep(-0.12,0.35,elevation)
	var twilight = (1-smoothstep(0.02,0.40,absf(elevation)))*smoothstep(-0.15,0.0,elevation)
	var sky_material = game.atmosphere_material
	sky_material.set_shader_parameter("cloud_origin",game.camera.global_position)
	sky_material.set_shader_parameter("cloud_altitude",cloud_altitude)
	sky_material.set_shader_parameter("cloud_clock",clock)
	sky_material.set_shader_parameter("cloud_weather",strength)
	sky_material.set_shader_parameter("cloud_amount",cloud_amount)
	sky_material.set_shader_parameter("wind_offset",wind_offset)
	sky_material.set_shader_parameter("daylight",daylight)
	sky_material.set_shader_parameter("SUN_DIR",sun_vector)
	sky_material.set_shader_parameter("zenith_color",Color("050c1b").lerp(Color("2769aa"),daylight))
	sky_material.set_shader_parameter("horizon_color",Color("101929").lerp(Color("a9c6d1"),daylight).lerp(Color("dc8157"),twilight*0.7))
	game.directional_sun.rotation = Basis.looking_at(-sun_vector).get_euler()
	game.directional_sun.light_color = Color("8aabdf").lerp(Color("f3dfb3"),daylight).lerp(Color("ff9864"),twilight*0.65)
	solar_energy = (0.12+1.13*daylight)*(1-strength*0.25)
	game.directional_sun.light_energy = solar_energy
	var env: Environment = game.world_environment.environment
	env.ambient_light_energy = lerpf(0.20,0.58,daylight)
	env.fog_light_color = Color("14283a").lerp(Color("4e5140"),daylight)
	env.tonemap_exposure = lerpf(1.10,1.0,daylight)
	post.material.set_shader_parameter("twilight",twilight)
	post.material.set_shader_parameter("night",1-daylight)

func spawn_drop(drop: Dictionary):
	var center: Vector3 = game.player.position
	var start = Vector3.ZERO
	var found = false
	for attempt in range(10):
		start = Vector3(center.x+rain_rng.randf_range(-22,22),cloud_altitude,center.z+rain_rng.randf_range(-22,22))
		if cloud_coverage(start) > 0.55: found = true;break
	if not found:
		drop.ready = false;drop.position = Vector3(0,-500,0);drop["retry"] = rain_rng.randf_range(0.3,1.0);return
	var floor_y: float = game.height_at(start.x,start.z)
	var drift = wind*((cloud_altitude-floor_y)/(4+strength*6))*0.22
	var hit = Vector3(start.x+drift.x,game.height_at(start.x+drift.x,start.z+drift.z),start.z+drift.z)
	var query = PhysicsRayQueryParameters3D.create(start,hit-Vector3.UP*2)
	query.collide_with_areas = true;query.collision_mask = 7
	var collision = game.get_world_3d().direct_space_state.intersect_ray(query)
	if not collision.is_empty(): hit = collision.position
	drop.position = start;drop.hit = hit;drop.ready = true
	drop["cloud_cover"] = cloud_coverage(start)
	drop["birth"] = start

func cloud_coverage(point: Vector3) -> float:
	var q = Vector2(point.x,point.z)+wind_offset+Vector2(posmod(game.WORLD_SEED-714219,997),posmod(game.WORLD_SEED-714219,991))
	var field = 0.5+sin(q.x*0.055)*0.23+sin(q.y*0.043)*0.20+sin((q.x+q.y)*0.031)*0.10+strength*0.12
	return smoothstep(0.50,0.73,field)*maxf(cloud_amount,strength)

func update_rain(delta: float):
	impact_budget = minf(1,impact_budget+delta*5)
	var raining = rain_active()
	if not raining: return
	for i in range(drops.size()):
		var drop = drops[i]
		if drop.get("retry",0.0) > 0:
			drop.retry -= delta;continue
		if not drop.ready: spawn_drop(drop)
		if not drop.ready:
			rain.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(0,-500,0)));continue
		var fraction = clampf(delta*(4+strength*6)/maxf(0.001,drop.position.y-drop.hit.y),0,1)
		drop.position = drop.position.lerp(drop.hit,fraction)
		if drop.position.y <= drop.hit.y:
			if impact_budget >= 1:
				signals.impact(drop.hit);impact_budget -= 1
			spawn_drop(drop)
		rain.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,drop.position))

func snapshot_state() -> Dictionary:
	return {"day":day_time,"clock":clock,"remaining":remaining,"kind":weather_kind,"target":target_strength,"strength":strength,"rng":str(rng.state),"clouds":cloud_amount,"rain_delay":rain_delay,"wind":[wind.x,wind.z],"wind_target":[wind_target.x,wind_target.z],"wind_offset":[wind_offset.x,wind_offset.y]}

func restore_state(state: Dictionary):
	day_time = fposmod(float(state.get("day",day_time)),1);clock = maxf(0,float(state.get("clock",clock)))
	remaining = clampf(float(state.get("remaining",remaining)),0,120);weather_kind = clampi(int(state.get("kind",weather_kind)),0,4)
	target_strength = clampf(float(state.get("target",target_strength)),0,1);strength = clampf(float(state.get("strength",strength)),0,1)
	if state.has("rng"): rng.state = int(state.rng)
	cloud_amount = clampf(float(state.get("clouds",maxf(strength,0.18))),0,1)
	rain_delay = clampf(float(state.get("rain_delay",0)),0,22)
	for key in ["wind","wind_target","wind_offset"]:
		var value = state.get(key,[])
		if value is Array and value.size() == 2 and is_finite(float(value[0])) and is_finite(float(value[1])):
			if key == "wind_offset": wind_offset = Vector2(float(value[0]),float(value[1]))
			else: set(key,Vector3(float(value[0]),0,float(value[1])).limit_length(6))

func _exit_tree():
	if is_instance_valid(audio): audio.stop()
