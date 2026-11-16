# Data.gd
# This script reads our JSON files ONE time, when the game starts.
# It is an "autoload": Godot keeps it alive the whole game, and every
# other script can reach it by its name, like this:  Data.parts
#
# There are NO game numbers in this file. They all live in data/game_data.json.
extends Node

# These variables hold what we read from the files.
# Other scripts read them, for example: Data.parts["camera"]
var game_data: Dictionary = {}
var story: Dictionary = {}
var voice: Dictionary = {}

# Shortcuts to the parts of game_data we use the most.
var resources: Dictionary = {}
var parts: Dictionary = {}
var missions: Dictionary = {}
var characters: Dictionary = {}
var destinations: Dictionary = {}   # from data/destinations.json
var timing: Dictionary = {}   # from data/timing.json (launch moments)
var levels: Dictionary = {}   # from data/levels.json: what each level changes
var supplies: Dictionary = {}   # from data/supplies.json: crew food, water and air
var events: Dictionary = {}   # from data/events.json: the old water leak (archived Life Support)
var flight: Dictionary = {}   # from data/events.json "flight": the Flight screen and its events
var launch_events: Dictionary = {}   # from data/events.json "launch_events": the launch surprises
var minigames: Dictionary = {}   # from data/minigames.json: player count and the 3 build minigames
var audio: Dictionary = {}   # from data/audio.json: music, beep-talk voices, volume sliders
var nasa: Dictionary = {}    # from data/nasa_resources.json: NASA resources, segments, CML, Space Dictionary
var extras: Dictionary = {}  # from data/extras.json: the extra features (launch window, patch, clean room...)
var crew: Dictionary = {}    # from data/crew.json: the real astronauts on the ship (UPGRADE_PLAN_V6 C1)
var achievements: Dictionary = {}   # from data/achievements.json (UPGRADE_PLAN_V6 C3)
var mp: Dictionary = {}   # from data/multiplayer.json: parties, bots, voting, team-size scaling (MULTIPLAYER_PLAN_V6)


# _ready() runs automatically when this node starts.
func _ready() -> void:
	game_data = load_json("res://data/game_data.json")
	story = load_json("res://data/story.json")
	voice = load_json("res://data/inner_voice.json")
	levels = load_json("res://data/levels.json").get("levels", {})
	timing = load_json("res://data/timing.json")
	destinations = load_json("res://data/destinations.json").get("destinations", {})
	supplies = load_json("res://data/supplies.json")
	var events_file: Dictionary = load_json("res://data/events.json")
	events = events_file.get("events", {})
	flight = events_file.get("flight", {})
	launch_events = events_file.get("launch_events", {})
	minigames = load_json("res://data/minigames.json")
	audio = load_json("res://data/audio.json")
	nasa = load_json("res://data/nasa_resources.json")
	extras = load_json("res://data/extras.json")
	crew = load_json("res://data/crew.json")
	achievements = load_json("res://data/achievements.json")
	mp = load_json("res://data/multiplayer.json")

	resources = game_data.get("resources", {})
	parts = game_data.get("parts", {})
	missions = game_data.get("missions", {})
	characters = game_data.get("characters", {})

	print_summary()


# Opens one JSON file and turns it into a Dictionary
# (a list of "name: value" pairs).
func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing file: " + path)
		return {}

	var text := FileAccess.get_file_as_string(path)
	var result = JSON.parse_string(text)

	# If someone made a typo in the JSON (like a missing comma),
	# parse_string gives back null. We say so clearly.
	if result == null:
		push_error("This file has a typo and could not be read: " + path)
		return {}

	return result


# A part's name on screen, for example "Solar panel" (story.json "parts").
func part_name(part_id: String) -> String:
	return story["parts"][part_id]["name"]


# A part card's name on screen, for example "Large".
func version_name(part_id: String, version_id: String) -> String:
	return story["parts"][part_id]["versions"][version_id]["name"]


# Prints what we loaded, so we can check it in the Output panel.
func print_summary() -> void:
	print("=== Data loaded ===")
	print("Resources: ", resources.keys())

	for part_id in parts:
		print(part_name(part_id), " versions: ", parts[part_id]["versions"].keys())

	for mission_id in missions:
		print("Mission ", mission_id, " limits:")
		var limits: Dictionary = missions[mission_id]["limits"]
		for res_id in limits:
			var limit: Dictionary = limits[res_id]
			# A limit has a fixed "value", or comes from somewhere else ("value_from").
			var shown = limit.get("value", "from " + str(limit.get("value_from", "?")))
			print("   ", res_id, "  ", limit["rule"], " ", shown, "  (", limit["source"], ")")

	print("Intro cutscene, the one who quits: ", story["cutscene_intro"]["subtitles"]["commander_quit"]["speaker"])
	print("Inner voice, walk start: ", voice["walk"]["start"])
	print("=== End of data ===")
