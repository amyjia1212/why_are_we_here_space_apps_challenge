# minigame_assembly.gd
# Build job 1: Assembly (UPGRADE_PLAN_V2 step 18). The name of a rocket part
# appears (FIN, TANK, SOLAR PANEL...). Type its letters in order (spaces are
# skipped). When the word is done, that part snaps onto the rocket in the 3D
# workshop behind the game. A wrong key freezes you for a moment.
# Harder characters get longer words and less time (Scientist short words,
# Janitor medium, Student long).
# Score = words finished / target_parts x 100. The team average becomes
# BUILD QUALITY (PLAN.md section 7).
# Numbers and word lists: data/minigames.json "assembly". Words: story.json "minigames".
extends Control

@onready var frame: Control = $Frame

var settings: Dictionary   # minigames.json "assembly"
var level: Dictionary      # minigames.json "assembly" > "levels" > easy / medium / hard
var words: Dictionary      # story.json "minigames" > "assembly"
var rng := RandomNumberGenerator.new()

var prompt_label: Label
var word_label: RichTextLabel
var oops_label: Label
var job_label: Label
var game_box: VBoxContainer

var playing: bool = false
var time_left: float = 0.0
var freeze_left: float = 0.0
var placed: int = 0
var word: String = ""       # the part name, for example "SOLAR PANEL"
var typed: int = 0          # how many characters of word are done (spaces count as done)
var last_word: String = ""


func _ready() -> void:
	settings = Data.minigames["assembly"]
	var level_key: String = GameState.level if settings["levels"].has(GameState.level) else "medium"
	level = settings["levels"][level_key]
	words = Data.story["minigames"]["assembly"]
	rng.randomize()
	make_play_area()
	frame.turn_started.connect(_on_turn_started)
	frame.setup("assembly", {"freeze": GameState.fmt(settings["wrong_key_freeze_seconds"])})


# The middle of the screen: "Bolt on the:", the word (done letters green),
# and a "Wrong key!" line.
func make_play_area() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.play_area.add_child(center)

	game_box = VBoxContainer.new()
	game_box.add_theme_constant_override("separation", 8)
	game_box.visible = false
	center.add_child(game_box)

	prompt_label = new_label(&"HeadingText")
	prompt_label.text = words["bolt_on"]
	word_label = RichTextLabel.new()
	word_label.bbcode_enabled = true
	word_label.fit_content = true
	word_label.scroll_active = false
	word_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	word_label.custom_minimum_size = Vector2(900, 0)
	word_label.theme_type_variation = &"TypingRich"
	game_box.add_child(word_label)
	oops_label = new_label(&"AccentText")
	# Part jobs (extras): after a word, three words flash, for example "ANTENNA: talks to Earth".
	job_label = new_label(&"HeadingText")
	job_label.add_theme_color_override("font_color", get_theme_color("good_color", &"Minigame"))


func new_label(style: StringName) -> Label:
	var label := Label.new()
	label.theme_type_variation = style
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_box.add_child(label)
	return label


func _on_turn_started(_player_index: int) -> void:
	placed = 0
	time_left = level["duration_seconds"]
	freeze_left = 0.0
	oops_label.text = ""
	job_label.text = ""
	frame.get_workshop().clear_snapped_parts()
	next_word()
	game_box.visible = true
	playing = true


# A new random part name (never the same one twice in a row).
func next_word() -> void:
	var list: Array = level["words"]
	var pick: String = last_word
	while pick == last_word and list.size() > 1:
		pick = list[rng.randi_range(0, list.size() - 1)]
	word = pick
	last_word = pick
	typed = 0
	skip_spaces()
	show_word()
	frame.set_status(words["placed"].format({"count": placed, "target": int(level["target_parts"])}))


func skip_spaces() -> void:
	while typed < word.length() and word[typed] == " ":
		typed += 1


# Done letters are green, the next letter is orange and underlined, the rest are dim.
func show_word() -> void:
	var good: String = get_theme_color("good_color", &"Minigame").to_html(false)
	var next: String = get_theme_color("target_color", &"Minigame").to_html(false)
	var dim: String = get_theme_color("dim_text_color", &"Minigame").to_html(false)
	var text: String = "[center]"
	for i in word.length():
		var letter: String = word[i]
		if i < typed:
			text += "[color=#%s]%s[/color]" % [good, letter]
		elif i == typed:
			text += "[color=#%s][u]%s[/u][/color]" % [next, letter]
		else:
			text += "[color=#%s]%s[/color]" % [dim, letter]
	word_label.text = text + "[/center]"


func _process(delta: float) -> void:
	if not playing:
		return
	time_left -= delta
	frame.set_time_left(time_left)
	if freeze_left > 0.0:
		freeze_left -= delta
		if freeze_left <= 0.0:
			oops_label.text = ""
	if time_left <= 0.0:
		end_turn()


func _unhandled_input(event: InputEvent) -> void:
	if not playing or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode < KEY_A or key_event.keycode > KEY_Z:
		return   # only letters count
	get_viewport().set_input_as_handled()
	if freeze_left > 0.0:
		return   # frozen after a wrong key
	if char(key_event.keycode) == word[typed]:
		typed += 1
		skip_spaces()
		AudioManager.play_sfx("type")
		if typed >= word.length():
			finish_word()
		else:
			show_word()
	else:
		freeze_left = settings["wrong_key_freeze_seconds"]
		oops_label.text = words["oops"]
		AudioManager.play_sfx("bad")


# The word is done: the part snaps onto the workshop rocket.
func finish_word() -> void:
	placed += 1
	AudioManager.play_sfx("snap")
	var shape: String = settings["part_shapes"].get(word, "box")
	frame.get_workshop().snap_part(shape, placed, settings["part_color"])
	var job: String = Data.story["extras"]["part_jobs"].get(word, "")
	if job != "":
		job_label.text = word + ": " + job
		job_label.modulate.a = 1.0
		var fade := job_label.create_tween()
		fade.tween_interval(0.9)
		fade.tween_property(job_label, "modulate:a", 0.0, 0.5)
	next_word()


func end_turn() -> void:
	playing = false
	game_box.visible = false
	var score: int = roundi(placed * 100.0 / float(level["target_parts"]))
	frame.finish_turn(score)
