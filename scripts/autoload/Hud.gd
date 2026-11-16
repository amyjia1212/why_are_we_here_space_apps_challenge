# Hud.gd
# The layer that sits on top of every screen (an autoload, so it is always there).
#   - the small controls hint at the top (changes with the screen, step 8)
#   - the Controls panel (H), Settings (volume sliders), Credits, Leaderboard
#   - the pause menu (Esc)
#   - the mission tablet (Tab, step 22): mini map, the six resources, the goal, timers
#   - waypoints (step 23): a marker over every open problem, and an arrow at
#     the screen edge pointing to the most urgent one when it is off screen
#   - running timers in the top-right corner (step 2)
#   - the player's portrait in the top-left corner (step 10)
#
# A 3D screen tells the Hud what to show by having these functions (all optional):
#   get_tablet_map() -> { "player": Vector3, "yaw": float,
#                         "rooms": [ { "name": "Bridge", "rect": Rect2(x, z, w, d) } ],
#                         "points": [ { "pos": Vector3, "label": "Leak", "urgent": true } ] }
#   get_waypoints()  -> [ { "pos": Vector3, "label": "Water leak", "urgent": true, "seconds": 20.0 } ]
#   get_hud_timers() -> [ { "label": "Water leak", "seconds": 20.0 } ]
#   get_goal_text()  -> "Fix the leak"
extends CanvasLayer

var settings: Dictionary        # game_data.json "hud"
var root: Control
var hint_panel: PanelContainer
var hint_label: Label
var key_strip: HBoxContainer    # key caps on walking screens (story.json controls > key_strip)
var flash_label: Label
var flash_tween: Tween
var timers_panel: PanelContainer
var timers_label: Label
var portrait: TextureRect
var overlay: Control            # draws the waypoints
var modal: Control              # the dimmed layer behind panels
var modal_box: VBoxContainer    # the panel's contents
var page: String = ""           # the open panel: "", "pause", "controls", "settings", "credits", "leaderboard"
var paused_by_us: bool = false
var mouse_before: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var tablet: Control
var tablet_open: bool = false
var tablet_map: Control
var tablet_info: Label
var scene_id: String = ""

# NASA resources (NASA_RESOURCES_PLAN.md N2 and N7).
var strip_panel: PanelContainer     # the four mission segment badges + the CML meter
var strip_badges: Array = []        # one Label per segment
var strip_cml: Label
var dictionary: Control             # the Space Dictionary page (G)
var dictionary_box: VBoxContainer
var dictionary_open: bool = false
var dictionary_mouse_before: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var newest_stamp: String = ""

# The Q card (UPGRADE_PLAN_V3 A2): Q opens a small card about the thing you
# look at or stand near. The game pauses while it is open (DEFAULT: nobody is
# punished for being curious). Its words are the glossary in nasa_resources.json.
const TYPEWRITER = preload("res://scripts/typewriter_label.gd")
const UI = preload("res://scripts/ui_kit.gd")
var question_card: Control
var question_box: VBoxContainer
var question_open: bool = false
var question_paused_by_us: bool = false
var question_mouse_before: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var question_tag: PanelContainer
var question_tag_label: Label


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings = Data.game_data["hud"]
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_waypoints)
	root.add_child(overlay)

	make_hint()
	make_strip()
	make_timers()
	make_portrait()
	make_tablet()
	make_dictionary()
	make_question_card()
	make_notebook_button()
	make_modal()
	# Step 4 (UI_POLISH_PLAN_V4): every button in the game grows a tiny bit on
	# hover and dips when pressed. One hook here, so no screen has to remember it.
	get_tree().node_added.connect(_on_node_added)


# The Notebook button (INNOVATION.md Feature B): top left, under the room name,
# on the screens listed in game_data.json hud > notebook_button_scenes. N works everywhere.
var notebook_button: Button

func make_notebook_button() -> void:
	notebook_button = Button.new()
	notebook_button.theme_type_variation = &"SmallButton"
	notebook_button.text = Data.story["notebook"]["button"]
	notebook_button.focus_mode = Control.FOCUS_NONE   # Enter must keep confirming choices
	notebook_button.position = Vector2(12 + float(settings["portrait_size"]) + 12, 56)
	notebook_button.visible = false
	notebook_button.pressed.connect(func(): open_page("notebook"))
	root.add_child(notebook_button)


func update_notebook_button() -> void:
	notebook_button.visible = settings.get("notebook_button_scenes", []).has(scene_id) and GameState.character_id != "" and page == "" and not tablet_open and not dictionary_open and not question_open


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		UI.add_hover(node as Control)


# ---------- building the pieces ----------

