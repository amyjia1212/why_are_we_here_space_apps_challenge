# flight.gd
# The flight, inside the ship (UPGRADE_PLAN_V2 step 21, based on reference 3).
# You walk the ship in first person while it flies to the Moon, Mars or Venus
# (about three minutes, with a day counter).
#   - Five rooms: Bridge, Power Room, Science Bay, Comms Room, Life Support.
#     Warm white walls, a navy floor, cyan and orange accents, ceiling lights,
#     windows to space, and furniture that shows what each room is for.
#   - The Bridge: pilot seats, a big window where the destination slowly grows,
#     and a wall screen with the flight log and the trip map (flight_log.tscn
#     in a SubViewport).
#   - Stations: glowing cyan floor pads, at least two per room. Calm tasks
#     (yellow) open now and then: walk there and press E for a little extra data.
#   - Emergencies (red): a flight event whose design check fails becomes an
#     alert with a timer at a station. Fix it in time and the loss is avoided;
#     miss it and the loss happens, with the reason in the flight log. A good
#     design gets fewer emergencies. Crew emergencies (a water leak...) top the
#     trip up to 3-5 emergencies.
#   - Halfway (2026-11-14): the Clean Room task. E at Instruments opens the
#     wipe-the-dust minigame on top of the ship; the trip pauses meanwhile.
#   - After the first trip, Enter skips to the arrival.
# The Hud (Tab tablet, waypoints, timers) reads get_tablet_map(), get_waypoints(),
# get_hud_timers() and get_goal_text() below.
# Layout and colors: game_data.json "ship". Rules: events.json "flight" > "ship".
# Words: story.json "flight_ship".
extends Node3D

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const BAR_SCENE = preload("res://scenes/inner_voice_bar.tscn")
const LOG_SCENE = preload("res://scenes/flight_log.tscn")
const SHIP_BUILDER = preload("res://scripts/ship_builder.gd")
const PROMPT_BOX = preload("res://scripts/prompt_box.gd")
const CLEAN_SCENE = preload("res://scenes/minigame_clean.tscn")
const PLANET_LOOK = preload("res://scripts/planet_look.gd")

const DIRECTIONS := {
	"north": Vector3(0, 0, -1), "south": Vector3(0, 0, 1),
	"east": Vector3(1, 0, 0), "west": Vector3(-1, 0, 0),
}

var ship: Dictionary      # game_data.json "ship"
var rules: Dictionary     # events.json "flight" > "ship"
var words: Dictionary     # story.json "flight_ship"

var player: CharacterBody3D
var flight_log: Control   # the flight log on the Bridge wall screen
var planet_node: Node3D
var room_rects: Dictionary = {}   # room id -> Rect2 (x, z, width, depth)
var stations: Dictionary = {}     # station id -> { "pos", "pad", "label", "light", "room" }

# Open tasks: key -> { "kind": "routine" | "event" | "crew", "id", "station",
#                      "task", "alert", "left" (seconds, emergencies only) }
var tasks: Dictionary = {}
var crew_plan: Array = []         # [ { "at": 0.5, "id": "water_leak" } ], soonest first
var routine_clock: float = 0.0
var arrived: bool = false
var near_station: String = ""
var rng := RandomNumberGenerator.new()

var alert_panel: PanelContainer
var alert_label: Label
var prompt_label: Label
var day_label: Label
var skip_label: Label
var inner_voice: Control


func _ready() -> void:
	# Safety net for pressing Play on this screen directly.
	if GameState.character_id == "":
		GameState.character_id = Data.game_data["setup"]["default_character"]
	if GameState.mission_id == "":
		GameState.mission_id = Data.missions.keys()[0]
	GameState.fill_default_choices()
	rng.randomize()

	ship = Data.game_data["ship"]
	rules = Data.flight["ship"]
	words = Data.story["flight_ship"]

	build_environment()
	# The rooms, furniture and station pads (shared with the Venus arrival).
	var builder: Node3D = SHIP_BUILDER.new()
	add_child(builder)
	builder.build(true)
	room_rects = builder.room_rects
	stations = builder.stations
	build_wall_screen()
	build_planet_and_stars()
	spawn_player()
	build_ui()
	# The real astronauts of this mission walk the ship (UPGRADE_PLAN_V6 C1): the same three all mission.
	Bots.spawn_walkers(self, ship["bot_routes"], Data.crew["missions"].get(GameState.get_destination_key(), []))
	Bots.set_alert(false)

	flight_log.emergency_started.connect(_on_emergency_started)
	flight_log.trip_finished.connect(_on_trip_finished)
	plan_crew_emergencies()
	GameState.clear_minigame_scores("clean")   # this trip's cleaning (empty = not done yet)
	inner_voice.say(words["voice_start"])
	build_sky_bodies()
	build_zero_g_toy()


func _exit_tree() -> void:
	Bots.set_alert(false)


# ---------- building the ship ----------

