# landing.gd
# The landing animation between the flight and the arrival (playtest note:
# "Should be a landing animation").
#   Moon and Mars: the lander comes down on its engine, slower and slower,
#   the dust blows out when it gets close, then TOUCHDOWN with a thud.
#   Venus: nobody lands, so the ship fires its engine to slow down and stays
#   in orbit around the huge cloudy planet: IN ORBIT.
# A caption with one real fact, an altitude readout, and Space / Enter /
# click to skip. Then the arrival walk starts.
# The ground and sky use the arrival's look (destinations.json > mission >
# "arrival"); the lander uses its "lander" look. Timing and camera:
# game_data.json "landing". Words: story.json "landing".
extends Node3D

var settings: Dictionary   # game_data.json "landing"
var look: Dictionary       # destinations.json > mission > "arrival"
var words: Dictionary      # story.json "landing"
var key: String = ""       # "moon", "mars" or "venus"
var orbit: bool = false    # true for Venus: arrive in orbit instead of landing

var craft: Node3D          # the lander, or the spacecraft (Venus)
var flame: MeshInstance3D
var dust: CPUParticles3D
var camera: Camera3D
var altitude_label: Label
var big_label: Label
var time: float = 0.0
var done: bool = false
var shake: float = 0.0


func _ready() -> void:
	if GameState.character_id == "":
		GameState.character_id = Data.game_data["setup"]["default_character"]
	GameState.fill_default_choices()
	settings = Data.game_data["landing"]
	words = Data.story["landing"]
	key = GameState.get_destination_key()
	look = GameState.get_destination()["arrival"]
	orbit = look["area"] == "ship"
	build_world()
	build_ui()
	AudioManager.play_sfx("rumble")


# ---------- the world ----------

func build_world() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0.02) if orbit else Color(look["sky_color"])
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	environment.ambient_light_energy = 0.5
	environment.fog_enabled = look.get("fog_enabled", false) and not orbit
	environment.fog_light_color = Color(look["sky_color"])
	environment.fog_density = float(look.get("fog_density", 0.0)) * 0.5
	env.environment = environment
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 40, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = false
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = settings["camera_fov"]
	add_child(camera)
	camera.current = true
	if orbit:
		build_orbit()
	else:
		build_surface()


# The ground, a few rocks, and the lander high above it.
func build_surface() -> void:
	var ground := Color(look["ground_color"])
	MeshKit.box(self, Vector3(400, 1, 400), Vector3(0, -0.5, 0), ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 40:
		var spot := Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(-70, 20))
		if spot.length() < 6.0:
			continue
		var size: float = rng.randf_range(0.4, 2.2)
		MeshKit.sphere(self, size, spot, Color(look.get("rock_color", "#666666")), 8).scale = Vector3(1.0, 0.6, 1.0)
	craft = make_lander(look["lander"])
	add_child(craft)
	craft.position = Vector3(0, settings["start_height"], 0)
	# The engine flame under the lander.
	flame = MeshKit.add(craft, cone_mesh(0.45, 2.4), Vector3(0, -1.0, 0), MeshKit.glow(Color(settings["flame_color"]), 3.0))
	flame.rotation.x = PI   # the cone points down
	# The dust that blows out when the engine gets close to the ground.
	dust = CPUParticles3D.new()
	dust.emitting = false
	dust.amount = int(settings["dust_amount"])
	dust.lifetime = 1.6
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = 1.0
	dust.direction = Vector3(1, 0.15, 0)
	dust.spread = 180.0
	dust.flatness = 0.85
	dust.initial_velocity_min = 4.0
	dust.initial_velocity_max = 9.0
	dust.gravity = Vector3(0, -1.0, 0)
	dust.scale_amount_min = 0.3
	dust.scale_amount_max = 0.8
	var puff := SphereMesh.new()
	puff.radius = 0.22
	puff.height = 0.44
	puff.radial_segments = 8
	puff.rings = 4
	dust.mesh = puff
	var dust_color := ground.lightened(0.25)
	dust_color.a = 0.55   # see-through, like a dust cloud
	dust.material_override = MeshKit.material(dust_color)
	add_child(dust)
	dust.position = Vector3(0, 0.3, 0)


