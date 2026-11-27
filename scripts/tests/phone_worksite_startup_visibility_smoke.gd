extends SceneTree

const PhoneWorksiteScene: PackedScene = preload("res://scenes/phone_creation_worksite.tscn")


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var worksite := PhoneWorksiteScene.instantiate() as Node3D
	if worksite == null:
		_fail("Phone Creation Worksite could not be instantiated.")
		return

	# Match production: defer the initial build while the campus loading
	# overlay is displayed, with the 3D root hidden and processing disabled.
	worksite.call("set_defer_initial_setup", true)
	worksite.process_mode = Node.PROCESS_MODE_DISABLED
	worksite.hide()
	root.add_child(worksite)

	var setup_succeeded: bool = await worksite.call("prepare_for_initial_load")
	if not setup_succeeded or not bool(worksite.get("startup_setup_complete")):
		_fail("Phone Creation Worksite did not finish its deferred startup preparation.")
		worksite.free()
		return

	var interface_layer := worksite.get_node_or_null("PhoneCreationWorksiteInterface") as CanvasLayer
	if interface_layer == null or interface_layer.visible:
		_fail("Phone Creation Worksite CanvasLayer leaked through the hidden startup scene.")
		worksite.free()
		return

	worksite.process_mode = Node.PROCESS_MODE_INHERIT
	worksite.show()
	interface_layer.show()
	await process_frame
	if not interface_layer.visible or not worksite.visible:
		_fail("Phone Creation Worksite interface did not reveal after startup preparation.")
		worksite.free()
		return

	worksite.queue_free()
	await process_frame
	print("PHONE_WORKSITE_STARTUP_VISIBILITY_SMOKE_TEST: PASS")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	print("PHONE_WORKSITE_STARTUP_VISIBILITY_SMOKE_TEST: FAIL: " + message)
	quit(1)
