extends RefCounted
class_name DigitalWorldResearchManager

const ScreenTechnologySystem = preload("res://scripts/screen_technology_system.gd")

# Research duration is fixed by component. Staff efficiency affects success chance, never duration.
const BASE_RESEARCH_DURATION_DAYS := 30.0
const RESEARCH_DURATION_FORMULA_VERSION := 4
const COMPONENT_RESEARCH_DURATION_DAYS := {
	"Screen Technology": 45.0,
	"Screen Width": 60.0,
	"Screen Height": 60.0,
	"Refresh Rate": 30.0,
	"Phone Thickness": 60.0,
	"Border Radius": 60.0,
	"Speakers": 25.0,
	"Charge Port": 90.0,
	"Home Button": 120.0,
	"Front Camera": 500.0,
	"Front Camera MP": 45.0,
	"RAM": 120.0,
	"Internal Storage": 160.0,
	"RAM Technology": 650.0,
	"Mobile Network": 365.0,
	"Wi-Fi": 320.0,
	"Bluetooth": 240.0,
	"Cooling System Design": 425.0,
	"Phone Type": 1460.0,
	"Memory Clock": 30.0,
	"Curved Screen Horizontal": 500.0,
	"Curved Screen Vertical": 510.0,
	"Curved Screen Both": 600.0,
	"Battery Capacity": 40.0,
	"Power Bank": 150.0,
	"Charging Speed": 65.0,
	"Wireless Charging": 370.0,
	"Fingerprint Sensor": 365.0,
	"Face Recognition / Face ID": 365.0,
	"NFC Controller": 365.0,
	"Accelerometer": 365.0,
	"Gyroscope": 365.0,
	"Proximity Sensor": 365.0,
	"Ambient Light Sensor": 365.0,
	"Magnetometer / Compass": 365.0,
	"Barometer": 365.0,
	"GNSS / GPS Receiver": 365.0,
	"Rear Camera MP": 60.0,
	"Rear Camera Count": 360.0,
	"Rear Flash Count": 200.0,
	"Back Raised Design": 370.0,
	"Device Color": 35.0,
	"Phone Case": 250.0,
	"Protection Glass": 120.0,
	"Box Package": 90.0,
	"Wireless Earbuds": 230.0
}
const MIN_RESEARCH_DURATION_DAYS := 1.0
const STATUS_ACTIVE := "active"
const STATUS_AWAITING_VALIDATION := "awaiting_validation"
const STATUS_APPROVED := "approved"
const STATUS_REJECTED := "rejected"
const STATUS_SUCCESSFUL := "successful"
const STATUS_UNSUCCESSFUL := "unsuccessful"
const RESEARCH_BASE_SUCCESS_CHANCE := 50.0
const RESEARCH_MAX_SUCCESS_CHANCE := 90.0
const RESEARCH_SUCCESS_POINTS_PER_100_EFFICIENCY := 1.0
const RESEARCH_SUCCESS_FORMULA_VERSION := 1
const STATUS_CANCELLED := "cancelled"
const FRONT_CAMERA_MODEL_COUNT := 8
const FRONT_CAMERA_MP_BASE := 1
const FRONT_CAMERA_MP_STEP := 5
const FRONT_CAMERA_MP_RESEARCH_UPGRADES := 60
const FRONT_CAMERA_MP_MAX := 300
const REAR_CAMERA_MP_BASE := 1
const REAR_CAMERA_MP_STEP := 5
const REAR_CAMERA_MP_RESEARCH_UPGRADES := 80
const REAR_CAMERA_MP_MAX := 400
const REAR_HARDWARE_BASE_COUNT := 1
const REAR_HARDWARE_MAX_COUNT := 5
const REAR_HARDWARE_COUNT_RESEARCH_UPGRADES := REAR_HARDWARE_MAX_COUNT - REAR_HARDWARE_BASE_COUNT
const BACK_RAISED_DESIGN_MAX_BOXES := 20
const BATTERY_CAPACITY_BASE_MAH := 1000
const BATTERY_CAPACITY_STEP_MAH := 350
const BATTERY_CAPACITY_RESEARCH_UPGRADES := 20
const CHARGER_BASE_W := 2
const CHARGER_STEP_W := 3
const CHARGER_MAX_W := 200
const CHARGER_WATTAGE_RESEARCH_UPGRADES := 66
const CHARGER_MAX_RESEARCH_LEVEL := 2 + CHARGER_WATTAGE_RESEARCH_UPGRADES
const POWER_BANK_BASE_MAH := 5000
const POWER_BANK_STEP_MAH := 100
const POWER_BANK_MAX_MAH := 25000
const POWER_BANK_MAX_RESEARCH_LEVEL := 201
const CHARGING_SPEED_BASE_W := 1
const CHARGING_SPEED_STEP_W := 3
const CHARGING_SPEED_RESEARCH_UPGRADES := 66
const CHARGING_SPEED_MAX_W := 200
const WIRELESS_CHARGING_MAX_LEVEL := CHARGING_SPEED_RESEARCH_UPGRADES + 1
const WIRELESS_CHARGING_SPEED_UPGRADE_DURATION_DAYS := 45.0
const PHONE_CASE_DESIGN_DURATION_DAYS := 50.0
const SCREEN_WIDTH_RESEARCH_LEVELS := 12
const SCREEN_HEIGHT_RESEARCH_LEVELS := 12
const REFRESH_RATE_RESEARCH_LEVELS := 30
const MEMORY_CLOCK_MIN_SPEED := 200
const MEMORY_CLOCK_RESEARCH_LEVELS_PER_RANGE := 20
const MEMORY_CLOCK_MAX_RESEARCH_LEVEL := 120
const MEMORY_CLOCK_SPEED_TARGETS := [1066, 2133, 4266, 6400, 10700, 14400]
const MEMORY_CLOCK_RAM_TECHNOLOGY_LEVEL_CAPS := [20, 40, 60, 60, 80, 100, 120]
const PHONE_TYPE_SEQUENCE := ["Standard", "Flip", "Fold"]
const PHONE_CASE_RESEARCH_SEQUENCE := ["Custom Case Enablement (Smooth)", "Carbon Weave", "Hex Pattern", "Racing Stripes", "Grip Ridges", "Gradient Finish"]
const PROTECTION_GLASS_RESEARCH_SEQUENCE := ["Normal Glass", "Privacy Glass"]


static func get_component_research_duration_days(component_value: String, research_target_index: int = -1) -> float:
	var component := normalize_component(component_value)
	if component == "Wireless Charging" and research_target_index > 1:
		return WIRELESS_CHARGING_SPEED_UPGRADE_DURATION_DAYS
	if component == "Phone Case" and research_target_index > 1:
		return PHONE_CASE_DESIGN_DURATION_DAYS
	return maxf(
		MIN_RESEARCH_DURATION_DAYS,
		float(COMPONENT_RESEARCH_DURATION_DAYS.get(component, BASE_RESEARCH_DURATION_DAYS))
	)

const PHONE_SENSOR_COMPONENTS := [
	"Fingerprint Sensor",
	"Face Recognition / Face ID",
	"NFC Controller",
	"Accelerometer",
	"Gyroscope",
	"Proximity Sensor",
	"Ambient Light Sensor",
	"Magnetometer / Compass",
	"Barometer",
	"GNSS / GPS Receiver"
]

const SIDE_BUTTON_COMPONENTS := [
	"Side Button",
	"Sound Button",
	"Style Pen (S Pen)"
]

const POWER_VOLUME_BUTTON_LENGTH_COMPONENT := "Power/Volume Button Length"
const POWER_VOLUME_BUTTON_LENGTH_MAX_LEVEL := 3
const POWER_VOLUME_BUTTON_LENGTH_MIN_SCALES := [1.35, 1.10, 0.85, 0.55]
const POWER_VOLUME_BUTTON_POSITION_COMPONENTS := [
	"Power Button Position",
	"Volume Button Position",
	"Smartwatch"
]
const CURVED_SCREEN_RESEARCH_COMPONENTS := [
	"Curved Screen Horizontal",
	"Curved Screen Vertical",
	"Curved Screen Both"
]

const COOLING_SYSTEM_SEQUENCE := [
	"No Dedicated Cooling",
	"Graphite Sheet",
	"Graphite + Copper Foil",
	"Graphene Composite",
	"Heat Pipe",
	"Vapor Chamber",
	"Dual Vapor Chamber",
	"Vapor Chamber + Graphite Stack",
	"Internal Cooling Fan",
	"Advanced Cooling Fan",
	"Liquid Cooling",
	"Advanced Liquid Cooling"
]
const COMPONENT_CATALOGUE := [
	"Screen Technology",
	"Screen Width",
	"Screen Height",
	"Refresh Rate",
	"Phone Thickness",
	"Border Radius",
	"Speakers",
	"Charge Port",
	"Home Button",
	"Front Camera",
	"Front Camera MP",
	"RAM",
	"Internal Storage",
	"RAM Technology",
	"Mobile Network",
	"Wi-Fi",
	"Bluetooth",
	"Cooling System Design",
	"Phone Type",
	"Memory Clock",
	"Curved Screen Horizontal",
	"Curved Screen Vertical",
	"Curved Screen Both",
	"Battery Capacity",
	"Power Bank",
	"Charging Speed",
	"Wireless Charging",
	"Fingerprint Sensor",
	"Face Recognition / Face ID",
	"NFC Controller",
	"Accelerometer",
	"Gyroscope",
	"Proximity Sensor",
	"Ambient Light Sensor",
	"Magnetometer / Compass",
	"Barometer",
	"GNSS / GPS Receiver",
	"Rear Camera MP",
	"Rear Camera Count",
	"Rear Flash Count",
	"Back Raised Design",
	"Device Color",
	"Phone Case",
	"Protection Glass",
	"Box Package",
	"Wireless Earbuds",
	"Charger",
	"Side Button",
	"Sound Button",
	"Style Pen (S Pen)",
	"Power/Volume Button Length",
	"Power Button Position",
	"Volume Button Position"
]