# The lander from the arrival's look: a box body with a gold foil band, four
# legs with foot pads, and a dish on top. Its feet are at y = 0.
func make_lander(lander: Dictionary) -> Node3D:
	var root := Node3D.new()
	var size := MeshKit.vec3(lander["size"])
	var leg_h: float = lander.get("leg_height", 0.9)
	MeshKit.box(root, Vector3(size.x, size.y - leg_h, size.z), Vector3(0, leg_h + (size.y - leg_h) / 2.0, 0), Color(lander["color"]))
	MeshKit.box(root, Vector3(size.x * 1.02, 0.35, size.z * 1.02), Vector3(0, leg_h + 0.3, 0), Color(lander.get("foil_color", "#c9a227")))
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var foot := Vector3(corner.x * size.x * 0.75, 0, corner.y * size.z * 0.75)
		var hip := Vector3(corner.x * size.x * 0.4, leg_h + 0.2, corner.y * size.z * 0.4)
		var leg := MeshKit.cylinder(root, 0.07, 0.07, foot.distance_to(hip), (foot + hip) / 2.0, Color(lander.get("leg_color", "#7a8290")), 8)
		leg.basis = Basis(Quaternion(Vector3.UP, (hip - foot).normalized()))
		MeshKit.cylinder(root, 0.3, 0.3, 0.08, foot + Vector3(0, 0.04, 0), Color(lander.get("leg_color", "#7a8290")), 12)
	var dish := MeshKit.cylinder(root, 0.6, 0.12, 0.2, Vector3(size.x * 0.25, size.y + 0.35, 0), Color(lander.get("dish_color", "#eeeeee")), 16)
	dish.rotation_degrees.z = 25
	# The engine bell under the body.
	MeshKit.cylinder(root, 0.25, 0.5, 0.6, Vector3(0, leg_h - 0.1, 0), Color(0.3, 0.32, 0.36), 16)
	return root


# Venus: the huge banded planet below, stars, and the spacecraft flying in.
func build_orbit() -> void:
	var color := Color(Data.game_data["ship"]["planet"]["colors"].get(key, "#e3c16f"))
	var planet := MeshKit.sphere(self, settings["orbit_planet_radius"], Vector3(0, -settings["orbit_planet_radius"] - 6.0, -20), color, 48)
	planet.material_override.albedo_color = Color.WHITE
	planet.material_override.albedo_texture = MeshKit.planet_texture(color, true)
	var stars := CPUParticles3D.new()
	stars.amount = 200
	stars.lifetime = 1000.0
	stars.preprocess = 1.0
	stars.speed_scale = 0.0
	stars.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	stars.emission_sphere_radius = 300.0
	stars.gravity = Vector3.ZERO
	stars.initial_velocity_max = 0.0
	var dot := SphereMesh.new()
	dot.radius = 0.6
	dot.height = 1.2
	stars.mesh = dot
	stars.material_override = MeshKit.glow(Color.WHITE, 2.0)
	add_child(stars)
	craft = SpacecraftModel.new()
	add_child(craft)
	craft.scale = Vector3.ONE * float(settings["orbit_craft_scale"])
	craft.position = Vector3(-settings["orbit_fly_distance"], 2.0, -8)
	# The braking burn: the engine points the way the ship is flying, to slow it down.
	flame = MeshKit.add(craft, cone_mesh(0.5, 3.0), Vector3(2.2, 0, 0), MeshKit.glow(Color(settings["flame_color"]), 3.0))
	flame.rotation.z = -PI / 2.0   # the cone points along +x (forward)


