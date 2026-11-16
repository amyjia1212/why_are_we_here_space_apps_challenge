# ship_task.gd
# A small hands-on job at a ship station (UPGRADE_PLAN_V6 C5), 5 to 10 seconds:
#   "swap" (Air): drag the dirty filter into the bin, then the clean one into the slot.
#   "fill" (Water): hold the mouse on the valve; let go when the gauge is in the green.
#   "eat"  (Food): click the pouch to add water, then click it again to eat.
# It sits on top of the ship; the trip waits while it is open. Emits done.
# Numbers: minigames.json "ship_tasks". Words: story.json "ship_tasks".
extends Control

signal done

var mode: String = "swap"
var settings: Dictionary
var words: Dictionary
var board: Control
var step: int = 0             # how far the job is
var dragging: String = ""     # "old" / "new" while dragging a filter
var drag_pos := Vector2.ZERO
var gauge: float = 0.0
var holding: bool = false
var hint_label: Label
var finished: bool = false


func setup(job: String) -> void:
	mode = job


func _ready() -> void:
	settings = Data.minigames["ship_tasks"]
	words = Data.story["ship_tasks"][mode]
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # fill the screen (anchors alone left it 0 x 0)
	var dim := Panel.new()
	dim.theme_type_variation = &"DimBackground"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"NavyPanel"
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var title := Label.new()
	title.theme_type_variation = &"HeadingText"
	title.text = words["title"]
	column.add_child(title)
	hint_label = Label.new()
	hint_label.theme_type_variation = &"BodyText"
	column.add_child(hint_label)
	board = Control.new()
	board.custom_minimum_size = Vector2(560, 300)
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	column.add_child(board)
	show_hint()


func show_hint() -> void:
	hint_label.text = words["steps"][mini(step, words["steps"].size() - 1)]


func _process(delta: float) -> void:
	if mode == "fill" and holding and not finished:
		gauge += delta / float(settings["fill_seconds"])
		if gauge >= 1.0:
			gauge = 0.0   # too far: the tank overflows, start again
			holding = false
			hint_label.text = words["too_far"]
			AudioManager.play_sfx("bad")
	board.queue_redraw()


# Where things sit on the board.
func slot_rect() -> Rect2:
	return Rect2(60, 90, 140, 120)


func bin_rect() -> Rect2:
	return Rect2(380, 150, 120, 120)


func tray_rect() -> Rect2:
	return Rect2(380, 20, 120, 100)


func pouch_rect() -> Rect2:
	return Rect2(220, 60, 120, 180)


func valve_center() -> Vector2:
	return Vector2(160, 160)


func _on_board_input(event: InputEvent) -> void:
	if finished:
		return
	if event is InputEventMouseMotion:
		drag_pos = event.position
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	match mode:
		"swap":
			if event.pressed:
				if step == 0 and slot_rect().has_point(event.position):
					dragging = "old"
				elif step == 1 and tray_rect().has_point(event.position):
					dragging = "new"
				drag_pos = event.position
			elif dragging != "":
				if dragging == "old" and bin_rect().has_point(event.position):
					step = 1
					AudioManager.play_sfx("snap")
				elif dragging == "new" and slot_rect().has_point(event.position):
					step = 2
					finish()
				dragging = ""
				show_hint()
		"fill":
			if event.pressed and event.position.distance_to(valve_center()) < 70.0:
				holding = true
				hint_label.text = words["steps"][0]
			elif not event.pressed and holding:
				holding = false
				if gauge >= float(settings["green_start"]) and gauge <= float(settings["green_end"]):
					finish()
				else:
					hint_label.text = words["too_early"]
					gauge = 0.0
					AudioManager.play_sfx("cancel")
		"eat":
			if event.pressed and pouch_rect().has_point(event.position):
				step += 1
				AudioManager.play_sfx("snap" if step == 1 else "good")
				if step >= 2:
					finish()
				show_hint()


func finish() -> void:
	finished = true
	hint_label.text = words["done"]
	AudioManager.play_sfx("task_done")
	await get_tree().create_timer(float(settings["done_pause_seconds"])).timeout
	done.emit()