func build_environment() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.02)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1, 1, 1)
	environment.ambient_light_energy = 0.45
	env.environment = environment
	add_child(env)
	var sun := DirectionalLight3D.new()   # the Sun, off to one side: lights the planet
	sun.rotation_degrees = Vector3(-20, 60, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = false
	add_child(sun)


func box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func station_label(station_id: String) -> String:
	return words["stations"][station_id]["label"]


# The big screen on the Bridge: the flight log and the trip map.
func build_wall_screen() -> void:
	var info: Dictionary = ship["wall_screen"]
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	add_child(viewport)
	flight_log = LOG_SCENE.instantiate()
	# Seen from across the Bridge: the theme, scaled up (UI_POLISH_PLAN_V4).
	flight_log.theme = preload("res://scripts/ui_kit.gd").wall_theme(float(ship["wall_screen"].get("ui_scale", 1.45)))
	viewport.add_child(flight_log)
	var size: Array = info["size"]
	var quad := QuadMesh.new()
	quad.size = Vector2(size[0], size[1])
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = viewport.get_texture()
	var face: Vector3 = DIRECTIONS[info["face"]]
	var center: Vector3 = MeshKit.vec3(info["center"])
	var screen := MeshKit.add(self, quad, center + face * 0.03, mat)
	screen.rotation.y = atan2(face.x, face.z)   # a QuadMesh shows its +Z side
	var frame := MeshKit.box(self, Vector3(size[0] + 0.25, size[1] + 0.25, 0.05), center, Color(ship["screen_color"]))
	frame.rotation.y = screen.rotation.y
	# UI_POLISH_PLAN_V4 Step 3b: make it look like a real monitor built into the
	# ship: a warm-white bezel behind the navy frame, a thin cyan glow strip under
	# it, and a soft cyan light spilling onto the wall.
	var accent := Color(ship.get("accent_color", "#3fd9ff"))
	var bezel := MeshKit.box(self, Vector3(size[0] + 0.55, size[1] + 0.55, 0.03), center - face * 0.02, Color(0.93, 0.91, 0.86))
	bezel.rotation.y = screen.rotation.y
	var strip := MeshKit.add(self, box_mesh(Vector3(size[0] * 0.6, 0.05, 0.03)), center + face * 0.04 - Vector3(0, size[1] / 2.0 + 0.22, 0), MeshKit.glow(accent, 2.0))
	strip.rotation.y = screen.rotation.y
	var glow := OmniLight3D.new()
	glow.light_color = accent
	glow.light_energy = 0.5
	glow.omni_range = maxf(float(size[0]), 2.0)
	glow.shadow_enabled = false
	glow.position = center + face * 0.8
	add_child(glow)


# The destination outside the Bridge window (it grows during the trip), and stars.
func build_planet_and_stars() -> void:
	var p: Dictionary = ship["planet"]
	var color := Color(p["colors"].get(GameState.get_destination_key(), "#c8c8c8"))
	planet_node = MeshKit.sphere(self, float(p["radius"]), Vector3.ZERO, color, 48)
	# The real NASA map when it is in the project, else a better made-in-code
	# surface; a glowing edge and a slow spin (planet_look.gd, UPGRADE_PLAN_V3 D1).
	PLANET_LOOK.apply(planet_node, GameState.get_destination_key())
	update_planet(0.0)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = box_mesh(Vector3(0.35, 0.35, 0.35))
	multimesh.instance_count = int(ship["star_count"])
	var star_rng := RandomNumberGenerator.new()
	star_rng.seed = 11
	for i in multimesh.instance_count:
		var dir := Vector3(star_rng.randf_range(-1, 1), star_rng.randf_range(-0.6, 1), star_rng.randf_range(-1, 1)).normalized()
		multimesh.set_instance_transform(i, Transform3D(Basis(), dir * 220.0))
	var stars := MultiMeshInstance3D.new()
	stars.multimesh = multimesh
	stars.material_override = MeshKit.glow(Color(1, 1, 1), 2.0)
	add_child(stars)


func update_planet(progress: float) -> void:
	var p: Dictionary = ship["planet"]
	var bridge: Rect2 = room_rects["bridge"]
	# The planet's size ON SCREEN grows steadily (an angle, in degrees) from a dot
	# to filling the window. distance = radius / tan(half the angle).
	var angle: float = deg_to_rad(lerpf(float(p["start_angle_degrees"]), float(p["end_angle_degrees"]), progress))
	var distance: float = float(p["radius"]) / tan(angle / 2.0)
	planet_node.position = Vector3(0, float(p["height"]), bridge.position.y - distance)


func spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.position = MeshKit.vec3(ship["player_start"])
	player.rotation_degrees.y = ship["player_facing_degrees"]
	player.set_first_person(true)
	player.set_avatar(GameState.character_id)


func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	alert_panel = PanelContainer.new()
	alert_panel.theme_type_variation = &"AlertPanel"
	# Left, under the day counter, at most 620 pixels wide: clear of the Hud's
	# timer box (top right) and the segment strip (top middle).
	alert_panel.position = Vector2(16, 158)
	alert_panel.visible = false
	layer.add_child(alert_panel)
	alert_label = Label.new()
	alert_label.theme_type_variation = &"BodyText"
	alert_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	alert_label.custom_minimum_size.x = 620
	alert_panel.add_child(alert_label)

	# The day counter sits on a small dark chip, so it reads on the white walls (UI_POLISH_PLAN_V4).
	var day_chip := PanelContainer.new()
	day_chip.theme_type_variation = &"HintPanel"
	day_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	day_chip.position = Vector2(12, 116)
	layer.add_child(day_chip)
	day_label = Label.new()
	day_label.theme_type_variation = &"AccentText"
	day_chip.add_child(day_label)

	# The "E: ..." line: on a dark box, above the voice bar (prompt_box.gd).
	var box = PROMPT_BOX.new()
	layer.add_child(box)
	prompt_label = box.label

	skip_label = Label.new()
	skip_label.theme_type_variation = &"SmallText"
	skip_label.text = words["skip"]
	skip_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skip_label.position = Vector2(-16, 52)   # under the Hud's Q ? tag (top right)
	skip_label.visible = GameState.trips_flown > 0
	layer.add_child(skip_label)

	inner_voice = BAR_SCENE.instantiate()
	layer.add_child(inner_voice)
	build_need_bars(layer)


# ---------- the trip ----------

# How many crew emergencies, and when: enough to make 3-5 emergencies in all.
func plan_crew_emergencies() -> void:
	var event_ids: Array = flight_log.event_ids
	var design_fails: int = event_ids.filter(func(id): return flight_log.will_need_crew(id)).size()
	var count: int = mini(maxi(int(rules["min_emergencies"]) - design_fails, 1), maxi(int(rules["max_emergencies"]) - design_fails, 0))
	var crew_ids: Array = rules["crew"].keys()
	crew_ids.shuffle()
	var slots: Array = rules["crew_slots"]
	for i in mini(count, mini(crew_ids.size(), slots.size())):
		var at: float = slots[i]
		# Not at the same moment as a design event.
		for event_id in event_ids:
			if absf(float(Data.flight["events"][event_id]["at"]) - at) < 0.06:
				at += 0.07
		crew_plan.append({"at": at, "id": crew_ids[i]})
	crew_plan.sort_custom(func(a, b): return a["at"] < b["at"])


func _process(delta: float) -> void:
	if cleaning != null or talk_crew != "" or ship_task != null:
		return   # the Clean Room, a crew talk or a station job is open: the whole trip waits
	var progress: float = flight_log.progress
	update_planet(progress)
	day_label.text = words["day"].format({"day": flight_log.get_day(), "days": flight_log.get_trip_days()})
	if not arrived:
		while not crew_plan.is_empty() and progress >= crew_plan[0]["at"]:
			start_crew_emergency(crew_plan.pop_front()["id"])
		if clean_state == "waiting" and progress >= float(Data.extras["clean_room"]["flight_at"]):
			open_clean_task()
		drain_needs(delta)
		routine_clock += delta
		if routine_clock >= float(rules["routine_every_seconds"]):
			routine_clock = 0.0
			open_routine_task()
		tick_emergencies(delta)
	update_near_station()
	update_proper_fix(delta)
	update_extras(delta)
	update_alert_and_music()
	update_station_looks()


func _unhandled_input(event: InputEvent) -> void:
	if cleaning != null or ship_task != null:
		return
	if talk_crew != "":
		if event.is_action_pressed("interact") or event.is_action_pressed("confirm"):
			next_talk_line()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		if near_station != "":
			# An emergency needs E HELD for the proper fix (update_proper_fix);
			# a calm task is done with one press.
			if not is_emergency(task_key_at(near_station)):
				use_station(near_station)
			get_viewport().set_input_as_handled()
		elif spot_target != "":
			snap_postcard(spot_target)
			get_viewport().set_input_as_handled()
		elif crew_near != null:
			ask_crew()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_fix") and near_station != "" and is_emergency(task_key_at(near_station)):
		quick_fix(task_key_at(near_station))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("preview_1") or event.is_action_pressed("preview_2") or event.is_action_pressed("preview_3"):
		# The Bridge trip map views, like NASA's mission viewers (N9).
		for i in 3:
			if event.is_action_pressed("preview_" + str(i + 1)):
				flight_log.map.set_view(i)
				AudioManager.play_sfx("preview")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm") and skip_label.visible and not arrived:
		skip_label.visible = false
		get_viewport().set_input_as_handled()
		skip_to_arrival()


# A calm task at a random station that has nothing to do yet (at most 3 open).
func open_routine_task() -> void:
	var open: int = tasks.values().filter(func(t): return t["kind"] == "routine").size()
	if open >= 3:
		return
	var free: Array = stations.keys().filter(func(id): return not tasks.values().any(func(t): return t["station"] == id))
	if free.is_empty():
		return
	var station_id: String = free[rng.randi_range(0, free.size() - 1)]
	var text: String = words["stations"][station_id]["task"].format({"instrument": key_instrument_name()})
	tasks["routine:" + station_id] = {"kind": "routine", "id": station_id, "station": station_id, "task": text, "alert": ""}


func key_instrument_name() -> String:
	var keys: Array = GameState.get_key_instruments()
	if keys.is_empty():
		return ""
	return Data.story["instruments"][GameState.get_destination_key()][keys[0]]["name"].to_lower()


# The flight log says a design check failed: an emergency with a timer.
func _on_emergency_started(event_id: String, _blanks: Dictionary) -> void:
	var info: Dictionary = rules["emergencies"][event_id]
	var text: Dictionary = words["emergencies"][event_id]
	add_emergency("event:" + event_id, "event", event_id, info, text)


func start_crew_emergency(crew_id: String) -> void:
	var info: Dictionary = rules["crew"][crew_id]
	var text: Dictionary = words["crew"][crew_id]
	flight_log.add_line(text["log"], "warn")
	add_emergency("crew:" + crew_id, "crew", crew_id, info, text)


func add_emergency(key: String, kind: String, id: String, info: Dictionary, text: Dictionary) -> void:
	var seconds: float = info["seconds"]
	if info.has("design_part"):
		seconds *= float(info["factors"].get(GameState.choices.get(info["design_part"], ""), 1.0))
	tasks.erase("routine:" + info["station"])   # the emergency takes over that station
	tasks[key] = {"kind": kind, "id": id, "station": info["station"], "task": text["task"], "alert": text["alert"], "left": seconds}
	AudioManager.play_sfx("alarm")
	inner_voice.say(words["voice_alert"].format({"seconds": int(seconds)}))


func tick_emergencies(delta: float) -> void:
	for key in tasks.keys():
		var task: Dictionary = tasks[key]
		if not task.has("left"):
			continue
		task["left"] -= delta
		if task["left"] <= 0.0:
			tasks.erase(key)
			miss_emergency(task)


func miss_emergency(task: Dictionary) -> void:
	AudioManager.play_sfx("bad")
	if task["kind"] == "event":
		flight_log.resolve_event(task["id"], false)
	else:
		var cost: float = rules["crew"][task["id"]]["miss_cost"]
		GameState.cash_reserve -= cost
		flight_log.add_line(words["crew"][task["id"]]["missed"].format({"cost": GameState.fmt(cost)}), "bad")
	inner_voice.say(words["voice_missed"] + moment_text(task["id"]))


# E at a station: fix its emergency first, otherwise do its calm task.
func use_station(station_id: String) -> void:
	var key: String = task_key_at(station_id)
	# Life Support (UPGRADE_PLAN_V6 C2): eat, drink or swap the air filter any time,
	# unless an emergency is waiting there. The first time, a learn card teaches it.
	if need_for_station(station_id) != "" and not is_emergency(key):
		start_need_job(station_id, key)
		return
	if key == "":
		learn_station(station_id)
		return
	var task: Dictionary = tasks[key]
	if task["kind"] == "clean":
		start_cleaning()   # the task stays open until the minigame is finished
		return
	tasks.erase(key)
	AudioManager.play_sfx("task_done")
	match task["kind"]:
		"event":
			flight_log.resolve_event(task["id"], true)
			inner_voice.say(Data.voice["extras"]["proper_fix"] + moment_text(task["id"]))
		"crew":
			flight_log.add_line(words["crew"][task["id"]]["fixed"], "good")
			inner_voice.say(Data.voice["extras"]["proper_fix"] + moment_text(task["id"]))
		"routine":
			GameState.data_sent += float(rules["routine_data_gb"])
			flight_log.add_line(words["task_log"].format({"task": task["task"]}), "good")
			learn_station(station_id)   # the first time here: what this station is for (C2)


# The most urgent open task at a station ("" = none).
func task_key_at(station_id: String) -> String:
	var best: String = ""
	var best_left: float = INF
	for key in tasks:
		var task: Dictionary = tasks[key]
		if task["station"] != station_id:
			continue
		# A calm task has no timer: rank it after every emergency. (Bug fixed 2026-11-15:
		# it used INF - 1.0, which is still INF, so calm tasks and the Clean Room never opened.)
		var left: float = task.get("left", 1.0e9)
		if left < best_left:
			best = key
			best_left = left
	return best


var current_room: String = ""


# A door whoosh when you walk into a room, a soft beep when you reach a station.
func play_place_sounds(old_station: String) -> void:
	var here := Vector2(player.global_position.x, player.global_position.z)
	var room: String = "hallway"
	for room_id in room_rects:
		if room_rects[room_id].has_point(here):
			room = room_id
	if room != current_room:
		if current_room != "":
			AudioManager.play_sfx("door")
		current_room = room
	if near_station != "" and near_station != old_station:
		AudioManager.play_sfx("station")


func update_near_station() -> void:
	var old_station: String = near_station
	near_station = ""
	var reach: float = rules["reach_meters"]
	var best: float = reach
	var here := Vector3(player.global_position.x, 0, player.global_position.z)
	for station_id in stations:
		var d: float = here.distance_to(stations[station_id]["pos"])
		if d <= best:
			best = d
			near_station = station_id
	play_place_sounds(old_station)
	if near_station == "":
		prompt_label.text = ""
		return
	var key: String = task_key_at(near_station)
	var need: String = need_for_station(near_station)
	if need != "" and not is_emergency(key):
		prompt_label.text = Data.story["ship_life"]["prompt"].format({"job": Data.story["ship_life"]["bars"][need]["job"], "bar": Data.story["ship_life"]["bars"][need]["name"], "value": int(needs[need])})
	elif key == "":
		prompt_label.text = words["all_good"].format({"label": station_label(near_station)})
	elif is_emergency(key):
		# Two ways to fix it (extras): hold E (proper) or R (quick, costs later).
		var fix_words: Dictionary = Data.story["extras"]["two_way_fix"]
		var hold: float = Data.extras["two_way_fix"]["proper_hold_seconds"]
		if fixing_key == key:
			prompt_label.text = fix_words["holding"].format({"percent": int(fix_time / hold * 100.0)})
		else:
			prompt_label.text = tasks[key]["task"] + "\n" + fix_words["prompt"].format({"seconds": GameState.fmt(hold)})
	else:
		prompt_label.text = words["press"].format({"task": tasks[key]["task"]})


# The red alert at the top (the most urgent emergency), the tension music
# while one is open, and the staff run during alerts.
func update_alert_and_music() -> void:
	var urgent: Dictionary = most_urgent()
	alert_panel.visible = not urgent.is_empty()
	if not urgent.is_empty():
		alert_label.text = urgent["alert"] + "  ·  " + str(int(ceil(urgent["left"]))) + " s"
	AudioManager.play_music("tension" if not urgent.is_empty() else "space")
	Bots.set_alert(not urgent.is_empty())


func most_urgent() -> Dictionary:
	var best: Dictionary = {}
	for task in tasks.values():
		if task.has("left") and (best.is_empty() or task["left"] < best["left"]):
			best = task
	return best


# Pads glow cyan (nothing to do), yellow (a calm task) or red (an emergency).
func update_station_looks() -> void:
	for station_id in stations:
		var key: String = task_key_at(station_id)
		var color := Color(ship["accent_color"])
		var label_text: String = station_label(station_id)
		if key != "":
			var task: Dictionary = tasks[key]
			color = Color(ship["emergency_glow_color"] if task.has("left") else ship["task_glow_color"])
			label_text += "\n" + task["task"]
			if task.has("left"):
				label_text += "  " + str(int(ceil(task["left"]))) + " s"
		var s: Dictionary = stations[station_id]
		var mat: StandardMaterial3D = s["pad"].material_override
		mat.albedo_color = color
		mat.emission = color
		s["light"].light_color = color
		s["label"].modulate = color
		s["label"].text = label_text
		# Standing on the pad: the prompt at the bottom says it, so the big label hides.
		s["label"].visible = station_id != near_station


func skip_to_arrival() -> void:
	for key in tasks.keys():
		tasks.erase(key)
	if clean_state != "done":
		clean_state = "skipped"   # skipping costs nothing (like the launch's Skip)
	flight_log.skip_to_end()


func _on_trip_finished() -> void:
	if arrived:
		return
	arrived = true
	for key in tasks.keys():
		if tasks[key]["kind"] == "routine":
			tasks.erase(key)
	miss_cleaning_if_open()
	apply_quick_fix_costs()
	# The checklist (UPGRADE_PLAN_V3 A3): we made it across. The orbit burn
	# event ticks "arrive"; after a skip it counts as done.
	GameState.set_phase_goal("cruise", "done")
	# A real mission for comparison (UPGRADE_PLAN_V3 C3: nasa_resources.json real_missions).
	for mission in GameState.real_list("real_missions"):
		if mission.get("shows_in", []).has("flight_" + GameState.get_destination_key()) and mission.has("flight_log_line"):
			flight_log.add_line(mission["flight_log_line"].format({"day": flight_log.get_day()}), "good")
	for goal_id in GameState.goal_ids_in_phase("arrive"):
		if GameState.goals.get(goal_id, "open") == "open":
			GameState.set_goal(goal_id, "done")
	GameState.trips_flown += 1
	skip_label.visible = false
	inner_voice.say(Data.story["flight_screen"]["lines"]["arrived"].format({"planet": flight_log.planet}))
	AudioManager.play_sfx("done")
	await get_tree().create_timer(float(Data.game_data["walk"]["end_read_seconds"])).timeout
	if is_inside_tree():
		StageManager.go_next()


# ---------- the Clean Room, halfway through the trip (2026-11-14) ----------
# Numbers: extras.json "clean_room". Words: story.json extras > clean.

var clean_state: String = "waiting"   # "waiting", "open" (task at the pad), "done", "skipped"
var cleaning: CanvasLayer = null      # the minigame on top of the ship while it is open


# Halfway: a yellow task at Instruments in the Science Bay.
func open_clean_task() -> void:
	clean_state = "open"
	var clean_words: Dictionary = Data.story["extras"]["clean"]
	var station_id: String = Data.extras["clean_room"]["flight_station"]
	tasks.erase("routine:" + station_id)   # the cleaning takes over that pad
	tasks["clean"] = {"kind": "clean", "id": "clean", "station": station_id, "task": clean_words["flight_task"], "alert": ""}
	flight_log.add_line(clean_words["flight_log"], "warn")
	AudioManager.play_sfx("station")
	inner_voice.say(Data.voice["extras"]["clean_halfway"])


# E at the pad: the Clean Room minigame opens on top of the ship. The trip,
# its timers and the player all wait until it is finished.
func start_cleaning() -> void:
	cleaning = CanvasLayer.new()
	cleaning.layer = 55   # over the ship's panels AND the Hud's top bar (2026-11-15: the key strip covered its title)
	var game: Control = CLEAN_SCENE.instantiate()
	var frame: Control = game.get_node("Frame")
	frame.embedded = true
	frame.get_node("Workshop").free()   # no build workshop here: the ship is the background
	frame.all_done.connect(_on_cleaning_done)
	flight_log.process_mode = Node.PROCESS_MODE_DISABLED
	player.process_mode = Node.PROCESS_MODE_DISABLED
	prompt_label.text = ""
	alert_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	add_child(cleaning)
	cleaning.add_child(game)


func _on_cleaning_done() -> void:
	cleaning.queue_free()
	cleaning = null
	tasks.erase("clean")
	clean_state = "done"
	flight_log.process_mode = Node.PROCESS_MODE_INHERIT
	player.process_mode = Node.PROCESS_MODE_INHERIT
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	AudioManager.play_sfx("task_done")
	Achievements.unlock("clean_instrument")
	var score: String = GameState.fmt(GameState.get_team_score("clean"))
	flight_log.add_line(Data.story["extras"]["clean"]["flight_done"].format({"score": score}), "good")


# The ship arrived and nobody cleaned: CLEANLINESS gets missed_score.
func miss_cleaning_if_open() -> void:
	if clean_state == "done" or clean_state == "skipped":
		return
	tasks.erase("clean")
	clean_state = "done"
	var missed: int = int(Data.extras["clean_room"]["missed_score"])
	GameState.clear_minigame_scores("clean")
	GameState.add_minigame_score("clean", missed)
	flight_log.add_line(Data.story["extras"]["clean"]["flight_missed"].format({"score": missed}), "bad")


# ---------- the extras (2026-11-14, data/extras.json) ----------

# Two-way fixes: hold E at an emergency for the proper fix, or R for a quick
# one that costs something at the end of the trip.
var fixing_key: String = ""
var fix_time: float = 0.0


func is_emergency(key: String) -> bool:
	return key != "" and tasks.has(key) and tasks[key].has("left")


func update_proper_fix(delta: float) -> void:
	var key: String = task_key_at(near_station) if near_station != "" else ""
	if not is_emergency(key) or not Input.is_action_pressed("interact"):
		fixing_key = ""
		fix_time = 0.0
		return
	if key != fixing_key:
		fixing_key = key
		fix_time = 0.0
	fix_time += delta
	if fix_time >= float(Data.extras["two_way_fix"]["proper_hold_seconds"]):
		fixing_key = ""
		fix_time = 0.0
		use_station(near_station)


func quick_fix(key: String) -> void:
	var task: Dictionary = tasks[key]
	tasks.erase(key)
	AudioManager.play_sfx("task_done")
	if task["kind"] == "event":
		flight_log.resolve_event(task["id"], true)
	else:
		flight_log.add_line(words["crew"][task["id"]]["fixed"], "good")
	flight_log.add_line(Data.story["extras"]["two_way_fix"]["quick_note"], "warn")
	GameState.quick_fixes.append({"kind": task["kind"], "day": flight_log.get_day()})
	inner_voice.say(Data.voice["extras"]["quick_fix"] + moment_text(task["id"]))


# The bill for every quick fix comes at the end of the trip.
func apply_quick_fix_costs() -> void:
	var costs: Dictionary = Data.extras["two_way_fix"]["quick_costs"]
	var fix_words: Dictionary = Data.story["extras"]["two_way_fix"]
	for fix in GameState.quick_fixes:
		if fix["kind"] == "event":
			var gb: float = costs["event"]["data_gb"]
			GameState.data_sent = maxf(GameState.data_sent - gb, 0.0)
			flight_log.add_line(fix_words["quick_log_event"].format({"day": fix["day"], "amount": GameState.fmt(gb)}), "bad")
		else:
			var cash: float = costs["crew"]["cash"]
			GameState.cash_reserve -= cash
			flight_log.add_line(fix_words["quick_log_crew"].format({"day": fix["day"], "amount": GameState.fmt(cash)}), "bad")


# Real Mission Moments: after each problem, one line about a real spacecraft
# that had it too (story.json extras > moments). Also printed in the flight log.
func moment_text(problem_id: String) -> String:
	var moments: Dictionary = Data.story["extras"]["moments"]
	if not moments.has(problem_id):
		return ""
	flight_log.add_line(moments["title"] + " " + moments[problem_id], "good")
	return " " + moments["title"] + " " + moments[problem_id]


# The zero-g toy: a little plush floats up off the Bridge console as the trip starts.
var toy: Node3D
var toy_time: float = 0.0
var toy_risen: bool = false


func build_zero_g_toy() -> void:
	var info: Dictionary = Data.extras["zero_g_toy"]
	var spot: Vector3 = MeshKit.vec3(info["position"])
	toy = Node3D.new()
	add_child(toy)
	toy.position = Vector3(spot.x, float(info["start_height"]), spot.z)
	var body := Color(info["body_color"])
	var ears := Color(info["ear_color"])
	MeshKit.sphere(toy, 0.13, Vector3(0, 0, 0), body, 12)
	MeshKit.sphere(toy, 0.1, Vector3(0, 0.18, 0), body, 12)
	for side in [-1, 1]:
		MeshKit.sphere(toy, 0.045, Vector3(side * 0.07, 0.27, 0), ears, 8)
		MeshKit.sphere(toy, 0.045, Vector3(side * 0.13, 0.02, 0), body, 8)   # arms
	MeshKit.sphere(toy, 0.018, Vector3(-0.035, 0.2, 0.09), Color(0.1, 0.1, 0.1), 6)
	MeshKit.sphere(toy, 0.018, Vector3(0.035, 0.2, 0.09), Color(0.1, 0.1, 0.1), 6)
	var tag := MeshKit.label(toy, Data.story["extras"]["zero_g"]["tag"], Vector3(0, 0.45, 0), 0.0025, Color(info["body_color"]))
	tag.fixed_size = false
	var rise := create_tween()
	rise.tween_interval(1.5)
	rise.tween_property(toy, "position:y", spot.y, float(info["rise_seconds"])).set_trans(Tween.TRANS_SINE)
	rise.tween_callback(func():
		toy_risen = true
		inner_voice.say(Data.voice["extras"]["zero_g"]))


# Window spotting: Earth and the Moon behind the ship (Earth shrinks as we
# leave), the Sun off to the side. With the destination ahead, these are the
# things you can photograph from a window.
var sky_bodies: Dictionary = {}   # id -> Node3D
var window_spots: Array = []      # Vector3 middle of each window
var spot_target: String = ""      # the body you are looking at from a window ("" = none)
var crew_near: Node3D = null


func build_sky_bodies() -> void:
	var info: Dictionary = Data.extras["spotting"]
	var earth := MeshKit.sphere(self, float(info["earth_radius"]), Vector3.ZERO, Color(info["earth_color"]), 48)
	PLANET_LOOK.apply(earth, "earth")
	sky_bodies["earth"] = earth
	var destination: String = GameState.get_destination_key()
	if destination != "moon":
		var moon := MeshKit.sphere(self, float(info["earth_radius"]) * float(info["moon_radius_share"]), Vector3.ZERO, Color(info["moon_color"]), 24)
		PLANET_LOOK.apply(moon, "moon")
		sky_bodies["moon"] = moon
	var sun_dir: Vector3 = MeshKit.vec3(info["sun_direction"]).normalized()
	var sun := MeshKit.add(self, SphereMesh.new(), sun_dir * float(info["sun_distance"]), MeshKit.glow(Color(info["sun_color"]), 4.0))
	sun.scale = Vector3.ONE * float(info["sun_radius"]) * 2.0
	sky_bodies["sun"] = sun
	sky_bodies[destination] = planet_node
	# The middle of every window (game_data.json ship > windows).
	for window in ship["windows"]:
		var rect: Rect2 = room_rects[window["room"]]
		var y: float = (float(ship["window_bottom"]) + float(ship["window_top"])) / 2.0
		var c: float = window["center"]
		match window["wall"]:
			"north":
				window_spots.append(Vector3(c, y, rect.position.y))
			"south":
				window_spots.append(Vector3(c, y, rect.end.y))
			"west":
				window_spots.append(Vector3(rect.position.x, y, c))
			_:
				window_spots.append(Vector3(rect.end.x, y, c))
	build_satellites()
	update_sky_bodies(0.0)


func update_sky_bodies(progress: float) -> void:
	var info: Dictionary = Data.extras["spotting"]
	var back_z: float = room_rects["comms_room"].end.y
	var angle: float = deg_to_rad(lerpf(float(info["earth_start_degrees"]), float(info["earth_end_degrees"]), progress))
	var distance: float = float(info["earth_radius"]) / tan(angle / 2.0)
	var behind := Vector3(0, 1.6, back_z + distance)
	# 2026-11-15 (team note): first you see Earth out the FRONT window (we just
	# left it), then it swings past the right-hand windows to behind the ship,
	# while the destination grows ahead. earth_swing_until = the share of the
	# trip the swing takes; after it, Earth shrinks behind (the back window).
	var swing: Dictionary = info.get("earth_swing", {})
	var until: float = float(swing.get("until", 0.0))
	if until > 0.0 and progress < until:
		var s: float = progress / until
		var front: Vector3 = earth_front_point(info, swing)
		var side := Vector3(float(swing["side_x"]), 1.0, 2.0)
		sky_bodies["earth"].position = front * (1.0 - s) * (1.0 - s) + side * 2.0 * (1.0 - s) * s + behind * s * s
	else:
		sky_bodies["earth"].position = behind
	# Earth's Moon rides next to Earth, but only when the Moon is NOT where we are
	# going (bug fixed 2026-11-15: on Moon trips the destination was pulled back
	# next to Earth, so it never showed in the Bridge window).
	if GameState.get_destination_key() != "moon" and sky_bodies.has("moon"):
		var offset: Vector3 = MeshKit.vec3(info["moon_offset"]) * (maxf(distance, 24.0) / 40.0)
		sky_bodies["moon"].position = sky_bodies["earth"].position + offset
	update_satellites(progress)


# Where Earth sits at the start: low and to the right in the Bridge window, big.
func earth_front_point(info: Dictionary, swing: Dictionary) -> Vector3:
	var bridge: Rect2 = room_rects["bridge"]
	var eye := Vector3(0, 1.6, bridge.position.y + 2.5)
	var size: float = deg_to_rad(float(info["earth_start_degrees"]))
	var reach: float = float(info["earth_radius"]) / tan(size / 2.0)
	var yaw: float = deg_to_rad(float(swing["front_right_degrees"]))
	var pitch: float = deg_to_rad(float(swing["front_down_degrees"]))
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), -cos(yaw) * cos(pitch))
	return eye + dir * reach