func cone_mesh(radius: float, length: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 12
	return mesh


# ---------- the words on screen ----------

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.theme_type_variation = &"TitleText"
	title.text = words["titles"][key]
	title.position = Vector2(30, 60)
	layer.add_child(title)
	altitude_label = Label.new()
	altitude_label.theme_type_variation = &"HeadingText"
	altitude_label.position = Vector2(30, 130)
	layer.add_child(altitude_label)
	# The caption box (bottom left): one real fact.
	var caption := PanelContainer.new()
	caption.theme_type_variation = &"CaptionPanel"
	caption.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	caption.grow_vertical = Control.GROW_DIRECTION_BEGIN
	caption.position = Vector2(30, -40)
	caption.custom_minimum_size.x = 620
	layer.add_child(caption)
	var box := VBoxContainer.new()
	caption.add_child(box)
	var caption_title := Label.new()
	caption_title.theme_type_variation = &"AccentText"
	caption_title.text = words["captions"][key]["title"]
	box.add_child(caption_title)
	var caption_text := Label.new()
	caption_text.theme_type_variation = &"BodyText"
	caption_text.text = words["captions"][key]["text"]
	caption_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption_text.custom_minimum_size.x = 600
	box.add_child(caption_text)
	big_label = Label.new()
	big_label.theme_type_variation = &"FloatText"
	big_label.set_anchors_preset(Control.PRESET_CENTER)
	big_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	big_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	big_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_label.visible = false
	layer.add_child(big_label)


# ---------- the animation ----------

func _process(delta: float) -> void:
	time += delta
	var duration: float = settings["duration_seconds"]
	var share: float = clampf(time / duration, 0.0, 1.0)
	# Slower and slower near the end (ease out), like a real braking burn.
	var eased: float = 1.0 - pow(1.0 - share, 2.5)
	if orbit:
		animate_orbit(eased)
	else:
		animate_landing(eased, delta)
	if share >= 1.0 and not done:
		finish()
	# A small camera shake at touchdown.
	if shake > 0.0:
		shake = maxf(shake - delta, 0.0)
		camera.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.3


func animate_landing(eased: float, _delta: float) -> void:
	var height: float = lerpf(float(settings["start_height"]), 0.0, eased)
	if not done:
		craft.position.y = height
		craft.rotation.z = sin(time * 1.7) * 0.03 * (height / float(settings["start_height"]))   # a little wobble high up
		flame.scale = Vector3.ONE * (0.8 + randf() * 0.4)
		dust.emitting = height < float(settings["dust_below_height"])
	altitude_label.text = words["altitude"].format({"m": int(craft.position.y * float(settings["altitude_scale"]))})
	# The camera: a wide shot from the side that follows the lander down.
	var target: Vector3 = craft.position + Vector3(0, 1.5, 0)
	camera.position = Vector3(10, 2.5 + craft.position.y * 0.6, 14)
	camera.look_at(target, Vector3.UP)


func animate_orbit(eased: float) -> void:
	if not done:
		craft.position.x = lerpf(-float(settings["orbit_fly_distance"]), 0.0, eased)
		craft.rotation.y += get_process_delta_time() * 0.2
		flame.scale = Vector3.ONE * (0.8 + randf() * 0.4) * (1.0 - eased * 0.6)
	altitude_label.text = words["speed"].format({"percent": int(lerpf(100.0, 0.0, eased))})
	camera.position = Vector3(0, 4.0, 6.0)
	camera.look_at(craft.position, Vector3.UP)


func finish() -> void:
	done = true
	flame.visible = false
	if dust != null:
		dust.emitting = false
		var burst := dust.duplicate() as CPUParticles3D
		add_child(burst)
		burst.position = dust.position
		burst.one_shot = true
		burst.emitting = true
		craft.position.y = 0.0
		craft.rotation = Vector3.ZERO
		shake = 0.4
		AudioManager.play_sfx("clank")
	big_label.text = words["in_orbit" if orbit else "touchdown"]
	big_label.visible = true
	big_label.pivot_offset = big_label.size / 2.0
	big_label.scale = Vector2.ONE * 1.6
	big_label.create_tween().tween_property(big_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioManager.play_sfx("done")
	await get_tree().create_timer(float(settings["hold_seconds"])).timeout
	if is_inside_tree():
		StageManager.go_next()


# Space, Enter or a click skips to the arrival (after a short moment, so a
# key still held from the flight doesn't skip it by accident).
func _unhandled_input(event: InputEvent) -> void:
	if time < 0.6 or done:
		return
	var skip: bool = event.is_action_pressed("jump") or event.is_action_pressed("confirm")
	if event is InputEventMouseButton and event.pressed:
		skip = true
	if skip:
		get_viewport().set_input_as_handled()
		time = float(settings["duration_seconds"])   # jump to the end: touchdown, then go on
