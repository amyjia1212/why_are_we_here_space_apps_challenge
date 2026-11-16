# minigame_frame.gd
# The frame around every build minigame (Assembly, Hammering, Fueling).
# It runs the turns, so each minigame only has to play ONE turn:
#   1. the tutorial card (UPGRADE_PLAN_V2 step 17): three short steps, a tiny
#      moving example and "Press Space to start". The full card shows the
#      first time a minigame is played; after that only the turn line shows,
#      and the "?" button opens the full card again.
#   2. the minigame plays in %PlayArea, then calls finish_turn(score)
#   3. "Player 2 scored 80 out of 100" + Next player
#   4. after the last player: every score and the team average + Next
# How a minigame uses it:
#   frame.turn_started.connect(_on_turn_started)
#   frame.setup("assembly", {"freeze": 0.5})
#   ... later: frame.finish_turn(80)
extends Control

# Sent when a player presses Start. player_index starts at 0.
signal turn_started(player_index: int)
# Sent instead of going to the next screen when the frame is embedded.
signal all_done

# true = this minigame pops up INSIDE another screen (the Clean Room during
# the flight, 2026-11-14): the last "Next" sends all_done instead of changing
# the screen. Set it before the minigame is added to the tree.
var embedded: bool = false

# Which minigames already showed their full tutorial (stays for the whole game).
static var tutorials_seen: Dictionary = {}

@onready var title_label: Label = %Title
@onready var status_label: Label = %Status
@onready var timer_label: Label = %TimerLabel
@onready var how_to_label: Label = %HowTo
@onready var play_area: Control = %PlayArea
@onready var overlay: Panel = %Overlay
@onready var overlay_title: Label = %OverlayTitle
@onready var overlay_body: Label = %OverlayBody
@onready var overlay_button: Button = %OverlayButton

var game_id: String = ""        # "assembly", "hammer" or "fuel"
var words: Dictionary           # story.json "minigames"
var game_words: Dictionary      # story.json "minigames" > game_id
var how_to: String = ""
var player_index: int = 0
var state: String = ""          # what the overlay button does: "intro", "score" or "results"
var playing: bool = false       # a turn is running (the "?" button pauses it)

var help_button: Button
var example: Control            # the tiny moving example on the tutorial card
var steps_label: Label
var space_label: Label
var example_time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # the "?" card works while the game is paused
	add_to_group("frees_mouse")   # every build minigame needs the mouse (player.gd never grabs it then)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	overlay_button.pressed.connect(_on_overlay_button_pressed)
	make_tutorial_parts()


# The "?" button in the top row, and the extra parts of the tutorial card.
func make_tutorial_parts() -> void:
	var top_row: HBoxContainer = title_label.get_parent()
	help_button = Button.new()
	help_button.theme_type_variation = &"SmallButton"
	help_button.focus_mode = Control.FOCUS_NONE
	help_button.custom_minimum_size = Vector2(48, 48)
	help_button.pressed.connect(_on_help_pressed)
	top_row.add_child(help_button)
	# Room for the Hud's "Q ?" sign in the top-right corner, so it no longer
	# sits on top of the "?" button (UPGRADE_PLAN_V6 A4).
	var q_gap := Control.new()
	q_gap.custom_minimum_size.x = float(Data.minigames["tutorial"].get("q_tag_gap_pixels", 200))
	q_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(q_gap)

	var column: VBoxContainer = overlay_title.get_parent()
	steps_label = Label.new()
	steps_label.theme_type_variation = &"BodyText"
	steps_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(steps_label)
	column.move_child(steps_label, overlay_body.get_index() + 1)

	example = Control.new()
	example.custom_minimum_size = Vector2(0, Data.minigames["tutorial"]["example_height_pixels"])
	example.draw.connect(_draw_example)
	column.add_child(example)
	column.move_child(example, steps_label.get_index() + 1)

	space_label = Label.new()
	space_label.theme_type_variation = &"SmallText"
	space_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(space_label)


