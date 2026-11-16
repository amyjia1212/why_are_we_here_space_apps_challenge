# choice_room.gd
# The 3D Choice Room (UPGRADE_PLAN_V2 steps 13-14). Every selection in the
# game uses this one room; it builds itself from the data files.
#   room_kind = "character": the three characters stand on the pedestals
#   room_kind = "mission":   three planet globes
#   room_kind = "design":    rocket -> orbit -> the 7 spacecraft parts -> instruments
#
# How it plays:
#   - walk around (and jump) in a small room
#   - each pedestal holds one option with its name and cost floating above
#   - walk up and press E (or click, or press 1/2/3) to PREVIEW. Nothing is final yet.
#   - the wall screen shows the choice: the option cards (the previewed one lit),
#     the six resources before -> after, the ripple effect and any red blockers
#   - the model on the display stand shows the rocket or the spacecraft with the
#     previewed part glowing and labeled (Inside view for the parts inside)
#   - press E on the CONFIRM console (or Enter) to lock it in. The next choice loads.
#   - Backspace goes back one choice (Q asks a question, UPGRADE_PLAN_V3 A2).
#     Instruments switch on and off (pack as many as you like).
# Numbers: game_data.json "choice_room". Words: story.json "choice_room".
extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const BAR_SCENE := preload("res://scenes/inner_voice_bar.tscn")
const PROMPT_BOX = preload("res://scripts/prompt_box.gd")
const UI = preload("res://scripts/ui_kit.gd")
const PLANET_LOOK = preload("res://scripts/planet_look.gd")
const FIXED_LABEL_PIXEL := 0.0006   # pedestal labels keep one size on screen (about 16 pixels a line, UI_POLISH_PLAN_V4)

@export var room_kind: String = "design"

var settings: Dictionary
var words: Dictionary
var categories: Array = []
var cat_index: int = 0
var options: Array = []
var blocked: Array = []          # options that cannot work for this mission: { "name", "reason" } (N4)
var snapshot = null              # the confirmed value of this category (to compare and to undo)
var first_value = null           # the value when this category loaded (CML 3: did the player change it?)
var before_totals: Dictionary = {}
var previewed: bool = false
var pedestals: Array = []        # { "root", "area", "id", "ring", "label" }
var near_pedestal: int = -1
var near_console: bool = false
var busy: bool = false           # true during the "You're hired" moment or while leaving

var player: CharacterBody3D
var console: Node3D
var console_tag: Label3D
var display: Node3D
var display_model: Node3D
var general: Node3D
var wall_viewport: SubViewport
var wall_root: Control
var wall_cards: Array = []            # the option cards on the wall (same order as the pedestals)
var last_wall_totals: Dictionary = {} # the numbers at the last wall refresh (for count-up and the change marks)
var prompt_label: Label
var previous_button: Button   # Design Lab only: back one station (shown from the 2nd station on)
var confirm_mark: Label       # "Press ENTER to confirm" watermark once something is picked
var confirm_pill: PanelContainer   # the dark see-through box behind it
var inner_voice: PanelContainer
var hired_camera: Camera3D
var hired_target: Vector3


func _ready() -> void:
	settings = Data.game_data["choice_room"]
	words = Data.story["choice_room"]
	if room_kind != "character" and GameState.character_id == "":
		GameState.character_id = Data.game_data["setup"]["default_character"]
	if room_kind == "design" and GameState.mission_id == "":
		GameState.mission_id = Data.missions.keys()[0]
	match room_kind:
		"character":
			categories = ["character"]
		"mission":
			categories = ["mission"]
		_:
			# launch_window = the launch date station (extras, 2026-11-14).
			categories = ["rocket", "orbit", "launch_window"] + Data.parts.keys() + ["instruments"]
			GameState.fill_default_choices()
			if GameState.launch_vehicle_id == "":
				GameState.launch_vehicle_id = GameState.get_launch_vehicle_id()
			if GameState.orbit_id == "":
				GameState.orbit_id = GameState.get_orbit_id()
	build_room()
	build_wall()
	build_ui()
	if party_votes():
		build_vote_ui()
	spawn_player()
	# Toy-like staff walk along the sides of the room and wave (step 27).
	Bots.spawn_walkers(self, settings.get("bot_routes", []))
	if room_kind == "character":
		build_achievement_board()
		general = load(Data.game_data["portraits"]["list"]["general"]).instantiate()
		add_child(general)
		general.position = MeshKit.vec3(settings["general_position"])
		general.rotation.y = deg_to_rad(150)
	# UPGRADE_PLAN_V6 B3: a guided retry (Scientist) that forgot a key instrument
	# opens straight at the instruments station.
	var start: int = 0
	if room_kind == "design" and GameState.retry_mode == "guided" and not GameState.last_attempt.get("missing_key", []).is_empty():
		start = maxi(categories.find("instruments"), 0)
	load_category(start)


# ---------- building the room ----------

func build_room() -> void:
	var size: Array = settings["room_size"]
	var w: float = size[0]
	var d: float = size[1]
	var h: float = settings["wall_height"]
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.07, 0.12)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.85, 0.88, 0.95)
	environment.ambient_light_energy = 0.65   # a little brighter (Holden: "better lighting", 2026-11-15)
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 30, 0)
	sun.light_energy = 0.5
	add_child(sun)

	var wall_color := Color(settings["wall_color"])
	solid_box(Vector3(w, 0.2, d), Vector3(0, -0.1, 0), Color(settings["floor_color"]))
	solid_box(Vector3(w, 0.2, d), Vector3(0, h + 0.1, 0), wall_color.darkened(0.2))
	solid_box(Vector3(w, h, 0.3), Vector3(0, h / 2.0, -d / 2.0), wall_color)
	solid_box(Vector3(w, h, 0.3), Vector3(0, h / 2.0, d / 2.0), wall_color)
	solid_box(Vector3(0.3, h, d), Vector3(-w / 2.0, h / 2.0, 0), wall_color)
	solid_box(Vector3(0.3, h, d), Vector3(w / 2.0, h / 2.0, 0), wall_color)
	# Orange and cyan accent stripes along the walls.
	var stripe := Color(settings["stripe_color"])
	var accent := Color(settings["accent_color"])
	for z in [-d / 2.0 + 0.16, d / 2.0 - 0.16]:
		MeshKit.box(self, Vector3(w, 0.18, 0.04), Vector3(0, 1.0, z), stripe)
	for x in [-w / 2.0 + 0.16, w / 2.0 - 0.16]:
		MeshKit.box(self, Vector3(0.04, 0.18, d), Vector3(x, 1.0, 0), stripe)
	MeshKit.add(self, plane(w - 1.0, 0.08), Vector3(0, 0.02, float(settings["pedestal_z"]) + 1.3), MeshKit.glow(accent, 1.2))
	# Ceiling lights: three across (the room is wide now), two deep.
	for x in [-w / 3.0, 0.0, w / 3.0]:
		for z in [-d / 4.0, d / 4.0]:
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(x, h - 0.6, z)
			lamp.omni_range = 12.0
			lamp.light_energy = 0.8
			lamp.shadow_enabled = false
			add_child(lamp)
			MeshKit.add(self, plane(1.6, 0.5), Vector3(x, h - 0.02, z), MeshKit.glow(Color(1, 0.98, 0.9), 1.5)).rotation.x = PI
	build_observation()
	# (ROOM_LAYOUT_PLAN_V5 Step 4: no 3D room title any more; the room's name is
	# small text in the top-left HUD, next to the portrait. See build_ui.)

	# The chosen thing FLOATS, big and detailed, over the hologram in the middle
	# of the observation area (Holden, 2026-11-15). It turns and bobs (_process).
	display = Node3D.new()
	display.position = MeshKit.vec3(settings["display_position"])
	add_child(display)

	# The CONFIRM console in the middle.
	console = Node3D.new()
	console.position = MeshKit.vec3(settings["console_position"])
	add_child(console)
	# Low (0.85 m), so it never hides a nameplate from the start spot (V5).
	solid_box(Vector3(1.2, 0.85, 0.7), console.position + Vector3(0, 0.425, 0), Color(settings["console_color"]))
	var button := MeshKit.cylinder(console, 0.24, 0.28, 0.1, Vector3(0, 0.9, 0), Color(0.2, 0.9, 0.4), 20)
	button.material_override = MeshKit.glow(Color(0.2, 0.9, 0.4), 1.6)
	# Low (below eye level), so it never covers the wall screen; it hides while
	# you stand at the console (the prompt at the bottom says it then).
	console_tag = MeshKit.label(console, words["console_label"], Vector3(0, 1.35, 0), 0.005, Color(0.4, 1.0, 0.6))
	console_tag.visible = false   # V5 Step 2: no floating CONFIRM text; the hint bar says Enter
	console.add_child(make_area(Vector3.ZERO, "console"))


# The observation area in the middle third (Holden, 2026-11-15): a round
# holographic emitter on the floor lights the floating model from below with a
# soft beam; a low railing keeps you out (you look, you don't walk in). A
# spotlight from the ceiling and a cyan glow light the model.
# Numbers: game_data.json choice_room > observation.
func build_observation() -> void:
	var info: Dictionary = settings["observation"]
	var spot: Vector3 = MeshKit.vec3(settings["display_position"])
	spot.y = 0.0
	var accent := Color(settings["accent_color"])
	var r: float = float(info["radius"])
	# The emitter: a dark disc, a glowing ring and a glowing face.
	MeshKit.cylinder(self, r, r * 1.05, 0.12, spot + Vector3(0, 0.06, 0), Color(settings["console_color"]), 40)
	MeshKit.add(self, ring_mesh(r * 0.86, r * 0.98), spot + Vector3(0, 0.13, 0), MeshKit.glow(accent, 2.5))
	MeshKit.add(self, ring_mesh(r * 0.45, r * 0.52), spot + Vector3(0, 0.13, 0), MeshKit.glow(accent, 2.0))
	# The beam: a see-through cyan cone up to the model.
	var beam := CylinderMesh.new()
	beam.bottom_radius = r * 0.9
	beam.top_radius = r * 1.15
	beam.height = float(info["beam_height"])
	beam.cap_top = false
	beam.cap_bottom = false
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_mat.albedo_color = Color(accent, float(info["beam_alpha"]))
	MeshKit.add(self, beam, spot + Vector3(0, 0.13 + beam.height / 2.0, 0), beam_mat)
	var glow := OmniLight3D.new()
	glow.light_color = accent
	glow.light_energy = 1.2
	glow.omni_range = r * 3.0
	glow.shadow_enabled = false
	glow.position = spot + Vector3(0, 0.6, 0)
	add_child(glow)
	var key_light := SpotLight3D.new()
	key_light.light_energy = float(info["spot_energy"])
	key_light.spot_range = 9.0
	key_light.spot_angle = 22.0
	key_light.shadow_enabled = false
	key_light.position = MeshKit.vec3(settings["display_position"]) + Vector3(0, 4.0, 2.0)
	add_child(key_light)
	key_light.look_at(MeshKit.vec3(settings["display_position"]), Vector3.UP)
	# The railing: posts and a top rail in a ring; solid, so nobody walks in.
	var rail_r: float = float(info["rail_radius"])
	var rail_h: float = float(info["rail_height"])
	var rail_color := Color(0.85, 0.87, 0.9)
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = rail_color
	rail_mat.metallic = 0.4
	MeshKit.add(self, ring_mesh(rail_r - 0.04, rail_r + 0.04), spot + Vector3(0, rail_h, 0), rail_mat)
	for i in 12:
		var angle: float = TAU * i / 12.0
		MeshKit.box(self, Vector3(0.06, rail_h, 0.06), spot + Vector3(cos(angle) * rail_r, rail_h / 2.0, sin(angle) * rail_r), rail_color)
	var body := StaticBody3D.new()
	body.position = spot + Vector3(0, rail_h / 2.0, 0)
	add_child(body)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = rail_r
	cyl.height = rail_h
	shape.shape = cyl
	body.add_child(shape)


