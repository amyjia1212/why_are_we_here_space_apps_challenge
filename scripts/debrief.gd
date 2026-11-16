# debrief.gd
# The last screen: the MISSION REPORT (PLAN.md section 11).
#   Header:    the mission, who designed it, the flight and lifetime, a stamp
#              (MISSION SUCCESS = every checklist goal done, else MISSION
#              FAILED), and the Redesign / New mission buttons.
#   Score:     out of 1000, with its 5 parts (game_data.json "report").
#   Checklist: each goal done [x] or failed [!].
#   Lessons:   "what went well" and "fix next time", 2-3 lines each. Every
#              line names a design choice or a build job.
#   Findings:  one numbered card per problem: what failed, why, how to fix it.
#              A resource card also shows the cause chain (GameState.get_cause_chain).
#   Readings:  the six resources, OK or not.
# The General reads the report out in the speech bar.
# Words: data/inner_voice.json ("debrief") and story.json. Green and red come
# from game_data.json ("dashboard.colors"), the same colors as the dashboard.
extends Control

@onready var mission_name: Label = %MissionName
@onready var report_label: Label = %ReportLabel
@onready var details: Label = %Details
@onready var stamp: PanelContainer = %Stamp
@onready var stamp_text: Label = %StampText
@onready var redesign_button: Button = %RedesignButton
@onready var new_mission_button: Button = %NewMissionButton
@onready var score_label: Label = %ScoreLabel
@onready var score_value: Label = %ScoreValue
@onready var score_lines: VBoxContainer = %ScoreLines
@onready var checklist: VBoxContainer = %Checklist
@onready var went_well_box: VBoxContainer = %WentWell
@onready var fix_next_box: VBoxContainer = %FixNext
@onready var findings_label: Label = %FindingsLabel
@onready var findings_list: VBoxContainer = %Findings
@onready var readings_label: Label = %ReadingsLabel
@onready var readings: GridContainer = %Readings
@onready var inner_voice: PanelContainer = %InnerVoiceBar

var words: Dictionary
var ok_color: Color
var bad_color: Color


func _ready() -> void:
	# Safety net for pressing Play on this screen directly.
	if GameState.character_id == "":
		GameState.character_id = Data.game_data["setup"]["default_character"]
	if GameState.mission_id == "":
		GameState.mission_id = Data.missions.keys()[0]
	GameState.fill_default_choices()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	words = Data.voice["debrief"]
	var colors: Dictionary = Data.game_data["dashboard"]["colors"]
	ok_color = Color.html(colors["safe"])
	bad_color = Color.html(colors["danger"])

	redesign_button.text = words["redesign_button"]
	redesign_button.pressed.connect(_on_redesign_pressed)
	new_mission_button.text = words["new_mission_button"]
	new_mission_button.pressed.connect(_on_new_mission_pressed)

	# Pressing Play here (or skipping the return): decide Depart and Home now.
	if GameState.goal_ids_in_phase("home").any(func(id): return GameState.goals.get(id, "open") == "open"):
		GameState.decide_return()
	var success: bool = GameState.is_mission_success()
	GameState.reach_segment("user")
	GameState.unlock_for_scene("debrief")   # before the score, so a full Dictionary counts (N7)
	fill_header()
	show_stamp(words["success_title"] if success else words["failed_title"], ok_color if success else bad_color)
	Sfx.play("done" if success else "bad")
	fill_score()
	fill_checklist()
	fill_lessons()

	findings_label.text = words["findings_label"]
	var failures: Array = GameState.get_all_failures()
	if failures.is_empty():
		add_success_note()
	else:
		for i in failures.size():
			add_finding(i + 1, failures[i])
	fill_readings()
	add_life_report()
	Achievements.check_report()   # UPGRADE_PLAN_V6 C3: an achievement for every kind of ending
	# A second "Redesign" button at the very bottom, so nobody scrolls back up (UPGRADE_PLAN_V6 A2).
	var bottom_button := Button.new()
	bottom_button.text = words["redesign_button"]
	bottom_button.custom_minimum_size = redesign_button.custom_minimum_size
	bottom_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	bottom_button.pressed.connect(_on_redesign_pressed)
	get_node("Margin/Column/Scroll/Body").add_child(bottom_button)
	# The voice learns (INNOVATION.md Feature B): a failed mission or checkpoint
	# teaches the character the word for the main cause.
	if not success or not failures.is_empty() or not GameState.get_missing_key_instruments().is_empty():
		var learned: Dictionary = Notebook.learn_from_run()
		if not learned.is_empty():
			add_notebook_card(learned)
	var notebook_button := Button.new()
	notebook_button.text = Data.story["notebook"]["button"]
	notebook_button.theme_type_variation = &"SmallButton"
	notebook_button.pressed.connect(Hud.open_page.bind("notebook"))
	new_mission_button.get_parent().add_child(notebook_button)

	# The General reads it out.
	var player: String = GameState.player_name if GameState.player_name != "" else words["general_default_name"]
	inner_voice.set_speaker(words["general_speaker"])
	inner_voice.say(words["general_success" if success else "general_failed"].format({"name": player}))
	AudioManager.play_music("win" if success else "fail")
	add_to_leaderboard()


