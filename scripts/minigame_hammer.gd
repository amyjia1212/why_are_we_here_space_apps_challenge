# minigame_hammer.gd
# Build job 2: Hammering (UPGRADE_PLAN_V2 step 19). Nails pop up on a metal
# rocket panel. The mouse cursor is a hammer: click on a nail to swing and
# sink it (sparks and a clank). Clicking the bare panel dents it (looks only,
# no points lost). A nail you don't hit in time slides back out and stays loose.
# A count shows the nails left.
# Score = nails hit / nails_per_turn x 100. The team average becomes
# STRUCTURE STRENGTH (PLAN.md section 7).
# Numbers: data/minigames.json "hammer". Words: story.json "minigames".
extends Control

const FRAME = preload("res://scripts/minigame_frame.gd")   # the shared hammer drawing
const SWING_SECONDS := 0.14
const SPARK_SECONDS := 0.3

@onready var frame: Control = $Frame

var settings: Dictionary   # minigames.json "hammer"
var words: Dictionary      # story.json "minigames" > "hammer"
var rng := RandomNumberGenerator.new()

var board: Control         # draws the panel, the nails, the sparks and the hammer
var playing: bool = false
var spawn_clock: float = 0.0
var shown: int = 0
var hits: int = 0
var nails: Array = []      # { "pos": Vector2, "age": float, "state": "out" | "in" | "loose" }
var dents: Array = []      # Vector2
var sparks: Array = []     # { "pos": Vector2, "age": float }
var swing_left: float = 0.0


func _ready() -> void:
	settings = Data.minigames["hammer"]
	words = Data.story["minigames"]["hammer"]
	rng.randomize()
	board = Control.new()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	frame.play_area.add_child(board)
	frame.turn_started.connect(_on_turn_started)
	frame.setup("hammer")


func _on_turn_started(_player_index: int) -> void:
	spawn_clock = 0.0
	shown = 0
	hits = 0
	nails.clear()
	dents.clear()
	sparks.clear()
	show_count()
	spawn_nail()   # the first nail comes right away
	playing = true


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# The metal panel: the middle of the play area, with a margin.
func panel_rect() -> Rect2:
	var area: Vector2 = board.size
	return Rect2(Vector2(area.x * 0.08, area.y * 0.06), Vector2(area.x * 0.84, area.y * 0.88))


func time_left() -> float:
	var still_to_come: int = int(settings["nails_per_turn"]) - shown
	return still_to_come * float(settings["spawn_every_seconds"]) - spawn_clock + float(settings["nail_life_seconds"])


func _process(delta: float) -> void:
	swing_left = maxf(swing_left - delta, 0.0)
	for spark in sparks:
		spark["age"] += delta
	sparks = sparks.filter(func(s): return s["age"] < SPARK_SECONDS)
	# The hammer replaces the mouse arrow while the game is on (and the mouse is over the panel).
	var over: bool = playing and board.get_global_rect().has_point(board.get_global_mouse_position()) and not frame.overlay.visible
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if over else Input.MOUSE_MODE_VISIBLE
	board.queue_redraw()
	if not playing:
		return
	frame.set_time_left(time_left())
	for nail in nails:
		if nail["state"] == "out":
			nail["age"] += delta
			if nail["age"] >= settings["nail_life_seconds"]:
				nail["state"] = "loose"   # slid back out: a miss
				show_count()
	if shown < int(settings["nails_per_turn"]):
		spawn_clock += delta
		if spawn_clock >= settings["spawn_every_seconds"]:
			spawn_clock -= settings["spawn_every_seconds"]
			spawn_nail()
	elif not nails.any(func(n): return n["state"] == "out"):
		end_turn()


# A nail at a random free spot on the panel.
func spawn_nail() -> void:
	var rect: Rect2 = panel_rect().grow(-float(settings["hit_radius_pixels"]))
	var pos := Vector2.ZERO
	for attempt in 12:
		pos = Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
		if not nails.any(func(n): return n["state"] == "out" and n["pos"].distance_to(pos) < settings["hit_radius_pixels"] * 2.2):
			break
	nails.append({"pos": pos, "age": 0.0, "state": "out"})
	shown += 1
	AudioManager.play_sfx("preview")
	show_count()


