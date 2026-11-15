# Controls.gd
# Puts every key from data/game_data.json ("keybinds") into Godot's Input Map
# when the game starts (UPGRADE_PLAN_V2 step 8). Scripts then ask about
# actions ("interact", "tablet"), never about keys, so a key can change in
# the data file without touching any script.
#
# It also runs the keys that work on every screen:
#   H = show the controls,  M = mute,  F = full screen.
# (Esc and Tab are handled by the Hud.)
extends Node

# True while a typing minigame needs letter keys, so H, M and F type letters
# instead of opening the controls or muting.
var typing_mode: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var actions: Dictionary = Data.game_data["keybinds"]["actions"]
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key_name in actions[action]:
			var keycode: Key = OS.find_keycode_from_string(key_name)
			if keycode == KEY_NONE:
				push_error("Controls: unknown key name '" + key_name + "' for " + action)
				continue
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)


func _unhandled_input(event: InputEvent) -> void:
	if typing_mode or not event is InputEventKey or event.echo:
		return
	if event.is_action_pressed("show_controls"):
		Hud.toggle_controls()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("mute"):
		AudioManager.toggle_mute()
		Hud.flash(Data.story["controls"]["muted" if AudioManager.muted else "unmuted"])
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("fullscreen"):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


# The key names for one action, for example "W / Up" (for hints).
func keys_for(action: String) -> String:
	return " / ".join(PackedStringArray(Data.game_data["keybinds"]["actions"].get(action, [])))
