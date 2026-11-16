# ship_crew.gd
# The party on the ship (MULTIPLAYER_PLAN_V6, shared ship, 2026-11-15): every
# teammate, bot or person, is on the SAME ship working on the SAME tasks.
#   - Teammates show as their toy characters with a name tag.
#   - Bots walk the hallway to a problem nobody started (after a few seconds)
#     and fix it there; when the ship is calm they do the calm tasks too.
#     Only the party leader's game (or the one computer in a bots party) moves
#     the bots; the others see them through the ship state the leader sends.
#   - Online, every computer sends where its player stands, 5 times a second.
# flight.gd makes this node and owns the tasks; this node only asks it
# screen.do_task(key, how, seat) when a bot finishes a job. planet_crew.gd
# extends it for the planet walk (arrival.gd), with its own bot jobs.
# Numbers: multiplayer.json "bots" and "ship_sync". Words: story.json "party".
extends Node3D

var screen: Node3D                 # the screen: flight.gd, or arrival.gd (through planet_crew.gd)
var avatars: Dictionary = {}       # seat -> { "node": Node3D, "target": Vector3, "yaw": float }
var bots: Dictionary = {}          # seat -> { "pos": Vector3, "yaw": float, "path": Array, "key": "", "how": "", "work_left": 0.0 }
var task_age: Dictionary = {}      # task key -> seconds it has been open
var send_clock: float = 0.0
var time: float = 0.0


func setup(owner_screen: Node3D) -> void:
	screen = owner_screen
	var start: Vector3 = start_spot()
	var spots: Array = Party.bots_on_my_ship()
	for i in spots.size():
		var seat: int = spots[i]
		# Beside the start spot, a few steps to each side (not in front of the camera).
		var pos: Vector3 = start + Vector3(-3.0 + 6.0 * float(i % 2), 0, -1.0 - floorf(i / 2.0) * 1.5)
		bots[seat] = {"pos": pos, "yaw": 0.0, "path": [], "key": "", "how": "", "work_left": 0.0}
		var avatar: Dictionary = ensure_avatar(seat)
		avatar["node"].position = pos
		avatar["target"] = pos


# Where the bots start (next to the player's start spot).
func start_spot() -> Vector3:
	return MeshKit.vec3(Data.game_data["ship"]["player_start"])


# ---------- the figures ----------

func ensure_avatar(seat: int) -> Dictionary:
	if avatars.has(seat):
		return avatars[seat]
	var character: String = ""
	if seat < Party.seats.size():
		character = str(Party.seats[seat].get("character", ""))
	if not Data.characters.has(character):
		character = Data.game_data["setup"]["default_character"]
	var node: Node3D = load(Data.characters[character]["scene"]).instantiate()
	add_child(node)
	var tag := Label3D.new()
	tag.text = Party.seat_name(seat) + ((" " + Data.story["party"]["bot_tag"]) if Party.is_bot(seat) else "")
	tag.font_size = 32
	tag.pixel_size = 0.0008
	tag.fixed_size = true   # the same size on screen near or far
	tag.outline_size = 8
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.position = Vector3(0, float(Data.mp["ship_sync"]["name_tag_height"]), 0)
	node.add_child(tag)
	avatars[seat] = {"node": node, "target": node.position, "yaw": 0.0, "tag": tag}
	return avatars[seat]


# A teammate's place from the network (a person's own message, or the leader's ship state for bots).
func set_target(seat: int, pos: Vector3, yaw: float) -> void:
	if seat == Party.my_seat:
		return
	var avatar: Dictionary = ensure_avatar(seat)
	if avatar["node"].position == Vector3.ZERO and avatar["target"] == Vector3.ZERO:
		avatar["node"].position = pos
	avatar["target"] = pos
	avatar["yaw"] = yaw


func _process(delta: float) -> void:
	time += delta
	if not bots.is_empty():
		tick_bots(delta)
	# Figures glide to where they should be, with a little toy wobble while they move.
	for seat in avatars:
		var avatar: Dictionary = avatars[seat]
		var node: Node3D = avatar["node"]
		var to_target: Vector3 = avatar["target"] - node.position
		node.position = node.position.lerp(avatar["target"], minf(delta * 10.0, 1.0))
		node.rotation.y = lerp_angle(node.rotation.y, avatar["yaw"], minf(delta * 10.0, 1.0))
		node.rotation.z = sin(time * 10.0 + seat) * 0.05 if to_target.length() > 0.05 else 0.0
	if Party.is_online():
		send_clock += delta
		if send_clock >= 1.0 / float(Data.mp["ship_sync"]["sends_per_second"]):
			send_clock = 0.0
			var me: Node3D = screen.player
			Net.send({"t": "pos", "p": [me.global_position.x, me.global_position.y, me.global_position.z], "y": me.rotation.y})
			if Party.is_leader():
				Net.send(screen.shared_state())


func bot_positions() -> Dictionary:
	var list: Dictionary = {}
	for seat in bots:
		var b: Dictionary = bots[seat]
		list[str(seat)] = [b["pos"].x, b["pos"].z, b["yaw"]]
	return list


