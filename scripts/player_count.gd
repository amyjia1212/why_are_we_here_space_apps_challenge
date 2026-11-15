# player_count.gd
# "How many players are on the team?" One card for 1, 2, 3 and 4 players.
# The players take turns at each build minigame, and their scores are
# averaged (PLAN.md section 7, team play). Saved in GameState.player_count.
extends Control

const CHOICE_CARD = preload("res://scenes/choice_card.tscn")

@onready var title_label: Label = %Title
@onready var cards_row: HBoxContainer = %Cards
@onready var inner_voice: PanelContainer = %InnerVoiceBar

var cards: Array = []


func _ready() -> void:
	var screen_text: Dictionary = Data.story["player_count_screen"]
	title_label.text = screen_text["title"]
	var settings: Dictionary = Data.minigames["players"]

	for count in range(1, int(settings["max"]) + 1):   # 1, 2, 3, 4
		var words: Dictionary = screen_text["cards"][str(count)]
		var card = CHOICE_CARD.instantiate()
		cards_row.add_child(card)
		card.custom_minimum_size.x = settings["card_width"]
		card.setup(words["name"], "", words["description"], words["button"])
		cards.append(card)
		card.chosen.connect(_on_count_chosen.bind(count))


func _on_count_chosen(count: int) -> void:
	GameState.player_count = count
	print("Players: ", count)
	for card in cards:
		card.set_locked(true)
	inner_voice.say_then_next(Data.voice["setup"]["player_count"][str(count)])
