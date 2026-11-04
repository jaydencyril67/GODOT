extends SceneTree

const MainGameScript = preload("res://scripts/digitalworld_game.gd")

var game: Node


func _initialize() -> void:
	call_deferred("_run_transition_checks")


func _run_transition_checks() -> void:
	game = MainGameScript.new()
	root.add_child(game)
	await process_frame

	# Build a real Home scene and verify that Office opens over that same HQ.
	game._show_home_scene()
	if not await _wait_for_headquarters():
		_fail("Initial Home scene did not create its headquarters.")
		return
	var headquarters = game.world_root
	await headquarters.setup_completed
	game._show_office_hub()
	if game.current_screen != "headquarters" or not headquarters.visible or headquarters.home_mode:
		_fail("Office did not open the active headquarters scene.")
		return

	# Returning from Office must restore Home without destroying the HQ.
	game._return_home_from_headquarters()
	if game.current_screen != "home" or not headquarters.visible or not headquarters.home_mode:
		_fail("Returning from Office did not restore Home.")
		return

	# Create deliberately disposes of the 3D world; its return must rebuild it.
	game._show_create_scene()
	if is_instance_valid(game.world_root):
		_fail("Create did not dispose of its exclusive 3D Home world.")
		return
	game._return_to_home()
	if not await _wait_for_headquarters():
		_fail("Returning from Create did not rebuild Home.")
		return
	headquarters = game.world_root
	await headquarters.setup_completed
	game._show_office_hub()
	if game.current_screen != "headquarters" or not headquarters.visible:
		_fail("Office failed after returning from Create.")
		return

	# Research also disposes of the 3D world; its return must rebuild it too.
	game._show_research_scene()
	if is_instance_valid(game.world_root):
		_fail("Research did not dispose of its exclusive 3D Home world.")
		return
	game._return_home_from_research()
	if not await _wait_for_headquarters():
		_fail("Returning from Research did not rebuild Home.")
		return
	headquarters = game.world_root
	await headquarters.setup_completed
	game._show_office_hub()
	if game.current_screen != "headquarters" or not headquarters.visible:
		_fail("Office failed after returning from Research.")
		return

	print("HOME_OFFICE_TRANSITION_SMOKE_TEST: PASS")
	quit(0)


func _wait_for_headquarters() -> bool:
	for frame_index in range(180):
		if is_instance_valid(game.world_root):
			return true
		await process_frame
	return false


func _fail(message: String) -> void:
	push_error("HOME_OFFICE_TRANSITION_SMOKE_TEST: " + message)
	quit(1)
