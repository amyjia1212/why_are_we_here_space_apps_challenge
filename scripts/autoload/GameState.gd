# GameState.gd
# The game's memory. It remembers what the player picked, so every
# screen can see it. Like Data.gd, it is an autoload, so any script
# can reach it by name, for example:  GameState.mission_id
#
# Data.gd    = what the game KNOWS   (the files, never changes)
# GameState  = what the player DID   (changes as they play)
extends Node

var character_id: String = ""   # for example "janitor"

# The player's level: "easy", "medium" or "hard". It is NOT stored. It is
# looked up from the character every time, so the two can never disagree.
# (The character -> level link is in game_data.json, "characters".)
var level: String:
	get:
		if character_id == "":
			return ""
		return Data.characters[character_id]["level"]

var mission_id: String = ""     # for example "mars_ice"

# Which version of each part the player picked.
# For example: { "solar_panel": "large", "antenna": "small", ... }
var choices: Dictionary = {}

# The science instruments the player packed, for example ["ice_drill", "camera_basic"].
# instruments_set turns true once the start list is filled in, so an
# empty list later really means "the player took everything out".
var instruments_packed: Array = []
var instruments_set: bool = false

# How many players take turns at the build minigames (1 to 4).
var player_count: int = 1
# Every player's score (0-100) in each minigame, in player order.
# For example: { "assembly": [80, 55], "hammer": [90, 70], "fuel": [64, 88] }
var minigame_scores: Dictionary = {}

# Problems that happened DURING the mission (not in the build),
# for example ["power_event"] if the player didn't fix the power alarm.
# Each name must match a section in inner_voice.json "resource_failures".
var event_failures: Array = []


# --- More things the game will remember later (not used by any screen yet) ---
# They start empty or at zero. Later steps will fill them in.
var player_name: String = ""          # what the player typed as their name
var destination_id: String = ""       # where the mission goes
var goal_id: String = ""              # what the mission wants to find out
var launch_vehicle_id: String = ""    # which rocket the player picked
var orbit_id: String = ""             # which orbit the player picked, for example "low"
var crew_supplies: Dictionary = { "food": 0.0, "water": 0.0, "air": 0.0 }
# Launch misses are saved here: "fuel" (percent of fuel lost) and part names
# like "solar_panel" (percent damaged). See add_damage().
var damage: Dictionary = {}
# One entry per timed press: { "stage": "launch", "moment": "liftoff", "result": "Perfect" }
# The result is "Perfect", "Good" or "Miss".
var timing_results: Array = []
var findings: Array = []              # things that went wrong on the way (crew supplies at zero)
# Crew supplies (data/supplies.json). crew_supplies above holds how much is left.
var supplies_started: bool = false    # true once the ship has been stocked
var rationing: bool = false           # true once the player rations the food (Food station)
var leak_active: bool = false         # true while the water leak is pouring (Flight)
var generator_run: bool = false       # true once the player ran the oxygen generator (Air station)


func _ready() -> void:
	# Show the whole state once, so we can see it in the Output panel.
	print("GameState at startup: ", JSON.stringify(to_dict(), "  "))


# Turns the WHOLE state into one dictionary. Later, a checkpoint will save it.
# (duplicate(true) makes a copy, so changing the copy never changes the game.)
func to_dict() -> Dictionary:
	return {
		"player_name": player_name,
		"level": level,
		"character_id": character_id,
		"mission_id": mission_id,
		"destination_id": destination_id,
		"goal_id": goal_id,
		"launch_vehicle_id": launch_vehicle_id,
		"orbit_id": orbit_id,
		"choices": choices.duplicate(true),
		"instruments_packed": instruments_packed.duplicate(true),
		"instruments_set": instruments_set,
		"player_count": player_count,
		"minigame_scores": minigame_scores.duplicate(true),
		"data_sent": data_sent,
		"cash_reserve": cash_reserve,
		"data_rate_factor": data_rate_factor,
		"flight_instruments_off": flight_instruments_off.duplicate(true),
		"flight_outcomes": flight_outcomes.duplicate(true),
		"goals": goals.duplicate(true),
		"goal_progress": goal_progress.duplicate(true),
		"has_sample": has_sample,
		"drill_tries": drill_tries,
		"crew_supplies": crew_supplies.duplicate(true),
		"damage": damage.duplicate(true),
		"timing_results": timing_results.duplicate(true),
		"findings": findings.duplicate(true),
		"supplies_started": supplies_started,
		"rationing": rationing,
		"leak_active": leak_active,
		"generator_run": generator_run,
		"event_failures": event_failures.duplicate(true),
		"mission_months": mission_months,
		"data_collected": data_collected,
		"parts_off": parts_off.duplicate(true),
		"lifetime_lost": lifetime_lost,
		"storm_active": storm_active,
		"end_values": end_values.duplicate(true),
		"end_limits": end_limits.duplicate(true),
		"launch_window_id": launch_window_id,
		"patch": patch.duplicate(true),
	}


# Puts a saved dictionary back into the game. A missing key keeps its
# current value, so an older save still loads.
func from_dict(d: Dictionary) -> void:
	player_name = d.get("player_name", player_name)
	character_id = d.get("character_id", character_id)
	mission_id = d.get("mission_id", mission_id)
	destination_id = d.get("destination_id", destination_id)
	goal_id = d.get("goal_id", goal_id)
	launch_vehicle_id = d.get("launch_vehicle_id", launch_vehicle_id)
	orbit_id = d.get("orbit_id", orbit_id)
	choices = d.get("choices", choices).duplicate(true)
	instruments_packed = d.get("instruments_packed", instruments_packed).duplicate(true)
	instruments_set = d.get("instruments_set", instruments_set)
	player_count = d.get("player_count", player_count)
	minigame_scores = d.get("minigame_scores", minigame_scores).duplicate(true)
	data_sent = d.get("data_sent", data_sent)
	cash_reserve = d.get("cash_reserve", cash_reserve)
	data_rate_factor = d.get("data_rate_factor", data_rate_factor)
	flight_instruments_off = d.get("flight_instruments_off", flight_instruments_off).duplicate(true)
	flight_outcomes = d.get("flight_outcomes", flight_outcomes).duplicate(true)
	goals = d.get("goals", goals).duplicate(true)
	goal_progress = d.get("goal_progress", goal_progress).duplicate(true)
	has_sample = d.get("has_sample", has_sample)
	drill_tries = d.get("drill_tries", drill_tries)
	crew_supplies = d.get("crew_supplies", crew_supplies).duplicate(true)
	damage = d.get("damage", damage).duplicate(true)
	timing_results = d.get("timing_results", timing_results).duplicate(true)
	findings = d.get("findings", findings).duplicate(true)
	supplies_started = d.get("supplies_started", supplies_started)
	rationing = d.get("rationing", rationing)
	leak_active = d.get("leak_active", leak_active)
	generator_run = d.get("generator_run", generator_run)
	event_failures = d.get("event_failures", event_failures).duplicate(true)
	mission_months = d.get("mission_months", mission_months)
	data_collected = d.get("data_collected", data_collected)
	parts_off = d.get("parts_off", parts_off).duplicate(true)
	lifetime_lost = d.get("lifetime_lost", lifetime_lost)
	storm_active = d.get("storm_active", storm_active)
	end_values = d.get("end_values", end_values).duplicate(true)
	end_limits = d.get("end_limits", end_limits).duplicate(true)
	launch_window_id = d.get("launch_window_id", launch_window_id)
	patch = d.get("patch", patch).duplicate(true)


# Everything that went wrong: build problems first, then mission events.
func get_all_failures() -> Array:
	return get_failed_resources() + event_failures


# Clears what happened during the last mission, but keeps the part choices,
# so "Try again" lets the player change just one thing.
func start_new_attempt() -> void:
	run_recorded = false
	segment_reached = -1   # the mission segments light up again from Launch (the CML stays)
	event_failures.clear()
	# The launch starts again too. The parts, name, character and rocket stay.
	damage.clear()
	timing_results.clear()
	# The crew supplies, the findings and the leak start again too.
	clear_supplies()
	findings.clear()
	# The flight and the arrival start again too.
	data_sent = 0.0
	data_rate_factor = 1.0
	flight_instruments_off.clear()
	flight_outcomes.clear()
	lifetime_lost = 0.0
	goals.clear()
	goal_progress.clear()
	has_sample = false
	drill_tries = 0
	# The extras (2026-11-14): photos, sightings, quick fixes and the weather wait start again.
	postcards.clear()
	sightings.clear()
	quick_fixes.clear()
	weather_wait_cost = 0.0
	ice_share = 1.0
	ship_log.clear()   # life on the ship starts again (UPGRADE_PLAN_V6 C2)
	ice_samples = 0


