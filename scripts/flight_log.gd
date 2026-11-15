# flight_log.gd
# The flight log (PLAN.md section 9). Since UPGRADE_PLAN_V2 step 21 it runs on
# the big wall screen on the Bridge of the walkable ship (scripts/flight.gd puts
# it in a SubViewport: "embedded"). There, an event whose design check fails
# becomes an EMERGENCY on the ship (signal emergency_started); the ship calls
# resolve_event() when the player fixed it in time, or when the timer ran out.
# Played on its own (press Play on this scene), it works like before.
# The trip:
#   - a map with the ship moving from Earth to the destination, and a day clock
#   - status tiles: phase, signal delay, power, cash reserve, data sent home
#   - a flight log that types out line by line: green = fine, amber =
#     warning, red = loss. Every red line says WHY.
#   - 3-5 events (data/events.json "flight"). How each one goes depends on
#     the design, the launch damage and the minigame scores.
#   - a 1x / 4x speed button
# Bad events become findings in the mission report.
extends Control

@onready var title_label: Label = %Title
@onready var clock_label: Label = %Clock
@onready var speed_button: Button = %SpeedButton
@onready var map: Control = %Map
@onready var tiles_row: HBoxContainer = %Tiles
@onready var log_label: RichTextLabel = %Log
@onready var next_button: Button = %NextButton

const TILE_IDS := ["phase", "signal", "power", "reserve", "data"]

# Embedded on the ship: an event's design check failed, the crew can still fix it.
signal emergency_started(event_id: String, blanks: Dictionary)
signal trip_finished

var embedded: bool = false     # true = on the Bridge wall screen of the ship
var trip_seconds: float = 0.0  # how long the trip lasts (longer on the ship)
var pending: Dictionary = {}   # event id -> blanks, emergencies not fixed yet

var settings: Dictionary   # events.json "flight"
var words: Dictionary      # story.json "flight_screen"
var planet: String = ""    # the destination's name, for example "Mars"
var trip_days: float = 0.0

var progress: float = 0.0   # 0 = just launched, 1 = arrived
var speed: float = 1.0
var done: bool = false
var typed: float = 0.0      # how many log letters are showing (the typing effect)
var log_lines: Array = []   # the log lines on screen (the newest few, UPGRADE_PLAN_V3 E)

var event_ids: Array = []
var next_event: int = 0
var next_routine: int = 0
var tile_labels: Dictionary = {}   # { "phase": <value Label>, ... }


func _ready() -> void:
	# Safety net for pressing Play on this screen directly.
	if GameState.character_id == "":
		GameState.character_id = Data.game_data["setup"]["default_character"]
	if GameState.mission_id == "":
		GameState.mission_id = Data.missions.keys()[0]
	GameState.fill_default_choices()

	settings = Data.flight
	words = Data.story["flight_screen"]
	var destination_key: String = GameState.get_destination_key()
	# "the Moon" inside a sentence, not "The Moon" (story.json in_sentence; the name if none).
	var place_words: Dictionary = Data.story["destinations"][destination_key]
	planet = place_words.get("in_sentence", place_words["name"])
	trip_days = GameState.get_trip_days()   # the launch date stretches or shortens it (extras.json)
	event_ids = settings["mission_events"].get(destination_key, [])

	title_label.text = words["title"].format({"planet": planet})
	map.planet_name = planet
	embedded = get_tree().current_scene != self
	trip_seconds = settings["ship"]["trip_seconds"] if embedded else settings["flight_seconds"]["value"]
	speed_button.visible = not embedded   # on the ship the trip runs at walking speed
	speed_button.toggled.connect(_on_speed_toggled)
	_on_speed_toggled(false)
	next_button.text = words["next_button"]
	next_button.pressed.connect(_on_next_pressed)
	log_label.text = ""
	log_label.visible_characters = 0

	GameState.start_flight()
	make_tiles()
	write_start_lines()
	update_screen()


# Five small navy tiles, each with a name and a value.
func make_tiles() -> void:
	for tile_id in TILE_IDS:
		var tile := PanelContainer.new()
		tile.theme_type_variation = &"NavyPanel"
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tiles_row.add_child(tile)
		var column := VBoxContainer.new()
		tile.add_child(column)
		var name_label := Label.new()
		name_label.theme_type_variation = &"SmallText"
		name_label.text = words["tiles"][tile_id]
		column.add_child(name_label)
		var value_label := Label.new()
		value_label.theme_type_variation = &"BodyText"
		column.add_child(value_label)
		tile_labels[tile_id] = value_label


