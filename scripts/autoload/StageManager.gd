# StageManager.gd
# Moves the player from one screen to the next. It is an autoload,
# so any script can call it by name, for example:  StageManager.go_next()
#
# The screen order is NOT in this file. It lives in data/game_data.json
# under "stages". To change the order, change that list.
extends Node


# The id of the screen we are on now, for example "build".
# It is the scene's file name without ".tscn".
func get_current() -> String:
	return get_tree().current_scene.scene_file_path.get_file().get_basename()


# Go to the next screen in the list.
func go_next() -> void:
	var order: Array = Data.game_data["stages"]["order"]
	var next_index: int = order.find(get_current()) + 1
	if next_index <= 0 or next_index >= order.size():
		push_error("StageManager: there is no screen after '" + get_current() + "'")
		return
	go_to(order[next_index])


# Go to one named screen, for example go_to("build").
# Used by the Back button and by Try again.
func go_to(stage_id: String) -> void:
	var stages: Dictionary = Data.game_data["stages"]
	if not stages["order"].has(stage_id):
		push_error("StageManager: '" + stage_id + "' is not in the stages list")
		return
	# Give the mouse back on every screen change. A 3D room locks it for looking
	# around; the next screen may need it for buttons. Screens with a walking
	# player lock it again by themselves (player.gd).
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(stages["scene_folder"] + stage_id + ".tscn")
	fade_from_dark()


# Screens change with a short fade (UI_POLISH_PLAN_V4 Step 4): a navy veil
# covers the screen at the moment of the change and clears in 0.25 s. The
# change itself is not delayed, so nothing waits on the fade.
var veil: ColorRect
var veil_tween: Tween

func fade_from_dark() -> void:
	if veil == null:
		var layer := CanvasLayer.new()
		layer.layer = 100
		add_child(layer)
		veil = ColorRect.new()
		veil.color = Color(0.04, 0.086, 0.2)   # the theme's background navy
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		veil.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(veil)
	if veil_tween:
		veil_tween.kill()
	veil.modulate.a = 1.0
	veil.visible = true
	veil_tween = veil.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	veil_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	veil_tween.tween_interval(0.05)
	veil_tween.tween_property(veil, "modulate:a", 0.0, 0.25)
	veil_tween.tween_callback(func(): veil.visible = false)