# --- Life on the ship (UPGRADE_PLAN_V6 C2): what the player did on the way ---

# counts: "meals", "drinks", "filters", "trips_failed"; lists: "crew_talks", "stations_learned"
var ship_log: Dictionary = {}
var ice_samples: int = 0   # Mars ice samples analyzed this run (UPGRADE_PLAN_V6 C4)


func ship_log_add(key: String, id: String = "") -> void:
	if id == "":
		ship_log[key] = int(ship_log.get(key, 0)) + 1
		return
	var list: Array = ship_log.get(key, [])
	if not list.has(id):
		list.append(id)
	ship_log[key] = list


# A life bar ran out: the trip starts again, the design stays.
func restart_trip() -> void:
	data_sent = 0.0
	data_rate_factor = 1.0
	flight_instruments_off.clear()
	flight_outcomes.clear()
	quick_fixes.clear()


# --- Retries that fit the character (UPGRADE_PLAN_V6 B3) and "last time" (B4) ---

var last_attempt: Dictionary = {}   # { "choices": {cat: value}, "verdicts": {cat: "good"/"okay"/"bad"}, "missing_key": [...] }
var retry_mode: String = ""         # "guided" (Scientist: arrows) / "fresh" (start the design again) / ""


# Called by the report before "Redesign": remember this run's picks and how each went.
func save_last_attempt() -> void:
	var picks: Dictionary = {
		"rocket": get_launch_vehicle_id(), "orbit": get_orbit_id(), "launch_window": get_launch_window_id(),
		"instruments": instruments_packed.duplicate(),
	}
	for part_id in choices:
		picks[part_id] = choices[part_id]
	var verdicts: Dictionary = {}
	var success: bool = is_mission_success()
	var failed: Array = get_failed_resources()
	# The stations to blame: the most blamed choice for each failed resource.
	var bad: Array = []
	var blamed_some: Array = []
	for res_id in failed:
		var blamed: Dictionary = most_blamed_choice(res_id)
		var cat: String = blamed_category(blamed)
		if cat != "":
			bad.append(cat)
		for c in picks:
			if c != "instruments" and choice_blame(c, res_id) > 0.0:
				blamed_some.append(c)
	var missing: Array = get_missing_key_instruments()
	for cat in picks:
		if cat == "instruments":
			verdicts[cat] = "bad" if not missing.is_empty() else "good"
		elif bad.has(cat):
			verdicts[cat] = "bad"
		elif not success and blamed_some.has(cat):
			verdicts[cat] = "okay"
		else:
			verdicts[cat] = "good"
	last_attempt = {"choices": picks, "verdicts": verdicts, "missing_key": missing, "failed": failed}


# Which Design Lab station a most_blamed_choice() result belongs to ("" = none).
func blamed_category(blamed: Dictionary) -> String:
	if blamed.is_empty():
		return ""
	match blamed["kind"]:
		"rocket":
			return "rocket"
		"orbit":
			return "orbit"
		"window":
			return "launch_window"
		"part":
			for part_id in choices:
				if choice_name(part_id, choices[part_id]) == blamed["name"]:
					return part_id
	return ""


# How much worse this station's pick is for one resource than its best option (0 = best).
func choice_blame(cat: String, res_id: String) -> float:
	if not Data.parts.has(cat):
		return 0.0
	var more_is_good: bool = get_limits()[res_id]["rule"] == "min"
	var versions: Dictionary = Data.parts[cat]["versions"]
	var mine: float = float(versions[choices[cat]]["effects"].get(res_id, 0.0))
	var worst: float = 0.0
	for version_id in versions:
		var other: float = float(versions[version_id]["effects"].get(res_id, 0.0))
		worst = maxf(worst, (other - mine) if more_is_good else (mine - other))
	return worst


# The option to point the Scientist's arrow at on this station ("" = none):
# a missing key instrument, or the version that is best for a resource that failed.
func guide_options(cat: String) -> Array:
	if retry_mode != "guided" or last_attempt.is_empty():
		return []
	if cat == "instruments":
		return last_attempt.get("missing_key", []).filter(func(id): return not instruments_packed.has(id))
	if not Data.parts.has(cat) or last_attempt["verdicts"].get(cat, "good") != "bad":
		return []
	for res_id in last_attempt.get("failed", []):
		var more_is_good: bool = get_limits()[res_id]["rule"] == "min"
		var versions: Dictionary = Data.parts[cat]["versions"]
		var best_id: String = ""
		var best_value: float = 0.0
		for version_id in versions:
			var value: float = float(versions[version_id]["effects"].get(res_id, 0.0))
			if best_id == "" or (value > best_value if more_is_good else value < best_value):
				best_id = version_id
				best_value = value
		if best_id != "":
			return [best_id]
	return []


# "Redesign and fly again", by character: the Scientist keeps the design and is
# guided; the Janitor and the Student pick everything again.
func start_retry() -> void:
	save_last_attempt()
	start_new_attempt()
	var mode: String = str(Data.game_data["stages"].get("retry_by_level", {}).get(level, "guided"))
	retry_mode = mode
	if mode == "fresh":
		choices.clear()
		instruments_packed.clear()
		instruments_set = false
		launch_vehicle_id = ""
		orbit_id = ""
		launch_window_id = ""


# "New mission": forget the whole design and the mission, but keep who
# is playing (name, character, number of players).
func start_new_mission() -> void:
	start_new_attempt()
	choices.clear()
	instruments_packed.clear()
	instruments_set = false
	launch_vehicle_id = ""
	orbit_id = ""
	destination_id = ""
	minigame_scores.clear()
	cml_events.clear()      # a new mission idea starts at CML 0 again
	launch_window_id = ""
	last_attempt.clear()    # "last time" lines are only about the same mission
	retry_mode = ""


# --- The extras (2026-11-14, data/extras.json) --------------------------------
# Launch window, mission patch, window postcards and sightings, quick fixes,
# the weather wait and the vanishing Mars ice.

var launch_window_id: String = ""   # "best", "ok" or "poor" ("" = not picked yet: the default)
var patch: Dictionary = {}          # { "shape": "circle", "color": 0, "icon": "rocket" }
var postcards: Array = []           # Images snapped at the ship windows (this run only, not saved)
var sightings: Array = []           # what was spotted out the windows, for example ["earth", "sun"]
var quick_fixes: Array = []         # { "kind": "event" / "crew", "day": 40 } quick fixes on the ship
var weather_wait_cost: float = 0.0  # million $ spent waiting a day for the weather
var peanuts_eaten: int = 0          # lucky peanuts (they change nothing)
var ice_share: float = 1.0          # how much of the Mars ice sample was left at the analyzer


func get_launch_window_id() -> String:
	if launch_window_id != "":
		return launch_window_id
	return Data.extras["launch_window"]["default"]


func get_launch_window() -> Dictionary:
	return Data.extras["launch_window"]["options"][get_launch_window_id()]


# The trip in days: the mission's trip_days x the launch date's trip_factor.
func get_trip_days() -> float:
	return float(get_destination()["trip_days"]["value"]) * float(get_launch_window()["trip_factor"])


# The patch the player made, or the default one.
func get_patch() -> Dictionary:
	if patch.is_empty():
		return Data.extras["patch"]["default"].duplicate()
	return patch


# --- NASA resources (NASA_RESOURCES_PLAN.md, data/nasa_resources.json) -------
# The four mission segments, the Concept Maturity Level meter and the Space
# Dictionary stamps. The Hud shows them; scripts only report what happened:
#     GameState.cml_event("fit_check")       a CML event (levels go up in order)
#     GameState.reach_segment("space")       a mission segment was reached
#     GameState.unlock_for_scene("review")   dictionary stamps for this screen

const DICTIONARY_PATH := "user://dictionary.json"

var cml_events: Dictionary = {}    # CML event name -> true, for example "mission_picked"
var segment_reached: int = -1      # the furthest segment reached (index in segments "order")
var stamps: Array = []             # Space Dictionary word ids unlocked (saved on this computer)
var stamps_loaded: bool = false


# The CML level now, 0 to 4: each level counts only when every level below it is on.
func get_cml() -> int:
	var level_now: int = 0
	for level in Data.nasa["cml"]["levels"]:
		if not cml_events.has(level["event"]):
			break
		level_now = level["level"]
	return level_now


func get_cml_level_info(level_number: int) -> Dictionary:
	for level in Data.nasa["cml"]["levels"]:
		if int(level["level"]) == level_number:
			return level
	return {}


