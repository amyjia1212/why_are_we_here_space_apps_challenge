# launch.gd
# The launch, rebuilt in 3D like reference 1 (UPGRADE_PLAN_V2 step 16),
# with the player's own rocket and spacecraft.
#   1. The pad at dawn, with the GO / NO-GO poll. GO FOR LAUNCH starts it.
#      "Scrub" goes back to the design; "Skip" works after the first launch.
#   2. A countdown from 10 with big numbers, then the ignition press.
#   3. Liftoff: smoke, the camera follows the rocket, a science caption.
#   4. The climb: the sky goes from orange to purple to black, the rocket tips
#      over, and a ring prompt for each of the rocket's launch moments
#      (THROTTLE DOWN, STAGE, FAIRING). The cheaper the rocket, the more prompts.
#   5. One surprise from data/events.json ("launch_events"): ENGINE OUT or a
#      DEBRIS ALERT. How bad it is depends on the Assembly and Hammering scores.
#   6. Space: the first stage drops, the nose cone splits, Earth's curve below.
#   7. The burn toward the Moon, Mars or Venus, then RELEASE, then
#      HOLD TO DETUMBLE until the spin is zero: STABLE.
#   8. A short summary of what the launch cost, then the flight.
# Every press uses the same rules as before: Perfect or Good costs nothing, a
# Miss adds a cost to GameState.damage (timing.json "launch_moments"). The
# structure check (Hammering) runs at the end. Numbers: timing.json "launch3d",
# events.json "launch_events". Words: story.json "launch3d" and "launch_screen".
extends Node3D

const PRESS_SCENE := preload("res://scenes/timed_press.tscn")
const BAR_SCENE := preload("res://scenes/inner_voice_bar.tscn")

var numbers: Dictionary       # timing.json "launch3d"
var words: Dictionary         # story.json "launch3d"
var old_words: Dictionary     # story.json "launch_screen" (costs, summary)
var voice_lines: Dictionary   # inner_voice.json "launch"
var moment_ids: Array = []
var tightness: float = 1.0
var result_counts: Dictionary = {}

# 3D
var pad: Dictionary
var rocket: RocketModel
var craft: SpacecraftModel
var camera: Camera3D
var camera_mode: String = "pad"   # pad, follow, space, payload
var smoke: CPUParticles3D
var big_smoke: CPUParticles3D
var space_set: Node3D
var climbing: bool = false
var climb_speed: float = 0.0
var flame: float = 0.0
var upper_flame: float = 0.0
var spin: float = 0.0             # the spacecraft's spin after release, degrees per second
var payload: Node3D

# Telemetry on the tiles.
var mission_time: float = 0.0     # seconds; negative = before liftoff
var clock_running: bool = false
var altitude: float = 0.0
var speed: float = 0.0
var status_id: String = "pad"

# UI
var tile_values: Dictionary = {}
var right_column: VBoxContainer
var poll_box: VBoxContainer
var timeline_box: HFlowContainer
var chips: Dictionary = {}
var go_button: Button
var scrub_button: Button
var skip_button: Button
var big_label: Label
var float_label: Label
var press: Control
var ring_hint: Label
var caption_panel: PanelContainer
var caption_title: Label
var caption_text: Label
var alert_panel: PanelContainer
var alert_title: Label
var alert_text: Label
var alert_bar: ProgressBar
var alert_buttons: HBoxContainer
var detumble_box: VBoxContainer
var detumble_label: Label
var detumble_bar: ProgressBar
var fade: ColorRect
var inner_voice: PanelContainer
var debris_choice: String = ""
signal debris_done
var plush: Control               # the zero-g plush in the cabin tile (UPGRADE_PLAN_V3 A2)
var plush_floating: bool = false
var plush_time: float = 0.0


func _ready() -> void:
	if GameState.character_id == "":
		GameState.character_id = Data.game_data["setup"]["default_character"]
	if GameState.mission_id == "":
		GameState.mission_id = Data.missions.keys()[0]
	GameState.fill_default_choices()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	numbers = Data.timing["launch3d"]
	words = Data.story["launch3d"]
	old_words = Data.story["launch_screen"]
	voice_lines = Data.voice["launch"]
	var timing: Dictionary = Data.timing["launch_vehicles"][GameState.get_launch_vehicle_id()]
	moment_ids = timing["moment_ids"]
	# The launch date changes how tight the launch moments are (extras: launch_window).
	tightness = timing["window_tightness"] * float(GameState.get_launch_window()["tightness_factor"])
	GameState.start_launch()
	GameState.weather_wait_cost = 0.0
	# UPGRADE_PLAN_V6 B1: the scrub chance comes from the picked launch date.
	scrubs = 0
	weather_amber = roll_scrub()
	mission_time = -float(numbers["pad_mission_time"])
	build_world()
	build_ui()
	fill_poll()
	build_peanut_jar()
	inner_voice.say(voice_lines["start"])


func alive() -> bool:
	return is_inside_tree()


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout   # false = it stops in the pause menu


# ---------- the 3D world ----------

func build_world() -> void:
	pad = LaunchPad.build(self, Data.game_data["start_menu"])
	rocket = load("res://scenes/rockets/rocket_" + GameState.get_launch_vehicle_id() + ".tscn").instantiate()
	rocket.position.y = 1.0
	add_child(rocket)
	craft = SpacecraftModel.new()
	craft.scale = Vector3.ONE * 0.45
	rocket.payload.add_child(craft)

	smoke = make_smoke(30, 2.0, 3.0)
	big_smoke = make_smoke(160, 7.0, 4.0)

	camera = Camera3D.new()
	camera.fov = 55
	camera.h_offset = 6.0   # the rocket sits in the left part, clear of the right panel
	add_child(camera)
	camera.current = true
	place_pad_camera()


