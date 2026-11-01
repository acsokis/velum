extends SceneTree
func _initialize():
	print("ENGINE ",Engine.get_version_info().string)
	for type in ["RenderingServer","Viewport","Environment","DirectionalLight3D"]:
		var constants = []
		for key in ClassDB.class_get_integer_constant_list(type):
			if "SCALING" in key or "DLSS" in key or "FSR" in key or "SHADOW_PARALLEL" in key:
				constants.append(str(key)+"="+str(ClassDB.class_get_integer_constant(type,key)))
		print(type," constants ",constants)
		var props = []
		for p in ClassDB.class_get_property_list(type):
			if "sdfgi" in p.name or "volumetric" in p.name or "ssao" in p.name or "ssil" in p.name or "dlss" in p.name or "scaling_3d" in p.name or "taa" in p.name:
				props.append(p.name)
		print(type," properties ",props)
	var features = []
	for m in RenderingServer.get_method_list():
		if "dlss" in m.name.to_lower() or "frame_gen" in m.name.to_lower(): features.append(m.name)
	print("DLSS_FRAMEGEN_API ",features)
	quit()
