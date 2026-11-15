# mission_select.gd
# "Choose a mission": one card for each mission in data/destinations.json
# (Moon, Mars, Venus). Each card shows the mission's goal and its success
# checklist. Locked missions show their card, but the button is off.
# Picking a mission also picks the place, so there is no separate
# "Where are we going?" screen any more.
extends Control

const CHOICE_CARD = preload("res://scenes/choice_card.tscn")

@onready var title_label: Label = %Title
@onready var cards_row: HBoxContainer = %Cards
@onready var inner_voice: PanelContainer = %InnerVoiceBar

# Only the cards that can be picked. Locked cards stay off.
var open_cards: Array = []


func _ready() -> void:
	var screen_text: Dictionary = Data.story["mission_screen"]
	var setup: Dictionary = Data.game_data["setup"]
	title_label.text = screen_text["title"]

	for destination_id in Data.destinations:
		var facts: Dictionary = Data.destinations[destination_id]   # from destinations.json
		var words: Dictionary = Data.story["destinations"][destination_id]   # from story.json
		var locked: bool = facts["locked"]["value"]

		var card = CHOICE_CARD.instantiate()
		cards_row.add_child(card)
		var button_text: String = screen_text["locked_button"] if locked else words["button"]
		card.setup(words["name"], words["goal"], words["description"], button_text)
		card.set_extra(make_checklist(destination_id))
		card.custom_minimum_size.x = setup["mission_card_width"]

		if locked:
			card.set_locked(true)
			card.modulate.a = setup["locked_card_opacity"]   # greyed out
		else:
			open_cards.append(card)
			card.chosen.connect(_on_mission_chosen.bind(destination_id))


# Builds the checklist text, for example:
#   Success if we:
#   [ ] Land safely
# Which items: destinations.json, "goals". The sentences: story.json.
func make_checklist(destination_id: String) -> String:
	var screen_text: Dictionary = Data.story["mission_screen"]
	var goal_words: Dictionary = Data.story["destinations"][destination_id]["goals"]

	var lines: PackedStringArray = [screen_text["goal_heading"]]
	for goal_id in Data.destinations[destination_id]["goals"]["value"]:
		lines.append(screen_text["checklist_mark"] + " " + goal_words[goal_id])
	return "\n".join(lines)


func _on_mission_chosen(destination_id: String) -> void:
	GameState.destination_id = destination_id
	GameState.goal_id = destination_id   # each mission has one goal with the same id
	# The budget, mass and other limits live in game_data.json "missions".
	GameState.mission_id = Data.destinations[destination_id]["limits_from"]["value"]
	print("Mission chosen: ", destination_id, "  (limits: ", GameState.mission_id,
			", character: ", GameState.character_id, ")")

	for card in open_cards:
		card.set_locked(true)
	inner_voice.say_then_next(Data.voice["setup"]["goal"][destination_id][GameState.level])
