# build_done.gd
# "Build complete" (UPGRADE_PLAN_V6 B2): a short celebration between the last
# build job and the launch, so all that work feels like a moment.
#   1. The finished rocket rolls out to the pad at dawn.
#   2. The three build scores count up, one line each.
#   3. The staff jump and cheer, confetti falls. A great build gets a big
#      cheer, a weak one a kind one.
#   4. "Ready to launch": Enter or the button goes on. Enter skips after
#      skip_after_seconds.
# Numbers: game_data.json "build_done". Words: story.json "build_done".
extends Node3D

const UI = preload("res://scripts/ui_kit.gd")
const STAFF := ["res://scenes/characters/staff1.tscn", "res://scenes/characters/staff2.tscn", "res://scenes/characters/staff3.tscn"]
const JOBS := ["assembly", "hammer", "fuel"]

var settings: Dictionary
var words: Dictionary
var rocket: Node3D
var camera: Camera3D
var staff: Array = []
var confetti: CPUParticles3D
var time: float = 0.0
var cheering: bool = false
var cheer_height: float = 0.5
var score_box: VBoxContainer
var verdict_label: Label
var go_button: Button
var leaving: bool = false


func _ready() -> void:
	if GameState.character_id == "":
		GameState.character_id = Data.game_data["setup"]["default_character"]
	if GameState.mission_id == "":
		GameState.mission_id = Data.missions.keys()[0]
	GameState.fill_default_choices()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	settings = Data.game_data["build_done"]
	words = Data.story["build_done"]
	build_world()
	build_ui()
	play()


func build_world() -> void:
	LaunchPad.build(self, Data.game_data["start_menu"])
	rocket = load("res://scenes/rockets/rocket_" + GameState.get_launch_vehicle_id() + ".tscn").instantiate()
	rocket.position = Vector3(-float(settings["roll_from_meters"]), 1.0, 0)
	add_child(rocket)
	# The staff stand in front of the pad, facing the camera.
	for i in STAFF.size():
		var person: Node3D = load(STAFF[i]).instantiate()
		person.position = Vector3(2.0 + i * 2.2, 0.0, 15.0)   # right of the pad, close to the camera
		person.rotation.y = 0.0
		add_child(person)
		staff.append(person)
	camera = Camera3D.new()
	camera.fov = 55
	add_child(camera)
	camera.position = Vector3(-4, 5, 30)
	camera.look_at(Vector3(2, 6.5, 0))
	camera.current = true
	confetti = CPUParticles3D.new()
	confetti.emitting = false
	confetti.amount = int(settings["confetti_amount"])
	confetti.lifetime = 4.0
	confetti.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	confetti.emission_box_extents = Vector3(12, 0.5, 6)
	confetti.position = Vector3(0, 16, 8)
	confetti.direction = Vector3(0, -1, 0)
	confetti.spread = 25.0
	confetti.gravity = Vector3(0, -2.5, 0)
	confetti.initial_velocity_min = 0.5
	confetti.initial_velocity_max = 2.0
	confetti.angular_velocity_min = -360
	confetti.angular_velocity_max = 360
	var piece := QuadMesh.new()
	piece.size = Vector2(0.18, 0.12)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	piece.material = mat
	confetti.mesh = piece
	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
	colors.colors = PackedColorArray([Color("#ff9a3c"), Color("#4fc3f7"), Color("#ffe066"), Color("#7bed9f")])
	confetti.color_initial_ramp = colors
	add_child(confetti)


func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GlassPanel"
	# On the left, so the rocket in the middle stays in view.
	panel.offset_left = 32
	panel.offset_right = 32 + 460
	panel.offset_top = 56
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var title := Label.new()
	title.theme_type_variation = &"TitleText"
	title.text = words["title"]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var sub := Label.new()
	sub.theme_type_variation = &"BodyText"
	sub.text = words["subtitle"]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(sub)
	score_box = VBoxContainer.new()
	column.add_child(score_box)
	verdict_label = Label.new()
	verdict_label.theme_type_variation = &"HeadingText"
	verdict_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	verdict_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(verdict_label)
	go_button = Button.new()
	go_button.text = words["button"]
	go_button.custom_minimum_size = Vector2(320, 56)
	go_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go_button.visible = false
	go_button.pressed.connect(leave)
	column.add_child(go_button)


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func play() -> void:
	# 1. Roll out.
	AudioManager.play_sfx("rumble")
	var roll := create_tween()
	roll.tween_property(rocket, "position:x", 0.0, float(settings["roll_seconds"])).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await wait(float(settings["roll_seconds"]))
	if not is_inside_tree():
		return
	# 2. The scores count up.
	var total: float = 0.0
	for job in JOBS:
		var score: float = GameState.get_team_score(job)
		total += score
		var line := Label.new()
		line.theme_type_variation = &"BodyText"
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_box.add_child(line)
		var name_text: String = Data.story["minigames"][job]["result_name"]
		UI.count_to(line, 0.0, score, func(v: float) -> String: return words["score_line"].format({"name": name_text, "score": int(round(v))}))
		AudioManager.play_sfx("good")
		await wait(float(settings["line_seconds"]))
		if not is_inside_tree():
			return
	# 3. Cheer, sized to the build.
	var average: float = total / JOBS.size()
	var kind: String = "great" if average >= float(settings["great_at"]) else ("weak" if average < float(settings["weak_below"]) else "good")
	verdict_label.text = words["verdict"][kind]
	cheer_height = float(settings["jump_meters"][kind])
	cheering = true
	confetti.amount = maxi(int(float(settings["confetti_amount"]) * float(settings["confetti_share"][kind])), 8)
	confetti.emitting = true
	Sfx.play("cheer")
	AudioManager.play_sfx("done")
	AudioManager.play_music("win")
	await wait(float(settings["skip_after_seconds"]))
	if is_inside_tree():
		go_button.visible = true
		go_button.grab_focus()


func _process(delta: float) -> void:
	time += delta
	if cheering:
		for i in staff.size():
			var person: Node3D = staff[i]
			person.position.y = absf(sin(time * 6.0 + i * 1.3)) * cheer_height
	# The camera drifts slowly closer.
	camera.position.z = maxf(camera.position.z - delta * 0.4, 26.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("confirm") and go_button.visible:
		get_viewport().set_input_as_handled()
		leave()


func leave() -> void:
	if leaving:
		return
	leaving = true
	StageManager.go_next()
