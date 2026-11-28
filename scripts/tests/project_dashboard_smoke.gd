extends SceneTree

const ProjectDashboardScene: PackedScene = preload("res://scenes/project_dashboard.tscn")

const EXPECTED_DESIGNS := [
	"wooden",
	"concrete_block",
	"modern_steel",
	"premium_architectural"
]


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var dashboard := ProjectDashboardScene.instantiate() as Control
	if dashboard == null:
		_fail("The Project dashboard scene could not be instantiated.")
		return
	root.add_child(dashboard)
	var back_requests := [0]
	dashboard.back_requested.connect(func(): back_requests[0] += 1)
	await process_frame

	if str(dashboard.get_meta("project_dashboard_version", "")) != "stage_one_fencing_catalogue":
		_fail("The Project dashboard is missing its stage-one identity metadata.")
		return
	if str(dashboard.get_meta("active_page", "")) != "projects":
		_fail("The Project app did not open on its project category page.")
		return

	var fencing_category := dashboard.find_child("ProjectCategory_Fencing", true, false) as PanelContainer
	var fencing_preview := dashboard.find_child("FencingCategory3DPreview", true, false) as SubViewportContainer
	var open_catalogue := dashboard.find_child("OpenFencingCatalogueButton", true, false) as Button
	if fencing_category == null or fencing_preview == null or open_catalogue == null:
		_fail("Fencing must be the only available Project category and include a physical 3D preview.")
		return
	if dashboard.find_children("ProjectCategory_*", "PanelContainer", true, false).size() != 1:
		_fail("Stage one must show Fencing as the only project category.")
		return
	if not _has_valid_3d_preview(fencing_preview, "wooden"):
		_fail("The Fencing category preview is not backed by its own 3D fence model.")
		return

	open_catalogue.emit_signal("pressed")
	await process_frame
	if str(dashboard.get_meta("active_page", "")) != "fencing":
		_fail("Selecting Fencing did not open the fence design catalogue.")
		return

	var grid := dashboard.find_child("FenceCatalogueGrid", true, false) as GridContainer
	if grid == null or grid.get_child_count() != EXPECTED_DESIGNS.size():
		_fail("The fence catalogue must display exactly four fence designs.")
		return
	if int(dashboard.get_meta("fence_catalogue_count", 0)) != EXPECTED_DESIGNS.size():
		_fail("The Project dashboard does not report the approved four-design catalogue.")
		return
	if grid.columns != EXPECTED_DESIGNS.size() or not bool(grid.get_meta("single_horizontal_row", false)):
		_fail("All four fence designs must be aligned in one horizontal row.")
		return
	if dashboard.find_child("FenceCatalogueScroll", true, false) != null or dashboard.find_children("*", "ScrollContainer", true, false).size() > 0:
		_fail("The fence catalogue must fit without vertical or horizontal scrolling.")
		return
	for _layout_frame in range(3):
		await process_frame
	var grid_rect := grid.get_global_rect()
	var expected_row_y := -1.0
	for design_index in range(EXPECTED_DESIGNS.size()):
		var row_card := grid.get_child(design_index) as Control
		var row_rect := row_card.get_global_rect()
		if row_rect.size.x <= 0.0 or row_rect.size.y <= 0.0:
			_fail("Fence cards must receive a usable on-screen layout.")
			return
		if expected_row_y < 0.0:
			expected_row_y = row_rect.position.y
		elif absf(row_rect.position.y - expected_row_y) > 1.0:
			_fail("All four fence cards must share the same horizontal row.")
			return
		if row_rect.position.x < grid_rect.position.x - 1.0 or row_rect.end.x > grid_rect.end.x + 1.0:
			_fail("Fence cards must fit inside the visible catalogue width.")
			return

	for design_id in EXPECTED_DESIGNS:
		var card := dashboard.find_child("FenceCard_" + design_id, true, false) as PanelContainer
		var preview := dashboard.find_child("Fence3DPreview_" + design_id, true, false) as SubViewportContainer
		var title := dashboard.find_child("FenceTitle_" + design_id, true, false) as Label
		if card == null or preview == null or title == null:
			_fail("The fence catalogue is missing its card, title, or 3D preview for " + design_id + ".")
			return
		if str(card.get_meta("fence_design_id", "")) != design_id or not bool(card.get_meta("preview_is_3d", false)):
			_fail("The " + design_id + " fence card is not registered as a 3D design.")
			return
		if not _has_valid_3d_preview(preview, design_id):
			_fail("The " + design_id + " fence preview does not contain real 3D mesh geometry.")
			return

	if dashboard.find_children("BuildFenceButton_*", "Button", true, false).size() > 0:
		_fail("The fence upgrade selection stage must not start construction.")
		return
	var level_two_button := dashboard.find_child("SelectFenceUpgradeButton_02", true, false) as Button
	var level_three_button := dashboard.find_child("SelectFenceUpgradeButton_03", true, false) as Button
	var level_four_button := dashboard.find_child("SelectFenceUpgradeButton_04", true, false) as Button
	if level_two_button == null or level_three_button == null or level_four_button == null:
		_fail("The three upgradeable fence levels must each have a selection control.")
		return
	if level_two_button.disabled or not level_three_button.disabled or not level_four_button.disabled:
		_fail("Only the immediate next fence level should be selectable.")
		return
	if str((dashboard.find_child("FenceUpgradeCost_concrete_block", true, false) as Label).text) != "FULL UPGRADE COST  $2,000,000":
		_fail("Level 2 must display its full fixed $2,000,000 cost.")
		return
	var requested_upgrades: Array[Dictionary] = []
	dashboard.connect("fence_upgrade_requested", func(level: int, cost: int):
		requested_upgrades.append({"level": level, "cost": cost})
	)
	level_two_button.emit_signal("pressed")
	if requested_upgrades.size() != 1 or int(requested_upgrades[0].get("level", 0)) != 2 or int(requested_upgrades[0].get("cost", 0)) != 2000000:
		_fail("Selecting Level 2 did not request the correct full-cost fence upgrade.")
		return
	dashboard.call("configure_fence_upgrade_state", 1, {"level": 2, "cost": 2000000, "status": "paid_pending_construction"}, 898000000.0)
	await process_frame
	var paid_level_two_button := dashboard.find_child("SelectFenceUpgradeButton_02", true, false) as Button
	if paid_level_two_button == null or not paid_level_two_button.disabled or not paid_level_two_button.text.contains("PAID"):
		_fail("A paid fence upgrade must remain queued and must not allow a duplicate purchase.")
		return
	if int(dashboard.get_meta("current_fence_level", 0)) != 1:
		_fail("Recording an upgrade payment must not instantly change the installed fence level.")
		return

	var back_button := dashboard.find_child("ProjectBackButton", true, false) as Button
	if back_button == null:
		_fail("The Project page is missing its back control.")
		return
	back_button.emit_signal("pressed")
	await process_frame
	if str(dashboard.get_meta("active_page", "")) != "projects":
		_fail("The fence catalogue back control did not return to Project categories.")
		return
	back_button.emit_signal("pressed")
	await process_frame
	if back_requests[0] != 1:
		_fail("The Project back control did not request a return to the campus.")
		return

	print("PROJECT_DASHBOARD_SMOKE_TEST: PASS")
	dashboard.queue_free()
	await process_frame
	quit(0)


func _has_valid_3d_preview(container: SubViewportContainer, design_id: String) -> bool:
	if not bool(container.get_meta("actual_3d_preview", false)):
		return false
	if str(container.get_meta("fence_design_id", "")) != design_id:
		return false
	var viewport := container.get_child(0) as SubViewport
	if viewport == null or not viewport.own_world_3d:
		return false
	var model := viewport.find_child("FencePreviewModel_" + design_id, true, false) as Node3D
	if model == null or str(model.get_meta("fence_design_id", "")) != design_id:
		return false
	var mesh_nodes := model.find_children("*", "MeshInstance3D", true, false)
	return mesh_nodes.size() >= 8


func _fail(message: String) -> void:
	push_error(message)
	print("PROJECT_DASHBOARD_SMOKE_TEST: FAIL: " + message)
	quit(1)