# Satellites drifting past the side windows while we are still near Earth.
var satellites: Array = []   # { "node": Node3D, "x": float, "y": float, "from": float, "to": float, "spin": float }

func build_satellites() -> void:
	var info: Dictionary = Data.extras["spotting"].get("satellites", {})
	var count: int = int(info.get("count", 0))
	var sat_rng := RandomNumberGenerator.new()
	sat_rng.seed = 7
	for i in count:
		var sat := Node3D.new()
		add_child(sat)
		MeshKit.box(sat, Vector3(0.9, 0.9, 1.2), Vector3.ZERO, Color(info["body_color"]))
		for side in [-1.0, 1.0]:
			MeshKit.box(sat, Vector3(2.4, 0.05, 0.9), Vector3(side * 1.75, 0, 0), Color(info["panel_color"]))
		MeshKit.cylinder(sat, 0.45, 0.05, 0.3, Vector3(0, 0.6, 0), Color(info["dish_color"]))
		sat.rotation = Vector3(sat_rng.randf_range(-0.6, 0.6), sat_rng.randf_range(0, TAU), sat_rng.randf_range(-0.4, 0.4))
		var side_sign: float = -1.0 if i % 2 == 0 else 1.0
		satellites.append({
			"node": sat,
			"x": side_sign * sat_rng.randf_range(float(info["side_min"]), float(info["side_max"])),
			"y": sat_rng.randf_range(-1.0, 4.0),
			"from": -float(info["start_ahead"]) - i * float(info["gap"]),
			"to": float(info["start_ahead"]) + 20.0,
			"spin": sat_rng.randf_range(-0.4, 0.4),
		})
	update_satellites(0.0)