# Something that can raise the CML happened. A stamp sound and a flash when the level goes up.
func cml_event(event_name: String) -> void:
	if cml_events.has(event_name):
		return
	var before: int = get_cml()
	cml_events[event_name] = true
	var after: int = get_cml()
	if after > before:
		var info: Dictionary = get_cml_level_info(after)
		AudioManager.play_sfx("stamp")
		Hud.flash(Data.story["nasa"]["cml_up"].format({"level": after, "nickname": info.get("nickname", "")}))
		unlock_event("cml")


# A mission segment was reached (the badges light up in order, never go dark).
func reach_segment(segment_id: String) -> void:
	var index: int = Data.nasa["segments"]["order"].find(segment_id)
	if index > segment_reached:
		segment_reached = index


# The segment a screen belongs to ("" = none), from nasa_resources.json "segments".
func segment_for_scene(scene_id: String) -> String:
	var segments: Dictionary = Data.nasa["segments"]
	for segment_id in segments["order"]:
		if segments[segment_id]["scenes"].has(scene_id):
			return segment_id
	return ""


# --- Space Dictionary stamps ---

func load_stamps() -> void:
	stamps_loaded = true
	if FileAccess.file_exists(DICTIONARY_PATH):
		var saved = JSON.parse_string(FileAccess.get_file_as_string(DICTIONARY_PATH))
		if saved is Dictionary:
			stamps = saved.get("stamps", [])


func save_stamps() -> void:
	var file := FileAccess.open(DICTIONARY_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"stamps": stamps}))


func get_stamps() -> Array:
	if not stamps_loaded:
		load_stamps()
	return stamps


func glossary_entry(word_id: String) -> Dictionary:
	for entry in Data.nasa["glossary"]:
		if entry["id"] == word_id:
			return entry
	return {}


func has_full_dictionary() -> bool:
	return get_stamps().size() >= Data.nasa["glossary"].size()


# A new stamp: saved, a stamp sound, and a flash ("Dictionary stamp: Payload · 12 of 30").
func unlock_stamp(word_id: String) -> void:
	if get_stamps().has(word_id) or glossary_entry(word_id).is_empty():
		return
	stamps.append(word_id)
	save_stamps()
	AudioManager.play_sfx("stamp")
	Hud.flash(Data.story["nasa"]["stamp_flash"].format({
		"word": glossary_entry(word_id)["word"], "n": stamps.size(), "total": Data.nasa["glossary"].size(),
	}))
	Hud.newest_stamp = word_id


# --- Real things (UPGRADE_PLAN_V3 C1-C4: nasa_resources.json) ----------------
# An entry ships only when it has a real source: anything whose "status" or
# "source" says PLACEHOLDER stays out of the game.
func is_checked(entry: Dictionary) -> bool:
	return not str(entry.get("status", "")).begins_with("PLACEHOLDER") and not str(entry.get("source", "PLACEHOLDER")).begins_with("PLACEHOLDER")


func real_list(list_name: String) -> Array:
	return Data.nasa.get(list_name, []).filter(func(e): return e is Dictionary and is_checked(e))


# The astronaut fact that belongs on this Q card (or in Mission School), or {}.
func astronaut_fact_for(where_id: String) -> Dictionary:
	for fact in real_list("astronaut_facts"):
		if fact.get("shows_in", []).has(where_id):
			return fact
	return {}


# "Name · mission · one true sentence · source" (UPGRADE_PLAN_V3 C4 format).
func astronaut_fact_line(fact: Dictionary) -> String:
	return "%s · %s · %s · %s" % [fact["name"], fact["mission"], fact["sentence"], fact.get("short_source", "")]


# The Q card for a Choice Room thing (UPGRADE_PLAN_V3 A2): cat = the category,
# option_id = the pedestal you stand at ("" = none). Gives a glossary id or "".
func question_for(cat: String, option_id: String) -> String:
	match cat:
		"character":
			return ""
		"mission":
			return option_id if not glossary_entry(option_id).is_empty() else "mission"
		"rocket":
			return "rocket_" + option_id if not glossary_entry("rocket_" + option_id).is_empty() else "launch_vehicle"
		"launch_window":
			return "launch_window"
		"instruments":
			return "instrument" if option_id != "" else "payload"
	for entry in Data.nasa["glossary"]:
		if entry["unlock"].get("category", "") == cat:
			return entry["id"]
	return ""


func unlock_matching(key: String, value: String) -> void:
	for entry in Data.nasa["glossary"]:
		if entry["unlock"].get(key, "") == value:
			unlock_stamp(entry["id"])


func unlock_for_scene(scene_id: String) -> void:
	unlock_matching("scene", scene_id)


func unlock_for_category(category_id: String) -> void:
	unlock_matching("category", category_id)


func unlock_event(event_name: String) -> void:
	unlock_matching("event", event_name)


# Office Hours (the hint): the first red resource (else the first yellow one),
# said at the level's hint detail. The parts that change that resource come
# from the part data, so the hint is never wrong (inner_voice.json "office_hours").
func office_hours_line() -> String:
	var words: Dictionary = Data.voice["office_hours"]
	var lvl: String = level if words["all_good"].has(level) else "medium"
	var totals: Dictionary = get_totals()
	var limits: Dictionary = get_limits()
	var pick: String = ""
	var kind: String = ""
	for res_id in limits:
		var status: String = get_status(totals[res_id], limits[res_id])
		if status == "danger":
			pick = res_id
			kind = "danger"
			break
		if status == "warning" and pick == "":
			pick = res_id
			kind = "warning"
	if pick == "":
		return words["all_good"][lvl]
	var names: PackedStringArray = []
	if pick == "mass":
		names.append(Data.story["choice_room"]["short_names"]["rocket"])
		names.append(Data.story["choice_room"]["short_names"]["orbit"])
	for part_id in Data.parts:
		for version_id in Data.parts[part_id]["versions"]:
			if float(Data.parts[part_id]["versions"][version_id]["effects"].get(pick, 0.0)) != 0.0:
				names.append(Data.part_name(part_id))
				break
	for instrument in get_instruments().values():
		if float(instrument["effects"].get(pick, 0.0)) != 0.0:
			names.append(Data.story["choice_room"]["short_names"]["instruments"])
			break
	return words["problem"][lvl].format({"warning": Data.voice["dashboard_warnings"][pick][kind], "parts": ", ".join(names)})


# --- The mission report score (game_data.json "report") ---------------------

# The score out of 1000, part by part (PLAN.md section 11). Gives back, e.g.
# { "parts": { "goals": 267, "data": 150, ... }, "total": 640, "max": 1000 }
func get_report_score() -> Dictionary:
	var weights: Dictionary = Data.game_data["report"]["weights"]
	var parts: Dictionary = {}

	# Goals: each goal counts by the share of its tasks done, so placing
	# 2 of 3 seismometers earns 2/3 of that goal (not 0).
	var progress_sum: float = 0.0
	for goal_id in goals:
		progress_sum += 1.0 if goals[goal_id] == "done" else goal_progress.get(goal_id, 0.0)
	parts["goals"] = weights["goals"] * (progress_sum / goals.size() if goals.size() > 0 else 0.0)

	var target: float = get_data_target()
	parts["data"] = weights["data"] * clampf(data_sent / target, 0.0, 1.0)

	# Resources: a green row earns full points, a yellow row (close to the
	# limit) earns a share of them, and a red row earns none.
	var totals: Dictionary = get_totals()
	var limits: Dictionary = get_limits()
	var row_points: float = 0.0
	for res_id in limits:
		match get_status(totals[res_id], limits[res_id]):
			"safe":
				row_points += 1.0
			"warning":
				row_points += Data.game_data["report"]["warning_row_share"]
	parts["resources"] = weights["resources"] * row_points / limits.size()

	parts["build_quality"] = weights["build_quality"] * get_build_result("build_quality") / 100.0
	parts["teamwork"] = weights["teamwork"] * get_teamwork_average() / 100.0

	var total: int = 0
	var most: int = 0
	for part_id in parts:
		parts[part_id] = roundi(parts[part_id])
		total += parts[part_id]
		most += int(weights[part_id])
	# A full Space Dictionary adds a small bonus (nasa_resources.json "dictionary_bonus").
	# The total never goes over the maximum.
	if has_full_dictionary():
		var bonus: int = int(Data.nasa["dictionary_bonus"]["points"])
		parts["dictionary"] = mini(bonus, most - total)
		total += parts["dictionary"]
	return {"parts": parts, "total": total, "max": most}


# The data to send home for full points. A bigger party must gather more
# (MULTIPLAYER_PLAN_V6 3a: multiplayer.json scaling "data_goal"; solo = x1).
func get_data_target() -> float:
	return float(get_destination()["report"]["data_target_gb"]) * Party.scale("data_goal")