func make_smoke(amount: int, spread: float, life: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = life
	particles.emitting = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = spread
	particles.direction = Vector3(0, 0.3, 0)
	particles.spread = 80.0
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 3.0
	particles.gravity = Vector3(0, 0.6, 0)
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.5
	var puff := SphereMesh.new()
	puff.radius = 0.6
	puff.height = 1.2
	puff.radial_segments = 8
	puff.rings = 4
	puff.material = MeshKit.material(Color(0.92, 0.9, 0.88, 0.55))
	particles.mesh = puff
	particles.position = Vector3(0, 1.2, 0)
	add_child(particles)
	return particles


func place_pad_camera() -> void:
	camera.position = Vector3(-15, 7, 30)
	camera.look_at(Vector3(0, 11, 0), Vector3.UP)


func _process(delta: float) -> void:
	if clock_running:
		mission_time += delta
	if climbing:
		climb_speed += float(numbers["climb_acceleration"]) * delta
		rocket.position.y += climb_speed * delta
		var share: float = clampf(rocket.position.y / float(numbers["climb_height"]), 0.0, 1.0)
		rocket.rotation.z = -deg_to_rad(float(numbers["pitch_degrees"])) * share * share
		rocket.position.x += climb_speed * delta * sin(-rocket.rotation.z)
		tint_sky(share)
	if rocket != null:
		rocket.set_flame(flame)
		rocket.set_flame(upper_flame, true)
	if payload != null and spin > 0.0:
		payload.rotate_object_local(Vector3.RIGHT, deg_to_rad(spin) * delta)
	update_camera(delta)
	update_tiles()
	if plush_floating and plush != null:
		plush_time += delta
		plush.queue_redraw()


func update_camera(_delta: float) -> void:
	match camera_mode:
		"follow":
			var target: Vector3 = rocket.global_position + Vector3(0, 10, 0)
			camera.position = target + Vector3(-12, -3, 26)
			camera.look_at(target, Vector3.UP)
		"space":
			camera.position = Vector3(-4, 4, 26)
			camera.look_at(Vector3(4, 0, 0), Vector3.UP)
		"payload":
			if payload != null:
				camera.position = payload.global_position + Vector3(-2, 1.5, 7)
				camera.look_at(payload.global_position, Vector3.UP)


# The sky goes from dawn orange to purple to black as the rocket climbs.
func tint_sky(share: float) -> void:
	var sky: ProceduralSkyMaterial = pad["sky"]
	var settings: Dictionary = Data.game_data["start_menu"]
	var purple := Color(0.25, 0.12, 0.38)
	var black := Color(0.01, 0.01, 0.04)
	if share < 0.5:
		var t: float = share * 2.0
		sky.sky_horizon_color = Color(settings["sky_horizon"]).lerp(purple, t)
		sky.sky_top_color = Color(settings["sky_top"]).lerp(purple.darkened(0.4), t)
	else:
		var t: float = (share - 0.5) * 2.0
		sky.sky_horizon_color = purple.lerp(black, t)
		sky.sky_top_color = purple.darkened(0.4).lerp(black, t)
	(pad["environment"] as Environment).fog_density = 0.004 * (1.0 - share)


# The cut to space: Earth's curve below, thin blue air, stars, black sky.
func build_space() -> void:
	pad["ground"].visible = false
	smoke.emitting = false
	big_smoke.emitting = false
	var environment: Environment = pad["environment"]
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.02)
	environment.fog_enabled = false
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.65, 0.8)
	environment.ambient_light_energy = 0.5
	(pad["sun"] as DirectionalLight3D).light_color = Color(1, 1, 0.96)
	(pad["sun"] as DirectionalLight3D).rotation_degrees = Vector3(-35, 60, 0)
	space_set = Node3D.new()
	add_child(space_set)
	var earth := MeshKit.sphere(space_set, 400.0, Vector3(0, -425, -60), Color(0.15, 0.35, 0.75), 64)
	earth.material_override.roughness = 0.9
	var air := MeshKit.sphere(space_set, 408.0, Vector3(0, -425, -60), Color(0.45, 0.7, 1.0, 0.22), 64)
	air.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var stars := CPUParticles3D.new()
	stars.amount = 400
	stars.lifetime = 1000.0
	stars.preprocess = 1.0
	stars.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	stars.emission_sphere_radius = 300.0
	stars.gravity = Vector3.ZERO
	stars.initial_velocity_min = 0.0
	stars.initial_velocity_max = 0.0
	var dot := QuadMesh.new()
	dot.size = Vector2(0.8, 0.8)
	var dot_material := MeshKit.glow(Color(1, 1, 1), 1.0)
	dot_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dot.material = dot_material
	stars.mesh = dot
	space_set.add_child(stars)
	# The rocket now flies sideways above Earth.
	climbing = false
	rocket.position = Vector3.ZERO
	rocket.rotation = Vector3(0, 0, -PI / 2.0)
	rocket.scale = Vector3.ONE * 0.6
	camera.h_offset = 3.0
	camera_mode = "space"