func update_satellites(progress: float) -> void:
	if satellites.is_empty():
		return
	var until: float = float(Data.extras["spotting"]["satellites"]["until"])
	var s: float = progress / until
	for sat in satellites:
		var node: Node3D = sat["node"]
		node.visible = s < 1.0
		if not node.visible:
			continue
		node.position = Vector3(sat["x"], sat["y"], lerpf(sat["from"], sat["to"], s))
		node.rotation.y += sat["spin"] * get_process_delta_time()


func update_extras(delta: float) -> void:
	update_sky_bodies(flight_log.progress)
	PLANET_LOOK.spin_all(sky_bodies.values(), delta)
	if toy != null and toy_risen:
		toy_time += delta
		var info: Dictionary = Data.extras["zero_g_toy"]
		toy.position.y = float(info["position"][1]) + sin(toy_time * 1.3) * float(info["bob_meters"])
		toy.rotation.y += deg_to_rad(float(info["spin_degrees_per_second"])) * delta
		toy.rotation.z = sin(toy_time * 0.7) * 0.3
	spot_target = ""
	crew_near = null
	if near_station != "":
		return
	spot_target = find_spot_target()
	var spot_words: Dictionary = Data.story["extras"]["spotting"]
	if spot_target != "":
		prompt_label.text = spot_words["prompt"].format({"name": spot_words["names"].get(spot_target, spot_target)})
		return
	crew_near = Bots.nearest_walker(player.global_position, float(Data.extras["ask_crew"]["reach_meters"]))
	if crew_near != null:
		prompt_label.text = Data.story["extras"]["ask_crew"]["prompt"]