func make_hint() -> void:
	hint_panel = PanelContainer.new()
	hint_panel.theme_type_variation = &"HintPanel"
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_panel.position.y = 6
	root.add_child(hint_panel)
	var hint_row := HBoxContainer.new()
	hint_row.add_theme_constant_override("separation", 16)
	hint_panel.add_child(hint_row)
	hint_label = Label.new()
	hint_label.theme_type_variation = &"HintText"
	hint_row.add_child(hint_label)
	# The key strip (UPGRADE_PLAN_V6 A3): on walking screens each key is a small
	# key cap with its job next to it, so it reads as "these are the buttons".
	key_strip = HBoxContainer.new()
	key_strip.add_theme_constant_override("separation", 12)
	hint_row.add_child(key_strip)

	flash_label = Label.new()
	flash_label.theme_type_variation = &"HeadingText"
	flash_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	flash_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	flash_label.position.y = 82   # under the hint and the segment strip
	flash_label.modulate.a = 0.0
	flash_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash_label)


# NASA's four mission segments as badges (they light up in order), and the
# CML meter: "Launch · Space · Ground · User   CML 2 · Could it work?" (N2).
func make_strip() -> void:
	strip_panel = PanelContainer.new()
	strip_panel.theme_type_variation = &"HintPanel"
	strip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	strip_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	strip_panel.position.y = 42
	strip_panel.visible = false
	root.add_child(strip_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	strip_panel.add_child(row)
	for segment_id in Data.nasa["segments"]["order"]:
		var badge := Label.new()
		badge.theme_type_variation = &"HintText"
		badge.text = Data.nasa["segments"][segment_id]["short"]
		row.add_child(badge)
		strip_badges.append(badge)
	strip_cml = Label.new()
	strip_cml.theme_type_variation = &"HintText"
	row.add_child(strip_cml)


func update_strip(scene: Node) -> void:
	var current: String = ""
	if scene != null and scene.has_method("get_segment"):
		current = scene.get_segment()
	else:
		current = GameState.segment_for_scene(scene_id)
	if current != "":
		GameState.reach_segment(current)
	strip_panel.visible = Data.nasa["segments"]["strip_scenes"].has(scene_id) and page == "" and not tablet_open and not dictionary_open
	if not strip_panel.visible:
		return
	var order: Array = Data.nasa["segments"]["order"]
	for i in order.size():
		var badge: Label = strip_badges[i]
		var color_name: String = "idle_color"
		var mark: String = "[ ] "
		if order[i] == current:
			color_name = "marker_color"
			mark = "[>] "
		elif i <= GameState.segment_reached:
			color_name = "go_color"
			mark = "[x] "
		badge.text = mark + Data.nasa["segments"][order[i]]["short"]
		badge.add_theme_color_override("font_color", badge.get_theme_color(color_name, &"Status"))
	strip_cml.visible = Data.nasa["cml"]["strip_scenes"].has(scene_id)
	strip_cml.text = "   " + cml_text()


# "CML 2 · Could it work?" with four pips.
func cml_text() -> String:
	var level: int = GameState.get_cml()
	var pips: String = ""
	for i in 4:
		pips += "#" if i < level else "-"
	if level == 0:
		return "[" + pips + "] " + Data.story["nasa"]["cml_none"]
	return "[" + pips + "] " + Data.story["nasa"]["cml_strip"].format({"level": level, "nickname": GameState.get_cml_level_info(level)["nickname"]})


# The Space Dictionary page (N7): every word, stamped or "???".
func make_dictionary() -> void:
	dictionary = Control.new()
	dictionary.set_anchors_preset(Control.PRESET_FULL_RECT)
	dictionary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dictionary.visible = false
	root.add_child(dictionary)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dictionary.add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"NavyPanel"
	center.add_child(panel)
	dictionary_box = VBoxContainer.new()
	dictionary_box.add_theme_constant_override("separation", 8)
	panel.add_child(dictionary_box)


func open_dictionary() -> void:
	close_tablet()
	if not dictionary_open:
		dictionary_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # so the mouse wheel can scroll the list
	dictionary_open = true
	AudioManager.play_sfx("preview")
	for child in dictionary_box.get_children():
		child.queue_free()
	var words: Dictionary = Data.story["nasa"]
	var glossary: Array = Data.nasa["glossary"]
	var owned: Array = GameState.get_stamps()
	add_dictionary_label(words["dictionary_title"].format({"n": owned.size(), "total": glossary.size()}), &"AccentText", 1000)
	var newest: Dictionary = GameState.glossary_entry(newest_stamp)
	if not newest.is_empty():
		add_dictionary_label(words["dictionary_newest"].format(newest), &"TinyText", 1000)
	# The word list scrolls (mouse wheel), so 45 words fit on the screen.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(1040, 430)
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	dictionary_box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)
	for entry in glossary:
		var label := Label.new()
		label.theme_type_variation = &"TinyText"
		label.custom_minimum_size.x = 500
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if owned.has(entry["id"]):
			label.text = "[x] " + entry["word"] + ": " + entry["meaning"]
		else:
			label.text = "[ ] " + words["dictionary_locked"]
			label.modulate.a = 0.5
		grid.add_child(label)
	add_dictionary_label(words["dictionary_bonus_line"].format({"points": int(Data.nasa["dictionary_bonus"]["points"])}), &"TinyText", 1000)
	add_dictionary_label(words["dictionary_close"], &"TinyText", 1000)
	dictionary.visible = true
	UI.fade_in(dictionary, Vector2.ZERO)


