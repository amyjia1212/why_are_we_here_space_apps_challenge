# arrival.gd
# The arrival walk (PLAN.md section 10). Works for every mission: the area,
# the task spots and the tasks all come from destinations.json > <mission> >
# "arrival". Four kinds of task:
#   reach: step on the spot
#   press: press E at the spot
#   hold:  hold E, let go while the bar is in the green zone
#   send:  press E, then the data goes home (slower with a weak signal)
# A task can need an instrument (not packed = the task fails, and the game
# says why) and can need other tasks done first. The tasks tick the
# mission checklist. When nothing is left to do, Enter leaves.
# Missed goals become report findings.
extends Node3D

@onready var environment_node: WorldEnvironment = %Environment
@onready var sun: DirectionalLight3D = %Sun
@onready var world: Node3D = %World
@onready var player: CharacterBody3D = %Player
@onready var task_list: VBoxContainer = %TaskList
@onready var controls_label: Label = %Controls
@onready var prompt_label: Label = %Prompt
@onready var drill_meter: Control = %DrillMeter
@onready var send_bar: ProgressBar = %SendBar
@onready var inner_voice: PanelContainer = %InnerVoiceBar

var settings: Dictionary      # destinations.json > mission > "arrival"
var words: Dictionary         # story.json "arrival_screen"
var voice: Dictionary         # inner_voice.json "arrival" > mission
var mission_key: String = ""  # for example "mars"
var planet: String = ""       # for example "Mars"

var tasks: Array = []             # the task list from the data, in order
var state: Dictionary = {}        # task id -> "open", "done" or "failed"
var current_spot: String = ""     # the spot the player stands on, or ""
var holding: String = ""          # the hold task being held, or ""
var hold_value: float = 0.0
var sending: String = ""          # the send task running, or ""
var send_time: float = 0.0
var send_seconds: float = 0.0
var leaving_allowed: bool = false


func _ready() -> void:
	# Safety net for pressing Play on this screen directly.
	if GameState.character_id == "":
		GameState.character_id = Data.game_data["setup"]["default_character"]
	if GameState.mission_id == "":
		GameState.mission_id = Data.missions.keys()[0]
	GameState.fill_default_choices()

	mission_key = GameState.get_destination_key()
	# "the Moon" inside a sentence, not "The Moon" (story.json in_sentence; the name if none).
	var place_words: Dictionary = Data.story["destinations"][mission_key]
	planet = place_words.get("in_sentence", place_words["name"])
	settings = GameState.get_destination()["arrival"]
	words = Data.story["arrival_screen"]
	voice = Data.voice["arrival"][mission_key]
	# The controls now show in the Hud's hint bar at the top (story.json controls >
	# hints > arrival), like every other screen, so this faint label hides.
	controls_label.visible = false
	make_text_readable()
	tasks = settings["tasks"]
	for task in tasks:
		state[task["id"]] = "open"

	make_environment()
	if settings["area"] == "plain":
		make_plain()
	elif settings["area"] == "ship":
		make_ship()
	for spot_id in settings["spots"]:
		make_spot(spot_id)
	make_spot_props()
	place_player()

	GameState.start_arrival()
	refresh_task_list()
	inner_voice.say(voice["start"])
	# The party on the same planet (bots walk to the tasks; other players show as their characters).
	if ship_builder != null:
		room_rects = ship_builder.room_rects
	crew = PLANET_CREW.new()
	world.add_child(crew)
	crew.setup(self)
	Party.ship_note.connect(_on_planet_note)


# Nothing on top covers the task list (it starts under the Hud's hint bar and
# segment strip), and the "E: ..." line sits on a dark box so it reads on
# bright sand and white walls.
var prompt_box: PanelContainer


func make_text_readable() -> void:
	var task_panel: PanelContainer = task_list.get_parent()
	task_panel.offset_left = 32
	task_panel.offset_top = 88
	task_panel.offset_right = 32   # shrinks to fit its words (small, in the corner)
	task_panel.offset_bottom = 120
	task_panel.theme_type_variation = &"GlassPanel"
	var middle: Control = prompt_label.get_parent()
	prompt_box = PanelContainer.new()
	prompt_box.theme_type_variation = &"HintPanel"
	prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	middle.add_child(prompt_box)
	middle.move_child(prompt_box, prompt_label.get_index())
	prompt_label.reparent(prompt_box)
	prompt_label.custom_minimum_size.x = 560   # a wrapping label needs a width
	prompt_box.visible = false


# --- Building the area -------------------------------------------------------

func make_environment() -> void:
	var env := Environment.new()
	var sky := Color.html(settings["sky_color"])
	env.background_mode = Environment.BG_COLOR
	env.background_color = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# A black sky (the Moon) would give no ambient light at all, so use gray then.
	env.ambient_light_color = sky if sky.get_luminance() > 0.05 else Color(0.6, 0.6, 0.65)
	if settings["area"] == "ship":
		env.ambient_light_color = Color(1, 1, 1)   # inside the ship: white light, the clouds stay outside
	env.ambient_light_energy = settings["ambient_energy"]
	env.fog_enabled = settings["fog_enabled"]   # the soft haze (Mars), none on the Moon
	env.fog_light_color = sky
	env.fog_density = settings["fog_density"]
	environment_node.environment = env
	sun.light_energy = settings["sun_energy"]


# Ground, lander, rocks, craters and a planet in the sky.
func make_plain() -> void:
	var ground_size: Array = settings["ground_size"]
	make_box(Vector3(ground_size[0], 1.0, ground_size[1]), Vector3(0, -0.5, 0), Color.html(settings["ground_color"]))
	make_lander()
	make_rocks()
	if settings.has("crater_count"):
		make_craters()
	if settings.has("sky_planet"):
		make_sky_planet()
	if settings.has("hills"):
		make_hills()
	if settings.has("stars"):
		make_stars()


