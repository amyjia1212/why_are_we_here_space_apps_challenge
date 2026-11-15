# build.gd
# The build screen. Across the top: one tab for each part category, plus
# an Instruments tab. The middle shows the cards for the open tab:
#   - part tabs: 3 cards, pick ONE (simple / better / best)
#   - Instruments: one card each, pack as MANY as you like (on/off)
# Right side: the mission dashboard, updated after every click.
# Numbers: data/game_data.json ("parts") and data/destinations.json
# ("instruments"). Words: data/story.json ("build_screen", "parts", "instruments").
extends Control

const CHOICE_CARD = preload("res://scenes/choice_card.tscn")
const INSTRUMENTS_TAB := "instruments"   # the tab id for the Instruments tab

@onready var title_label: Label = %Title
@onready var tabs_row: HFlowContainer = %Tabs
@onready var hint_label: Label = %Hint
@onready var tip_label: Label = %Tip
@onready var cards_area: HFlowContainer = %Cards
@onready var dashboard: PanelContainer = %Dashboard
@onready var review_button: Button = %ReviewButton
@onready var ripple_label: RichTextLabel = %Ripple

var words: Dictionary          # the build_screen text from story.json
var current_tab: String = ""   # which tab is open, for example "solar_panel"


func _ready() -> void:
	# Safety net: if we press Play on this screen directly, nobody has
	# picked a character or mission yet, so use the first ones in the data.
	if GameState.character_id == "":
		GameState.character_id = Data.game_data["setup"]["default_character"]
	if GameState.mission_id == "":
		GameState.mission_id = Data.missions.keys()[0]

	words = Data.story["build_screen"]
	title_label.text = words["title"]
	review_button.text = words["review_button"]
	review_button.pressed.connect(_on_review_pressed)

	GameState.fill_default_choices()
	make_tabs()
	show_tab(Data.parts.keys()[0])   # start on the first category
	refresh_dashboard()
	ripple_label.text = Data.story["ripple"]["start"]


# One tab button per part category, then the Instruments tab.
# A ButtonGroup makes them work like radio buttons: only one is pressed.
func make_tabs() -> void:
	var group := ButtonGroup.new()
	var tab_ids: Array = Data.parts.keys() + [INSTRUMENTS_TAB]
	for tab_id in tab_ids:
		var button := Button.new()
		button.text = words["instruments_tab"] if tab_id == INSTRUMENTS_TAB else Data.story["parts"][tab_id]["tab"]
		button.toggle_mode = true
		button.button_group = group
		button.theme_type_variation = &"SmallButton"
		button.button_pressed = tab_id == Data.parts.keys()[0]
		button.pressed.connect(show_tab.bind(tab_id))
		tabs_row.add_child(button)


# Clears the middle and fills it with the cards for one tab.
func show_tab(tab_id: String) -> void:
	current_tab = tab_id
	for old_card in cards_area.get_children():
		old_card.queue_free()

	# "Did you know?": one real fact for this tab (story.json "did_you_know").
	var tips: Dictionary = Data.story["did_you_know"]
	var tip: Dictionary = {}
	if tab_id == INSTRUMENTS_TAB:
		tip = tips["instruments"].get(GameState.get_destination_key(), {})
	else:
		tip = tips["parts"].get(tab_id, {})
	tip_label.visible = tip.has("text")
	tip_label.text = tips["label"] + " " + tip.get("text", "")

	if tab_id == INSTRUMENTS_TAB:
		hint_label.text = words["instruments_hint"]
		make_instrument_cards()
	else:
		hint_label.text = Data.story["parts"][tab_id]["hint"]
		make_part_cards(tab_id)


# 3 cards for one part category. The picked one says "YOUR PICK";
# the others are a little see-through.
func make_part_cards(part_id: String) -> void:
	var versions: Dictionary = Data.parts[part_id]["versions"]
	for version_id in versions:
		var text: Dictionary = Data.story["parts"][part_id]["versions"][version_id]
		var picked: bool = GameState.choices[part_id] == version_id
		var card = new_card(picked)
		card.setup(
			text["name"],
			words["picked_word"] if picked else "",
			text["description"],
			words["picked_button"] if picked else words["pick_button"],
		)
		card.set_extra(GameState.effects_text(versions[version_id]["effects"], "\n"))
		card.set_locked(picked)   # the picked card's button can't be pressed again
		card.chosen.connect(_on_version_picked.bind(part_id, version_id))


