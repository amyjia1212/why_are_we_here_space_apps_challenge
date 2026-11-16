# party.gd
# The party screen and the lobby (MULTIPLAYER_PLAN_V6 section 2). Only shown
# for 2-4 players (StageManager skips it for 1).
#   CREATE A PARTY -> who fills the other seats?
#        Other players join -> a 4-letter code and the seat list (online)
#        Play with bots     -> every other seat is a bot (no internet)
#   JOIN A PARTY   -> type the code -> lobby -> wait for the leader's START
# The lobby has one row per seat: portrait, name, "Waiting…" / "Joined" / "Bot".
# The leader can turn an empty seat into a bot. START lights up when every
# seat is filled. Rules and network: Party.gd and Net.gd. Words: story.json "party".
extends Control

var words: Dictionary
var page: Control          # the current page (choice, fill, join, lobby)
var code_box: LineEdit
var message_label: Label
var seat_list: VBoxContainer
var start_button: Button


func _ready() -> void:
	words = Data.story["party"]
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var background := Panel.new()
	background.theme_type_variation = &"ScreenBackground"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	Party.seats_changed.connect(_on_seats_changed)
	if Party.is_party() and not Party.started:
		show_lobby()   # back on this screen with a party already made
	else:
		Party.reset()
		show_choice()


func new_page(title: String, note: String = "") -> VBoxContainer:
	if page != null:
		page.queue_free()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -40
	add_child(center)
	page = center
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GlassPanel"
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	add_label(column, title, &"TitleText")
	if note != "":
		add_label(column, note, &"BodyText")
	message_label = add_label(column, Party.party_error, &"SmallText")
	message_label.add_theme_color_override("font_color", message_label.get_theme_color("caution_color", &"Status"))
	message_label.visible = Party.party_error != ""
	return column


func add_label(parent: Control, text: String, style: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = style
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func add_button(parent: Control, text: String, action: Callable, small: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48 if small else 60)
	if small:
		button.theme_type_variation = &"SmallButton"
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func show_message(text: String) -> void:
	message_label.text = text
	message_label.visible = text != ""


# ---------- page 1: create or join ----------

func show_choice() -> void:
	var column := new_page(words["title"], words["subtitle"])
	var first := add_button(column, words["create"], show_fill)
	add_button(column, words["join"], show_join)
	first.grab_focus()


func show_fill() -> void:
	Party.party_error = ""
	var column := new_page(words["fill_title"])
	var first := add_button(column, words["fill_players"], _on_fill_players)
	add_label(column, words["fill_players_note"], &"SmallText")
	add_button(column, words["fill_bots"], _on_fill_bots)
	add_label(column, words["fill_bots_note"], &"SmallText")
	add_button(column, words["back"], show_choice, true)
	first.grab_focus()


func _on_fill_bots() -> void:
	AudioManager.play_sfx("confirm")
	Party.start_bots(GameState.player_count)
	show_lobby()


func _on_fill_players() -> void:
	AudioManager.play_sfx("confirm")
	var column := new_page(words["connecting"])
	add_button(column, words["back"], _on_back_to_choice, true)
	Party.create_online(GameState.player_count)


func show_join() -> void:
	Party.party_error = ""
	var column := new_page(words["join_title"], words["join_note"])
	code_box = LineEdit.new()
	code_box.max_length = int(Data.mp["code"]["length"])
	code_box.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_box.custom_minimum_size = Vector2(0, 64)
	code_box.text_submitted.connect(func(_t): _on_join_pressed())
	column.add_child(code_box)
	add_button(column, words["join_button"], _on_join_pressed)
	add_button(column, words["back"], show_choice, true)
	code_box.grab_focus()


func _on_join_pressed() -> void:
	var typed: String = code_box.text.strip_edges().to_upper()
	if typed.length() != int(Data.mp["code"]["length"]):
		show_message(words["errors"]["no_party"])
		return
	AudioManager.play_sfx("confirm")
	var column := new_page(words["connecting"])
	add_button(column, words["back"], _on_back_to_choice, true)
	Party.join_online(typed)


func _on_back_to_choice() -> void:
	Party.reset()
	show_choice()


# ---------- the lobby ----------

func _on_seats_changed() -> void:
	if not is_inside_tree():
		return
	if Party.is_party():
		show_lobby()
	elif Party.party_error != "":
		# A wrong code, a full party or no relay: one plain sentence, back to the start.
		show_choice()


func show_lobby() -> void:
	var title: String = words["lobby_title"]
	var column := new_page(title)
	if Party.is_online() and Party.code != "":
		add_label(column, words["code_line"].format({"code": Party.code}), &"HeadingText")
		if Party.is_leader():
			add_label(column, words["code_note"], &"SmallText")
	seat_list = VBoxContainer.new()
	seat_list.add_theme_constant_override("separation", 8)
	column.add_child(seat_list)
	for i in Party.seats.size():
		add_seat_row(i)
	if Party.is_leader():
		start_button = add_button(column, words["start"], _on_start_pressed)
		start_button.disabled = not Party.can_start()
		if start_button.disabled:
			add_label(column, words["start_wait"], &"SmallText")
		else:
			start_button.grab_focus()
	else:
		add_label(column, words["wait_leader_start"], &"BodyText")
	add_button(column, words["back"], _on_back_to_choice, true)


func add_seat_row(i: int) -> void:
	var entry: Dictionary = Party.seats[i]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	seat_list.add_child(row)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(56, 56)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var character: String = str(entry.get("character", ""))
	if entry["kind"] == "me":
		character = GameState.character_id
	if character != "" and Data.characters.has(character):
		portrait.texture = Portraits.get_texture(character)
	row.add_child(portrait)
	var name_label := Label.new()
	name_label.theme_type_variation = &"BodyText"
	name_label.text = Party.seat_name(i) if entry["kind"] != "empty" else words["player_n"].format({"n": i + 1})
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var state := Label.new()
	state.theme_type_variation = &"SmallText"
	var tags: PackedStringArray = []
	match str(entry["kind"]):
		"me":
			tags.append(words["seat_you"])
		"human":
			tags.append(words["seat_joined"])
		"bot":
			tags.append(words["seat_bot"])
		_:
			tags.append(words["seat_waiting"])
	if i == Party.LEADER:
		tags.append(words["seat_leader"])
	state.text = " · ".join(tags)
	row.add_child(state)
	if entry["kind"] == "empty" and Party.is_leader():
		var bot_button := Button.new()
		bot_button.text = words["make_bot"]
		bot_button.theme_type_variation = &"SmallButton"
		bot_button.pressed.connect(Party.make_seat_bot.bind(i))
		row.add_child(bot_button)


func _on_start_pressed() -> void:
	if not Party.can_start():
		return
	start_button.disabled = true
	AudioManager.play_sfx("confirm")
	Party.start()
