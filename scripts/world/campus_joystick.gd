extends Control

signal vector_changed(value: Vector2)

const OUTER_RADIUS := 94.0
const KNOB_RADIUS := 44.2
const TRAVEL_RADIUS := 48.0

var _value := Vector2.ZERO
var _knob_offset := Vector2.ZERO
var _active_touch_index := -1
var _mouse_active := false


func _ready() -> void:
	custom_minimum_size = Vector2(196.0, 196.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func get_value() -> Vector2:
	return _value


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _active_touch_index == -1:
			_active_touch_index = event.index
			_update_from_point(event.position)
			accept_event()
		elif not event.pressed and event.index == _active_touch_index:
			_active_touch_index = -1
			_release()
			accept_event()
	elif event is InputEventScreenDrag and event.index == _active_touch_index:
		_update_from_point(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_active = event.pressed
		if _mouse_active:
			_update_from_point(event.position)
		else:
			_release()
		accept_event()
	elif event is InputEventMouseMotion and _mouse_active:
		_update_from_point(event.position)
		accept_event()


func _update_from_point(point: Vector2) -> void:
	var offset := (point - size * 0.5).limit_length(TRAVEL_RADIUS)
	_knob_offset = offset
	_value = Vector2(offset.x / TRAVEL_RADIUS, -offset.y / TRAVEL_RADIUS).limit_length(1.0)
	vector_changed.emit(_value)
	queue_redraw()


func _release() -> void:
	_value = Vector2.ZERO
	_knob_offset = Vector2.ZERO
	vector_changed.emit(_value)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, OUTER_RADIUS, Color(0.025, 0.040, 0.035, 0.58))
	draw_arc(center, OUTER_RADIUS, 0.0, TAU, 80, Color(0.80, 0.86, 0.78, 0.52), 2.4, true)
	draw_circle(center, 69.0, Color(0.12, 0.17, 0.13, 0.24))
	draw_circle(center + _knob_offset, KNOB_RADIUS, Color(0.82, 0.86, 0.78, 0.94))
	draw_arc(center + _knob_offset, KNOB_RADIUS, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.82), 2.0, true)
	draw_string(ThemeDB.fallback_font, Vector2(center.x - 22.0, center.y + 78.0), "MOVE", HORIZONTAL_ALIGNMENT_CENTER, 44.0, 11, Color(0.92, 0.95, 0.89, 0.86))
