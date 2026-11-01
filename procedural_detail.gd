extends Node
## Seeded voxel-shaped accretions; bounded rigid-body chips, not a destructible voxel world.
var game
var debris: Array[Dictionary] = []
var rng = RandomNumberGenerator.new()
var detail_root: Node3D
var fingerprint = 0

func setup(owner_game):
	game = owner_game;rng.seed = game.WORLD_SEED ^ 0xC077
	detail_root = Node3D.new();detail_root.name = "ProceduralAccretions";game.add_child(detail_root)
	var material = game.mat(Color("487e59"));material.roughness = 0.92;material.metallic = 0.3
	var cube = BoxMesh.new();cube.size = Vector3.ONE
	# Clusters are independently culled. Individual flakes require no physics until harvested.
	for cluster in range(24):
		var center = Vector3(rng.randf_range(-88,88),0,rng.randf_range(-88,88))
		center.y = game.height_at(center.x,center.z)+0.04
		center = game.world_art.supported_position(center,0.7)+Vector3.UP*0.04
		var transforms: Array[Transform3D] = []
		for x in range(-3,4):
			for z in range(-3,4):
				var weight = exp(-float(x*x+z*z)/7.0)
				if rng.randf() > weight*0.8: continue
				var height = rng.randi_range(1,4)
				for y in range(height):
					var size = Vector3(rng.randf_range(0.09,0.2),0.075,rng.randf_range(0.09,0.2))
					var p = Vector3(x*0.16,y*0.075,z*0.16)
					transforms.append(Transform3D(Basis(Vector3.UP,rng.randf_range(-0.4,0.4)).scaled_local(size),p))
					fingerprint = (fingerprint*31+int((p.x+p.z+size.x)*10000)) & 0x7fffffff
		var multi = MultiMesh.new();multi.transform_format = MultiMesh.TRANSFORM_3D;multi.mesh = cube;multi.instance_count = transforms.size()
		for i in range(transforms.size()): multi.set_instance_transform(i,transforms[i])
		var mesh = MultiMeshInstance3D.new();mesh.multimesh = multi;mesh.material_override = material;mesh.position = center
		mesh.visibility_range_end = 28 if OS.has_feature("web") else 45
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;detail_root.add_child(mesh)
	add_seed_controls()

func add_seed_controls():
	var box = game.menu.find_child("LinkContent",true,false)
	var label = Label.new();label.text = "World seed: %d" % game.WORLD_SEED;box.add_child(label)
	var row = HBoxContainer.new();box.add_child(row)
	var input = SpinBox.new();input.min_value = 1;input.max_value = 2147483647;input.step = 1;input.value = game.WORLD_SEED;input.custom_minimum_size.x = 220;row.add_child(input)
	var button = Button.new();button.text = "Generate seed — resets unsaved progress";row.add_child(button)
	button.pressed.connect(func():
		var seed_value = int(input.value)
		var cfg = ConfigFile.new();cfg.set_value("world","seed",seed_value);cfg.save(game.runtime_dir.path_join("world.cfg"))
		ProjectSettings.set_meta("velum_seed",seed_value)
		game.get_tree().reload_current_scene.call_deferred()
	)

func burst(position: Vector3):
	var limit = 12 if OS.has_feature("web") else 24
	for i in range(mini(6,limit-debris.size())):
		var body = RigidBody3D.new();body.mass = 0.035;body.collision_layer = 0;body.collision_mask = 1
		body.position = position+Vector3(rng.randf_range(-0.2,0.2),0.3,rng.randf_range(-0.2,0.2))
		var size = Vector3.ONE*rng.randf_range(0.07,0.13)
		var shape = BoxShape3D.new();shape.size = size
		var collision = CollisionShape3D.new();collision.shape = shape;body.add_child(collision)
		var cube = BoxMesh.new();cube.size = size;game.mesh_at(body,cube,Vector3.ZERO,Vector3.ONE,game.mat(Color("719570")))
		game.add_child(body);body.linear_velocity = Vector3(rng.randf_range(-1.4,1.4),rng.randf_range(1,2.4),rng.randf_range(-1.4,1.4))
		body.angular_velocity = Vector3(rng.randf_range(-3,3),rng.randf_range(-3,3),0)
		debris.append({"node":body,"life":6.0})

func _physics_process(delta):
	for i in range(debris.size()-1,-1,-1):
		debris[i].life -= delta
		if debris[i].life <= 0:
			debris[i].node.queue_free();debris.remove_at(i)
