# patch_maker.gd
# The mission patch maker (the "more stuff" list, 2026-11-14), between the
# mission briefing and the Design Room. Pick a shape, a color and an icon;
# the big patch on the left changes at once. The patch then flies on the
# rocket's logo panel, sits on the suit, and shows on the report and the
# leaderboard (patch_art.gd draws it everywhere).
# Choices: extras.json "patch". Words: story.json extras > patch.
extends Control

const PATCH_ART = preload("res://scripts/patch_art.gd")

var words: Dictionary
var settings: Dictionary
var preview: Control
var buttons: Dictionary = {}   # "shape:circle" -> Button


func _ready() -> void:
	words = Data.story["extras"]["patch"]
	settings = Data.extras["patch"]
	if GameState.patch.is_empty():
		GameState.patch = GameState.get_patch()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	build()
	refresh()


func build() -> void:
	var background := Panel.new()
	background.theme_type_variation = &"ScreenBackground"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 70)   # under the Hud's hint bar
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var title := Label.new()
	title.theme_type_variation = &"TitleText"
	title.text = words["title"]
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.theme_type_variation = &"BodyText"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.text = words["subtitle"]
	column.add_child(subtitle)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 48)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	preview = PATCH_ART.new()
	var pixels: float = settings["preview_pixels"]
	preview.custom_minimum_size = Vector2(pixels, pixels)
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(preview)

	var choices := VBoxContainer.new()
	choices.add_theme_constant_override("separation", 12)
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(choices)
	add_choice_row(choices, "shape", words["shape_title"], settings["shapes"])
	add_choice_row(choices, "color", words["color_title"], range(settings["colors"].size()))
	add_choice_row(choices, "icon", words["icon_title"], settings["icons"])
	var where := Label.new()
	where.theme_type_variation = &"SmallText"
	where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	where.text = words["where"]
	choices.add_child(where)
	var next := Button.new()
	next.text = words["next"]
	next.custom_minimum_size = Vector2(320, 64)
	next.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	next.pressed.connect(_on_next_pressed)
	choices.add_child(next)


func add_choice_row(parent: Control, key: String, heading: String, values: Array) -> void:
	var label := Label.new()
	label.theme_type_variation = &"AccentText"
	label.text = heading
	parent.add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	for value in values:
		var button := Button.new()
		button.theme_type_variation = &"SmallButton"
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(120, 52)
		if key == "color":
			# A color swatch: the button is filled with that color.
			var style := StyleBoxFlat.new()
			style.bg_color = Color(settings["colors"][value])
			style.set_corner_radius_all(8)
			for state in ["normal", "hover", "pressed", "hover_pressed"]:
				button.add_theme_stylebox_override(state, style)
			button.custom_minimum_size = Vector2(64, 52)
		else:
			button.text = words[key + "s"][value]
		button.pressed.connect(_on_choice.bind(key, value))
		row.add_child(button)
		buttons[key + ":" + str(value)] = button


func _on_choice(key: String, value) -> void:
	AudioManager.play_sfx("preview")
	GameState.patch[key] = value
	refresh()


func refresh() -> void:
	var patch: Dictionary = GameState.get_patch()
	for id in buttons:
		var parts: PackedStringArray = id.split(":")
		var current = patch.get(parts[0], "")
		if parts[0] == "color":
			current = int(current)   # a saved patch can bring the number back as 1.0
		var on: bool = str(current) == parts[1]
		buttons[id].button_pressed = on
		if parts[0] == "color":
			buttons[id].text = "X" if on else ""   # the picked color gets a mark
	preview.queue_redraw()


func _on_next_pressed() -> void:
	AudioManager.play_sfx("confirm")
	StageManager.go_next()
