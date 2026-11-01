extends Node3D
## Diagnostic control scene only; never reported as VELUM gameplay performance.
var elapsed = 0.0
var frames = 0
var cube: MeshInstance3D
func _ready():
	var camera = Camera3D.new();camera.position = Vector3(0,1,4);camera.current = true;add_child(camera)
	cube = MeshInstance3D.new();cube.mesh = BoxMesh.new();add_child(cube)
	var material = StandardMaterial3D.new();material.albedo_color = Color("47a68b");cube.material_override = material
	var light = DirectionalLight3D.new();light.rotation_degrees = Vector3(-40,-30,0);add_child(light)
	var canvas = CanvasLayer.new();var label = Label.new();label.text = "ENGINE BASELINE / NO GAMEPLAY";label.position = Vector2(20,20);canvas.add_child(label);add_child(canvas)
	get_viewport().scaling_3d_scale = 0.4
func _process(delta):
	cube.rotation.y += delta
	elapsed += delta;frames += 1
	if elapsed >= 1:
		JavaScriptBridge.eval("window.velumBenchmark="+JSON.stringify({"kind":"engine_baseline_not_gameplay","fps":frames/elapsed,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})+";")
		elapsed = 0;frames = 0