func box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func solid_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	add_child(body)
	MeshKit.box(body, size, Vector3.ZERO, color)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)


func plane(width: float, depth: float) -> PlaneMesh:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(width, depth)
	return mesh


func ring_mesh(inner: float, outer: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 6
	return mesh


# An invisible zone: when the player stands inside, E works on that thing.
func make_area(pos: Vector3, tag: String) -> Area3D:
	var area := Area3D.new()
	area.position = pos
	var shape := CollisionShape3D.new()
	var sphere := CylinderShape3D.new()
	sphere.radius = settings["reach"]
	sphere.height = 3.0
	shape.shape = sphere
	shape.position.y = 1.5
	area.add_child(shape)
	area.set_meta("tag", tag)
	area.body_entered.connect(_on_area_entered.bind(area))
	area.body_exited.connect(_on_area_exited.bind(area))
	return area


# ---------- the wall screen ----------

# ROOM_LAYOUT_PLAN_V5 Step 1: two screens, one on each side, closer to the
# player than the pedestals and turned toward the start spot. Left = "This
# choice" (wall_viewport / wall_root), right = "Your mission" (right_viewport /
# right_root). The back wall stays plain behind the models.
var right_viewport: SubViewport
var right_root: Control
var float_time: float = 0.0   # for the floating spacecraft's bob


func build_wall() -> void:
	var info: Dictionary = settings["side_screens"]
	var left: Array = make_side_screen(info, -1.0)
	wall_viewport = left[0]
	wall_root = left[1]
	var right: Array = make_side_screen(info, 1.0)
	right_viewport = right[0]
	right_root = right[1]


# One screen: a SubViewport drawn on a quad, in a warm-white bezel and navy
# frame on a post, turned angle_degrees toward the middle. side = -1 left, +1 right.
func make_side_screen(info: Dictionary, side: float) -> Array:
	var pixels: Array = info["pixels"]
	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(pixels[0]), int(pixels[1]))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	viewport.transparent_bg = false
	add_child(viewport)
	var ui_root := Control.new()
	ui_root.size = Vector2(pixels[0], pixels[1])
	ui_root.theme = UI.wall_theme(float(info["ui_scale"]))   # big text: read from the start spot
	viewport.add_child(ui_root)

	# Flat on the BACK wall: the left third and the right third (Holden,
	# 2026-11-15). The middle third is the observation area. x = the middle of
	# each screen (DEFAULT: one third of the room's width from the center).
	var size: Array = info["size"]
	var wall_z: float = -float(settings["room_size"][1]) / 2.0 + 0.15 + 0.06   # just in front of the wall's surface
	var holder := Node3D.new()
	holder.position = Vector3(side * float(info.get("x", float(settings["room_size"][0]) / 3.0)), float(info["height"]), wall_z)
	add_child(holder)
	var quad := QuadMesh.new()
	quad.size = Vector2(size[0], size[1])
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = viewport.get_texture()
	MeshKit.add(holder, quad, Vector3(0, 0, 0.03), mat)
	MeshKit.box(holder, Vector3(float(size[0]) + 0.16, float(size[1]) + 0.16, 0.04), Vector3.ZERO, Color(settings["console_color"]))
	return [viewport, ui_root]


func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	# The "E: ..." line: on a dark box, above the voice bar (prompt_box.gd).
	var box = PROMPT_BOX.new()
	layer.add_child(box)
	prompt_label = box.label
	inner_voice = BAR_SCENE.instantiate()
	layer.add_child(inner_voice)
	# The room's name: small text at the top left, next to the Hud's portrait
	# (ROOM_LAYOUT_PLAN_V5 Step 4; it was 3D text that hit the hint bar).
	var name_chip := PanelContainer.new()
	name_chip.theme_type_variation = &"HintPanel"
	name_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_chip.position = Vector2(12 + float(Data.game_data["hud"]["portrait_size"]) + 12, 16)
	layer.add_child(name_chip)
	var name_label := Label.new()
	name_label.theme_type_variation = &"AccentText"
	name_label.text = words["room_names"][room_kind]
	name_chip.add_child(name_label)
	# The confirm watermark (2026-11-15 team note): once something is picked, a big
	# see-through "Press ENTER to confirm" sits just under the middle of the screen.
	# On a dark see-through pill so it reads on the white walls too.
	confirm_pill = PanelContainer.new()
	confirm_pill.theme_type_variation = &"HintPanel"
	confirm_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_pill.anchor_left = 0.5
	confirm_pill.anchor_right = 0.5
	confirm_pill.anchor_top = 0.5
	confirm_pill.anchor_bottom = 0.5
	confirm_pill.offset_top = float(settings.get("confirm_mark_offset_y", 40))
	confirm_pill.offset_bottom = confirm_pill.offset_top
	confirm_pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	confirm_pill.modulate.a = float(settings.get("confirm_mark_alpha", 0.7))
	confirm_pill.visible = false
	layer.add_child(confirm_pill)
	confirm_mark = Label.new()
	confirm_mark.theme_type_variation = &"TitleText"   # HugeText ran off the screen
	confirm_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_pill.add_child(confirm_mark)
	# A Previous button (2026-11-15 team note): go back one station in the Design
	# Lab and change that choice. Backspace does the same; Esc frees the mouse to click it.
	if room_kind == "design":
		previous_button = Button.new()
		previous_button.theme_type_variation = &"SmallButton"
		previous_button.text = words["previous_button"]
		previous_button.focus_mode = Control.FOCUS_NONE   # Enter must keep confirming
		previous_button.position = Vector2(12 + float(Data.game_data["hud"]["portrait_size"]) + 12, 104)
		previous_button.visible = false
		previous_button.pressed.connect(go_back)
		layer.add_child(previous_button)


func spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.position = MeshKit.vec3(settings["spawn"])
	player.set_first_person(settings["first_person"])
	if GameState.character_id != "":
		player.set_avatar(GameState.character_id)


# ---------- categories and options ----------

func category() -> String:
	return categories[cat_index]


func is_part(cat: String) -> bool:
	return Data.parts.has(cat)


func list_options(cat: String) -> Array:
	match cat:
		"character":
			return Data.characters.keys().filter(func(id): return Data.story["characters"].has(id))
		"mission":
			return Data.destinations.keys()
		"rocket":
			return Data.game_data["launch_vehicles"]["vehicles"].keys()
		"orbit":
			return GameState.get_destination()["orbits"].keys().filter(func(id): return not id.begins_with("_"))
		"instruments":
			return GameState.get_instruments().keys()
		"launch_window":
			return Data.extras["launch_window"]["order"]
	return Data.parts[cat]["versions"].keys()


func get_value(cat: String):
	match cat:
		"character":
			return GameState.character_id
		"mission":
			return GameState.destination_id
		"rocket":
			return GameState.launch_vehicle_id
		"orbit":
			return GameState.orbit_id
		"instruments":
			return GameState.instruments_packed.duplicate()
		"launch_window":
			return GameState.launch_window_id
	return GameState.choices[cat]


func set_value(cat: String, value) -> void:
	match cat:
		"character":
			GameState.character_id = value
		"mission":
			GameState.destination_id = value
			GameState.goal_id = value
			GameState.mission_id = Data.destinations[value]["limits_from"]["value"]
		"rocket":
			GameState.launch_vehicle_id = value
		"orbit":
			GameState.orbit_id = value
		"instruments":
			GameState.instruments_packed = value.duplicate()
			GameState.instruments_set = true
		"launch_window":
			GameState.launch_window_id = value
		_:
			GameState.choices[cat] = value


func option_name(cat: String, id: String) -> String:
	match cat:
		"character":
			return Data.story["characters"][id]["name"]
		"mission":
			return Data.story["destinations"][id]["name"]
		"rocket":
			return Data.story["launch_vehicles"][id]["name"]
		"orbit":
			return Data.story["orbits"][GameState.get_destination_key()][id]["name"]
		"instruments":
			return Data.story["instruments"][GameState.get_destination_key()][id]["name"]
		"launch_window":
			return Data.story["extras"]["launch_window"]["names"][id]
	return Data.version_name(cat, id)


func category_name(cat: String) -> String:
	if is_part(cat):
		return Data.part_name(cat)
	return words["short_names"][cat]