# The new notebook word, first in the findings: the word, what it means, and
# what happened in this run (with this run's real numbers).
func add_notebook_card(learned: Dictionary) -> void:
	var words: Dictionary = Data.story["notebook"]
	var t: Dictionary = Notebook.term(learned["id"])
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardSelected"   # the one amber thing: you learned something
	# At the very top of the report's scrolling part, so it is seen right away.
	var body: VBoxContainer = get_node("Margin/Column/Scroll/Body")
	body.add_child(card)
	body.move_child(card, 1)   # right under the header (the header scrolls with the page since 2026-11-15)
	var column := VBoxContainer.new()
	card.add_child(column)
	add_line(column, words["new_word_title" if learned["new"] else "known_word_title"].format({"word": t["word"]}), &"HeadingText")
	add_line(column, t["meaning"], &"BodyText").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if str(learned["run"]) != "":
		add_line(column, words["this_run"] + " " + learned["run"], &"SmallText").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if learned["new"]:
		Hud.flash(words["new_word_flash"].format({"word": t["word"]}))
		AudioManager.play_sfx("stamp")


# Save this run on the leaderboard (UPGRADE_PLAN_V2 step 12) and show it,
# with the new run highlighted. In a solo game, the bot crewmates' scores
# show too (step 27); they are for show and never change the result.
func add_to_leaderboard() -> void:
	if not GameState.run_recorded:
		GameState.run_recorded = true
		Leaderboard.add_run(GameState.get_report_score()["total"])
		Bots.add_scores_to_leaderboard()
	var button := Button.new()
	button.text = Data.story["leaderboard"]["title"]
	button.theme_type_variation = &"SmallButton"
	button.pressed.connect(Hud.open_page.bind("leaderboard"))
	new_mission_button.get_parent().add_child(button)
	await get_tree().create_timer(float(Data.game_data["leaderboard"]["show_after_seconds"])).timeout
	if is_inside_tree() and Hud.page == "":
		Hud.open_page("leaderboard")


# The top of the report: mission name, designer, flight days, lifetime.
func fill_header() -> void:
	# The first line: NASA's User segment, the scientists who use the data (N2).
	report_label.text = Data.story["nasa"]["user_segment_line"]
	report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # a long line must not push the page wider
	var place: Dictionary = Data.story["destinations"][GameState.get_destination_key()]
	mission_name.text = place["name"] + ": " + place["goal"]
	var designer: String = Data.story["characters"][GameState.character_id]["name"]
	if GameState.player_name != "":
		designer = GameState.player_name + " (" + designer + ")"   # for example: Sam (The Janitor)
	var days: String = words["flight_value"].format({"days": int(GameState.get_trip_days())})   # with the launch date (extras)
	var lifetime: float = GameState.get_totals()["mission_lifetime"] - GameState.lifetime_lost
	var months: String = GameState.fmt(lifetime) + " " + Data.resources["mission_lifetime"]["unit"]
	details.text = "%s %s      %s %s      %s %s" % [
		words["designer_label"], designer, words["flight_label"], days, words["lifetime_label"], months,
	]


# The big stamp: a colored box with a thick colored border, like a rubber
# stamp on a paper report.
func show_stamp(title: String, color: Color) -> void:
	stamp_text.text = title.to_upper()
	stamp_text.add_theme_color_override("font_color", color)

	var style: StyleBoxFlat = get_theme_stylebox("panel", &"NavyPanel").duplicate()
	style.border_color = color
	style.set_border_width_all(3)   # a status stamp: the one bordered thing on the report
	style.bg_color = Color(color, 0.12)   # the same color, almost see-through
	stamp.add_theme_stylebox_override("panel", style)