func add_dictionary_label(text: String, style: StringName, width: float) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = style
	label.custom_minimum_size.x = width
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dictionary_box.add_child(label)


func close_dictionary() -> void:
	if dictionary_open:
		Input.mouse_mode = dictionary_mouse_before
	dictionary_open = false
	if dictionary != null:
		dictionary.visible = false


# ---------- the Q card (UPGRADE_PLAN_V3 A2) ----------

func make_question_card() -> void:
	# UI_POLISH_PLAN_V4 Step 3a: ONE small see-through card, low on the left, so
	# the middle of the view stays clear (no dark screen behind it). It fades and
	# slides in. Width: game_data.json hud > question_card_width.
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GlassPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 32
	panel.offset_right = 32 + float(settings.get("question_card_width", 380))
	panel.offset_bottom = -float(settings.get("question_tag_bottom", 160))
	panel.offset_top = panel.offset_bottom
	panel.visible = false
	root.add_child(panel)
	question_card = panel
	question_box = VBoxContainer.new()
	question_box.add_theme_constant_override("separation", 8)
	panel.add_child(question_box)
	# The small "Q ?" sign: bottom right, just above the voice bar, so it never
	# covers the middle of the screen (screenshot check, 2026-11-14).
	question_tag = PanelContainer.new()
	question_tag.theme_type_variation = &"HintPanel"
	question_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	question_tag.anchor_left = 1.0
	question_tag.anchor_right = 1.0
	# UI_POLISH_PLAN_V4 Step 5: top-right corner, because "Next" always sits at
	# the bottom right and the tag covered it on Review.
	question_tag.anchor_top = 0.0
	question_tag.anchor_bottom = 0.0
	question_tag.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	question_tag.offset_right = -16
	question_tag.offset_top = 12
	question_tag.visible = false
	root.add_child(question_tag)
	question_tag_label = Label.new()
	question_tag_label.theme_type_variation = &"HintText"
	question_tag.add_child(question_tag_label)


# Which glossary id the screen offers right now ("" = nothing to ask about).
func current_question_id() -> String:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("get_question_id"):
		return scene.get_question_id()
	return str(settings.get("scene_questions", {}).get(scene_id, ""))


func update_question_tag() -> void:
	var entry: Dictionary = {}
	if page == "" and not question_open and not tablet_open and not dictionary_open:
		entry = GameState.glossary_entry(current_question_id())
	question_tag.visible = not entry.is_empty()
	if not entry.is_empty():
		question_tag_label.text = Data.story["question_card"]["tag"].format({"word": entry["word"]})


# The "Q ?" sign grows and shrinks twice, so the player notices it (UPGRADE_PLAN_V6 A4).
func pulse_question_tag() -> void:
	question_tag.pivot_offset = question_tag.size / 2.0
	var tween := question_tag.create_tween()
	for i in 2:
		tween.tween_property(question_tag, "scale", Vector2(1.25, 1.25), 0.25)
		tween.tween_property(question_tag, "scale", Vector2.ONE, 0.25)


func open_question(word_id: String) -> void:
	var entry: Dictionary = GameState.glossary_entry(word_id)
	if entry.is_empty():
		return
	var words: Dictionary = Data.story["question_card"]
	close_tablet()
	close_dictionary()
	for child in question_box.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = entry["word"]
	title.theme_type_variation = &"HeadingText"
	question_box.add_child(title)
	var meaning = TYPEWRITER.new()
	meaning.theme_type_variation = &"CardRich"
	meaning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_box.add_child(meaning)
	meaning.type_text(entry["meaning"], "crew")
	add_question_line("[b]" + words["real_label"] + "[/b] " + entry["real"], &"CardRichSmall")
	# An astronaut fact (C4), when one belongs to this card.
	var fact: Dictionary = GameState.astronaut_fact_for(word_id)
	if not fact.is_empty():
		add_question_line("[b]" + words["astronaut_label"] + "[/b] " + GameState.astronaut_fact_line(fact), &"CardRichSmall")
	# The source and the close key share one quiet line.
	var source: String = str(entry.get("link", ""))
	if source == "" and Data.nasa["resources"].has(entry.get("resource", "")):
		source = Data.nasa["resources"][entry["resource"]]["name"]
	add_question_line((words["source_label"] + " " + source + "   ·   " if source != "" else "") + words["close"], &"CardRichSmall")
	question_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not get_tree().paused and scene_id != "start_menu":
		get_tree().paused = true
		question_paused_by_us = true
	question_open = true
	(question_card as Control).offset_top = (question_card as Control).offset_bottom   # shrink to this card's words
	question_card.visible = true
	UI.fade_in(question_card, Vector2.ZERO)   # 0.18 s fade (Step 3a / Step 4); its height is still settling, so no slide
	AudioManager.play_sfx("preview")
	GameState.unlock_stamp(word_id)
	Achievements.question_opened()


