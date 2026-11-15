# Leaderboard.gd
# The best runs on THIS computer (UPGRADE_PLAN_V2 step 12), saved in
# user://leaderboard.json: name, character, mission, score and date.
# (An online board waits for multiplayer.)
#     Leaderboard.add_run(score)   -> the new run's place (0 = first), or -1
#     Leaderboard.runs             -> the list, best first
extends Node

const PATH := "user://leaderboard.json"

var runs: Array = []
var last_added: Dictionary = {}   # the newest run, so the board can highlight it


func _ready() -> void:
	if FileAccess.file_exists(PATH):
		var saved = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if saved is Array:
			runs = saved


# Adds the run that just finished. Bot crewmates (step 27) are added with
# is_bot = true: they show on the board but never change the mission result.
func add_run(score: int, run_name: String = "", character: String = "", is_bot: bool = false) -> int:
	var entry: Dictionary = {
		"name": run_name if run_name != "" else GameState.player_name,
		"character": character if character != "" else GameState.character_id,
		"mission": GameState.get_destination_key(),
		"score": score,
		"date": Time.get_date_string_from_system(),
		"bot": is_bot,
		"id": str(Time.get_ticks_usec()) + str(randi()),
	}
	runs.append(entry)
	runs.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	runs = runs.slice(0, int(Data.game_data["leaderboard"]["size"]))
	save()
	if not is_bot:
		last_added = entry
	return runs.find(entry)


func save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(runs))


# Builds the board as a table, ready to put on any screen. The newest
# player run is highlighted.
func make_table() -> Control:
	var words: Dictionary = Data.story["leaderboard"]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	if runs.is_empty():
		var empty := Label.new()
		empty.text = words["empty"]
		empty.theme_type_variation = &"BodyText"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size.x = 560
		box.add_child(empty)
		return box
	var grid := GridContainer.new()
	grid.columns = words["headers"].size()
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for header in words["headers"]:
		add_cell(grid, header, &"AccentText", false)
	for i in runs.size():
		var run: Dictionary = runs[i]
		var mine: bool = not last_added.is_empty() and run.get("id", "") == last_added.get("id", "")
		var character_words: Dictionary = Data.story["characters"].get(run["character"], {})
		var mission_words: Dictionary = Data.story["destinations"].get(run["mission"], {})
		var shown_name: String = str(run["name"])
		if run.get("bot", false):
			shown_name += " " + words["bot_tag"]
		var cells: Array = [str(i + 1), shown_name, character_words.get("name", run["character"]),
				mission_words.get("name", run["mission"]), str(run["score"]), str(run["date"])]
		if mine:
			cells[1] += " " + words["you_tag"]
		for c in cells.size():
			add_cell(grid, cells[c], &"TableText", mine)
	var note := Label.new()
	note.text = words["note"]
	note.theme_type_variation = &"TinyText"
	box.add_child(note)
	return box


func add_cell(grid: GridContainer, text: String, style: StringName, highlight: bool) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = style
	if highlight:
		label.add_theme_color_override("font_color", label.get_theme_color("caution_color", &"Status"))
	grid.add_child(label)