func _draw_board() -> void:
	var c := func(key: String) -> Color: return board.get_theme_color(key, &"Minigame")
	board.draw_rect(Rect2(Vector2.ZERO, board.size), c.call("panel_color").darkened(0.6))
	var font: Font = board.get_theme_default_font()
	var small: int = board.get_theme_font_size("font_size", &"SmallText")
	match mode:
		"swap":
			board.draw_rect(slot_rect(), c.call("panel_edge_color"), false, 4.0)
			board.draw_string(font, slot_rect().position + Vector2(0, -8), words["labels"][0], HORIZONTAL_ALIGNMENT_LEFT, -1, small, c.call("dim_text_color"))
			board.draw_rect(bin_rect(), c.call("dent_color"))
			board.draw_string(font, bin_rect().position + Vector2(0, -8), words["labels"][1], HORIZONTAL_ALIGNMENT_LEFT, -1, small, c.call("dim_text_color"))
			board.draw_string(font, tray_rect().position + Vector2(0, -6), words["labels"][2], HORIZONTAL_ALIGNMENT_LEFT, -1, small, c.call("dim_text_color"))
			var dirty := Color(0.45, 0.38, 0.28)
			var clean := Color(0.95, 0.97, 1.0)
			if step == 0:
				var r: Rect2 = slot_rect().grow(-10)
				if dragging == "old":
					r.position = drag_pos - r.size / 2.0
				draw_filter(r, dirty)
			if step >= 1:
				var r2: Rect2 = tray_rect().grow(-10) if step == 1 else slot_rect().grow(-10)
				if dragging == "new":
					r2.position = drag_pos - r2.size / 2.0
				draw_filter(r2, clean)
		"fill":
			var gauge_rect := Rect2(360, 30, 60, 240)
			board.draw_rect(gauge_rect, c.call("dent_color"))
			var g0: float = float(settings["green_start"])
			var g1: float = float(settings["green_end"])
			board.draw_rect(Rect2(gauge_rect.position.x, gauge_rect.end.y - gauge_rect.size.y * g1, gauge_rect.size.x, gauge_rect.size.y * (g1 - g0)), c.call("good_color"))
			board.draw_rect(Rect2(gauge_rect.position.x + 8, gauge_rect.end.y - gauge_rect.size.y * gauge, gauge_rect.size.x - 16, gauge_rect.size.y * gauge), Color(0.3, 0.6, 1.0, 0.85))
			board.draw_rect(gauge_rect, c.call("panel_edge_color"), false, 3.0)
			var v: Vector2 = valve_center()
			board.draw_circle(v, 64.0, c.call("bad_color"))
			var turn: float = gauge * TAU * 2.0
			for k in 4:
				var a: float = turn + k * PI / 2.0
				board.draw_line(v, v + Vector2(cos(a), sin(a)) * 58.0, c.call("panel_color"), 8.0)
			board.draw_circle(v, 14.0, c.call("panel_edge_color"))
			board.draw_string(font, Vector2(40, 280), words["labels"][0], HORIZONTAL_ALIGNMENT_LEFT, -1, small, c.call("dim_text_color"))
		"eat":
			var r3: Rect2 = pouch_rect()
			var full: float = 1.0 if step >= 1 else 0.35
			board.draw_rect(r3, Color(0.85, 0.85, 0.8))
			board.draw_rect(Rect2(r3.position.x + 10, r3.end.y - (r3.size.y - 20) * full - 10, r3.size.x - 20, (r3.size.y - 20) * full), Color(0.85, 0.55, 0.25))
			board.draw_rect(r3, c.call("panel_edge_color"), false, 3.0)
			board.draw_string(font, r3.position + Vector2(0, -8), words["labels"][0], HORIZONTAL_ALIGNMENT_LEFT, -1, small, c.call("dim_text_color"))


func draw_filter(r: Rect2, color: Color) -> void:
	board.draw_rect(r, color)
	for i in 6:
		var x: float = r.position.x + r.size.x * (i + 0.5) / 6.0
		board.draw_line(Vector2(x, r.position.y + 6), Vector2(x, r.end.y - 6), color.darkened(0.3), 3.0)