# Call once from the minigame's _ready(). blanks fills {…} in the how-to line.
func setup(id: String, blanks: Dictionary = {}) -> void:
	game_id = id
	var workshop: Node = get_node_or_null("Workshop")   # the 3D workers behind the game (workshop_background.gd)
	if workshop != null:   # (an embedded minigame has none: the screen behind it is the background)
		workshop.set_job(id)
	words = Data.story["minigames"]
	# The Clean Room (extras, 2026-11-14) keeps its words in story.json extras > clean.
	game_words = words[game_id] if words.has(game_id) else Data.story["extras"][game_id]
	title_label.text = game_words["title"]
	how_to = game_words["how_to"].format(blanks)
	how_to_label.text = how_to
	help_button.text = words["help_button"]
	space_label.text = words["press_space"]
	GameState.clear_minigame_scores(game_id)
	player_index = 0
	show_intro()


# The minigame calls these while it plays.
func set_status(text: String) -> void:
	status_label.text = text


func set_time_left(seconds: float) -> void:
	timer_label.text = words["time_left"].format({"seconds": int(ceil(maxf(seconds, 0.0)))})


# The workshop behind the game (Assembly snaps parts onto its rocket).
func get_workshop() -> Node:
	return $Workshop


# The minigame calls this when the turn is over. score = 0 to 100.
func finish_turn(score: int) -> void:
	playing = false
	score = clampi(score, 0, 100)
	GameState.add_minigame_score(game_id, score)
	print(game_id, ": ", GameState.get_player_label(player_index), " scored ", score)
	timer_label.text = ""
	AudioManager.play_sfx("done")
	var last_player: bool = player_index + 1 >= player_total()
	show_overlay(
		words["your_score"].format({"player": GameState.get_player_label(player_index), "score": score}),
		"",
		words["results_button"] if last_player else words["next_player_button"],
		"score",
	)


func player_total() -> int:
	return maxi(GameState.player_count, 1)


# The turn card. The first time this minigame is played it is the full
# tutorial (three steps + the moving example); after that it is short.
func show_intro() -> void:
	status_label.text = ""
	timer_label.text = ""
	var full: bool = not tutorials_seen.has(game_id)
	tutorials_seen[game_id] = true
	show_overlay(
		words["your_turn"].format({"player": GameState.get_player_label(player_index)}),
		"" if full else how_to,
		words["start_button"],
		"intro",
		full,
	)


# The "?" button: show the full tutorial again. The game pauses while it is open.
func _on_help_pressed() -> void:
	if overlay.visible and state != "help":
		return
	if playing:
		get_tree().paused = true
	show_overlay(game_words["title"], "", words["back_button"], "help", true)


# Every player's score, the team average, and what it becomes.
func show_results() -> void:
	var lines: PackedStringArray = []
	var scores: Array = GameState.minigame_scores[game_id]
	for i in scores.size():
		lines.append(words["result_line"].format({"player": GameState.get_player_label(i), "score": scores[i]}))
	var average: String = GameState.fmt(GameState.get_team_score(game_id))
	lines.append("")
	lines.append(words["average_line"].format({"score": average}))
	lines.append(words["becomes_line"].format({"result": game_words["result_name"], "score": average}))
	lines.append("")
	lines.append(Data.voice["speaker_name"] + ": " + voice_line(GameState.get_team_score(game_id)))
	show_overlay(words["results_title"], "\n".join(lines), words["next_button"], "results")


# What the inner voice says about the team average (inner_voice.json "minigames").
func voice_line(average: float) -> String:
	var limits: Dictionary = Data.minigames["voice"]
	var kind: String = "ok"
	if average >= limits["good_at"]:
		kind = "good"
	elif average < limits["bad_below"]:
		kind = "bad"
	# Hammering has one real line: the launch's structure check (timing.json),
	# so the voice says "good" or "bad" exactly at that line. It is never wrong.
	if game_id == "hammer":
		kind = "good" if average >= Data.timing["structure_check"]["min_strength"] else "bad"
	var level: String = GameState.level if GameState.level != "" else "medium"
	if not Data.voice["minigames"].has(game_id):
		return Data.voice["extras"]["minigame_" + kind]   # the Clean Room (extras)
	return Data.voice["minigames"][game_id][kind][level]


