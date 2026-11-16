# planet_crew.gd
# The party on the planet (2026-11-15): every teammate, bot or person, walks
# the SAME planet and helps with the SAME task list (arrival.gd owns it).
# The figures, name tags and position messages come from ship_crew.gd; this
# file only gives the bots their planet jobs:
#   - a bot takes an open task nobody is standing on, once it has waited
#     take_planet_task_after_seconds, walks there and does it (place, drill,
#     send...); press_seconds / hold_seconds / send_seconds of work
#   - a bot that just finished one step goes straight to the next step of the
#     same chain (drill -> analyze), so the Mars ice is not lost waiting
# Only the party leader's game (or the one computer in a bots party) moves
# the bots; the others see them through the planet state the leader sends.
# Numbers: multiplayer.json "bots". Words: story.json "party".
extends "res://scripts/ship_crew.gd"

var last_done: Dictionary = {}   # bot seat -> the task id it finished last
var rng := RandomNumberGenerator.new()


func start_spot() -> Vector3:
	rng.randomize()
	return screen.to_vector(screen.settings["player_start"])


func tick_bots(delta: float) -> void:
	var rules: Dictionary = Data.mp["bots"]
	# How long each task has been open and ready (bots wait a moment before they take
	# one). A task whose instrument was not packed counts too: a bot walks there
	# and finds out, like a player would.
	for task in screen.tasks:
		var id: String = task["id"]
		if screen.state[id] == "open" and screen.ready_now(task):
			task_age[id] = float(task_age.get(id, 0.0)) + delta
		else:
			task_age.erase(id)
	for seat in bots:
		var b: Dictionary = bots[seat]
		# The task is gone (someone else did it) or the player is standing on it: drop it.
		if b["key"] != "" and (screen.state.get(b["key"], "") != "open" or screen.current_spot == spot_of(b["key"])):
			b["key"] = ""
			b["path"] = []
		if b["key"] == "" and not screen.leaving_allowed:
			pick_planet_job(seat, b, rules)
		if b["key"] == "":
			wander(b, delta, rules)   # nothing to do right now: walk around, never just stand
		walk(b, delta)
		if b["key"] != "" and b["path"].is_empty():
			var task: Dictionary = screen.task_by_id(b["key"])
			if not screen.instrument_ok(task):
				# We did not pack its instrument: the bot finds out and tells the team.
				b["key"] = ""
				screen.bot_found_missing(task, seat)
				continue
			b["work_left"] -= delta
			if b["work_left"] <= 0.0:
				var id: String = b["key"]
				b["key"] = ""
				last_done[seat] = id
				screen.bot_did(id, seat)
		var avatar: Dictionary = ensure_avatar(seat)
		avatar["target"] = b["pos"]
		avatar["yaw"] = b["yaw"]


func spot_of(task_id: String) -> String:
	for task in screen.tasks:
		if task["id"] == task_id:
			return task["spot"]
	return ""


func pick_planet_job(seat: int, b: Dictionary, rules: Dictionary) -> void:
	var taken: Array = []
	for other in bots.values():
		if other["key"] != "":
			taken.append(other["key"])
	var best: Dictionary = {}
	for task in screen.tasks:
		var id: String = task["id"]
		if not task_age.has(id) or taken.has(id) or screen.current_spot == task["spot"]:
			continue
		# The next step of the chain this bot just did: go at once.
		if task.get("needs_tasks", []).has(last_done.get(seat, "")):
			best = task
			break
		if best.is_empty() and task_age[id] >= float(rules["take_planet_task_after_seconds"]):
			best = task
	if best.is_empty():
		return
	b["key"] = best["id"]
	b["wait"] = 0.0
	match str(best["type"]):
		"reach":
			b["work_left"] = 0.0
		"hold":
			b["work_left"] = float(rules["hold_seconds"])
		"send":
			b["work_left"] = float(screen.settings["send"]["base_seconds"])
		_:
			b["work_left"] = float(rules["press_seconds"])
	b["path"] = route(b["pos"], screen.to_vector(screen.settings["spots"][best["spot"]]))


# No job for this bot right now: walk to a spot near an open task (or near the
# player), look around for a moment, then go somewhere else.
func wander(b: Dictionary, delta: float, rules: Dictionary) -> void:
	if not b["path"].is_empty():
		return
	b["wait"] = float(b.get("wait", 0.0)) - delta
	if b["wait"] > 0.0:
		return
	b["wait"] = rng.randf_range(float(rules["wander_pause_min"]), float(rules["wander_pause_max"]))
	var places: Array = []
	for task in screen.tasks:
		if screen.state[task["id"]] == "open":
			places.append(screen.to_vector(screen.settings["spots"][task["spot"]]))
	places.append(screen.player.global_position)
	var center: Vector3 = places[rng.randi_range(0, places.size() - 1)]
	var radius: float = float(rules["wander_radius"])
	var goal: Vector3 = center + Vector3(rng.randf_range(-radius, radius), 0, rng.randf_range(-radius, radius))
	if not screen.room_rects.is_empty():
		goal = center   # inside the ship (Venus): stay on the spot, never inside a wall
	b["path"] = route(b["pos"], goal)