# The lander: a solid body (you bump into it) on four legs with round feet,
# a gold foil band and a small dish on top. Sizes from "lander".
func make_lander() -> void:
	var lander: Dictionary = settings["lander"]
	var size := to_vector(lander["size"])
	var base := to_vector(lander["position"])
	var leg_h: float = lander.get("leg_height", 0.0)
	make_box(Vector3(size.x, size.y - leg_h, size.z), base + Vector3(0, leg_h + (size.y - leg_h) / 2.0, 0), Color.html(lander["color"]))
	if not lander.has("foil_color"):
		return
	var parts: Dictionary = Data.game_data["arrival_props"]["lander_parts"]   # leg, foot and dish sizes
	var band := BoxMesh.new()
	band.size = Vector3(size.x * 1.02, parts["band_height"], size.z * 1.02)
	add_mesh(world, band, solid_material(lander["foil_color"]), base + Vector3(0, leg_h + parts["band_above_legs"], 0))
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		# A leg is a thin tube from the foot up to the hip under the body.
		var foot := Vector3(corner.x * size.x * 0.75, 0, corner.y * size.z * 0.75)
		var hip := Vector3(corner.x * size.x * 0.4, leg_h + 0.2, corner.y * size.z * 0.4)
		var leg := CylinderMesh.new()
		leg.top_radius = parts["leg_radius"]
		leg.bottom_radius = parts["leg_radius"]
		leg.height = foot.distance_to(hip)
		var node := add_mesh(world, leg, solid_material(lander["leg_color"]), base + (foot + hip) / 2.0)
		node.basis = Basis(Quaternion(Vector3.UP, (hip - foot).normalized()))
		var pad := CylinderMesh.new()
		pad.top_radius = parts["foot_radius"]
		pad.bottom_radius = parts["foot_radius"]
		pad.height = parts["foot_height"]
		add_mesh(world, pad, solid_material(lander["leg_color"]), base + foot + Vector3(0, parts["foot_height"] / 2.0, 0))
	var dish := CylinderMesh.new()
	dish.top_radius = parts["dish_radius"]
	dish.bottom_radius = parts["dish_radius"] * 0.2
	dish.height = parts["dish_depth"]
	var dish_node := add_mesh(world, dish, solid_material(lander["dish_color"]), base + Vector3(size.x * 0.25, size.y + parts["dish_above_top"], 0))
	dish_node.rotation_degrees.z = parts["dish_tilt_degrees"]


# Big low hills far away, so the ground doesn't end at a sharp edge.
func make_hills() -> void:
	var hills: Dictionary = settings["hills"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hills["seed"])
	var material := solid_material(hills["color"])
	for i in int(hills["count"]):
		var angle: float = TAU * i / float(hills["count"]) + rng.randf_range(-0.2, 0.2)
		var distance: float = rng.randf_range(hills["distance_min"], hills["distance_max"])
		var radius: float = rng.randf_range(hills["size_min"], hills["size_max"])
		var hill := SphereMesh.new()
		hill.radius = radius
		hill.height = radius * 2.0
		hill.radial_segments = 12
		hill.rings = 6
		var node := add_mesh(world, hill, material, Vector3(cos(angle) * distance, 0, sin(angle) * distance))
		node.scale = Vector3(1, rng.randf_range(0.2, 0.45), 1)


# Tiny glowing dots far away in the black sky (the Moon has no air, so the
# stars show even in daylight in the game). One MultiMesh = fast in the browser.
func make_stars() -> void:
	var stars: Dictionary = settings["stars"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(stars["seed"])
	var dot := SphereMesh.new()
	dot.radius = stars["size"]
	dot.height = stars["size"] * 2.0
	dot.radial_segments = 4
	dot.rings = 2
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = dot
	multi.instance_count = int(stars["count"])
	for i in multi.instance_count:
		# A random point on the upper half of a big ball around the player.
		var direction := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.05, 1), rng.randf_range(-1, 1)).normalized()
		multi.set_instance_transform(i, Transform3D(Basis(), direction * stars["distance"]))
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.html(stars["color"])
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = material
	world.add_child(node)


# Props next to a task spot (an analyzer console, an antenna dish...), from
# "spot_props": [{ "spot": ..., "kind": ..., "offset": [x, y, z] }].
# The kinds and their colors are in game_data.json "arrival_props".
func make_spot_props() -> void:
	for prop in settings.get("spot_props", []):
		make_prop(prop["kind"], to_vector(settings["spots"][prop["spot"]]) + to_vector(prop["offset"]))


# A prop that appears when a task is done ("done_props": task id -> kind),
# for example a seismometer standing where the player set it down.
func make_done_prop(task_id: String) -> void:
	var done_props: Dictionary = settings.get("done_props", {})
	if not done_props.has(text_of(task_id)):
		return
	var task: Dictionary = tasks.filter(func(t): return t["id"] == task_id)[0]
	make_prop(done_props[text_of(task_id)], to_vector(settings["spots"][task["spot"]]))


# Builds one prop from its recipe in game_data.json "arrival_props" > "kinds":
# a list of simple shapes. Each shape: "shape" (box, cylinder or sphere),
# "size" (box: [x, y, z]; cylinder: [top radius, bottom radius, height];
# sphere: [radius]), "at" = its middle, in meters from the prop's foot,
# "color" = a color name from arrival_props, "glow" (optional) and
# "turn" (optional, [x, y, z] in degrees).
func make_prop(kind: String, at: Vector3) -> void:
	var props: Dictionary = Data.game_data["arrival_props"]
	for piece in props["kinds"].get(kind, []):
		var mesh: Mesh
		var s: Array = piece["size"]
		match piece["shape"]:
			"box":
				var box := BoxMesh.new()
				box.size = Vector3(s[0], s[1], s[2])
				mesh = box
			"cylinder":
				var tube := CylinderMesh.new()
				tube.top_radius = s[0]
				tube.bottom_radius = s[1]
				tube.height = s[2]
				mesh = tube
			_:
				var ball := SphereMesh.new()
				ball.radius = s[0]
				ball.height = s[0] * 2.0
				mesh = ball
		var material := solid_material(props[piece["color"]], piece.get("glow", 0.0))
		var node := add_mesh(world, mesh, material, at + to_vector(piece["at"]))
		if piece.has("turn"):
			node.rotation_degrees = to_vector(piece["turn"])