func _on_board_input(event: InputEvent) -> void:
	if not playing or not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	swing_left = SWING_SECONDS
	var best: Dictionary = {}
	var best_distance: float = settings["hit_radius_pixels"]
	for nail in nails:
		var d: float = nail["pos"].distance_to(event.position)
		if nail["state"] == "out" and d <= best_distance:
			best = nail
			best_distance = d
	if not best.is_empty():
		best["state"] = "in"
		hits += 1
		sparks.append({"pos": best["pos"], "age": 0.0})
		AudioManager.play_sfx("clank")
		AudioManager.play_sfx("spark")
	elif panel_rect().has_point(event.position):
		dents.append(event.position)
		if dents.size() > int(settings["dent_limit"]):
			dents.pop_front()
		AudioManager.play_sfx("dent")
	show_count()


func show_count() -> void:
	var left: int = int(settings["nails_per_turn"]) - shown + nails.filter(func(n): return n["state"] == "out").size()
	frame.set_status(words["hits"].format({"hits": hits}) + "   " + words["left"].format({"left": left}))


func end_turn() -> void:
	playing = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	frame.finish_turn(roundi(hits * 100.0 / float(settings["nails_per_turn"])))


# ---------- drawing ----------

func _draw_board() -> void:
	if not playing and nails.is_empty():
		return
	var rect: Rect2 = panel_rect()
	var c := func(key: String) -> Color: return board.get_theme_color(key, &"Minigame")
	# The panel: metal with an orange stripe and a row of rivets on each edge.
	board.draw_rect(rect, c.call("panel_color"))
	board.draw_rect(rect, c.call("panel_edge_color"), false, 6.0)
	board.draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y * 0.45, rect.size.x, 18.0), c.call("target_color"))
	var rivets: int = 16
	for i in rivets + 1:
		var x: float = rect.position.x + rect.size.x * i / rivets
		board.draw_circle(Vector2(x, rect.position.y + 14.0), 5.0, c.call("rivet_color"))
		board.draw_circle(Vector2(x, rect.end.y - 14.0), 5.0, c.call("rivet_color"))
	for dent in dents:
		board.draw_circle(dent, 9.0, c.call("dent_color"))
		board.draw_arc(dent, 11.0, PI, TAU, 10, c.call("panel_edge_color"), 2.0)
	var head: float = settings["nail_size_pixels"] / 2.0
	for nail in nails:
		var p: Vector2 = nail["pos"]
		match nail["state"]:
			"in":
				board.draw_circle(p, head * 0.7, c.call("nail_sunk_color"))
			"loose":
				board.draw_circle(p, head * 0.6, c.call("bad_color"))
				board.draw_line(p, p + Vector2(head * 0.5, -head * 1.2), c.call("bad_color"), 4.0)
			_:
				# Sticking out: a shadow, a shaft and a shiny head. It shrinks as time runs out.
				var life: float = 1.0 - nail["age"] / float(settings["nail_life_seconds"])
				board.draw_circle(p + Vector2(6, 6), head * 0.8, c.call("dent_color"))
				board.draw_rect(Rect2(p.x - 4.0, p.y - head * 1.6, 8.0, head * 1.6), c.call("nail_color"))
				board.draw_circle(p - Vector2(0, head * 1.6), head, c.call("nail_color"))
				board.draw_arc(p - Vector2(0, head * 1.6), head + 6.0, -PI / 2.0, -PI / 2.0 + TAU * life, 32, c.call("target_color"), 4.0)
	for spark in sparks:
		var grow: float = spark["age"] / SPARK_SECONDS
		for k in 8:
			var a: float = k * TAU / 8.0
			var from: Vector2 = spark["pos"] + Vector2(cos(a), sin(a)) * (8.0 + 30.0 * grow)
			board.draw_line(from, from + Vector2(cos(a), sin(a)) * 12.0, c.call("spark_color"), 3.0)
	# The hammer follows the mouse and swings down on a click.
	if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		var swing: float = 0.0 if swing_left > 0.0 else -0.5   # down while striking, raised otherwise
		FRAME.draw_hammer(board, board.get_local_mouse_position() + Vector2(5, -24), swing)
