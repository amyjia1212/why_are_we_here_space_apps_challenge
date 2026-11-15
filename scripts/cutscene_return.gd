# cutscene_return.gd
# The return-to-Earth slot (PLAN.md section 11). For now it shows one line of
# text, then the two checklist lines for Depart and Home (UPGRADE_PLAN_V3 A3
# DEFAULT: decided by a simple rule in game_data.json report > return_rules),
# then moves on to the mission report after return_seconds.
# Space, Enter or a click skips it. The team makes a real cutscene later
# and puts it here.
extends Control

@onready var line_label: Label = %Line
@onready var skip_hint: Label = %SkipHint

var time_left: float = 0.0
var leaving: bool = false


func _ready() -> void:
	var words: Dictionary = Data.story["cutscene_return"]
	var lines: Array = GameState.decide_return()
	line_label.text = words["lines"].get(GameState.get_destination_key(), "") + "\n\n" + "\n".join(PackedStringArray(lines))
	line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skip_hint.text = words["skip_hint"]
	time_left = Data.game_data["report"]["return_seconds"]


func _process(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		leave()


func _unhandled_input(event: InputEvent) -> void:
	var key_skip: bool = event is InputEventKey and event.pressed and not event.echo \
		and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER)
	var click_skip: bool = event is InputEventMouseButton and event.pressed
	if key_skip or click_skip:
		leave()


func leave() -> void:
	if leaving:
		return   # only once, even if a key and the timer come together
	leaving = true
	StageManager.go_next()
