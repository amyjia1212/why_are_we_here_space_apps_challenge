# inner_voice_bar.gd
# The bar at the bottom of the screen where the inner voice talks.
# Any screen can use it: add the inner_voice_bar scene, then call
#     %InnerVoiceBar.say("some text")
# While a line types out, the speaker "talks" in beeps at their own pitch
# (AudioManager.talk, UPGRADE_PLAN_V2 step 26), and their portrait shows on
# the left (step 10).
extends PanelContainer

# How many letters appear per second (the "typing" effect).
const LETTERS_PER_SECOND := 60.0
const TYPEWRITER = preload("res://scripts/typewriter_label.gd")

@onready var speaker_label: Label = %Speaker
@onready var line_label: Label = %Line
@onready var next_button: Button = %NextButton

var typing: Tween   # the running typing animation, if any
var speaker_key: String = ""   # "" = the player's own character (the inner voice)
var portrait: TextureRect


func _ready() -> void:
	speaker_label.text = Data.voice["speaker_name"]
	line_label.text = ""
	next_button.visible = false
	next_button.text = Data.story["setup_next_button"]
	next_button.pressed.connect(_on_next_pressed)
	# The portrait sits left of the words.
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(88, 88)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row: HBoxContainer = $Margin/Row
	row.add_child(portrait)
	row.move_child(portrait, 0)
	update_portrait()
	Portraits.portrait_ready.connect(func(_id): update_portrait())
	# ROOM_LAYOUT_PLAN_V5 Step 4: hidden while it has nothing to say; it fades in
	# when a line starts (say()).
	visible = false
	# 2026-11-15 team note: the bar must not block anything.
	# 1. Clicks go through it (only the Next button catches clicks).
	for node in [self, $Margin, $Margin/Row, $Margin/Row/Column, speaker_label, line_label, portrait]:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 2. It is narrower and centered, so the bottom corners stay free.
	var hud: Dictionary = Data.game_data["hud"]
	var width: float = float(hud.get("voice_bar_max_width", 0))
	if width > 0.0:
		anchor_left = 0.5
		anchor_right = 0.5
		offset_left = -width / 2.0
		offset_right = width / 2.0
	# 3. It fades away after the line has been read (see _process).
	hold_seconds = float(hud.get("voice_bar_hold_seconds", 0))
	seconds_per_letter = float(hud.get("voice_bar_seconds_per_letter", 0))


var hold_seconds: float = 0.0          # 0 = never fade away on its own
var seconds_per_letter: float = 0.0
var show_left: float = 0.0             # seconds until the bar fades away
var fading: bool = false


var showing_goal: bool = false        # the bar shows "what to do now" (UPGRADE_PLAN_V6 A5)


func _process(delta: float) -> void:
	if showing_goal:
		# Keep the task line up to date; it changes when an alarm starts or a job is done.
		var goal: String = current_goal()
		if goal == "":
			showing_goal = false
			visible = false
		elif goal != line_label.text:
			line_label.text = goal
		return
	if not visible or hold_seconds <= 0.0 or next_button.visible or get_meta("hold", false):
		return   # a Next button waits for the player: the bar stays
	show_left -= delta
	if show_left <= 0.0 and not fading and current_goal() != "":
		# On the ship and the planet the bar does not just vanish: after the line
		# was read it shows the task at hand, quietly (no beep-talk).
		showing_goal = true
		speaker_label.text = Data.voice["speaker_name"]
		speaker_key = ""
		update_portrait()
		line_label.text = current_goal()
		line_label.visible_ratio = 1.0
		return
	if show_left <= 0.0 and not fading:
		fading = true
		fade_tween = create_tween()
		fade_tween.tween_property(self, "modulate:a", 0.0, 0.4)
		fade_tween.tween_callback(func():
			visible = false
			modulate.a = 1.0
			fading = false)


var fade_tween: Tween


# The screen's "what to do now" line ("" on screens without one).
func current_goal() -> String:
	var scene := get_tree().current_scene
	if scene == null or not scene.has_method("get_goal_text"):
		return ""
	var scene_id: String = scene.scene_file_path.get_file().get_basename()
	if not Data.game_data["hud"].get("voice_goal_scenes", []).has(scene_id):
		return ""
	return str(scene.get_goal_text())


# Someone else talks in the bar (for example the General on the report).
# key = their beep voice and portrait ("general"); "" = the inner voice.
func set_speaker(speaker_name: String, key: String = "general") -> void:
	speaker_label.text = speaker_name
	speaker_key = key
	update_portrait()


func update_portrait() -> void:
	var key: String = speaker_key if speaker_key != "" else GameState.character_id
	var texture: Texture2D = Portraits.get_texture(key)
	portrait.texture = texture
	portrait.visible = texture != null


# Shows a new line, typed out letter by letter.
func say(text: String) -> void:
	if text == "":
		visible = false
		return
	showing_goal = false
	# Time to type the line, then time to read it, then it fades away.
	show_left = text.length() / LETTERS_PER_SECOND + hold_seconds + text.length() * seconds_per_letter
	if fading:
		fading = false
		if fade_tween:
			fade_tween.kill()
		modulate.a = 1.0
	if not visible:
		visible = true
		preload("res://scripts/ui_kit.gd").fade_in(self, Vector2.ZERO)
	line_label.text = text
	line_label.visible_ratio = 0.0   # 0 = no letters showing, 1 = all showing

	# Stop the old typing if a new line arrives before it finished.
	if typing:
		typing.kill()

	# The shared typewriter (typewriter_label.gd, UPGRADE_PLAN_V3 B3): the
	# letters appear one by one while the speaker beep-talks.
	typing = TYPEWRITER.type_into(line_label, text, speaker_key, LETTERS_PER_SECOND)


# Used by the setup questions. The voice reacts, then a Next button shows.
# The player reads at their own pace and clicks Next to go on.
func say_then_next(text: String) -> void:
	say(text)
	next_button.visible = true
	next_button.disabled = false
	next_button.grab_focus()


# Lock the button at once, so a double click cannot skip two screens.
func _on_next_pressed() -> void:
	next_button.disabled = true
	StageManager.go_next()
