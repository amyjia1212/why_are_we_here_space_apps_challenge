# valve_dial.gd
# The fuel valve for Build job 3 (Fueling), polished at UPGRADE_PLAN_V2 step 20.
# A red valve wheel with spokes and a white knob on its rim. Drag the knob
# around (counterclockwise from Start, which is on the right, at 0 degrees)
# and let go: the dial sends "released" with the angle. The wheel turns with
# the knob, a fuel gauge on the right fills as you turn (a full turn = full),
# and an orange mark on the dial and on the gauge shows the target.
# Colors from the theme ("Minigame" and the text styles).
extends Control

const FRAME = preload("res://scripts/minigame_frame.gd")   # the shared wheel drawing

signal released(angle: float)

var radius: float = 150.0
var handle_radius: float = 22.0
var show_live_angle: bool = false
var input_enabled: bool = false

var angle: float = 0.0        # degrees, counterclockwise from Start
var target: float = -1.0      # the target angle (the orange mark); -1 = no mark
var dragging: bool = false
var last_click_angle: float = 0.0

const TICK_ANGLES := [0, 90, 180, 270]
const TICK_LENGTH := 14.0
const LABEL_GAP := 40.0       # how far outside the circle the tick labels sit
const GAUGE_SPACE := 130.0    # room on the right for the fuel gauge
const GAUGE_WIDTH := 44.0


func setup(dial_radius: float, handle: float, live: bool) -> void:
	radius = dial_radius
	handle_radius = handle
	show_live_angle = live
	var side: float = (radius + LABEL_GAP + handle_radius) * 2.0
	custom_minimum_size = Vector2(side + 80.0 + GAUGE_SPACE, side)   # a bit wider for "Start" and the gauge
	queue_redraw()


func reset() -> void:
	angle = 0.0
	dragging = false
	queue_redraw()


func set_target(degrees: float) -> void:
	target = degrees
	queue_redraw()


func get_center() -> Vector2:
	return Vector2((size.x - GAUGE_SPACE) / 2.0, size.y / 2.0)


# Where the knob is on the screen. Screen y goes DOWN, so "up" is -sin.
func get_handle_position() -> Vector2:
	var radians: float = deg_to_rad(angle)
	return get_center() + Vector2(cos(radians), -sin(radians)) * radius


func _gui_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Grab only near the knob (a little bigger than it, to be kind).
			if event.position.distance_to(get_handle_position()) <= handle_radius * 1.8:
				dragging = true
		elif dragging:
			dragging = false
			released.emit(angle)
	elif event is InputEventMouseMotion and dragging:
		var offset: Vector2 = event.position - get_center()
		angle = fposmod(rad_to_deg(atan2(-offset.y, offset.x)), 360.0)
		# A squeak every 30 degrees, like a real valve turning.
		if absf(angle - last_click_angle) >= 30.0:
			last_click_angle = angle
			AudioManager.play_sfx("valve")
		queue_redraw()


func _draw() -> void:
	var center: Vector2 = get_center()
	var ring_color: Color = get_theme_color("font_color", &"SmallText")
	var accent: Color = get_theme_color("target_color", &"Minigame")
	var text_color: Color = get_theme_color("font_color", &"Label")
	var font: Font = get_theme_default_font()
	var font_size: int = get_theme_default_font_size()

	# The outer scale with ticks at 0, 90, 180, 270 degrees. 0 is labeled "Start".
	draw_arc(center, radius + TICK_LENGTH, 0.0, TAU, 96, ring_color, 2.0)
	for tick in TICK_ANGLES:
		var direction := Vector2(cos(deg_to_rad(tick)), -sin(deg_to_rad(tick)))
		draw_line(center + direction * (radius + 4.0), center + direction * (radius + TICK_LENGTH * 2.0), ring_color, 3.0)
		var label: String = Data.story["minigames"]["fuel"]["start_mark"] if tick == 0 else str(tick) + "°"
		var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var spot: Vector2 = center + direction * (radius + LABEL_GAP)
		if tick == 0:
			spot.x += text_size.x / 2.0 - 10.0   # push "Start" out to the right
		draw_string(font, spot + Vector2(-text_size.x / 2.0, text_size.y / 3.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ring_color)

	# How far the valve is turned: a thin colored arc from Start (screen angles go clockwise).
	if angle > 0.5:
		draw_arc(center, radius + TICK_LENGTH, -deg_to_rad(angle), 0.0, 96, get_theme_color("fuel_color", &"Minigame"), 6.0)

	# The wheel itself, turned to the knob's angle, with the target mark.
	FRAME.draw_wheel(self, center, radius, angle, target)
	draw_circle(get_handle_position(), handle_radius, text_color)

	# The fuel gauge on the right: fills as the valve turns, orange line = target.
	var gauge := Rect2(Vector2(size.x - GAUGE_SPACE + (GAUGE_SPACE - GAUGE_WIDTH) / 2.0, center.y - radius), Vector2(GAUGE_WIDTH, radius * 2.0))
	draw_rect(gauge, get_theme_color("gauge_back_color", &"Minigame"))
	var fill: float = gauge.size.y * angle / 360.0
	draw_rect(Rect2(gauge.position.x, gauge.end.y - fill, gauge.size.x, fill), get_theme_color("fuel_color", &"Minigame"))
	draw_rect(gauge, ring_color, false, 2.0)
	if target >= 0.0:
		var mark_y: float = gauge.end.y - gauge.size.y * target / 360.0
		draw_line(Vector2(gauge.position.x - 12.0, mark_y), Vector2(gauge.end.x + 12.0, mark_y), accent, 5.0)
	var gauge_word: String = Data.story["minigames"]["fuel"]["gauge"]
	var word_size: Vector2 = font.get_string_size(gauge_word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, Vector2(gauge.get_center().x - word_size.x / 2.0, gauge.end.y + word_size.y), gauge_word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ring_color)

	if show_live_angle:
		var live_text: String = Data.story["minigames"]["fuel"]["live_angle"].format({"angle": int(round(angle))})
		var live_size: Vector2 = font.get_string_size(live_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, center + Vector2(-live_size.x / 2.0, radius / 2.0), live_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