# The sky body the player looks at from near a window, or "".
func find_spot_target() -> String:
	var info: Dictionary = Data.extras["spotting"]
	var here: Vector3 = player.global_position
	var close: bool = false
	for spot in window_spots:
		if Vector2(here.x - spot.x, here.z - spot.z).length() <= float(info["window_reach_meters"]):
			close = true
	if not close:
		return ""
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return ""
	var eye: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_transform.basis.z
	var best: String = ""
	var best_angle: float = deg_to_rad(float(info["look_degrees"]))
	for body_id in sky_bodies:
		var node: Node3D = sky_bodies[body_id]
		var to_body: Vector3 = node.global_position - eye
		var angle: float = forward.angle_to(to_body)
		if angle < best_angle:
			best = body_id
			best_angle = angle
	return best


# E at a window: a sighting, and a photo of the view for the report.
func snap_postcard(body_id: String) -> void:
	var info: Dictionary = Data.extras["spotting"]
	var spot_words: Dictionary = Data.story["extras"]["spotting"]
	var name_text: String = spot_words["names"].get(body_id, body_id)
	AudioManager.play_sfx("stamp")
	var first: bool = not GameState.sightings.has(body_id)
	if first:
		GameState.sightings.append(body_id)
	if first:
		inner_voice.say(spot_words["got"].format({"name": name_text, "count": GameState.sightings.size(), "total": sky_bodies.size()}))
	else:
		inner_voice.say(spot_words["got_again"].format({"name": name_text}))
	Achievements.unlock("postcard")
	if GameState.postcards.size() < int(info["max_postcards"]) and DisplayServer.get_name() != "headless":
		take_photo()