const MOBILE_NETWORK_SEQUENCE := [
	{"generation": "1G", "generation_name": "Analog Cellular", "technology": "AMPS"},
	{"generation": "1G", "generation_name": "Analog Cellular", "technology": "NMT"},
	{"generation": "1G", "generation_name": "Analog Cellular", "technology": "TACS"},
	{"generation": "2G", "generation_name": "Digital Cellular", "technology": "GSM"},
	{"generation": "2G", "generation_name": "Digital Cellular", "technology": "IS-95 (cdmaOne)"},
	{"generation": "2G", "generation_name": "Digital Cellular", "technology": "D-AMPS (IS-136)"},
	{"generation": "2G", "generation_name": "Digital Cellular", "technology": "GPRS"},
	{"generation": "2G", "generation_name": "Digital Cellular", "technology": "EDGE"},
	{"generation": "3G", "generation_name": "Mobile Broadband", "technology": "UMTS / WCDMA"},
	{"generation": "3G", "generation_name": "Mobile Broadband", "technology": "CDMA2000"},
	{"generation": "3G", "generation_name": "Mobile Broadband", "technology": "TD-SCDMA"},
	{"generation": "3G", "generation_name": "Mobile Broadband", "technology": "HSPA"},
	{"generation": "3G", "generation_name": "Mobile Broadband", "technology": "HSPA+"},
	{"generation": "4G", "generation_name": "High-Speed Mobile Broadband", "technology": "LTE"},
	{"generation": "4G", "generation_name": "High-Speed Mobile Broadband", "technology": "LTE-Advanced"},
	{"generation": "4G", "generation_name": "High-Speed Mobile Broadband", "technology": "LTE-Advanced Pro"},
	{"generation": "5G", "generation_name": "New Radio", "technology": "5G NSA"},
	{"generation": "5G", "generation_name": "New Radio", "technology": "5G SA"},
	{"generation": "5G", "generation_name": "New Radio", "technology": "5G-Advanced"},
	{"generation": "6G", "generation_name": "Next-Generation Wireless", "technology": "6G (IMT-2030)"},
	{"generation": "6G", "generation_name": "Next-Generation Wireless", "technology": "Terahertz Communications"},
	{"generation": "6G", "generation_name": "Next-Generation Wireless", "technology": "AI-Native Networking"},
	{"generation": "6G", "generation_name": "Next-Generation Wireless", "technology": "Integrated Sensing and Communication"}
]


static func get_phone_case_research_target(component_levels: Dictionary) -> Dictionary:
	var next_index := int(component_levels.get("Phone Case", 0)) + 1
	if next_index < 1 or next_index > PHONE_CASE_RESEARCH_SEQUENCE.size():
		return {}
	return {"index": next_index, "technology": PHONE_CASE_RESEARCH_SEQUENCE[next_index - 1]}


static func get_protection_glass_research_target(component_levels: Dictionary) -> Dictionary:
	var next_index := clampi(int(component_levels.get("Protection Glass", 0)), 0, PROTECTION_GLASS_RESEARCH_SEQUENCE.size()) + 1
	if next_index > PROTECTION_GLASS_RESEARCH_SEQUENCE.size():
		return {}
	return {"index": next_index, "technology": PROTECTION_GLASS_RESEARCH_SEQUENCE[next_index - 1]}


static func get_mobile_network_step_count() -> int:
	return MOBILE_NETWORK_SEQUENCE.size()


static func get_mobile_network_entry(index: int) -> Dictionary:
	if index < 0 or index >= MOBILE_NETWORK_SEQUENCE.size():
		return {}
	var entry: Dictionary = MOBILE_NETWORK_SEQUENCE[index].duplicate(true)
	entry["index"] = index
	return entry


static func get_mobile_network_research_target(component_levels: Dictionary) -> Dictionary:
	var current_level := clampi(
		int(component_levels.get("Mobile Network", 0)),
		0,
		MOBILE_NETWORK_SEQUENCE.size() - 1
	)
	var target_index := current_level + 1
	if target_index >= MOBILE_NETWORK_SEQUENCE.size():
		return {}
	return get_mobile_network_entry(target_index)


const WIFI_SEQUENCE := [
	{"generation": "Wi-Fi 1", "generation_name": "Wireless LAN", "technology": "802.11b"},
	{"generation": "Wi-Fi 2", "generation_name": "Wireless LAN", "technology": "802.11a"},
	{"generation": "Wi-Fi 3", "generation_name": "Wireless LAN", "technology": "802.11g"},
	{"generation": "Wi-Fi 4", "generation_name": "Wireless LAN", "technology": "802.11n"},
	{"generation": "Wi-Fi 5", "generation_name": "Wireless LAN", "technology": "802.11ac"},
	{"generation": "Wi-Fi 6", "generation_name": "High-Efficiency WLAN", "technology": "802.11ax"},
	{"generation": "Wi-Fi 6E", "generation_name": "6 GHz Extension", "technology": "802.11ax (6 GHz)"},
	{"generation": "Wi-Fi 7", "generation_name": "Extremely High Throughput", "technology": "802.11be"},
	{"generation": "Wi-Fi 8", "generation_name": "Ultra High Reliability · Under Development", "technology": "802.11bn"}
]


static func get_wifi_step_count() -> int:
	return WIFI_SEQUENCE.size()


static func get_wifi_entry(index: int) -> Dictionary:
	if index < 0 or index >= WIFI_SEQUENCE.size():
		return {}
	var entry: Dictionary = WIFI_SEQUENCE[index].duplicate(true)
	entry["index"] = index
	return entry


static func get_wifi_research_target(component_levels: Dictionary) -> Dictionary:
	var current_level := clampi(
		int(component_levels.get("Wi-Fi", 0)),
		0,
		WIFI_SEQUENCE.size() - 1
	)
	var target_index := current_level + 1
	if target_index >= WIFI_SEQUENCE.size():
		return {}
	return get_wifi_entry(target_index)


static func get_bluetooth_research_target(component_levels: Dictionary) -> Dictionary:
	var current_level := clampi(
		int(component_levels.get("Bluetooth", 0)),
		0,
		BLUETOOTH_SEQUENCE.size() - 1
	)
	var target_index := current_level + 1
	if target_index >= BLUETOOTH_SEQUENCE.size():
		return {}
	return get_bluetooth_entry(target_index)


static func get_battery_capacity_max_for_level(level: int) -> int:
	# Level 1 starts at 1,000 mAh; each of the next 20 approved projects adds 350 mAh.
	var completed_upgrades := clampi(level, 0, BATTERY_CAPACITY_RESEARCH_UPGRADES)
	return BATTERY_CAPACITY_BASE_MAH + completed_upgrades * BATTERY_CAPACITY_STEP_MAH


static func get_battery_capacity_research_target(component_levels: Dictionary) -> Dictionary:
	var completed_upgrades := clampi(int(component_levels.get("Battery Capacity", 0)), 0, BATTERY_CAPACITY_RESEARCH_UPGRADES)
	if completed_upgrades >= BATTERY_CAPACITY_RESEARCH_UPGRADES:
		return {}
	var target_level := completed_upgrades + 2
	var target_capacity := get_battery_capacity_max_for_level(target_level - 1)
	return {
		"index": target_level,
		"technology": "%s mAh" % _format_research_integer(target_capacity),
		"max_capacity_mah": target_capacity
	}


static func get_charger_wattage_max_for_level(level: int) -> int:
	# Level 0 is locked; Level 1 unlocks the adapter; Level 2 unlocks the cable.
	# The next 66 approvals raise the selectable output ceiling from 2W to 200W.
	var safe_level := clampi(level, 0, CHARGER_MAX_RESEARCH_LEVEL)
	if safe_level <= 0:
		return 0
	var wattage_upgrades := clampi(safe_level - 2, 0, CHARGER_WATTAGE_RESEARCH_UPGRADES)
	return mini(CHARGER_MAX_W, CHARGER_BASE_W + wattage_upgrades * CHARGER_STEP_W)


static func get_charger_research_target(component_levels: Dictionary) -> Dictionary:
	var completed_level := clampi(int(component_levels.get("Charger", 0)), 0, CHARGER_MAX_RESEARCH_LEVEL)
	if completed_level >= CHARGER_MAX_RESEARCH_LEVEL:
		return {}
	var target_level := completed_level + 1
	if completed_level == 0:
		return {
			"index": target_level,
			"technology": "Charger Adapter Unlock",
			"stage": "adapter"
		}
	if completed_level == 1:
		return {
			"index": target_level,
			"technology": "Physical Charging Cable",
			"stage": "cable"
		}
	var next_wattage := get_charger_wattage_max_for_level(target_level)
	return {
		"index": target_level,
		"technology": "%dW" % next_wattage,
		"max_wattage": next_wattage,
		"stage": "wattage"
	}


static func get_power_bank_max_for_level(level: int) -> int:
	# Level 0 is locked. Level 1 unlocks 5,000 mAh; 200 further approvals add 100 mAh each.
	var safe_level := clampi(level, 0, POWER_BANK_MAX_RESEARCH_LEVEL)
	if safe_level <= 0:
		return 0
	return mini(POWER_BANK_MAX_MAH, POWER_BANK_BASE_MAH + (safe_level - 1) * POWER_BANK_STEP_MAH)


static func get_power_bank_research_target(component_levels: Dictionary) -> Dictionary:
	var completed_level := clampi(int(component_levels.get("Power Bank", 0)), 0, POWER_BANK_MAX_RESEARCH_LEVEL)
	if completed_level >= POWER_BANK_MAX_RESEARCH_LEVEL:
		return {}
	var target_level := completed_level + 1
	var target_capacity := get_power_bank_max_for_level(target_level)
	return {
		"index": target_level,
		"technology": "%s mAh" % _format_research_integer(target_capacity),
		"max_capacity_mah": target_capacity
	}


static func get_charging_speed_max_for_level(level: int) -> int:
	# Level 1 starts at 1W. The first 65 upgrades add 3W each;
	# the 66th upgrade adds 4W to reach the exact 200W ceiling.
	var completed_upgrades := clampi(level, 0, CHARGING_SPEED_RESEARCH_UPGRADES)
	if completed_upgrades >= CHARGING_SPEED_RESEARCH_UPGRADES:
		return CHARGING_SPEED_MAX_W
	return CHARGING_SPEED_BASE_W + completed_upgrades * CHARGING_SPEED_STEP_W


static func get_charging_speed_research_target(component_levels: Dictionary) -> Dictionary:
	var completed_upgrades := clampi(
		int(component_levels.get("Charging Speed", 0)),
		0,
		CHARGING_SPEED_RESEARCH_UPGRADES
	)
	if completed_upgrades >= CHARGING_SPEED_RESEARCH_UPGRADES:
		return {}
	var target_level := completed_upgrades + 2
	var target_maximum := get_charging_speed_max_for_level(completed_upgrades + 1)
	return {
		"index": target_level,
		"technology": "%dW" % target_maximum,
		"max_charging_speed_w": target_maximum
	}


static func get_front_camera_mp_max_for_level(completed_upgrades: int) -> int:
	# The 1MP baseline is available by default. The first 59 upgrades add 5MP;
	# the final upgrade adds 4MP to reach exactly 300MP.
	var upgrades := clampi(completed_upgrades, 0, FRONT_CAMERA_MP_RESEARCH_UPGRADES)
	if upgrades >= FRONT_CAMERA_MP_RESEARCH_UPGRADES:
		return FRONT_CAMERA_MP_MAX
	return mini(FRONT_CAMERA_MP_MAX, FRONT_CAMERA_MP_BASE + upgrades * FRONT_CAMERA_MP_STEP)


static func get_front_camera_mp_research_target(component_levels: Dictionary) -> Dictionary:
	var completed_upgrades := clampi(
		int(component_levels.get("Front Camera MP", 0)),
		0,
		FRONT_CAMERA_MP_RESEARCH_UPGRADES
	)
	if completed_upgrades >= FRONT_CAMERA_MP_RESEARCH_UPGRADES:
		return {}
	var target_level := completed_upgrades + 2
	var target_maximum := get_front_camera_mp_max_for_level(completed_upgrades + 1)
	return {
		"index": target_level,
		"technology": "%dMP" % target_maximum,
		"max_front_camera_mp": target_maximum
	}


