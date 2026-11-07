extends RefCounted
class_name ScreenTechnologySystem

const QUALITY_ORDER := ["darkness", "shininess", "reflection_reduction"]
const TECHNOLOGY_NAMES := [
	"TFT LCD", "LED-LCD", "IPS LCD", "Mini-LED LCD", "OLED",
	"AMOLED", "Super AMOLED", "Dynamic AMOLED", "LTPO AMOLED", "MicroLED"
]
const LEVELS_PER_MILESTONE := 3


static func create_state() -> Dictionary:
	return {
		"darkness": 0,
		"shininess": 0,
		"reflection_reduction": 0,
		"next_quality_index": 0,
		"technology_milestone": 0
	}


static func ensure_state(state: Dictionary) -> void:
	for quality in QUALITY_ORDER:
		state[quality] = maxi(0, int(state.get(quality, 0)))
	state["next_quality_index"] = posmod(int(state.get("next_quality_index", 0)), QUALITY_ORDER.size())
	state["technology_milestone"] = maxi(0, int(state.get("technology_milestone", 0)))


static func upgrade(state: Dictionary) -> Dictionary:
	ensure_state(state)
	var quality_index := int(state["next_quality_index"])
	var quality: String = QUALITY_ORDER[quality_index]
	state[quality] = int(state[quality]) + 1
	state["next_quality_index"] = (quality_index + 1) % QUALITY_ORDER.size()

	var previous_milestone := int(state["technology_milestone"])
	while true:
		var next_milestone := int(state["technology_milestone"]) + 1
		var required_level := next_milestone * LEVELS_PER_MILESTONE
		var all_qualities_ready := true
		for quality_name in QUALITY_ORDER:
			if int(state[quality_name]) < required_level:
				all_qualities_ready = false
				break
		if not all_qualities_ready:
			break
		state["technology_milestone"] = next_milestone

	return {
		"quality": quality,
		"quality_level": int(state[quality]),
		"technology": get_technology_name(int(state["technology_milestone"])),
		"technology_unlocked": int(state["technology_milestone"]) > previous_milestone,
		"milestone": int(state["technology_milestone"])
	}


static func get_technology_name(milestone_index: int) -> String:
	if milestone_index < TECHNOLOGY_NAMES.size():
		return TECHNOLOGY_NAMES[maxi(0, milestone_index)]
	var generation := milestone_index - TECHNOLOGY_NAMES.size() + 2
	return "MicroLED Generation %d" % generation


static func get_next_quality(state: Dictionary) -> String:
	ensure_state(state)
	return str(QUALITY_ORDER[int(state["next_quality_index"])])


static func get_next_milestone_requirement(state: Dictionary) -> int:
	ensure_state(state)
	return (int(state["technology_milestone"]) + 1) * LEVELS_PER_MILESTONE


static func get_quality_display_name(quality: String) -> String:
	match quality:
		"darkness":
			return "Darkness"
		"shininess":
			return "Shininess / Metallic Nature"
		"reflection_reduction":
			return "Reflection Reduction"
	return quality.capitalize()


static func get_visual_profile(state: Dictionary) -> Dictionary:
	ensure_state(state)
	var darkness_level := int(state["darkness"])
	var shininess_level := int(state["shininess"])
	var reflection_level := int(state["reflection_reduction"])

	# Each quality changes only its own visual property.
	var screen_color := Color("#303030") * pow(0.88, float(darkness_level))
	var screen_roughness := 0.04 + 0.24 * pow(0.90, float(shininess_level))
	var screen_metallic := 0.04 + 0.56 * (1.0 - pow(0.94, float(shininess_level)))
	var screen_specular := maxf(0.025, 0.90 * pow(0.88, float(reflection_level)))

	return {
		"albedo_color": screen_color,
		"roughness": screen_roughness,
		"metallic": screen_metallic,
		"metallic_specular": screen_specular
	}