# The photo: every on-screen panel hides for one frame, so the postcard shows
# only the view out of the window.
func take_photo() -> void:
	var hidden: Array = []
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if layer.visible:
			layer.visible = false
			hidden.append(layer)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	for layer in hidden:
		if is_instance_valid(layer):
			layer.visible = true
	if image != null and not image.is_empty():
		var pixels: Array = Data.extras["spotting"]["postcard_pixels"]
		image.resize(int(pixels[0]), int(pixels[1]), Image.INTERPOLATE_BILINEAR)
		GameState.postcards.append(image)


# Ask the crew: a real astronaut gets a paused fact card (UPGRADE_PLAN_V6 C1);
# other staff say one line about the room they stand in.
func ask_crew() -> void:
	if crew_near.has_meta("crew_id"):
		start_crew_talk(str(crew_near.get_meta("crew_id")))
		return
	var here := Vector2(crew_near.global_position.x, crew_near.global_position.z)
	var room: String = "hallway"
	for room_id in room_rects:
		if room_rects[room_id].has_point(here):
			room = room_id
	var crew_words: Dictionary = Data.story["extras"]["ask_crew"]
	AudioManager.play_sfx("preview")
	inner_voice.say(crew_words["speaker"] + ": " + crew_words["rooms"].get(room, crew_words["rooms"]["hallway"]))