# The short facts on a card and over a pedestal.
func option_lines(cat: String, id: String) -> PackedStringArray:
	var lines: PackedStringArray = []
	match cat:
		"character":
			var level: String = Data.characters[id]["level"]
			lines.append(words["difficulty_dots"].get(level, level))
		"mission":
			lines.append(words["goal_line"].format({"goal": Data.story["destinations"][id]["goal"]}))
			lines.append(words["trip_line"].format({"days": GameState.fmt(Data.destinations[id]["trip_days"]["value"])}))
			if Data.destinations[id]["locked"]["value"]:
				lines.append(words["locked_tag"])
		"rocket":
			var vehicle: Dictionary = Data.game_data["launch_vehicles"]["vehicles"][id]
			lines.append(words["cost_line"].format({"value": GameState.fmt(vehicle["cost"])}))
			lines.append(words["lift_line"].format({"value": GameState.fmt(vehicle["capacity"])}))
			# The rocket line-up (extras): its real height in school buses.
			var lineup: Dictionary = Data.extras["rocket_lineup"]
			var meters: float = lineup["real_height_meters"].get(id, 0.0)
			if meters > 0.0:
				lines.append(Data.story["extras"]["lineup"]["height_line"].format({"meters": GameState.fmt(meters), "buses": GameState.fmt(roundf(meters / float(lineup["bus"][0])))}))
		"launch_window":
			var window: Dictionary = Data.extras["launch_window"]["options"][id]
			var window_words: Dictionary = Data.story["extras"]["launch_window"]
			# UPGRADE_PLAN_V6 B1: three chips that show the trade-off: Wait · Trip · Scrub risk.
			var wait: float = window["effects"].get("budget", 0.0)
			lines.append(window_words["wait_line"].format({"value": GameState.fmt(wait)}) if wait > 0.0 else window_words["wait_none"])
			lines.append(window_words["trip_line"].format({"days": GameState.fmt(roundf(float(GameState.get_destination()["trip_days"]["value"]) * float(window["trip_factor"])))}))
			lines.append(window_words["scrub_line"].format({"word": window_words["scrub_words"][id]}))
		"orbit":
			lines.append(words["fuel_line"].format({"value": GameState.fmt(GameState.get_destination()["orbits"][id]["fuel_mass"]["value"])}))
		"instruments":
			if GameState.get_key_instruments().has(id):
				lines.append(words["key_tag"])
			lines.append(GameState.effects_text(GameState.get_instruments()[id]["effects"], "\n"))
			if GameState.is_instrument_packed(id):
				lines.append(words["packed_tag"])
		_:
			lines.append(GameState.effects_text(Data.parts[cat]["versions"][id]["effects"], "\n"))
	return lines


func load_category(index: int) -> void:
	cat_index = index
	var cat: String = category()
	options = list_options(cat)
	blocked = list_blocked(cat)
	snapshot = get_value(cat)
	first_value = snapshot.duplicate() if snapshot is Array else snapshot
	GameState.unlock_for_category(cat)   # Space Dictionary stamps (N7)
	previewed = cat == "instruments" or (snapshot != "" and snapshot != null and cat != "character" and cat != "mission")
	before_totals = GameState.get_totals() if room_kind == "design" else {}
	build_pedestals()
	refresh_display()
	refresh_wall()
	update_prompt()
	if previous_button != null:
		previous_button.visible = index > 0
	update_retry_marks()
	if party_votes():
		Party.begin_vote(cat, options, cat == "instruments")
		refresh_votes()
	if cat == "character" or cat == "mission":
		inner_voice.say(words["nothing_previewed"])
	elif room_kind == "design":
		var retry_line: String = retry_line_for(cat)
		if retry_line != "":
			inner_voice.say(retry_line)   # a retry: the guide / last-time line replaces the station hint
		else:
			show_station_hint(index)


# ---------- the achievement board (UPGRADE_PLAN_V6 C3) ----------
# A big board on the wall behind the player's start spot: every achievement,
# with how to get it; earned ones are ticked and bright.
func build_achievement_board() -> void:
	var size: Array = settings["room_size"]
	var wall_z: float = float(size[1]) / 2.0 - 0.2
	var board_info: Dictionary = settings.get("achievement_board", {"width": 14.0, "height": 4.6, "center_y": 2.7})
	var w: float = float(board_info["width"])
	var h: float = float(board_info["height"])
	var cy: float = float(board_info["center_y"])
	MeshKit.box(self, Vector3(w, h, 0.06), Vector3(0, cy, wall_z), Color(settings["console_color"]))
	var words_a: Dictionary = Data.story["achievements"]
	var title := MeshKit.label(self, words_a["board_title"] + "   " + Achievements.count_text(), Vector3(0, cy + h / 2.0 - 0.35, wall_z - 0.05), 0.008, Color(settings["stripe_color"]))
	title.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	title.rotation.y = PI
	var order: Array = Data.achievements["order"]
	var per_column: int = int(ceil(order.size() / 2.0))
	for i in order.size():
		var a: Dictionary = Achievements.info(order[i])
		var got: bool = Achievements.has(order[i])
		var col: int = i / per_column
		var row: int = i % per_column
		var x: float = (w / 4.0) * (1 if col == 0 else -1)   # turned around: the first column is on the viewer's left
		var y: float = cy + h / 2.0 - 0.8 - row * ((h - 1.0) / per_column)
		var line := MeshKit.label(self, "%s %s: %s" % [words_a["got_mark"] if got else words_a["open_mark"], a["name"], a["how"]], Vector3(x, y, wall_z - 0.05), 0.0032, Color(a["color"]) if got else Color(0.75, 0.78, 0.85))
		line.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		line.rotation.y = PI
		line.outline_size = 4
		line.font_size = 32
		line.width = (w / 2.0 - 0.3) / 0.0032
		line.autowrap_mode = TextServer.AUTOWRAP_OFF


# ---------- retries (UPGRADE_PLAN_V6 B3 + B4) ----------

var retry_marks: Array = []      # the amber arrows and "Last time" tags in the room
var retry_said: Array = []       # stations whose retry line was already said (once each)


# Amber bouncing arrows over what the Scientist should pick, and a "Last time"
# tag over last run's pick. Rebuilt for each station.
func update_retry_marks() -> void:
	for mark in retry_marks:
		if is_instance_valid(mark):
			mark.queue_free()
	retry_marks.clear()
	if room_kind != "design" or GameState.last_attempt.is_empty():
		return
	var cat: String = category()
	var guide: Array = GameState.guide_options(cat)
	var last = GameState.last_attempt["choices"].get(cat, null)
	var retry_words: Dictionary = words["retry"]
	for p in pedestals:
		if p.has("blocked"):
			continue
		var top: Vector3 = p["root"].global_position + Vector3(0, float(settings.get("retry_mark_height", 2.2)), 0)
		if guide.has(p["id"]):
			var arrow := MeshKit.cylinder(self, 0.32, 0.0, 0.6, top, Color(retry_words["arrow_color"]), 12)   # points down
			arrow.material_override = MeshKit.glow(Color(retry_words["arrow_color"]), 2.0)
			arrow.set_meta("bounce_base", top.y)
			retry_marks.append(arrow)
			var name_tag := MeshKit.label(self, option_name(cat, p["id"]), top + Vector3(0, 0.75, 0), 0.006, Color(retry_words["arrow_color"]))
			name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			retry_marks.append(name_tag)
		var was_last: bool = (last is Array and last.has(p["id"])) or (last is String and last == p["id"])
		if was_last and cat != "instruments":
			var tag := MeshKit.label(self, retry_words["last_tag"], top + Vector3(0, -0.5, 0), 0.005, Color.WHITE)
			tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			retry_marks.append(tag)


# The bouncing arrows (called every frame from _process).
func bounce_retry_marks() -> void:
	for mark in retry_marks:
		if is_instance_valid(mark) and mark.has_meta("bounce_base"):
			mark.position.y = float(mark.get_meta("bounce_base")) + absf(sin(Time.get_ticks_msec() / 250.0)) * 0.3


# One line per station on a retry: the Scientist's guide ("Pick the ice drill"),
# else what happened last time, in this character's own words.
func retry_line_for(cat: String) -> String:
	if GameState.last_attempt.is_empty() or retry_said.has(cat):
		return ""
	var retry_words: Dictionary = Data.voice["last_time"]
	var guide: Array = GameState.guide_options(cat)
	if not guide.is_empty():
		retry_said.append(cat)
		var key: String = "guide_instrument" if cat == "instruments" else "guide_part"
		return retry_words[key].format({"name": option_name(cat, guide[0])})
	var last = GameState.last_attempt["choices"].get(cat, null)
	if last == null or (last is Array):
		return ""
	retry_said.append(cat)
	var verdict: String = GameState.last_attempt["verdicts"].get(cat, "good")
	var level: String = GameState.level if GameState.level != "" else "medium"
	return retry_words[level][verdict].format({"name": option_name(cat, str(last))})


# Three voices, one decision (INNOVATION.md Feature A): the picked character's
# hint for this station, a moment after it loads (so the "locked in" line of
# the last station can be heard first). Words: inner_voice.json "character_hints".
func show_station_hint(index: int) -> void:
	var hint: String = Notebook.hint_for(category())
	if hint == "":
		return
	await get_tree().create_timer(float(settings.get("hint_delay_seconds", 1.6))).timeout
	if is_inside_tree() and cat_index == index and not busy:
		inner_voice.say(hint)


# Options that cannot work for this mission (the telescope game's idea, N4):
# destinations.json > mission > "not_possible" > category. They stand on dim
# pedestals with one line why. Options that are only a bad idea stay pickable.
func list_blocked(cat: String) -> Array:
	if room_kind != "design":
		return []
	return GameState.get_destination().get("not_possible", {}).get(cat, [])


func build_pedestals() -> void:
	for p in pedestals:
		p["root"].queue_free()
	pedestals.clear()
	near_pedestal = -1
	var count: int = options.size() + blocked.size()
	for i in count:
		if i >= options.size():
			build_blocked_pedestal(i, count)
			continue
		var id: String = options[i]
		var root := make_pedestal_root(i, count)
		var r: float = settings["pedestal_radius"]
		var h: float = settings["pedestal_height"]
		var low: bool = category() == "character"
		var top: float = float(settings.get("character_pedestal_height", 0.35)) if low else h
		var body := StaticBody3D.new()
		root.add_child(body)
		MeshKit.cylinder(body, r, r * 1.1, top, Vector3(0, top / 2.0, 0), Color(settings["pedestal_color"]), 24)
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = r * 1.1
		cyl.height = top
		shape.shape = cyl
		shape.position.y = top / 2.0
		body.add_child(shape)
		var ring := MeshKit.add(root, ring_mesh(r * 0.95, r * 1.08), Vector3(0, top + 0.01, 0), MeshKit.glow(Color(settings["accent_color"]), 2.0))
		ring.visible = false
		var holder := Node3D.new()
		holder.position.y = top
		root.add_child(holder)
		make_option_model(holder, category(), id, i)
		# The options are smaller and low (below eye height, so they never block the
		# back-wall screens); the big detailed one floats in the middle. Sizes:
		# game_data.json choice_room > option_model_scale (Holden, 2026-11-15).
		var scales: Dictionary = settings.get("option_model_scale", {})
		holder.set_meta("base_scale", float(scales.get(category(), scales.get("other", 1.0))))
		holder.set_meta("base_y", top)
		var plate: Dictionary = make_nameplate(root, plate_text(i, option_name(category(), id)), top, false)
		var area := make_area(Vector3.ZERO, "pedestal")
		area.set_meta("index", i)
		root.add_child(area)
		pedestals.append({"root": root, "id": id, "ring": ring, "label": plate["node"], "plate": plate, "holder": holder})
		if party_votes():
			# One dot per vote, just above the nameplate (MULTIPLAYER_PLAN_V6 3b).
			var dots := Label3D.new()
			dots.font_size = 64
			dots.pixel_size = float(settings.get("nameplate_letter", 0.0042))
			dots.outline_size = 8
			dots.modulate = Color(1, 0.6, 0.2)
			dots.position = Vector3(0, 0.36, 0.03)
			plate["node"].add_child(dots)
			pedestals[-1]["dots"] = dots
	refresh_pedestals()


