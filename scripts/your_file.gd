# your_file.gd
# "Your File" (UPGRADE_PLAN_V2 step 11): a clean page styled like a paper
# personnel file, shown after the character is chosen. It shows the portrait,
# the name, who you are, the difficulty and one line on the job. (The six
# resources are taught in Mission School now.) Words: story.json "your_file".
extends Control

var words: Dictionary


func _ready() -> void:
	if GameState.character_id == "":
		GameState.character_id = Data.game_data["setup"]["default_character"]
	words = Data.story["your_file"]
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	build_page()


func build_page() -> void:
	var background := Panel.new()
	background.theme_type_variation = &"ScreenBackground"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var paper := PanelContainer.new()
	paper.theme_type_variation = &"PaperPanel"
	paper.custom_minimum_size = Vector2(1020, 0)
	center.add_child(paper)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	paper.add_child(column)

	add_label(column, words["folder_label"], &"PaperLabel")
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 32)
	column.add_child(top)

	# The portrait, like a photo clipped to the file.
	var photo := TextureRect.new()
	photo.custom_minimum_size = Vector2(190, 190)
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.texture = Portraits.get_texture(GameState.character_id)
	top.add_child(photo)
	Portraits.portrait_ready.connect(func(id):
		if id == GameState.character_id:
			photo.texture = Portraits.get_texture(id))

	var facts := VBoxContainer.new()
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(facts)
	var character_words: Dictionary = Data.story["characters"][GameState.character_id]
	add_fact(facts, words["name_label"], GameState.player_name if GameState.player_name != "" else character_words["name"])
	add_fact(facts, words["who_label"], character_words["name"] + ". " + character_words["description"])
	add_fact(facts, words["difficulty_label"], words["difficulty_words"].get(GameState.level, GameState.level))
	add_fact(facts, words["job_label"], words["job"])

	# (The six resources moved to Mission School, where the General teaches
	# them: UPGRADE_PLAN_V3 B4. The same thing is not explained twice.)

	var button := Button.new()
	button.text = words["next"]
	button.custom_minimum_size = Vector2(220, 52)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.pressed.connect(_on_next_pressed.bind(button))
	column.add_child(button)
	button.grab_focus()

	# The red HIRED stamp, a little crooked.
	var stamp := Label.new()
	stamp.text = words["stamp"]
	stamp.theme_type_variation = &"StampText"
	stamp.rotation_degrees = -14.0
	add_child(stamp)   # on top of the page, not inside it (a container would move it)
	stamp.scale = Vector2(2.2, 2.2)
	stamp.modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	stamp.position = paper.position + Vector2(paper.size.x - 300, 40)
	var tween := create_tween()
	tween.tween_interval(0.5)
	tween.tween_callback(AudioManager.play_sfx.bind("stamp"))
	tween.parallel().tween_property(stamp, "modulate:a", 1.0, 0.12)
	tween.parallel().tween_property(stamp, "scale", Vector2.ONE, 0.18)


func add_fact(parent: Control, label_text: String, value: String) -> void:
	add_label(parent, label_text, &"PaperLabel")
	add_label(parent, value, &"PaperText")


func add_label(parent: Control, text: String, style: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = style
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _on_next_pressed(button: Button) -> void:
	button.disabled = true
	StageManager.go_next()