# "640 / 1000", and one line per part: "Goals met: 267 / 400".
func fill_score() -> void:
	# The score sits at the top of its panel: the 8-item checklist next to it
	# makes the row tall, and centered it would slide out of view.
	score_label.get_parent().size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	score_lines.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var score: Dictionary = GameState.get_report_score()
	var weights: Dictionary = Data.game_data["report"]["weights"]
	score_label.text = words["score_label"]
	score_value.text = words["score_value"].format({"score": score["total"], "max": score["max"]})
	# The score counts up from 0 (UI_POLISH_PLAN_V4 section 4 extra; 0.3 s, via the shared motion helper).
	var score_words: String = words["score_value"]
	var score_max = score["max"]
	preload("res://scripts/ui_kit.gd").count_to(score_value, 0.0, float(score["total"]), func(v): return score_words.format({"score": int(round(v)), "max": score_max}))
	for part_id in score["parts"]:
		add_line(score_lines, words["score_line"].format({
			"name": words["score_parts"][solo_key(part_id)],
			"points": score["parts"][part_id],
			"max": int(weights.get(part_id, Data.nasa["dictionary_bonus"]["points"])),
		}), &"SmallText")


# The first twin whose instrument was packed; the last one (no instrument) is the fallback.
func mission_twin() -> Dictionary:
	for twin in GameState.get_destination().get("twins", {}).get("list", []):
		if not twin.has("when_packed") or GameState.is_instrument_packed(twin["when_packed"]):
			return twin
	return {}


# With one player there is no team: "teamwork" becomes "teamwork_solo" (inner_voice.json).
func solo_key(key: String) -> String:
	if key == "teamwork" and GameState.player_count <= 1:
		return "teamwork_solo"
	return key


# The full checklist, grouped by phase (UPGRADE_PLAN_V3 A3), with the two
# return lines (Smooth / Rough) under it.
func fill_checklist() -> void:
	add_line(checklist, words["checklist_label"] + " · " + GameState.checklist_progress_text(), &"AccentText")
	var marks: Dictionary = Data.story["arrival_screen"]["marks"]
	var goal_words: Dictionary = Data.story["destinations"][GameState.get_destination_key()]["goals"]
	var phase_words: Dictionary = Data.story["checklist"]["phases"]
	for group in GameState.checklist_by_phase():
		for goal_id in group["ids"]:
			var state: String = GameState.goals.get(goal_id, "open")
			var line: Label = add_line(checklist, marks[state] + " " + phase_words.get(group["phase"], "") + ": " + goal_words[goal_id], &"SmallText")
			line.add_theme_color_override("font_color", ok_color if state == "done" else bad_color)
	for return_line in GameState.return_lines():
		add_line(checklist, return_line, &"TinyText")
	# Your mission twin: the real mission most like this design (N5).
	var twin: Dictionary = mission_twin()
	if not twin.is_empty():
		var nasa_words: Dictionary = Data.story["nasa"]
		add_line(checklist, nasa_words["twin_label"], &"AccentText")
		add_line(checklist, nasa_words["twin_line"].format(twin), &"SmallText")
	# What happens to the spacecraft when it is finished (N3; moved here from
	# the briefing when the briefing became four short cards, UPGRADE_PLAN_V3 B3).
	var end_words: Dictionary = Data.story["nasa"]
	add_line(checklist, end_words["end_of_mission_label"] + ": " + end_words["end_of_mission"][GameState.get_destination_key()]["text"], &"TinyText")
	add_patch_and_postcards()


# The extras (2026-11-14): the photos snapped at the ship's windows with the
# list of sightings. (The mission patch was removed, UPGRADE_PLAN_V3 A1.)
func add_patch_and_postcards() -> void:
	var extra_words: Dictionary = Data.story["extras"]
	var cards_box := VBoxContainer.new()
	cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	checklist.add_child(cards_box)
	var spot_words: Dictionary = extra_words["spotting"]
	add_line(cards_box, spot_words["report_title"], &"AccentText")
	if GameState.postcards.is_empty() and GameState.sightings.is_empty():
		add_line(cards_box, spot_words["none"], &"TinyText").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	var photos := HBoxContainer.new()
	photos.add_theme_constant_override("separation", 8)
	cards_box.add_child(photos)
	for image in GameState.postcards:
		var picture := TextureRect.new()
		picture.texture = ImageTexture.create_from_image(image)
		picture.custom_minimum_size = Vector2(128, 72)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		photos.add_child(picture)
	var names: PackedStringArray = []
	for body_id in GameState.sightings:
		names.append(spot_words["names"].get(body_id, body_id))
	if not names.is_empty():
		add_line(cards_box, spot_words["sightings_line"].format({"list": ", ".join(names)}), &"TinyText").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