# ---------- the UI ----------

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# Top-left: the four tiles, then the header chips and buttons.
	var top := VBoxContainer.new()
	top.position = Vector2(16, 44)
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 8)
	top.add_child(tiles)
	for tile_id in ["time", "altitude", "speed", "status"]:
		var tile := PanelContainer.new()
		tile.theme_type_variation = &"NavyPanel"
		tile.custom_minimum_size.x = 172   # five tiles (with the cabin) stay left of the right panel
		tiles.add_child(tile)
		var box := VBoxContainer.new()
		tile.add_child(box)
		var name_label := Label.new()
		name_label.theme_type_variation = &"TinyText"
		name_label.text = words["tiles"][tile_id]
		box.add_child(name_label)
		var value := Label.new()
		value.theme_type_variation = &"BodyText"
		box.add_child(value)
		tile_values[tile_id] = value
	# The cabin camera (UPGRADE_PLAN_V3 A2): our zero-g plush sits on the
	# dashboard, and floats once the launch reaches STABLE.
	var cabin := PanelContainer.new()
	cabin.theme_type_variation = &"NavyPanel"
	tiles.add_child(cabin)
	var cabin_box := VBoxContainer.new()
	cabin.add_child(cabin_box)
	var cabin_name := Label.new()
	cabin_name.theme_type_variation = &"TinyText"
	cabin_name.text = words["tiles"]["cabin"]
	cabin_box.add_child(cabin_name)
	plush = Control.new()
	plush.custom_minimum_size = Vector2(70, 40)
	plush.draw.connect(_draw_plush)
	cabin_box.add_child(plush)
	var chips_row := HBoxContainer.new()
	chips_row.add_theme_constant_override("separation", 8)
	top.add_child(chips_row)
	add_chip_label(chips_row, words["rocket_chip"].format({"rocket": Data.story["launch_vehicles"][GameState.get_launch_vehicle_id()]["name"]}))
	add_chip_label(chips_row, words["site"])
	# The buttons get their own row, so they never run under the right panel.
	var buttons_row := HBoxContainer.new()
	buttons_row.add_theme_constant_override("separation", 8)
	top.add_child(buttons_row)
	scrub_button = Button.new()
	scrub_button.text = words["scrub"]
	scrub_button.theme_type_variation = &"SmallButton"
	scrub_button.pressed.connect(_on_scrub_pressed)
	buttons_row.add_child(scrub_button)
	skip_button = Button.new()
	skip_button.text = words["skip"]
	skip_button.theme_type_variation = &"SmallButton"
	skip_button.visible = GameState.launches_done > 0   # only after the first launch
	skip_button.pressed.connect(_on_skip_pressed)
	buttons_row.add_child(skip_button)

	# Right: the poll, the timeline and the big button.
	var right := PanelContainer.new()
	right.theme_type_variation = &"NavyPanel"
	right.anchor_left = 0.7
	right.anchor_right = 1.0
	right.anchor_bottom = 1.0
	right.offset_left = 0
	right.offset_right = -12
	right.offset_top = 44
	right.offset_bottom = -205   # leaves room for the Hud's Q ? sign above the voice bar
	root.add_child(right)
	# The poll and the timeline scroll if they are too tall; the GO button stays
	# at the bottom of the panel, always above the voice bar.
	var right_outer := VBoxContainer.new()
	right_outer.add_theme_constant_override("separation", 8)
	right.add_child(right_outer)
	var right_scroll := ScrollContainer.new()
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_outer.add_child(right_scroll)
	right_column = VBoxContainer.new()
	right_column.add_theme_constant_override("separation", 8)
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right_column)
	poll_box = VBoxContainer.new()
	right_column.add_child(poll_box)
	var timeline_title := Label.new()
	timeline_title.theme_type_variation = &"AccentText"
	timeline_title.text = words["timeline_title"]
	right_column.add_child(timeline_title)
	timeline_box = HFlowContainer.new()
	timeline_box.add_theme_constant_override("h_separation", 8)
	timeline_box.add_theme_constant_override("v_separation", 8)
	right_column.add_child(timeline_box)
	add_timeline_chip("countdown", words["chips"]["countdown"])
	for moment_id in moment_ids:
		add_timeline_chip(moment_id, words["prompts"][moment_id])
	add_timeline_chip("surprise", words["chips"]["surprise"])
	add_timeline_chip("orbit", words["chips"]["orbit"])
	add_timeline_chip("burn", words["chips"]["burn"])
	add_timeline_chip("stable", words["chips"]["stable"])
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_child(filler)
	go_button = Button.new()
	go_button.text = words["go_button"]
	go_button.custom_minimum_size = Vector2(0, 64)
	go_button.pressed.connect(_on_go_pressed)
	right_outer.add_child(go_button)

	# Middle of the 3D view: big countdown numbers, floating text, the ring.
	big_label = make_center_label(root, &"HugeText", -60)
	float_label = make_center_label(root, &"FloatText", -150)
	# The ring sits in the right half of the 3D view, clear of the caption box
	# (bottom left) and above the voice bar; its hint goes above it.
	press = PRESS_SCENE.instantiate()
	press.position = Vector2(566, 180)
	press.visible = false
	root.add_child(press)
	ring_hint = Label.new()
	ring_hint.theme_type_variation = &"SmallText"
	ring_hint.text = words["ring_hint"]
	ring_hint.position = Vector2(566, 530)   # just under the ring, right of the caption box, above the voice bar
	ring_hint.custom_minimum_size.x = 300
	ring_hint.theme_type_variation = &"HintText"   # small, so it stays on one line between the caption box and the right panel
	ring_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ring_hint.visible = false
	root.add_child(ring_hint)

	# Bottom-left: the science caption.
	caption_panel = PanelContainer.new()
	caption_panel.theme_type_variation = &"CaptionPanel"
	caption_panel.anchor_top = 1.0
	caption_panel.anchor_bottom = 1.0
	caption_panel.offset_left = 16
	caption_panel.offset_top = -330
	caption_panel.offset_right = 560
	caption_panel.offset_bottom = -170
	caption_panel.visible = false
	root.add_child(caption_panel)
	var caption_box := VBoxContainer.new()
	caption_panel.add_child(caption_box)
	caption_title = Label.new()
	caption_title.theme_type_variation = &"AccentText"
	caption_box.add_child(caption_title)
	caption_text = Label.new()
	caption_text.theme_type_variation = &"TableText"
	caption_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption_box.add_child(caption_text)

	# The alert box (ENGINE OUT / DEBRIS ALERT).
	alert_panel = PanelContainer.new()
	alert_panel.theme_type_variation = &"AlertPanel"
	alert_panel.position = Vector2(16, 270)   # left, under the tiles, so the ring (right) stays in view
	alert_panel.custom_minimum_size = Vector2(520, 0)
	alert_panel.visible = false
	root.add_child(alert_panel)
	var alert_box := VBoxContainer.new()
	alert_panel.add_child(alert_box)
	alert_title = Label.new()
	alert_title.theme_type_variation = &"HeadingText"
	alert_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_box.add_child(alert_title)
	alert_text = Label.new()
	alert_text.theme_type_variation = &"TableText"
	alert_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	alert_box.add_child(alert_text)
	alert_bar = ProgressBar.new()
	alert_bar.show_percentage = false
	alert_bar.custom_minimum_size.y = 14
	alert_box.add_child(alert_bar)
	alert_buttons = HBoxContainer.new()
	alert_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	alert_buttons.add_theme_constant_override("separation", 24)
	alert_box.add_child(alert_buttons)

	# HOLD TO DETUMBLE.
	detumble_box = VBoxContainer.new()
	detumble_box.position = Vector2(1280 * 0.35 - 220, 260)   # above the caption box and the voice bar
	detumble_box.custom_minimum_size.x = 440
	detumble_box.visible = false
	root.add_child(detumble_box)
	detumble_label = Label.new()
	detumble_label.theme_type_variation = &"HeadingText"
	detumble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detumble_box.add_child(detumble_label)
	detumble_bar = ProgressBar.new()
	detumble_bar.show_percentage = false
	detumble_bar.custom_minimum_size.y = 18
	detumble_box.add_child(detumble_bar)

	inner_voice = BAR_SCENE.instantiate()
	layer.add_child(inner_voice)

	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)


