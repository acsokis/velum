extends SceneTree

func _initialize():
	var before = Image.load_from_file("res://runtime/sky-01-clouds.png")
	var after = Image.load_from_file("res://runtime/sky-02-motion.png")
	if before == null or after == null:
		push_error("Missing DX12 sky captures"); quit(1); return
	var changed = 0
	var sampled = 0
	# Fixed camera; sample the sky above foreground geometry and below the HUD.
	for y in range(180,320,3):
		for x in range(0,1280,3):
			var a = before.get_pixel(x,y)
			var b = after.get_pixel(x,y)
			var difference = absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
			if difference > 0.012: changed += 1
			sampled += 1
	var ratio = float(changed)/sampled
	print("SKY_MOTION_AUDIT changed=%d sampled=%d ratio=%.3f" % [changed,sampled,ratio])
	quit(0 if ratio > 0.02 else 1)
