# ui_kit.gd
# Small shared helpers for the look of the game (UI_POLISH_PLAN_V4).
#     const UI = preload("res://scripts/ui_kit.gd")
#
# Every size and color still comes from theme/game_theme.tres. This file only
# builds things out of the theme's pieces, and holds the ONE motion helper
# (Step 4) so every screen moves the same way.
#
#   UI.wall_theme(factor)        the project theme, scaled up for a screen inside the 3D world
#   UI.fade_in(node)             fade + slide in (0.18 s)
#   UI.fade_out(node, hide)      fade + slide out (0.15 s)
#   UI.count_to(label, a, b, fmt) a number counts from a to b (0.3 s)
#   UI.add_hover(control)        grows very slightly on hover, dips when pressed
#   UI.chip(text)                a small stat chip ("$ 80", "kg 4020")
extends RefCounted

const IN_SECONDS := 0.18
const OUT_SECONDS := 0.15
const SLIDE_PIXELS := 12.0
const COUNT_SECONDS := 0.3
const HOVER_SCALE := 1.03
const PRESS_SCALE := 0.97

static var _wall_themes: Dictionary = {}


# A copy of the game theme with every font size, padding, corner and gap
# multiplied by factor. Screens drawn inside the 3D world (the Design Lab wall,
# the Bridge screen, Mission School) are seen from far away, so they need it.
static func wall_theme(factor: float) -> Theme:
	var key := snappedf(factor, 0.01)
	if _wall_themes.has(key):
		return _wall_themes[key]
	var theme: Theme = ThemeDB.get_project_theme().duplicate(true)
	theme.default_font_size = int(round(theme.default_font_size * factor))
	for type in theme.get_font_size_type_list():
		for item in theme.get_font_size_list(type):
			theme.set_font_size(item, type, int(round(theme.get_font_size(item, type) * factor)))
	for type in theme.get_constant_type_list():
		if type == "Status":
			continue
		for item in theme.get_constant_list(type):
			theme.set_constant(item, type, int(round(theme.get_constant(item, type) * factor)))
	for type in theme.get_stylebox_type_list():
		for item in theme.get_stylebox_list(type):
			var box: StyleBox = theme.get_stylebox(item, type)
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				box.set_content_margin(side, box.get_content_margin(side) * factor)
			if box is StyleBoxFlat:
				var flat := box as StyleBoxFlat
				flat.set_corner_radius_all(int(round(flat.corner_radius_top_left * factor)))
				flat.shadow_size = int(round(flat.shadow_size * factor))
				flat.shadow_offset *= factor
				for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
					flat.set_border_width(side, int(round(flat.get_border_width(side) * factor)))
	_wall_themes[key] = theme
	return theme


# ---------- soft motion (Step 4): gentle, never longer than 0.3 s ----------

static func fade_in(node: CanvasItem, from_offset: Vector2 = Vector2(0, SLIDE_PIXELS)) -> void:
	if node == null or not node.is_inside_tree():
		return
	node.visible = true
	node.modulate.a = 0.0
	var tween := node.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(node, "modulate:a", 1.0, IN_SECONDS)
	if node is Control and from_offset != Vector2.ZERO:
		var control := node as Control
		# Slide the drawing only (not the layout), so containers never jump.
		var end := control.position
		control.position = end + from_offset
		tween.tween_property(control, "position", end, IN_SECONDS)


static func fade_out(node: CanvasItem, then_hide: bool = true, to_offset: Vector2 = Vector2(0, SLIDE_PIXELS)) -> void:
	if node == null or not node.is_inside_tree() or not node.visible:
		return
	var tween := node.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(node, "modulate:a", 0.0, OUT_SECONDS)
	if node is Control and to_offset != Vector2.ZERO:
		var control := node as Control
		var start := control.position
		tween.tween_property(control, "position", start + to_offset, OUT_SECONDS)
		tween.chain().tween_callback(func(): control.position = start)
	if then_hide:
		tween.chain().tween_callback(func():
			node.visible = false
			node.modulate.a = 1.0)


# A number on a label counts from one value to the next instead of jumping.
# fmt turns the number into text (default: whole numbers).
static func count_to(label: Control, from_value: float, to_value: float, fmt: Callable = Callable()) -> void:
	if label == null or not label.is_inside_tree():
		return
	var show := func(v: float) -> void:
		label.set("text", fmt.call(v) if fmt.is_valid() else str(int(round(v))))
	if is_equal_approx(from_value, to_value):
		show.call(to_value)
		return
	show.call(from_value)
	var tween := label.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(show, from_value, to_value, COUNT_SECONDS)


# Buttons and cards grow a tiny bit on hover and dip when pressed.
static func add_hover(control: Control) -> void:
	if control == null or control.has_meta("ui_hover"):
		return
	control.set_meta("ui_hover", true)
	var set_scale := func(target: float) -> void:
		if not control.is_inside_tree():
			return
		control.pivot_offset = control.size / 2.0
		var tween := control.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(control, "scale", Vector2.ONE * target, 0.12)
	control.mouse_entered.connect(func(): set_scale.call(HOVER_SCALE))
	control.mouse_exited.connect(func(): set_scale.call(1.0))
	control.focus_entered.connect(func(): set_scale.call(HOVER_SCALE))
	control.focus_exited.connect(func(): set_scale.call(1.0))
	if control is BaseButton:
		(control as BaseButton).button_down.connect(func(): set_scale.call(PRESS_SCALE))
		(control as BaseButton).button_up.connect(func(): set_scale.call(HOVER_SCALE))


# ---------- small building blocks ----------

# A stat chip: "kg 4020". The first word is the icon (a short unit), the rest is the value.
static func chip(text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ChipPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.theme_type_variation = &"ChipText"
	label.text = text
	panel.add_child(label)
	return panel


static func label(text: String, style: StringName, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = style
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
