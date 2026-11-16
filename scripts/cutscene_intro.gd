# cutscene_intro.gd
# The intro cutscene in the mission control war room (about 27.5 seconds).
# The AnimationPlayer node plays one animation called "intro" by itself
# (Autoplay). The animation moves the camera and the people, shows and
# hides the subtitles, shakes the camera and fades in and out.
# The people are character scenes (scenes/characters). The animation also
# calls talk() and point_at_camera() on them, and turns their heads.
#
# SHOT LIST (each shot is a hard cut; the times are in the animation):
#   Shot 0   0.0  fade in from black
#   Shot 1   0.0  high wide shot of the war room, slow push in
#   Shot 2   3.0  low angle on the chief mission designer, snap zoom on "I quit!"
#                 (the node is still called Person_Commander; only the name on
#                 screen changed)
#   Shot 3   5.0  door shot from the walkway, the door slides, he leaves
#   Shot 4   7.3  close up of the General, held still (silent pause)
#   Shot 5   8.1  low angle medium shot of the General: "Who will run it?"
#   Shot 6  12.0  three quick cuts: Staff 1 ducks, Staff 2 ducks, Staff 3 dives
#                 into the closet, then a wide beat of the empty consoles
#   Shot 7  14.6  over the General's shoulder: "I need somebody. Anybody!"
#   Shot 8  17.4  same shot held, pause, his head turns toward us
#   Shot 9  18.2  front close up, punch in and shake: "You. I want you."
#   Shot 10 21.0  front three shot: Assistant Scientist, Janitor, Student
#   Shot 11 25.5  fade to black, then the name screen
#
# This script does three small jobs:
#   1. show_subtitle() / hide_subtitle(): speaker name (amber) and line (white).
#   2. shake_camera(): a quick camera shake that the animation can call.
#   3. When the animation ends, or the player skips (Space, Enter or a click),
#      it goes to the next screen in the stage list.
# The words come from data/story.json ("cutscene_intro").
extends Node3D

var _shake_left := 0.0
var _shake_total := 0.0
var _shake_strength := 0.0

# True once we have started leaving, so a double press only skips once.
var _leaving := false

@onready var subtitle_box: VBoxContainer = $CanvasLayer/BarBottom/SubtitleBox
@onready var speaker: Label = $CanvasLayer/BarBottom/SubtitleBox/Speaker
@onready var subtitle: Label = $CanvasLayer/BarBottom/SubtitleBox/Subtitle
@onready var skip_hint: Label = $CanvasLayer/BarTop/SkipHint
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	# When the animation is over, move on to the next screen.
	animation_player.animation_finished.connect(_on_animation_finished)
	subtitle_box.visible = false
	skip_hint.text = Data.story.get("cutscene_intro", {}).get("skip_hint", "")


# Space or Enter (Godot's built-in "ui_accept" action) or a left mouse click
# skips the cutscene.
func _unhandled_input(event: InputEvent) -> void:
	var clicked: bool = event is InputEventMouseButton \
			and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event.is_action_pressed("ui_accept") or clicked:
		get_viewport().set_input_as_handled()
		_leave()


# The animation calls this (a "method track") to show one subtitle line.
func show_subtitle(key: String) -> void:
	var lines: Dictionary = Data.story.get("cutscene_intro", {}).get("subtitles", {})
	var line: Dictionary = lines.get(key, {})
	speaker.text = line.get("speaker", "")
	subtitle.text = line.get("text", "MISSING: " + key)
	subtitle_box.visible = true


func hide_subtitle() -> void:
	subtitle_box.visible = false


# The animation calls this to shake the camera for "seconds".
# "strength" is how far the picture jumps (0.02 is small).
func shake_camera(seconds: float, strength: float) -> void:
	_shake_left = seconds
	_shake_total = seconds
	_shake_strength = strength


# The shake moves the camera's h_offset and v_offset, so it never fights the
# animation tracks that move the camera's position and rotation.
func _process(delta: float) -> void:
	check_plaques()
	if _shake_left > 0.0:
		_shake_left -= delta
		var fade := clampf(_shake_left / _shake_total, 0.0, 1.0)
		camera.h_offset = randf_range(-1.0, 1.0) * _shake_strength * fade
		camera.v_offset = randf_range(-1.0, 1.0) * _shake_strength * fade
	elif camera.h_offset != 0.0 or camera.v_offset != 0.0:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


# ---------- the name plaques (UPGRADE_PLAN_V3 C4) ----------
# Just before "You. I want you." the animation pauses on a wall of name
# plaques (text only) of real astronauts, and the General says one true,
# sourced line about what real crews have done (nasa_resources.json
# "intro_plaques"; the facts are in "astronaut_facts"). The real people
# never speak. Then the animation goes on.
var _plaques_done := false
var _plaque_layer: CanvasLayer


func check_plaques() -> void:
	if _plaques_done or _leaving or not animation_player.is_playing():
		return
	var info: Dictionary = Data.nasa.get("intro_plaques", {})
	if info.is_empty() or not info.get("enabled", true):
		_plaques_done = true   # turned off (2026-11-15): the astronauts meet you on the ship instead
		return
	if animation_player.current_animation_position < float(info["at_seconds"]):
		return
	_plaques_done = true
	show_plaques(info)


func show_plaques(info: Dictionary) -> void:
	animation_player.pause()
	_plaque_layer = CanvasLayer.new()
	_plaque_layer.layer = 0   # UNDER the cutscene's bars (layer 1), so the subtitle line stays visible
	add_child(_plaque_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.07, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plaque_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -140   # above the subtitle bar
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plaque_layer.add_child(center)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 16)
	center.add_child(grid)
	for plaque_name in info["names"]:
		var plaque := PanelContainer.new()
		plaque.theme_type_variation = &"NavyPanel"
		plaque.custom_minimum_size = Vector2(440, 0)
		grid.add_child(plaque)
		var label := Label.new()
		label.text = plaque_name
		label.theme_type_variation = &"AccentText"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plaque.add_child(label)
	speaker.text = info.get("speaker", "General")
	subtitle.text = info["line"]
	subtitle_box.visible = true
	await get_tree().create_timer(float(info["show_seconds"])).timeout
	if not is_inside_tree() or _leaving:
		return
	_plaque_layer.queue_free()
	subtitle_box.visible = false
	animation_player.play()


func _on_animation_finished(_animation_name: StringName) -> void:
	_leave()


# Go to the next screen. StageManager is the same way every other screen
# moves on (the screen list is in data/game_data.json, "stages").
func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	animation_player.stop()
	StageManager.go_next()
