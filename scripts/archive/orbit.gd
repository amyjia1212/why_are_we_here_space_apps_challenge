# orbit.gd
# "Choose an orbit": one card for each orbit of the picked mission
# (data/destinations.json, "orbits"). Each card shows how much fuel the
# spacecraft needs to get into that orbit. That fuel is added to the Mass
# total, and the Mass must fit what the rocket can lift.
# The answer is saved in GameState.orbit_id.
extends Control

const CHOICE_CARD = preload("res://scenes/choice_card.tscn")

@onready var title_label: Label = %Title
@onready var cards_row: HBoxContainer = %Cards
@onready var inner_voice: PanelContainer = %InnerVoiceBar

var cards: Array = []


func _ready() -> void:
	var screen_text: Dictionary = Data.story["orbit_screen"]
	title_label.text = screen_text["title"]

	var mission: String = mission_key()
	var orbits: Dictionary = GameState.get_destination()["orbits"]

	for orbit_id in orbits:
		if orbit_id.begins_with("_"):
			continue   # skip the "_readme" note
		var fuel: float = orbits[orbit_id]["fuel_mass"]["value"]
		var words: Dictionary = Data.story["orbits"][mission][orbit_id]

		# For example "Fuel to get there: 200 kg".
		var fuel_text: String = "%s: %s %s" % [
			screen_text["fuel_word"], GameState.fmt(fuel), Data.resources["mass"]["unit"],
		]

		var card = CHOICE_CARD.instantiate()
		cards_row.add_child(card)
		card.setup(words["name"], "", words["description"], words["button"])
		card.set_extra(fuel_text)
		cards.append(card)
		card.chosen.connect(_on_orbit_chosen.bind(orbit_id))


# The mission id used to find the words, for example "mars".
# If you press Play on this screen directly, nothing is picked yet,
# so we use the first unlocked mission (the same one GameState uses).
func mission_key() -> String:
	if GameState.destination_id != "":
		return GameState.destination_id
	for some_id in Data.destinations:
		if not Data.destinations[some_id]["locked"]["value"]:
			return some_id
	return ""


func _on_orbit_chosen(orbit_id: String) -> void:
	GameState.orbit_id = orbit_id
	print("Orbit chosen: ", orbit_id, "  (fuel ", GameState.get_orbit_fuel_mass(), " kg)")

	for card in cards:
		card.set_locked(true)
	inner_voice.say_then_next(Data.voice["setup"]["orbit"][mission_key()][orbit_id][GameState.level])