# Launch is done: say so, and list any launch damage.
func write_start_lines() -> void:
	add_line(words["lines"]["start"].format({"planet": planet}), "good")
	if GameState.weather_wait_cost > 0.0:   # the weather call (extras)
		add_line(Data.story["extras"]["weather"]["waited_log"].format({"cost": GameState.fmt(GameState.weather_wait_cost)}), "warn")
	if GameState.damage.is_empty():
		add_line(words["lines"]["no_damage"], "good")
		return
	var cost_kinds: Dictionary = Data.story["launch_screen"]["cost_kinds"]
	var parts: PackedStringArray = []
	for kind in GameState.damage:
		var amount: String = GameState.fmt(GameState.damage[kind])
		parts.append(cost_kinds.get(kind, kind + " {amount}%").format({"amount": amount}))
	add_line(words["lines"]["damage"].format({"what": ", ".join(parts)}), "warn")


func _process(delta: float) -> void:
	if not done:
		fly(delta)
	# The typing effect: show a few more letters of the log each frame.
	var total: int = log_label.get_total_character_count()
	if typed < total:
		typed = minf(typed + settings["type_chars_per_second"]["value"] * speed * delta, total)
		log_label.visible_characters = int(typed)
	elif done and not next_button.visible and not embedded:
		next_button.visible = true   # only after the last line has typed out


# Moves the ship along, sends a little data home, and runs what is due.
func fly(delta: float) -> void:
	var before: float = progress
	progress = minf(progress + delta * speed / trip_seconds, 1.0)
	var days_passed: float = trip_days * (progress - before)
	GameState.data_sent += GameState.get_flight_values()["data"] * settings["cruise_data_share"]["value"] * days_passed

	var routine: Array = settings["routine_at"]["value"]
	while next_routine < routine.size() and progress >= routine[next_routine]:
		add_line(words["lines"]["routine"], "good")
		next_routine += 1
	var events: Dictionary = settings["events"]
	while next_event < event_ids.size() and progress >= events[event_ids[next_event]]["at"]:
		run_event(event_ids[next_event])
		next_event += 1

	# On the ship, the arrival waits until every emergency is fixed or timed out.
	if progress >= 1.0 and pending.is_empty():
		finish()
	update_screen()


# Does this event's design check pass? No side effects (the ship asks this
# at the start to plan how many crew emergencies to add).
# Gives back { "ok": bool, "blanks": {...} }.
func check_event(event_id: String) -> Dictionary:
	var event: Dictionary = settings["events"][event_id]
	var values: Dictionary = GameState.get_flight_values()
	var limits: Dictionary = GameState.get_limits()
	var blanks: Dictionary = {}
	var ok: bool = false

	match event["check"]:
		"computer":
			ok = not is_simple_card("computer")
			blanks["computer"] = Data.version_name("computer", GameState.choices["computer"]).to_lower()
			blanks["days"] = GameState.fmt(event["data_lost_days"])
		"communications":
			ok = GameState.is_ok(values["communications"], limits["communications"])
			blanks["comms"] = GameState.fmt(values["communications"])
			blanks["limit"] = GameState.fmt(limits["communications"]["value"])
			blanks["percent"] = GameState.fmt(event.get("bad_data_rate_factor", 1.0) * 100.0)
		"power_margin":
			ok = values["power"] >= event["min_spare_power"]
			blanks["spare"] = GameState.fmt(values["power"])
		"fuel":
			var fuel: float = GameState.get_fuel_left()
			ok = fuel >= event["min_fuel"]
			blanks["fuel"] = GameState.fmt(maxf(fuel, 0.0))
			blanks["months"] = GameState.fmt(event["lifetime_months_lost"])
		"heat":
			# Near the Sun: heaters only (the simple card) can't get rid of heat.
			ok = not is_simple_card("thermal_control")
			blanks["thermal"] = card_phrase("thermal_control")
		"lunar_night":
			# Needs more than the simple (first) card in BOTH battery and heat control.
			ok = not is_simple_card("battery") and not is_simple_card("thermal_control")
			blanks["battery"] = card_phrase("battery")
			blanks["thermal"] = card_phrase("thermal_control")
			blanks["months"] = GameState.fmt(event["lifetime_months_lost"])
	return {"ok": ok, "blanks": blanks}