func apply_bot_positions(list: Dictionary) -> void:
	for key in list:
		var p: Array = list[key]
		set_target(int(key), Vector3(float(p[0]), 0.0, float(p[1])), float(p[2]))


# ---------- the bots' jobs (leader / bots party only) ----------

func tick_bots(delta: float) -> void:
	if not Party.is_online() and (screen.cleaning != null or screen.talk_crew != "" or screen.ship_task != null):
		return   # one computer: the whole trip waits while my job is open, the bots too
	var rules: Dictionary = Data.mp["bots"]
	var tasks: Dictionary = screen.tasks
	for key in task_age.keys():
		if not tasks.has(key):
			task_age.erase(key)
	for key in tasks:
		task_age[key] = float(task_age.get(key, 0.0)) + delta
	for seat in bots:
		var b: Dictionary = bots[seat]
		# The job is gone (fixed by someone else, missed) or a person started it: drop it.
		if b["key"] != "" and (not tasks.has(b["key"]) or screen.fixing_key == b["key"]):
			b["key"] = ""
			b["path"] = []
		if b["key"] == "" and not screen.arrived:
			pick_job(seat, b, rules)
		walk(b, delta)
		if b["key"] != "" and b["path"].is_empty():
			b["work_left"] -= delta
			if b["work_left"] <= 0.0:
				var key: String = b["key"]
				b["key"] = ""
				screen.do_task(key, b["how"], seat)
		var avatar: Dictionary = ensure_avatar(seat)
		avatar["target"] = b["pos"]
		avatar["yaw"] = b["yaw"]


# Problems first (nobody started it for take_problem_after_seconds), then calm tasks.
func pick_job(seat: int, b: Dictionary, rules: Dictionary) -> void:
	var taken: Array = []
	for other in bots.values():
		if other["key"] != "":
			taken.append(other["key"])
	var best: String = ""
	for key in screen.tasks:
		var task: Dictionary = screen.tasks[key]
		if taken.has(key) or screen.fixing_key == key or not screen.stations.has(task["station"]):
			continue
		if task.has("left") and task_age[key] >= float(rules["take_problem_after_seconds"]):
			best = key
			break
		if best == "" and task["kind"] == "routine" and task_age[key] >= float(rules["take_routine_after_seconds"]):
			best = key
	if best == "":
		return
	var task: Dictionary = screen.tasks[best]
	b["key"] = best
	b["how"] = "bot" if task.has("left") else "routine"
	b["work_left"] = float(rules["fix_problem_in_seconds"] if task.has("left") else rules["routine_seconds"])
	b["path"] = route(b["pos"], screen.stations[task["station"]]["pos"])
	if task.has("left"):
		screen.log_line(Data.story["party"]["bot_fixing"].format({"name": Party.seat_name(seat), "task": task["task"]}), "warn")


func walk(b: Dictionary, delta: float) -> void:
	var step: float = float(Data.mp["bots"]["walk_speed"]) * delta
	while step > 0.0 and not b["path"].is_empty():
		var target: Vector3 = b["path"][0]
		target.y = 0.0
		var to_target: Vector3 = target - b["pos"]
		if to_target.length() <= step:
			b["pos"] = target
			step -= to_target.length()
			b["path"].pop_front()
		else:
			b["pos"] += to_target.normalized() * step
			b["yaw"] = atan2(-to_target.x, -to_target.z)   # the characters face -Z
			step = 0.0


# ---------- finding the way: room door -> hallway -> room door ----------

func room_at(p: Vector3) -> String:
	for room_id in screen.room_rects:
		if (screen.room_rects[room_id] as Rect2).grow(0.05).has_point(Vector2(p.x, p.z)):
			return room_id
	return "hall"


# [the doorway, the spot just outside it in the hallway]
func door_points(room_id: String) -> Array:
	var rect: Rect2 = screen.room_rects[room_id]
	var hall_x: float = screen.to_rect(Data.game_data["ship"]["hallway"]).get_center().x
	var c: Vector2 = rect.get_center()
	match str(Data.game_data["ship"]["rooms"][room_id]["door"]):
		"south":
			return [Vector3(c.x, 0, rect.end.y - 0.4), Vector3(c.x, 0, rect.end.y + 0.8)]
		"north":
			return [Vector3(c.x, 0, rect.position.y + 0.4), Vector3(c.x, 0, rect.position.y - 0.8)]
		"west":
			return [Vector3(rect.position.x + 0.4, 0, c.y), Vector3(hall_x, 0, c.y)]
	return [Vector3(rect.end.x - 0.4, 0, c.y), Vector3(hall_x, 0, c.y)]


func route(from: Vector3, to: Vector3) -> Array:
	var a: String = room_at(from)
	var b: String = room_at(to)
	to.y = 0.0
	if a == b:
		return [to]
	var path: Array = []
	if a != "hall":
		path.append_array(door_points(a))
	if b != "hall":
		var doors: Array = door_points(b)
		path.append(doors[1])
		path.append(doors[0])
	path.append(to)
	return path