func add_question_line(text: String, style: StringName) -> void:
	var line := RichTextLabel.new()
	line.bbcode_enabled = true
	line.fit_content = true
	line.scroll_active = false
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.theme_type_variation = style
	line.text = text
	question_box.add_child(line)


func close_question() -> void:
	if not question_open:
		return
	question_open = false
	UI.fade_out(question_card, true, Vector2.ZERO)
	AudioManager.stop_talk()
	if question_paused_by_us:
		get_tree().paused = false
		question_paused_by_us = false
	Input.mouse_mode = question_mouse_before


func make_timers() -> void:
	timers_panel = PanelContainer.new()
	timers_panel.theme_type_variation = &"NavyPanel"
	timers_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	timers_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	timers_panel.position = Vector2(-16, 88)   # under the Q ? tag and the skip line (top right)
	timers_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timers_panel.visible = false
	root.add_child(timers_panel)
	timers_label = Label.new()
	timers_label.theme_type_variation = &"BodyText"
	timers_panel.add_child(timers_label)


func make_portrait() -> void:
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var size: float = settings["portrait_size"]
	portrait.size = Vector2(size, size)
	portrait.position = Vector2(12, 12)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.visible = false
	root.add_child(portrait)


func make_tablet() -> void:
	tablet = Control.new()
	tablet.set_anchors_preset(Control.PRESET_FULL_RECT)
	tablet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tablet.visible = false
	root.add_child(tablet)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tablet.add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"NavyPanel"
	center.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := Label.new()
	title.text = Data.story["tablet"]["title"]
	title.theme_type_variation = &"AccentText"
	column.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	column.add_child(row)
	tablet_map = Control.new()
	var px: float = settings["tablet_map_pixels"]
	tablet_map.custom_minimum_size = Vector2(px, px)
	tablet_map.draw.connect(_draw_tablet_map)
	row.add_child(tablet_map)
	tablet_info = Label.new()
	tablet_info.theme_type_variation = &"TableText"
	tablet_info.custom_minimum_size.x = 380
	tablet_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(tablet_info)
	var hint := Label.new()
	hint.text = Data.story["tablet"]["close_hint"]
	hint.theme_type_variation = &"TinyText"
	column.add_child(hint)


func make_modal() -> void:
	modal = Panel.new()
	modal.theme_type_variation = &"DimBackground"
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.visible = false
	root.add_child(modal)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"NavyPanel"
	center.add_child(panel)
	modal_box = VBoxContainer.new()
	modal_box.add_theme_constant_override("separation", 16)
	panel.add_child(modal_box)


# ---------- every frame ----------

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	var new_id: String = "" if scene == null else scene.scene_file_path.get_file().get_basename()
	if new_id != scene_id:
		scene_id = new_id
		on_scene_changed()
	update_timers(scene)
	update_strip(scene)
	update_question_tag()
	update_notebook_button()
	if tablet_open:
		update_tablet(scene)
	overlay.queue_redraw()


func on_scene_changed() -> void:
	var hints: Dictionary = Data.story["controls"]["hints"]
	hint_label.text = hints.get(scene_id, Data.story["controls"]["hint_default"])
	fill_key_strip()
	hint_label.visible = key_strip.get_child_count() == 0
	hint_panel.visible = hint_label.text != "" or key_strip.get_child_count() > 0
	close_tablet()
	close_dictionary()
	close_question()
	if scene_id != "":
		GameState.unlock_for_scene(scene_id)   # Space Dictionary stamps for this screen (N7)
	if page != "":
		close_page()
	update_portrait()


# Key caps for this screen: [ WASD ] move  [ E ] use ... (story.json controls > key_strip).
func fill_key_strip() -> void:
	for child in key_strip.get_children():
		child.queue_free()
		key_strip.remove_child(child)
	var keys: Array = Data.story["controls"].get("key_strip", {}).get(scene_id, [])
	for pair in keys:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 4)
		var cap := PanelContainer.new()
		cap.theme_type_variation = &"TagPill"
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cap_text := Label.new()
		cap_text.theme_type_variation = &"PillSmallText"
		cap_text.text = pair[0]
		cap.add_child(cap_text)
		item.add_child(cap)
		var job := Label.new()
		job.theme_type_variation = &"HintText"
		job.text = pair[1]
		item.add_child(job)
		key_strip.add_child(item)


func update_portrait() -> void:
	var wanted: bool = settings["portrait_scenes"].has(scene_id) and GameState.character_id != ""
	var texture: Texture2D = Portraits.get_texture(GameState.character_id) if wanted else null
	portrait.texture = texture
	portrait.visible = texture != null


func update_timers(scene: Node) -> void:
	var timers: Array = []
	if scene != null and scene.has_method("get_hud_timers"):
		timers = scene.get_hud_timers()
	timers_panel.visible = not timers.is_empty() and page == ""
	if timers.is_empty():
		return
	var lines: PackedStringArray = []
	for timer in timers:
		lines.append(Data.story["hud"]["timer_line"].format({"label": timer["label"], "seconds": int(ceil(maxf(timer["seconds"], 0.0)))}))
	timers_label.text = "\n".join(lines)