# "What went well" and "Fix next time": up to max_lines each.
func fill_lessons() -> void:
	var max_lines: int = int(Data.game_data["report"]["max_lines"])
	var good: Array = went_well_lines()
	var bad: Array = fix_next_lines()

	add_line(went_well_box, words["went_well_label"], &"AccentText")
	if good.is_empty():
		good = [words["went_well_none"]]
	for i in mini(good.size(), max_lines):
		add_line(went_well_box, "+ " + good[i], &"SmallText").add_theme_color_override("font_color", ok_color)

	add_line(fix_next_box, words["fix_next_label"], &"AccentText")
	if bad.is_empty():
		bad = [words["fix_none"]]
	for i in mini(bad.size(), max_lines):
		add_line(fix_next_box, "- " + bad[i], &"SmallText").add_theme_color_override("font_color", bad_color if bad[i] != words["fix_none"] else ok_color)


# Good things, most important first: goals, then flight events, then the
# build (resources, teamwork).
func went_well_lines() -> Array:
	var lines: Array = []
	var good: Dictionary = words["went_well"]
	for goal_id in GameState.goals:
		if GameState.goals[goal_id] == "done" and good.has(goal_id):
			lines.append(good[goal_id])
	var computer: String = Data.version_name("computer", GameState.choices["computer"]).to_lower()
	for outcome in GameState.flight_outcomes:
		# "saved" = build quality fixed it; "fixed" = the player fixed it on the ship in time.
		var key: String = outcome["event"] + {"saved": "_saved", "fixed": "_fixed"}.get(outcome["result"], "")
		if outcome["result"] != "bad" and good.has(key):
			lines.append(good[key].format({"computer": computer}))
	if GameState.get_failed_resources().is_empty():
		lines.append(good["resources"])
	var teamwork: float = GameState.get_teamwork_average()
	if teamwork >= Data.game_data["report"]["good_teamwork"]:
		lines.append(good[solo_key("teamwork")].format({"score": GameState.fmt(teamwork)}))
	return lines


# One "fix" line per problem: "Solar flare: pick a better computer..."
# Missed goals (arrival_...) come first: they matter most.
func fix_next_lines() -> Array:
	var lines: Array = []
	var failures: Array = GameState.get_all_failures()
	var ordered: Array = failures.filter(func(id): return id.begins_with("arrival_"))
	ordered += failures.filter(func(id): return not id.begins_with("arrival_"))
	for failure_id in ordered:
		var text: Dictionary = Data.voice["resource_failures"][failure_id]
		lines.append(words["fix_line"].format({"title": text.get("title", resource_name(failure_id)), "fix": text["fix"]}))
	return lines


func add_line(box: VBoxContainer, text: String, style: StringName) -> Label:
	var line := Label.new()
	line.text = text
	line.theme_type_variation = style
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(line)
	return line


# One numbered card for one problem, with what / why / fix side by side.
func add_finding(number: int, failure_id: String) -> void:
	var text: Dictionary = Data.voice["resource_failures"][failure_id]

	# A card from the theme; the red title says it is a problem (no borders, UI_POLISH_PLAN_V4).
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	findings_list.add_child(card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)

	# "Finding 1: Data"
	var title := Label.new()
	var card_title: String = text.get("title", resource_name(failure_id))   # a card can have its own title
	title.text = "%s %d: %s" % [words["finding_word"], number, card_title]
	title.theme_type_variation = &"HeadingText"
	title.add_theme_color_override("font_color", bad_color)
	column.add_child(title)

	# The cause chain (2026-11-14): "Heavy instrument → more mass → bigger rocket → budget gone".
	var chain: Array = GameState.get_cause_chain(failure_id)
	if chain.size() > 1:
		var chain_words: Dictionary = Data.story["cause_chain"]
		var chain_box := VBoxContainer.new()
		chain_box.add_theme_constant_override("separation", 4)
		column.add_child(chain_box)
		var chain_heading := Label.new()
		chain_heading.text = chain_words["label"]
		chain_heading.theme_type_variation = &"AccentText"
		chain_box.add_child(chain_heading)
		var chain_label := Label.new()
		chain_label.text = chain_words["arrow"].join(PackedStringArray(chain))
		chain_label.theme_type_variation = &"BodyText"
		chain_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		chain_label.add_theme_color_override("font_color", bad_color)
		chain_box.add_child(chain_label)

	# The three parts in three columns. fill_blanks() puts in the real numbers.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	column.add_child(row)
	add_part(row, words["what_label"], GameState.fill_blanks(text["what"], failure_id))
	add_part(row, words["why_label"], text["why"])
	add_part(row, words["fix_label"], text["fix"])