# The average of the three minigame team scores (0-100).
func get_teamwork_average() -> float:
	var sum: float = 0.0
	var results: Array = ["build_quality", "structure_strength", "fuel_loaded", "cleanliness"]   # cleanliness = the Clean Room (2026-11-14)
	for result_id in results:
		sum += get_build_result(result_id)
	return sum / results.size()


# Success = every checklist goal done.
func is_mission_success() -> bool:
	if goals.is_empty():
		return false
	return not goals.values().has("open") and not goals.values().has("failed")


# --- The launch (timed presses) -------------------------------------------

# Call when the Launch screen opens: no damage and no results yet, and a
# fresh success checklist (UPGRADE_PLAN_V3 A3).
func start_launch() -> void:
	damage.clear()
	timing_results.clear()
	start_checklist()


# Saves one timed-press result.
func record_press(stage: String, moment_id: String, result: String) -> void:
	timing_results.append({ "stage": stage, "moment": moment_id, "result": result })


# Adds damage (or lost fuel). kind is "fuel" or a part name. amount is a percent.
func add_damage(kind: String, amount: float) -> void:
	damage[kind] = damage.get(kind, 0.0) + amount


# --- Crew supplies (food, water, air) --------------------------------------
# A separate group from the six resources. They show in Flight and Arrival.
# Every number is in data/supplies.json. Each one drops by:
#   (use per person per day) x (crew size) x (game days that passed)

const SUPPLY_IDS: Array = ["food", "water", "air"]


# The destination facts from destinations.json. If none is picked yet (for
# example when you test one screen with F6), use the first unlocked one.
func get_destination() -> Dictionary:
	return Data.destinations[get_destination_key()]


# The destination's id, for example "mars" (the first unlocked one if none is picked).
func get_destination_key() -> String:
	if destination_id != "":
		return destination_id
	for some_id in Data.destinations:
		if not Data.destinations[some_id]["locked"]["value"]:
			return some_id
	return ""


# How many real days one Flight leg stands for: the trip's days split into legs.
func get_flight_leg_days() -> float:
	var trip: Dictionary = get_destination()
	return get_trip_days() / float(trip["flight_legs"]["value"])


# How many real seconds one Flight leg lasts when you play it.
func get_flight_leg_seconds() -> float:
	return float(get_destination()["flight_leg_seconds"]["value"])


# Stock the ship: every supply at its start amount, no rationing, no leak.
func start_supplies() -> void:
	for id in SUPPLY_IDS:
		crew_supplies[id] = float(Data.supplies["start_amount"][id]["value"])
	rationing = false
	leak_active = false
	generator_run = false
	supplies_started = true
	findings.clear()
	for id in SUPPLY_IDS:   # old crew problems from a last try are gone
		event_failures.erase(id + "_empty")
		event_failures.erase(id + "_low")


# Safety net: if the walk starts without a Flight (Play on the walk scene), stock the ship.
# The Flight tasks never happened, so the ship starts as if they were done:
# rationing is on and the oxygen generator ran (supplies.json "walk_alone").
func ensure_supplies() -> void:
	if not supplies_started:
		start_supplies()
		rationing = true
		generator_run = true
		var result: String = Data.supplies["walk_alone"]["air_result"]["value"]
		add_supply("air", Data.supplies["tasks"]["oxygen_generator"]["restore"][result]["value"])


# "Try again": no supplies, no leak, no rationing. (Parts, name, character and rocket stay.)
func clear_supplies() -> void:
	for id in SUPPLY_IDS:
		crew_supplies[id] = 0.0
	rationing = false
	leak_active = false
	generator_run = false
	supplies_started = false


# How much the whole crew uses in one game day.
func get_supply_use_per_day(id: String) -> float:
	var use: float = Data.supplies["per_person_per_day"][id]["value"] * Data.supplies["crew_size"]["value"]
	use *= Party.scale("supply_drain")   # a bigger party drains faster (MULTIPLAYER_PLAN_V6 3a; solo = x1)
	if id == "food" and rationing:
		use *= Data.supplies["tasks"]["ration"]["food_use_factor"]["value"]
	return use


# Some game days passed: the crew used some supplies.
func advance_supplies(days_passed: float) -> void:
	for id in SUPPLY_IDS:
		crew_supplies[id] = maxf(0.0, crew_supplies[id] - get_supply_use_per_day(id) * days_passed)


# The water leak: it pours out liters_per_second every real second.
func drain_leak(delta: float) -> void:
	if leak_active:
		var rate: float = Data.events["water_leak"]["drain_liters_per_second"]["value"]
		crew_supplies["water"] = maxf(0.0, crew_supplies["water"] - rate * delta)


# Put air (or anything else) back, but never above the meter's capacity.
func add_supply(id: String, amount: float) -> void:
	crew_supplies[id] = minf(get_supply_capacity(id), crew_supplies[id] + amount)


func get_supply_capacity(id: String) -> float:
	return float(Data.supplies["capacity"][id]["value"])


# "safe" (green), "warning" (yellow) or "danger" (red). The thresholds are a
# percent of the meter's capacity (supplies.json "status").
func get_supply_status(id: String) -> String:
	var percent: float = crew_supplies[id] / get_supply_capacity(id) * 100.0
	if percent < Data.supplies["status"]["danger_percent"]["value"]:
		return "danger"
	if percent < Data.supplies["status"]["warning_percent"]["value"]:
		return "warning"
	return "safe"


func get_supply_statuses() -> Dictionary:
	var statuses: Dictionary = {}
	for id in SUPPLY_IDS:
		statuses[id] = get_supply_status(id)
	return statuses


# The worst of the three supply colors (the wrist light uses it).
func get_worst_supply_status() -> String:
	var worst := "safe"
	for id in SUPPLY_IDS:
		var status: String = get_supply_status(id)
		if status == "danger":
			return "danger"
		if status == "warning":
			worst = "warning"
	return worst


# A supply at zero is a finding and costs some damage. It happens once per supply.
# It gives back the supplies that just hit zero, so the screen can say something.
func check_empty_supplies() -> Array:
	var just_empty: Array = []
	if not supplies_started:
		return just_empty
	for id in SUPPLY_IDS:
		if crew_supplies[id] <= 0.0 and not event_failures.has(id + "_empty"):
			add_crew_finding(id)
			just_empty.append(id)
	return just_empty


func add_crew_finding(id: String) -> void:
	var cost: Dictionary = Data.supplies["empty_damage"]
	findings.append({ "supply": id, "finding": id + "_empty" })
	event_failures.append(id + "_empty")   # the debrief makes a card from it
	add_damage(cost["kind"], cost["amount"]["value"])


# At the end of Arrival: a supply that is still red is a failure (unless it
# already has its "ran out" finding).
func add_end_of_supply_failures() -> void:
	if not supplies_started:
		return
	for id in SUPPLY_IDS:
		if get_supply_status(id) == "danger" and not event_failures.has(id + "_empty") and not event_failures.has(id + "_low"):
			event_failures.append(id + "_low")


# --- The live mission (3D walk) ------------------------------------------

var mission_months: float = 0.0     # mission time so far, in months
var data_collected: float = 0.0     # science data collected so far
var parts_off: Array = []           # systems turned off, for example ["camera", "heater"]
var lifetime_lost: float = 0.0      # extra months lost while the heater was off
var storm_active: bool = false      # true during the shadow pass (no sunlight on the solar panels)

# The live numbers at the moment the mission ended (for the debrief's blanks).
var end_values: Dictionary = {}
var end_limits: Dictionary = {}


# Call when the walk starts: the clock goes back to zero.
func start_mission() -> void:
	mission_months = 0.0
	data_collected = 0.0
	parts_off.clear()
	lifetime_lost = 0.0
	storm_active = false
	end_values.clear()
	end_limits.clear()


# Call when the walk ends. Any dashboard row that is RED at the end is a
# failure: the player has to keep an eye on their goals the whole mission.
# Rows that already have their own explanation are skipped:
#   - a build failure (it was already red on the Review screen)
#   - power, when the power alarm already failed ("power_event")
# The failure is named "<resource>_live" (for example "data_live") when
# inner_voice.json has a card for it, otherwise just the resource name.
func add_end_of_mission_failures() -> void:
	end_values = get_live_values()
	end_limits = get_live_limits()
	var build_failures: Array = get_failed_resources()
	for res_id in end_values:
		if is_ok(end_values[res_id], end_limits[res_id]):
			continue
		if build_failures.has(res_id):
			continue
		if res_id == "power" and event_failures.has("power_event"):
			continue
		var failure_id: String = res_id + "_live"
		if not Data.voice["resource_failures"].has(failure_id):
			failure_id = res_id
		if not event_failures.has(failure_id):
			event_failures.append(failure_id)
	add_end_of_supply_failures()   # red crew supplies count too


# Call every frame during the walk. delta = real seconds since last frame.
func advance_mission(delta: float) -> void:
	var clock: Dictionary = Data.game_data["mission_clock"]
	var months_passed: float = delta * clock["months_per_second"]
	mission_months += months_passed
	# Data adds up: (data per day right now) x (days that just passed).
	var days_passed: float = months_passed * clock["days_per_month"]
	data_collected += get_running_values()["data"] * days_passed
	# Heater off: the cold wears out the batteries, so lifetime drops faster.
	if parts_off.has("heater"):
		lifetime_lost += delta * Data.game_data["reroute_power"]["heater"]["off_lifetime_months_per_second"]


# Like get_totals(), but parts that are turned off stop giving or using
# the resources listed in "turned_off_parts_stop" (power, data, communications).
func get_running_values() -> Dictionary:
	var values: Dictionary = get_totals()
	var stops: Array = Data.game_data["mission_clock"]["turned_off_parts_stop"]
	for system_id in parts_off:
		var effects: Dictionary = system_effects(system_id)
		for res_id in stops:
			values[res_id] -= effects.get(res_id, 0.0)   # the heater only has power

	# Shadow pass: the solar part makes solar_drop_percent less power,
	# and the batteries give battery_power instead.
	if storm_active:
		var storm: Dictionary = Data.game_data["events"]["power_low"]
		var solar_id: String = storm["solar_part"]
		var solar_power: float = Data.parts[solar_id]["versions"][choices[solar_id]]["effects"]["power"]
		values["power"] -= solar_power * storm["solar_drop_percent"] / 100.0
		values["power"] += storm["battery_power"]
	return values


# --- The power panel's systems (Reroute Power) -------------------------------
# A "system" is something with a switch: the packed instruments (all
# together), the antenna, or the heater (the picked thermal control card).

# What a system gives and uses.
func system_effects(system_id: String) -> Dictionary:
	ensure_choices()
	if system_id == "instruments":
		var sum: Dictionary = {}
		for res_id in Data.resources:
			sum[res_id] = 0.0
		for instrument_id in instruments_packed:
			add_effects(sum, get_instruments()[instrument_id]["effects"])
		return sum
	if system_id == "heater":
		system_id = Data.game_data["reroute_power"]["heater"]["heater_part"]
	return Data.parts[system_id]["versions"][choices[system_id]]["effects"]


# Flip a switch. Turned-off systems go in parts_off, and
# get_running_values() leaves out their power, data and communications.
func set_system_on(system_id: String, on: bool) -> void:
	if on:
		parts_off.erase(system_id)
	elif not parts_off.has(system_id):
		parts_off.append(system_id)


func is_system_on(system_id: String) -> bool:
	return not parts_off.has(system_id)


# What the solar panels make right now. During the shadow pass they make
# less (none at all), and the batteries give battery_power instead.
func get_power_available() -> float:
	ensure_choices()
	var storm: Dictionary = Data.game_data["events"]["power_low"]
	var solar_id: String = storm["solar_part"]
	var solar: float = Data.parts[solar_id]["versions"][choices[solar_id]]["effects"]["power"]
	if storm_active:
		solar -= solar * storm["solar_drop_percent"] / 100.0
		solar += storm["battery_power"]
	return solar


# What everything WITHOUT a switch uses (the body, computer, pointing...).
# = all power used, minus what the switchable systems use.
func get_body_power_use() -> float:
	ensure_choices()
	var solar_id: String = Data.game_data["events"]["power_low"]["solar_part"]
	var solar: float = Data.parts[solar_id]["versions"][choices[solar_id]]["effects"]["power"]
	var all_used: float = solar - get_totals()["power"]
	for system_id in Data.game_data["reroute_power"]["systems"]:
		all_used -= get_power_use(system_id)
	return all_used


# What one system uses when it is ON.
func get_power_use(system_id: String) -> float:
	return -system_effects(system_id).get("power", 0.0)


# Everything that is using power right now: the body + every system that is ON.
func get_power_used() -> float:
	var used: float = get_body_power_use()
	for system_id in Data.game_data["reroute_power"]["systems"]:
		if is_system_on(system_id):
			used += get_power_use(system_id)
	return used


# Has the mission clock reached the mission length? The length is the
# mission's "need at least" lifetime (for example 24 months).
func is_mission_time_up() -> bool:
	return mission_months >= get_limits()["mission_lifetime"]["value"]


# Is spare power inside its limit right now? (Used by the alarm.)
func is_power_ok() -> bool:
	return is_ok(get_running_values()["power"], get_limits()["power"])


# The six values the dashboard shows during the walk.
func get_live_values() -> Dictionary:
	var values: Dictionary = get_running_values()
	values["data"] = data_collected                                     # total so far
	values["mission_lifetime"] = get_totals()["mission_lifetime"] - mission_months - lifetime_lost   # months left
	return values


# The limits during the walk. Two of them move with the mission clock:
#   data:     "should have by now" = the minimum rate x days so far
#   lifetime: "months still needed" = mission length - months so far
func get_live_limits() -> Dictionary:
	var limits: Dictionary = get_limits()
	var days_per_month: float = Data.game_data["mission_clock"]["days_per_month"]
	var days_so_far: float = mission_months * days_per_month
	var mission_days: float = limits["mission_lifetime"]["value"] * days_per_month

	var data: Dictionary = limits["data"]
	data["bar_max"] = data["bar_max"] * mission_days
	data["value"] = data["value"] * days_so_far
	data["warning"] = data["warning"] * days_so_far

	var lifetime: Dictionary = limits["mission_lifetime"]
	lifetime["value"] -= mission_months
	lifetime["warning"] -= mission_months
	return limits


# If a part has no choice yet, pick its FIRST version from the data file.
# The first time, pack the mission's default instruments too.
# (When the player comes back with "Try again", their old choices stay.)
func fill_default_choices() -> void:
	for part_id in Data.parts:
		if not choices.has(part_id):
			var versions: Dictionary = Data.parts[part_id]["versions"]
			choices[part_id] = versions.keys()[0]
	# A saved choice for a part that no longer exists is dropped.
	for part_id in choices.keys():
		if not Data.parts.has(part_id):
			choices.erase(part_id)
	if not instruments_set:
		instruments_packed = get_destination()["default_instruments"]["value"].duplicate()
		instruments_set = true


# Safety net for pressing Play on a later screen directly (F6):
# if nothing is picked yet, use the default picks.
func ensure_choices() -> void:
	if choices.is_empty():
		fill_default_choices()


# --- Players and build minigames (data/minigames.json) -----------------------

# A player's name for the turn screens. Player 1 is the name typed at the
# start (if any); the others are "Player 2", "Player 3"... (index starts at 0).
func get_player_label(index: int) -> String:
	if index == 0 and player_name != "":
		return player_name
	return Data.story["minigames"]["player_default"].format({"n": index + 1})


# Start a minigame fresh: forget its old scores.
func clear_minigame_scores(game_id: String) -> void:
	minigame_scores[game_id] = []


# Save the next player's score (0-100) for one minigame.
func add_minigame_score(game_id: String, score: int) -> void:
	if not minigame_scores.has(game_id):
		minigame_scores[game_id] = []
	minigame_scores[game_id].append(score)


# The team average for one minigame (0 if nobody has played it yet).
func get_team_score(game_id: String) -> float:
	var scores: Array = minigame_scores.get(game_id, [])
	if scores.is_empty():
		return 0.0
	var sum: float = 0.0
	for score in scores:
		sum += score
	return sum / scores.size()


# The mission numbers the minigames make (PLAN.md section 7), 0-100 each:
# build quality (Assembly), structure strength (Hammering), fuel loaded (Fueling).
# For example get_build_result("build_quality").
# A minigame nobody played (pressing Play on a later screen with F6) counts as 100.
func get_build_result(result_id: String) -> float:
	for game_id in ["assembly", "hammer", "fuel", "clean"]:
		var game: Dictionary = Data.minigames[game_id] if Data.minigames.has(game_id) else Data.extras["clean_room"]
		if game["becomes"] == result_id:
			if minigame_scores.get(game_id, []).is_empty():
				return 100.0
			return get_team_score(game_id)
	return 0.0


# Launch: a weak structure (Hammering) lets the shaking loosen a part.
# Gives back the damage percent added (0 = it all held). timing.json "structure_check".
func apply_structure_check() -> float:
	var check: Dictionary = Data.timing["structure_check"]
	if get_build_result("structure_strength") >= check["min_strength"]:
		return 0.0
	add_damage(check["shake_part"], check["shake_damage_percent"])
	return check["shake_damage_percent"]


# --- Flight (events.json "flight") --------------------------------------------

var data_sent: float = 0.0             # Gb of data sent home during the flight
var cash_reserve: float = 0.0          # million $ left in the budget (budget limit - spent - event costs)
var data_rate_factor: float = 1.0      # 0.5 after "radio too weak": data sent at half rate
var flight_instruments_off: Array = [] # instruments switched off during the flight (dust on the panels)
var flight_outcomes: Array = []        # { "event": "solar_flare", "result": "good" / "saved" / "bad" }


# Call when the Flight screen opens.
func start_flight() -> void:
	data_sent = 0.0
	cash_reserve = get_limits()["budget"]["value"] - get_totals()["budget"] - weather_wait_cost
	data_rate_factor = 1.0
	quick_fixes.clear()
	flight_instruments_off.clear()
	flight_outcomes.clear()
	lifetime_lost = 0.0


# How much of a part still works after launch damage, 0 to 1 (1 = no damage).
func get_working_share(kind: String) -> float:
	return clampf(1.0 - damage.get(kind, 0.0) / 100.0, 0.0, 1.0)


# The six numbers during the flight: the build totals, minus launch damage
# and the flight's own losses.
func get_flight_values() -> Dictionary:
	var values: Dictionary = get_totals()
	# Damaged solar panels make less power.
	var solar_id: String = Data.game_data["events"]["power_low"]["solar_part"]
	var solar: float = Data.parts[solar_id]["versions"][choices[solar_id]]["effects"]["power"]
	values["power"] -= solar * (1.0 - get_working_share(solar_id))
	# A damaged antenna sends slower.
	values["communications"] *= get_working_share("antenna")
	# Damaged or switched-off instruments make less data (and use no power when off).
	var instruments: Dictionary = get_instruments()
	for instrument_id in flight_instruments_off:
		values["data"] -= instruments[instrument_id]["effects"]["data"]
		values["power"] -= instruments[instrument_id]["effects"]["power"]
	values["data"] = maxf(values["data"], 0.0) * get_working_share("instruments") * data_rate_factor
	values["mission_lifetime"] -= lifetime_lost
	return values


# The six numbers the tablet (Tab) shows: the design totals before launch,
# the flight values (with launch damage and flight losses) after it.
func get_hud_values() -> Dictionary:
	if character_id == "":
		character_id = Data.game_data["setup"]["default_character"]
	if mission_id == "":
		mission_id = Data.missions.keys()[0]
	fill_default_choices()
	var scene := get_tree().current_scene
	var scene_id: String = "" if scene == null else scene.scene_file_path.get_file().get_basename()
	if ["launch", "flight", "landing", "arrival", "cutscene_return", "debrief"].has(scene_id):
		return get_flight_values()
	return get_totals()


# What the solar panels make right now, after launch damage.
func get_flight_power_made() -> float:
	var solar_id: String = Data.game_data["events"]["power_low"]["solar_part"]
	var solar: float = Data.parts[solar_id]["versions"][choices[solar_id]]["effects"]["power"]
	return solar * get_working_share(solar_id)


# Fuel for the arrival burn, 0-100: the Fueling score minus fuel lost at launch.
func get_fuel_left() -> float:
	return get_build_result("fuel_loaded") - damage.get("fuel", 0.0)


# --- Arrival walk (destinations.json "arrival") ---------------------------------

# The mission checklist: "open", "done" or "failed" for each goal id,
# for example { "land_safely": "done", "sample_ice": "open", "send_data": "open" }.
var goals: Dictionary = {}
var run_recorded: bool = false   # true once this run is on the leaderboard (so a reload doesn't add it twice)
var trips_flown: int = 0         # finished flights this session: after the first, Skip buttons appear
var launches_done: int = 0       # finished launches this session: after the first, the launch can be skipped
var school_seen: bool = false    # Mission School watched once this session: after that, S skips it (UPGRADE_PLAN_V3 B4)
# How much of each goal's tasks got done, 0 to 1, for example { "place_seismometers": 0.67 }.
# The report gives part points for a goal that is only partly done.
var goal_progress: Dictionary = {}
var has_sample: bool = false
var drill_tries: int = 0


# --- The success checklist (UPGRADE_PLAN_V3 A3) ---------------------------------
# Eight items grouped by phase (destinations.json goals + goal_phases). It
# starts when the launch starts; each stage ticks its own items.

# Every item "open" (the launch calls this through start_launch).
func start_checklist() -> void:
	goals.clear()
	goal_progress.clear()
	for goal_id in get_destination()["goals"]["value"]:
		goals[goal_id] = "open"


# Tick (or fail) one item. Pressing Play on a later screen starts the list first.
func set_goal(goal_id: String, new_state: String) -> void:
	if goals.is_empty():
		start_checklist()
	if goals.has(goal_id):
		goals[goal_id] = new_state


# Tick the item of one phase ("arrive", "cruise"...) if this mission has it.
func set_phase_goal(phase: String, new_state: String) -> void:
	for goal_id in goal_ids_in_phase(phase):
		set_goal(goal_id, new_state)


func goal_phase(goal_id: String) -> String:
	return str(get_destination().get("goal_phases", {}).get(goal_id, ""))


func goal_ids_in_phase(phase: String) -> Array:
	return get_destination()["goals"]["value"].filter(func(id): return goal_phase(id) == phase)


# "3 of 8 done".
func checklist_progress_text() -> String:
	var done: int = goals.values().filter(func(s): return s == "done").size()
	return Data.story["checklist"]["progress"].format({"done": done, "total": get_destination()["goals"]["value"].size()})


# The phases in order, each with its items: [ { "phase": "launch", "ids": [...] } ].
func checklist_by_phase() -> Array:
	var groups: Array = []
	for goal_id in get_destination()["goals"]["value"]:
		var phase: String = goal_phase(goal_id)
		if groups.is_empty() or groups[-1]["phase"] != phase:
			groups.append({"phase": phase, "ids": []})
		groups[-1]["ids"].append(goal_id)
	return groups


# The phase the game is in now, from the screen (for the tablet: only these items show).
func current_phases(scene_id: String) -> Array:
	match scene_id:
		"launch":
			return ["launch"]
		"flight":
			return ["cruise", "arrive"]
		"landing", "arrival":
			return ["land", "science", "data"]
		"cutscene_return":
			return ["depart", "home"]
	return []


# The orbit burn in the flight ticks the "arrive" item (bad = failed).
func note_orbit_burn(result: String) -> void:
	set_phase_goal("arrive", "failed" if result == "bad" else "done")


# Depart and Home (DEFAULT rule, game_data.json report > return_rules): fuel
# left for the lift-off, structure strength for the landing at home. Gives
# back the two one-line reasons for the screen.
func decide_return() -> Array:
	var rules: Dictionary = Data.game_data["report"]["return_rules"]
	var words: Dictionary = Data.story["checklist"]["return"]
	var fuel: float = get_fuel_left()
	var strength: float = get_build_result("structure_strength") - damage.get("structure", 0.0)
	var depart_ok: bool = fuel >= float(rules["depart_min_fuel"])
	var home_ok: bool = strength >= float(rules["home_min_structure"])
	set_phase_goal("depart", "done" if depart_ok else "failed")
	set_phase_goal("home", "done" if home_ok else "failed")
	if not depart_ok and not event_failures.has("return_depart"):
		event_failures.append("return_depart")
	if not home_ok and not event_failures.has("return_home"):
		event_failures.append("return_home")
	return [
		words["depart_ok"] if depart_ok else words["depart_bad"].format({"fuel": fmt(maxf(fuel, 0.0))}),
		words["home_ok"] if home_ok else words["home_bad"].format({"strength": fmt(maxf(strength, 0.0))}),
	]


# The two return lines without deciding again (for the report).
func return_lines() -> Array:
	var words: Dictionary = Data.story["checklist"]["return"]
	var lines: Array = []
	for phase in ["depart", "home"]:
		for goal_id in goal_ids_in_phase(phase):
			var ok: bool = goals.get(goal_id, "open") == "done"
			if phase == "depart":
				lines.append(words["depart_ok"] if ok else words["depart_bad"].format({"fuel": fmt(maxf(get_fuel_left(), 0.0))}))
			else:
				lines.append(words["home_ok"] if ok else words["home_bad"].format({"strength": fmt(maxf(get_build_result("structure_strength") - damage.get("structure", 0.0), 0.0))}))
	return lines