# One on/off card per instrument. Key instruments say "Needed for the mission goal!"
func make_instrument_cards() -> void:
	var instruments: Dictionary = GameState.get_instruments()
	var key_ids: Array = GameState.get_key_instruments()
	for instrument_id in instruments:
		var text: Dictionary = Data.story["instruments"][GameState.get_destination_key()][instrument_id]
		var packed: bool = GameState.is_instrument_packed(instrument_id)
		var card = new_card(packed)
		card.setup(
			text["name"],
			words["packed_word"] if packed else "",
			text["description"],
			words["unpack_button"] if packed else words["pack_button"],
		)
		var extra: String = GameState.effects_text(instruments[instrument_id]["effects"], "\n")
		if key_ids.has(instrument_id):
			extra = words["key_instrument_line"] + "\n" + extra
		card.set_extra(extra)
		card.chosen.connect(_on_instrument_toggled.bind(instrument_id, not packed))


# Makes one card in the middle area. Cards that are not picked are see-through.
func new_card(picked: bool) -> PanelContainer:
	var settings: Dictionary = Data.game_data["setup"]
	var card = CHOICE_CARD.instantiate()
	cards_area.add_child(card)
	card.custom_minimum_size.x = settings["build_card_width"]
	card.modulate.a = 1.0 if picked else settings["picked_card_opacity"]
	return card


# GameState adds up the six totals; the dashboard draws them.
func refresh_dashboard() -> void:
	dashboard.show_values(GameState.get_totals())


# Runs when the player picks a part card.
func _on_version_picked(part_id: String, version_id: String) -> void:
	var old_version: String = GameState.choices[part_id]
	var before: Dictionary = GameState.get_totals()   # remember the numbers first
	GameState.choices[part_id] = version_id
	print("Picked ", part_id, " = ", version_id)
	show_tab(current_tab)   # redraw the cards so the new pick shows
	refresh_dashboard()
	# For example "Camera: High resolution instead of Basic"
	var cause: String = Data.story["ripple"]["swap"].format({
		"part": Data.part_name(part_id),
		"new": Data.version_name(part_id, version_id),
		"old": Data.version_name(part_id, old_version),
	})
	show_ripple(cause, before, GameState.get_totals())


# Runs when the player packs or unpacks an instrument.
func _on_instrument_toggled(instrument_id: String, packed: bool) -> void:
	var before: Dictionary = GameState.get_totals()
	GameState.set_instrument_packed(instrument_id, packed)
	print("Instrument ", instrument_id, " packed = ", packed)
	show_tab(current_tab)
	refresh_dashboard()
	var instrument_name: String = Data.story["instruments"][GameState.get_destination_key()][instrument_id]["name"]
	var cause: String = Data.story["ripple"]["packed" if packed else "unpacked"].format({"name": instrument_name})
	show_ripple(cause, before, GameState.get_totals())


# The Ripple effect strip: the change, then every number it moved (green =
# helps, red = hurts), then any row that just turned red (with a tip) or
# came back inside its limit. For example:
#   Packed the Ice drill → Power -100 W → Budget +60 million $ → ...
func show_ripple(cause: String, before: Dictionary, after: Dictionary) -> void:
	var text: Dictionary = Data.story["ripple"]
	var colors: Dictionary = Data.game_data["dashboard"]["colors"]
	var limits: Dictionary = GameState.get_limits()
	var pieces: PackedStringArray = ["[b]" + cause + "[/b]"]

	var steps: Array = GameState.get_ripple_steps(before, after)
	if steps.is_empty():
		pieces.append(text["no_change"])
	for step in steps:
		var res_id: String = step["res_id"]
		var amount: float = step["amount"]
		var line: String = text["change"].format({
			"resource": Data.resources[res_id]["name"],
			"amount": ("+" if amount > 0 else "") + GameState.fmt(amount),
			"unit": Data.resources[res_id]["unit"],
		})
		pieces.append(colored(line, colors["safe"] if step["good"] else colors["danger"]))

	# Did a row just cross its limit, one way or the other?
	var rocket_name: String = Data.story["launch_vehicles"][GameState.get_launch_vehicle_id()]["name"]
	for res_id in Data.resources:
		var was_ok: bool = GameState.is_ok(before[res_id], limits[res_id])
		var now_ok: bool = GameState.is_ok(after[res_id], limits[res_id])
		if was_ok and not now_ok:
			var bad: String = text["now_bad"][res_id].format({"rocket": rocket_name})
			pieces.append(colored("[b]" + bad + "[/b]" + text["arrow"] + text["tips"][res_id], colors["danger"]))
		elif now_ok and not was_ok:
			pieces.append(colored(text["now_ok"].format({"resource": Data.resources[res_id]["name"]}), colors["safe"]))

	ripple_label.text = text["arrow"].join(pieces)


# Wraps text in a color, for example [color=#ff5c5c]Power -53 W[/color]
func colored(line: String, color_code: String) -> String:
	return "[color=%s]%s[/color]" % [color_code, line]


func _on_review_pressed() -> void:
	StageManager.go_next()