# Where pedestal i of count stands: a gentle curve (the outer ones a little
# closer), turned to face the player's start spot (ROOM_LAYOUT_PLAN_V5 Step 2).
func make_pedestal_root(i: int, count: int) -> Node3D:
	var root := Node3D.new()
	var half: float = maxf((count - 1) / 2.0, 1.0)
	var t: float = (i - (count - 1) / 2.0) / half
	var x: float = (i - (count - 1) / 2.0) * pedestal_spacing(count)
	var z: float = float(settings["pedestal_z"]) + float(settings.get("pedestal_curve", 0.0)) * t * t
	root.position = Vector3(x, 0, z)
	var spawn: Vector3 = MeshKit.vec3(settings["spawn"])
	root.rotation.y = atan2(spawn.x - x, spawn.z - z)   # its front (+Z) faces the start spot
	add_child(root)
	return root


# The gap between pedestals: the normal spacing, or less when many options
# would make the row wider than pedestal_max_span (then they would stand
# behind the side screens).
func pedestal_spacing(count: int) -> float:
	var spacing: float = float(settings["pedestal_spacing"])
	if count > 1:
		spacing = minf(spacing, float(settings.get("pedestal_max_span", 99.0)) / float(count - 1))
	return spacing


# "2 · Atlas V 401": the number key and the name only (V5 Step 3).
func plate_text(i: int, option: String) -> String:
	return str(i + 1) + " · " + option


# A dark navy nameplate on the front of a pedestal with big off-white words.
# The picked one turns amber (refresh_pedestals). dim = an option that cannot be chosen.
func make_nameplate(root: Node3D, text: String, top: float, dim: bool) -> Dictionary:
	var size: Array = settings.get("nameplate_size", [2.6, 0.42])
	var letter: float = float(settings.get("nameplate_letter", 0.0042))
	# Never wider than the gap between pedestals, so plates never touch.
	var width: float = minf(float(size[0]), pedestal_spacing(options.size() + blocked.size()) - 0.2)
	# A long name wraps to two lines: the plate grows, the letters never shrink.
	var lines: int = 2 if text.length() * 48.0 * letter * 0.55 > width - 0.2 else 1
	var height: float = float(size[1]) * (1.7 if lines == 2 else 1.0)
	var node := Node3D.new()
	var r: float = settings["pedestal_radius"]
	node.position = Vector3(0, maxf(top - height / 2.0 - 0.06, height / 2.0 + 0.04), r * 1.1 + 0.06)
	root.add_child(node)
	var mesh := MeshKit.box(node, Vector3(width, height, 0.05), Vector3.ZERO, Color(0.06, 0.1, 0.22))
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = letter
	label.outline_size = 0
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.width = (width - 0.2) / letter
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector3(0, 0, 0.03)
	label.modulate = Color(0.94, 0.95, 1.0, 0.45 if dim else 1.0)
	node.add_child(label)
	if dim:
		(mesh.material_override as StandardMaterial3D).albedo_color = Color(0.06, 0.1, 0.22).lightened(0.05)
		node.scale = Vector3.ONE * 0.95
	return {"node": node, "mesh": mesh, "label": label}


# A plate turns amber when its option is picked (the one amber thing in the room).
func set_plate_picked(plate: Dictionary, picked: bool) -> void:
	var mat := (plate["mesh"] as MeshInstance3D).material_override as StandardMaterial3D
	if mat != null:
		mat.albedo_color = Color(1, 0.6, 0.2) if picked else Color(0.06, 0.1, 0.22)
	(plate["label"] as Label3D).modulate = Color(0.04, 0.086, 0.2) if picked else Color(0.94, 0.95, 1.0)


# A dim pedestal with a dark box and a dim nameplate (name only; the reason
# shows on the left screen when you walk up). Pressing E on it only explains why.
func build_blocked_pedestal(i: int, count: int) -> void:
	var info: Dictionary = blocked[i - options.size()]
	var root := make_pedestal_root(i, count)
	var r: float = settings["pedestal_radius"]
	var h: float = settings["pedestal_height"]
	var dim := Color(settings["pedestal_color"]).darkened(0.65)
	var body := StaticBody3D.new()
	root.add_child(body)
	MeshKit.cylinder(body, r, r * 1.1, h, Vector3(0, h / 2.0, 0), dim, 24)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r * 1.1
	cyl.height = h
	shape.shape = cyl
	shape.position.y = h / 2.0
	body.add_child(shape)
	var holder := Node3D.new()
	holder.position.y = h
	root.add_child(holder)
	MeshKit.box(holder, Vector3(0.45, 0.45, 0.45), Vector3(0, 0.3, 0), dim.lightened(0.15))
	var plate: Dictionary = make_nameplate(root, plate_text(i, info["name"]), h, true)
	var ring := MeshKit.add(root, ring_mesh(r * 0.95, r * 1.08), Vector3(0, h + 0.01, 0), MeshKit.glow(dim, 0.5))
	ring.visible = false
	var area := make_area(Vector3.ZERO, "pedestal")
	area.set_meta("index", i)
	root.add_child(area)
	pedestals.append({"root": root, "id": "", "ring": ring, "label": plate["node"], "plate": plate, "holder": holder, "blocked": info})


# The model on each pedestal.
func make_option_model(holder: Node3D, cat: String, id: String, index: int) -> void:
	match cat:
		"character":
			var person: Node3D = load(Data.characters[id]["scene"]).instantiate()
			person.rotation.y = PI   # face the player
			holder.add_child(person)
		"mission":
			var globe := MeshKit.sphere(holder, settings["planet_radius"], Vector3(0, 0.9, 0), Color(settings["planet_colors"].get(id, "#888888")), 32)
			PLANET_LOOK.apply(globe, id)   # the real NASA map (more detail)
			globe.set_meta("spin", true)
			if Data.destinations[id]["locked"]["value"]:
				globe.material_override.albedo_color = globe.material_override.albedo_color.darkened(0.6)
		"rocket":
			var rocket: Node3D = load("res://scenes/rockets/rocket_" + id + ".tscn").instantiate()
			rocket.scale = Vector3.ONE * float(settings["rocket_scale"])
			holder.add_child(rocket)
			add_school_bus(holder, rocket, id)
		"launch_window":
			# A little calendar page: white with a red top, and a colored dot for how good the date is.
			MeshKit.box(holder, Vector3(0.6, 0.6, 0.08), Vector3(0, 0.55, 0), Color(0.95, 0.95, 0.95))
			MeshKit.box(holder, Vector3(0.6, 0.14, 0.09), Vector3(0, 0.8, 0), Color(0.8, 0.2, 0.2))
			var dot: Color = [Color(0.3, 0.9, 0.4), Color(1.0, 0.85, 0.3), Color(1.0, 0.4, 0.3)][clampi(index, 0, 2)]
			MeshKit.add(holder, SphereMesh.new(), Vector3(0, 0.5, 0.06), MeshKit.glow(dot, 1.5)).scale = Vector3.ONE * 0.2
		"orbit":
			var key: String = GameState.get_destination_key()
			MeshKit.sphere(holder, 0.35, Vector3(0, 0.9, 0), Color(settings["planet_colors"].get(key, "#888888")), 20)
			var radius: float = settings["orbit_radius"].get(id, 0.8)
			var ring := MeshKit.add(holder, ring_mesh(radius - 0.02, radius + 0.02), Vector3(0, 0.9, 0), MeshKit.glow(Color(settings["accent_color"]), 1.5))
			if id == "polar":
				ring.rotation.x = PI / 2.0
			MeshKit.sphere(holder, 0.07, Vector3(radius, 0.9, 0), Color.WHITE, 8)
		"instruments":
			var colors: Array = Data.game_data["spacecraft_model"]["instrument_colors"]
			MeshKit.box(holder, Vector3(0.45, 0.45, 0.45), Vector3(0, 0.45, 0), Color(colors[index % colors.size()]))
			MeshKit.cylinder(holder, 0.12, 0.12, 0.3, Vector3(0, 0.45, 0.32), Color(0.15, 0.15, 0.18), 10).rotation.x = PI / 2.0
		_:
			part_icon(holder, cat, index)


# The rocket line-up (extras): a yellow school bus next to the rocket, at the
# same scale (the rocket's real height vs the bus's real length), so its size makes sense.
func add_school_bus(holder: Node3D, rocket: Node3D, id: String) -> void:
	var lineup: Dictionary = Data.extras["rocket_lineup"]
	var real: float = lineup["real_height_meters"].get(id, 0.0)
	var model_height: float = rocket.get("height") if rocket.get("height") != null else 0.0
	if real <= 0.0 or model_height <= 0.0:
		return
	var meters_to_scene: float = model_height * rocket.scale.y / real
	var bus: Array = lineup["bus"]
	var size := Vector3(float(bus[0]), float(bus[1]), float(bus[2])) * meters_to_scene
	var spot := Vector3(float(settings["pedestal_radius"]) * 0.62, size.y / 2.0, 0.15)
	MeshKit.box(holder, size, spot, Color(lineup["bus_color"]))
	MeshKit.box(holder, Vector3(size.x * 0.8, size.y * 0.3, size.z * 1.02), spot + Vector3(0, size.y * 0.15, 0), Color(lineup["window_color"]))


