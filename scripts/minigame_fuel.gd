# minigame_fuel.gd
# Build job 3: Fueling. A target angle appears ("turn the valve 254°
# counterclockwise"). Drag the valve handle around and let go. 3 rounds.
# Each round: 100 points minus points_lost_per_degree for every degree off.
# The turn's score is the average of the rounds.
# The team average becomes FUEL LOADED (PLAN.md section 7).
# Numbers: data/minigames.json "fuel". Words: story.json "minigames".
extends Control

const VALVE_DIAL = preload("res://scenes/valve_dial.tscn")

@onready var frame: Control = $Frame

var settings: Dictionary   # minigames.json "fuel"
var words: Dictionary      # story.json "minigames" > "fuel"
var rng := RandomNumberGenerator.new()

var game_box: VBoxContainer
var target_label: Label
var result_label: Label
var dial: Control

var in_round: bool = false       # the player can turn the valve now
var round_time_left: float = 0.0
var wait_left: float = 0.0       # showing a round's result before the next one
var round_number: int = 0        # 1, 2, 3
var target: int = 0
var points_total: float = 0.0


func _ready() -> void:
	settings = Data.minigames["fuel"]
	words = Data.story["minigames"]["fuel"]
	rng.randomize()
	make_play_area()
	frame.turn_started.connect(_on_turn_started)
	frame.setup("fuel")


func make_play_area() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.play_area.add_child(center)

	game_box = VBoxContainer.new()
	game_box.add_theme_constant_override("separation", 8)
	game_box.visible = false
	center.add_child(game_box)

	target_label = Label.new()
	target_label.theme_type_variation = &"HeadingText"
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_box.add_child(target_label)

	dial = VALVE_DIAL.instantiate()
	game_box.add_child(dial)
	dial.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dial.setup(settings["dial_radius_pixels"], settings["handle_radius_pixels"], settings["show_live_angle"])
	dial.released.connect(finish_round)

	result_label = Label.new()
	result_label.theme_type_variation = &"BodyText"
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_box.add_child(result_label)

	# Mostly fuel (extras): how much of this rocket's weight on the pad is fuel.
	var share: float = Data.extras["mostly_fuel"]["fuel_share"].get(GameState.get_launch_vehicle_id(), 0.9)
	var fuel_line := Label.new()
	fuel_line.theme_type_variation = &"SmallText"
	fuel_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fuel_line.text = Data.story["extras"]["mostly_fuel"].format({"percent": int(round(share * 100.0))})
	game_box.add_child(fuel_line)
	# Right under the round's target, so it never runs off the bottom of the screen.
	game_box.move_child(fuel_line, target_label.get_index() + 1)


func _on_turn_started(_player_index: int) -> void:
	round_number = 0
	points_total = 0.0
	game_box.visible = true
	start_round()


func start_round() -> void:
	round_number += 1
	target = rng.randi_range(int(settings["min_angle"]), int(settings["max_angle"]))
	target_label.text = words["target"].format({"round": round_number, "rounds": int(settings["rounds"]), "angle": target})
	result_label.text = ""
	frame.set_status("")
	dial.reset()
	dial.set_target(target)
	dial.input_enabled = true
	round_time_left = settings["round_seconds"]
	in_round = true


func _process(delta: float) -> void:
	if in_round:
		round_time_left -= delta
		frame.set_time_left(round_time_left)
		if round_time_left <= 0.0:
			finish_round(dial.angle)   # time's up: wherever the valve is, counts
	elif wait_left > 0.0:
		wait_left -= delta
		if wait_left <= 0.0:
			if round_number < int(settings["rounds"]):
				start_round()
			else:
				end_turn()


# The player let go of the handle (or time ran out).
func finish_round(angle: float) -> void:
	if not in_round:
		return
	in_round = false
	dial.input_enabled = false
	var turned: int = int(round(angle))
	var off: int = absi(turned - target)
	var points: int = maxi(0, 100 - roundi(off * float(settings["points_lost_per_degree"])))
	points_total += points
	Sfx.play("good" if points >= int(Data.minigames["voice"]["good_at"]) else "bad")
	result_label.text = words["round_result"].format({"turned": turned, "off": off, "points": points})
	wait_left = settings["result_seconds"]


func end_turn() -> void:
	game_box.visible = false
	frame.finish_turn(roundi(points_total / float(settings["rounds"])))
