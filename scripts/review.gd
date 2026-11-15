# review.gd
# The review screen: a table of the six resources, with each one marked
# OK (green) or a problem (red). Under it, a red list of "blockers": one
# line for each problem, with the reason. The player can still launch
# (PLAN.md 6d: failing teaches). The inner voice comments at the bottom.
extends Control

const OK_COLOR := Color(0.45, 0.9, 0.55)
const BAD_COLOR := Color(1, 0.38, 0.38)

@onready var title_label: Label = %Title
@onready var table: GridContainer = %Table
@onready var blockers_label: Label = %Blockers
@onready var back_button: Button = %BackButton
@onready var launch_button: Button = %LaunchButton
@onready var inner_voice: PanelContainer = %InnerVoiceBar

var words: Dictionary   # the review_screen text from story.json


func _ready() -> void:
	# Safety net for pressing Play on this screen directly.
	if GameState.character_id == "":
		GameState.character_id = Data.game_data["setup"]["default_character"]
	if GameState.mission_id == "":
		GameState.mission_id = Data.missions.keys()[0]
	GameState.fill_default_choices()

	words = Data.story["review_screen"]
	equipment = Data.story["nasa"]["equipment"]
	# NASA calls this step Verification; the list is the Mission Design Lab's
	# Equipment List (NASA_RESOURCES_PLAN.md N3).
	title_label.text = equipment["title"]
	back_button.text = words["back_button"]
	launch_button.text = words["launch_button"]
	back_button.pressed.connect(_on_back_pressed)
	launch_button.pressed.connect(_on_launch_pressed)
	var office := Button.new()
	office.text = Data.story["nasa"]["office_hours_button"]
	office.custom_minimum_size = Vector2(0, 46)
	office.pressed.connect(func(): inner_voice.say(GameState.office_hours_line()))
	# UI_POLISH_PLAN_V4 Step 5: one amber button (Launch, bottom right); Back is
	# quiet text at the bottom left; Office Hours is a quiet button.
	var buttons: HBoxContainer = launch_button.get_parent()
	back_button.theme_type_variation = &"QuietButton"
	back_button.custom_minimum_size.x = 0
	office.theme_type_variation = &"SmallButton"
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	buttons.add_child(office)
	buttons.move_child(launch_button, buttons.get_child_count() - 1)

	make_columns()
	fill_equipment()
	fill_table()
	fill_blockers()
	inner_voice_comment()


var equipment: Dictionary       # story.json "nasa" > "equipment"
var checks_box: VBoxContainer   # the right column: the checks and the blockers


# Left: the Equipment List (the scene's table). Right: the checks.
func make_columns() -> void:
	var table_panel: Control = table.get_parent().get_parent()
	var column: VBoxContainer = table_panel.get_parent()
	# Room at the top for the Hud's mission segment strip, and a tighter column.
	var margin: MarginContainer = column.get_parent()
	margin.add_theme_constant_override("margin_top", 80)
	back_button.custom_minimum_size.y = 46
	launch_button.custom_minimum_size.y = 46
	column.add_theme_constant_override("separation", 8)
	title_label.theme_type_variation = &"HeadingText"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	column.add_child(row)
	column.move_child(row, table_panel.get_index())
	table_panel.reparent(row)
	table_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	checks_box = VBoxContainer.new()
	checks_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	checks_box.custom_minimum_size.x = 440
	checks_box.add_theme_constant_override("separation", 4)
	row.add_child(checks_box)
	blockers_label.reparent(checks_box)
	blockers_label.theme_type_variation = &"TinyText"   # the long blocker sentences are small print; the checks above are body size