func add_chip_label(parent: Control, text: String) -> void:
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"HintPanel"
	parent.add_child(chip)
	var label := Label.new()
	label.theme_type_variation = &"SmallText"
	label.text = text
	chip.add_child(label)


func add_timeline_chip(chip_id: String, text: String) -> void:
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"HintPanel"
	timeline_box.add_child(chip)
	var label := Label.new()
	label.theme_type_variation = &"TinyText"
	label.text = text
	chip.add_child(label)
	chips[chip_id] = label
	set_chip(chip_id, "idle")


# idle = gray, now = amber, done = green.
func set_chip(chip_id: String, state: String) -> void:
	if not chips.has(chip_id):
		return
	var label: Label = chips[chip_id]
	var color_name: String = {"idle": "idle_color", "now": "caution_color", "done": "go_color", "bad": "danger_color"}[state]
	label.add_theme_color_override("font_color", label.get_theme_color(color_name, &"Status"))


func make_center_label(root: Control, style: StringName, y: float) -> Label:
	var label := Label.new()
	label.theme_type_variation = style
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.anchor_left = 0.0
	label.anchor_right = 0.7
	label.anchor_top = 0.5
	label.anchor_bottom = 0.5
	label.offset_top = y - 90
	label.offset_bottom = y + 90
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	return label


func update_tiles() -> void:
	var t: int = int(absf(mission_time))
	tile_values["time"].text = words["time_format"].format({
		"sign": "-" if mission_time < 0 else "+",
		"minutes": "%02d" % (t / 60), "seconds": "%02d" % (t % 60)})
	tile_values["altitude"].text = words["altitude_format"].format({"value": GameState.fmt(altitude)})
	tile_values["speed"].text = words["speed_format"].format({"value": GameState.fmt(speed)})
	tile_values["status"].text = words["status"][status_id]


# ---------- the GO / NO-GO poll ----------

func fill_poll() -> void:
	var title := Label.new()
	title.theme_type_variation = &"AccentText"
	title.text = words["poll_title"]
	poll_box.add_child(title)
	var totals: Dictionary = GameState.get_totals()
	var rocket_name: String = Data.story["launch_vehicles"][GameState.get_launch_vehicle_id()]["name"]
	var capacity: float = GameState.get_rocket_capacity()
	var mass_ok: bool = GameState.is_ok(totals["mass"], GameState.get_limits()["mass"])
	var mass_blanks := {"mass": GameState.fmt(totals["mass"]), "rocket": rocket_name, "capacity": GameState.fmt(capacity)}
	var orbit_name: String = Data.story["orbits"][GameState.get_destination_key()][GameState.get_orbit_id()]["name"]
	var blocker_count: int = GameState.get_failed_resources().size() + GameState.get_missing_key_instruments().size()
	var reasons: PackedStringArray = []
	add_poll_row("rocket", rocket_name, true)
	var mass_text: String = old_words["mass_fits" if mass_ok else "mass_over"].format(mass_blanks)
	add_poll_row("mass", mass_text, mass_ok)
	if not mass_ok:
		reasons.append(mass_text)
	add_poll_row("orbit", orbit_name, true)
	var design_text: String = old_words["no_blockers"] if blocker_count == 0 else old_words["some_blockers"].format({"count": blocker_count})
	add_poll_row("design", design_text, blocker_count == 0)
	if blocker_count > 0:
		reasons.append(design_text)
	# The weather call (extras): sometimes amber; GO then asks to launch now or wait a day.
	var weather_words: Dictionary = Data.story["extras"]["weather"]
	add_poll_row("weather", weather_words["amber"] if weather_amber else words["weather_quiet"], not weather_amber)
	if weather_amber:
		reasons.append(words["poll_items"]["weather"] + ": " + weather_words["amber"])
	var warning := Label.new()
	warning.theme_type_variation = &"TinyText"
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.text = words["all_go"] if reasons.is_empty() else words["caution_line"].format({"reason": reasons[0]})
	warning.add_theme_color_override("font_color", warning.get_theme_color("go_color" if reasons.is_empty() else "caution_color", &"Status"))
	poll_box.add_child(warning)


