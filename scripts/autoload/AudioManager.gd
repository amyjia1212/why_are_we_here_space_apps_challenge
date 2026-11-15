# AudioManager.gd
# One place for every sound in the game (UPGRADE_PLAN_V2 steps 9, 25, 26).
# It is an autoload, so any script can call it:
#     AudioManager.play_sfx("good")          a sound effect
#     AudioManager.play_music("tension")     change the music (1 second crossfade)
#     AudioManager.talk("general", text)     beep-talk while a line types out
#     AudioManager.set_volume("Music", 0.5)  a volume slider (0 to 1)
#     AudioManager.toggle_mute()             the M key
#
# Three volume "buses" (like channels on a mixing desk): Music, SFX, Voice.
# All settings are in data/audio.json. Nothing is downloaded: the music is
# made in code, a little every frame, so the browser never freezes.
extends Node

const SETTINGS_PATH := "user://settings.json"
const BUS_NAMES := ["Music", "SFX", "Voice"]

var settings: Dictionary           # data/audio.json
var volumes: Dictionary = {}       # bus name -> 0..1
var muted: bool = false

# Music: two players, so one can fade out while the other fades in.
var music_players: Array = []
var active_player: int = 0
var current_state: String = ""     # the state we want to hear, for example "calm"
var playing_state: String = ""     # the state that is actually playing
var music_cache: Dictionary = {}   # state key -> finished AudioStreamWAV
var job: Dictionary = {}           # the track being made right now (see start_job)

# Beep-talk.
var voice_player: AudioStreamPlayer
var voice_streams: Dictionary = {} # speaker -> AudioStreamWAV blip
var talk_left: int = 0             # beeps still to play
var talk_gap: float = 0.0          # seconds between beeps
var talk_clock: float = 0.0
var talk_speaker: String = ""

var last_scene: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep playing in the pause menu
	settings = Data.audio
	make_buses()
	load_settings()
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = "Music"
		player.volume_db = -80.0
		add_child(player)
		music_players.append(player)
	voice_player = AudioStreamPlayer.new()
	voice_player.bus = "Voice"
	add_child(voice_player)


# --- Buses and volume ----------------------------------------------------------

func make_buses() -> void:
	for bus_name in BUS_NAMES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")


func set_volume(bus_name: String, value: float) -> void:
	volumes[bus_name] = clampf(value, 0.0, 1.0)
	apply_volumes()
	save_settings()


func get_volume(bus_name: String) -> float:
	return volumes.get(bus_name, 1.0)


func toggle_mute() -> void:
	muted = not muted
	apply_volumes()
	save_settings()


func apply_volumes() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)
	for bus_name in BUS_NAMES:
		var index: int = AudioServer.get_bus_index(bus_name)
		var value: float = volumes.get(bus_name, 1.0)
		AudioServer.set_bus_mute(index, value <= 0.001)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.001)))


# The volumes are saved on this computer, so they stay the same next time.
# (In a private browser window saving can fail; then the defaults are used.)
func load_settings() -> void:
	volumes = settings["buses"].duplicate()
	if FileAccess.file_exists(SETTINGS_PATH):
		var saved = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if saved is Dictionary:
			for bus_name in BUS_NAMES:
				if saved.get("volumes", {}).has(bus_name):
					volumes[bus_name] = float(saved["volumes"][bus_name])
			muted = bool(saved.get("muted", false))
	apply_volumes()


func save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"volumes": volumes, "muted": muted}))


# --- Sound effects ---------------------------------------------------------------

# A real file named in audio.json wins; otherwise the code-made sound.
func play_sfx(sound_name: String) -> void:
	var entry: Dictionary = settings["sfx"].get(sound_name, {})
	var path: String = entry.get("file", "")
	if path != "" and ResourceLoader.exists(path):
		var player := AudioStreamPlayer.new()
		player.stream = load(path)
		player.bus = "SFX"
		add_child(player)
		player.finished.connect(player.queue_free)
		player.play()
		return
	Sfx.play(sound_name)


# --- Music -----------------------------------------------------------------------

# Change the music. The same state again does nothing.
func play_music(state: String) -> void:
	if state == "planet":
		state = GameState.get_destination_key()
	if not settings["music"]["states"].has(state):
		return
	current_state = state
	var key: String = music_key(state)
	if music_cache.has(key):
		crossfade_to(key)
	elif job.get("key", "") != key:
		start_job(state, key)


