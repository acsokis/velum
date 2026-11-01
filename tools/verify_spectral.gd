extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var field = load("res://spectral_field.gd").new();field.setup(714219)
	var impulse = PackedVector2Array();impulse.resize(32);impulse[0] = Vector2(32,0)
	for value in field.inverse_fft(impulse):
		if value.distance_to(Vector2(1,0)) > 0.00001: push_error("IFFT constant response mismatch");quit(1);return
	var original = field.image.get_data();field.update(2.5)
	if original == field.image.get_data() or field.last_energy <= 0: push_error("Spectrum did not evolve");quit(1);return
	var clone = load("res://spectral_field.gd").new();clone.setup(714219);clone.update(2.5)
	if clone.image.get_data() != field.image.get_data(): push_error("Spectrum not reproducible");quit(1);return
	print("VELUM_SPECTRAL_PASS radix2_inverse_fft constant_response evolving_2d_field seeded_reproduction energy=",field.last_energy)
	quit(0)