func add_poll_row(item_id: String, detail: String, go: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	poll_box.add_child(row)
	var badge := Label.new()
	badge.theme_type_variation = &"TableText"
	badge.text = words["go"] if go else words["caution"]
	badge.custom_minimum_size.x = 104
	badge.add_theme_color_override("font_color", badge.get_theme_color("go_color" if go else "caution_color", &"Status"))
	row.add_child(badge)
	var line := Label.new()
	line.theme_type_variation = &"TinyText"
	line.text = words["poll_items"][item_id] + ": " + detail
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(line)


func _on_scrub_pressed() -> void:
	AudioManager.play_sfx("cancel")
	StageManager.go_to(Data.game_data["stages"]["redesign_to"])


# After the first launch: skip it. Every moment counts as Good (no cost);
# the structure check still runs.
func _on_skip_pressed() -> void:
	skip_button.disabled = true
	for moment_id in moment_ids:
		GameState.record_press("launch", moment_id, "Good")
	GameState.apply_structure_check()
	GameState.launches_done += 1
	GameState.set_goal("launch_safely", "done")   # the checklist (UPGRADE_PLAN_V3 A3)
	StageManager.go_next()


# The Q card (UPGRADE_PLAN_V3 A2): the peanut jar on the pad, the floating
# plush once STABLE, the rocket stages in between.
func get_question_id() -> String:
	if go_button != null and go_button.visible:
		return "lucky_peanuts"
	if plush_floating:
		return "zero_g_indicator"
	return "staging"


# The plush in the cabin tile: an original little bear-like toy (DEFAULT: not
# a real character). It sits on the dashboard line, then bobs once weightless.
func _draw_plush() -> void:
	var w: float = plush.size.x
	var h: float = plush.size.y
	var dash_y: float = h - 4.0
	plush.draw_line(Vector2(0, dash_y), Vector2(w, dash_y), Color(0.5, 0.55, 0.65), 2.0)
	var info: Dictionary = Data.extras["zero_g_toy"]
	var body := Color(info["body_color"])
	var ears := Color(info["ear_color"])
	var lift: float = 0.0
	var tilt: float = 0.0
	if plush_floating:
		lift = 10.0 + sin(plush_time * 2.0) * 4.0
		tilt = sin(plush_time * 1.3) * 0.4
	var c := Vector2(w / 2.0, dash_y - 9.0 - lift)
	plush.draw_set_transform(c, tilt, Vector2.ONE)
	plush.draw_circle(Vector2(0, 0), 8.0, body)
	plush.draw_circle(Vector2(0, -11.0), 6.5, body)
	plush.draw_circle(Vector2(-5.0, -16.0), 2.6, ears)
	plush.draw_circle(Vector2(5.0, -16.0), 2.6, ears)
	plush.draw_circle(Vector2(-2.2, -12.0), 1.0, Color(0.1, 0.1, 0.1))
	plush.draw_circle(Vector2(2.2, -12.0), 1.0, Color(0.1, 0.1, 0.1))
	plush.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _on_go_pressed() -> void:
	if weather_amber:
		ask_weather()
		return
	go_button.disabled = true
	go_button.visible = false
	scrub_button.disabled = true
	skip_button.visible = false
	AudioManager.play_sfx("confirm")
	run_sequence()


# ---------- the extras (2026-11-14, data/extras.json) ----------

var weather_amber: bool = false
var scrubs: int = 0   # how many times the weather scrubbed this launch


# Amber weather (a scrub) for the picked date, until that date's max_scrubs is used up.
func roll_scrub() -> bool:
	var window: Dictionary = GameState.get_launch_window()
	if scrubs >= int(window.get("max_scrubs", 1)):
		return false
	return randf() < float(window.get("scrub_chance", Data.extras["weather"]["amber_chance"]))


var peanut_jar: Control
var peanut_label: Label
var peanuts_left: int = 0


# Wait-or-go: amber weather. Launch now (tighter launch moments) or wait a day
# (costs money from the flight's cash reserve, and the weather turns green).
func ask_weather() -> void:
	var weather: Dictionary = Data.extras["weather"]
	var weather_words: Dictionary = Data.story["extras"]["weather"]
	var cost: String = GameState.fmt(weather["wait_cost"])
	AudioManager.play_sfx("warning")
	go_button.disabled = true
	show_alert(weather_words["ask_title"], weather_words["ask_text"].format({"cost": cost}), true)
	alert_bar.visible = false
	for child in alert_buttons.get_children():
		child.queue_free()
	for choice in ["go_now", "wait"]:
		var button := Button.new()
		button.text = weather_words[choice].format({"cost": cost})
		button.theme_type_variation = &"SmallButton"
		button.pressed.connect(_on_weather_choice.bind(choice))
		alert_buttons.add_child(button)


func _on_weather_choice(choice: String) -> void:
	var weather: Dictionary = Data.extras["weather"]
	alert_panel.visible = false
	weather_amber = false
	go_button.disabled = false
	if choice == "wait":
		scrubs += 1
		if scrubs >= 2:
			Achievements.unlock("scrubbed_twice")
		GameState.weather_wait_cost += float(weather["wait_cost"])
		# After the wait the weather can scrub the launch AGAIN (B1): poor dates often do.
		weather_amber = roll_scrub()
		var window_words: Dictionary = Data.story["extras"]["launch_window"]
		if weather_amber:
			inner_voice.say(window_words["scrub_again_poor"] if GameState.get_launch_window_id() == "poor" else window_words["scrub_again"])
			AudioManager.play_sfx("warning")
		else:
			inner_voice.say(Data.voice["extras"]["weather_wait"])
		for child in poll_box.get_children():
			child.queue_free()
		await get_tree().process_frame
		fill_poll()
		if not weather_amber:
			# Say the new weather in the poll: calm after the wait.
			var last_row: Node = poll_box.get_child(poll_box.get_child_count() - 2)
			if last_row is HBoxContainer:
				(last_row.get_child(1) as Label).text = words["poll_items"]["weather"] + ": " + Data.story["extras"]["weather"]["green_after_wait"]
			AudioManager.play_sfx("confirm")
	else:
		tightness *= float(weather["go_tightness_factor"])
		inner_voice.say(Data.voice["extras"]["weather_go"])
		_on_go_pressed()


# Lucky peanuts: a jar by the buttons. E (or a click) eats one. It changes
# nothing, and the game says so.
func build_peanut_jar() -> void:
	peanuts_left = int(Data.extras["peanuts"]["jar_count"])
	# A little glass jar on the console, drawn in code: the peanuts inside go
	# down as you eat them. Click it (or press E).
	var holder := PanelContainer.new()
	holder.theme_type_variation = &"HintPanel"
	scrub_button.get_parent().add_child(holder)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	holder.add_child(row)
	peanut_jar = Control.new()
	peanut_jar.custom_minimum_size = Vector2(44, 52)
	peanut_jar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	peanut_jar.draw.connect(_draw_peanut_jar)
	peanut_jar.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			eat_peanut())
	row.add_child(peanut_jar)
	peanut_label = Label.new()
	peanut_label.theme_type_variation = &"SmallText"
	peanut_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(peanut_label)
	update_peanut_jar()


