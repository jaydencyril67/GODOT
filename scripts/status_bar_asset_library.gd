extends RefCounted

const STATUS_BAR_ATLAS_PATH := "res://assets/system-ui/godot/status-bar/status_bar_atlas.svg"
const CELL_SIZE := 32

const STYLES := [
	{"id":"pixel_compact","name":"PIXEL COMPACT","icon_size":15,"gap":3,"show_lock":false,"show_bluetooth":false,"time_size":12,"time_side":"left","order":["wifi","signal","battery"],"wifi_level":4,"signal_level":5,"battery_level":4},
	{"id":"one_ui_balanced","name":"ONE UI BALANCED","icon_size":16,"gap":4,"show_lock":false,"show_bluetooth":true,"time_size":12,"time_side":"left","order":["signal","wifi","bluetooth","battery"],"wifi_level":4,"signal_level":5,"battery_level":4},
	{"id":"aosp_classic","name":"AOSP CLASSIC","icon_size":15,"gap":3,"show_lock":true,"show_bluetooth":false,"time_size":11,"time_side":"left","order":["signal","wifi","battery"],"wifi_level":3,"signal_level":4,"battery_level":3},
	{"id":"material_compact","name":"MATERIAL COMPACT","icon_size":16,"gap":2,"show_lock":true,"show_bluetooth":false,"time_size":12,"time_side":"right","order":["wifi","signal","battery"],"wifi_level":4,"signal_level":4,"battery_level":5},
	{"id":"connectivity_focus","name":"CONNECTIVITY FOCUS","icon_size":18,"gap":4,"show_lock":false,"show_bluetooth":true,"time_size":12,"time_side":"left","order":["wifi","signal","bluetooth","battery"],"wifi_level":3,"signal_level":5,"battery_level":4},
	{"id":"battery_first","name":"BATTERY FIRST","icon_size":16,"gap":4,"show_lock":false,"show_bluetooth":false,"time_size":12,"time_side":"right","order":["battery","wifi","signal"],"wifi_level":4,"signal_level":5,"battery_level":5},
	{"id":"bluetooth_ready","name":"BLUETOOTH READY","icon_size":16,"gap":3,"show_lock":true,"show_bluetooth":true,"time_size":11,"time_side":"left","order":["bluetooth","signal","wifi","battery"],"wifi_level":4,"signal_level":3,"battery_level":3},
	{"id":"quiet_minimal","name":"QUIET MINIMAL","icon_size":14,"gap":2,"show_lock":false,"show_bluetooth":false,"time_size":11,"time_side":"right","order":["wifi","battery"],"wifi_level":4,"signal_level":5,"battery_level":4},
	{"id":"network_dense","name":"NETWORK DENSE","icon_size":17,"gap":2,"show_lock":true,"show_bluetooth":true,"time_size":12,"time_side":"left","order":["signal","wifi","battery","bluetooth"],"wifi_level":2,"signal_level":4,"battery_level":2},
	{"id":"classic_wide","name":"CLASSIC WIDE","icon_size":18,"gap":5,"show_lock":true,"show_bluetooth":false,"time_size":13,"time_side":"left","order":["signal","wifi","battery"],"wifi_level":4,"signal_level":5,"battery_level":5}
]

static func get_styles() -> Array[Dictionary]:
	return STYLES.duplicate(true)

static func has_style(style_id: String) -> bool:
	for style in STYLES:
		if str(style.get("id", "")) == style_id:
			return true
	return false

static func get_style(style_id: String) -> Dictionary:
	for style in STYLES:
		if str(style.get("id", "")) == style_id:
			return style.duplicate(true)
	return STYLES[0].duplicate(true)

static func get_icon_texture(icon_name: String) -> Texture2D:
	var region := Rect2()
	if icon_name.begins_with("battery_"):
		region = Rect2(float(int(icon_name.trim_prefix("battery_"))) * CELL_SIZE, 0, 24, 24)
	elif icon_name.begins_with("signal_"):
		region = Rect2(float(int(icon_name.trim_prefix("signal_"))) * CELL_SIZE, CELL_SIZE, 24, 24)
	elif icon_name.begins_with("wifi_"):
		region = Rect2(float(int(icon_name.trim_prefix("wifi_"))) * CELL_SIZE, CELL_SIZE * 2.0, 24, 24)
	elif icon_name == "bluetooth_connected":
		region = Rect2(CELL_SIZE * 5.0, CELL_SIZE * 2.0, 24, 24)
	elif icon_name == "roaming_indicator":
		region = Rect2(CELL_SIZE * 6.0, CELL_SIZE * 2.0, 24, 24)
	else:
		return null
	var atlas := load(STATUS_BAR_ATLAS_PATH) as Texture2D
	if atlas == null:
		return null
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = region
	return texture
