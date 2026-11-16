# learn_card.gd
# A paused full-screen card that teaches one thing (UPGRADE_PLAN_V6 C2):
# a title, a few short lines, the NASA source, and one button.
#     const LEARN_CARD = preload("res://scripts/learn_card.gd")
#     LEARN_CARD.open(self, {"title": "...", "lines": [...], "source": "..."}, "Got it", on_close)
# The game pauses while it is open; the button (or Enter) closes it and calls on_close.
extends RefCounted


static func open(parent: Node, card: Dictionary, button_text: String, on_close: Callable = Callable()) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(layer)
	var dim := Panel.new()
	dim.theme_type_variation = &"DimBackground"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"NavyPanel"
	panel.custom_minimum_size.x = 640
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	if card.has("kicker"):
		var kicker := Label.new()
		kicker.theme_type_variation = &"AccentText"
		kicker.text = card["kicker"]
		column.add_child(kicker)
	var title := Label.new()
	title.theme_type_variation = &"HeadingText"
	title.text = card.get("title", "")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	for line in card.get("lines", []):
		var label := Label.new()
		label.theme_type_variation = &"BodyText"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = line
		column.add_child(label)
	if str(card.get("source", "")) != "":
		var source := Label.new()
		source.theme_type_variation = &"TinyText"
		source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		source.text = card["source"]
		column.add_child(source)
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(320, 56)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(button)
	var tree: SceneTree = parent.get_tree()
	var was_paused: bool = tree.paused
	var mouse_before: Input.MouseMode = Input.mouse_mode
	tree.paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	button.pressed.connect(func():
		layer.queue_free()
		tree.paused = was_paused
		Input.mouse_mode = mouse_before
		if on_close.is_valid():
			on_close.call())
	button.call_deferred("grab_focus")
	AudioManager.play_sfx("preview")
	return layer