const SHIP_BUILDER = preload("res://scripts/ship_builder.gd")
var ship_builder: Node3D   # Venus: the same ship as the flight


# Venus stays on the ship: build the SAME ship as the flight (ShipBuilder,
# game_data.json "ship"), without the flight's station pads; the arrival has
# its own task spots (destinations.json > venus > arrival > spots). The
# clouds are the sky color outside every window.
func make_ship() -> void:
	ship_builder = SHIP_BUILDER.new()
	world.add_child(ship_builder)
	ship_builder.build(false)

# Places that rocks and craters must keep away from: the lander, the start
# and every task spot.
func keep_clear_points() -> Array:
	var points: Array = [to_vector(settings["lander"]["position"]), to_vector(settings["player_start"])]
	for spot_id in settings["spots"]:
		points.append(to_vector(settings["spots"][spot_id]))
	return points


# A random spot on the ground that is not too close to the keep-clear points.
# Gives back Vector3.INF if it could not find one.
func free_spot(rng: RandomNumberGenerator) -> Vector3:
	var spread: float = settings["rock_spread"]
	for attempt in 50:
		var spot := Vector3(rng.randf_range(-spread, spread), 0, rng.randf_range(-spread, spread))
		var too_close := false
		for other in keep_clear_points():
			if spot.distance_to(other) < settings["rock_keep_clear"]:
				too_close = true
		if not too_close:
			return spot
	return Vector3.INF


# Random rocks (the same layout every time, from rock_seed).
func make_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(settings["rock_seed"])
	for i in int(settings["rock_count"]):
		var spot: Vector3 = free_spot(rng)
		if spot == Vector3.INF:
			continue
		var side: float = rng.randf_range(settings["rock_size_min"], settings["rock_size_max"])
		var size := Vector3(side, side * rng.randf_range(0.5, 1.0), side * rng.randf_range(0.7, 1.3))
		make_box(size, spot + Vector3(0, size.y / 2.0, 0), Color.html(settings["rock_color"]))
		if settings.get("round_rocks", false):
			# Swap the box look for a lumpy, faceted stone (the box still blocks you).
			var body: StaticBody3D = world.get_child(world.get_child_count() - 1)
			var stone := SphereMesh.new()
			stone.radius = 0.62
			stone.height = 1.24
			stone.radial_segments = 7
			stone.rings = 4
			var look: MeshInstance3D = body.get_child(0)
			look.mesh = stone
			look.scale = size
			look.rotation.y = rng.randf_range(0, TAU)


# Craters: low flat rings on the ground. You can walk over them.
func make_craters() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(settings["crater_seed"])
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.html(settings["crater_color"])
	material.roughness = 1.0
	for i in int(settings["crater_count"]):
		var spot: Vector3 = free_spot(rng)
		if spot == Vector3.INF:
			continue
		var radius: float = rng.randf_range(settings["crater_size_min"], settings["crater_size_max"])
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = radius
		torus.outer_radius = radius * 1.25
		ring.mesh = torus
		ring.material_override = material
		ring.scale = Vector3(1, 0.25, 1)   # flatten it into a low rim
		ring.position = spot
		world.add_child(ring)


# A glowing planet in the sky (Earth over the Moon).
func make_sky_planet() -> void:
	var info: Dictionary = settings["sky_planet"]
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = info["radius"]
	sphere.height = info["radius"] * 2.0
	ball.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.html(info["color"])
	material.emission_enabled = true
	material.emission = Color.html(info["color"])
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ball.material_override = material
	ball.position = to_vector(info["position"])
	world.add_child(ball)


# A glowing round marker on the floor, and an invisible zone that knows
# when the player stands on it.
func make_spot(spot_id: String) -> void:
	var position_3d := to_vector(settings["spots"][spot_id])
	var radius: float = settings["marker_radius"]
	var color := Color.html(settings["marker_color"])

	var marker := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.06
	marker.mesh = disc
	var glow := StandardMaterial3D.new()
	glow.albedo_color = color
	glow.emission_enabled = true
	glow.emission = color
	glow.emission_energy_multiplier = settings["marker_glow"]
	marker.material_override = glow
	marker.position = position_3d + Vector3(0, 0.03, 0)
	world.add_child(marker)

	var zone := Area3D.new()
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = 3.0
	shape.shape = cylinder
	zone.add_child(shape)
	zone.position = position_3d + Vector3(0, 1.5, 0)
	world.add_child(zone)
	zone.body_entered.connect(_on_spot_entered.bind(spot_id))
	zone.body_exited.connect(_on_spot_exited.bind(spot_id))


func place_player() -> void:
	player.position = to_vector(settings["player_start"])
	player.gravity_scale = settings["gravity_scale"]
	# On the Moon and Mars the camera sits behind the suited character (third
	# person, a SpringArm so it never goes through rocks). Venus stays on the
	# ship, so it is first person like the flight (UPGRADE_PLAN_V2 step 24).
	player.set_first_person(settings["area"] == "ship")
	player.get_node("Head").rotation.x = deg_to_rad(-15)   # look a little down at the ground
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color.html(settings["player_color"])
	player.get_node("Body").material_override = body_material
	make_suit()