# Stop the music (fade out).
func stop_music() -> void:
	current_state = ""
	playing_state = ""
	var old: AudioStreamPlayer = music_players[active_player]
	var fade := create_tween()
	fade.tween_property(old, "volume_db", -80.0, settings["music"]["crossfade_seconds"])


# The tension track depends on the difficulty, so it gets its own key.
func music_key(state: String) -> String:
	if state == "tension":
		return state + "_" + GameState.level
	return state


func crossfade_to(key: String) -> void:
	if playing_state == key:
		return
	playing_state = key
	var seconds: float = settings["music"]["crossfade_seconds"]
	var old: AudioStreamPlayer = music_players[active_player]
	active_player = 1 - active_player
	var new: AudioStreamPlayer = music_players[active_player]
	new.stream = music_cache[key]
	new.volume_db = -40.0
	new.play()
	var fade := create_tween().set_parallel(true)
	fade.tween_property(new, "volume_db", float(settings["music"]["volume_db"]), seconds)
	fade.tween_property(old, "volume_db", -80.0, seconds)
	fade.chain().tween_callback(old.stop)


# Begin making one music loop. _process adds a chunk every frame.
func start_job(state: String, key: String) -> void:
	var recipe: Dictionary = settings["music"]["states"][state].duplicate(true)
	var bpm: float = recipe["bpm"]
	var drums: float = recipe["drums"]
	if state == "tension":
		var difficulty: Dictionary = settings["music"]["difficulty"].get(GameState.level, {})
		bpm *= difficulty.get("speed", 1.0)
		drums += difficulty.get("extra_drums", 0.0)
	var rate: int = settings["music"]["mix_rate"]
	var beat_seconds: float = 60.0 / bpm
	var beats: int = recipe["progression"].size() * int(recipe["beats_per_chord"])
	var total: int = int(beats * beat_seconds * rate)
	var data := PackedByteArray()
	data.resize(total * 2)
	job = {
		"key": key, "recipe": recipe, "rate": rate, "beat": beat_seconds,
		"drums": drums, "total": total, "done": 0, "data": data,
		"phases": [0.0, 0.0, 0.0, 0.0, 0.0], "rng": RandomNumberGenerator.new(),
	}
	job["rng"].seed = 7


func _process(delta: float) -> void:
	if not job.is_empty():
		make_chunk()
	update_talk(delta)
	# Each screen starts its own music (audio.json "scenes").
	var scene := get_tree().current_scene
	if scene != null:
		var scene_id: String = scene.scene_file_path.get_file().get_basename()
		if scene_id != last_scene:
			last_scene = scene_id
			var wanted: String = settings["music"]["scenes"].get(scene_id, "")
			# The start menu waits for the first click (browsers block sound until then).
			if wanted != "" and scene_id != "start_menu":
				play_music(wanted)