# A short message in the middle top, for example "Sound off".
func flash(text: String) -> void:
	flash_label.text = text
	if flash_tween:
		flash_tween.kill()
	flash_label.modulate.a = 1.0
	flash_tween = create_tween()
	flash_tween.tween_interval(1.0)
	flash_tween.tween_property(flash_label, "modulate:a", 0.0, 0.5)


# ---------- keys ----------

func _unhandled_input(event: InputEvent) -> void:
	# The Q card: Q opens it (when there is something to ask about); Q or Esc closes it.
	if question_open and (event.is_action_pressed("ask_question") or event.is_action_pressed("pause")):
		close_question()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ask_question") and not Controls.typing_mode and page == "" and not event.is_echo():
		var word_id: String = current_question_id()
		if word_id != "":
			open_question(word_id)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("pause"):
		if page != "":
			close_page()
		elif not settings["no_pause_scenes"].has(scene_id):
			open_page("pause")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("replay_lesson") and tablet_open and page == "":
		# Mission School again, from the tablet (UPGRADE_PLAN_V3 B4).
		lesson_index = 0
		open_page("lesson")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tablet") and not Controls.typing_mode and page == "":
		if tablet_open or dictionary_open:
			close_tablet()
			close_dictionary()
		else:
			open_tablet()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("dictionary") and not Controls.typing_mode and page == "" and scene_id != "start_menu":
		if dictionary_open:
			close_dictionary()
		else:
			open_dictionary()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("notebook") and not Controls.typing_mode and (page == "" or page == "notebook") and GameState.character_id != "":
		# The character's Notebook (INNOVATION.md Feature B): N opens and closes it.
		if page == "notebook":
			close_page()
		else:
			close_dictionary()
			open_page("notebook")
		get_viewport().set_input_as_handled()


# ---------- panels (pause, controls, settings, credits, leaderboard) ----------

func toggle_controls() -> void:
	if page == "controls":
		close_page()
	else:
		open_page("controls")


func open_page(new_page: String) -> void:
	if page == "":
		mouse_before = Input.mouse_mode
	page = new_page
	close_tablet()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not get_tree().paused and scene_id != "start_menu":
		get_tree().paused = true
		paused_by_us = true
	for child in modal_box.get_children():
		child.queue_free()
	match new_page:
		"pause":
			fill_pause()
		"controls":
			fill_controls()
		"settings":
			fill_settings()
		"credits":
			fill_credits()
		"leaderboard":
			fill_leaderboard()
		"lesson":
			fill_lesson()
		"notebook":
			fill_notebook()
	var was_open: bool = modal.visible
	modal.visible = true
	if not was_open:
		UI.fade_in(modal, Vector2.ZERO)   # Step 4: panels ease in, never pop


func close_page() -> void:
	page = ""
	modal.visible = false
	if paused_by_us:
		get_tree().paused = false
		paused_by_us = false
	Input.mouse_mode = mouse_before


func add_title(text: String) -> void:
	var title := Label.new()
	title.text = text
	title.theme_type_variation = &"HeadingText"
	modal_box.add_child(title)


func add_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	modal_box.add_child(button)
	return button


func fill_pause() -> void:
	var words: Dictionary = Data.story["pause"]
	add_title(words["title"])
	add_button(words["resume"], close_page).grab_focus()
	add_volume_sliders()
	add_button(words["controls"], open_page.bind("controls"))
	add_button(words["quit"], _on_quit_pressed)


func _on_quit_pressed() -> void:
	close_page()
	StageManager.go_to("start_menu")


func fill_controls() -> void:
	var words: Dictionary = Data.story["controls"]
	add_title(words["title"])
	# Two key/action pairs per row, so the whole list fits on the screen.
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	modal_box.add_child(grid)
	for row in words["keys"]:
		var key := Label.new()
		key.text = row[0]
		key.theme_type_variation = &"AccentText"
		grid.add_child(key)
		var action := Label.new()
		action.text = row[1]
		action.theme_type_variation = &"TableText"
		action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		action.custom_minimum_size.x = 440
		grid.add_child(action)
	add_back_button()


func fill_settings() -> void:
	add_title(Data.story["start_menu"]["settings"])
	add_volume_sliders()
	add_back_button()


func fill_credits() -> void:
	var words: Dictionary = Data.story["credits"]
	add_title(words["title"])
	for line in words["lines"]:
		var label := Label.new()
		label.text = line
		label.theme_type_variation = &"TableText"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 720
		modal_box.add_child(label)
	add_back_button()


# Mission School replay: one resource at a time, the same words and limits.
var lesson_index: int = 0

