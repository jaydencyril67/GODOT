extends Control

signal activated

const FINGERPRINT_ICON_PATH := "res://assets/lock-screen/aosp/SVG/ic_fingerprint.svg"

@onready var prompt_button: Button = $PromptButton
@onready var fingerprint_icon: TextureRect = $PromptButton/PromptRow/FingerprintIcon
@onready var prompt_label: Label = $PromptButton/PromptRow/PromptLabel


func _ready() -> void:
	prompt_button.pressed.connect(func(): activated.emit())


func configure(palette: Dictionary, label_text: String = "USE FINGERPRINT", icon_size: Vector2 = Vector2(19, 27), interactive: bool = false) -> void:
	fingerprint_icon.texture = load(FINGERPRINT_ICON_PATH) as Texture2D
	fingerprint_icon.modulate = palette.get("accent", Color.WHITE)
	fingerprint_icon.custom_minimum_size = icon_size
	prompt_label.text = label_text
	prompt_label.add_theme_color_override("font_color", palette.get("muted", Color.WHITE))
	prompt_button.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	prompt_label.visible = not label_text.is_empty()