# Makes the next piece of the music loop. Layers: a soft pad (the chord),
# an arpeggio (chord notes one after another), a bass note and simple drums.
func make_chunk() -> void:
	var recipe: Dictionary = job["recipe"]
	var rate: float = job["rate"]
	var beat: float = job["beat"]
	var data: PackedByteArray = job["data"]
	var phases: Array = job["phases"]
	var rng: RandomNumberGenerator = job["rng"]
	var root: float = recipe["root_hz"]
	var chords: Array = recipe["progression"]
	var per_chord: float = float(recipe["beats_per_chord"])
	var pattern: Array = recipe["arp_pattern"]
	var octave: float = pow(2.0, float(recipe["arp_octave"]))
	var triangle: bool = recipe["wave"] == "triangle"
	var pad_vol: float = recipe["pad"]
	var arp_vol: float = recipe["arp"]
	var bass_vol: float = recipe["bass"]
	var drum_vol: float = job["drums"]
	var start: int = job["done"]
	var stop: int = mini(start + int(settings["music"]["chunk_samples"]), job["total"])
	for i in range(start, stop):
		var t: float = i / rate
		var beat_pos: float = t / beat
		var chord: Array = chords[int(beat_pos / per_chord) % chords.size()]
		var sample: float = 0.0
		# Pad: the three chord notes together.
		for n in 3:
			var hz: float = root * pow(2.0, float(chord[n]) / 12.0)
			phases[n] = fmod(phases[n] + hz / rate, 1.0)
			sample += wave(phases[n], triangle) * pad_vol / 3.0
		# Arpeggio: one chord note per eighth note, with a short fade.
		var eighth: float = beat_pos * 2.0
		var step: int = int(eighth) % pattern.size()
		var note_index: int = int(pattern[step]) % chord.size()
		var arp_hz: float = root * octave * pow(2.0, float(chord[note_index]) / 12.0)
		phases[3] = fmod(phases[3] + arp_hz / rate, 1.0)
		var arp_env: float = exp(-(eighth - floor(eighth)) * 4.0)
		sample += wave(phases[3], triangle) * arp_vol * arp_env
		# Bass: the chord's first note, two octaves down, on every beat.
		var bass_hz: float = root * 0.5 * pow(2.0, float(chord[0]) / 12.0)
		phases[4] = fmod(phases[4] + bass_hz / rate, 1.0)
		var bass_env: float = exp(-(beat_pos - floor(beat_pos)) * 2.5)
		sample += sin(phases[4] * TAU) * bass_vol * bass_env
		# Drums: a kick on every beat and a hiss on the off-beats.
		if drum_vol > 0.0:
			var in_beat: float = (beat_pos - floor(beat_pos)) * beat
			if in_beat < 0.12:
				sample += sin(TAU * (50.0 + 70.0 * (1.0 - in_beat / 0.12)) * in_beat) * drum_vol * (1.0 - in_beat / 0.12)
			var in_half: float = (eighth - floor(eighth)) * beat * 0.5
			if int(eighth) % 2 == 1 and in_half < 0.03:
				sample += rng.randf_range(-1.0, 1.0) * drum_vol * 0.35 * (1.0 - in_half / 0.03)
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 30000.0))
	job["done"] = stop
	if stop >= job["total"]:
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = int(rate)
		stream.stereo = false
		stream.data = data
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = job["total"]
		var key: String = job["key"]
		music_cache[key] = stream
		job = {}
		# Play it only if it is still the state we want.
		if current_state != "" and music_key(current_state) == key:
			crossfade_to(key)
		elif current_state != "" and not music_cache.has(music_key(current_state)):
			start_job(current_state, music_key(current_state))


func wave(phase: float, triangle: bool) -> float:
	if triangle:
		return 4.0 * absf(phase - 0.5) - 1.0
	return sin(phase * TAU)


# --- Beep-talk ---------------------------------------------------------------------

# speaker = "scientist", "janitor", "student", "general" or "crew".
# letters_per_second = how fast the text types out.
func talk(speaker: String, text: String, letters_per_second: float = 60.0) -> void:
	var voices: Dictionary = settings["voices"]
	if not voices["speakers"].has(speaker):
		speaker = "crew"
	if not voice_streams.has(speaker):
		voice_streams[speaker] = make_blip(float(voices["speakers"][speaker]["pitch_hz"]), float(voices["beep_seconds"]))
	talk_speaker = speaker
	var letters: int = text.replace(" ", "").length()
	var per_beep: int = int(voices["letters_per_beep"])
	talk_left = int(ceil(float(letters) / per_beep))
	talk_gap = per_beep / maxf(letters_per_second, 1.0)
	talk_clock = 0.0


func stop_talk() -> void:
	talk_left = 0


func update_talk(delta: float) -> void:
	if talk_left <= 0:
		return
	talk_clock -= delta
	if talk_clock > 0.0:
		return
	talk_clock = talk_gap
	talk_left -= 1
	var wobble: float = settings["voices"]["pitch_wobble"]
	voice_player.stream = voice_streams[talk_speaker]
	voice_player.pitch_scale = randf_range(1.0 - wobble, 1.0 + wobble)
	voice_player.volume_db = settings["voices"]["volume_db"]
	voice_player.play()


func make_blip(hz: float, seconds: float) -> AudioStreamWAV:
	var rate: int = 22050
	var count: int = int(seconds * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t: float = float(i) / rate
		var envelope: float = minf(1.0, minf(float(i) / 60.0, float(count - i) / 200.0))
		var square: float = 1.0 if fmod(t * hz, 1.0) < 0.5 else -1.0
		data.encode_s16(i * 2, int(square * envelope * 0.35 * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream
