# Notebook.gd
# "Three voices, one decision" and "The voice learns" (INNOVATION.md).
#
# Feature A: hint_for(decision) gives the inner-voice hint for a Design Lab
#   station, in the voice of the picked character (inner_voice.json
#   "character_hints"). The {blanks} are filled from the data files, so every
#   number matches what is on screen.
# Feature B: learn_from_run() finds the main cause of a failed run, picks the
#   word it teaches (story.json "notebook" > causes) and writes it in the
#   character's notebook with a line about this run's real numbers. Earned
#   words change the hints: the voice now uses them (the "learned" lines).
#   The notebook is saved in user://notebook.json, so it stays between retries
#   and after the game is closed (like the Space Dictionary).
extends Node

const PATH := "user://notebook.json"

# character id -> list of { "id": term id, "run": "what happened in that run" },
# oldest first (the newest earned word is the last one).
var earned: Dictionary = {}


func _ready() -> void:
	if FileAccess.file_exists(PATH):
		var saved = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if saved is Dictionary:
			earned = saved


func save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(earned, "  "))


# ---------- the words ----------

func terms() -> Array:
	return Data.story["notebook"]["terms"]


func term(id: String) -> Dictionary:
	for t in terms():
		if t["id"] == id:
			return t
	return {}


func words_for(character_id: String) -> Array:
	return earned.get(character_id, [])


func has_word(character_id: String, id: String) -> bool:
	return words_for(character_id).any(func(e): return e["id"] == id)


# Writes a word in the character's notebook (or updates its run line).
# Returns true when the word is new.
func earn(character_id: String, id: String, run_text: String) -> bool:
	if character_id == "" or term(id).is_empty():
		return false
	var list: Array = words_for(character_id).duplicate(true)
	for entry in list:
		if entry["id"] == id:
			entry["run"] = run_text
			earned[character_id] = list
			save()
			return false
	list.append({"id": id, "run": run_text})
	earned[character_id] = list
	save()
	return true


# ---------- Feature B: learning from a failed run ----------

# The failures of this run, the main one first: build problems (biggest
# overshoot first), a missing key instrument, then what went wrong in flight
# and on arrival. Each is { "id": failure id, "run": line with real numbers }.
func ranked_failures() -> Array:
	var result: Array = []
	var totals: Dictionary = GameState.get_totals()
	var limits: Dictionary = GameState.get_limits()
	var built: Array = GameState.get_failed_resources().duplicate()
	built.sort_custom(func(a, b): return overshoot(totals[a], limits[a]) > overshoot(totals[b], limits[b]))
	for res_id in built:
		result.append({"id": res_id, "run": resource_run_line(res_id, totals[res_id], limits[res_id]["value"])})
	for instrument_id in GameState.get_missing_key_instruments():
		var name: String = Data.story["instruments"][GameState.get_destination_key()][instrument_id]["name"]
		result.append({"id": "missing_instrument", "run": cause_text("missing_instrument", {"instrument": name.to_lower()})})
	for failure_id in GameState.event_failures:
		if str(failure_id).ends_with("_live") and Data.resources.has(str(failure_id).trim_suffix("_live")):
			var live_id: String = str(failure_id).trim_suffix("_live")
			result.append({"id": failure_id, "run": resource_run_line(failure_id, float(GameState.end_values.get(live_id, 0.0)), float(GameState.end_limits.get(live_id, {}).get("value", 0.0)))})
		else:
			result.append({"id": failure_id, "run": report_sentence(failure_id)})
	return result


func overshoot(value: float, limit: Dictionary) -> float:
	return absf(value - float(limit["value"])) / maxf(absf(float(limit.get("bar_max", 1.0))), 0.001)


# "Your spacecraft was 300 kg over the Atlas V 401's payload capacity of 2315 kg."
func resource_run_line(failure_id: String, value: float, limit: float) -> String:
	var rocket: String = Data.story["launch_vehicles"][GameState.get_launch_vehicle_id()]["name"]
	var over: float = absf(value - limit)
	if failure_id == "power":
		over = absf(minf(value, 0.0) - limit)   # power is "spare": below 0 means the parts use more than the panels make
	return cause_text(failure_id, {"value": GameState.fmt(value), "limit": GameState.fmt(limit), "over": GameState.fmt(over), "rocket": rocket})


func cause_text(cause_id: String, blanks: Dictionary) -> String:
	var cause: Dictionary = Data.story["notebook"]["causes"].get(cause_id, {})
	if cause.has("run"):
		return str(cause["run"]).format(blanks)
	return report_sentence(cause_id)


# The report's own sentence for a failure (already true for this run).
func report_sentence(failure_id: String) -> String:
	var text: Dictionary = Data.voice["resource_failures"].get(failure_id, {})
	if text.is_empty():
		return ""
	return GameState.fill_blanks(text["what"], failure_id)


# Called by the report when the run failed (a mission or a checkpoint).
# Gives back { "id": term id, "run": text, "new": bool } or {} (nothing to learn).
func learn_from_run() -> Dictionary:
	var who: String = GameState.character_id
	var failures: Array = ranked_failures().filter(func(f): return Data.story["notebook"]["causes"].has(f["id"]))
	if failures.is_empty():
		return {}
	# The main cause's own word first, then any other failure's own word, then
	# the extra words: the first one the character does not know yet is taught.
	# If every word is known, the main word gets this run's numbers.
	var rounds: int = 0
	for failure in failures:
		rounds = maxi(rounds, Data.story["notebook"]["causes"][failure["id"]]["words"].size())
	for r in rounds:
		for failure in failures:
			var words: Array = Data.story["notebook"]["causes"][failure["id"]]["words"]
			if r < words.size() and not has_word(who, words[r]):
				earn(who, words[r], failure["run"])
				return {"id": words[r], "run": failure["run"], "new": true}
	var main: Dictionary = failures[0]
	var main_word: String = Data.story["notebook"]["causes"][main["id"]]["words"][0]
	earn(who, main_word, main["run"])
	return {"id": main_word, "run": main["run"], "new": false}


# ---------- Feature A: three voices, one decision ----------

# The hint for one Design Lab station, for the picked character ("" = none).
func hint_for(decision: String) -> String:
	var who: String = GameState.character_id
	if who == "":
		return ""
	var hints: Dictionary = Data.voice["character_hints"]
	var options: Dictionary = {}
	var text: String = ""
	if hints.has(decision) and not decision.begins_with("_"):
		options = hints[decision].get("learned", {})
		text = hints[decision].get(who, "")
	else:
		options = hints["learned_only"].get(decision, {})
	# The newest earned word that has a line here wins (the voice learned it).
	var list: Array = words_for(who)
	for i in range(list.size() - 1, -1, -1):
		var id: String = list[i]["id"]
		if options.has(id) and options[id].has(who):
			text = options[id][who]
			break
	return text.format(hint_values()) if text != "" else ""


# The numbers and names the hints may use, all from the data files.
func hint_values() -> Dictionary:
	var totals: Dictionary = GameState.get_totals()
	var limits: Dictionary = GameState.get_limits()
	var vehicles: Dictionary = Data.game_data["launch_vehicles"]["vehicles"]
	var low_id: String = ""
	var cheap_id: String = ""
	var big_id: String = ""
	for id in vehicles:
		if low_id == "" or vehicles[id]["capacity"] < vehicles[low_id]["capacity"]:
			low_id = id
		if cheap_id == "" or vehicles[id]["cost"] < vehicles[cheap_id]["cost"]:
			cheap_id = id
		if big_id == "" or vehicles[id]["capacity"] > vehicles[big_id]["capacity"]:
			big_id = id
	var key: String = GameState.get_destination_key()
	var place: Dictionary = Data.story["destinations"][key]
	var orbits: Dictionary = GameState.get_destination()["orbits"]
	var orbit_words: Dictionary = Data.story["orbits"][key]
	var values := {
		"mass": GameState.fmt(totals["mass"]),
		"low_name": Data.story["launch_vehicles"][low_id]["name"],
		"low_lift": GameState.fmt(vehicles[low_id]["capacity"]),
		"cheap_name": Data.story["launch_vehicles"][cheap_id]["name"],
		"cheap_cost": GameState.fmt(vehicles[cheap_id]["cost"]),
		"cheap_lift": GameState.fmt(vehicles[cheap_id]["capacity"]),
		"big_name": Data.story["launch_vehicles"][big_id]["name"],
		"big_lift": GameState.fmt(vehicles[big_id]["capacity"]),
		"planet": place.get("in_sentence", place["name"]),
		"power_spare": GameState.fmt(totals["power"]),
		"comms": GameState.fmt(totals["communications"]),
		"comms_need": GameState.fmt(limits["communications"]["value"]),
		"lifetime": GameState.fmt(totals["mission_lifetime"]),
		"lifetime_need": GameState.fmt(limits["mission_lifetime"]["value"]),
	}
	# The orbit hints compare the low and high orbit of this mission.
	if orbits.has("low") and orbits.has("high"):
		values["low_orbit"] = str(orbit_words["low"]["name"]).to_lower()
		values["low_fuel"] = GameState.fmt(orbits["low"]["fuel_mass"]["value"])
		values["high_orbit"] = str(orbit_words["high"]["name"]).to_lower()
		values["high_fuel"] = GameState.fmt(orbits["high"]["fuel_mass"]["value"])
	var key_ids: Array = GameState.get_key_instruments()
	if not key_ids.is_empty():
		var instrument_id: String = key_ids[0]
		values["key_name"] = str(Data.story["instruments"][key][instrument_id]["name"]).to_lower()
		values["key_power"] = GameState.fmt(absf(float(GameState.get_instruments()[instrument_id]["effects"].get("power", 0.0))))
	return values