# An orange heading with its text underneath, as one of the three columns.
func add_part(row: HBoxContainer, heading: String, body: String) -> void:
	var part := VBoxContainer.new()
	part.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # 3 equal columns
	part.add_theme_constant_override("separation", 4)
	row.add_child(part)

	var heading_label := Label.new()
	heading_label.text = heading
	heading_label.theme_type_variation = &"AccentText"   # orange, from the theme
	part.add_child(heading_label)

	var body_label := Label.new()
	body_label.text = body
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.theme_type_variation = &"BodyText"
	part.add_child(body_label)


# "data_live" and "power_event" are about Data and Power: show those names.
func resource_name(failure_id: String) -> String:
	var res_id: String = failure_id.trim_suffix("_live").trim_suffix("_event")
	if Data.resources.has(res_id):
		return Data.resources[res_id]["name"]
	return failure_id


# No problems: one green card instead of the findings.
func add_success_note() -> void:
	findings_label.visible = false
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	findings_list.add_child(card)

	var note := Label.new()
	note.text = words["success_note"]
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.theme_type_variation = &"BodyText"
	note.add_theme_color_override("font_color", ok_color)
	card.add_child(note)


# The table of the six resources (the build totals from Review).
func fill_readings() -> void:
	readings_label.text = words["readings_label"]
	for key in ["header_resource", "header_end", "header_limit", "header_result"]:
		add_cell(words[key], get_theme_color("font_color", &"AccentText"))

	var ended: bool = not GameState.end_values.is_empty()
	var values: Dictionary = GameState.end_values if ended else GameState.get_totals()
	var limits: Dictionary = GameState.end_limits if ended else GameState.get_limits()
	var review_words: Dictionary = Data.story["review_screen"]
	var build_words: Dictionary = Data.story["build_screen"]

	for res_id in Data.resources:
		var resource: Dictionary = Data.resources[res_id]
		var limit: Dictionary = limits[res_id]
		var ok: bool = GameState.is_ok(values[res_id], limit)
		var unit: String = resource.get("live_unit", resource["unit"]) if ended else resource["unit"]
		var rule_word: String = build_words["max_word"] if limit["rule"] == "max" else build_words["min_word"]

		var result: String = review_words["ok_word"]
		if not ok:
			result = review_words["over_word"] if limit["rule"] == "max" else review_words["under_word"]
		var color: Color = ok_color if ok else bad_color

		add_cell(resource["name"], color)
		add_cell(GameState.fmt(values[res_id]) + " " + unit, color)
		add_cell(rule_word + " " + GameState.fmt(limit["value"]), Color.WHITE)
		add_cell(result, color)


func add_cell(text: String, color: Color) -> void:
	var cell := Label.new()
	cell.text = text
	cell.theme_type_variation = &"BodyText"
	cell.add_theme_color_override("font_color", color)
	readings.add_child(cell)


# "Life on the ship" (UPGRADE_PLAN_V6 C2): what the player did on the way.
func add_life_report() -> void:
	var w: Dictionary = Data.story["life_report"]
	var trip: Dictionary = GameState.ship_log
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"NavyPanel"
	get_node("Margin/Column/Scroll/Body").add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	add_line(column, w["title"], &"AccentText")
	add_line(column, w["meals"].format({"n": int(trip.get("meals", 0))}), &"BodyText")
	add_line(column, w["drinks"].format({"n": int(trip.get("drinks", 0))}), &"BodyText")
	add_line(column, w["filters"].format({"n": int(trip.get("filters", 0))}), &"BodyText")
	var names: Array = []
	for crew_id in trip.get("crew_talks", []):
		names.append(Data.crew["people"][crew_id]["name"])
	add_line(column, w["crew"].format({"names": ", ".join(PackedStringArray(names)) if not names.is_empty() else w["nobody"]}), &"BodyText")
	add_line(column, w["learned"].format({"n": trip.get("stations_learned", []).size()}), &"BodyText")
	if int(trip.get("trips_failed", 0)) > 0:
		add_line(column, w["failed"].format({"n": int(trip["trips_failed"])}), &"BodyText")
	add_line(column, w["tip"], &"SmallText")


# Keep the whole design, fly again (the player changes one thing).
func _on_redesign_pressed() -> void:
	redesign_button.disabled = true
	GameState.start_retry()   # UPGRADE_PLAN_V6 B3: the retry depends on the character
	StageManager.go_to(Data.game_data["stages"]["redesign_to"])


# Start over with a new mission. Name, character and players stay.
func _on_new_mission_pressed() -> void:
	new_mission_button.disabled = true
	GameState.start_new_mission()
	StageManager.go_to(Data.game_data["stages"]["new_mission_to"])