func show_overlay(title: String, body: String, button_text: String, new_state: String, tutorial: bool = false) -> void:
	overlay_title.text = title
	overlay_body.text = body
	overlay_body.visible = body != ""
	var steps: Array = game_words.get("steps", [])
	var lines: PackedStringArray = []
	for i in steps.size():
		lines.append(str(i + 1) + ".  " + steps[i])
	# What real teams call this step (NASA_RESOURCES_PLAN.md N8, from CubeSat 101).
	if game_words.has("real_step"):
		lines.append("")
		lines.append(game_words["real_step"])
	steps_label.text = "\n".join(lines)
	steps_label.visible = tutorial
	example.visible = tutorial
	space_label.visible = new_state == "intro"
	# Before each build job: remind the player that Q explains it (UPGRADE_PLAN_V6 A4).
	if new_state == "intro" and words.has("q_reminder"):
		space_label.text = words["press_space"] + "\n" + words["q_reminder"]
		Hud.pulse_question_tag()
	overlay_button.text = button_text
	state = new_state
	overlay.visible = true
	# Wait a moment before the button works, so a player still mashing keys
	# from the game doesn't press it by accident (minigames.json "button_delay_seconds").
	overlay_button.disabled = true
	await get_tree().create_timer(Data.minigames["button_delay_seconds"], true).timeout
	if state == new_state:
		overlay_button.disabled = false
		overlay_button.grab_focus()   # so Enter or Space presses it too


func _on_overlay_button_pressed() -> void:
	match state:
		"intro":
			overlay.visible = false
			playing = true
			turn_started.emit(player_index)
		"help":
			overlay.visible = false
			state = ""
			if get_tree().paused:
				get_tree().paused = false
			else:
				show_intro_again()
		"score":
			player_index += 1
			if player_index < player_total():
				show_intro()
			else:
				show_results()
		"results":
			overlay_button.disabled = true
			if embedded:
				all_done.emit()
			else:
				StageManager.go_next()


# "?" was pressed on the turn card itself (not during play): go back to it.
func show_intro_again() -> void:
	if not playing:
		show_overlay(
			words["your_turn"].format({"player": GameState.get_player_label(player_index)}),
			how_to, words["start_button"], "intro")


func _process(delta: float) -> void:
	if example.visible and overlay.visible:
		example_time += delta
		example.queue_redraw()


# ---------- the tiny moving example on the tutorial card ----------

