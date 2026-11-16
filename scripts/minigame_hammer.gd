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
	slide = minf(slide + delta / float(settings.get("slide_seconds", 0.35)), 1.0)
	if shown < int(settings["nails_per_turn"]):
		# A new panel comes only when every nail on this one is in or loose.
		var starts_panel: bool = shown % per_panel() == 0
		if not (starts_panel and nails.any(func(n): return n["state"] == "out")):
			spawn_clock += delta
		if spawn_clock >= settings["spawn_every_seconds"]:
			spawn_clock -= settings["spawn_every_seconds"]
			spawn_nail()
	elif not nails.any(func(n): return n["state"] == "out"):
		end_turn()


# --- Panels (UPGRADE_PLAN_V6 A7): one ship panel at a time, nails along its seam ---

var slide: float = 1.0   # 0 = the new panel is just sliding in, 1 = in place


func per_panel() -> int:
	return maxi(int(settings.get("nails_per_panel", 3)), 1)


func panel_count() -> int:
	return int(ceil(float(settings["nails_per_turn"]) / per_panel()))


# Which panel is on the board now (the panel of the newest nail).
func current_panel() -> int:
	return maxi(shown - 1, 0) / per_panel()


# How far right the panel still is while it slides in (pixels).
func slide_shift() -> Vector2:
	return Vector2((1.0 - ease(slide, 0.4)) * panel_rect().size.x, 0.0)


# A panel's outline in screen pixels, where it rests (add slide_shift() to draw it).
func panel_points(index: int) -> PackedVector2Array:
	var shapes: Array = settings["panels"]
	var shape: Array = shapes[index % shapes.size()]["points"]
	var rect: Rect2 = panel_rect()
	var points := PackedVector2Array()
	for p in shape:
		points.append(rect.position + Vector2(float(p[0]) * rect.size.x, float(p[1]) * rect.size.y))
	return points


# A point a share (0 to 1) of the way around an outline.
func point_on_outline(points: PackedVector2Array, share: float) -> Vector2:
	var total: float = 0.0
	for i in points.size():
		total += points[i].distance_to(points[(i + 1) % points.size()])
	var goal: float = share * total
	for i in points.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		var length: float = a.distance_to(b)
		if goal <= length:
			return a.lerp(b, goal / maxf(length, 0.001))
		goal -= length
	return points[0]


# The next nail: in order along the current panel's seam. The first nail of a
# panel brings the new panel in (the old one slides away).
func spawn_nail() -> void:
	var slot: int = shown % per_panel()
	if slot == 0:
		nails.clear()   # the finished panel leaves with its nails
		dents.clear()
		slide = 0.0 if shown > 0 else 1.0   # the very first panel is already in place
	shown += 1
	var pos: Vector2 = point_on_outline(panel_points(current_panel()), (slot + 0.5) / float(per_panel()))
	nails.append({"pos": pos, "age": 0.0, "state": "out"})
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
		var d: float = (nail["pos"] + slide_shift()).distance_to(event.position)
		if nail["state"] == "out" and d <= best_distance:
			best = nail
			best_distance = d
	if not best.is_empty():
		best["state"] = "in"
		hits += 1
		sparks.append({"pos": best["pos"] + slide_shift(), "age": 0.0})
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

# A small rocket in the top-right corner: one piece fills in per finished panel.
func draw_rocket_progress(c: Callable) -> void:
	var count: int = panel_count()
	var finished: int = current_panel() if nails.any(func(n): return n["state"] == "out") or shown < int(settings["nails_per_turn"]) else panel_count()
	var area: Vector2 = board.size
	var w: float = 44.0
	var piece: float = 22.0
	var top := Vector2(area.x - w - 24.0, 24.0)
	# The nose on top, then the body pieces from the bottom up.
	var nose := PackedVector2Array([top + Vector2(w / 2.0, 0), top + Vector2(w, piece), top + Vector2(0, piece)])
	board.draw_colored_polygon(nose, c.call("target_color") if finished >= count else c.call("dent_color"))
	for i in count - 1:
		var y: float = top.y + piece + (count - 2 - i) * piece
		var box := Rect2(top.x, y, w, piece - 3.0)
		board.draw_rect(box, c.call("target_color") if i < finished else c.call("dent_color"))
		board.draw_rect(box, c.call("panel_edge_color"), false, 2.0)

func _draw_board() -> void:
	if not playing and nails.is_empty():
		return
	var rect: Rect2 = panel_rect()
	var c := func(key: String) -> Color: return board.get_theme_color(key, &"Minigame")
	# The current ship panel (UPGRADE_PLAN_V6 A7): its own shape, a metal face, a
	# thick edge and its name; it slides in from the right.
	var shift: Vector2 = slide_shift()
	var outline := PackedVector2Array()
	for p in panel_points(current_panel()):
		outline.append(p + shift)
	board.draw_colored_polygon(outline, c.call("panel_color"))
	var closed := outline.duplicate()
	closed.append(outline[0])
	board.draw_polyline(closed, c.call("panel_edge_color"), 6.0)
	var shapes: Array = settings["panels"]
	var font: Font = board.get_theme_default_font()
	var font_size: int = board.get_theme_font_size("font_size", &"HeadingText")
	var panel_name: String = str(shapes[current_panel() % shapes.size()]["name"])
	board.draw_string(font, rect.position + Vector2(0, font_size) + shift, panel_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, c.call("target_color"))
	draw_rocket_progress(c)
	for dent in dents:
		board.draw_circle(dent, 9.0, c.call("dent_color"))
		board.draw_arc(dent, 11.0, PI, TAU, 10, c.call("panel_edge_color"), 2.0)
	var head: float = settings["nail_size_pixels"] / 2.0
	for nail in nails:
		var p: Vector2 = nail["pos"] + shift
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
