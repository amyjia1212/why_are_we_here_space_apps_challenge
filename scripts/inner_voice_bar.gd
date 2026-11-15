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
