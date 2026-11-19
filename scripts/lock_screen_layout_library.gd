extends RefCounted

# Curated structural foundations. The designer owns layout and content variation;
# wallpaper selection is applied independently from layout generation.
const BLUEPRINTS := [
	{
		"id": "pixel_centered",
		"name": "PIXEL-CENTERED",
		"clock_rect": Rect2(0.08, 0.205, 0.30, 0.15),
		"date_rect": Rect2(0.12, 0.375, 0.76, 0.038),
		"date_alignments": ["center"],
		"content_slots": [
			{"type": "notification", "rect": Rect2(0.075, 0.46, 0.85, 0.085)},
			{"type": "media", "rect": Rect2(0.075, 0.57, 0.85, 0.15)}
		],
		"fingerprint": true
	},
	{
		"id": "one_ui_lower",
		"name": "ONE UI LOWER CLOCK",
		"clock_rect": Rect2(0.08, 0.265, 0.30, 0.15),
		"date_rect": Rect2(0.08, 0.215, 0.84, 0.032),
		"date_alignments": ["left"],
		"content_slots": [
			{"type": "notification", "rect": Rect2(0.075, 0.475, 0.85, 0.082)},
			{"type": "media", "rect": Rect2(0.075, 0.581, 0.85, 0.165)}
		],
		"fingerprint": false
	},
	{
		"id": "material_stack",
		"name": "MATERIAL STACK",
		"clock_rect": Rect2(0.08, 0.145, 0.30, 0.15),
		"date_rect": Rect2(0.08, 0.312, 0.84, 0.04),
		"date_alignments": ["left", "center"],
		"content_slots": [
			{"type": "notification", "rect": Rect2(0.075, 0.385, 0.85, 0.07)},
			{"type": "notification", "rect": Rect2(0.075, 0.475, 0.85, 0.07)},
			{"type": "media", "rect": Rect2(0.075, 0.565, 0.85, 0.18)}
		],
		"fingerprint": true
	},
	{
		"id": "media_stage",
		"name": "MEDIA STAGE",
		"clock_rect": Rect2(0.12, 0.14, 0.30, 0.15),
		"date_rect": Rect2(0.12, 0.365, 0.76, 0.035),
		"date_alignments": ["center"],
		"content_slots": [
			{"type": "notification", "rect": Rect2(0.075, 0.425, 0.85, 0.08)},
			{"type": "media", "rect": Rect2(0.075, 0.535, 0.85, 0.185)}
		],
		"fingerprint": true
	},
	{
		"id": "analog_classic",
		"name": "ANALOG CLASSIC",
		"clock_rect": Rect2(0.35, 0.175, 0.30, 0.15),
		"date_rect": Rect2(0.12, 0.365, 0.76, 0.038),
		"date_alignments": ["center"],
		"content_slots": [
			{"type": "notification", "rect": Rect2(0.075, 0.435, 0.85, 0.075)},
			{"type": "media", "rect": Rect2(0.075, 0.555, 0.85, 0.17)}
		],
		"fingerprint": true
	},
	{
		"id": "editorial_left",
		"name": "EDITORIAL LEFT",
		"clock_rect": Rect2(0.075, 0.205, 0.30, 0.15),
		"date_rect": Rect2(0.075, 0.375, 0.85, 0.04),
		"date_alignments": ["left"],
		"content_slots": [
			{"type": "notification", "rect": Rect2(0.075, 0.435, 0.85, 0.075)},
			{"type": "media", "rect": Rect2(0.075, 0.555, 0.85, 0.17)}
		],
		"fingerprint": true
	},
	{
		"id": "split_clock",
		"name": "SPLIT CLOCK",
		"clock_rect": Rect2(0.12, 0.14, 0.30, 0.15),
		"date_rect": Rect2(0.12, 0.375, 0.76, 0.035),
		"date_alignments": ["center"],
		"content_slots": [
			{"type": "notification", "rect": Rect2(0.075, 0.435, 0.85, 0.075)},
			{"type": "media", "rect": Rect2(0.075, 0.55, 0.85, 0.17)}
		],
		"fingerprint": true
	},
	{
		"id": "notification_rich",
		"name": "NOTIFICATION RICH",
		"clock_rect": Rect2(0.075, 0.13, 0.30, 0.15),
		"date_rect": Rect2(0.075, 0.30, 0.85, 0.04),
		"date_alignments": ["left", "center"],
		"content_slots": [
			{"type": "notification", "rect": Rect2(0.075, 0.395, 0.85, 0.082)},
			{"type": "notification", "rect": Rect2(0.075, 0.49, 0.85, 0.082)},
			{"type": "media", "rect": Rect2(0.075, 0.60, 0.85, 0.15)}
		],
		"fingerprint": true
	},
	{
		"id": "quiet_focus",
		"name": "QUIET FOCUS",
		"clock_rect": Rect2(0.12, 0.215, 0.30, 0.15),
		"date_rect": Rect2(0.12, 0.385, 0.76, 0.035),
		"date_alignments": ["center", "right"],
		"content_slots": [
			{"type": "notification", "rect": Rect2(0.075, 0.435, 0.85, 0.075)},
			{"type": "media", "rect": Rect2(0.075, 0.565, 0.85, 0.155)}
		],
		"fingerprint": true
	},
	{
		"id": "dual_content",
		"name": "DUAL CONTENT",
		"clock_rect": Rect2(0.075, 0.155, 0.30, 0.15),
		"date_rect": Rect2(0.075, 0.32, 0.85, 0.035),
		"date_alignments": ["left", "center"],
		"content_slots": [
			{"type": "notification", "rect": Rect2(0.075, 0.405, 0.85, 0.082)},
			{"type": "media", "rect": Rect2(0.075, 0.511, 0.85, 0.19)}
		],
		"fingerprint": false
	}
]


static func get_blueprints() -> Array:
	return BLUEPRINTS.duplicate(true)