func fill_lesson() -> void:
	var words: Dictionary = Data.story["mission_school"]
	var ids: Array = Data.resources.keys()
	var res_id: String = ids[clampi(lesson_index, 0, ids.size() - 1)]
	var limit: Dictionary = GameState.get_limits()[res_id]
	add_title(words["title"] + " · " + Data.resources[res_id]["name"])
	var text := Label.new()
	text.theme_type_variation = &"BodyText"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 640
	text.text = words["beats"][res_id]["meaning"] + "\n" + words["beats"][res_id]["limit"].format({
		"value": GameState.fmt(limit["value"]), "unit": Data.resources[res_id]["unit"],
		"rocket": Data.story["launch_vehicles"][GameState.get_launch_vehicle_id()]["name"],
	})
	modal_box.add_child(text)
	var dots := Label.new()
	dots.theme_type_variation = &"TinyText"
	dots.text = words["beat_dots"].format({"n": lesson_index + 1, "total": ids.size()})
	modal_box.add_child(dots)
	if lesson_index + 1 < ids.size():
		add_button(words["replay_next"], func():
			lesson_index += 1
			open_page("lesson")).grab_focus()
	add_button(words["replay_close"], close_page)


func fill_leaderboard() -> void:
	add_title(Data.story["leaderboard"]["title"])
	modal_box.add_child(Leaderboard.make_table())
	add_back_button()


# The character's Notebook (INNOVATION.md Feature B): "3 of 10 words earned",
# then every word: earned ones with their meaning and what happened in that
# run; the others stay hidden.
func fill_notebook() -> void:
	var words: Dictionary = Data.story["notebook"]
	var who: String = GameState.character_id
	add_title(words["title"].format({"name": Data.story["characters"][who]["name"]}))
	var earned: Array = Notebook.words_for(who)
	var all_terms: Array = Notebook.terms()
	# Two sides (UPGRADE_PLAN_V6 C3): the words on the left, the achievements on the right.
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 24)
	modal_box.add_child(sides)
	var left := VBoxContainer.new()
	sides.add_child(left)
	var progress := UI.label(words["progress"].format({"n": earned.size(), "total": all_terms.size()}), &"AccentText")
	left.add_child(progress)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(470, 400)
	left.add_child(scroll)
	sides.add_child(make_achievement_list(Vector2(500, 400)))
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	# Earned words first (newest on top), then the hidden ones.
	var ordered: Array = []
	for i in range(earned.size() - 1, -1, -1):
		ordered.append(Notebook.term(earned[i]["id"]))
	for t in all_terms:
		if not ordered.has(t):
			ordered.append(t)
	for t in ordered:
		var entry: Dictionary = {}
		for e in earned:
			if e["id"] == t["id"]:
				entry = e
		var card := PanelContainer.new()
		card.theme_type_variation = &"CardPanel"
		list.add_child(card)
		var box := VBoxContainer.new()
		card.add_child(box)
		if entry.is_empty():
			var locked := UI.label(words["locked"], &"SmallText")
			locked.modulate.a = 0.6
			box.add_child(locked)
			continue
		box.add_child(UI.label(t["word"], &"HeadingText"))
		box.add_child(UI.label(t["meaning"], &"BodyText", true))
		if str(entry.get("run", "")) != "":
			box.add_child(UI.label(words["this_run"] + " " + entry["run"], &"SmallText", true))
	modal_box.add_child(UI.label(words["close"], &"TinyText"))
	add_button(Data.story["pause"]["close"], close_page).grab_focus()


