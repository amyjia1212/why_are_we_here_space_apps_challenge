# mission_briefing.gd
# The Mission Briefing (UPGRADE_PLAN_V3 B3): four short cards that type out
# one at a time, with the General's beep-talk voice.
#   1. Why we are going
#   2. What success looks like: the ConOps pictures, then the checklist by
#      phase, one line at a time
#   3. The big trade-off
#   4. Real missions like this one (+ an honest line: no astronaut has been
#      to Mars or Venus)
# Enter (or the button) once finishes the card; again goes to the next card.
# A small amber arrow marks the line being typed. Dots at the bottom show
# "Card 2 of 4". Key words are bold, and Q opens a card about each one.
# "What you start with" moved to Mission School (the next screen, B4).
# Words: story.json "briefing" (cards: missions_cards). The typing:
# typewriter_label.gd (the shared TypewriterLabel).
extends Control

const TYPEWRITER = preload("res://scripts/typewriter_label.gd")

var words: Dictionary
var cards_words: Dictionary   # story.json briefing > missions_cards > this mission
var key: String = ""
var card_index: int = 0
var lines: Array = []           # the lines of the card on screen (bbcode strings)
var line_index: int = -1
var current_line = null         # the TypewriterLabel typing now
var current_arrow: Label = null
var card_box: VBoxContainer
var line_parent: Container      # where the line rows go (a 2-column grid on the checklist card)
var card_title: Label
var dots_label: Label
var button: Button
var conops: Control
var leaving: bool = false


func _ready() -> void:
	if GameState.character_id == "":
		GameState.character_id = Data.game_data["setup"]["default_character"]
	if GameState.mission_id == "":
		GameState.mission_id = Data.missions.keys()[0]
	GameState.fill_default_choices()
	words = Data.story["briefing"]
	key = GameState.get_destination_key()
	cards_words = words["missions_cards"][key]
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	build_page()
	show_card(0)


func build_page() -> void:
	var place: Dictionary = Data.story["destinations"][key]
	var background := Panel.new()
	background.theme_type_variation = &"ScreenBackground"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 40
	center.offset_bottom = -20
	add_child(center)
	var paper := PanelContainer.new()
	paper.theme_type_variation = &"PaperPanel"
	paper.custom_minimum_size = Vector2(900, 520)
	center.add_child(paper)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	paper.add_child(column)

	add_label(column, words["folder_label"] + " · " + words["general_name"], &"PaperLabel")
	add_label(column, place["name"] + ": " + place["goal"], &"PaperTitle")
	card_title = add_label(column, "", &"PaperLabel")
	conops = Control.new()
	conops.custom_minimum_size = Vector2(0, 80)
	conops.draw.connect(_draw_conops.bind(conops))
	conops.visible = false
	column.add_child(conops)
	card_box = VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 4)
	card_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(card_box)

	var bottom := HBoxContainer.new()
	column.add_child(bottom)
	dots_label = add_label(bottom, "", &"PaperLabel")
	dots_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dots_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button = Button.new()
	button.custom_minimum_size = Vector2(240, 48)
	button.pressed.connect(advance)
	bottom.add_child(button)
	add_label(column, words["enter_hint"], &"PaperLabel")
	button.grab_focus()


# One card: its title, then its lines one at a time.
func show_card(index: int) -> void:
	card_index = index
	for child in card_box.get_children():
		child.queue_free()
	current_line = null
	current_arrow = null
	card_title.text = words["card_titles"][index]
	conops.visible = index == 1
	# The checklist card puts its 8 lines in two columns, so it fits the screen.
	line_parent = card_box
	if index == 1:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 24)
		grid.add_theme_constant_override("v_separation", 4)
		card_box.add_child(grid)
		line_parent = grid
	lines = card_lines(index)
	line_index = -1
	var marks: PackedStringArray = []
	for i in 4:
		marks.append("•" if i <= index else "·")
	dots_label.text = words["card_dots"].format({"n": index + 1, "total": 4}) + "   " + " ".join(marks)
	button.text = words["next"] if index == 3 else words["next_card"]
	next_line()


func card_lines(index: int) -> Array:
	match index:
		0:
			if Party.is_party():
				# A bigger crew: more problems, faster drain, more data (MULTIPLAYER_PLAN_V6 3a).
				return [cards_words["why"], Data.story["party"]["crew_line"].format({
					"n": Party.size(), "problems": GameState.fmt(Party.scale("ship_problems")),
					"drain": GameState.fmt(Party.scale("supply_drain")), "data": GameState.fmt(Party.scale("data_goal")),
				})]
			return [cards_words["why"]]
		1:
			# The checklist by phase, one line per phase.
			var result: Array = []
			var goal_words: Dictionary = Data.story["destinations"][key]["goals"]
			var phase_words: Dictionary = Data.story["checklist"]["phases"]
			for group in GameState.checklist_by_phase():
				var names: PackedStringArray = []
				for goal_id in group["ids"]:
					names.append(goal_words[goal_id])
				result.append("[b]" + phase_words.get(group["phase"], "") + ":[/b] " + " · ".join(names))
			return result
		2:
			return [cards_words["tradeoff"]]
	var real: Array = [cards_words["real"]]
	if str(cards_words.get("crew_note", "")) != "":
		real.append(cards_words["crew_note"])
	return real


