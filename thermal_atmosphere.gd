extends RefCounted
## Warm working-fluid vapor condenses as it mixes with cooler, humid ambient air.
var game
var weather
var sources: Array[Dictionary] = []
var fog: Array[FogVolume] = []
var mist: MultiMeshInstance3D
var material: ShaderMaterial
var timer = 1.0
var vapor_strength = 0.0
var wakes: Array[Dictionary] = []
var wake_clock = 0.0
var wake_injections = 0
var render_clock = 0.0
var render_delta = 0.0
var wake_positions = PackedVector4Array()
var wake_flows = PackedVector4Array()

func emit_wake(position: Vector3, velocity: Vector3):
	if velocity.length() < 0.35: return
	wakes.push_front({"position":position,"velocity":velocity.limit_length(8),"age":0.0})
	if wakes.size() > 12: wakes.resize(12)
	wake_injections += 1

func airflow_at(point: Vector3) -> Vector3:
	var result: Vector3 = weather.wind*0.35
	for wake in wakes:
		var offset: Vector3 = point-wake.position
		var influence = exp(-offset.length_squared()*0.25)*exp(-wake.age*0.9)
		result += (wake.velocity*0.3+Vector3.UP.cross(offset)*0.55)*influence
	return result.limit_length(3)

func setup(owner_game, owner_weather):
	game = owner_game;weather = owner_weather
	mist = MultiMeshInstance3D.new();mist.name = "ThermalCondensation"
	mist.multimesh = MultiMesh.new();mist.multimesh.transform_format = MultiMesh.TRANSFORM_3D;mist.multimesh.instance_count = 24
	var quad = QuadMesh.new();quad.size = Vector2(3.5,2.7)
	material = ShaderMaterial.new();material.shader = load("res://shaders/heat_mist.gdshader");quad.material = material
	mist.multimesh.mesh = quad;mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;game.add_child(mist)
	if not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		for i in range(6):
			var volume = FogVolume.new();volume.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
			volume.size = Vector3(5,3.5,5)
			var volume_material = ShaderMaterial.new();volume_material.shader = load("res://shaders/thermal_volume.gdshader")
			volume.material = volume_material;game.add_child(volume);fog.append(volume)

func temperature_at(point: Vector3) -> float:
	var ambient = 14.0 if point.x < 0 else 46.0
	var result = ambient
	for source in sources:
		var p: Vector3 = source.node.position
		result += (12.0+source.energy*16)*exp(-Vector2(point.x-p.x,point.z-p.z).length_squared()/14.0)
	return result

func step(delta: float):
	# Atmosphere is interpolated visually by shader TIME; it does not need 144 CPU uploads/s.
	render_clock += delta
	render_delta += delta
	if render_clock < (1.0/20.0 if OS.has_feature("web") else 1.0/30.0): return
	render_clock = fmod(render_clock,1.0/20.0 if OS.has_feature("web") else 1.0/30.0)
	delta = render_delta;render_delta = 0.0
	for wake in wakes:
		wake.age += delta
		wake.position += (wake.velocity*0.12+Vector3.UP*0.4)*delta
	wake_clock += delta
	if wake_clock > 0.15:
		wake_clock = 0
		emit_wake(game.player.position+Vector3.UP*0.6,game.player.velocity)
		# Bounded nearest actors preserve browser and froxel costs.
		var count = 0
		for c in game.creatures:
			if c.node.position.distance_squared_to(game.player.position) < 225:
				emit_wake(c.node.position,c.node.velocity);count += 1
				if count >= 2: break
	wake_positions.clear();wake_flows.clear()
	for wake in wakes:
		wake_positions.append(Vector4(wake.position.x,wake.position.y,wake.position.z,exp(-wake.age*0.9)))
		wake_flows.append(Vector4(wake.velocity.x,wake.velocity.y,wake.velocity.z,0))
	while wake_positions.size() < 12:
		wake_positions.append(Vector4.ZERO);wake_flows.append(Vector4.ZERO)
	timer += delta
	if timer > 0.5:
		timer = 0
		var sorted = game.world_art.plants.duplicate()
		sorted.sort_custom(func(a,b): return a.node.position.distance_squared_to(game.player.position) < b.node.position.distance_squared_to(game.player.position))
		sources.clear()
		for i in range(mini(6,sorted.size())): sources.append(sorted[i])
	var humidity = 0.12+weather.strength*0.65 if weather.enabled else 0.08
	vapor_strength = 0
	var heat_spots = PackedVector4Array()
	for i in range(sources.size()):
		var source = sources[i];var p: Vector3 = source.node.position
		var ambient = 14.0 if p.x < 0 else 46.0
		var hot = 55.0+source.energy*24
		var condensation = clampf((hot-ambient)/55,0,1)*humidity
		vapor_strength = maxf(vapor_strength,condensation)
		for j in range(4):
			var phase = fposmod(weather.clock*0.17+j*0.25+i*0.137,1)
			var pos = p+Vector3(sin(phase*5+i)*0.6+phase*1.3,0.5+phase*4,cos(phase*4+i)*0.5)
			pos += airflow_at(pos)*0.7
			mist.multimesh.set_instance_transform(i*4+j,Transform3D(Basis.IDENTITY,pos))
		if i < fog.size():
			fog[i].position = p+Vector3(0,1.5,0)
			fog[i].material.set_shader_parameter("condensation",condensation*0.045)
			fog[i].material.set_shader_parameter("wakes",wake_positions);fog[i].material.set_shader_parameter("flows",wake_flows)
			fog[i].material.set_shader_parameter("wind",weather.wind)
			fog[i].visible = game.world_environment.environment.volumetric_fog_enabled
		var screen = game.camera.unproject_position(p+Vector3(0,1.8,0))/game.get_viewport().get_visible_rect().size
		var visible = not game.camera.is_position_behind(p)
		heat_spots.append(Vector4(screen.x,screen.y,0.10,condensation if visible else 0))
	mist.visible = vapor_strength > 0.015;material.set_shader_parameter("humidity",vapor_strength)
	while heat_spots.size() < 6: heat_spots.append(Vector4.ZERO)
	weather.post.material.set_shader_parameter("heat_spots",heat_spots)
	for c in game.creatures: c.skin.set_shader_parameter("wetness",weather.strength*weather.cloud_coverage(c.node.position) if weather.enabled else 0.0)
