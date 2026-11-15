# minigame_clean.gd
# Build job 0: the Clean Room (the "more stuff" list, 2026-11-14). Dust specks
# land on the instrument one by one. Hold the mouse button and move the cloth
# over them to wipe them off before the timer ends. Real spacecraft are built
# in clean rooms so Earth germs don't travel to Mars (planetary protection).
# Score = specks wiped / specks x 100. The team average becomes CLEANLINESS,
# which counts in the teamwork score.
# Numbers: data/extras.json "clean_room". Words: story.json extras > clean.
extends Control

@onready var frame: Control = $Frame

var settings: Dictionary   # extras.json "clean_room"
var words: Dictionary      # story.json extras > clean
var rng := RandomNumberGenerator.new()

var board: Control         # the instrument, drawn in _draw_board
var playing: bool = false
var time_left: float = 0.0
var spawn_clock: float = 0.0
var spawned: int = 0
var wiped: int = 0
var specks: Array = []     # Vector2 spots on the board


func _ready() -> void:
	settings = Data.extras["clean_room"]
	words = Data.story["extras"]["clean"]
	rng.randomize()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.play_area.add_child(center)
	board = Control.new()
	var pixels: Array = settings["instrument_size_pixels"]
	board.custom_minimum_size = Vector2(pixels[0], pixels[1])
	board.visible = false
	board.mouse_filter = Control.MOUSE_FILTER_PASS
	board.draw.connect(_draw_board)
	center.add_child(board)
	frame.turn_started.connect(_on_turn_started)
	frame.setup("clean")


func _on_turn_started(_player_index: int) -> void:
	time_left = settings["duration_seconds"]
	spawn_clock = 0.0
	spawned = 0
	wiped = 0
	specks.clear()
	board.visible = true
	playing = true
	show_status()


func show_status() -> void:
	frame.set_status(words["status"].format({"count": wiped, "total": int(settings["specks"])}))


func _process(delta: float) -> void:
	if not playing:
		return
	time_left -= delta
	frame.set_time_left(time_left)
	spawn_clock -= delta
	if spawn_clock <= 0.0 and spawned < int(settings["specks"]):
		spawn_clock = settings["spawn_every_seconds"]
		spawned += 1
		var margin: float = 30.0
		specks.append(Vector2(rng.randf_range(margin, board.size.x - margin), rng.randf_range(margin, board.size.y - margin)))
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		wipe(board.get_local_mouse_position())
	board.queue_redraw()
	# Over when time runs out, or when every speck has landed and been wiped.
	if time_left <= 0.0 or (spawned >= int(settings["specks"]) and specks.is_empty()):
		end_turn()


func wipe(at: Vector2) -> void:
	var radius: float = settings["wipe_radius_pixels"]
	for i in range(specks.size() - 1, -1, -1):
		if specks[i].distance_to(at) <= radius:
			specks.remove_at(i)
			wiped += 1
			AudioManager.play_sfx("type")
	show_status()


func _draw_board() -> void:
	var rect := Rect2(Vector2.ZERO, board.size)
	board.draw_rect(rect, board.get_theme_color("panel_color", &"Minigame"))
	# The instrument: a gold box with a round lens in the middle.
	var gold := Color(Data.game_data["arrival_props"]["gold"])
	board.draw_rect(rect.grow(-24.0), gold)
	board.draw_circle(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.22, Color(0.1, 0.12, 0.18))
	board.draw_circle(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.12, Color(0.25, 0.45, 0.7))
	var font: Font = board.get_theme_default_font()
	var font_size: int = board.get_theme_font_size("font_size", &"SmallText")
	board.draw_string(font, Vector2(36.0, 56.0), words["instrument"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.15, 0.12, 0.05))
	var dust: Color = board.get_theme_color("dim_text_color", &"Minigame").darkened(0.4)
	for speck in specks:
		board.draw_circle(speck, float(settings["speck_size_pixels"]), dust)
	# The cloth follows the mouse (brighter while wiping).
	if playing:
		var cloth: Color = board.get_theme_color("good_color", &"Minigame")
		cloth.a = 0.75 if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 0.35
		board.draw_circle(board.get_local_mouse_position(), float(settings["wipe_radius_pixels"]), cloth)


func end_turn() -> void:
	playing = false
	board.visible = false
	frame.finish_turn(roundi(wiped * 100.0 / float(settings["specks"])))