# A small model for one part card: bigger for the better cards.
func part_icon(holder: Node3D, cat: String, index: int) -> void:
	var step: float = [0.8, 1.0, 1.25][clampi(index, 0, 2)]
	var look: Dictionary = Data.game_data["spacecraft_model"]
	match cat:
		"structure":
			var s: float = 0.7 * step
			for x in [-1, 1]:
				for z in [-1, 1]:
					MeshKit.box(holder, Vector3(0.05 * step, s, 0.05 * step), Vector3(x * s / 2.0, s / 2.0 + 0.1, z * s / 2.0), Color(look["structure"]["color"]))
			for y in [0.1, s + 0.1]:
				MeshKit.box(holder, Vector3(s, 0.05 * step, s), Vector3(0, y, 0), Color(look["structure"]["color"]))
		"solar_panel":
			for side in [-1, 1]:
				var panel := MeshKit.box(holder, Vector3(0.45 * step, 0.04, 0.6 * step), Vector3(side * 0.3 * step, 0.7, 0), Color(Data.parts["solar_panel"]["look"]["color"]))
				panel.rotation.z = side * 0.3
				Textures.apply(panel.material_override, Data.parts["solar_panel"]["look"]["texture"])
		"battery":
			MeshKit.box(holder, Vector3(0.5, 0.35, 0.35) * step, Vector3(0, 0.3, 0), Color(look["battery"]["color"]))
			MeshKit.cylinder(holder, 0.05, 0.05, 0.08, Vector3(0.12, 0.5 * step + 0.05, 0), Color(0.8, 0.8, 0.8), 8)
		"attitude_control":
			for i in index + 1:
				var wheel := MeshKit.cylinder(holder, 0.18, 0.18, 0.07, Vector3((i - index / 2.0) * 0.3, 0.45, 0), Color(look["attitude_control"]["color"]), 16)
				wheel.rotation.x = PI / 2.0
		"thermal_control":
			for i in index + 2:
				MeshKit.box(holder, Vector3(0.06, 0.6, 0.5), Vector3((i - (index + 1) / 2.0) * 0.14, 0.4, 0), Color(look["thermal_control"]["color"]))
		"antenna":
			MeshKit.cylinder(holder, 0.04, 0.04, 0.4, Vector3(0, 0.2, 0), Color(0.7, 0.7, 0.7), 8)
			MeshKit.lathe(holder, [Vector2(0.03, 0.0), Vector2(0.3 * step, 0.08 * step), Vector2(0.42 * step, 0.2 * step)], Vector3(0, 0.4, 0), Color(Data.parts["antenna"]["look"]["color"]), 0.0, TAU, 16)
		"computer":
			MeshKit.box(holder, Vector3(0.45, 0.2, 0.35) * step, Vector3(0, 0.3, 0), Color(look["computer"]["color"]))
			for i in index + 1:
				MeshKit.add(holder, SphereMesh.new(), Vector3(-0.12 + i * 0.1, 0.42 * step, 0.18 * step), MeshKit.glow(Color(0.3, 1.0, 0.4))).scale = Vector3.ONE * 0.05


# The model on the display stand: the rocket, the spacecraft or the planet.
func refresh_display() -> void:
	if display_model != null:
		display_model.queue_free()
		display_model = null
	var cat: String = category()
	# Over the hologram everything is shown big and in detail, centered on the
	# floating spot (Holden, 2026-11-15). display_scale = game_data.json.
	var big: float = float(settings.get("display_scale", 1.0))
	match cat:
		"character":
			var who: String = str(get_value(cat))
			if who == "" or not previewed:
				return
			var person: Node3D = load(Data.characters[who]["scene"]).instantiate()
			person.scale = Vector3.ONE * big
			person.position.y = -0.9 * big   # centered: a person is about 1.8 m tall
			person.rotation.y = PI
			display_model = Node3D.new()
			display_model.add_child(person)
			display.add_child(display_model)
		"mission":
			var id: String = str(get_value(cat))
			if id == "":
				return
			display_model = Node3D.new()
			display.add_child(display_model)
			# The real NASA map (planet_look.gd), so the planet has real detail.
			var globe := MeshKit.sphere(display_model, 0.9 * big, Vector3.ZERO, Color(settings["planet_colors"].get(id, "#888888")), 48)
			PLANET_LOOK.apply(globe, id)
			globe.set_meta("spin", true)
		"rocket", "orbit", "launch_window":
			var rocket: Node3D = load("res://scenes/rockets/rocket_" + GameState.get_launch_vehicle_id() + ".tscn").instantiate()
			var s: float = float(settings["display_rocket_scale"]) * big
			rocket.scale = Vector3.ONE * s
			var rocket_height = rocket.get("height")
			rocket.position.y = -(float(rocket_height) if rocket_height != null else 20.0) * s / 2.0   # centered over the beam
			display_model = Node3D.new()
			display_model.add_child(rocket)
			display.add_child(display_model)
		_:
			var craft := SpacecraftModel.new()
			craft.scale = Vector3.ONE * float(settings["spacecraft_display_scale"]) * big
			display_model = craft
			display.add_child(craft)
			craft.set_inside(settings["inside_categories"].has(cat))
			# The part glows; no floating name over it (it crossed the screen). The
			# left screen names the part instead.
			craft.highlight(cat, "")


func _process(delta: float) -> void:
	bounce_retry_marks()
	_process_votes()   # the vote countdown (party only)
	if display_model != null:
		display_model.rotation.y += delta * float(settings["turn_speed"])   # the floating model turns slowly
	float_time += delta
	display.position.y = float(settings["display_position"][1]) + sin(float_time * 1.2) * 0.12   # and bobs up and down
	for node in find_children("*", "MeshInstance3D", true, false):
		if node.has_meta("spin"):
			node.rotation.y += delta * 0.5
	if hired_camera != null:
		hired_camera.look_at(hired_target, Vector3.UP)
	update_crew_prompt()
	update_tap_part()


# Ask the crew (extras): next to a staff member with nothing else in reach,
# the prompt offers E for one line about this room.
var crew_near: Node3D = null

func update_crew_prompt() -> void:
	if busy or player == null:
		return
	var was: Node3D = crew_near
	crew_near = null
	if near_pedestal < 0 and not near_console:
		crew_near = Bots.nearest_walker(player.global_position, float(Data.extras["ask_crew"]["reach_meters"]))
	if crew_near != was:
		update_prompt()


# Tap a part (extras): in the Inside view, look at a part of the spacecraft on
# the display stand and click it for its job in five words.
var tap_target: String = ""

func update_tap_part() -> void:
	var was: String = tap_target
	tap_target = ""
	# Only up close (at the railing), so the hint never covers the first look.
	var close: bool = player != null and player.global_position.distance_to(display.global_position * Vector3(1, 0, 1)) < float(settings["observation"].get("tap_distance", 6.0))
	if close and not busy and room_kind == "design" and display_model is SpacecraftModel and display_model.inside and near_pedestal < 0:
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			var middle: Vector2 = get_viewport().get_visible_rect().size / 2.0
			var best: float = float(Data.extras["tap_part"]["pick_pixels"])
			for key in display_model.holders:
				var holder: Node3D = display_model.holders[key]
				if not holder.is_visible_in_tree():
					continue
				var meshes: Array = holder.find_children("*", "MeshInstance3D", true, false)
				if meshes.is_empty():
					continue
				var center := Vector3.ZERO
				for mesh in meshes:
					center += (mesh as Node3D).global_position
				center /= meshes.size()
				if camera.is_position_behind(center):
					continue
				var d: float = camera.unproject_position(center).distance_to(middle)
				if d < best:
					best = d
					tap_target = "instruments" if String(key).begins_with("instrument:") else String(key)
	if tap_target != was:
		update_prompt()


func tap_target_name() -> String:
	return str(Data.story["extras"]["tap_part"]["jobs"].get(tap_target, tap_target)).get_slice(":", 0)


func tap_part() -> void:
	var job: String = Data.story["extras"]["tap_part"]["jobs"].get(tap_target, "")
	if job == "":
		return
	AudioManager.play_sfx("preview")
	display_model.highlight(tap_target, "")   # the job is said in the voice box (no floating label, V5)
	inner_voice.say(job)


func ask_crew() -> void:
	var crew_words: Dictionary = Data.story["extras"]["ask_crew"]
	AudioManager.play_sfx("preview")
	inner_voice.say(crew_words["speaker"] + ": " + crew_words["rooms"].get(room_kind, crew_words["rooms"]["design"]))


# ---------- the wall screen's contents ----------

func refresh_wall() -> void:
	if wall_root == null or right_root == null:
		return
	fill_left(screen_column(wall_root))
	fill_right(screen_column(right_root))
	last_wall_totals = GameState.get_totals() if room_kind == "design" else {}


# Clears one side screen and gives back its column (background + margin).
func screen_column(ui_root: Control) -> VBoxContainer:
	for child in ui_root.get_children():
		child.queue_free()
	var background := Panel.new()
	background.theme_type_variation = &"ScreenBackground"
	background.size = ui_root.size
	ui_root.add_child(background)
	var margin := MarginContainer.new()
	margin.size = ui_root.size
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, wall_gap(16))
	ui_root.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", wall_gap(8))
	margin.add_child(column)
	return column


# The screens are drawn with a scaled-up theme; gaps set here scale the same way.
func wall_gap(pixels: float) -> int:
	return int(round(pixels * float(settings["side_screens"]["ui_scale"])))


func screen_label(column: Control, text: String, style: StringName, wrap: bool = false) -> Label:
	var label := UI.label(text, style, wrap)
	column.add_child(label)
	return label