func update_peanut_jar() -> void:
	var peanut_words: Dictionary = Data.story["extras"]["peanuts"]
	peanut_label.text = peanut_words["jar"].format({"count": peanuts_left}) if peanuts_left > 0 else peanut_words["empty"]
	peanut_jar.queue_redraw()


func _draw_peanut_jar() -> void:
	var w: float = peanut_jar.size.x
	var h: float = peanut_jar.size.y
	var glass := Color(0.75, 0.88, 1.0, 0.35)
	var rim := Color(0.85, 0.92, 1.0, 0.9)
	var nut := Color(0.79, 0.58, 0.35)
	var body := Rect2(3.0, 12.0, w - 6.0, h - 14.0)
	peanut_jar.draw_rect(body, glass)
	peanut_jar.draw_rect(body, rim, false, 2.0)
	peanut_jar.draw_rect(Rect2(6.0, 4.0, w - 12.0, 8.0), Color(0.85, 0.25, 0.2))   # the red lid
	# The peanuts: little two-bump shells, stacked from the bottom.
	var total: int = int(Data.extras["peanuts"]["jar_count"])
	var per_row: int = 3
	for i in peanuts_left:
		var col: int = i % per_row
		var row_index: int = i / per_row
		var c := Vector2(10.0 + col * 12.0, h - 8.0 - row_index * (h - 24.0) / ceilf(float(total) / per_row))
		peanut_jar.draw_circle(c + Vector2(-2.5, 0), 3.6, nut)
		peanut_jar.draw_circle(c + Vector2(2.5, 0), 3.6, nut)


func eat_peanut() -> void:
	if peanuts_left <= 0:
		return
	peanuts_left -= 1
	GameState.peanuts_eaten += 1
	Achievements.unlock("peanuts")
	AudioManager.play_sfx("pickup")
	# The message shows right next to the jar for a moment (not over the buttons).
	peanut_label.text = Data.story["extras"]["peanuts"]["ate"]
	peanut_jar.queue_redraw()
	get_tree().create_timer(1.6).timeout.connect(func():
		if is_instance_valid(peanut_label):
			update_peanut_jar())
	if GameState.peanuts_eaten == 1:
		inner_voice.say(Data.story["extras"]["peanuts"]["fact"].format({"year": GameState.fmt(Data.extras["peanuts"]["since_year"])}))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		eat_peanut()
		get_viewport().set_input_as_handled()


# ---------- the launch, beat by beat ----------

func run_sequence() -> void:
	# 2. Countdown with big numbers and smoke building at the base.
	set_chip("countdown", "now")
	clock_running = true
	smoke.emitting = true
	var from: int = numbers["countdown_from"]
	var step: float = numbers["countdown_step_seconds"]
	mission_time = -from * step
	# The ignition ring starts so that it closes right at zero.
	var close_time: float = Data.timing["timed_press"]["close_seconds"] / Data.timing["timed_press"]["base_speed"]
	get_tree().create_timer(maxf(from * step - close_time, 0.0), false).timeout.connect(start_ignition_ring)
	for n in range(from, 0, -1):
		big_label.text = str(n)
		AudioManager.play_sfx("countdown")
		pop(big_label)
		await wait(step)
		if not alive():
			return
	big_label.text = ""
	set_chip("countdown", "done")
	var result: String = press.last_result
	if press.running or result == "":
		result = await press.finished
	if not alive():
		return
	score_moment("liftoff", result)
	# 3. Liftoff.
	AudioManager.play_sfx("countdown_go")
	AudioManager.play_sfx("rumble")
	big_smoke.emitting = true
	flame = 1.0
	climbing = true
	camera_mode = "follow"
	status_id = "ascent"
	tween_telemetry(float(numbers["telemetry"]["orbit_altitude_km"]) * 0.5, float(numbers["telemetry"]["orbit_speed_kmh"]) * 0.4, float(numbers["liftoff_seconds"]) + float(numbers["between_prompts_seconds"]) * 2.0)
	show_caption("liftoff")
	await wait(float(numbers["liftoff_seconds"]))
	if not alive():
		return
	big_smoke.emitting = false
	# 4. The climb: one ring per launch moment of this rocket (not liftoff or release).
	var surprise_done := false
	for moment_id in moment_ids:
		if moment_id == "liftoff" or moment_id == "engine_cutoff":
			continue
		await ring_moment(moment_id)
		if not alive():
			return
		apply_moment_visual(moment_id)
		if not surprise_done:
			surprise_done = true
			await wait(float(numbers["between_prompts_seconds"]) * 0.5)
			await run_surprise()
			if not alive():
				return
		await wait(float(numbers["between_prompts_seconds"]) * 0.5)
	if not surprise_done:
		await run_surprise()
		if not alive():
			return
	# 6. Space: cut to Earth's curve; anything not yet dropped drops now.
	await fade_out_in(build_space)
	if not alive():
		return
	status_id = "orbit"
	set_chip("orbit", "now")
	AudioManager.play_music("space")
	altitude = float(numbers["telemetry"]["orbit_altitude_km"])
	speed = float(numbers["telemetry"]["orbit_speed_kmh"])
	flame = 0.0
	if rocket.first_stage != null:
		drop_stage()
	await wait(1.0)
	if not fairing_open:
		open_fairing()
	show_caption("orbit")
	await wait(float(numbers["space_beat_seconds"]))
	if not alive():
		return
	set_chip("orbit", "done")
	# 7. The burn toward the destination.
	set_chip("burn", "now")
	upper_flame = 1.0
	AudioManager.play_sfx("whoosh")
	show_caption("burn")
	tween_telemetry(altitude * 3.0, float(numbers["telemetry"]["escape_speed_kmh"]), float(numbers["burn_seconds"]))
	await wait(float(numbers["burn_seconds"]))
	if not alive():
		return
	upper_flame = 0.0
	set_chip("burn", "done")
	# RELEASE: a ring if this rocket has the engine-cutoff moment, else automatic.
	status_id = "hold"
	if moment_ids.has("engine_cutoff"):
		await ring_moment("engine_cutoff")
		if not alive():
			return
	release()
	await wait(1.2)
	if not alive():
		return
	await detumble()
	if not alive():
		return
	show_summary()


