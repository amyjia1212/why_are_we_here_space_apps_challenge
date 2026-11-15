# drill_meter.gd
# The ice drill bar on the arrival screen. It fills from left to right
# while the player holds E. The green zone is where to let go.
# value: 0 = empty, 1 = full. Colors come from the theme ("DrillMeter").
extends Control

var value: float = 0.0
var green_start: float = 0.7
var green_end: float = 0.86


func setup(zone_start: float, zone_end: float) -> void:
	green_start = zone_start
	green_end = zone_end
	queue_redraw()


func set_value(new_value: float) -> void:
	value = clampf(new_value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var full := Rect2(Vector2.ZERO, size)
	draw_rect(full, get_theme_color("back_color", &"DrillMeter"))
	draw_rect(Rect2(size.x * green_start, 0, size.x * (green_end - green_start), size.y), get_theme_color("green_color", &"DrillMeter"))
	draw_rect(Rect2(0, size.y * 0.25, size.x * value, size.y * 0.5), get_theme_color("fill_color", &"DrillMeter"))
	draw_rect(full, get_theme_color("line_color", &"DrillMeter"), false, 3.0)