# ---------- life on the ship (UPGRADE_PLAN_V6 C2 + C5) ----------
# Three bars: Hunger, Hydration, Air. They drain as the trip goes. Food, Water
# and Air in Life Support refill them, each with a short hands-on job. Low bars
# slow you down; an empty one ends the trip and it starts again (the design stays).

const LEARN_CARD = preload("res://scripts/learn_card.gd")
const SHIP_TASK = preload("res://scripts/ship_task.gd")

var needs: Dictionary = {}       # bar id -> 0..100
var need_bars: Dictionary = {}   # bar id -> ProgressBar
var ship_task: Control = null    # the open station job (the trip waits)
var trip_over: bool = false
var learned_here: Array = []     # stations whose learn card was shown on this trip


func build_need_bars(layer: CanvasLayer) -> void:
	var info: Dictionary = Data.supplies["needs"]
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GlassPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 16
	panel.offset_right = 16 + 180
	panel.offset_bottom = -16
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	for need_id in info["bars"]:
		needs[need_id] = float(info["start"])
		var label := Label.new()
		label.theme_type_variation = &"SmallText"
		label.text = Data.story["ship_life"]["bars"][need_id]["name"]
		column.add_child(label)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(148, 12)
		bar.max_value = 100.0
		column.add_child(bar)
		need_bars[need_id] = bar
	update_need_bars()


func need_for_station(station_id: String) -> String:
	var bars: Dictionary = Data.supplies["needs"]["bars"]
	for need_id in bars:
		if bars[need_id]["station"] == station_id:
			return need_id
	return ""


func drain_needs(delta: float) -> void:
	if trip_over:
		return
	var info: Dictionary = Data.supplies["needs"]
	var seconds: float = maxf(flight_log.trip_seconds, 1.0)
	for need_id in needs:
		needs[need_id] = maxf(needs[need_id] - float(info["bars"][need_id]["empties_per_trip"]) * 100.0 * delta / seconds, 0.0)
		if needs[need_id] <= 0.0:
			fail_trip(need_id)
			return
	update_need_bars()
	# A low bar makes walking slow (you are tired, thirsty or out of breath).
	var low: bool = needs.values().any(func(v): return v < float(info["slow_below"]))
	player.walk_speed = float(info["walk_speed"]) * (float(info["slow_factor"]) if low else 1.0)


func update_need_bars() -> void:
	var info: Dictionary = Data.supplies["needs"]
	for need_id in need_bars:
		var bar: ProgressBar = need_bars[need_id]
		bar.value = needs[need_id]
		var color_name: String = "go_color"
		if needs[need_id] < float(info["slow_below"]):
			color_name = "danger_color"
		elif needs[need_id] < float(info["remind_below"]):
			color_name = "caution_color"
		bar.modulate = bar.get_theme_color(color_name, &"Status")


# The lowest bar under the reminder line, for the voice bar's "what to do now" ("" = none).
func low_need() -> String:
	var info: Dictionary = Data.supplies["needs"]
	var worst: String = ""
	for need_id in needs:
		if needs[need_id] < float(info["remind_below"]) and (worst == "" or needs[need_id] < needs[worst]):
			worst = need_id
	return worst


# E at Food, Water or Air: the learn card the first time, then the small job, then the refill.
func start_need_job(station_id: String, routine_key: String) -> void:
	var go := func(): open_ship_task(station_id, routine_key)
	if not learn_station(station_id, go):
		go.call()


func open_ship_task(station_id: String, routine_key: String) -> void:
	var need_id: String = need_for_station(station_id)
	var job: String = Data.supplies["needs"]["bars"][need_id]["job"]
	var layer := CanvasLayer.new()
	layer.layer = 55
	add_child(layer)
	ship_task = SHIP_TASK.new()
	ship_task.setup(job)
	layer.add_child(ship_task)
	player.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ship_task.done.connect(func():
		layer.queue_free()
		ship_task = null
		player.frozen = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		needs[need_id] = minf(needs[need_id] + float(Data.supplies["needs"]["bars"][need_id]["restore"]), 100.0)
		update_need_bars()
		GameState.ship_log_add(Data.supplies["needs"]["bars"][need_id]["log"])
		Achievements.unlock("first_" + need_id)
		inner_voice.say(Data.story["ship_life"]["bars"][need_id]["done_voice"])
		# A calm task here is done by the same job.
		if routine_key != "" and tasks.has(routine_key):
			tasks.erase(routine_key)
			GameState.data_sent += float(rules["routine_data_gb"])
			flight_log.add_line(words["task_log"].format({"task": station_label(station_id)}), "good"))