# Call when the arrival walk starts. Landing counts as soon as we arrive.
# The items from earlier phases (launch, cruise, orbit) stay as they are.
func start_arrival() -> void:
	if goals.is_empty():
		start_checklist()
	var goal_tasks: Dictionary = get_destination()["arrival"]["goals"]
	for goal_id in goal_tasks:
		if goal_tasks[goal_id] is String and goal_tasks[goal_id] == "arrive":
			set_goal(goal_id, "done")
		elif goals.has(goal_id):
			goals[goal_id] = "open"
			goal_progress.erase(goal_id)
	has_sample = false
	drill_tries = 0


# Call when the player leaves. Every arrival item not done becomes a report
# finding. (Depart and Home are decided later, on the return screen.)
# reasons = a finding id per goal, for example { "sample_ice": "arrival_no_drill" }.
func finish_arrival(reasons: Dictionary) -> void:
	var arrival_goals: Dictionary = get_destination()["arrival"]["goals"]
	for goal_id in goals:
		if goals[goal_id] == "done" or not arrival_goals.has(goal_id):
			continue
		goals[goal_id] = "failed"
		var failure_id: String = reasons.get(goal_id, "arrival_" + goal_id)
		if Data.voice["resource_failures"].has(failure_id) and not event_failures.has(failure_id):
			event_failures.append(failure_id)


# Remember how a flight event went. A bad one becomes a report finding.
func record_flight_outcome(event_id: String, result: String) -> void:
	flight_outcomes.append({"event": event_id, "result": result})
	if event_id == str(Data.flight.get("orbit_burn_event", "arrival_burn")):
		note_orbit_burn(result)   # the checklist's "arrive" item (UPGRADE_PLAN_V3 A3)
	if result == "bad" and not event_failures.has("flight_" + event_id):
		event_failures.append("flight_" + event_id)


# --- Science instruments (destinations.json "instruments") -------------------

# This mission's instruments, without the "_readme" note.
# For example: { "ice_drill": { "effects": {...}, "source": "..." }, ... }
func get_instruments() -> Dictionary:
	var result: Dictionary = {}
	var all: Dictionary = get_destination().get("instruments", {})
	for instrument_id in all:
		if not instrument_id.begins_with("_"):
			result[instrument_id] = all[instrument_id]
	return result


# The instruments the mission's goal needs, for example ["ice_drill"].
func get_key_instruments() -> Array:
	return get_destination().get("key_instruments", {}).get("value", [])


func is_instrument_packed(instrument_id: String) -> bool:
	return instruments_packed.has(instrument_id)


# Pack an instrument, or take it out.
func set_instrument_packed(instrument_id: String, packed: bool) -> void:
	if packed and not instruments_packed.has(instrument_id):
		instruments_packed.append(instrument_id)
	elif not packed:
		instruments_packed.erase(instrument_id)


# Key instruments the player left out. An empty list means all are packed.
func get_missing_key_instruments() -> Array:
	var missing: Array = []
	for instrument_id in get_key_instruments():
		if not is_instrument_packed(instrument_id):
			missing.append(instrument_id)
	return missing


# Adds up the six resources:
# the spacecraft body + every part version the player picked.
func get_totals() -> Dictionary:
	var totals: Dictionary = {}

	# Start every resource at 0.
	for res_id in Data.resources:
		totals[res_id] = 0.0

	# Add the spacecraft body. (The heater is now the thermal control part.)
	add_effects(totals, Data.game_data["spacecraft_base"]["effects"])

	# Add the rocket's cost. (If no rocket is picked yet, use the default.)
	totals["budget"] += Data.game_data["launch_vehicles"]["vehicles"][get_launch_vehicle_id()]["cost"]

	# Add the fuel the spacecraft needs to slow down into its orbit.
	# Fuel is heavy, so it counts toward the Mass the rocket must lift.
	totals["mass"] += get_orbit_fuel_mass()

	# The launch date: a poor date needs extra fuel (and a little money), the best one less.
	add_effects(totals, get_launch_window()["effects"])

	# Add each chosen part version.
	for part_id in choices:
		var version_id: String = choices[part_id]
		add_effects(totals, Data.parts[part_id]["versions"][version_id]["effects"])

	# Add each packed science instrument.
	var instruments: Dictionary = get_instruments()
	for instrument_id in instruments_packed:
		if instruments.has(instrument_id):
			add_effects(totals, instruments[instrument_id]["effects"])

	return totals


# The picked rocket, or the default rocket if none is picked yet.
func get_launch_vehicle_id() -> String:
	if launch_vehicle_id != "":
		return launch_vehicle_id
	return Data.game_data["launch_vehicles"]["default"]


# How many kg the picked rocket can lift (game_data.json "launch_vehicles").
func get_rocket_capacity() -> float:
	return float(Data.game_data["launch_vehicles"]["vehicles"][get_launch_vehicle_id()]["capacity"])


# The picked orbit, or the mission's default orbit if none is picked yet.
func get_orbit_id() -> String:
	if orbit_id != "":
		return orbit_id
	return get_destination()["default_orbit"]["value"]


# The kg of fuel needed to get into the picked orbit (destinations.json "orbits").
func get_orbit_fuel_mass() -> float:
	return float(get_destination()["orbits"][get_orbit_id()]["fuel_mass"]["value"])


# Adds one list of effects into the totals.
func add_effects(totals: Dictionary, effects: Dictionary) -> void:
	for res_id in effects:
		totals[res_id] += effects[res_id]


# The limits for this mission. They are the same for every character.
# Gives back, for example: { "budget": { "rule": "max", "value": 450 }, ... }
func get_limits() -> Dictionary:
	var limits: Dictionary = {}
	var mission_limits: Dictionary = Data.missions[mission_id]["limits"]

	for res_id in mission_limits:
		var limit: Dictionary = mission_limits[res_id]
		if limit.get("value_from", "") == "launch_vehicle":
			# This limit is what the picked rocket can lift (the Mass row).
			var capacity: float = get_rocket_capacity()
			limits[res_id] = {
				"rule": limit["rule"],
				"value": capacity,
				"warning": capacity * limit["warning_fraction"],
				"bar_max": capacity * limit["bar_max_fraction"],
			}
		else:
			limits[res_id] = {
				"rule": limit["rule"],
				"value": limit["value"],
				"warning": limit["warning"],
				"bar_max": limit["bar_max"],
			}
	return limits


# The worst color among all rows: "danger" beats "warning" beats "safe".
# Used by the wrist light: one light that sums up the whole dashboard.
func get_worst_status(values: Dictionary, limits: Dictionary) -> String:
	var worst := "safe"
	for res_id in values:
		var status: String = get_status(values[res_id], limits[res_id])
		if status == "danger":
			return "danger"   # can't get worse than this, stop looking
		if status == "warning":
			worst = "warning"
	return worst


# Safe, close to the limit, or past it? Used by the dashboard.
#   "danger"  = past the limit (over a max, or under a min)  -> red
#   "warning" = still OK, but past the warning line          -> yellow
#   "safe"    = everything fine                               -> green
func get_status(total: float, limit: Dictionary) -> String:
	if not is_ok(total, limit):
		return "danger"
	if is_equal_approx(total, limit["warning"]):
		return "safe"   # exactly on the warning line counts as safe
	if limit["rule"] == "max" and total > limit["warning"]:
		return "warning"
	if limit["rule"] == "min" and total < limit["warning"]:
		return "warning"
	return "safe"


# Is this one resource inside its limit?
#   rule "max": the total must be AT or BELOW the limit.
#   rule "min": the total must be AT or ABOVE the limit.
func is_ok(total: float, limit: Dictionary) -> bool:
	# is_equal_approx = "equal, ignoring tiny rounding errors".
	# Without it, two numbers that should be equal (like 900.0000001 and 900)
	# can flicker between OK and not OK.
	if is_equal_approx(total, limit["value"]):
		return true
	if limit["rule"] == "max":
		return total <= limit["value"]
	return total >= limit["value"]


# A list of every resource that breaks its limit, for example ["mission_lifetime"].
# An empty list means the build is good.
func get_failed_resources() -> Array:
	var totals: Dictionary = get_totals()
	var limits: Dictionary = get_limits()
	var failed: Array = []
	for res_id in limits:
		if not is_ok(totals[res_id], limits[res_id]):
			failed.append(res_id)
	return failed


# The Ripple effect (PLAN.md 6c): what one change did to the six totals.
# before / after = get_totals() from just before and just after the change.
# Gives back one step per resource that moved, biggest change first, e.g.
#   [ { "res_id": "data", "amount": 11.6, "good": true }, ... ]
# "Biggest" = the change compared with that row's full bar (bar_max), so
# different units (kg, W, $) can be compared fairly.
# good = the change helps: less of a "max" resource, or more of a "min" one.
func get_ripple_steps(before: Dictionary, after: Dictionary) -> Array:
	var limits: Dictionary = get_limits()
	var steps: Array = []
	for res_id in Data.resources:
		var amount: float = after[res_id] - before[res_id]
		if is_zero_approx(snappedf(amount, 0.001)):
			continue   # this row did not move
		var more_is_good: bool = limits[res_id]["rule"] == "min"
		steps.append({
			"res_id": res_id,
			"amount": amount,
			"good": (amount > 0) == more_is_good,
			"size": absf(amount) / limits[res_id]["bar_max"],
		})
	steps.sort_custom(func(a, b): return a["size"] > b["size"])
	return steps