# One line per item: mass, power and cost, and the totals at the bottom.
# Power: + makes power, - uses it. The totals are the six-resource totals.
func fill_equipment() -> void:
	table.columns = 4
	table.add_theme_constant_override("h_separation", 24)
	table.add_theme_constant_override("v_separation", 0)   # body-size rows (18) need the room
	# The first header cell names the list: "Equipment List", then the columns.
	var headers: Array = equipment["header"].duplicate()
	headers[0] = equipment["list_label"]
	for i in headers.size():
		if i == 0:
			add_title_cell(headers[i])
		else:
			add_row_cell(headers[i], true)
	add_item(equipment["body"], Data.game_data["spacecraft_base"]["effects"])
	for part_id in Data.parts:
		var version_id: String = GameState.choices[part_id]
		# "Power: Large solar panel". A one-word card ("Large") gets the part's short name.
		var card: String = Data.version_name(part_id, version_id)
		if not card.contains(" "):
			card += " " + str(Data.story["parts"][part_id]["tab"]).to_lower()
		add_item(equipment["part"].format({
			"discipline": Data.story["nasa"]["disciplines"].get(part_id, ""),
			"card": card,
		}), Data.parts[part_id]["versions"][version_id]["effects"])
	var instruments: Dictionary = GameState.get_instruments()
	for instrument_id in GameState.instruments_packed:
		if instruments.has(instrument_id):
			add_item(equipment["instrument"].format({"name": instrument_text(instrument_id)["name"]}), instruments[instrument_id]["effects"])
	var vehicle_id: String = GameState.get_launch_vehicle_id()
	add_item(equipment["rocket"].format({"name": Data.story["launch_vehicles"][vehicle_id]["name"]}), {"budget": Data.game_data["launch_vehicles"]["vehicles"][vehicle_id]["cost"]})
	var orbit_id: String = GameState.get_orbit_id()
	add_item(equipment["orbit_fuel"].format({"name": Data.story["orbits"][GameState.get_destination_key()][orbit_id]["name"]}), {"mass": GameState.get_destination()["orbits"][orbit_id]["fuel_mass"]["value"]})
	var totals: Dictionary = GameState.get_totals()
	add_row_cell(equipment["total"], true)
	add_row_cell(GameState.fmt(totals["mass"]), true)
	add_row_cell(GameState.fmt(totals["power"]), true)
	add_row_cell(GameState.fmt(totals["budget"]), true)


func add_item(name_text: String, effects: Dictionary) -> void:
	add_row_cell(name_text, false)
	for res_id in ["mass", "power", "budget"]:
		var value: float = float(effects.get(res_id, 0.0))
		var text: String = equipment["none"] if value == 0.0 else (("+" if res_id == "power" and value > 0.0 else "") + GameState.fmt(value))
		add_row_cell(text, false)


func add_row_cell(text: String, bold: bool) -> void:
	var cell := Label.new()
	cell.text = text
	cell.theme_type_variation = &"BodyText" if bold else &"SmallText"
	# Names left, numbers right, so the numbers line up in columns (Step 1).
	if table.get_child_count() % table.columns != 0:
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	table.add_child(cell)


func add_title_cell(text: String) -> void:
	var cell := Label.new()
	cell.text = text
	cell.theme_type_variation = &"AccentText"
	table.add_child(cell)


# One line per check, green or red (UPGRADE_PLAN_V2 step 14), for example
#   [OK] Budget: 570 million $ (max 671)
#   [X] Communications: 0.1 Mb/s (min 0.6) - too low
#   [OK] Key instrument packed: Ice drill
func fill_table() -> void:
	var title := Label.new()
	title.text = equipment["checks_label"]
	title.theme_type_variation = &"AccentText"
	checks_box.add_child(title)
	checks_box.move_child(title, 0)
	var totals: Dictionary = GameState.get_totals()
	var limits: Dictionary = GameState.get_limits()
	for res_id in Data.resources:
		var resource: Dictionary = Data.resources[res_id]
		var limit: Dictionary = limits[res_id]
		var ok: bool = GameState.is_ok(totals[res_id], limit)
		var rule_word: String = Data.story["build_screen"]["max_word"] if limit["rule"] == "max" else Data.story["build_screen"]["min_word"]
		var line: String = words["check_line"].format({
			"mark": words["ok_mark"] if ok else words["bad_mark"],
			"name": resource["name"],
			"value": GameState.fmt(totals[res_id]),
			"unit": resource["unit"],
			"rule": rule_word,
			"limit": GameState.fmt(limit["value"]),
		})
		if not ok:
			line += " - " + (words["over_word"] if limit["rule"] == "max" else words["under_word"])
		add_cell(line, OK_COLOR if ok else BAD_COLOR)
	# The key instruments for the goal.
	for instrument_id in GameState.get_key_instruments():
		var packed: bool = GameState.is_instrument_packed(instrument_id)
		var template: String = words["instrument_ok_line"] if packed else words["instrument_missing_line"]
		add_cell(template.format({
			"mark": words["ok_mark"] if packed else words["bad_mark"],
			"instrument": instrument_text(instrument_id)["name"],
		}), OK_COLOR if packed else BAD_COLOR)