# Type the next line of this card, with the amber arrow in front of it.
func next_line() -> void:
	if current_arrow != null:
		current_arrow.modulate.a = 0.0   # the arrow moves on to the new line
	line_index += 1
	if line_index >= lines.size():
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_parent.add_child(row)
	current_arrow = Label.new()
	current_arrow.text = ">"
	current_arrow.theme_type_variation = &"PaperTitle"
	current_arrow.add_theme_color_override("font_color", get_theme_color("font_color", &"AccentText"))
	row.add_child(current_arrow)
	current_line = TYPEWRITER.new()
	current_line.theme_type_variation = &"PaperRich"
	current_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(current_line)
	# The honest crew note is small print; the 8 checklist lines are smaller so
	# the card fits on the screen.
	# (Sizes come from the theme: PaperRich = body 18 for every line, UI_POLISH_PLAN_V4.)
	current_line.type_text(lines[line_index], "general")
	current_line.typed.connect(_on_line_typed, CONNECT_ONE_SHOT)


# A line finished: the next line of the same card starts by itself.
func _on_line_typed() -> void:
	if line_index + 1 < lines.size():
		await get_tree().create_timer(0.25).timeout
		if is_inside_tree() and line_index + 1 < lines.size() and current_line != null and not current_line.is_typing():
			next_line()


func card_done() -> bool:
	return line_index >= lines.size() - 1 and (current_line == null or not current_line.is_typing())


# Enter (or the button): finish the card first; then go to the next card.
func advance() -> void:
	if leaving:
		return
	if not card_done():
		# Show the rest of this card at once.
		if current_line != null:
			current_line.finish()
		while line_index + 1 < lines.size():
			next_line()
			current_line.finish()
		return
	if card_index < 3:
		AudioManager.play_sfx("preview")
		show_card(card_index + 1)
	else:
		leaving = true
		button.disabled = true
		AudioManager.stop_talk()
		StageManager.go_next()


# The Q card for this card's key word (UPGRADE_PLAN_V3 B3).
func get_question_id() -> String:
	var ids: Array = cards_words.get("card_questions", [])
	return ids[card_index] if card_index < ids.size() else ""


# The ConOps picture strip (NASA_RESOURCES_PLAN.md N6, from CubeSat 101):
# launch -> travel -> arrive -> do the science -> send it home.
func _draw_conops(strip: Control) -> void:
	var steps: Array = Data.story["nasa"]["conops_steps"]
	var ink: Color = strip.get_theme_color("font_color", &"PaperTitle")
	var accent: Color = strip.get_theme_color("font_color", &"PaperLabel")
	var font: Font = strip.get_theme_default_font()
	var font_size: int = strip.get_theme_font_size("font_size", &"PaperText")
	var slot: float = strip.size.x / steps.size()
	for i in steps.size():
		var c := Vector2(slot * (i + 0.5), 24)
		match i:
			0:   # launch: a rocket
				strip.draw_rect(Rect2(c.x - 6, c.y - 8, 12, 24), ink)
				strip.draw_colored_polygon(PackedVector2Array([Vector2(c.x - 6, c.y - 8), Vector2(c.x + 6, c.y - 8), Vector2(c.x, c.y - 20)]), accent)
				strip.draw_colored_polygon(PackedVector2Array([Vector2(c.x - 6, c.y + 16), Vector2(c.x + 6, c.y + 16), Vector2(c.x, c.y + 24)]), accent)
			1:   # travel: a curved path with the ship
				strip.draw_arc(Vector2(c.x, c.y + 18), 26, PI * 1.15, PI * 1.85, 16, ink, 3.0)
				strip.draw_circle(Vector2(c.x + 10, c.y - 6), 5, accent)
			2:   # arrive: a planet with an orbit
				strip.draw_circle(c, 13, ink)
				strip.draw_arc(c, 21, 0.0, TAU, 32, accent, 2.0)
			3:   # do the science: a magnifying glass
				strip.draw_arc(Vector2(c.x - 4, c.y - 4), 11, 0.0, TAU, 24, ink, 3.0)
				strip.draw_line(Vector2(c.x + 4, c.y + 4), Vector2(c.x + 14, c.y + 14), ink, 4.0)
			4:   # send it home: a dish and radio waves
				strip.draw_arc(Vector2(c.x - 8, c.y + 4), 14, -PI * 0.25, PI * 0.75, 16, ink, 3.0)
				for k in 3:
					strip.draw_arc(Vector2(c.x - 4, c.y), 10 + k * 7, -PI * 0.45, -PI * 0.05, 8, accent, 2.0)
		if i < steps.size() - 1:   # an arrow to the next step
			var a := Vector2(slot * (i + 1) - 14, 24)
			strip.draw_line(a - Vector2(14, 0), a + Vector2(6, 0), accent, 2.0)
			strip.draw_colored_polygon(PackedVector2Array([a + Vector2(12, 0), a + Vector2(4, -5), a + Vector2(4, 5)]), accent)
		var word: String = steps[i]
		var w: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		strip.draw_string(font, Vector2(c.x - w / 2.0, 68), word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


func add_label(parent: Control, text: String, style: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = style
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label