func start_ignition_ring() -> void:
	if not alive():
		return
	press.visible = true
	ring_hint.visible = true
	press.start(words["prompts"]["liftoff"], 1.0, tightness, press.ACTION_SPACE)


func pop(label: Label) -> void:
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2.ONE * 1.4
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.25)


func tween_telemetry(to_altitude: float, to_speed: float, seconds: float) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "altitude", to_altitude, seconds)
	tween.tween_property(self, "speed", to_speed, seconds)


func show_caption(caption_id: String) -> void:
	var caption: Dictionary = words["captions"][caption_id]
	var place_words: Dictionary = Data.story["destinations"][GameState.get_destination_key()]
	var planet: String = place_words.get("in_sentence", place_words["name"])   # "Mars" has no in_sentence: use the name
	caption_title.text = caption["title"]
	caption_text.text = caption["text"].format({"planet": planet})
	caption_panel.visible = true


# One ring prompt for a launch moment, and its result.
func ring_moment(moment_id: String) -> void:
	set_chip(moment_id, "now")
	press.visible = true
	ring_hint.visible = true
	press.start(words["prompts"][moment_id], float(numbers["prompt_speed"]), tightness, press.ACTION_SPACE)
	var result: String = await press.finished
	if not alive():
		return
	score_moment(moment_id, result)
	await wait(0.4)
	if alive():
		press.visible = false
		ring_hint.visible = false


# Records the press like before: a Miss adds its cost to GameState.damage.
func score_moment(moment_id: String, result: String) -> void:
	press.visible = false
	ring_hint.visible = false
	GameState.record_press("launch", moment_id, result)
	if result == "Miss":
		var cost: Dictionary = Data.timing["launch_moments"][moment_id]["miss_cost"]
		GameState.add_damage(cost["kind"], cost["amount"])
	set_chip(moment_id, "bad" if result == "Miss" else "done")
	float_text(words["results"][result])
	var lines: Array = voice_lines["results"][result]
	inner_voice.say(lines[result_counts.get(result, 0) % lines.size()])
	result_counts[result] = result_counts.get(result, 0) + 1


const FLOAT_TOP := -240.0   # where the floating text starts (above the middle)

func float_text(text: String) -> void:
	float_label.text = text
	float_label.modulate.a = 1.0
	float_label.offset_top = FLOAT_TOP
	float_label.offset_bottom = FLOAT_TOP + 180.0
	var seconds: float = numbers["float_text_seconds"]
	var tween := float_label.create_tween().set_parallel(true)
	tween.tween_property(float_label, "offset_top", FLOAT_TOP - 50.0, seconds)
	tween.tween_property(float_label, "offset_bottom", FLOAT_TOP + 130.0, seconds)
	tween.tween_property(float_label, "modulate:a", 0.0, seconds).set_delay(0.4)


# What the rocket does after each moment.
func apply_moment_visual(moment_id: String) -> void:
	match moment_id:
		"max_pressure":
			show_caption("max_pressure")
		"stage_separation":
			show_caption("stage_separation")
			drop_stage()
		"fairing_release":
			show_caption("fairing_release")
			open_fairing()


var fairing_open: bool = false

func open_fairing() -> void:
	fairing_open = true
	rocket.split_fairing()
	AudioManager.play_sfx("separation")


func drop_stage() -> void:
	if rocket.first_stage == null:
		return
	AudioManager.play_sfx("separation")
	var stage: Node3D = rocket.drop_first_stage()
	flame = 0.0
	upper_flame = 1.0
	var tween := stage.create_tween().set_parallel(true)
	tween.tween_property(stage, "position", stage.position + Vector3(-6, -30, 0), 3.0)
	tween.tween_property(stage, "rotation:z", stage.rotation.z + 1.2, 3.0)
	tween.chain().tween_callback(stage.queue_free)
	await wait(1.5)
	if alive() and status_id == "ascent":
		upper_flame = 0.8


func fade_out_in(middle: Callable) -> void:
	var seconds: float = numbers["fade_seconds"]
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, seconds)
	await tween.finished
	if not alive():
		return
	middle.call()
	var back := create_tween()
	back.tween_property(fade, "color:a", 0.0, seconds)
	await back.finished


# ---------- 5. the surprise ----------

func run_surprise() -> void:
	var ids: Array = Data.launch_events.keys().filter(func(id): return not id.begins_with("_"))
	if ids.is_empty():
		return
	set_chip("surprise", "now")
	AudioManager.play_music("tension")
	var event_id: String = ids[randi() % ids.size()]
	if event_id == "engine_out":
		await engine_out()
	else:
		await debris_alert()
	if not alive():
		return
	alert_panel.visible = false
	set_chip("surprise", "done")
	AudioManager.play_music("launch")


func engine_out() -> void:
	var event: Dictionary = Data.launch_events["engine_out"]
	AudioManager.play_sfx("alarm")
	show_alert(words["engine_out"], "", false)
	press.visible = true
	ring_hint.visible = true
	press.start(words["prompts"]["rebalance"], float(numbers["rebalance_speed"]), tightness, press.ACTION_SPACE)
	var result: String = await press.finished
	if not alive():
		return
	press.visible = false
	ring_hint.visible = false
	float_text(words["results"][result])
	if result == "Miss":
		# The worse the Assembly score, the more fuel the computer burns fixing it.
		var quality: float = GameState.get_build_result("build_quality") / 100.0
		var amount: float = float(event["miss_cost"]["amount"]) * lerpf(float(event["worst_multiplier"]), float(event["best_multiplier"]), quality)
		GameState.add_damage(event["miss_cost"]["kind"], amount)
		await wait(0.6)
		float_text(words["computer_took_over"])
	await wait(0.8)