# LEFT, "This choice": the room's question, step dots, then the option you
# stand at (or the picked one): name, one line, up to three stats.
func fill_left(column: VBoxContainer) -> void:
	var cat: String = category()
	var wall_words: Dictionary = words["wall"]
	screen_label(column, words["titles"].get(cat, words["part_title"].format({"part": category_name(cat).to_lower()})), &"HeadingText", true)
	if room_kind == "design":
		var marks: PackedStringArray = []
		for i in categories.size():
			marks.append("•" if i <= cat_index else "·")
		screen_label(column, " ".join(marks) + "   " + wall_words["steps"].format({"n": cat_index + 1, "total": categories.size()}) + "  ·  " + discipline(cat), &"TinyText")
	var spacer := Control.new()
	spacer.custom_minimum_size.y = wall_gap(8)
	column.add_child(spacer)

	# Which option to show: the pedestal you stand at, else the picked one.
	var index: int = near_pedestal
	if index < 0 and cat != "instruments" and previewed:
		index = options.find(str(get_value(cat)))
	if index < 0 or index >= pedestals.size():
		screen_label(column, words["nothing_previewed"], &"BodyText", true)
		return
	if pedestals[index].has("blocked"):
		var info: Dictionary = pedestals[index]["blocked"]
		screen_label(column, plate_text(index, info["name"]), &"BodyText", true).modulate.a = 0.6
		screen_label(column, Data.story["nasa"]["not_possible_tag"], &"SmallText")
		screen_label(column, info["reason"], &"SmallText", true)
		return
	var id: String = options[index]
	var top := HBoxContainer.new()
	column.add_child(top)
	var name_label := screen_label(top, plate_text(index, option_name(cat, id)), &"BodyText", true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lit: bool = (cat == "instruments" and GameState.is_instrument_packed(id)) or (cat != "instruments" and previewed and str(get_value(cat)) == id)
	if lit:
		var mark := PanelContainer.new()
		mark.theme_type_variation = &"TagPill"
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(mark)
		screen_label(mark, wall_words["packed"] if cat == "instruments" else wall_words["picked"], &"PillSmallText")
	var line: String = card_line(cat, id)
	if line == "":
		line = option_description(cat, id)
	if line != "":
		var line_label := screen_label(column, line, &"SmallText", true)
		line_label.max_lines_visible = 3
	var chips: Array = card_chips(cat, id).slice(0, 3)
	if not chips.is_empty():
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", wall_gap(8))
		flow.add_theme_constant_override("v_separation", wall_gap(8))
		column.add_child(flow)
		for text in chips:
			flow.add_child(UI.chip(text))


# One option's own description (the words the left screen shows for it).
func option_description(cat: String, id: String) -> String:
	match cat:
		"rocket":
			return Data.story["launch_vehicles"][id]["description"]
		"orbit":
			return Data.story["orbits"][GameState.get_destination_key()][id]["description"]
		"launch_window":
			return Data.story["extras"]["launch_window"]["descriptions"][id]
	if is_part(cat):
		return Data.story["parts"][cat]["versions"][id]["description"]
	return ""


# RIGHT, "Your mission": the six resources (name, bar, one number; before →
# after only on the bars that changed at this station) and one red blocker
# line. In the Character and Mission Rooms there are no resources yet: the
# picked staff card or mission card shows instead.
func fill_right(column: VBoxContainer) -> void:
	var wall_words: Dictionary = words["wall"]
	if room_kind != "design":
		screen_label(column, wall_words["right_title_" + room_kind], &"HeadingText")
		var id: String = str(get_value(category()))
		if not previewed or id == "":
			screen_label(column, words["nothing_previewed"], &"SmallText", true)
			return
		var text: String = base_detail_text(category(), id)
		if category() == "mission":
			# The plan's three lines: where, the job, why it matters (the rest is behind Q).
			var card: Dictionary = Data.story["destinations"][id]["mission_card"]
			var labels: Dictionary = words["mission_labels"]
			var lines: PackedStringArray = []
			for key in ["where", "job", "why"]:
				lines.append(labels[key] + ": " + card[key])
			text = "\n".join(lines)
		screen_label(column, text, &"TinyText", true)
		return
	screen_label(column, wall_words["right_title"], &"HeadingText")
	add_resource_rows(column)
	var lines: PackedStringArray = blocker_lines()
	if not lines.is_empty():
		var blockers := screen_label(column, lines[0].trim_prefix("- ") + ("  " + wall_words["more_blockers"].format({"n": lines.size() - 1}) if lines.size() > 1 else ""), &"SmallText")
		blockers.clip_text = true   # one line; the full list is on Review
		blockers.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		blockers.add_theme_color_override("font_color", blockers.get_theme_color("danger_color", &"Status"))
	else:
		var ok := screen_label(column, words["no_blockers"], &"SmallText", true)
		ok.add_theme_color_override("font_color", ok.get_theme_color("go_color", &"Status"))


# The one short line on a card (or "").
func card_line(cat: String, id: String) -> String:
	match cat:
		"character":
			return words["difficulty_dots"].get(Data.characters[id]["level"], "")
		"mission":
			var goal: String = words["goal_line"].format({"goal": Data.story["destinations"][id]["goal"]})
			return goal + ("  · " + words["locked_tag"] if Data.destinations[id]["locked"]["value"] else "")
		"instruments":
			return words["key_tag"] if GameState.get_key_instruments().has(id) else ""
	return ""


# Up to three stat chips. Parts and instruments: the three effects that move
# their resource the most (DEFAULT, so the antenna shows its signal); other
# choices: their short facts (cost, lift, fuel, trip).
func card_chips(cat: String, id: String) -> Array:
	var effects: Dictionary = {}
	match cat:
		"character":
			return []
		"mission":
			return [words["trip_line"].format({"days": GameState.fmt(Data.destinations[id]["trip_days"]["value"])})]
		"instruments":
			effects = GameState.get_instruments()[id]["effects"]
		"rocket", "orbit", "launch_window":
			return Array(option_lines(cat, id))
		_:
			effects = Data.parts[cat]["versions"][id]["effects"]
	var limits: Dictionary = GameState.get_limits()
	var ids: Array = effects.keys().filter(func(r): return float(effects[r]) != 0.0 and Data.resources.has(r))
	ids.sort_custom(func(a, b): return absf(effects[a]) / maxf(float(limits[a]["bar_max"]), 0.001) > absf(effects[b]) / maxf(float(limits[b]["bar_max"]), 0.001))
	var chips: Array = []
	for res_id in ids.slice(0, 3):
		var amount: float = effects[res_id]
		chips.append("%s %s%s %s" % [words["wall"]["short_resources"].get(res_id, Data.resources[res_id]["name"]), "+" if amount > 0 else "", GameState.fmt(amount), Data.resources[res_id]["unit"]])
	return chips


# The six resources, one row each: name, thin bar, one number. The bar is
# off-white, amber close to the limit, red over it. A row that changed at this
# station shows "before → after"; the number counts to its new value.
func add_resource_rows(column: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", wall_gap(16))
	grid.add_theme_constant_override("v_separation", wall_gap(2))
	column.add_child(grid)
	var after: Dictionary = GameState.get_totals()
	var limits: Dictionary = GameState.get_limits()
	for res_id in Data.resources:
		var name_label := UI.label(words["wall"]["short_resources"].get(res_id, Data.resources[res_id]["name"]), &"SmallText")
		grid.add_child(name_label)
		var status: String = GameState.get_status(after[res_id], limits[res_id])
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(wall_gap(120), wall_gap(8))
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.max_value = maxf(float(limits[res_id]["bar_max"]), 0.001)
		bar.value = clampf(after[res_id], 0.0, bar.max_value)
		var fill: StyleBoxFlat = right_root.theme.get_stylebox("fill", &"ProgressBar").duplicate()
		fill.bg_color = bar.get_theme_color({"warning": "bar_warn_color", "danger": "bar_over_color"}.get(status, "bar_color"), &"Status")
		bar.add_theme_stylebox_override("fill", fill)
		grid.add_child(bar)
		var value := UI.label("", &"BodyText")
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if status == "danger":
			value.add_theme_color_override("font_color", value.get_theme_color("danger_color", &"Status"))
		grid.add_child(value)
		var start: float = before_totals.get(res_id, after[res_id])
		var changed: bool = not is_equal_approx(snappedf(start, 0.01), snappedf(after[res_id], 0.01))
		var from_value: float = last_wall_totals.get(res_id, after[res_id])
		var start_text: String = GameState.fmt(start)
		UI.count_to(value, from_value, after[res_id], func(v): return (start_text + " → " if changed else "") + GameState.fmt(v))


# The text under the cards, plus a "Did you know?" once something is previewed
# (rule 1: do, then learn).
func detail_text(cat: String, id: String) -> String:
	var text: String = base_detail_text(cat, id)
	var tip: String = did_you_know(cat)
	if tip != "" and (previewed or cat == "instruments"):
		text += "\n" + Data.story["did_you_know"]["label"] + " " + tip
	return text


# One real fact for this category: story.json "did_you_know" (each with its
# NASA source), the GMAT tip in the orbit station, the CSA tip in the Mission
# Room once a writer adds it (nasa_resources.json "csa_tip").
func did_you_know(cat: String) -> String:
	var tips: Dictionary = Data.story["did_you_know"]
	match cat:
		"rocket":
			return tips["rockets"]["text"]
		"orbit":
			return Data.story["nasa"]["gmat_tip"]["text"]
		"launch_window":
			var window_words: Dictionary = Data.story["extras"]["launch_window"]
			match GameState.get_destination_key():
				"mars":
					return window_words["did_you_know"].format({"months": GameState.fmt(Data.extras["launch_window"]["mars_every_months"])})
				"moon":
					return window_words["did_you_know_moon"]
			return ""
		"instruments":
			return tips["instruments"].get(GameState.get_destination_key(), {}).get("text", "")
		"mission":
			var csa: Dictionary = Data.nasa["csa_tip"]
			return "" if str(csa["text"]).begins_with("PLACEHOLDER") else csa["text"]
	if tips["parts"].has(cat):
		return tips["parts"][cat]["text"]
	return ""


func base_detail_text(cat: String, id: String) -> String:
	if cat == "instruments":
		# Real word + kid meaning, once (rule 3).
		return Data.story["nasa"]["payload_meaning"] + " " + Data.story["build_screen"]["instruments_hint"]
	if id == "" or not previewed:
		return words["nothing_previewed"]
	match cat:
		"character":
			# The staff card (UPGRADE_PLAN_V3 B1): who they are, what they know,
			# how much help you get, and the difficulty as dots. No inner-voice text.
			var card: Dictionary = Data.story["characters"][id]["staff_card"]
			var labels: Dictionary = words["staff_labels"]
			var level: String = Data.characters[id]["level"]
			return "%s: %s\n%s: %s\n%s: %s\n%s: %s" % [labels["who"], card["who"], labels["knows"], card["knows"],
				labels["help"], card["help"], labels["difficulty"], words["difficulty_dots"].get(level, level)]
		"mission":
			# The mission card (UPGRADE_PLAN_V3 B2): where, the job, why, and what
			# NASA has already done. The longer story is behind Q on the globe.
			var card: Dictionary = Data.story["destinations"][id]["mission_card"]
			var labels: Dictionary = words["mission_labels"]
			var lines: PackedStringArray = []
			for key in ["where", "job", "why", "nasa"]:
				lines.append(labels[key] + ": " + card[key])
			return "\n".join(lines)
		"rocket":
			return Data.story["launch_vehicles"][id]["description"]
		"orbit":
			return Data.story["orbits"][GameState.get_destination_key()][id]["description"]
		"launch_window":
			return Data.story["extras"]["launch_window"]["descriptions"][id]
	if is_part(cat):
		return Data.story["parts"][cat]["versions"][id]["description"]
	return ""


# The ripple effect: what this choice changed, compared with the confirmed one.
func ripple_text() -> String:
	var text: Dictionary = Data.story["ripple"]
	var colors: Dictionary = Data.game_data["dashboard"]["colors"]
	var after: Dictionary = GameState.get_totals()
	var steps: Array = GameState.get_ripple_steps(before_totals, after)
	var pieces: PackedStringArray = []
	if steps.is_empty():
		pieces.append(text["no_change"])
	for step in steps:
		var res_id: String = step["res_id"]
		var amount: float = step["amount"]
		var line: String = text["change"].format({
			"resource": Data.resources[res_id]["name"],
			"amount": ("+" if amount > 0 else "") + GameState.fmt(amount),
			"unit": Data.resources[res_id]["unit"],
		})
		pieces.append("[color=%s]%s[/color]" % [colors["safe"] if step["good"] else colors["danger"], line])
	return text["arrow"].join(pieces)


# Red "mission blocker" lines: every resource over its limit, and a missing
# key instrument once the instruments are being packed.
func blocker_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	var review: Dictionary = Data.story["review_screen"]
	var totals: Dictionary = GameState.get_totals()
	var limits: Dictionary = GameState.get_limits()
	var rocket_name: String = Data.story["launch_vehicles"][GameState.get_launch_vehicle_id()]["name"]
	if category() == "instruments":
		for instrument_id in GameState.get_missing_key_instruments():
			var instrument: Dictionary = Data.story["instruments"][GameState.get_destination_key()][instrument_id]
			lines.append("- " + review["blockers"]["key_instrument"].format({"instrument": instrument["name"], "needed_for": instrument.get("needed_for", "")}))
	for res_id in GameState.get_failed_resources():
		lines.append("- " + review["blockers"][res_id].format({
			"value": GameState.fmt(totals[res_id]), "limit": GameState.fmt(limits[res_id]["value"]),
			"unit": Data.resources[res_id]["unit"], "rocket": rocket_name,
		}))
	return lines


# One spotlight follows the picked pedestal (better lighting on the choice).
var select_light: SpotLight3D

func aim_select_light(target: Node3D) -> void:
	if select_light == null:
		select_light = SpotLight3D.new()
		select_light.light_energy = 2.5
		select_light.spot_range = 6.0
		select_light.spot_angle = 18.0
		select_light.shadow_enabled = false
		add_child(select_light)
	select_light.visible = true
	select_light.global_position = target.global_position + Vector3(0, 3.5, 1.2)
	select_light.look_at(target.global_position + Vector3(0, 0.8, 0), Vector3.UP)


func refresh_pedestals() -> void:
	if select_light != null:
		select_light.visible = false
	var current = get_value(category())
	for i in pedestals.size():
		var p: Dictionary = pedestals[i]
		if p.has("blocked"):
			continue
		var lit: bool
		if category() == "instruments":
			lit = GameState.is_instrument_packed(p["id"])
		else:
			lit = previewed and str(current) == p["id"]
		p["ring"].visible = lit
		# The picked one rises a little and grows (emphasis: "we chose this one").
		p["holder"].scale = Vector3.ONE * float(p["holder"].get_meta("base_scale", 1.0)) * (float(settings.get("selected_scale", 1.12)) if lit else 1.0)
		p["holder"].position.y = float(p["holder"].get_meta("base_y", 0.0)) + (float(settings.get("selected_lift", 0.0)) if lit else 0.0)
		if lit and category() != "instruments":
			aim_select_light(p["root"])
		if p.has("plate"):
			set_plate_picked(p["plate"], lit)


# ---------- player input ----------

func _on_area_entered(body: Node3D, area: Area3D) -> void:
	if body != player:
		return
	if area.get_meta("tag") == "console":
		near_console = true
	else:
		near_pedestal = area.get_meta("index")
	update_prompt()
	refresh_wall()   # the left screen shows the option you walked up to (V5 Step 1)


func _on_area_exited(body: Node3D, area: Area3D) -> void:
	if body != player:
		return
	if area.get_meta("tag") == "console":
		near_console = false
	elif near_pedestal == area.get_meta("index"):
		near_pedestal = -1
	update_prompt()
	refresh_wall()


func _unhandled_input(event: InputEvent) -> void:
	if busy:
		return
	var clicked: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("interact") or clicked:
		if clicked and tap_target != "":
			tap_part()   # aiming at a part of the spacecraft: a click tells its job (E still confirms)
		elif near_pedestal >= 0 and near_pedestal < pedestals.size():
			preview(near_pedestal)
		elif near_console:
			confirm()
		elif event.is_action_pressed("interact") and crew_near != null:
			ask_crew()
	elif event.is_action_pressed("confirm"):
		confirm()
	elif event.is_action_pressed("go_back"):
		go_back()
	elif party_votes() and Party.mode == "bots" and event is InputEventKey and event.pressed and not event.echo and event.keycode == OS.find_keycode_from_string(str(Data.mp["debug"]["fake_vote_key"])):
		Party.cast_fake_vote(get_value(category()))   # test key: a fake human vote (MULTIPLAYER_PLAN_V6 A4)
	elif event.is_action_pressed("office_hours") and room_kind == "design":
		# Office Hours: the MDL's name for a quick brainstorm; the inner voice gives a hint (N3).
		AudioManager.play_sfx("preview")
		inner_voice.say(GameState.office_hours_line())
	else:
		for i in 6:
			if event.is_action_pressed("preview_" + str(i + 1)) and i < pedestals.size():
				preview(i)


func preview(index: int) -> void:
	var cat: String = category()
	if index >= options.size():
		# A "won't work here" pedestal: say why, pick nothing (N4).
		var info: Dictionary = blocked[index - options.size()]
		AudioManager.play_sfx("bad")
		inner_voice.say(Data.story["nasa"]["not_possible_prompt"].format({"name": info["name"], "reason": info["reason"]}))
		return
	var id: String = options[index]
	if cat == "instruments":
		var packed: bool = not GameState.is_instrument_packed(id)
		GameState.set_instrument_packed(id, packed)
		AudioManager.play_sfx("pickup" if packed else "cancel")
	else:
		set_value(cat, id)
		previewed = true
		AudioManager.play_sfx("preview")
		if cat == "character":
			player.set_avatar(id)
			inner_voice.update_portrait()
			inner_voice.say(Data.voice["setup"]["character"][id])
		elif cat == "mission":
			inner_voice.say(Data.story["destinations"][id]["description"])
		elif cat == "rocket":
			inner_voice.say(Data.story["launch_vehicles"][id]["description"])
	refresh_pedestals()   # the picked plates turn amber (packed instruments too)
	refresh_display()
	refresh_wall()
	update_prompt()


func update_prompt() -> void:
	# The 3D CONFIRM sign shows only before a preview; after it the waypoint
	# marker points at the console instead (never both, they would overlap).
	if console_tag != null:
		console_tag.visible = false   # ROOM_LAYOUT_PLAN_V5: never floating text in the middle
	update_confirm_mark()
	if busy:
		prompt_label.text = ""
		return
	var cat: String = category()
	if near_pedestal >= 0 and near_pedestal < pedestals.size():
		var id: String = pedestals[near_pedestal]["id"]
		if pedestals[near_pedestal].has("blocked"):
			var info: Dictionary = pedestals[near_pedestal]["blocked"]
			prompt_label.text = Data.story["nasa"]["not_possible_prompt"].format({"name": info["name"], "reason": info["reason"]})
		elif cat == "instruments":
			prompt_label.text = words["prompt_toggle_off" if GameState.is_instrument_packed(id) else "prompt_toggle_on"].format({"name": option_name(cat, id)})
		else:
			prompt_label.text = words["prompt_preview"].format({"name": option_name(cat, id)})
	elif near_console:
		if cat == "instruments":
			prompt_label.text = words["prompt_confirm_instruments"]
		elif previewed:
			prompt_label.text = words["prompt_confirm"].format({"name": option_name(cat, str(get_value(cat)))})
		else:
			prompt_label.text = words["prompt_pick_first"]
		if tap_target != "":
			prompt_label.text += "\n" + Data.story["extras"]["tap_part"]["hint"] + ": " + tap_target_name()
	elif crew_near != null:
		prompt_label.text = Data.story["extras"]["ask_crew"]["prompt"]
	elif tap_target != "":
		prompt_label.text = Data.story["extras"]["tap_part"]["hint"] + ": " + tap_target_name()
	else:
		prompt_label.text = ""


# The watermark shows once a choice is picked (instruments: always, it says "when done packing").
func update_confirm_mark() -> void:
	if confirm_mark == null:
		return
	var cat: String = category()
	var picked: bool = previewed and str(get_value(cat)) != ""
	confirm_pill.visible = picked and not busy
	confirm_mark.text = words["confirm_mark_instruments" if cat == "instruments" else "confirm_mark"]


func confirm() -> void:
	var cat: String = category()
	if not previewed or str(get_value(cat)) == "":
		AudioManager.play_sfx("cancel")
		prompt_label.text = words["prompt_pick_first"]
		return
	if cat == "mission" and Data.destinations[get_value(cat)]["locked"]["value"]:
		AudioManager.play_sfx("bad")
		prompt_label.text = words["prompt_locked"]
		return
	if party_votes():
		# In a party, Enter is my vote; the party's pick comes back in _on_vote_done.
		if not Party.vote_open:
			return
		AudioManager.play_sfx("confirm")
		Party.cast_vote(cat, get_value(cat))
		refresh_votes()
		return
	finish_confirm()


# The choice is final (solo: Enter; party: the vote ended).
func finish_confirm() -> void:
	var cat: String = category()
	AudioManager.play_sfx("confirm")
	snapshot = get_value(cat)
	report_cml(cat)
	if display_model != null:
		var pop := display_model.create_tween()
		var base: Vector3 = display_model.scale
		pop.tween_property(display_model, "scale", base * 1.15, 0.1)
		pop.tween_property(display_model, "scale", base, 0.15)
		AudioManager.play_sfx("snap")
	match cat:
		"character":
			play_hired_moment()
		"mission":
			busy = true
			update_prompt()
			inner_voice.say(Data.voice["setup"]["goal"][snapshot][GameState.level])
			leave_after(float(settings["read_seconds"]))
		_:
			say_confirm_line(cat)
			if cat_index + 1 >= categories.size():
				busy = true
				update_prompt()
				leave_after(float(settings["read_seconds"]) * 0.6)
			else:
				load_category(cat_index + 1)


# ---------- party votes (MULTIPLAYER_PLAN_V6 3b) ----------
# Every choice after the party forms is a vote. Preview with 1/2/3 as always;
# Enter locks my vote (it can change until the vote ends). Party.gd counts the
# votes; the dots over the nameplates and the top line show how it is going.

var vote_label: Label


func party_votes() -> bool:
	return Party.is_party() and room_kind != "character"


func build_vote_ui() -> void:
	Party.votes_changed.connect(_on_votes_changed)
	Party.vote_done.connect(_on_vote_done)
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"HintPanel"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.anchor_left = 0.5
	chip.anchor_right = 0.5
	chip.offset_top = 16
	chip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	inner_voice.get_parent().add_child(chip)   # the UI layer
	vote_label = Label.new()
	vote_label.theme_type_variation = &"AccentText"
	vote_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(vote_label)


func _on_votes_changed(cat: String) -> void:
	if is_inside_tree() and cat == category():
		refresh_votes()


func refresh_votes() -> void:
	if vote_label == null:
		return
	var cat: String = category()
	var party_words: Dictionary = Data.story["party"]
	var tally: Dictionary = Party.vote_tally(cat)
	for p in pedestals:
		if p.has("dots"):
			var count: int = int(tally.get(p["id"], 0))
			var tied_out: bool = Party.vote_round > 0 and not Party.vote_options.has(p["id"])
			(p["dots"] as Label3D).text = "" if tied_out else "●".repeat(count)
	var lines: PackedStringArray = []
	lines.append(party_words["votes_in"].format({"count": Party.vote_count(cat), "total": Party.human_seats().size(), "seconds": maxi(int(ceil(Party.vote_left)), 0)}))
	var mine = Party.my_vote(cat)
	if Party.vote_round > 0:
		lines.append(party_words["revote"])
	elif mine != null:
		lines.append(party_words["vote_locked"].format({"name": category_name(cat) if mine is Array else option_name(cat, str(mine))}))
	else:
		lines.append(party_words["vote_hint_instruments" if cat == "instruments" else "vote_hint"])
	vote_label.text = "\n".join(lines)


func _process_votes() -> void:
	if vote_label != null and Party.vote_open and not busy:
		refresh_votes()


# The vote ended: the party's pick snaps on and everyone moves on together.
func _on_vote_done(cat: String, value, how: String) -> void:
	if not is_inside_tree() or cat != category() or busy:
		return
	set_value(cat, value)
	previewed = true
	refresh_pedestals()
	refresh_display()
	refresh_wall()
	var party_words: Dictionary = Data.story["party"]
	var picked: String = category_name(cat) if value is Array else option_name(cat, str(value))
	Hud.flash(party_words["vote_coin" if how == "coin" else "vote_win"].format({"name": picked}))
	finish_confirm()


# The Concept Maturity Level meter (N2): what this confirm means for the idea.
func report_cml(cat: String) -> void:
	if cat == "mission":
		GameState.cml_event("mission_picked")
		return
	if room_kind != "design":
		return
	# CML 2: rocket and orbit chosen, and the spacecraft (with its orbit fuel) fits the rocket.
	var past_orbit: bool = categories.find(cat) >= categories.find("orbit")
	if past_orbit and not GameState.get_failed_resources().has("mass"):
		GameState.cml_event("fit_check")
	# CML 3: the player changed a part after seeing the ripple effect.
	if is_part(cat) or cat == "instruments":
		var now = get_value(cat)
		var changed: bool = (now != first_value) if not now is Array else (now.size() != first_value.size() or now.any(func(x): return not first_value.has(x)))
		if changed:
			GameState.cml_event("trade_off")


# Which of NASA's mission segments this station belongs to (N2).
func get_segment() -> String:
	if room_kind != "design":
		return ""
	return "launch" if ["rocket", "orbit", "launch_window"].has(category()) else "space"


func discipline(cat: String) -> String:
	return Data.story["nasa"]["disciplines"].get(cat, category_name(cat))


func say_confirm_line(cat: String) -> void:
	var setup: Dictionary = Data.voice["setup"]
	if cat == "rocket":
		inner_voice.say(setup["rocket"][snapshot][GameState.level])
	elif cat == "orbit":
		inner_voice.say(setup["orbit"][GameState.get_destination_key()][snapshot][GameState.level])
	else:
		var picked: String = category_name(cat) if cat == "instruments" else option_name(cat, str(snapshot))
		inner_voice.say(words["confirmed"].format({"name": picked}))


# Backspace: back one choice. The current preview is undone first.
func go_back() -> void:
	if busy:
		return   # the room is already leaving
	if cat_index == 0 or party_votes():   # a party moves forward together (no going back)
		AudioManager.play_sfx("cancel")
		return
	set_value(category(), snapshot)
	AudioManager.play_sfx("cancel")
	load_category(cat_index - 1)


func leave_after(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	if is_inside_tree():
		StageManager.go_next()


# ---------- the "You're hired" moment (about 5 seconds) ----------

func play_hired_moment() -> void:
	busy = true
	update_prompt()
	player.frozen = true
	var index: int = options.find(snapshot)
	var spot: Vector3 = pedestals[index]["root"].global_position
	var lift: float = float(settings.get("character_pedestal_height", 0.35)) - 0.35   # taller pedestals since V5
	spot.y += lift
	hired_target = spot + Vector3(0, 1.4, 0)
	# The camera swings from the player to the chosen character.
	hired_camera = Camera3D.new()
	add_child(hired_camera)
	hired_camera.global_transform = get_viewport().get_camera_3d().global_transform
	hired_camera.current = true
	var swing := create_tween()
	swing.tween_property(hired_camera, "global_position", spot + Vector3(0.6, 1.8, 3.4), 1.2).set_trans(Tween.TRANS_SINE)
	# The General says one line.
	var player_name: String = GameState.player_name if GameState.player_name != "" else Data.story["characters"][snapshot]["name"]
	inner_voice.set_speaker(words["general_name"], "general")
	inner_voice.say(words["hired_line"].format({"name": player_name}))
	if general != null and general.has_method("talk"):
		general.talk(1.5)
	# Clear the clutter: the other labels and the prompt hide, so the moment reads clearly.
	for p in pedestals:
		p["label"].visible = false
	prompt_label.text = ""
	# A name tag stamps on over the character, and a big HIRED card stamps onto the screen.
	await get_tree().create_timer(1.4).timeout
	var tag := MeshKit.label(self, words["hired_tag"].format({"name": player_name}), hired_target + Vector3(0, 1.0, 0), 0.008, Color(1, 0.85, 0.3))
	tag.scale = Vector3.ONE * 2.5
	var stamp := create_tween()
	stamp.tween_property(tag, "scale", Vector3.ONE, 0.18)
	show_hired_card(player_name)
	AudioManager.play_sfx("stamp")
	await get_tree().create_timer(float(settings["hired_seconds"]) - 1.4).timeout
	if is_inside_tree():
		StageManager.go_next()


# The confirmation on screen: a paper card with the portrait, a red HIRED stamp
# and "From now on, you are the Janitor." It stamps in (big, then settles).
func show_hired_card(player_name: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 330       # low on the screen, so the character's face stays in view
	center.offset_bottom = -150   # above the voice bar
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var card := PanelContainer.new()
	card.theme_type_variation = &"PaperPanel"
	center.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	card.add_child(row)
	var portrait := TextureRect.new()
	portrait.texture = Portraits.get_texture(snapshot)
	portrait.custom_minimum_size = Vector2(150, 150)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	row.add_child(portrait)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(column)
	var stamp_label := Label.new()
	stamp_label.theme_type_variation = &"StampText"
	stamp_label.text = words["hired_stamp"]
	column.add_child(stamp_label)
	var name_label := Label.new()
	name_label.theme_type_variation = &"PaperTitle"
	name_label.text = player_name
	column.add_child(name_label)
	var line := Label.new()
	line.theme_type_variation = &"PaperText"
	line.text = words["hired_card"].format({"character": Data.story["characters"][snapshot]["name"]})
	column.add_child(line)
	# Stamp in: start big, then settle (the pivot is the card's middle).
	card.resized.connect(func(): card.pivot_offset = card.size / 2.0)
	card.scale = Vector2.ONE * 1.8
	card.modulate.a = 0.0
	var pop := card.create_tween().set_parallel(true)
	pop.tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(card, "modulate:a", 1.0, 0.12)


# ---------- the Hud (tablet map, waypoints, goal) ----------

func get_tablet_map() -> Dictionary:
	var size: Array = settings["room_size"]
	var points: Array = []
	for p in pedestals:
		var point_label: String = p["blocked"]["name"] if p.has("blocked") else option_name(category(), p["id"])
		points.append({"pos": p["root"].global_position, "label": point_label})
	points.append({"pos": console.global_position, "label": words["console_label"]})
	return {
		"player": player.global_position, "yaw": player.rotation.y, "center": Vector3.ZERO,
		"rooms": [{"name": words["room_names"][room_kind], "rect": Rect2(-size[0] / 2.0, -size[1] / 2.0, size[0], size[1])}],
		"points": points,
	}


func get_goal_text() -> String:
	return words["goal_text"].format({"name": category_name(category()).to_lower()})


# The Q card (UPGRADE_PLAN_V3 A2): the pedestal you stand at, else this station's word.
func get_question_id() -> String:
	if busy:
		return ""
	var option_id: String = ""
	if near_pedestal >= 0 and near_pedestal < pedestals.size() and not pedestals[near_pedestal].has("blocked"):
		option_id = pedestals[near_pedestal]["id"]
	return GameState.question_for(category(), option_id)


func get_waypoints() -> Array:
	# ROOM_LAYOUT_PLAN_V5 Step 2: no floating "CONFIRM · 8 m" marker in the middle
	# of the view; the ring on the picked pedestal and the hint bar say it.
	return []