# The player's own character (scientist, janitor or student) in a space suit:
# the toy-like person from the intro, a white suit with an orange stripe,
# a backpack and a see-through helmet bubble (game_data.json "suit").
# The gray capsule stays only as the fallback when there is no character scene.
func make_suit() -> void:
	var character: Dictionary = Data.characters.get(GameState.character_id, {})
	if not character.has("scene"):
		return
	var suit: Dictionary = Data.game_data["suit"]
	var person: Node3D = load(character["scene"]).instantiate()
	person.set("body_color", Color.html(suit["color"]))   # before add_child, so it builds once
	person.set("idle_bob", false)
	person.name = "Suit"
	player.add_child(person)
	player.get_node("Body").visible = false
	player.get_node("Visor").visible = false
	person.visible = not player.first_person   # first person (Venus): your own body is hidden

	var top_r: float = person.get("top_r")
	var dome_h: float = person.get("dome_h")
	var rig: Node3D = person.get("rig")
	var head: Node3D = person.get("head")
	var height: float = person.get("height")

	# The stripe around the middle and the backpack.
	var stripe := CylinderMesh.new()
	var middle_r: float = (top_r + float(person.get("bottom_r"))) * 0.5
	stripe.top_radius = middle_r * 1.04
	stripe.bottom_radius = middle_r * 1.04
	stripe.height = 0.08
	add_mesh(rig, stripe, solid_material(suit["trim_color"]), Vector3(0, height * 0.42, 0))
	var pack := BoxMesh.new()
	pack.size = Vector3(top_r * 1.3, height * 0.3, top_r * 0.6)
	add_mesh(rig, pack, solid_material(suit["pack_color"]), Vector3(0, height * 0.55, middle_r + top_r * 0.25))

	# The helmet: a see-through bubble around the head.
	var bubble := SphereMesh.new()
	var bubble_r: float = top_r * suit["helmet_size"]
	bubble.radius = bubble_r
	bubble.height = bubble_r * 2.0
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(Color.html(suit["visor_color"]), suit["visor_alpha"])
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic = 0.3
	add_mesh(head, bubble, glass, Vector3(0, dome_h * 0.45, 0))