static func get_rear_camera_mp_max_for_level(completed_upgrades: int) -> int:
	# The 1MP baseline is available by default. The first 79 approvals add 5MP;
	# the final approval adds 4MP to reach exactly 400MP.
	var upgrades := clampi(completed_upgrades, 0, REAR_CAMERA_MP_RESEARCH_UPGRADES)
	if upgrades >= REAR_CAMERA_MP_RESEARCH_UPGRADES:
		return REAR_CAMERA_MP_MAX
	return mini(REAR_CAMERA_MP_MAX, REAR_CAMERA_MP_BASE + upgrades * REAR_CAMERA_MP_STEP)


static func get_rear_camera_mp_research_target(component_levels: Dictionary) -> Dictionary:
	var completed_upgrades := clampi(
		int(component_levels.get("Rear Camera MP", 0)),
		0,
		REAR_CAMERA_MP_RESEARCH_UPGRADES
	)
	if completed_upgrades >= REAR_CAMERA_MP_RESEARCH_UPGRADES:
		return {}
	var target_level := completed_upgrades + 2
	var target_maximum := get_rear_camera_mp_max_for_level(completed_upgrades + 1)
	return {
		"index": target_level,
		"technology": "%dMP" % target_maximum,
		"max_rear_camera_mp": target_maximum
	}


static func get_rear_camera_count_max_for_level(completed_upgrades: int) -> int:
	return REAR_HARDWARE_BASE_COUNT + clampi(completed_upgrades, 0, REAR_HARDWARE_COUNT_RESEARCH_UPGRADES)


static func get_rear_flash_count_max_for_level(completed_upgrades: int) -> int:
	return REAR_HARDWARE_BASE_COUNT + clampi(completed_upgrades, 0, REAR_HARDWARE_COUNT_RESEARCH_UPGRADES)


static func _get_rear_hardware_count_research_target(component_levels: Dictionary, component: String, noun: String) -> Dictionary:
	var completed_upgrades := clampi(
		int(component_levels.get(component, 0)),
		0,
		REAR_HARDWARE_COUNT_RESEARCH_UPGRADES
	)
	if completed_upgrades >= REAR_HARDWARE_COUNT_RESEARCH_UPGRADES:
		return {}
	var target_level := completed_upgrades + 1
	var target_count := REAR_HARDWARE_BASE_COUNT + target_level
	return {
		"index": target_level,
		"technology": "%d %s" % [target_count, noun],
		"max_count": target_count
	}


static func get_rear_camera_count_research_target(component_levels: Dictionary) -> Dictionary:
	return _get_rear_hardware_count_research_target(component_levels, "Rear Camera Count", "cameras")


static func get_rear_flash_count_research_target(component_levels: Dictionary) -> Dictionary:
	return _get_rear_hardware_count_research_target(component_levels, "Rear Flash Count", "flashes")


static func get_back_raised_design_max_for_level(research_level: int) -> int:
	# Level 0 is locked. The first approval unlocks one box; each later
	# approval adds one more, up to twenty raised back-design boxes.
	return clampi(research_level, 0, BACK_RAISED_DESIGN_MAX_BOXES)


static func get_back_raised_design_research_target(component_levels: Dictionary) -> Dictionary:
	var completed_level := clampi(
		int(component_levels.get("Back Raised Design", 0)),
		0,
		BACK_RAISED_DESIGN_MAX_BOXES
	)
	if completed_level >= BACK_RAISED_DESIGN_MAX_BOXES:
		return {}
	var target_level := completed_level + 1
	var box_name := "raised box" if target_level == 1 else "raised boxes"
	return {
		"index": target_level,
		"technology": "%d %s" % [target_level, box_name],
		"max_count": target_level
	}


static func get_power_volume_button_length_research_target(component_levels: Dictionary) -> Dictionary:
	var current_level := clampi(
		int(component_levels.get(POWER_VOLUME_BUTTON_LENGTH_COMPONENT, 0)),
		0,
		POWER_VOLUME_BUTTON_LENGTH_MAX_LEVEL
	)
	if current_level >= POWER_VOLUME_BUTTON_LENGTH_MAX_LEVEL:
		return {}
	var target_level := current_level + 1
	var minimum_scale := int(round(POWER_VOLUME_BUTTON_LENGTH_MIN_SCALES[target_level] * 100.0))
	return {
		"index": target_level,
		"technology": "Minimum button length %d%%" % minimum_scale,
		"minimum_length_scale": POWER_VOLUME_BUTTON_LENGTH_MIN_SCALES[target_level]
	}


static func get_wireless_charging_max_for_level(level: int) -> int:
	# Wireless charging is locked at Level 0. Its first approved project unlocks
	# Level 1 at 1W; the next 66 upgrades mirror the wired 1W–200W progression.
	var unlocked_level := clampi(level, 0, WIRELESS_CHARGING_MAX_LEVEL)
	if unlocked_level <= 0:
		return 0
	return get_charging_speed_max_for_level(unlocked_level - 1)


static func get_wireless_charging_research_target(component_levels: Dictionary) -> Dictionary:
	var current_level := clampi(
		int(component_levels.get("Wireless Charging", 0)),
		0,
		WIRELESS_CHARGING_MAX_LEVEL
	)
	if current_level >= WIRELESS_CHARGING_MAX_LEVEL:
		return {}
	var target_level := current_level + 1
	var target_maximum := get_wireless_charging_max_for_level(target_level)
	return {
		"index": target_level,
		"technology": "%dW" % target_maximum,
		"max_wireless_charging_speed_w": target_maximum
	}


static func _format_research_integer(value: int) -> String:
	var digits := str(value)
	var formatted := ""
	while digits.length() > 3:
		formatted = "," + digits.substr(digits.length() - 3, 3) + formatted
		digits = digits.substr(0, digits.length() - 3)
	return digits + formatted


static func get_phone_type_entry(index: int) -> Dictionary:
	if index < 0 or index >= PHONE_TYPE_SEQUENCE.size():
		return {}
	return {"technology": PHONE_TYPE_SEQUENCE[index], "index": index}


static func get_phone_type_research_target(component_levels: Dictionary) -> Dictionary:
	var current_level := clampi(int(component_levels.get("Phone Type", 0)), 0, PHONE_TYPE_SEQUENCE.size() - 1)
	var target_index := current_level + 1
	if target_index >= PHONE_TYPE_SEQUENCE.size():
		return {}
	return get_phone_type_entry(target_index)


static func get_cooling_system_research_target(component_levels: Dictionary) -> Dictionary:
	var current_level := clampi(
		int(component_levels.get("Cooling System Design", 0)),
		0,
		COOLING_SYSTEM_SEQUENCE.size() - 1
	)
	var target_index := current_level + 1
	if target_index >= COOLING_SYSTEM_SEQUENCE.size():
		return {}
	return get_cooling_system_entry(target_index)


static func get_cooling_system_step_count() -> int:
	return COOLING_SYSTEM_SEQUENCE.size()


static func get_cooling_system_entry(index: int) -> Dictionary:
	if index < 0 or index >= COOLING_SYSTEM_SEQUENCE.size():
		return {}
	return {"technology": COOLING_SYSTEM_SEQUENCE[index], "index": index}


