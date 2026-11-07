extends RefCounted

const QUALITY_ORDER := ["darkness", "shininess", "reflection_reduction"]
const TECHNOLOGY_NAMES := [
	"TFT LCD", "LED-LCD", "IPS LCD", "Mini-LED LCD", "OLED",
	"AMOLED", "Super AMOLED", "Dynamic AMOLED", "LTPO AMOLED", "MicroLED"
]
const LEVELS_PER_MILESTONE := 3
const FINAL_TECHNOLOGY_MILESTONE := 38 # MicroLED Generation 30
const MAX_QUALITY_LEVEL := FINAL_TECHNOLOGY_MILESTONE * LEVELS_PER_MILESTONE


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
		state[quality] = clampi(int(state.get(quality, 0)), 0, MAX_QUALITY_LEVEL)
	state["next_quality_index"] = posmod(int(state.get("next_quality_index", 0)), QUALITY_ORDER.size())
	state["technology_milestone"] = clampi(int(state.get("technology_milestone", 0)), 0, FINAL_TECHNOLOGY_MILESTONE)


static func upgrade(state: Dictionary) -> Dictionary:
	ensure_state(state)
	if int(state["technology_milestone"]) >= FINAL_TECHNOLOGY_MILESTONE:
		return {
			"quality": "",
			"quality_level": MAX_QUALITY_LEVEL,
			"technology": get_technology_name(FINAL_TECHNOLOGY_MILESTONE),
			"technology_unlocked": false,
			"milestone": FINAL_TECHNOLOGY_MILESTONE,
			"completed": true
		}

	# Pick the next quality that has not reached its final level.
	var quality_index := int(state["next_quality_index"])
	for offset in range(QUALITY_ORDER.size()):
		var candidate_index := (quality_index + offset) % QUALITY_ORDER.size()
		var candidate_quality: String = QUALITY_ORDER[candidate_index]
		if int(state[candidate_quality]) < MAX_QUALITY_LEVEL:
			quality_index = candidate_index
			break

	var quality: String = QUALITY_ORDER[quality_index]
	state[quality] = mini(int(state[quality]) + 1, MAX_QUALITY_LEVEL)
	state["next_quality_index"] = (quality_index + 1) % QUALITY_ORDER.size()

	var previous_milestone := int(state["technology_milestone"])
	while int(state["technology_milestone"]) < FINAL_TECHNOLOGY_MILESTONE:
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

	var completed := int(state["technology_milestone"]) >= FINAL_TECHNOLOGY_MILESTONE
	return {
		"quality": quality,
		"quality_level": int(state[quality]),
		"technology": get_technology_name(int(state["technology_milestone"])),
		"technology_unlocked": int(state["technology_milestone"]) > previous_milestone,
		"milestone": int(state["technology_milestone"]),
		"completed": completed
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
	if int(state["technology_milestone"]) >= FINAL_TECHNOLOGY_MILESTONE:
		return MAX_QUALITY_LEVEL
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
	var darkness_level := mini(int(state["darkness"]), MAX_QUALITY_LEVEL)
	var shininess_level := mini(int(state["shininess"]), MAX_QUALITY_LEVEL)
	var reflection_level := mini(int(state["reflection_reduction"]), MAX_QUALITY_LEVEL)

	# Spread each visible improvement across the complete journey to MicroLED
	# Generation 30, so the final levels still have a meaningful visual target.
	var darkness_progress := float(darkness_level) / float(MAX_QUALITY_LEVEL)
	var shininess_progress := float(shininess_level) / float(MAX_QUALITY_LEVEL)
	var reflection_progress := float(reflection_level) / float(MAX_QUALITY_LEVEL)
	var screen_color := Color("#303030").lerp(Color("#080808"), darkness_progress)
	var screen_roughness := lerpf(0.27, 0.06, shininess_progress)
	var screen_metallic := lerpf(0.04, 0.82, shininess_progress)
	var screen_specular := lerpf(0.55, 0.0, reflection_progress)

	return {
		"albedo_color": screen_color,
		"roughness": screen_roughness,
		"metallic": screen_metallic,
		"specular": screen_specular
	}