# A small problem fixes itself when the build quality (Assembly) is high.
func saved_by_quality(event_id: String) -> bool:
	return settings["events"][event_id]["small"] and GameState.get_build_result("build_quality") >= settings["build_quality"]["save_at_least"]


# Will this event become an emergency on the ship?
func will_need_crew(event_id: String) -> bool:
	return not check_event(event_id)["ok"] and not saved_by_quality(event_id)


# One flight event: check the design, then write a green, amber or red line.
func run_event(event_id: String) -> void:
	var lines: Dictionary = words["events"][event_id]
	var result: Dictionary = check_event(event_id)
	var blanks: Dictionary = result["blanks"]

	if result["ok"]:
		add_line(lines["good"].format(blanks), "good")
		GameState.record_flight_outcome(event_id, "good")
		return

	if saved_by_quality(event_id):
		add_line(lines["saved"].format(blanks), "warn")
		GameState.record_flight_outcome(event_id, "saved")
		return

	# On the ship: the crew gets a chance to fix it (an alert with a timer).
	if embedded and lines.has("alert"):
		pending[event_id] = blanks
		add_line(lines["alert"].format(blanks), "warn")
		emergency_started.emit(event_id, blanks)
		return

	apply_bad(event_id, blanks)


# The ship calls this: fixed = the player fixed it in time.
func resolve_event(event_id: String, fixed: bool) -> void:
	if not pending.has(event_id):
		return
	var blanks: Dictionary = pending[event_id]
	pending.erase(event_id)
	if fixed:
		add_line(words["events"][event_id]["fixed"].format(blanks), "good")
		GameState.record_flight_outcome(event_id, "fixed")
	else:
		apply_bad(event_id, blanks)


# The event goes badly: apply the loss and say why in red.
func apply_bad(event_id: String, blanks: Dictionary) -> void:
	var event: Dictionary = settings["events"][event_id]
	var lines: Dictionary = words["events"][event_id]
	var values: Dictionary = GameState.get_flight_values()
	var quality: Dictionary = settings["build_quality"]
	var build_quality: float = GameState.get_build_result("build_quality")
	var line_id: String = "bad"
	match event["check"]:
		"computer":
			var per_day: float = values["data"] * settings["cruise_data_share"]["value"]
			GameState.data_sent = maxf(GameState.data_sent - per_day * event["data_lost_days"], 0.0)
		"communications":
			GameState.data_rate_factor *= event["bad_data_rate_factor"]
		"power_margin", "heat":
			var instrument_id: String = hungriest_spare_instrument()
			if instrument_id != "":
				GameState.flight_instruments_off.append(instrument_id)
				blanks["instrument"] = Data.story["instruments"][GameState.get_destination_key()][instrument_id]["name"].to_lower()
			else:
				line_id = "bad_none"
				GameState.data_rate_factor *= event["no_instrument_data_rate_factor"]
				blanks["percent"] = GameState.fmt(event["no_instrument_data_rate_factor"] * 100.0)
		"fuel", "lunar_night":
			GameState.lifetime_lost += event["lifetime_months_lost"]
	add_line(lines[line_id].format(blanks), "bad")
	GameState.record_flight_outcome(event_id, "bad")

	# Low build quality: fixing the problem also costs money from the reserve.
	if build_quality < quality["low_below"]:
		GameState.cash_reserve -= quality["low_reserve_cost"]
		add_line(words["lines"]["low_quality"].format({"cost": GameState.fmt(quality["low_reserve_cost"])}), "warn")


# Is the player's pick for this part the first (simple) card?
func is_simple_card(part_id: String) -> bool:
	return GameState.choices[part_id] == Data.parts[part_id]["versions"].keys()[0]


# How the picked card reads inside a sentence, for example "heaters alone"
# (story.json "parts" > version > "phrase"; the card's name in small letters if none).
func card_phrase(part_id: String) -> String:
	var text: Dictionary = Data.story["parts"][part_id]["versions"][GameState.choices[part_id]]
	return text.get("phrase", text["name"].to_lower())


# The packed instrument that uses the most power, but not a key instrument
# (the mission needs those) and not one already switched off. "" if none.
func hungriest_spare_instrument() -> String:
	var best: String = ""
	var best_use: float = 0.0
	var instruments: Dictionary = GameState.get_instruments()
	for instrument_id in GameState.instruments_packed:
		if not instruments.has(instrument_id):
			continue   # packed for another mission (only when testing a screen alone)
		if GameState.get_key_instruments().has(instrument_id) or GameState.flight_instruments_off.has(instrument_id):
			continue
		var use: float = -instruments[instrument_id]["effects"]["power"]
		if use > best_use:
			best = instrument_id
			best_use = use
	return best