func _draw_example() -> void:
	var w: float = example.size.x
	var h: float = example.size.y
	var c := Vector2(w / 2.0, h / 2.0)
	var t: float = fmod(example_time, 3.0) / 3.0   # loops every 3 seconds
	var font: Font = example.get_theme_default_font()
	var font_size: int = example.get_theme_font_size("font_size", &"HeadingText")
	var text_color: Color = example.get_theme_color("text_color", &"Minigame")
	var dim: Color = example.get_theme_color("dim_text_color", &"Minigame")
	var good: Color = example.get_theme_color("good_color", &"Minigame")
	var target: Color = example.get_theme_color("target_color", &"Minigame")
	match game_id:
		"assembly":
			# The word FIN types itself, then a fin snaps onto a little rocket.
			var word: String = game_words.get("example_word", "FIN")
			var typed: int = mini(int(t * (word.length() + 2)), word.length())
			var x: float = c.x - 160.0
			for i in word.length():
				var color: Color = good if i < typed else dim
				example.draw_string(font, Vector2(x + i * 34.0, c.y + 14.0), word[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
			var rocket := Rect2(c.x + 90.0, c.y - 45.0, 34.0, 90.0)
			example.draw_rect(rocket, text_color)
			example.draw_colored_polygon(PackedVector2Array([rocket.position, rocket.position + Vector2(34, 0), rocket.position + Vector2(17, -26)]), target)
			if typed == word.length():
				var fin_x: float = rocket.position.x + 34.0
				example.draw_colored_polygon(PackedVector2Array([Vector2(fin_x, c.y + 10), Vector2(fin_x + 22, c.y + 45), Vector2(fin_x, c.y + 45)]), good)
		"hammer":
			# A hammer swings down onto a nail and sinks it, with sparks.
			var panel := Rect2(c.x - 150.0, c.y + 10.0, 300.0, 34.0)
			example.draw_rect(panel, example.get_theme_color("panel_color", &"Minigame"))
			var hit: bool = t > 0.45
			var nail_top: float = panel.position.y - (2.0 if hit else 22.0)
			example.draw_rect(Rect2(c.x - 4.0, nail_top, 8.0, panel.position.y - nail_top + 4.0), example.get_theme_color("nail_color", &"Minigame"))
			example.draw_rect(Rect2(c.x - 12.0, nail_top - 6.0, 24.0, 6.0), example.get_theme_color("nail_color", &"Minigame"))
			var swing: float = lerpf(-1.1, 0.0, clampf(t / 0.45, 0.0, 1.0)) if not hit else lerpf(0.0, -0.6, clampf((t - 0.45) * 3.0, 0.0, 1.0))
			draw_hammer(example, Vector2(c.x + 5.0, nail_top - 30.0), swing)
			if hit and t < 0.7:
				for k in 6:
					var a: float = PI + k * PI / 5.0
					example.draw_line(Vector2(c.x, nail_top - 6.0), Vector2(c.x, nail_top - 6.0) + Vector2(cos(a), sin(a)) * 22.0, example.get_theme_color("spark_color", &"Minigame"), 3.0)
		"clean":
			# A cloth sweeps across the instrument and the dust specks vanish behind it.
			var plate := Rect2(c.x - 150.0, c.y - 40.0, 300.0, 80.0)
			example.draw_rect(plate, example.get_theme_color("panel_color", &"Minigame"))
			var cloth_x: float = lerpf(plate.position.x, plate.end.x, t)
			for k in 8:
				var speck := Vector2(plate.position.x + 20.0 + k * 37.0, c.y + (12.0 if k % 2 == 0 else -14.0))
				if speck.x > cloth_x:
					example.draw_circle(speck, 6.0, dim)
			example.draw_circle(Vector2(cloth_x, c.y), 26.0, good)
		"fuel":
			# A valve wheel turns to the orange mark while the gauge fills.
			var turn: float = minf(t / 0.7, 1.0) * 200.0
			draw_wheel(example, Vector2(c.x - 50.0, c.y), 40.0, turn, 200.0)
			var gauge := Rect2(c.x + 60.0, c.y - 45.0, 26.0, 90.0)
			example.draw_rect(gauge, example.get_theme_color("gauge_back_color", &"Minigame"))
			var fill: float = gauge.size.y * turn / 360.0
			example.draw_rect(Rect2(gauge.position.x, gauge.end.y - fill, gauge.size.x, fill), example.get_theme_color("fuel_color", &"Minigame"))
			var mark_y: float = gauge.end.y - gauge.size.y * 200.0 / 360.0
			example.draw_line(Vector2(gauge.position.x - 8.0, mark_y), Vector2(gauge.end.x + 8.0, mark_y), target, 3.0)


# Shared drawings (the minigames use these too).
static func draw_hammer(canvas: Control, head_at: Vector2, swing: float) -> void:
	var handle_color: Color = canvas.get_theme_color("hammer_handle_color", &"Minigame")
	var head_color: Color = canvas.get_theme_color("hammer_head_color", &"Minigame")
	canvas.draw_set_transform(head_at + Vector2(46, 26), swing, Vector2.ONE)
	canvas.draw_line(Vector2(-46.0, -20.0), Vector2(8.0, 4.0), handle_color, 9.0)
	canvas.draw_rect(Rect2(-64.0, -36.0, 26.0, 34.0), head_color)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func draw_wheel(canvas: Control, center: Vector2, radius: float, angle_degrees: float, target_degrees: float) -> void:
	var wheel: Color = canvas.get_theme_color("wheel_color", &"Minigame")
	var target: Color = canvas.get_theme_color("target_color", &"Minigame")
	canvas.draw_arc(center, radius, 0.0, TAU, 64, wheel, radius * 0.18)
	var spin: float = -deg_to_rad(angle_degrees)
	for k in 4:
		var a: float = spin + k * PI / 2.0
		canvas.draw_line(center, center + Vector2(cos(a), sin(a)) * radius, wheel, radius * 0.1)
	canvas.draw_circle(center, radius * 0.18, wheel)
	# The knob on the rim shows how far it has turned.
	canvas.draw_circle(center + Vector2(cos(spin), sin(spin)) * radius, radius * 0.16, canvas.get_theme_color("text_color", &"Minigame"))
	if target_degrees >= 0.0:
		var ta: float = -deg_to_rad(target_degrees)
		var d := Vector2(cos(ta), sin(ta))
		canvas.draw_line(center + d * (radius * 1.12), center + d * (radius * 1.45), target, 5.0)