# One red line per resource that breaks its limit, for example:
#   - Too heavy: 1087 kg with the orbit fuel, but the Small rocket can only lift 1000.
# The sentences are in story.json ("review_screen", "blockers").
func fill_blockers() -> void:
	var failed: Array = GameState.get_failed_resources()
	var missing: Array = GameState.get_missing_key_instruments()
	if failed.is_empty() and missing.is_empty():
		return   # no blockers: the list stays hidden and the button says "Launch mission"

	var totals: Dictionary = GameState.get_totals()
	var limits: Dictionary = GameState.get_limits()
	var rocket_name: String = Data.story["launch_vehicles"][GameState.get_launch_vehicle_id()]["name"]

	var lines: PackedStringArray = [words["blockers_title"]]
	# A missing key instrument comes first: without it the goal can't happen at all.
	for instrument_id in missing:
		var instrument_words: Dictionary = instrument_text(instrument_id)
		lines.append("- " + words["blockers"]["key_instrument"].format({
			"instrument": instrument_words["name"],
			"needed_for": instrument_words.get("needed_for", ""),
		}))
	for res_id in failed:
		lines.append("- " + words["blockers"][res_id].format({
			"value": GameState.fmt(totals[res_id]),
			"limit": GameState.fmt(limits[res_id]["value"]),
			"unit": Data.resources[res_id]["unit"],
			"rocket": rocket_name,
		}))
	blockers_label.text = "\n".join(lines)
	blockers_label.add_theme_color_override("font_color", BAD_COLOR)
	blockers_label.visible = true
	launch_button.text = words["launch_anyway_button"]


func add_cell(text: String, color: Color) -> void:
	var cell := Label.new()
	cell.text = text
	cell.theme_type_variation = &"SmallText"
	cell.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cell.add_theme_color_override("font_color", color)
	checks_box.add_child(cell)
	checks_box.move_child(cell, blockers_label.get_index())   # the checks above the blockers


# What the inner voice says about this build.
func inner_voice_comment() -> void:
	var failed: Array = GameState.get_failed_resources()
	var missing: Array = GameState.get_missing_key_instruments()
	if not missing.is_empty():
		var instrument_name: String = instrument_text(missing[0])["name"]
		inner_voice.say(Data.voice["review"]["missing_key"].format({"instrument": instrument_name.to_lower()}))
	elif failed.is_empty():
		inner_voice.say(Data.voice["review"]["all_good"])
	else:
		# "Something is in the red..." plus the first problem, with numbers filled in.
		var first: String = failed[0]
		var what: String = GameState.fill_blanks(Data.voice["resource_failures"][first]["what"], first)
		inner_voice.say(Data.voice["review"]["some_over"] + " " + what)


# An instrument's words (story.json "instruments"), for example { "name": "Ice drill", ... }
func instrument_text(instrument_id: String) -> Dictionary:
	return Data.story["instruments"][GameState.get_destination_key()][instrument_id]


func _on_back_pressed() -> void:
	StageManager.go_to(Data.game_data["stages"]["redesign_to"])   # Back goes to the design screen


func _on_launch_pressed() -> void:
	# Launch goes on even with blockers. The trouble shows up later.
	GameState.cml_event("review_confirmed")   # CML 4: the real design (N2)
	StageManager.go_next()
