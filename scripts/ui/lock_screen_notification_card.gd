extends Control

const WidgetAssetLibrary = preload("res://scripts/ui/xmorph_widget_asset_library.gd")
const LockScreenAssetLibrary = preload("res://scripts/lock_screen_asset_library.gd")

var _widgets := WidgetAssetLibrary.new()


func configure(notification: Dictionary, palette: Dictionary = {}) -> void:
	_clear_children()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var widget := _widgets.get_widget("40_notifications")
	if widget.is_empty():
		return
	var bg_layer := _widgets.get_layer(widget, "bg")
	var count_layer := _widgets.get_layer(widget, "count")
	var screen_size := get_viewport_rect().size
	var text_color: Color = palette.get("text", Color.WHITE)
	var muted_color: Color = palette.get("muted", Color("#C3CFE3"))
	var accent: Color = palette.get("accent", Color("#A9C9FF"))

	var surface := TextureRect.new()
	surface.name = "GeneratedNotificationSurface"
	surface.texture = LockScreenAssetLibrary.get_surface_texture("notification")
	surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	surface.stretch_mode = TextureRect.STRETCH_SCALE
	surface.modulate = Color(1.0, 1.0, 1.0, 0.65)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(surface)

	var panel := Panel.new()
	panel.name = "XMorphNotificationCard"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = _widgets.get_asset_color(str(bg_layer.get("color", "#E61C1C1E")), Color(0.11, 0.11, 0.12, 0.90))
	panel_style.set_corner_radius_all(clampi(roundi(minf(size.y, 52.0) * float(bg_layer.get("radius", 0.5))), 14, 22))
	panel_style.border_color = Color(1.0, 1.0, 1.0, 0.10)
	panel_style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "NotificationContent"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var app_icon := TextureRect.new()
	app_icon.name = "NotificationAppIcon"
	var app_icon_path := str(notification.get("icon", ""))
	app_icon.texture = load(app_icon_path) as Texture2D if not app_icon_path.is_empty() else null
	app_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	app_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	app_icon.custom_minimum_size = Vector2(34, 34)
	app_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(app_icon)

	var text_column := VBoxContainer.new()
	text_column.name = "NotificationText"
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.alignment = BoxContainer.ALIGNMENT_CENTER
	text_column.add_theme_constant_override("separation", 2)
	text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 5)
	header.alignment = BoxContainer.ALIGNMENT_BEGIN
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.add_child(header)

	var app_label := Label.new()
	app_label.name = "NotificationApp"
	app_label.text = str(notification.get("app", "APP"))
	app_label.add_theme_font_size_override("font_size", 10)
	app_label.add_theme_color_override("font_color", accent)
	app_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var notification_font := _widgets.get_font(str(count_layer.get("font", "")))
	if notification_font != null:
		app_label.add_theme_font_override("font", notification_font)
	header.add_child(app_label)

	var category_icon := TextureRect.new()
	category_icon.name = "NotificationCategoryIcon"
	var category := LockScreenAssetLibrary.get_notification_category(str(notification.get("app", "")))
	category_icon.texture = LockScreenAssetLibrary.get_icon_texture("category_" + category)
	category_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	category_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	category_icon.custom_minimum_size = Vector2(15, 15)
	category_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(category_icon)

	var timestamp := Label.new()
	timestamp.name = "NotificationTimestamp"
	timestamp.text = str(notification.get("timestamp", "NOW"))
	timestamp.add_theme_font_size_override("font_size", 9)
	timestamp.add_theme_color_override("font_color", muted_color)
	timestamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(timestamp)

	var badge := Panel.new()
	badge.name = "NotificationCountBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = _widgets.get_asset_color(str(bg_layer.get("color", "#E61C1C1E")), Color(0.11, 0.11, 0.12, 0.90))
	badge_style.border_color = Color(accent.r, accent.g, accent.b, 0.45)
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(clampi(roundi(screen_size.x * 0.018), 7, 12))
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.custom_minimum_size = Vector2(25, 22)
	row.add_child(badge)

	var count := Label.new()
	count.name = "NotificationCount"
	count.text = str(notification.get("notification_count", 1))
	count.add_theme_font_size_override("font_size", clampi(roundi(screen_size.x * float(count_layer.get("weight", 600)) / 30000.0), 10, 14))
	count.add_theme_color_override("font_color", text_color)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var count_font := _widgets.get_font(str(count_layer.get("font", "")))
	if count_font != null:
		count.add_theme_font_override("font", count_font)
	badge.add_child(count)

	var title := Label.new()
	title.name = "NotificationTitle"
	title.text = str(notification.get("title", "New notification"))
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", text_color)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if notification_font != null:
		title.add_theme_font_override("font", notification_font)
	text_column.add_child(title)

	var body := Label.new()
	body.name = "NotificationBody"
	body.text = str(notification.get("body", ""))
	body.add_theme_font_size_override("font_size", 11)
	body.add_theme_color_override("font_color", muted_color)
	body.clip_text = true
	body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if notification_font != null:
		body.add_theme_font_override("font", notification_font)
	text_column.add_child(body)


func _clear_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