# Fills in the {value}, {limit} and {unit} blanks in an inner-voice line.
func fill_blanks(line: String, res_id: String) -> String:
	# "data_live": use the numbers from the END of the mission.
	if res_id.ends_with("_live"):
		var live_id: String = res_id.trim_suffix("_live")
		return line.format({
			"value": fmt(end_values[live_id]),
			"limit": fmt(end_limits[live_id]["value"]),
			"unit": Data.resources[live_id].get("live_unit", Data.resources[live_id]["unit"]),
		})
	if not Data.resources.has(res_id):
		return line   # for example "power_event", which has no blanks
	return line.format({
		"value": fmt(get_totals()[res_id]),
		"limit": fmt(get_limits()[res_id]["value"]),
		"unit": Data.resources[res_id]["unit"],
	})


# --- The cause chain (Mission Report, 2026-11-14) ----------------------------
# Why a resource failed, as a chain of steps, for example:
#   ["Heavy Large frame (+120 kg)", "more mass (4100 kg)",
#    "bigger rocket (Atlas V 541, 243 million $)", "budget gone (712 of 671 million $)"]
# It names the ONE choice that pushed this resource furthest from its best
# option ("blame" below), so every chain points at something the player can
# change. A budget that broke because the design was too heavy for every
# cheaper rocket follows the mass back to its heaviest choice.
# Words: story.json "cause_chain". Gives back [] when there is no chain.
func get_cause_chain(res_id: String) -> Array:
	if not Data.resources.has(res_id):
		return []
	var words: Dictionary = Data.story["cause_chain"]
	var totals: Dictionary = get_totals()
	var limit: Dictionary = get_limits()[res_id]
	var unit: String = Data.resources[res_id]["unit"]
	var rocket_name: String = Data.story["launch_vehicles"][get_launch_vehicle_id()]["name"]
	var last: String = words["last"][res_id].format({"value": fmt(totals[res_id]), "limit": fmt(limit["value"]), "unit": unit, "rocket": rocket_name})
	var top: Dictionary = most_blamed_choice(res_id)
	if top.is_empty():
		return [last]
	var steps: Array = []
	if res_id == "budget" and top["kind"] == "rocket" and rocket_forced_by_mass():
		# Heavy choice -> more mass -> bigger rocket -> budget gone.
		var heavy: Dictionary = most_blamed_choice("mass")
		var mass_unit: String = Data.resources["mass"]["unit"]
		if not heavy.is_empty():
			steps.append(words["first"]["mass"].format({"item": heavy["name"], "amount": fmt(heavy["blame"]), "unit": mass_unit}))
		steps.append(words["more_mass"].format({"value": fmt(totals["mass"]), "unit": mass_unit}))
		var cost: float = Data.game_data["launch_vehicles"]["vehicles"][get_launch_vehicle_id()]["cost"]
		steps.append(words["bigger_rocket"].format({"rocket": rocket_name, "cost": fmt(cost)}))
	else:
		steps.append(words["first"][res_id].format({"item": top["name"], "amount": fmt(top["blame"]), "unit": unit}))
	steps.append(last)
	return steps


# True when the design is too heavy for a cheaper rocket than the one picked,
# so its mass pushed it onto a pricier rocket. (The Falcon 9 is cheap AND
# strong, so "every cheaper rocket" would almost never be true.)
func rocket_forced_by_mass() -> bool:
	var vehicles: Dictionary = Data.game_data["launch_vehicles"]["vehicles"]
	var picked_cost: float = vehicles[get_launch_vehicle_id()]["cost"]
	var mass: float = get_totals()["mass"]
	for vehicle_id in vehicles:
		if float(vehicles[vehicle_id]["cost"]) < picked_cost and float(vehicles[vehicle_id]["capacity"]) < mass:
			return true
	return false


# The choice that hurts this resource most compared with its best option:
# { "kind", "name", "blame" } (blame > 0, in the resource's unit), or {}.
func most_blamed_choice(res_id: String) -> Dictionary:
	var more_is_good: bool = get_limits()[res_id]["rule"] == "min"
	var best: Dictionary = {}
	for choice in get_design_choices():
		var mine: float = float(choice["picked"].get(res_id, 0.0))
		var blame: float = 0.0
		for option in choice["options"]:
			var other: float = float(option.get(res_id, 0.0))
			blame = maxf(blame, (other - mine) if more_is_good else (mine - other))
		if blame > 0.0 and not is_zero_approx(snappedf(blame, 0.001)) and (best.is_empty() or blame > best["blame"]):
			best = {"kind": choice["kind"], "name": choice["name"], "blame": blame}
	return best


# Every choice in the design, with the effects of what was picked and of
# every option it could have been instead (an instrument could be left out).
func get_design_choices() -> Array:
	var words: Dictionary = Data.story["cause_chain"]
	var dest: String = get_destination_key()
	var list: Array = []
	var vehicles: Dictionary = Data.game_data["launch_vehicles"]["vehicles"]
	var rocket_options: Array = []
	for vehicle_id in vehicles:
		rocket_options.append({"budget": vehicles[vehicle_id]["cost"]})
	list.append({"kind": "rocket", "name": Data.story["launch_vehicles"][get_launch_vehicle_id()]["name"],
		"picked": {"budget": vehicles[get_launch_vehicle_id()]["cost"]}, "options": rocket_options})
	var orbits: Dictionary = get_destination()["orbits"]
	var orbit_options: Array = []
	for some_orbit in orbits:
		if not some_orbit.begins_with("_"):
			orbit_options.append({"mass": orbits[some_orbit]["fuel_mass"]["value"]})
	list.append({"kind": "orbit", "name": words["orbit_item"].format({"name": Data.story["orbits"][dest][get_orbit_id()]["name"].to_lower()}),
		"picked": {"mass": get_orbit_fuel_mass()}, "options": orbit_options})
	var windows: Dictionary = Data.extras["launch_window"]["options"]
	var window_options: Array = []
	for window_id in windows:
		window_options.append(windows[window_id]["effects"])
	list.append({"kind": "window", "name": words["window_item"].format({"name": Data.story["extras"]["launch_window"]["names"][get_launch_window_id()].to_lower()}),
		"picked": get_launch_window()["effects"], "options": window_options})
	for part_id in choices:
		var versions: Dictionary = Data.parts[part_id]["versions"]
		var part_options: Array = []
		for version_id in versions:
			part_options.append(versions[version_id]["effects"])
		list.append({"kind": "part", "name": choice_name(part_id, choices[part_id]),
			"picked": versions[choices[part_id]]["effects"], "options": part_options})
	var instruments: Dictionary = get_instruments()
	for instrument_id in instruments_packed:
		if instruments.has(instrument_id):
			list.append({"kind": "instrument", "name": Data.story["instruments"][dest][instrument_id]["name"],
				"picked": instruments[instrument_id]["effects"], "options": [{}]})   # {} = left out
	return list


# A part card's name for a sentence: "Large frame" stays, a one-word card
# like "Large" gets its category: "Large radio antenna".
func choice_name(part_id: String, version_id: String) -> String:
	var name: String = Data.version_name(part_id, version_id)
	if name.contains(" "):
		return name
	return name + " " + Data.part_name(part_id).to_lower()


# Lists what a part version changes, for example:
#   "Budget +40 million $, Power -50 W spare, Data +30 Gb/day"
# Used by the build screen (hover text) and the 3D walk (press E).
func effects_text(effects: Dictionary, separator: String) -> String:
	var lines: PackedStringArray = []
	for res_id in effects:
		var amount: float = effects[res_id]
		if amount != 0:
			var sign := "+" if amount > 0 else ""
			lines.append("%s %s%s %s" % [Data.resources[res_id]["name"], sign, fmt(amount), Data.resources[res_id]["unit"]])
	return separator.join(lines)


# Shows a number nicely: 450.0 becomes "450", 2.5 stays "2.5",
# 23.98 becomes "24", and big numbers like 2417.1 become "2417".
func fmt(value: float) -> String:
	if absf(value) >= 100:
		return str(int(round(value)))
	var text: String = "%.1f" % value
	if text.ends_with(".0"):
		text = text.trim_suffix(".0")
	if text == "-0":
		text = "0"
	return text
