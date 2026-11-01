extends SceneTree
func _initialize(): call_deferred("run")
func create_game(seed_value: int):
	ProjectSettings.set_meta("velum_seed",seed_value)
	var game = load("res://main.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	return game
func run():
	OS.set_environment("VELUM_DATA_DIR",ProjectSettings.globalize_path("res://runtime/seed-detail-qa"))
	var first = create_game(714219);var fingerprint = first.procedural_detail.fingerprint;var topology = first.labyrinth.passages.duplicate(true)
	first.queue_free();await process_frame
	var same = create_game(714219)
	if same.procedural_detail.fingerprint != fingerprint or same.labyrinth.passages != topology: push_error("Seed reproducibility failed");quit(1);return
	same.queue_free();await process_frame
	var other = create_game(123456)
	if other.WORLD_SEED != 123456 or other.procedural_detail.fingerprint == fingerprint or other.labyrinth.passages == topology: push_error("Seed diversity failed");quit(1);return
	for i in range(10): other.procedural_detail.burst(Vector3(0,1,0))
	if other.procedural_detail.debris.size() != 24: push_error("Debris budget failed");quit(1);return
	for i in range(180): await physics_frame
	for piece in other.procedural_detail.debris:
		if piece.node.position.y < -0.1: push_error("Voxel-shaped chip fell through terrain");quit(1);return
	other.procedural_detail._physics_process(7)
	if not other.procedural_detail.debris.is_empty(): push_error("Debris expiry failed");quit(1);return
	current_scene = other
	var inputs = other.menu.find_children("*","SpinBox",true,false)
	inputs[0].value = 123457
	for button in other.menu.find_children("*","Button",true,false):
		if button.text.begins_with("Generate seed"):
			button.pressed.emit();break
	for i in range(3): await process_frame
	if current_scene == other or current_scene.WORLD_SEED != 123457: push_error("Seed UI restart failed");quit(1);return
	ProjectSettings.remove_meta("velum_seed")
	print("VELUM_SEED_DETAIL_PASS same_seed_reproduces changed_seed_changes detail_clusters=24 debris_cap=24 physical_floor_collision expiry=true seed_ui_restart=true")
	quit(0)