# The first time a station is used: a paused card teaches what it is (story.json ship_life > learn).
# Gives back true when a card opened (then on_close runs after it).
func learn_station(station_id: String, on_close: Callable = Callable()) -> bool:
	var cards: Dictionary = Data.story["ship_life"]["learn"]
	if not cards.has(station_id) or learned_here.has(station_id):
		return false
	learned_here.append(station_id)
	GameState.ship_log_add("stations_learned", station_id)
	Achievements.unlock("learn_" + station_id)
	LEARN_CARD.open(self, cards[station_id], Data.story["ship_life"]["learn_button"], on_close)
	return true


# A bar hit zero: the crew cannot go on. The trip starts again (the design stays).
func fail_trip(need_id: String) -> void:
	trip_over = true
	GameState.ship_log_add("trips_failed")
	Achievements.unlock("ran_out")
	var life: Dictionary = Data.story["ship_life"]
	var card: Dictionary = {"kicker": life["fail_kicker"], "title": life["bars"][need_id]["fail_title"], "lines": [life["bars"][need_id]["fail_text"], life["fail_how"]]}
	LEARN_CARD.open(self, card, life["fail_button"], func():
		GameState.restart_trip()
		StageManager.go_to("flight"))


# ---------- talking to the real crew (UPGRADE_PLAN_V6 C1) ----------
# The trip pauses. The voice bar shows the astronaut's name and portrait and a
# narrator tells their sourced facts one at a time (E or Enter for the next).
# The last line always says that their place on this crew is our game's idea.

var talk_lines: Array = []     # what is still to come
var talk_crew: String = ""     # "" = nobody is being talked to


func start_crew_talk(crew_id: String) -> void:
	var person: Dictionary = Data.crew["people"][crew_id]
	talk_crew = crew_id
	talk_lines = [person["one_line"] + "."] + person["facts"]
	talk_lines.append(Data.crew["game_choice_line"].format({"name": person["name"]}))
	talk_lines.append(Data.story["crew_talk"]["source_label"] + " " + str(person["source"]))
	flight_log.process_mode = Node.PROCESS_MODE_DISABLED
	player.frozen = true
	inner_voice.set_speaker(person["name"], "crew_" + crew_id)
	inner_voice.set_meta("hold", true)   # the fact stays until E / Enter
	AudioManager.play_sfx("preview")
	GameState.ship_log_add("crew_talks", crew_id)
	Achievements.unlock("met_" + crew_id)
	next_talk_line()


func next_talk_line() -> void:
	if talk_lines.is_empty():
		end_crew_talk()
		return
	var line: String = talk_lines.pop_front()
	inner_voice.say(line + "   " + Data.story["crew_talk"]["next_hint"])


func end_crew_talk() -> void:
	talk_crew = ""
	inner_voice.set_meta("hold", false)
	flight_log.process_mode = Node.PROCESS_MODE_INHERIT
	player.frozen = false
	inner_voice.set_speaker(Data.voice["speaker_name"], "")
	inner_voice.say(Data.story["crew_talk"]["back_line"])


# ---------- the Hud (tablet map, waypoints, timers, goal) ----------

func get_tablet_map() -> Dictionary:
	var rooms: Array = []
	for room_id in room_rects:
		rooms.append({"name": Data.story["ship"]["room_names"][room_id], "rect": room_rects[room_id]})
	rooms.append({"name": "", "rect": to_rect(ship["hallway"])})
	var points: Array = []
	for task in tasks.values():
		points.append({"pos": stations[task["station"]]["pos"], "label": task["task"], "urgent": task.has("left")})
	return {"player": player.global_position, "yaw": player.rotation.y, "center": Vector3(0, 0, 2), "rooms": rooms, "points": points}


func get_waypoints() -> Array:
	var points: Array = []
	if cleaning != null:
		return points   # no markers over the Clean Room
	for task in tasks.values():
		var point := {"pos": stations[task["station"]]["pos"], "label": task["task"], "urgent": task.has("left")}
		if task.has("left"):
			point["seconds"] = task["left"]
		points.append(point)
	return points


func get_hud_timers() -> Array:
	var timers: Array = []
	if cleaning != null:
		return timers
	for task in tasks.values():
		if task.has("left"):
			timers.append({"label": task["task"], "seconds": task["left"]})
	return timers


# The Q card (UPGRADE_PLAN_V3 A2): the station you stand at, the zero-g plush
# when you are next to it, else the trip itself (cruise).
func get_question_id() -> String:
	if cleaning != null:
		return ""
	if near_station != "":
		return str(ship.get("station_questions", {}).get(near_station, "cruise"))
	if toy != null and player.global_position.distance_to(toy.global_position) <= float(rules["reach_meters"]) + 0.8:
		return "zero_g_indicator"
	if spot_target != "" and not GameState.glossary_entry(spot_target).is_empty():
		return spot_target   # looking at Mars, Venus or the Moon from a window
	return "cruise"


func get_goal_text() -> String:
	var urgent: Dictionary = most_urgent()
	if not urgent.is_empty():
		return words["goal_fix"].format({"task": urgent["task"]})
	# A low life bar comes right after the alarms (UPGRADE_PLAN_V6 C2).
	var need: String = low_need()
	if need != "":
		return Data.story["ship_life"]["bars"][need]["low_goal"]
	if clean_state == "open":
		return Data.story["extras"]["clean"]["flight_goal"]
	# The next calm job (UPGRADE_PLAN_V6 A5): the open yellow task nearest to the player.
	var best: String = ""
	var best_distance: float = INF
	for task in tasks.values():
		var d: float = player.global_position.distance_to(stations[task["station"]]["pos"])
		if d < best_distance:
			best = task["task"]
			best_distance = d
	if best != "":
		return words["goal_next"].format({"task": best})
	return words["goal_trip"].format({"planet": flight_log.planet})


# ---------- small helpers ----------

func to_rect(box: Dictionary) -> Rect2:
	var x0: float = box["x"][0]
	var z0: float = box["z"][0]
	return Rect2(x0, z0, float(box["x"][1]) - x0, float(box["z"][1]) - z0)


func v2_to_v3(a: Array) -> Vector3:
	return Vector3(a[0], 0, a[1])