func finish() -> void:
	done = true
	add_line(words["lines"]["arrived"].format({"planet": planet}), "good")
	var bad_count: int = 0
	for outcome in GameState.flight_outcomes:
		if outcome["result"] == "bad":
			bad_count += 1
	if bad_count == 0:
		add_line(words["lines"]["all_good"], "good")
	else:
		add_line(words["lines"]["some_bad"].format({"count": bad_count}), "warn")
	trip_finished.emit()


# The day of the trip right now, and the whole trip in days.
func get_day() -> int:
	return int(trip_days * progress)


func get_trip_days() -> int:
	return int(trip_days)


# "Skip to arrival" on the ship: the rest of the trip happens at once. Nobody
# is walking the ship, so every emergency still open, or still to come, goes
# the way the design alone decides (like the old automatic flight).
func skip_to_end() -> void:
	for event_id in pending.keys():
		resolve_event(event_id, false)
	embedded = false   # no more crew chances
	while not done:
		fly(trip_seconds)   # one big step: every event that is due runs now


# One log line, for example "DAY 57  Solar flare! ..." in green, amber or red.
func add_line(text: String, kind: String) -> void:
	var colors: Dictionary = Data.game_data["dashboard"]["colors"]
	var color: String = {"good": colors["safe"], "warn": colors["warning"], "bad": colors["danger"]}[kind]
	var day: String = words["log_day"].format({"day": int(trip_days * progress)})
	# Only the newest few lines show; older lines scroll away (UPGRADE_PLAN_V3 E,
	# game_data.json hud > flight_log_lines). Only the new line types out.
	log_lines.append("[color=%s]%s%s[/color]" % [color, day, text])
	var keep: int = int(Data.game_data["hud"].get("flight_log_lines", 4))
	if log_lines.size() > keep:
		log_lines = log_lines.slice(log_lines.size() - keep)
	log_label.text = "\n".join(PackedStringArray(log_lines)) + "\n"
	typed = maxf(log_label.get_total_character_count() - (day + text).length() - 1, 0.0)
	log_label.visible_characters = int(typed)
	if kind != "warn":
		Sfx.play(kind)   # "good" or "bad"


# The clock, the map and the five tiles.
func update_screen() -> void:
	clock_label.text = words["clock"].format({"day": int(trip_days * progress), "days": int(trip_days)})
	map.set_progress(progress)

	var phase: String = "cruise"
	if progress < settings["phase_cruise_from"]["value"]:
		phase = "launch"
	elif progress >= settings["phase_arrival_from"]["value"]:
		phase = "arrival"
	tile_labels["phase"].text = words["phases"][phase]

	var delay: Dictionary = GameState.get_destination()["signal_delay_minutes"]
	var minutes: float = lerpf(delay["start"], delay["end"], progress)
	if minutes < 1.0:   # under a minute: show seconds (the Moon is about one light-second away)
		tile_labels["signal"].text = words["signal_seconds"].format({"seconds": GameState.fmt(minutes * 60.0)})
	else:
		tile_labels["signal"].text = words["signal_value"].format({"minutes": GameState.fmt(minutes)})

	var values: Dictionary = GameState.get_flight_values()
	var made: float = GameState.get_flight_power_made()
	tile_labels["power"].text = words["power_value"].format({"made": GameState.fmt(made), "used": GameState.fmt(made - values["power"])})

	var colors: Dictionary = Data.game_data["dashboard"]["colors"]
	tile_labels["reserve"].text = words["reserve_value"].format({"amount": GameState.fmt(GameState.cash_reserve)})
	tile_labels["reserve"].add_theme_color_override("font_color", Color.html(colors["safe"] if GameState.cash_reserve >= 0.0 else colors["danger"]))
	tile_labels["data"].text = words["data_value"].format({"amount": GameState.fmt(GameState.data_sent)})


func _on_speed_toggled(fast: bool) -> void:
	speed = settings["fast_speed"]["value"] if fast else 1.0
	speed_button.text = words["speed_button"].format({"speed": GameState.fmt(speed)})


func _on_next_pressed() -> void:
	next_button.disabled = true
	StageManager.go_next()