# One mesh under a parent, with a material. Looks only (no collision).
func add_mesh(parent: Node3D, mesh: Mesh, material: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	parent.add_child(node)
	node.position = pos
	return node


func solid_material(color: String, glow: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.html(color)
	material.roughness = 0.8
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = Color.html(color)
		material.emission_energy_multiplier = glow
	return material


# A solid box: something to stand on or bump into.
func make_box(size: Vector3, center: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	mesh.material_override = material
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	world.add_child(body)


func to_vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])


# --- Task helpers ---------------------------------------------------------------

func tasks_at(spot_id: String) -> Array:
	return tasks.filter(func(task): return task["spot"] == spot_id)


func instrument_ok(task: Dictionary) -> bool:
	return not task.has("needs_instrument") or GameState.is_instrument_packed(task["needs_instrument"])


# Are all the tasks this one needs done?
func ready_now(task: Dictionary) -> bool:
	for needed in task.get("needs_tasks", []):
		if state[needed] != "done":
			return false
	return true


# The task the player can do right here, right now (not a reach task), or {}.
func current_task() -> Dictionary:
	for task in tasks_at(current_spot):
		if task["type"] != "reach" and state[task["id"]] == "open" and ready_now(task) and instrument_ok(task):
			return task
	return {}


func task_voice(task_id: String, line: String) -> String:
	return voice["tasks"].get(text_of(task_id), {}).get(line, "")


# The task whose words this task uses (UPGRADE_PLAN_V6 C4: drill_2 talks like "drill").
func text_of(task_id: String) -> String:
	for task in tasks:
		if task["id"] == task_id:
			return str(task.get("text_as", task_id))
	return task_id


# The task's line in the list, with its dig site number when it has one.
func task_label(task: Dictionary) -> String:
	var text: String = words["tasks"][mission_key][text_of(task["id"])]
	if task.has("site"):
		text += words["site_suffix"].format({"n": int(task["site"])})
	return text


# A missing instrument: every task that needs it fails, and so does every
# task that needs one of those.
func fail_missing(instrument_id: String) -> void:
	for task in tasks:
		if task.get("needs_instrument", "") == instrument_id and state[task["id"]] == "open":
			state[task["id"]] = "failed"
	var changed := true
	while changed:
		changed = false
		for task in tasks:
			if state[task["id"]] != "open":
				continue
			for needed in task.get("needs_tasks", []):
				if state[needed] == "failed":
					state[task["id"]] = "failed"
					changed = true
					break


# --- Walking onto a spot --------------------------------------------------------

func _on_spot_entered(body: Node3D, spot_id: String) -> void:
	if not body.is_in_group("player"):
		return
	current_spot = spot_id
	AudioManager.play_sfx("station")
	# Reach tasks are done just by standing here.
	for task in tasks_at(spot_id):
		if task["type"] == "reach" and state[task["id"]] == "open" and ready_now(task):
			player_did(task)
	# Discover a missing instrument here: say why the task can't be done.
	for task in tasks_at(spot_id):
		if state[task["id"]] == "open" and not instrument_ok(task):
			fail_missing(task["needs_instrument"])
			Sfx.play("bad")
			inner_voice.say(task_voice(task["id"], "missing"))
			after_task_change()
			return
	# The first time a task with an explanation is ready here, a card explains it
	# before you start (UPGRADE_PLAN_V6 A6: the drill and the ice race).
	var explain: Dictionary = Data.story["arrival_screen"].get("explain", {})
	for task in tasks_at(spot_id):
		if state[task["id"]] == "open" and ready_now(task) and explain.has(text_of(task["id"])) and not explained.has(text_of(task["id"])):
			explained.append(text_of(task["id"]))
			show_explain_card(explain[text_of(task["id"])])
			return
	# The ground radar reading at a dig site, the first time you step on it (C4 survey).
	var survey: Dictionary = Data.story["arrival_screen"].get("survey", {}).get(mission_key, {})
	if survey.has(spot_id) and not surveyed.has(spot_id):
		surveyed.append(spot_id)
		inner_voice.say(survey[spot_id])


var surveyed: Array = []           # dig sites whose radar reading was said


var explained: Array = []          # task ids whose card was shown this run
var explain_layer: CanvasLayer = null


# A paused card in the middle of the screen: a title, a few short lines, "Enter to start".
func show_explain_card(card: Dictionary) -> void:
	explain_layer = CanvasLayer.new()
	explain_layer.layer = 60
	explain_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	explain_layer.add_to_group("frees_mouse")   # the mouse stays free for the button
	add_child(explain_layer)
	var dim := Panel.new()
	dim.theme_type_variation = &"DimBackground"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	explain_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"NavyPanel"
	panel.custom_minimum_size.x = 620
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	var title := Label.new()
	title.theme_type_variation = &"HeadingText"
	title.text = card["title"]
	column.add_child(title)
	for line in card["lines"]:
		var label := Label.new()
		label.theme_type_variation = &"BodyText"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = line
		column.add_child(label)
	if card.has("source"):
		var source := Label.new()
		source.theme_type_variation = &"TinyText"
		source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		source.text = card["source"]
		column.add_child(source)
	# A focused button: Enter (or a click) starts. The layer keeps running while
	# the game is paused, so the button still works.
	var go := Button.new()
	go.text = Data.story["arrival_screen"]["explain_start"]
	go.custom_minimum_size = Vector2(320, 56)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(close_explain_card)
	column.add_child(go)
	get_tree().paused = true
	explain_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	go.call_deferred("grab_focus")
	AudioManager.play_sfx("preview")


var explain_mouse_before: Input.MouseMode = Input.MOUSE_MODE_CAPTURED


func close_explain_card() -> void:
	if explain_layer == null:
		return
	explain_layer.queue_free()
	explain_layer = null
	get_tree().paused = false
	Input.mouse_mode = explain_mouse_before


func _on_spot_exited(body: Node3D, spot_id: String) -> void:
	if body.is_in_group("player") and current_spot == spot_id:
		current_spot = ""
		holding = ""
		drill_meter.visible = false


# --- Doing tasks -----------------------------------------------------------------

func _process(delta: float) -> void:
	update_hold(delta)
	update_send(delta)
	update_prompt()
	prompt_box.visible = prompt_label.text != ""
	update_footprints(delta)
	update_ice(delta)
	update_gravity_line()


# --- The extras (2026-11-14, data/extras.json) -----------------------------------

# Real gravity: the first jump on the Moon or Mars, the inner voice says why it floats.
var gravity_said: bool = false

func update_gravity_line() -> void:
	if gravity_said or player.is_on_floor() or player.velocity.y <= 0.0:
		return
	gravity_said = true
	var line: String = Data.voice["extras"].get("gravity_" + mission_key, "")
	if line != "":
		inner_voice.say(line)


# Footprints: a print every few steps. On the Moon they stay forever (no wind);
# on Mars they shrink away (the wind covers them). Not inside the Venus ship.
var prints: Array = []            # { "node", "age" }
var last_print_at := Vector3.INF
var print_side: float = 1.0
var print_material: StandardMaterial3D
var footprint_line_said: bool = false

func update_footprints(delta: float) -> void:
	if settings["area"] != "plain":
		return
	var info: Dictionary = Data.extras["footprints"]
	var life: float = float(info["life_seconds"].get(mission_key, 0))
	if life > 0.0:
		for i in range(prints.size() - 1, -1, -1):
			var p: Dictionary = prints[i]
			p["age"] += delta
			var share: float = 1.0 - p["age"] / life
			if share <= 0.0:
				p["node"].queue_free()
				prints.remove_at(i)
			else:
				p["node"].scale = Vector3(share, 1.0, share)
	if not player.is_on_floor():
		return
	var here: Vector3 = player.global_position
	here.y = 0.0
	if last_print_at == Vector3.INF:
		last_print_at = here
		return
	var walked: Vector3 = here - last_print_at
	if walked.length() < float(info["spacing_meters"]):
		return
	last_print_at = here
	if print_material == null:
		print_material = StandardMaterial3D.new()
		print_material.albedo_color = Color.html(settings["ground_color"]).darkened(float(info["color_darken"]))
		print_material.roughness = 1.0
	var size: Array = info["size"]
	var box := BoxMesh.new()
	box.size = Vector3(size[0], 0.01, size[1])
	var heading: float = atan2(walked.x, walked.z)
	var side := Vector3(cos(heading), 0, -sin(heading)) * 0.12 * print_side
	print_side = -print_side
	var node := add_mesh(world, box, print_material, here + side + Vector3(0, 0.006, 0))
	node.rotation.y = heading
	prints.append({"node": node, "age": 0.0})
	if prints.size() > int(info["max_prints"]):
		prints.pop_front()["node"].queue_free()
	if not footprint_line_said and prints.size() == 30:
		footprint_line_said = true
		var line: String = Data.voice["extras"].get("footprints_" + mission_key, "")
		if line != "":
			inner_voice.say(line)


# Race the ice (Mars): after the drill, the sample turns to gas. It floats by
# the player and shrinks; the analyzer sends data for the share that is left.
var ice_left: float = -1.0        # seconds left (-1 = no ice yet)
var ice_cube: MeshInstance3D
var ice_locked: bool = false      # true once the analyzer has started

func start_ice(in_my_hands: bool = true) -> void:
	var info: Dictionary = Data.extras["ice_race"]
	ice_left = float(info["vanish_seconds"])
	ice_locked = false   # a new sample: the race starts again (C4)
	GameState.ice_share = 1.0
	if not in_my_hands:
		return   # a teammate drilled it: the timer runs, the cube is in their hands
	var cube := BoxMesh.new()
	var s: float = info["carry_size"]
	cube.size = Vector3(s, s, s)
	ice_cube = add_mesh(player, cube, solid_material(Data.game_data["arrival_props"]["ice"], 0.6), to_vector(info["carry_offset"]))
	inner_voice.say(Data.voice["extras"]["ice_start"])


func ice_share_now() -> float:
	var info: Dictionary = Data.extras["ice_race"]
	return maxf(ice_left / float(info["vanish_seconds"]), float(info["min_share"]))


func update_ice(delta: float) -> void:
	if ice_left < 0.0 or ice_locked:
		return
	ice_left = maxf(ice_left - delta, 0.0)
	if ice_cube != null:
		ice_cube.scale = Vector3.ONE * maxf(ice_left / float(Data.extras["ice_race"]["vanish_seconds"]), 0.05)
		ice_cube.rotation.y += delta


# Signal delay: the real radio wait from this place, pointed out (not waited).
func signal_delay_line() -> String:
	var minutes: float = float(GameState.get_destination()["signal_delay_minutes"]["end"])
	var words_delay: Dictionary = Data.story["extras"]["signal_delay"]
	var delay: String
	if minutes < 1.0:
		delay = words_delay["seconds"].format({"value": GameState.fmt(snappedf(minutes * 60.0, 0.1))})
	else:
		delay = words_delay["minutes"].format({"value": GameState.fmt(roundf(minutes))})
	return Data.voice["extras"]["signal_delay"].format({"planet": planet, "delay": delay})


# Hold E: the bar fills. Let go in the green zone. A full bar is too far.
func update_hold(delta: float) -> void:
	var task: Dictionary = current_task()
	if task.is_empty() or task["type"] != "hold":
		return
	if Input.is_action_pressed("interact"):
		if holding != task["id"]:
			holding = task["id"]
			hold_value = 0.0
			drill_meter.setup(task["green_start"], task["green_end"])
			drill_meter.visible = true
		hold_value += delta / task["fill_seconds"]
		drill_meter.set_value(hold_value)
		if hold_value >= 1.0:
			let_go(task)   # went all the way: too far
	elif holding == task["id"]:
		let_go(task)


func let_go(task: Dictionary) -> void:
	holding = ""
	GameState.drill_tries += 1
	if hold_value >= task["green_start"] and hold_value <= task["green_end"]:
		drill_meter.visible = false
		player_did(task)
	elif hold_value < task["green_start"]:
		inner_voice.say(task_voice(task["id"], "early"))
	else:
		inner_voice.say(task_voice(task["id"], "late"))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and sending == "":
		var task: Dictionary = current_task()
		if not task.is_empty():
			if task["type"] == "press":
				player_did(task)
			elif task["type"] == "send":
				start_send(task)
	# Enter (the "confirm" key) leaves once every task is done or can't be done.
	if leaving_allowed and event.is_action_pressed("confirm"):
		leave()


# Sending takes longer with a weaker signal: base_seconds at the mission's
# communications limit, longer below it (and after the "weak radio" flight
# event), at most max_seconds.
func start_send(task: Dictionary) -> void:
	var send: Dictionary = settings["send"]
	var signal_now: float = maxf(GameState.get_flight_values()["communications"], 0.001)
	var needed: float = GameState.get_limits()["communications"]["value"]
	var slow_down: float = maxf(needed / signal_now, 1.0) / maxf(GameState.data_rate_factor, 0.01)
	send_seconds = minf(send["base_seconds"] * slow_down, send["max_seconds"])
	send_time = 0.0
	sending = task["id"]
	send_bar.value = 0.0
	send_bar.visible = true
	var line: String = task_voice(task["id"], "start")
	if slow_down > 1.0:
		line += " " + voice["slow_send"]
	line += " " + signal_delay_line()   # the real radio wait, pointed out (extras)
	# The ice race ends here: what is left of the sample now is what gets analyzed.
	if text_of(task["id"]) == Data.extras["ice_race"]["send_task"] and ice_left >= 0.0:
		ice_locked = true
		GameState.ice_share = ice_share_now()
		var ice_key: String = "ice_gone" if ice_left <= 0.0 else "ice_share"
		line = Data.voice["extras"][ice_key].format({"percent": int(round(GameState.ice_share * 100.0))}) + " " + line
	inner_voice.say(line.strip_edges())


func update_send(delta: float) -> void:
	if sending == "":
		return
	send_time += delta
	send_bar.value = send_time / send_seconds
	if send_time >= send_seconds:
		var task: Dictionary = tasks.filter(func(t): return t["id"] == sending)[0]
		sending = ""
		send_bar.visible = false
		var share: float = GameState.ice_share if text_of(task["id"]) == Data.extras["ice_race"]["send_task"] else 1.0
		if share < 1.0 and ice_cube != null:
			ice_cube.queue_free()
			ice_cube = null
		player_did(task)


# mine = I did it here (my voice line, the ice cube in my hands); otherwise a
# teammate did it and a short flash says who.
func finish_task(task: Dictionary, mine: bool = true, who: String = "") -> void:
	state[task["id"]] = "done"
	make_done_prop(task["id"])
	Sfx.play("good")
	var line: String = task_voice(task["id"], "ok")
	if mine and line != "":
		inner_voice.say(line)
	elif not mine and who != "":
		Hud.flash(Data.story["party"]["planet_did"].format({"name": who, "task": task_label(task)}))
	if text_of(task["id"]) == Data.extras["ice_race"]["after_task"]:
		start_ice(mine)   # Race the ice: the sample starts turning to gas
	elif text_of(task["id"]) == Data.extras["ice_race"]["send_task"]:
		if ice_cube != null:
			ice_cube.queue_free()
			ice_cube = null
		ice_left = -1.0   # ready for the next sample (C4: three samples, one at a time)
		GameState.ice_samples += 1
		if GameState.ice_samples >= 3:
			Achievements.unlock("three_ice")
	after_task_change()


# The line in the middle of the screen: what you can do right here.
func update_prompt() -> void:
	var prompts: Dictionary = words["prompts"]
	if sending != "":
		prompt_label.text = prompts["sending"].format({"percent": int(send_bar.value * 100.0)})
		return
	if current_spot == "":
		prompt_label.text = prompts["leave"].format({"planet": planet}) if leaving_allowed else ""
		return
	var mission_prompts: Dictionary = prompts[mission_key]
	var here: Array = tasks_at(current_spot)
	var text: String = ""
	var task: Dictionary = current_task()
	if not task.is_empty():
		text = mission_prompts[text_of(task["id"])].get("do", "")
	else:
		# Nothing to do here: say why (failed, waiting for another task, or done).
		for kind in [["failed", "missing"], ["open", "waiting"], ["done", "done"]]:
			for other in here:
				if text == "" and state[other["id"]] == kind[0]:
					text = mission_prompts.get(text_of(other["id"]), {}).get(kind[1], "")
	prompt_label.text = text


# Tick the checklist, redraw the lists, and check whether we can leave.
func after_task_change() -> void:
	var goal_tasks: Dictionary = settings["goals"]
	for goal_id in goal_tasks:
		if goal_tasks[goal_id] is Array:
			var done_count: int = 0
			for task_id in goal_tasks[goal_id]:
				if state[task_id] == "done":
					done_count += 1
			# The share done counts in the report, even if the goal is not finished.
			GameState.goal_progress[goal_id] = float(done_count) / goal_tasks[goal_id].size()
			if done_count == goal_tasks[goal_id].size():
				GameState.goals[goal_id] = "done"
	refresh_task_list()

	if not leaving_allowed and not state.values().has("open"):
		leaving_allowed = true
		if state.values().has("failed"):
			inner_voice.say(inner_voice.line_label.text + " " + voice["cant_finish"])
		else:
			inner_voice.say(voice["all_done"])


# The task list and the mission checklist, top left.
func refresh_task_list() -> void:
	for old in task_list.get_children():
		old.queue_free()
	var marks: Dictionary = words["marks"]
	add_list_line(words["tasks_title"], &"AccentText")
	# Mars (C4): only the dig site you are on now, and "Ice samples: 1 of 3".
	var site_now: int = current_site()
	var sites: int = tasks.filter(func(t): return t.has("site")).map(func(t): return int(t["site"])).reduce(func(a, b): return maxi(a, b), 0)
	if sites > 0:
		add_list_line(words["samples_line"].format({"n": GameState.ice_samples, "total": sites}), &"BodyText")
	for task in tasks:
		if task.has("site") and int(task["site"]) != site_now:
			continue
		var line := add_list_line(marks[state[task["id"]]] + " " + task_label(task), &"BodyText")
		if state[task["id"]] == "done":
			line.modulate.a = 0.55   # finished tasks get quieter (UI_POLISH_PLAN_V4 Step 3a)
	# The mission checklist as ONE quiet line: "Mission checklist · 3 of 8 done".
	# The items themselves are on the tablet (Tab) and the report; on screen
	# they repeated the task list (UI_POLISH_PLAN_V4 Step 3a: small until you ask).
	add_list_line(words["checklist_title"] + " · " + GameState.checklist_progress_text(), &"TinyText")


# The first dig site that still has an open task (0 = no sites, or all done: show the last).
func current_site() -> int:
	var last: int = 0
	for task in tasks:
		if task.has("site"):
			last = int(task["site"])
			if state[task["id"]] == "open":
				return last
	return last


func add_list_line(text: String, style: StringName) -> Label:
	var line := Label.new()
	line.text = text
	line.theme_type_variation = style
	task_list.add_child(line)
	return line


# Leave: every goal not done becomes a finding. If a missing instrument
# caused it, that instrument's finding explains it.
func leave() -> void:
	leaving_allowed = false
	var reasons: Dictionary = {}
	var goal_tasks: Dictionary = settings["goals"]
	for goal_id in goal_tasks:
		if not goal_tasks[goal_id] is Array:
			continue
		var finding: String = missing_finding_for(goal_tasks[goal_id])
		if finding != "":
			reasons[goal_id] = finding
	GameState.finish_arrival(reasons)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # the report needs the mouse
	StageManager.go_next()


# --- The shared planet (2026-11-15) ---------------------------------------------
# The whole party walks ONE planet and works on ONE task list. Online, the party
# leader's game owns it: it counts every finished task (and the data it sends
# home), moves the bots, and sends the planet state 5 times a second. The others
# show that state and tell the leader when they finish a task ("planet_do").
# A bots party is one computer, like a leader. Solo: nothing here changes anything.

const PLANET_CREW = preload("res://scripts/planet_crew.gd")

var crew: Node3D                  # planet_crew.gd: teammates and the bots' jobs
var room_rects: Dictionary = {}   # Venus (on the ship): the rooms, so bots find the doors


func is_client() -> bool:
	return Party.is_online() and not Party.is_leader()


func to_rect(box: Dictionary) -> Rect2:
	return ship_builder.to_rect(box)


func task_by_id(task_id: String) -> Dictionary:
	for task in tasks:
		if task["id"] == task_id:
			return task
	return {}


# The data a finished send task sends home (less when the Mars ice melted).
func credit_send(task: Dictionary, seat: int) -> void:
	if task["type"] != "send":
		return
	var share: float = 1.0
	if text_of(task["id"]) == Data.extras["ice_race"]["send_task"] and ice_left >= 0.0:
		share = GameState.ice_share if ice_locked else ice_share_now()
	var gb: float = float(task.get("data_gb", 0.0)) * share
	GameState.data_sent += gb   # the data counts in the report
	if seat != Party.my_seat:
		Party.note_bot_data(seat, gb)   # on that teammate's report line, not mine


# I finished a task here.
func player_did(task: Dictionary) -> void:
	if is_client():
		Net.send({"t": "planet_do", "id": task["id"]}, Party.LEADER)
		finish_task(task)   # shows at once; the leader's planet counts it for everyone
		return
	credit_send(task, Party.my_seat)
	finish_task(task)


# Leader / bots party: a bot or another player finished a task.
func bot_did(task_id: String, seat: int) -> void:
	var task: Dictionary = task_by_id(task_id)
	if task.is_empty() or state[task_id] != "open" or not ready_now(task):
		return
	credit_send(task, seat)
	finish_task(task, false, Party.seat_name(seat))


# Leader / bots party: a bot walked to a task whose instrument we did not pack.
# The same as a player finding out: those tasks fail, and the team is told why.
func bot_found_missing(task: Dictionary, seat: int) -> void:
	if task.is_empty() or state[task["id"]] != "open" or instrument_ok(task):
		return
	fail_missing(task["needs_instrument"])
	Sfx.play("bad")
	Hud.flash(Data.story["party"]["planet_missing"].format({"name": Party.seat_name(seat), "task": task_label(task)}))
	after_task_change()


func shared_state() -> Dictionary:
	return {
		"t": "planet", "state": state, "data": GameState.data_sent, "samples": GameState.ice_samples,
		"ice_left": ice_left, "bots": crew.bot_positions(),
	}


func _on_planet_note(from_seat: int, data: Dictionary) -> void:
	if not is_inside_tree():
		return
	var t: String = str(data.get("t", ""))
	if t == "pos":
		var p: Array = data.get("p", [0, 0, 0])
		crew.set_target(from_seat, Vector3(float(p[0]), float(p[1]), float(p[2])), float(data.get("y", 0.0)))
	elif t == "planet_do" and Party.is_leader():
		bot_did(str(data["id"]), from_seat)
	elif t == "planet" and from_seat == Party.LEADER and not Party.is_leader():
		apply_planet_state(data)


# Client: show the leader's planet. A task done here never goes back to open.
func apply_planet_state(data: Dictionary) -> void:
	var new_state: Dictionary = data.get("state", {})
	var changed: bool = false
	for task_id in new_state:
		if not state.has(task_id) or state[task_id] == "done" or state[task_id] == new_state[task_id]:
			continue
		state[task_id] = str(new_state[task_id])
		changed = true
		if state[task_id] == "done":
			make_done_prop(task_id)
	GameState.data_sent = float(data.get("data", GameState.data_sent))
	GameState.ice_samples = int(data.get("samples", GameState.ice_samples))
	if ice_cube == null:
		ice_left = float(data.get("ice_left", ice_left))   # the ice timer of a teammate's sample
	crew.apply_bot_positions(data.get("bots", {}))
	if changed:
		after_task_change()


# --- The Hud (Tab tablet, waypoints, goal; UPGRADE_PLAN_V2 steps 22-24) ---------

# Tasks the player can walk to now (open, ready, instrument packed).
func open_spots() -> Array:
	var points: Array = []
	var seen: Array = []
	for task in tasks:
		if state[task["id"]] != "open" or not ready_now(task) or seen.has(task["spot"]):
			continue
		seen.append(task["spot"])
		points.append({"pos": to_vector(settings["spots"][task["spot"]]), "label": task_label(task), "urgent": false})
	return points


func get_tablet_map() -> Dictionary:
	var rooms: Array = []
	if ship_builder != null:
		for room_id in ship_builder.room_rects:
			rooms.append({"name": Data.story["ship"]["room_names"][room_id], "rect": ship_builder.room_rects[room_id]})
		rooms.append({"name": "", "rect": ship_builder.to_rect(Data.game_data["ship"]["hallway"])})
	var points: Array = open_spots()
	if crew != null:
		for seat in crew.avatars:
			points.append({"pos": crew.avatars[seat]["node"].global_position, "label": Party.seat_name(seat), "urgent": false})
	return {"player": player.global_position, "yaw": player.rotation.y, "rooms": rooms, "points": points}


func get_waypoints() -> Array:
	return open_spots()


func get_hud_timers() -> Array:
	var timers: Array = []
	if ice_left > 0.0 and not ice_locked:
		timers.append({"label": Data.story["extras"]["ice_race"]["timer"], "seconds": ice_left})
	if sending != "":
		timers.append({"label": words["prompts"]["sending"].format({"percent": int(send_bar.value * 100.0)}), "seconds": send_seconds - send_time})
	return timers


# The Q card (UPGRADE_PLAN_V3 A2): on a task spot, that task's word (a send
# task = downlink, a task that needs an instrument = instrument); anywhere
# else, the planet itself.
func get_question_id() -> String:
	if current_spot != "":
		for task in tasks_at(current_spot):
			if task.has("question"):
				return task["question"]
			if task["type"] == "send":
				return "downlink"
			if task.has("needs_instrument"):
				return "instrument"
	return mission_key


func get_goal_text() -> String:
	var spots: Array = open_spots()
	if spots.is_empty():
		return words["prompts"]["leave"].format({"planet": planet}) if leaving_allowed else ""
	return spots[0]["label"]


# For a goal's tasks: if one failed because an instrument was missing (or
# needs a task that did), give back that instrument's finding id.
func missing_finding_for(task_ids: Array) -> String:
	var to_check: Array = task_ids.duplicate()
	var seen: Array = []
	while not to_check.is_empty():
		var task_id: String = to_check.pop_front()
		if seen.has(task_id):
			continue
		seen.append(task_id)
		var task: Dictionary = tasks.filter(func(t): return t["id"] == task_id)[0]
		if state[task_id] == "failed" and task.has("missing_finding") and not instrument_ok(task):
			return task["missing_finding"]
		to_check.append_array(task.get("needs_tasks", []))
	return ""
