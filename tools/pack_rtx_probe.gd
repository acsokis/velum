extends SceneTree
func _initialize():
	var pack = PCKPacker.new()
	assert(pack.pck_start("res://build-rtx/probe.pck") == OK)
	for entry in [["project.godot","tools/rtx_probe/project.godot"],["probe.tscn","tools/rtx_probe/probe.tscn"],["probe.gd","tools/rtx_probe/probe.gd"],[".godot/global_script_class_cache.cfg","tools/empty_script_cache.cfg"]]:
		assert(pack.add_file("res://"+entry[0],"res://"+entry[1]) == OK)
	assert(pack.flush() == OK)
	quit()
