extends Node3D
var frames = 0
func _ready():
	print("RTX_PROBE_READY")
	if Engine.has_singleton("Streamline"):
		var sl = Engine.get_singleton("Streamline")
		print("RTX_PROBE_DLSS ",sl.call("get_capability",0)," FG ",sl.call("get_capability",1))
	var mesh = MeshInstance3D.new();mesh.mesh = BoxMesh.new();add_child(mesh)
	var camera = Camera3D.new();add_child(camera);camera.position=Vector3(0,1,4);camera.look_at(Vector3.ZERO);camera.current=true
	var light = DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-30,0);add_child(light)
func _process(_delta):
	frames += 1
	if frames == 90:
		print("RTX_PROBE_RENDER_PASS")
		get_tree().quit(0)