# The achievements, earned ones in color first, the rest gray but with how to
# get them (UPGRADE_PLAN_V6 C3). Used by the Notebook.
func make_achievement_list(size: Vector2) -> Control:
	var column := VBoxContainer.new()
	column.add_child(UI.label(Data.story["achievements"]["title"] + "  ·  " + Achievements.count_text(), &"AccentText"))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = size
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var order: Array = Data.achievements["order"].duplicate()
	order.sort_custom(func(a, b): return int(Achievements.has(a)) > int(Achievements.has(b)))
	for id in order:
		var a: Dictionary = Achievements.info(id)
		var got: bool = Achievements.has(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		list.add_child(row)
		var badge := Control.new()
		badge.custom_minimum_size = Vector2(44, 44)
		badge.draw.connect(func(): Achievements.draw_badge(badge, Rect2(Vector2.ZERO, badge.size), a.get("icon", "star"), Color(a.get("color", "#ffd700")), got))
		row.add_child(badge)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		row.add_child(text)
		var name_label := UI.label(a["name"], &"BodyText")
		if not got:
			name_label.modulate.a = 0.6
		text.add_child(name_label)
		text.add_child(UI.label(a["how"], &"SmallText", true))
	return column


# Back goes to the pause menu if the game is paused, otherwise closes.
func add_back_button() -> void:
	var words: Dictionary = Data.story["pause"]
	if paused_by_us:
		add_button(words["resume"], close_page)
		add_button(words["title"], open_page.bind("pause"))
	else:
		add_button(words["close"], close_page).grab_focus()


func add_volume_sliders() -> void:
	var words: Dictionary = Data.story["pause"]
	var label := Label.new()
	label.text = words["volume_title"]
	label.theme_type_variation = &"AccentText"
	modal_box.add_child(label)
	var grid := GridContainer.new()
	grid.columns = 2
	modal_box.add_child(grid)
	for bus_name in AudioManager.BUS_NAMES:
		var name_label := Label.new()
		name_label.text = words[bus_name]
		name_label.theme_type_variation = &"TableText"
		grid.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = AudioManager.get_volume(bus_name)
		slider.custom_minimum_size = Vector2(320, 30)
		slider.value_changed.connect(_on_volume_changed.bind(bus_name))
		grid.add_child(slider)


func _on_volume_changed(value: float, bus_name: String) -> void:
	AudioManager.set_volume(bus_name, value)


# ---------- the mission tablet (Tab) ----------

func open_tablet() -> void:
	tablet_open = true
	tablet.visible = true
	UI.fade_in(tablet, Vector2.ZERO)
	AudioManager.play_sfx("preview")
	update_tablet(get_tree().current_scene)


func close_tablet() -> void:
	tablet_open = false
	if tablet != null:
		tablet.visible = false


func update_tablet(scene: Node) -> void:
	var words: Dictionary = Data.story["tablet"]
	var has_map: bool = scene != null and scene.has_method("get_tablet_map")
	tablet_map.visible = has_map
	var lines: PackedStringArray = [words["resources"]]
	var values: Dictionary = GameState.get_hud_values()
	var limits: Dictionary = GameState.get_limits()
	for res_id in Data.resources:
		var mark: String = words["ok_mark"] if GameState.is_ok(values[res_id], limits[res_id]) else words["bad_mark"]
		lines.append(mark + " " + words["value_line"].format({
			"name": Data.resources[res_id]["name"],
			"value": GameState.fmt(values[res_id]),
			"unit": Data.resources[res_id]["unit"],
		}))
	if scene != null and scene.has_method("get_goal_text"):
		lines.append("")
		lines.append(words["goal"] + ": " + scene.get_goal_text())
	# The checklist: only the current phase's items, and "3 of 8 done" (UPGRADE_PLAN_V3 A3).
	var phases: Array = GameState.current_phases(scene_id)
	if not phases.is_empty() and not GameState.goals.is_empty():
		var check_words: Dictionary = Data.story["checklist"]
		var marks: Dictionary = Data.story["arrival_screen"]["marks"]
		var goal_words: Dictionary = Data.story["destinations"][GameState.get_destination_key()]["goals"]
		lines.append("")
		lines.append(check_words["now_label"] + " · " + GameState.checklist_progress_text())
		for goal_id in GameState.goals:
			if phases.has(GameState.goal_phase(goal_id)):
				lines.append(marks[GameState.goals[goal_id]] + " " + goal_words[goal_id])
	# NASA's mission segment and the CML meter (N2), and the Dictionary key (N7).
	# The segment and the CML only where the strip at the top does not show
	# them already (UPGRADE_PLAN_V3 E: the same thing is not shown twice).
	var nasa_words: Dictionary = Data.story["nasa"]
	lines.append("")
	var on_strip: bool = Data.nasa["segments"]["strip_scenes"].has(scene_id)
	var segment_id: String = scene.get_segment() if scene != null and scene.has_method("get_segment") else GameState.segment_for_scene(scene_id)
	if segment_id != "" and not on_strip:
		lines.append(nasa_words["tablet_segment"].format(Data.nasa["segments"][segment_id]))
	var cml: int = GameState.get_cml()
	if cml > 0 and not Data.nasa["cml"]["strip_scenes"].has(scene_id):
		lines.append(nasa_words["tablet_cml"].format({"level": cml, "nickname": GameState.get_cml_level_info(cml)["nickname"]}))
	lines.append(nasa_words["tablet_dictionary_hint"] + " · " + Data.story["mission_school"]["tablet_hint"])
	# (Running timers are not repeated here: the box in the top-right corner
	# shows them, UPGRADE_PLAN_V3 E. Their spots are on the map.)
	tablet_info.text = "\n".join(lines)
	tablet_map.queue_redraw()


# The mini map: seen from above, the player in the middle, north up.
func _draw_tablet_map() -> void:
	var scene := get_tree().current_scene
	if scene == null or not scene.has_method("get_tablet_map"):
		return
	var map: Dictionary = scene.get_tablet_map()
	var px: float = settings["tablet_map_pixels"]
	var scale: float = px / float(settings["tablet_map_meters"])
	var center: Vector3 = map.get("center", map.get("player", Vector3.ZERO))
	var to_map := func(world: Vector3) -> Vector2:
		return Vector2(px / 2.0, px / 2.0) + Vector2(world.x - center.x, world.z - center.z) * scale
	tablet_map.draw_rect(Rect2(Vector2.ZERO, Vector2(px, px)), Color(0, 0, 0, 0.35))
	var font: Font = tablet_map.get_theme_default_font()
	var font_size: int = tablet_map.get_theme_font_size("font_size", &"TinyText")
	var room_color: Color = tablet_map.get_theme_color("map_room_color", &"Status")
	var line_color: Color = tablet_map.get_theme_color("map_line_color", &"Status")
	for room in map.get("rooms", []):
		var rect: Rect2 = room["rect"]
		var top_left: Vector2 = to_map.call(Vector3(rect.position.x, 0, rect.position.y))
		var box := Rect2(top_left, rect.size * scale)
		tablet_map.draw_rect(box, room_color)
		tablet_map.draw_rect(box, line_color, false, 1.5)
		tablet_map.draw_string(font, box.position + Vector2(4, font_size + 2), room["name"], HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 6, font_size, line_color)
	for point in map.get("points", []):
		var p: Vector2 = to_map.call(point["pos"])
		var color: Color = tablet_map.get_theme_color("urgent_color" if point.get("urgent", false) else "marker_color", &"Status")
		tablet_map.draw_circle(p, 7.0, color)
		tablet_map.draw_string(font, p + Vector2(10, 5), point.get("label", ""), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	if map.has("player"):
		var you: Vector2 = to_map.call(map["player"])
		var yaw: float = map.get("yaw", 0.0)
		var forward := Vector2(-sin(yaw), -cos(yaw))
		var side := Vector2(forward.y, -forward.x)
		var you_color: Color = tablet_map.get_theme_color("you_color", &"Status")
		tablet_map.draw_colored_polygon(PackedVector2Array([you + forward * 12.0, you + side * 7.0 - forward * 6.0, you - side * 7.0 - forward * 6.0]), you_color)


# ---------- waypoints ----------

func _draw_waypoints() -> void:
	var scene := get_tree().current_scene
	if scene == null or not scene.has_method("get_waypoints") or page != "":
		return
	var points: Array = scene.get_waypoints()
	var camera := get_viewport().get_camera_3d()
	if points.is_empty() or camera == null:
		return
	# Most urgent first: urgent ones, then the least time left.
	points.sort_custom(func(a, b):
		if a.get("urgent", false) != b.get("urgent", false):
			return a.get("urgent", false)
		return a.get("seconds", 9999.0) < b.get("seconds", 9999.0))
	var screen: Vector2 = overlay.size
	var margin: float = settings["waypoint_edge_margin"]
	var font: Font = overlay.get_theme_default_font()
	var font_size: int = overlay.get_theme_font_size("font_size", &"HintText")
	var lift := Vector3(0, float(settings["waypoint_height"]), 0)
	for i in points.size():
		var point: Dictionary = points[i]
		var world: Vector3 = point["pos"] + lift
		var color: Color = overlay.get_theme_color("urgent_color" if point.get("urgent", false) else "marker_color", &"Status")
		var meters: int = int(camera.global_position.distance_to(point["pos"]))
		var text: String = Data.story["hud"]["waypoint"].format({"label": point.get("label", ""), "meters": meters})
		if point.has("seconds"):
			text += " · " + str(int(ceil(maxf(point["seconds"], 0.0)))) + " s"
		# A point right at the camera can't be drawn (it has no direction): skip it.
		var depth: float = (camera.global_transform.affine_inverse() * world).z
		if absf(depth) < 0.05:
			continue
		var behind: bool = camera.is_position_behind(world)
		var spot: Vector2 = camera.unproject_position(world)
		var on_screen: bool = not behind and Rect2(Vector2.ZERO, screen).has_point(spot)
		if on_screen:
			var diamond := PackedVector2Array([spot + Vector2(0, -10), spot + Vector2(8, 0), spot + Vector2(0, 10), spot + Vector2(-8, 0)])
			overlay.draw_colored_polygon(diamond, color)
			overlay.draw_string(font, spot + Vector2(-150, -16), text, HORIZONTAL_ALIGNMENT_CENTER, 300, font_size, color)
		elif i == 0:
			# Off screen: an arrow at the edge, pointing the way (only the most urgent).
			var middle: Vector2 = screen / 2.0
			var direction: Vector2 = (spot - middle)
			if behind:
				direction = -direction
			if direction.length() < 1.0:
				direction = Vector2.DOWN
			direction = direction.normalized()
			var reach: float = minf((screen.x / 2.0 - margin) / maxf(absf(direction.x), 0.001), (screen.y / 2.0 - margin) / maxf(absf(direction.y), 0.001))
			var tip: Vector2 = middle + direction * reach
			# Keep the arrow out of the top bar area (hint, strip, alerts) and above the voice bar.
			tip.y = clampf(tip.y, float(settings["waypoint_top_margin"]), screen.y - float(settings["waypoint_bottom_margin"]))
			var side := Vector2(-direction.y, direction.x)
			overlay.draw_colored_polygon(PackedVector2Array([tip + direction * 16.0, tip - direction * 10.0 + side * 12.0, tip - direction * 10.0 - side * 12.0]), color)
			# Keep the arrow's words fully on screen (they can be long).
			var text_width: float = 300.0
			var text_pos: Vector2 = tip - direction * 34.0 + Vector2(-text_width / 2.0, 6)
			text_pos.x = clampf(text_pos.x, 8.0, screen.x - text_width - 8.0)
			overlay.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size, color)