const BLUETOOTH_SEQUENCE := [
	{"generation": "Bluetooth 1.0b", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 1.0b"},
	{"generation": "Bluetooth 1.1", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 1.1"},
	{"generation": "Bluetooth 1.2", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 1.2"},
	{"generation": "Bluetooth 2.0 + EDR", "generation_name": "Enhanced Data Rate", "technology": "Bluetooth 2.0 + EDR"},
	{"generation": "Bluetooth 2.1 + EDR", "generation_name": "Secure Simple Pairing", "technology": "Bluetooth 2.1 + EDR"},
	{"generation": "Bluetooth 3.0 + HS", "generation_name": "High Speed", "technology": "Bluetooth 3.0 + HS"},
	{"generation": "Bluetooth 4.0", "generation_name": "Bluetooth Low Energy", "technology": "Bluetooth 4.0"},
	{"generation": "Bluetooth 4.1", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 4.1"},
	{"generation": "Bluetooth 4.2", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 4.2"},
	{"generation": "Bluetooth 5.0", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 5.0"},
	{"generation": "Bluetooth 5.1", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 5.1"},
	{"generation": "Bluetooth 5.2", "generation_name": "LE Audio foundation", "technology": "Bluetooth 5.2"},
	{"generation": "Bluetooth 5.3", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 5.3"},
	{"generation": "Bluetooth 5.4", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 5.4"},
	{"generation": "Bluetooth 6.0", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 6.0"},
	{"generation": "Bluetooth 6.1", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 6.1"},
	{"generation": "Bluetooth 6.2", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 6.2"},
	{"generation": "Bluetooth 6.3", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 6.3"},
	{"generation": "Bluetooth 7.0", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 7.0"}
]


static func get_bluetooth_step_count() -> int:
	return BLUETOOTH_SEQUENCE.size()


static func get_bluetooth_entry(index: int) -> Dictionary:
	if index < 0 or index >= BLUETOOTH_SEQUENCE.size():
		return {}
	var entry: Dictionary = BLUETOOTH_SEQUENCE[index].duplicate(true)
	entry["index"] = index
	return entry


static func normalize_component(component_value: String) -> String:
	var component := component_value.strip_edges()
	if component == "Screen Tech":
		return "Screen Technology"
	return component


static func get_memory_clock_speed_for_level(level: int) -> int:
	# One continuous speed ladder: every 20 approved projects unlocks the next
	# RAM-generation speed ceiling. Level 0 is the 200 MT/s starting speed.
	var safe_level := clampi(level, 0, MEMORY_CLOCK_MAX_RESEARCH_LEVEL)
	var previous_level := 0
	var previous_speed := MEMORY_CLOCK_MIN_SPEED
	for range_index in range(MEMORY_CLOCK_SPEED_TARGETS.size()):
		var range_end_level := (range_index + 1) * MEMORY_CLOCK_RESEARCH_LEVELS_PER_RANGE
		var range_end_speed := int(MEMORY_CLOCK_SPEED_TARGETS[range_index])
		if safe_level <= range_end_level:
			var progress := float(safe_level - previous_level) / float(MEMORY_CLOCK_RESEARCH_LEVELS_PER_RANGE)
			return roundi(lerpf(float(previous_speed), float(range_end_speed), progress))
		previous_level = range_end_level
		previous_speed = range_end_speed
	return previous_speed


static func get_memory_clock_research_ceiling_for_ram_technology_level(level: int) -> int:
	# RAM Technology research unlocks the next 20-level Memory Clock range.
	# LPDDR4X shares LPDDR4's ceiling and therefore adds no extra levels.
	var technology_level := clampi(level, 0, MEMORY_CLOCK_RAM_TECHNOLOGY_LEVEL_CAPS.size() - 1)
	return int(MEMORY_CLOCK_RAM_TECHNOLOGY_LEVEL_CAPS[technology_level])


static func get_memory_clock_max_level_for_ram_technology(technology: String) -> int:
	# Hardware capability limits the slider independently of research progress.
	match technology.strip_edges().to_upper():
		"LPDDR2":
			return 20
		"LPDDR3":
			return 40
		"LPDDR4", "LPDDR4X":
			return 60
		"LPDDR5":
			return 80
		"LPDDR5X":
			return 100
		"LPDDR6":
			return MEMORY_CLOCK_MAX_RESEARCH_LEVEL
		_:
			return 20


static func ensure_state(career: Dictionary) -> void:
	var projects_value: Variant = career.get("research_projects", [])
	if not (projects_value is Array):
		career["research_projects"] = []
	var projects: Array = career.get("research_projects", [])
	for index in range(projects.size()):
		if not (projects[index] is Dictionary):
			continue
		var project: Dictionary = projects[index]
		if not project.has("required_research_days"):
			var old_required_hours := maxf(0.001, float(project.get("work_required_hours", 120.0)))
			var old_completed_hours := clampf(float(project.get("work_completed_hours", 0.0)) / old_required_hours, 0.0, 1.0)
			var legacy_duration := maxf(MIN_RESEARCH_DURATION_DAYS, BASE_RESEARCH_DURATION_DAYS)
			project["required_research_days"] = legacy_duration
			project["completed_research_days"] = legacy_duration * old_completed_hours
			project["estimated_duration_days"] = legacy_duration
		if int(project.get("duration_formula_version", 0)) < RESEARCH_DURATION_FORMULA_VERSION:
			var previous_required_days := maxf(
				MIN_RESEARCH_DURATION_DAYS,
				float(project.get("required_research_days", BASE_RESEARCH_DURATION_DAYS))
			)
			var progress_ratio := clampf(
				float(project.get("completed_research_days", 0.0)) / previous_required_days,
				0.0,
				1.0
			)
			var component_duration := get_component_research_duration_days(
				str(project.get("component", "")),
				int(project.get("research_target_index", -1))
			)
			project["required_research_days"] = component_duration
			project["completed_research_days"] = component_duration * progress_ratio
			project["estimated_duration_days"] = component_duration
			project["duration_formula_version"] = RESEARCH_DURATION_FORMULA_VERSION
		project.erase("work_required_hours")
		project.erase("work_completed_hours")
		project.erase("daily_work_hours")
		# Recalculate saved projects once using only the efficiency already recorded
		# for the researchers assigned to that specific project.
		if int(project.get("success_formula_version", 0)) < RESEARCH_SUCCESS_FORMULA_VERSION:
			project["success_chance"] = _calculate_research_success_chance(
				float(project.get("team_efficiency", 0.0))
			)
			project["success_formula_version"] = RESEARCH_SUCCESS_FORMULA_VERSION
		projects[index] = project
	career["research_projects"] = projects
	var component_levels_value: Variant = career.get("research_component_levels", {})
	if not (component_levels_value is Dictionary):
		career["research_component_levels"] = {}
	var component_levels: Dictionary = career.get("research_component_levels", {})
	if int(component_levels.get("Box Package", 0)) < 1:
		for saved_project_value in projects:
			if not (saved_project_value is Dictionary):
				continue
			var saved_box_package_project: Dictionary = saved_project_value
			if str(saved_box_package_project.get("component", "")) == "Box Package" and str(saved_box_package_project.get("status", "")) == STATUS_APPROVED and int(saved_box_package_project.get("research_target_index", -1)) == 1 and str(saved_box_package_project.get("research_target", "")) == "Box Package":
				component_levels["Box Package"] = 1
				break
	career["research_component_levels"] = component_levels
	var technologies_value: Variant = career.get("research_technologies", {})
	if not (technologies_value is Dictionary):
		career["research_technologies"] = {}
	var next_id := maxi(1, int(career.get("next_research_project_id", 1)))
	career["next_research_project_id"] = next_id


static func get_workforce_summary(career: Dictionary) -> Dictionary:
	ensure_state(career)
	var total_staff := 0
	var available_staff := 0
	var total_efficiency := 0.0
	var available_efficiency := 0.0
	var occupied_ids := _get_active_project_staff_ids(career)

	for employee_value in career.get("staff_employees", []):
		if not (employee_value is Dictionary):
			continue
		var employee: Dictionary = employee_value
		if str(employee.get("department", "")) != "Research":
			continue
		var employee_id := str(employee.get("id", ""))
		var efficiency := float(clampi(int(employee.get("efficiency", 0)), 0, 100))
		total_staff += 1
		total_efficiency += efficiency
		if employee_id.is_empty() or occupied_ids.has(employee_id):
			continue
		available_staff += 1
		available_efficiency += efficiency

	return {
		"staff_count": total_staff,
		"available_staff_count": available_staff,
		"total_efficiency": total_efficiency,
		"available_efficiency": available_efficiency
	}


static func _calculate_research_success_chance(team_efficiency: float) -> float:
	var efficiency_contribution := maxf(0.0, team_efficiency) / 100.0 * RESEARCH_SUCCESS_POINTS_PER_100_EFFICIENCY
	return clampf(
		RESEARCH_BASE_SUCCESS_CHANCE + efficiency_contribution,
		RESEARCH_BASE_SUCCESS_CHANCE,
		RESEARCH_MAX_SUCCESS_CHANCE
	)


static func estimate_research(component_value: String, requested_staff: Array, employees: Array, research_target_index: int = -1) -> Dictionary:
	var component := normalize_component(component_value)
	if not COMPONENT_CATALOGUE.has(component):
		return _failure("Choose an available research component.")

	var selected_ids: Array[String] = []
	var team_efficiency := 0.0
	var staff_count := 0
	for staff_value in requested_staff:
		var staff_id := str(staff_value).strip_edges()
		if staff_id.is_empty() or selected_ids.has(staff_id):
			continue
		for employee_value in employees:
			if not (employee_value is Dictionary):
				continue
			var employee: Dictionary = employee_value
			if str(employee.get("id", "")) != staff_id or str(employee.get("department", "")) != "Research":
				continue
			selected_ids.append(staff_id)
			team_efficiency += float(clampi(int(employee.get("efficiency", 0)), 0, 100))
			staff_count += 1
			break

	if staff_count == 0:
		return _failure("Assign at least one available Research employee.")

	var average_efficiency := team_efficiency / float(staff_count)
	var expected_days := get_component_research_duration_days(component, research_target_index)
	# Each assigned researcher contributes independently: 100 efficiency points
	# add one percentage point to success. Unassigned company staff do not count.
	var success_chance := _calculate_research_success_chance(team_efficiency)
	return {
		"ok": true,
		"component": component,
		"staff_ids": selected_ids,
		"staff_count": staff_count,
		"team_efficiency": team_efficiency,
		"average_efficiency": average_efficiency,
		"expected_duration_days": expected_days,
		"success_chance": success_chance
	}


static func commission_project(career: Dictionary, request: Dictionary, game_time_unix: float) -> Dictionary:
	ensure_state(career)

	var component := normalize_component(str(request.get("component", "")))
	if component.is_empty():
		var requested_components: Variant = request.get("components", [])
		if requested_components is Array and not requested_components.is_empty():
			component = normalize_component(str(requested_components[0]))
	if not COMPONENT_CATALOGUE.has(component):
		return _failure("Choose an available research component.")

	if component == "Smartwatch":
		if int(career.get("research_component_levels", {}).get(component, 0)) >= 1:
			return _failure("Smartwatch has already been researched.")
		for existing_project_value in career.get("research_projects", []):
			if not (existing_project_value is Dictionary):
				continue
			var existing_smartwatch_project: Dictionary = existing_project_value
			if str(existing_smartwatch_project.get("component", "")) == component and str(existing_smartwatch_project.get("status", "")) in [STATUS_ACTIVE, STATUS_AWAITING_VALIDATION]:
				return _failure("Smartwatch research is already in progress or awaiting validation.")

	if component == "Box Package":
		if int(career.get("research_component_levels", {}).get(component, 0)) >= 1:
			return _failure("Box Package has already been researched.")
		for existing_project_value in career.get("research_projects", []):
			if not (existing_project_value is Dictionary):
				continue
			var existing_box_package_project: Dictionary = existing_project_value
			if str(existing_box_package_project.get("component", "")) == component and str(existing_box_package_project.get("status", "")) in [STATUS_ACTIVE, STATUS_AWAITING_VALIDATION, STATUS_APPROVED]:
				return _failure("Box Package research is already in progress or awaiting validation.")

	if component == "Wireless Earbuds":
		if int(career.get("research_component_levels", {}).get(component, 0)) >= 1:
			return _failure("Wireless Earbuds have already been researched.")
		for existing_project_value in career.get("research_projects", []):
			if not (existing_project_value is Dictionary):
				continue
			var existing_earbuds_project: Dictionary = existing_project_value
			if str(existing_earbuds_project.get("component", "")) == component and str(existing_earbuds_project.get("status", "")) in [STATUS_ACTIVE, STATUS_AWAITING_VALIDATION]:
				return _failure("Wireless Earbuds research is already in progress or awaiting validation.")

	if component == "Device Color":
		if int(career.get("research_component_levels", {}).get(component, 0)) >= 1:
			return _failure("Gradient device colour has already been unlocked.")
		for existing_project_value in career.get("research_projects", []):
			if not (existing_project_value is Dictionary):
				continue
			var existing_color_project: Dictionary = existing_project_value
			if str(existing_color_project.get("component", "")) == component and str(existing_color_project.get("status", "")) in [STATUS_ACTIVE, STATUS_AWAITING_VALIDATION]:
				return _failure("Device Color research is already in progress or awaiting validation.")

	if CURVED_SCREEN_RESEARCH_COMPONENTS.has(component):
		var completed_level := int(career.get("research_component_levels", {}).get(component, 0))
		if completed_level >= 1:
			return _failure("%s has already been researched." % component)
		for existing_project_value in career.get("research_projects", []):
			if not (existing_project_value is Dictionary):
				continue
			var existing_project: Dictionary = existing_project_value
			if str(existing_project.get("component", "")) == component and str(existing_project.get("status", "")) in [STATUS_ACTIVE, STATUS_AWAITING_VALIDATION]:
				return _failure("%s already has a research project in progress or awaiting validation." % component)

	if component == "Memory Clock":
		var memory_clock_level := int(career.get("research_component_levels", {}).get("Memory Clock", 0))
		var ram_technology_level := int(career.get("research_component_levels", {}).get("RAM Technology", 0))
		var memory_clock_research_ceiling := get_memory_clock_research_ceiling_for_ram_technology_level(ram_technology_level)
		if memory_clock_level >= memory_clock_research_ceiling:
			if memory_clock_research_ceiling >= MEMORY_CLOCK_MAX_RESEARCH_LEVEL:
				return _failure("Memory Clock has reached its maximum research level.")
			return _failure("Unlock a newer RAM Technology before researching faster Memory Clock speeds.")

	if PHONE_SENSOR_COMPONENTS.has(component) or SIDE_BUTTON_COMPONENTS.has(component) or POWER_VOLUME_BUTTON_POSITION_COMPONENTS.has(component):
		if int(career.get("research_component_levels", {}).get(component, 0)) >= 1:
			return _failure("%s research has already been approved." % component)
		for existing_project_value in career.get("research_projects", []):
			if not (existing_project_value is Dictionary):
				continue
			var existing_unlock_project: Dictionary = existing_project_value
			if str(existing_unlock_project.get("component", "")) == component and str(existing_unlock_project.get("status", "")) in [STATUS_ACTIVE, STATUS_AWAITING_VALIDATION]:
				return _failure("%s already has a research project in progress or awaiting validation." % component)

	var requested_staff: Variant = request.get("staff_ids", [])
	if not (requested_staff is Array) or requested_staff.is_empty():
		return _failure("Assign at least one available Research employee.")

	var occupied_ids := _get_active_project_staff_ids(career)
	var valid_staff_ids: Array[String] = []
	for staff_value in requested_staff:
		var staff_id := str(staff_value).strip_edges()
		if staff_id.is_empty() or valid_staff_ids.has(staff_id):
			continue
		var employee := _find_employee(career, staff_id)
		if employee.is_empty() or str(employee.get("department", "")) != "Research":
			return _failure("Every assigned person must be a Research department employee.")
		if occupied_ids.has(staff_id):
			return _failure("An assigned researcher is already working on another active project.")
		valid_staff_ids.append(staff_id)

	var estimate := estimate_research(component, valid_staff_ids, career.get("staff_employees", []))
	if not bool(estimate.get("ok", false)):
		return _failure(str(estimate.get("error", "The research team could not be calculated.")))

	var ordered_target: Dictionary = {}
	if component == "Mobile Network":
		ordered_target = get_mobile_network_research_target(career.get("research_component_levels", {}))
	elif component == "Wi-Fi":
		ordered_target = get_wifi_research_target(career.get("research_component_levels", {}))
	elif component == "Bluetooth":
		ordered_target = get_bluetooth_research_target(career.get("research_component_levels", {}))
	elif component == "Cooling System Design":
		ordered_target = get_cooling_system_research_target(career.get("research_component_levels", {}))
	elif component == "Phone Type":
		ordered_target = get_phone_type_research_target(career.get("research_component_levels", {}))
	elif component == "Battery Capacity":
		ordered_target = get_battery_capacity_research_target(career.get("research_component_levels", {}))
	elif component == "Charger":
		ordered_target = get_charger_research_target(career.get("research_component_levels", {}))
	elif component == "Power Bank":
		ordered_target = get_power_bank_research_target(career.get("research_component_levels", {}))
	elif component == "Charging Speed":
		ordered_target = get_charging_speed_research_target(career.get("research_component_levels", {}))
	elif component == "Wireless Charging":
		ordered_target = get_wireless_charging_research_target(career.get("research_component_levels", {}))
	elif component == "Front Camera MP":
		ordered_target = get_front_camera_mp_research_target(career.get("research_component_levels", {}))
	elif component == "Rear Camera MP":
		ordered_target = get_rear_camera_mp_research_target(career.get("research_component_levels", {}))
	elif component == "Rear Camera Count":
		ordered_target = get_rear_camera_count_research_target(career.get("research_component_levels", {}))
	elif component == "Rear Flash Count":
		ordered_target = get_rear_flash_count_research_target(career.get("research_component_levels", {}))
	elif component == "Back Raised Design":
		ordered_target = get_back_raised_design_research_target(career.get("research_component_levels", {}))
	elif component == "Smartwatch":
		ordered_target = {"index": 1, "technology": "Smartwatch"}
	elif component == "Wireless Earbuds":
		ordered_target = {"index": 1, "technology": "Wireless Earbuds"}
	elif component == "Box Package":
		ordered_target = {"index": 1, "technology": "Box Package"}
	elif component == "Device Color":
		ordered_target = {"index": 1, "technology": "Gradient Finish"} if int(career.get("research_component_levels", {}).get("Device Color", 0)) < 1 else {}
	elif component == "Phone Case":
		ordered_target = get_phone_case_research_target(career.get("research_component_levels", {}))
	elif component == "Protection Glass":
		ordered_target = get_protection_glass_research_target(career.get("research_component_levels", {}))
	elif component == POWER_VOLUME_BUTTON_LENGTH_COMPONENT:
		ordered_target = get_power_volume_button_length_research_target(career.get("research_component_levels", {}))
	elif PHONE_SENSOR_COMPONENTS.has(component) or SIDE_BUTTON_COMPONENTS.has(component) or POWER_VOLUME_BUTTON_POSITION_COMPONENTS.has(component):
		ordered_target = {"index": 1, "technology": "Left and Top positions" if POWER_VOLUME_BUTTON_POSITION_COMPONENTS.has(component) else component}
	if component in ["Wireless Charging", "Phone Case"]:
		estimate["expected_duration_days"] = get_component_research_duration_days(component, int(ordered_target.get("index", -1)))

	if component in ["Mobile Network", "Wi-Fi", "Bluetooth", "Cooling System Design", "Phone Type", "Battery Capacity", "Charger", "Power Bank", "Charging Speed", "Wireless Charging", "Front Camera MP", "Rear Camera MP", "Rear Camera Count", "Rear Flash Count", "Back Raised Design", "Device Color", "Phone Case", "Protection Glass", POWER_VOLUME_BUTTON_LENGTH_COMPONENT] or component == "Box Package" or PHONE_SENSOR_COMPONENTS.has(component) or SIDE_BUTTON_COMPONENTS.has(component) or POWER_VOLUME_BUTTON_POSITION_COMPONENTS.has(component):
		if ordered_target.is_empty():
			return _failure("All %s technologies in the progression have already been researched." % component)
		var target_index := int(ordered_target.get("index", -1))
		for existing_project_value in career.get("research_projects", []):
			if not (existing_project_value is Dictionary):
				continue
			var existing_project: Dictionary = existing_project_value
			if str(existing_project.get("component", "")) != component:
				continue
			if int(existing_project.get("research_target_index", -1)) != target_index:
				continue
			if str(existing_project.get("status", "")) in [STATUS_ACTIVE, STATUS_AWAITING_VALIDATION]:
				return _failure("The next %s technology already has a project in progress or awaiting validation." % component)

	if component in ["Screen Width", "Screen Height", "Refresh Rate", "Memory Clock", "Battery Capacity", "Speakers"]:
		for existing_project_value in career.get("research_projects", []):
			if not (existing_project_value is Dictionary):
				continue
			var existing_project: Dictionary = existing_project_value
			if str(existing_project.get("component", "")) == component and str(existing_project.get("status", "")) in [STATUS_ACTIVE, STATUS_AWAITING_VALIDATION]:
				return _failure("%s already has a research project in progress or awaiting validation." % component)

	var project_title := "Research: " + component
	var project_objective := ""
	if not ordered_target.is_empty():
		var target_technology := str(ordered_target.get("technology", ""))
		var target_generation := str(ordered_target.get("generation", ""))
		project_title = "Research: %s - %s" % [component, target_technology]
		if component == "Front Camera MP":
			project_objective = "Develop and validate the next front-camera resolution ceiling of %s while preserving player-selected resolutions in 1MP increments." % target_technology
		elif component == "Rear Camera MP":
			project_objective = "Develop and validate the next rear-camera resolution ceiling of %s while preserving player-selected resolutions in 1MP increments." % target_technology
		elif component == "Rear Camera Count":
			project_objective = "Research and validate support for a rear camera capacity of %s in one phone." % target_technology
		elif component == "Rear Flash Count":
			project_objective = "Research and validate support for a rear flash capacity of %s in one phone." % target_technology
		elif component == "Back Raised Design":
			project_objective = "Develop and validate support for %s on the back of one phone." % target_technology
		elif component == "Device Color":
			project_objective = "Develop and validate a gradient-finish system for the phone body while preserving the standard solid-colour finish as the default option."
		elif component == "Box Package":
			project_title = "Research: Box Package - Initial Unlock"
			project_objective = "Develop and validate the company-branded phone box package, unlocking all existing box-package customization controls in the phone creation worksite."
		elif component == "Wireless Earbuds":
			project_title = "Research: Wireless Earbuds - Initial Unlock"
			project_objective = "Develop and validate the wireless-earbuds accessory, unlocking its availability in the phone creation worksite."
		elif component == "Charger":
			var charger_stage := str(ordered_target.get("stage", ""))
			if charger_stage == "adapter":
				project_title = "Research: Charger - Initial Adapter Unlock"
				project_objective = "Develop and validate the wall charger adapter, unlocking its availability in the phone creation worksite with a 2W starting output ceiling."
			elif charger_stage == "cable":
				project_title = "Research: Charger - Physical Cable Unlock"
				project_objective = "Develop and validate the physical charging cable as a separate unlock. The cable must remain unavailable until this project is approved."
			else:
				project_title = "Research: Charger - %s Output Ceiling" % target_technology
				project_objective = "Develop and validate the next charger output-power ceiling of %s, increasing the selectable maximum by 3W while allowing whole-watt selections from 2W." % target_technology
		elif component == "Phone Case":
			project_title = "Research: Phone Case - " + target_technology
			project_objective = "Develop and validate %s for the fitted phone-case system. Smooth is the default finish; subsequent projects unlock each additional case design and finally gradient colouring." % target_technology
		elif component == "Protection Glass":
			project_title = "Research: Protection Glass - " + target_technology
			project_objective = "Develop and validate %s as a fitted screen-protection layer. Normal Glass provides subtle screen darkening; Privacy Glass adds a directional viewing filter that turns the display fully black at side angles." % target_technology
		elif PHONE_SENSOR_COMPONENTS.has(component):
			project_title = "Research: %s" % component
			project_objective = "Develop, test and validate the %s module for mobile-phone integration." % component
		elif SIDE_BUTTON_COMPONENTS.has(component):
			project_title = "Research: %s" % component
			project_objective = "Develop, test and validate the %s physical side feature for mobile-phone integration." % component
		elif component == POWER_VOLUME_BUTTON_LENGTH_COMPONENT:
			project_objective = "Research and validate the next lower minimum length limit for the shared physical power and volume buttons."
		elif POWER_VOLUME_BUTTON_POSITION_COMPONENTS.has(component):
			project_objective = "Research and validate additional left-edge and top-edge placement options for the %s." % ("power button" if component == "Power Button Position" else "volume rocker")
		elif component == "Bluetooth":
			project_title = "Research: %s" % target_technology
			project_objective = "Develop and validate %s for mobile-device connectivity." % target_technology
		elif component == "Mobile Network":
			project_objective = "Develop and validate %s for %s mobile networks." % [target_technology, target_generation]
		elif component == "Wi-Fi":
			project_objective = "Develop and validate IEEE %s for %s wireless networks." % [target_technology, target_generation]
		elif component == "Cooling System Design":
			project_objective = "Develop and validate %s for mobile phone heat removal." % target_technology
		elif component == "Phone Type":
			project_objective = "Develop and validate the %s mobile phone chassis architecture." % target_technology
		elif component == "Battery Capacity":
			project_objective = "Develop and validate the next battery capacity ceiling of %s while preserving player-selected capacity in 1 mAh increments." % target_technology
		elif component == "Power Bank":
			if int(career.get("research_component_levels", {}).get("Power Bank", 0)) == 0:
				project_title = "Research: Power Bank - Initial Unlock (5,000 mAh)"
				project_objective = "Develop and validate the Power Bank accessory, unlocking its availability with an initial capacity ceiling of 5,000 mAh."
			else:
				project_objective = "Develop and validate the next Power Bank capacity ceiling of %s while preserving player-selected capacity in 100 mAh increments." % target_technology
		elif component == "Charging Speed":
			project_objective = "Develop and validate the next wired charging-speed ceiling of %s while preserving player-selected speeds in 1W increments." % target_technology
		elif component == "Wireless Charging":
			project_objective = "Develop and validate the next wireless charging-speed ceiling of %s while preserving player-selected speeds in 1W increments." % target_technology
	elif component in ["Screen Width", "Screen Height", "Refresh Rate"]:
		project_objective = "Develop and validate improved %s for mobile phone displays." % component.to_lower()
	elif component == "Memory Clock":
		project_objective = "Develop and validate higher memory data-transfer speeds for mobile phone RAM."
	elif CURVED_SCREEN_RESEARCH_COMPONENTS.has(component):
		match component:
			"Curved Screen Horizontal":
				project_objective = "Develop and validate curved display glass along the left and right edges of a mobile phone."
			"Curved Screen Vertical":
				project_objective = "Develop and validate curved display glass along the top and bottom edges of a mobile phone."
			"Curved Screen Both":
				project_objective = "Develop and validate curved display glass along all four edges of a mobile phone."

	var project_id := "RDP-%06d" % int(career.get("next_research_project_id", 1))
	career["next_research_project_id"] = int(career.get("next_research_project_id", 1)) + 1
	var project := {
		"id": project_id,
		"title": project_title,
		"component": component,
		"components": [component],
		"objective": project_objective,
		"research_target_index": int(ordered_target.get("index", -1)),
		"research_target": str(ordered_target.get("technology", "")),
		"research_generation": str(ordered_target.get("generation", "")),
		"project_type": "technology_improvement",
		"required_research_days": float(estimate.get("expected_duration_days", BASE_RESEARCH_DURATION_DAYS)),
		"completed_research_days": 0.0,
		"estimated_duration_days": float(estimate.get("expected_duration_days", BASE_RESEARCH_DURATION_DAYS)),
		"duration_formula_version": RESEARCH_DURATION_FORMULA_VERSION,
		"team_efficiency": float(estimate.get("team_efficiency", 0.0)),
		"average_efficiency": float(estimate.get("average_efficiency", 0.0)),
		"success_chance": float(estimate.get("success_chance", RESEARCH_BASE_SUCCESS_CHANCE)),
		"success_formula_version": RESEARCH_SUCCESS_FORMULA_VERSION,
		"staff_ids": valid_staff_ids,
		"status": STATUS_ACTIVE,
		"pause_reason": "",
		"created_at_unix": game_time_unix,
		"completed_at_unix": 0.0,
		"approved_at_unix": 0.0,
		"approved_results": []
	}
	var projects: Array = career.get("research_projects", [])
	projects.append(project)
	career["research_projects"] = projects
	return {"ok": true, "project": project.duplicate(true)}


static func advance_projects(career: Dictionary, in_game_seconds: float, game_time_unix: float) -> Array[String]:
	ensure_state(career)
	var completed_project_ids: Array[String] = []
	if in_game_seconds <= 0.0:
		return completed_project_ids

	var employees: Array = career.get("staff_employees", [])
	var projects: Array = career.get("research_projects", [])
	var game_days := in_game_seconds / 86400.0

	for project_value in projects:
		if not (project_value is Dictionary):
			continue
		var project: Dictionary = project_value
		if str(project.get("status", "")) != STATUS_ACTIVE:
			continue

		var staff_ids: Array = project.get("staff_ids", [])
		var has_assigned_researcher := false
		for employee_value in employees:
			if not (employee_value is Dictionary):
				continue
			var employee: Dictionary = employee_value
			var employee_id := str(employee.get("id", ""))
			if staff_ids.has(employee_id) and str(employee.get("department", "")) == "Research":
				has_assigned_researcher = true
				break

		if not has_assigned_researcher:
			project["pause_reason"] = "No assigned Research employees are currently available."
			continue

		project["pause_reason"] = ""
		var required_days := maxf(MIN_RESEARCH_DURATION_DAYS, float(project.get("required_research_days", BASE_RESEARCH_DURATION_DAYS)))
		var completed_days := maxf(0.0, float(project.get("completed_research_days", 0.0)))
		completed_days = minf(required_days, completed_days + game_days)
		project["completed_research_days"] = completed_days

		if completed_days >= required_days:
			project["completed_at_unix"] = game_time_unix
			var success_roll := randf()
			var project_success_chance := clampf(float(project.get("success_chance", RESEARCH_BASE_SUCCESS_CHANCE)) / 100.0, 0.0, 1.0)
			var successful := success_roll < project_success_chance
			project["success_roll"] = success_roll
			project["success_chance"] = project_success_chance * 100.0
			if successful:
				project["status"] = STATUS_AWAITING_VALIDATION

			else:
				project["status"] = STATUS_UNSUCCESSFUL
			completed_project_ids.append(str(project.get("id", "")))

	career["research_projects"] = projects
	return completed_project_ids


static func approve_project(career: Dictionary, project_id: String, results: Array, game_time_unix: float) -> Dictionary:
	ensure_state(career)
	var projects: Array = career.get("research_projects", [])
	var project_index := _find_project_index(projects, project_id)
	if project_index < 0:
		return _failure("Research project not found.")

	var project: Dictionary = projects[project_index]
	if str(project.get("status", "")) != STATUS_AWAITING_VALIDATION:
		return _failure("Only completed projects awaiting validation can be approved.")

	var component := normalize_component(str(project.get("component", "")))
	var component_levels: Dictionary = career.get("research_component_levels", {})
	var mobile_network_target_index := -1
	var wifi_target_index := -1
	var bluetooth_target_index := -1
	var cooling_system_target_index := -1
	var phone_type_target_index := -1
	var battery_capacity_target_index := -1
	var charger_target_index := -1
	var power_bank_target_index := -1
	var charging_speed_target_index := -1
	var wireless_charging_target_index := -1
	var front_camera_mp_target_index := -1
	var rear_camera_mp_target_index := -1
	var rear_camera_count_target_index := -1
	var rear_flash_count_target_index := -1
	var back_raised_design_target_index := -1
	var device_color_target_index := -1
	var phone_case_target_index := -1
	var protection_glass_target_index := -1
	var phone_sensor_target_index := -1
	var side_button_target_index := -1
	var power_volume_button_length_target_index := -1
	var power_volume_button_position_target_index := -1
	if component == "Mobile Network":
		mobile_network_target_index = int(project.get("research_target_index", -1))
		var expected_target_index := int(component_levels.get(component, 0)) + 1
		if mobile_network_target_index != expected_target_index:
			return _failure("This Mobile Network project is no longer the next technology in the research sequence.")
		var expected_target := get_mobile_network_entry(mobile_network_target_index)
		if expected_target.is_empty() or str(project.get("research_target", "")) != str(expected_target.get("technology", "")):
			return _failure("The Mobile Network project target does not match the current research sequence.")
	elif component == "Wi-Fi":
		wifi_target_index = int(project.get("research_target_index", -1))
		var expected_wifi_index := int(component_levels.get(component, 0)) + 1
		if wifi_target_index != expected_wifi_index:
			return _failure("This Wi-Fi project is no longer the next technology in the research sequence.")
		var expected_wifi_target := get_wifi_entry(wifi_target_index)
		if expected_wifi_target.is_empty() or str(project.get("research_target", "")) != str(expected_wifi_target.get("technology", "")):
			return _failure("The Wi-Fi project target does not match the current research sequence.")
	elif component == "Bluetooth":
		bluetooth_target_index = int(project.get("research_target_index", -1))
		var expected_bluetooth_index := int(component_levels.get(component, 0)) + 1
		if bluetooth_target_index != expected_bluetooth_index:
			return _failure("This Bluetooth project is no longer the next technology in the research sequence.")
		var expected_bluetooth_target := get_bluetooth_entry(bluetooth_target_index)
		if expected_bluetooth_target.is_empty() or str(project.get("research_target", "")) != str(expected_bluetooth_target.get("technology", "")):
			return _failure("The Bluetooth project target does not match the current research sequence.")
	elif component == "Cooling System Design":
		cooling_system_target_index = int(project.get("research_target_index", -1))
		var expected_cooling_index := int(component_levels.get(component, 0)) + 1
		if cooling_system_target_index != expected_cooling_index:
			return _failure("This Cooling System project is no longer the next heat-removal option.")
		var expected_cooling_target := get_cooling_system_entry(cooling_system_target_index)
		if expected_cooling_target.is_empty() or str(project.get("research_target", "")) != str(expected_cooling_target.get("technology", "")):
			return _failure("The Cooling System project target does not match the current heat-removal progression.")
	elif component == "Phone Type":
		phone_type_target_index = int(project.get("research_target_index", -1))
		var expected_phone_type_index := int(component_levels.get(component, 0)) + 1
		if phone_type_target_index != expected_phone_type_index:
			return _failure("This Phone Type project is no longer the next chassis architecture in the research sequence.")
		var expected_phone_type := get_phone_type_entry(phone_type_target_index)
		if expected_phone_type.is_empty() or str(project.get("research_target", "")) != str(expected_phone_type.get("technology", "")):
			return _failure("The Phone Type project target does not match the current chassis architecture progression.")
	elif component == "Charger":
		charger_target_index = int(project.get("research_target_index", -1))
		var expected_charger_target := get_charger_research_target(component_levels)
		if expected_charger_target.is_empty() or charger_target_index != int(expected_charger_target.get("index", -1)):
			return _failure("This Charger project is no longer the next valid adapter, cable or wattage unlock.")
		if str(project.get("research_target", "")) != str(expected_charger_target.get("technology", "")):
			return _failure("The Charger project target does not match the current unlock and output-power progression.")
	elif component == "Battery Capacity":
		battery_capacity_target_index = int(project.get("research_target_index", -1))
		var expected_battery_target := get_battery_capacity_research_target(component_levels)
		if expected_battery_target.is_empty() or battery_capacity_target_index != int(expected_battery_target.get("index", -1)):
			return _failure("This Battery Capacity project is no longer the next capacity improvement.")
		if str(project.get("research_target", "")) != str(expected_battery_target.get("technology", "")):
			return _failure("The Battery Capacity project target does not match the current capacity progression.")
	elif component == "Power Bank":
		power_bank_target_index = int(project.get("research_target_index", -1))
		var expected_power_bank_target := get_power_bank_research_target(component_levels)
		if expected_power_bank_target.is_empty() or power_bank_target_index != int(expected_power_bank_target.get("index", -1)):
			return _failure("This Power Bank project is no longer the next capacity unlock.")
		if str(project.get("research_target", "")) != str(expected_power_bank_target.get("technology", "")):
			return _failure("The Power Bank project target does not match the current capacity progression.")
	elif component == "Charging Speed":
		charging_speed_target_index = int(project.get("research_target_index", -1))
		var expected_charging_target := get_charging_speed_research_target(component_levels)
		if expected_charging_target.is_empty() or charging_speed_target_index != int(expected_charging_target.get("index", -1)):
			return _failure("This Charging Speed project is no longer the next charging-speed improvement.")
		if str(project.get("research_target", "")) != str(expected_charging_target.get("technology", "")):
			return _failure("The Charging Speed project target does not match the current charging-speed progression.")
	elif component == "Wireless Charging":
		wireless_charging_target_index = int(project.get("research_target_index", -1))
		var expected_wireless_target := get_wireless_charging_research_target(component_levels)
		if expected_wireless_target.is_empty() or wireless_charging_target_index != int(expected_wireless_target.get("index", -1)):
			return _failure("This Wireless Charging project is no longer the next charging-speed improvement.")
		if str(project.get("research_target", "")) != str(expected_wireless_target.get("technology", "")):
			return _failure("The Wireless Charging project target does not match the current wireless charging progression.")
	elif component == "Front Camera MP":
		front_camera_mp_target_index = int(project.get("research_target_index", -1))
		var expected_front_camera_mp_target := get_front_camera_mp_research_target(component_levels)
		if expected_front_camera_mp_target.is_empty() or front_camera_mp_target_index != int(expected_front_camera_mp_target.get("index", -1)):
			return _failure("This Front Camera MP project is no longer the next resolution improvement.")
		if str(project.get("research_target", "")) != str(expected_front_camera_mp_target.get("technology", "")):
			return _failure("The Front Camera MP project target does not match the current resolution progression.")
	elif component == "Rear Camera MP":
		rear_camera_mp_target_index = int(project.get("research_target_index", -1))
		var expected_rear_camera_mp_target := get_rear_camera_mp_research_target(component_levels)
		if expected_rear_camera_mp_target.is_empty() or rear_camera_mp_target_index != int(expected_rear_camera_mp_target.get("index", -1)):
			return _failure("This Rear Camera MP project is no longer the next resolution improvement.")
		if str(project.get("research_target", "")) != str(expected_rear_camera_mp_target.get("technology", "")):
			return _failure("The Rear Camera MP project target does not match the current resolution progression.")
	elif component == "Rear Camera Count":
		rear_camera_count_target_index = int(project.get("research_target_index", -1))
		var expected_rear_camera_count_target := get_rear_camera_count_research_target(component_levels)
		if expected_rear_camera_count_target.is_empty() or rear_camera_count_target_index != int(expected_rear_camera_count_target.get("index", -1)):
			return _failure("This Rear Camera Count project is no longer the next camera-capacity upgrade.")
		if str(project.get("research_target", "")) != str(expected_rear_camera_count_target.get("technology", "")):
			return _failure("The Rear Camera Count project target does not match the current camera-capacity progression.")
	elif component == "Rear Flash Count":
		rear_flash_count_target_index = int(project.get("research_target_index", -1))
		var expected_rear_flash_count_target := get_rear_flash_count_research_target(component_levels)
		if expected_rear_flash_count_target.is_empty() or rear_flash_count_target_index != int(expected_rear_flash_count_target.get("index", -1)):
			return _failure("This Rear Flash Count project is no longer the next flash-capacity upgrade.")
		if str(project.get("research_target", "")) != str(expected_rear_flash_count_target.get("technology", "")):
			return _failure("The Rear Flash Count project target does not match the current flash-capacity progression.")
	elif component == "Back Raised Design":
		back_raised_design_target_index = int(project.get("research_target_index", -1))
		var expected_back_raised_design_target := get_back_raised_design_research_target(component_levels)
		if expected_back_raised_design_target.is_empty() or back_raised_design_target_index != int(expected_back_raised_design_target.get("index", -1)):
			return _failure("This Back Raised Design project is no longer the next raised-box capacity upgrade.")
		if str(project.get("research_target", "")) != str(expected_back_raised_design_target.get("technology", "")):
			return _failure("The Back Raised Design project target does not match the current raised-box capacity progression.")
	elif component == "Smartwatch":
		if int(component_levels.get(component, 0)) >= 1 or int(project.get("research_target_index", -1)) != 1 or str(project.get("research_target", "")) != "Smartwatch":
			return _failure("This Smartwatch project is no longer a valid, unapproved enablement unlock.")
	elif component == "Wireless Earbuds":
		if int(component_levels.get(component, 0)) >= 1 or int(project.get("research_target_index", -1)) != 1 or str(project.get("research_target", "")) != "Wireless Earbuds":
			return _failure("This Wireless Earbuds project is no longer a valid, unapproved enablement unlock.")
	elif component == "Box Package":
		if int(component_levels.get(component, 0)) >= 1 or int(project.get("research_target_index", -1)) != 1 or str(project.get("research_target", "")) != "Box Package":
			return _failure("This Box Package project is no longer a valid, unapproved enablement unlock.")
	elif component == "Device Color":
		device_color_target_index = int(project.get("research_target_index", -1))
		if int(component_levels.get(component, 0)) >= 1 or device_color_target_index != 1 or str(project.get("research_target", "")) != "Gradient Finish":
			return _failure("The Device Color project no longer matches the gradient-finish unlock.")
	elif component == "Phone Case":
		var expected_phone_case_target := get_phone_case_research_target(component_levels)
		phone_case_target_index = int(project.get("research_target_index", -1))
		if expected_phone_case_target.is_empty() or phone_case_target_index != int(expected_phone_case_target.get("index", -1)) or str(project.get("research_target", "")) != str(expected_phone_case_target.get("technology", "")):
			return _failure("This Phone Case project is no longer the next valid case unlock.")
	elif component == "Protection Glass":
		var expected_protection_glass_target := get_protection_glass_research_target(component_levels)
		protection_glass_target_index = int(project.get("research_target_index", -1))
		if expected_protection_glass_target.is_empty() or protection_glass_target_index != int(expected_protection_glass_target.get("index", -1)) or str(project.get("research_target", "")) != str(expected_protection_glass_target.get("technology", "")):
			return _failure("This Protection Glass project is no longer the next valid glass unlock.")
	elif PHONE_SENSOR_COMPONENTS.has(component):
		phone_sensor_target_index = int(project.get("research_target_index", -1))
		if int(component_levels.get(component, 0)) >= 1 or phone_sensor_target_index != 1 or str(project.get("research_target", "")) != component:
			return _failure("This sensor project is no longer a valid, unapproved sensor research target.")
	elif SIDE_BUTTON_COMPONENTS.has(component):
		side_button_target_index = int(project.get("research_target_index", -1))
		if int(component_levels.get(component, 0)) >= 1 or side_button_target_index != 1 or str(project.get("research_target", "")) != component:
			return _failure("This side-button feature is no longer a valid, unapproved research target.")
	elif component == POWER_VOLUME_BUTTON_LENGTH_COMPONENT:
		var expected_length_target := get_power_volume_button_length_research_target(component_levels)
		power_volume_button_length_target_index = int(project.get("research_target_index", -1))
		if expected_length_target.is_empty() or power_volume_button_length_target_index != int(expected_length_target.get("index", -1)) or str(project.get("research_target", "")) != str(expected_length_target.get("technology", "")):
			return _failure("This Power/Volume Button Length project is no longer the next valid reduction tier.")
	elif POWER_VOLUME_BUTTON_POSITION_COMPONENTS.has(component):
		power_volume_button_position_target_index = int(project.get("research_target_index", -1))
		if int(component_levels.get(component, 0)) >= 1 or power_volume_button_position_target_index != 1 or str(project.get("research_target", "")) != "Left and Top positions":
			return _failure("This button-position project is no longer a valid, unapproved placement unlock.")

	if results.is_empty():
		return _failure("Add at least one validated technology result before approving.")

	var project_components: Array = project.get("components", [])
	var technologies: Dictionary = career.get("research_technologies", {})
	var approved_results: Array = []
	for result_value in results:
		if not (result_value is Dictionary):
			return _failure("Every research result must be a structured technology record.")
		var result: Dictionary = result_value.duplicate(true)
		var result_component := normalize_component(str(result.get("component", "")))
		var metric := str(result.get("metric", "")).strip_edges()
		var value := str(result.get("value", "")).strip_edges()
		if result_component.is_empty() or not project_components.has(result_component):
			return _failure("Each result must refer to the component included in this project.")
		if metric.is_empty() or value.is_empty():
			return _failure("Each approved finding must include a measured attribute and result value.")
		if result_component == "Mobile Network" and value != str(project.get("research_target", "")):
			return _failure("Validate the exact Mobile Network technology assigned to this project.")
		if result_component == "Wi-Fi" and value != str(project.get("research_target", "")):
			return _failure("Validate the exact Wi-Fi IEEE standard assigned to this project.")
		if result_component == "Bluetooth" and value != str(project.get("research_target", "")):
			return _failure("Validate the exact Bluetooth version assigned to this project.")
		if result_component == "Cooling System Design" and value != str(project.get("research_target", "")):
			return _failure("Validate the exact heat-removal option assigned to this project.")
		if result_component == "Phone Type" and value != str(project.get("research_target", "")):
			return _failure("Validate the exact phone chassis type assigned to this project.")
		if result_component == "Battery Capacity" and value != str(project.get("research_target", "")):
			return _failure("Validate the exact next battery capacity ceiling assigned to this project.")
		if result_component == "Charger" and value != str(project.get("research_target", "")):
			return _failure("Validate the exact Charger adapter, cable or output-power target assigned to this project.")
		if result_component == "Power Bank" and value != str(project.get("research_target", "")):
			return _failure("Validate the exact next Power Bank unlock or capacity ceiling assigned to this project.")
		if result_component == "Charging Speed" and value != str(project.get("research_target", "")):
			return _failure("Validate the exact next wired charging-speed ceiling assigned to this project.")
		if result_component == "Wireless Charging" and value != str(project.get("research_target", "")):
			return _failure("Validate the exact next wireless charging-speed ceiling assigned to this project.")
		if result_component == "Front Camera MP" and value != str(project.get("research_target", "")):
			return _failure("Validate the exact next front-camera resolution ceiling assigned to this project.")
		if result_component == "Rear Camera MP" and value != str(project.get("research_target", "")):
			return _failure("Validate the exact next rear-camera resolution ceiling assigned to this project.")
		if result_component in ["Rear Camera Count", "Rear Flash Count"] and value != str(project.get("research_target", "")):
			return _failure("Validate the exact next rear-hardware addition capacity assigned to this project.")
		if result_component == "Back Raised Design" and value != str(project.get("research_target", "")):
			return _failure("Validate the exact next raised back-design box capacity assigned to this project.")
		if result_component in ["Device Color", "Smartwatch", "Wireless Earbuds"] and value != str(project.get("research_target", "")):
			return _failure("Validate the exact gradient-finish unlock assigned to this project.")
		if result_component == "Box Package" and value != str(project.get("research_target", "")):
			return _failure("Validate the exact Box Package unlock assigned to this project.")
		if result_component in ["Phone Case", "Protection Glass"] and value != str(project.get("research_target", "")):
			return _failure("Validate the exact fitted glass or case unlock assigned to this project.")
		if PHONE_SENSOR_COMPONENTS.has(result_component) and value != str(project.get("research_target", "")):
			return _failure("Validate the exact sensor component assigned to this project.")
		if SIDE_BUTTON_COMPONENTS.has(result_component) and value != str(project.get("research_target", "")):
			return _failure("Validate the exact side-button feature assigned to this project.")
		if result_component == POWER_VOLUME_BUTTON_LENGTH_COMPONENT and value != str(project.get("research_target", "")):
			return _failure("Validate the exact next button-length reduction tier assigned to this project.")
		if POWER_VOLUME_BUTTON_POSITION_COMPONENTS.has(result_component) and value != str(project.get("research_target", "")):
			return _failure("Validate the left and top placement unlock for the assigned button.")
		var component_history: Array = technologies.get(result_component, [])
		component_history.append(result)
		technologies[result_component] = component_history
		approved_results.append(result)

	project["status"] = STATUS_APPROVED
	project["approved_at_unix"] = game_time_unix
	project["approved_results"] = approved_results
	if component in ["Phone Thickness", "Border Radius"]:
		component_levels[component] = mini(20, int(component_levels.get(component, 0)) + 1)
	elif component == "Speakers":
		component_levels[component] = mini(11, int(component_levels.get(component, 0)) + 1)
	elif component == POWER_VOLUME_BUTTON_LENGTH_COMPONENT:
		component_levels[component] = power_volume_button_length_target_index
	elif component == "Charge Port":
		# The first port is the baseline; each approval unlocks the next port.
		component_levels[component] = mini(4, int(component_levels.get(component, 0)) + 1)
	elif component == "Home Button":
		# Circle is the baseline; each approval unlocks the next home-button design.
		component_levels[component] = mini(4, int(component_levels.get(component, 0)) + 1)
	elif component == "Screen Technology":
		# TFT LCD is the baseline; each approval unlocks the next listed display technology.
		component_levels[component] = mini(
			ScreenTechnologySystem.TECHNOLOGY_NAMES.size() - 1,
			int(component_levels.get(component, 0)) + 1
		)
	elif component == "Screen Width":
		# Each approval expands the maximum selectable display width by one tier.
		component_levels[component] = mini(SCREEN_WIDTH_RESEARCH_LEVELS, int(component_levels.get(component, 0)) + 1)
	elif component == "Screen Height":
		# Each approval expands the maximum selectable display height by one tier.
		component_levels[component] = mini(SCREEN_HEIGHT_RESEARCH_LEVELS, int(component_levels.get(component, 0)) + 1)
	elif component == "Refresh Rate":
		# Thirty approvals expand the selectable refresh-rate ceiling from 60 Hz to 300 Hz.
		component_levels[component] = mini(REFRESH_RATE_RESEARCH_LEVELS, int(component_levels.get(component, 0)) + 1)
	elif component == "Memory Clock":
		# Each approved project unlocks the next step on the shared 120-level speed ladder.
		component_levels[component] = mini(MEMORY_CLOCK_MAX_RESEARCH_LEVEL, int(component_levels.get(component, 0)) + 1)
	elif component == "Front Camera":
		# Bezel Camera is the baseline; each approval unlocks the next design in chronological order.
		component_levels[component] = mini(
			FRONT_CAMERA_MODEL_COUNT - 1,
			int(component_levels.get(component, 0)) + 1
		)
	elif component == "RAM":
		# 8 GB is the baseline ceiling; each approval unlocks the next supported capacity tier.
		component_levels[component] = mini(6, int(component_levels.get(component, 0)) + 1)
	elif component == "Internal Storage":
		# 2 GB is the baseline; each approval unlocks the next tier, up to 2 TB.
		component_levels[component] = mini(10, int(component_levels.get(component, 0)) + 1)
	elif component == "RAM Technology":
		# LPDDR2 is the baseline; six approvals unlock the remaining six RAM generations.
		component_levels[component] = mini(6, int(component_levels.get(component, 0)) + 1)
	elif component == "Mobile Network":
		# Each approved project unlocks exactly the next technology in the generation sequence.
		component_levels[component] = mobile_network_target_index
	elif component == "Wi-Fi":
		# Wi-Fi 1 is the starting baseline; each approval unlocks the next Wi-Fi generation.
		component_levels[component] = wifi_target_index
	elif component == "Bluetooth":
		# Bluetooth 1.0b is the baseline; each approval unlocks the next Core Specification version.
		component_levels[component] = bluetooth_target_index
	elif component == "Cooling System Design":
		# No Dedicated Cooling is the baseline; each approval unlocks the next heat-removal option.
		component_levels[component] = cooling_system_target_index
	elif component == "Phone Type":
		# Standard is the baseline; research unlocks Flip, then Fold.
		component_levels[component] = phone_type_target_index
	elif component == "Battery Capacity":
		# Level 1 is the 1,000 mAh starting state; 20 approved upgrades reach 8,000 mAh at Level 21.
		component_levels[component] = mini(BATTERY_CAPACITY_RESEARCH_UPGRADES, int(component_levels.get(component, 0)) + 1)
	elif component == "Charger":
		# Level 1 unlocks the adapter, Level 2 unlocks the cable, and 66 further approvals reach 200W.
		component_levels[component] = charger_target_index
	elif component == "Power Bank":
		# The first approval unlocks 5,000 mAh; 200 capacity approvals reach 25,000 mAh.
		component_levels[component] = power_bank_target_index
	elif component == "Charging Speed":
		# Level 1 starts at 1W; 66 approved upgrades reach 200W at Level 67.
		component_levels[component] = mini(CHARGING_SPEED_RESEARCH_UPGRADES, int(component_levels.get(component, 0)) + 1)
	elif component == "Wireless Charging":
		# The first approval unlocks wireless charging at 1W; 66 further upgrades reach 200W.
		component_levels[component] = wireless_charging_target_index
	elif component == "Front Camera MP":
		# The 1MP baseline is available by default; 60 approvals raise the ceiling to 300MP.
		component_levels[component] = mini(FRONT_CAMERA_MP_RESEARCH_UPGRADES, int(component_levels.get(component, 0)) + 1)
	elif component == "Rear Camera MP":
		# The 1MP baseline is available by default; 80 approvals raise the ceiling to 400MP.
		component_levels[component] = mini(REAR_CAMERA_MP_RESEARCH_UPGRADES, int(component_levels.get(component, 0)) + 1)
	elif component == "Rear Camera Count":
		# One camera is available by default; four separate approvals unlock up to five.
		component_levels[component] = rear_camera_count_target_index
	elif component == "Rear Flash Count":
		# One flash is available by default; four separate approvals unlock up to five.
		component_levels[component] = rear_flash_count_target_index
	elif component == "Back Raised Design":
		# Level 1 unlocks the first raised box; each approval adds one, up to twenty.
		component_levels[component] = back_raised_design_target_index
	elif component == "Smartwatch":
		# One approved project unlocks the Smartwatch worksite controls.
		component_levels[component] = 1
	elif component == "Wireless Earbuds":
		# One approved project unlocks the Wireless Earbuds worksite controls.
		component_levels[component] = 1
	elif component == "Box Package":
		# One approved project unlocks all Box Package worksite customization controls.
		component_levels[component] = 1
	elif component == "Device Color":
		# Solid colour is the default; one approved project unlocks gradient finishes.
		component_levels[component] = device_color_target_index
	elif component == "Phone Case":
		# Smooth case enablement is the first unlock, followed by four designs and gradient finish.
		component_levels[component] = phone_case_target_index
	elif component == "Protection Glass":
		# Normal Glass is the first unlock; Privacy Glass is the second and final type.
		component_levels[component] = protection_glass_target_index
	elif PHONE_SENSOR_COMPONENTS.has(component):
		# Every sensor is an independent, one-time approved research unlock.
		component_levels[component] = 1
	elif SIDE_BUTTON_COMPONENTS.has(component):
		# Each optional side feature is unlocked by its own approved research project.
		component_levels[component] = side_button_target_index
	elif POWER_VOLUME_BUTTON_POSITION_COMPONENTS.has(component):
		# Right-edge placement is the baseline; approval unlocks left and top edges.
		component_levels[component] = power_volume_button_position_target_index
	elif CURVED_SCREEN_RESEARCH_COMPONENTS.has(component):
		# Each curved-screen design is a separate one-time approved research unlock.
		component_levels[component] = 1
	career["research_component_levels"] = component_levels
	projects[project_index] = project
	career["research_projects"] = projects
	career["research_technologies"] = technologies
	return {"ok": true, "project": project.duplicate(true)}


static func reject_project(career: Dictionary, project_id: String, review_note: String) -> Dictionary:
	ensure_state(career)
	var projects: Array = career.get("research_projects", [])
	var project_index := _find_project_index(projects, project_id)
	if project_index < 0:
		return _failure("Research project not found.")
	var project: Dictionary = projects[project_index]
	if str(project.get("status", "")) != STATUS_AWAITING_VALIDATION:
		return _failure("Only completed projects awaiting validation can be rejected.")
	project["status"] = STATUS_REJECTED
	project["review_note"] = review_note.strip_edges()
	projects[project_index] = project
	career["research_projects"] = projects
	return {"ok": true, "project": project.duplicate(true)}


static func _get_active_project_staff_ids(career: Dictionary) -> Array[String]:
	var occupied_ids: Array[String] = []
	for project_value in career.get("research_projects", []):
		if not (project_value is Dictionary):
			continue
		var project: Dictionary = project_value
		if str(project.get("status", "")) != STATUS_ACTIVE:
			continue
		for staff_value in project.get("staff_ids", []):
			var staff_id := str(staff_value)
			if not staff_id.is_empty() and not occupied_ids.has(staff_id):
				occupied_ids.append(staff_id)
	return occupied_ids


static func _find_employee(career: Dictionary, employee_id: String) -> Dictionary:
	for employee_value in career.get("staff_employees", []):
		if not (employee_value is Dictionary):
			continue
		var employee: Dictionary = employee_value
		if str(employee.get("id", "")) == employee_id:
			return employee
	return {}


static func _find_project_index(projects: Array, project_id: String) -> int:
	for index in range(projects.size()):
		var project_value: Variant = projects[index]
		if project_value is Dictionary and str(project_value.get("id", "")) == project_id:
			return index
	return -1


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
