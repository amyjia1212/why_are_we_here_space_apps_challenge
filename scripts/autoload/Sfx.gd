# Sfx.gd
# Little sound effects, made in code (no sound files, nothing downloaded).
# It is an autoload, so any script can play one by name:
#     Sfx.play("good")
# The sounds are recipes in data/game_data.json ("sounds"): a list of notes,
# each [pitch in Hz, seconds], and a wave shape:
#   "sine"   = a soft beep        "square" = a buzzy game beep
#   "noise"  = a hiss (clanks, rumbles)
# Every button in the game clicks by itself: Sfx watches for new buttons.
extends Node

const MIX_RATE := 22050          # samples per second (enough for beeps, small in the browser)
const PLAYER_COUNT := 6          # how many sounds can play at the same time

var streams: Dictionary = {}     # sound name -> AudioStreamWAV, made once at start
var players: Array = []
var next_player: int = 0


func _ready() -> void:
	var recipes: Dictionary = Data.game_data.get("sounds", {})
	for sound_name in recipes:
		if sound_name.begins_with("_") or not recipes[sound_name] is Dictionary:
			continue
		streams[sound_name] = make_stream(recipes[sound_name])
	process_mode = Node.PROCESS_MODE_ALWAYS   # buttons in the pause menu click too
	for i in PLAYER_COUNT:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"   # the SFX volume slider (AudioManager makes the bus)
		add_child(player)
		players.append(player)
	# Every Button that appears anywhere in the game gets a click and a hover sound.
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(play.bind("click")):
		node.pressed.connect(play.bind("click"))
		node.mouse_entered.connect(_on_button_hover.bind(node))


func _on_button_hover(button: BaseButton) -> void:
	if not button.disabled:
		play("hover")


# Play one sound by name, for example Sfx.play("bad"). An empty name plays
# nothing. A name with no recipe plays a simple beep, so nothing crashes.
func play(sound_name: String) -> void:
	if sound_name == "":
		return
	if not streams.has(sound_name):
		sound_name = "beep"
	if not streams.has(sound_name):
		return
	var player: AudioStreamPlayer = players[next_player]
	next_player = (next_player + 1) % players.size()
	player.stream = streams[sound_name]
	player.volume_db = Data.game_data["sounds"][sound_name].get("volume_db", 0.0)
	player.play()


# Turns one recipe into sound samples (16-bit numbers from -32768 to 32767).
func make_stream(recipe: Dictionary) -> AudioStreamWAV:
	var data := PackedByteArray()
	var wave: String = recipe.get("wave", "sine")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var phase: float = 0.0
	for note in recipe["notes"]:
		var start_hz: float = note[0]
		var seconds: float = note[1]
		var end_hz: float = note[2] if note.size() > 2 else start_hz   # a third number slides the pitch
		var count: int = int(seconds * MIX_RATE)
		for i in count:
			var t: float = float(i) / maxf(count - 1, 1)
			phase += lerpf(start_hz, end_hz, t) / MIX_RATE
			var sample: float
			match wave:
				"square":
					sample = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
				"noise":
					sample = rng.randf_range(-1.0, 1.0)
				_:
					sample = sin(phase * TAU)
			# Fade in and out a little so notes don't pop, and fade down over the note.
			var envelope: float = minf(1.0, minf(t * 20.0, (1.0 - t) * 8.0)) * (1.0 - t * 0.5)
			var value: int = int(clampf(sample * envelope * 0.5, -1.0, 1.0) * 32767.0)
			data.append(value & 0xFF)
			data.append((value >> 8) & 0xFF)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