func debris_alert() -> void:
	var event: Dictionary = Data.launch_events["debris_alert"]
	AudioManager.play_sfx("warning")
	show_alert(words["debris_title"], words["debris_text"], true)
	for child in alert_buttons.get_children():
		child.queue_free()
	for choice in ["wait", "release"]:
		var button := Button.new()
		button.text = words["debris_" + choice]
		button.theme_type_variation = &"SmallButton"
		button.pressed.connect(_on_debris_choice.bind(choice))
		alert_buttons.add_child(button)
	debris_choice = ""
	var seconds: float = event["seconds"]
	alert_bar.max_value = seconds
	alert_bar.value = seconds
	var left: float = seconds
	while left > 0.0 and debris_choice == "":
		await get_tree().process_frame
		if not alive():
			return
		if not get_tree().paused:
			left -= get_process_delta_time()
		alert_bar.value = left
	alert_buttons.visible = false
	match debris_choice:
		"wait":
			GameState.add_damage(event["wait_cost"]["kind"], event["wait_cost"]["amount"])
			float_text(words["debris_wait"])
		"release":
			var strength: float = GameState.get_build_result("structure_strength")
			var safe: float = event["safe_strength"]
			if strength < safe:
				GameState.add_damage(event["release_cost"]["kind"], float(event["release_cost"]["amount"]) * (1.0 - strength / safe))
				float_text(words["results"]["Miss"])
			else:
				float_text(words["results"]["Perfect"])
		_:
			GameState.add_damage(event["timeout_cost"]["kind"], event["timeout_cost"]["amount"])
			float_text(words["computer_took_over"])
	await wait(1.0)


func _on_debris_choice(choice: String) -> void:
	debris_choice = choice
	AudioManager.play_sfx("confirm")


func show_alert(title: String, text: String, with_buttons: bool) -> void:
	alert_title.text = title
	alert_text.text = text
	alert_text.visible = text != ""
	alert_bar.visible = with_buttons
	alert_buttons.visible = with_buttons
	alert_panel.visible = true
	caption_panel.visible = false   # the alert takes the caption's place, so nothing overlaps


# ---------- 7. release and detumble ----------

func release() -> void:
	AudioManager.play_sfx("separation")
	status_id = "separated"
	payload = rocket.release_payload()
	var tween := payload.create_tween()
	tween.tween_property(payload, "position", payload.position + Vector3(6, 0.5, 0), 2.0)
	var back := rocket.create_tween()
	back.tween_property(rocket, "position", rocket.position + Vector3(-8, -1.5, 0), 3.0)
	spin = float(numbers["start_spin_degrees"])
	camera_mode = "payload"
	camera.h_offset = 1.5


# Hold Space (or the mouse button) until the spin is zero.
func detumble() -> void:
	show_caption("detumble")
	detumble_box.visible = true
	var start_spin: float = numbers["start_spin_degrees"]
	var per_second: float = start_spin / float(numbers["hold_detumble_seconds"])
	detumble_bar.max_value = start_spin
	while spin > 0.5:
		await get_tree().process_frame
		if not alive():
			return
		if get_tree().paused:
			continue
		var holding: bool = Input.is_action_pressed("jump") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if holding:
			spin = maxf(spin - per_second * get_process_delta_time(), 0.0)
		detumble_label.text = words["hold_detumble"] + "\n" + words["spin_line"].format({"value": int(spin)})
		detumble_bar.value = start_spin - spin
	spin = 0.0
	detumble_label.text = words["stable"]
	status_id = "stable"
	set_chip("stable", "done")
	AudioManager.play_sfx("task_done")
	float_text(words["stable"])
	plush_floating = true   # weightless: the plush lifts off the dashboard
	GameState.set_goal("launch_safely", "done")   # the checklist (UPGRADE_PLAN_V3 A3)
	await wait(1.2)


# ---------- 8. the summary ----------

func show_summary() -> void:
	clock_running = false
	detumble_box.visible = false
	GameState.launches_done += 1
	for child in right_column.get_children():
		child.queue_free()
	var title := Label.new()
	title.theme_type_variation = &"AccentText"
	title.text = old_words["summary_title"]
	right_column.add_child(title)
	var any_cost := false
	for kind in GameState.damage:
		any_cost = true
		add_summary_line(old_words["cost_kinds"].get(kind, kind + " {amount}%").format({"amount": GameState.fmt(GameState.damage[kind])}))
	if not any_cost:
		add_summary_line(old_words["no_losses"])
	inner_voice.say(voice_lines["summary_costs" if any_cost else "summary_clean"])
	# The structure check (Hammering score): weak means a part shakes loose.
	add_summary_line("")
	add_summary_line(old_words["structure_title"])
	var strength: String = GameState.fmt(GameState.get_build_result("structure_strength"))
	var shake: float = GameState.apply_structure_check()
	if shake > 0.0:
		var part_id: String = Data.timing["structure_check"]["shake_part"]
		add_summary_line(old_words["structure_shake"].format({
			"strength": strength, "part": Data.part_name(part_id).to_lower(),
			"cost": old_words["cost_kinds"][part_id].format({"amount": GameState.fmt(shake)}),
		}))
	else:
		add_summary_line(old_words["structure_ok"].format({"strength": strength}))
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_child(filler)
	var next := Button.new()
	var place: Dictionary = Data.story["destinations"][GameState.get_destination_key()]
	next.text = words["summary_next"].format({"planet": place.get("in_sentence", place["name"])})
	next.custom_minimum_size.y = 56
	next.pressed.connect(_on_next_pressed.bind(next))
	right_column.add_child(next)


func add_summary_line(text: String) -> void:
	var line := Label.new()
	line.theme_type_variation = &"TinyText"
	line.text = text
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_column.add_child(line)


func _on_next_pressed(button: Button) -> void:
	button.disabled = true
	StageManager.go_next()
