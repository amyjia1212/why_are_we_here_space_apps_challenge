# Bots.gd
# Toy-like staff and bot crewmates (UPGRADE_PLAN_V2 step 27).
#   spawn_walkers(parent, routes)  staff walk simple routes, wave now and then,
#                                  and run while an alert is on (set_alert)
#   add_scores_to_leaderboard()    in a solo game, three bot crewmates with names
#                                  show their scores on the leaderboard.
# DEFAULT: bot scores are for show and never change the mission result.
# Numbers: game_data.json "bots". Names: story.json "bots" (made-up names).
extends Node

var walkers: Array = []     # { "node", "path", "target", "wait", "speed" }
var alert: bool = false
var time: float = 0.0


func _process(delta: float) -> void:
	time += delta
	for i in range(walkers.size() - 1, -1, -1):
		var walker: Dictionary = walkers[i]
		if not is_instance_valid(walker["node"]):
			walkers.remove_at(i)
			continue
		move(walker, delta)


# routes = a list of paths; each path is a list of [x, y, z] points.
# The staff scenes come from game_data.json "bots" > "staff_scenes".
func spawn_walkers(parent: Node3D, routes: Array) -> void:
	var settings: Dictionary = Data.game_data["bots"]
	var scenes: Array = settings["staff_scenes"]
	for i in routes.size():
		var path: Array = []
		for point in routes[i]:
			path.append(Vector3(point[0], point[1], point[2]))
		if path.is_empty():
			continue
		var person: Node3D = load(scenes[i % scenes.size()]).instantiate()
		parent.add_child(person)
		person.position = path[0]
		# Ask the crew (extras, 2026-11-14): a "?" bubble; E next to them asks about the room.
		var ask: Dictionary = Data.extras["ask_crew"]
		var bubble := Label3D.new()
		bubble.text = "?"
		bubble.font_size = 64
		bubble.pixel_size = 0.006
		bubble.outline_size = 12
		bubble.modulate = Color(ask["bubble_color"])
		bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		bubble.position = Vector3(0, float(ask["bubble_height"]), 0)
		person.add_child(bubble)
		walkers.append({
			"node": person, "path": path, "target": 1 % path.size(),
			"wait": randf() * 2.0, "speed": float(settings["walk_speed"]), "phase": randf() * TAU,
		})


func set_alert(on: bool) -> void:
	alert = on


# The staff member closest to a point, within reach meters (null = nobody).
func nearest_walker(at: Vector3, reach: float) -> Node3D:
	var best: Node3D = null
	var best_distance: float = reach
	for walker in walkers:
		var person: Node3D = walker["node"]
		if not is_instance_valid(person) or not person.is_inside_tree():
			continue
		var d: float = Vector2(person.global_position.x - at.x, person.global_position.z - at.z).length()
		if d <= best_distance:
			best = person
			best_distance = d
	return best


func move(walker: Dictionary, delta: float) -> void:
	var settings: Dictionary = Data.game_data["bots"]
	var person: Node3D = walker["node"]
	var arm: Node3D = person.get("arm_r_node")
	if walker["wait"] > 0.0 and not alert:
		walker["wait"] -= delta
		# Waving while waiting.
		if arm != null:
			arm.rotation.z = 2.4 + sin(time * 8.0 + walker["phase"]) * 0.4
		return
	if arm != null:
		arm.rotation.z = 0.0
	var target: Vector3 = walker["path"][walker["target"]]
	var to_target: Vector3 = target - person.position
	to_target.y = 0.0
	if to_target.length() < 0.1:
		walker["target"] = (walker["target"] + 1) % walker["path"].size()
		walker["wait"] = float(settings["wait_seconds"])
		return
	var speed: float = walker["speed"] * (float(settings["alert_speed_multiplier"]) if alert else 1.0)
	var step: Vector3 = to_target.normalized() * minf(speed * delta, to_target.length())
	person.position += step
	person.rotation.y = atan2(-to_target.x, -to_target.z)   # the staff face -Z
	person.rotation.z = sin(time * 10.0 + walker["phase"]) * 0.05


# Solo game only: three bot crewmates' scores on the leaderboard. The old bot
# rows are taken off first, so bots never fill the whole board.
func add_scores_to_leaderboard() -> void:
	if GameState.player_count > 1:
		return
	var settings: Dictionary = Data.game_data["bots"]
	Leaderboard.runs = Leaderboard.runs.filter(func(run): return not run.get("bot", false))
	var player_score: int = GameState.get_report_score()["total"]
	var characters: Array = ["scientist", "janitor", "student"]
	var names: Array = Data.story["bots"]["crew"]
	for i in names.size():
		var spread: int = int(settings["score_spread"])
		var score: int = clampi(player_score + randi_range(-spread, spread), 0, 1000)
		Leaderboard.add_run(score, names[i], characters[i % characters.size()], true)
