# mission_school.gd
# Mission School (UPGRADE_PLAN_V3 B4): a short lesson right after the
# briefing. The General stands at the wall screen like a teacher (the war
# room's grey materials and the General's model from the intro).
#   - six beats, one per resource: its tile lights up on the wall, and the
#     General says what it means and what YOUR limit is (read from the data
#     files, so it always matches the dashboard)
#   - the last beat: he swaps one part on the wall and the ripple effect
#     strip plays ("Touch one thing, and everything else moves.")
#   - Enter goes to the next beat. After the first time, S skips the lesson.
#     The tablet (Tab, then L) can replay it any time.
# This is also where "What you start with" lives now (the six limits on the
# wall, and the trip time).
# Words: story.json "mission_school". The typing: typewriter_label.gd.
extends Node3D

const TYPEWRITER = preload("res://scripts/typewriter_label.gd")

var words: Dictionary
var beats: Array = []          # resource ids, then "ripple"
var beat_index: int = -1
var lines: Array = []          # the beat's lines
var line_index: int = -1
var line_label = null          # TypewriterLabel
var fact_label: Label
var dots_label: Label
var hint_label: Label
var general: Node3D
var wall_viewport: SubViewport
var wall_root: Control
var leaving: bool = false


func _ready() -> void:
	if GameState.character_id == "":
		GameState.character_id = Data.game_data["setup"]["default_character"]
	if GameState.mission_id == "":
		GameState.mission_id = Data.missions.keys()[0]
	GameState.fill_default_choices()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	words = Data.story["mission_school"]
	beats = Data.resources.keys() + ["ripple"]
	build_room()
	build_ui()
	next_beat()


# ---------- the room ----------

func build_room() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.03, 0.04, 0.08)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.85, 0.95)
	environment.ambient_light_energy = 0.5
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var lamp := DirectionalLight3D.new()
	lamp.rotation_degrees = Vector3(-45, 25, 0)
	lamp.light_energy = 0.8
	add_child(lamp)
	# The war room's floor and wall materials (materials/*.tres).
	var floor_mesh := MeshKit.box(self, Vector3(16, 0.2, 12), Vector3(0, -0.1, 0), Color(0.3, 0.32, 0.36))
	floor_mesh.material_override = load("res://materials/grey_floor.tres")
	var wall := MeshKit.box(self, Vector3(16, 6, 0.3), Vector3(0, 3, -4.2), Color(0.5, 0.52, 0.56))
	wall.material_override = load("res://materials/grey_wall.tres")
	# The wall screen (a SubViewport with the six tiles).
	wall_viewport = SubViewport.new()
	wall_viewport.size = Vector2i(1280, 720)
	wall_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(wall_viewport)
	wall_root = Control.new()
	wall_root.size = Vector2(1280, 720)
	wall_root.theme = preload("res://scripts/ui_kit.gd").wall_theme(1.7)   # seen from far away (UI_POLISH_PLAN_V4)
	wall_viewport.add_child(wall_root)
	var quad := QuadMesh.new()
	quad.size = Vector2(6.4, 3.6)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = wall_viewport.get_texture()
	MeshKit.add(self, quad, Vector3(0.9, 2.5, -4.0), mat)
	MeshKit.box(self, Vector3(6.7, 3.9, 0.05), Vector3(0.9, 2.5, -4.04), Color(0.1, 0.12, 0.18))
	# The General, beside the screen, facing the class.
	general = load(Data.game_data["portraits"]["list"]["general"]).instantiate()
	add_child(general)
	# Facing the class (the character models face -z, so turn him around).
	general.position = Vector3(-3.0, 0, -2.6)
	general.rotation.y = deg_to_rad(160)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(-0.3, 2.2, 2.2)
	camera.look_at(Vector3(-0.1, 2.0, -3.5), Vector3.UP)
	camera.current = true


# ---------- the subtitle panel ----------

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"VoiceBar"
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -150   # under the Hud's Q ? sign (game_data.json hud > question_tag_bottom)
	# A floating rounded panel, like the voice bar everywhere else (UI_POLISH_PLAN_V4).
	panel.offset_left = 32
	panel.offset_right = -32
	panel.offset_bottom = -16
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	layer.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var speaker := Label.new()
	speaker.theme_type_variation = &"SpeakerName"
	speaker.text = words["speaker"]
	speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(speaker)
	dots_label = Label.new()
	dots_label.theme_type_variation = &"SmallText"
	top.add_child(dots_label)
	line_label = TYPEWRITER.new()
	line_label.theme_type_variation = &"CardRich"
	column.add_child(line_label)
	fact_label = Label.new()
	fact_label.theme_type_variation = &"TinyText"
	fact_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(fact_label)
	hint_label = Label.new()
	hint_label.theme_type_variation = &"TinyText"
	hint_label.text = words["skip_hint"] if GameState.school_seen else words["enter_hint"]
	column.add_child(hint_label)


# ---------- the beats ----------

func next_beat() -> void:
	beat_index += 1
	if beat_index >= beats.size():
		leave()
		return
	var beat: String = beats[beat_index]
	lines = beat_lines(beat)
	line_index = -1
	dots_label.text = words["beat_dots"].format({"n": beat_index + 1, "total": beats.size()})
	var fact: Dictionary = GameState.astronaut_fact_for("school_" + beat)
	fact_label.text = "" if fact.is_empty() else Data.story["question_card"]["astronaut_label"] + " " + GameState.astronaut_fact_line(fact)
	refresh_wall(beat)
	if general != null and general.has_method("talk"):
		general.talk(2.5)
	next_line()


# The two sentences of a beat, with this mission's real limits filled in.
func beat_lines(beat: String) -> Array:
	if beat == "ripple":
		return [words["ripple"]]
	var info: Dictionary = words["beats"][beat]
	var limit: Dictionary = GameState.get_limits()[beat]
	var blanks := {
		"value": GameState.fmt(limit["value"]),
		"unit": Data.resources[beat]["unit"],
		"rocket": Data.story["launch_vehicles"][GameState.get_launch_vehicle_id()]["name"],
	}
	return [info["meaning"], info["limit"].format(blanks)]


func next_line() -> void:
	line_index += 1
	if line_index >= lines.size():
		return
	# Both lines stay on screen: the second one is added under the first.
	var shown: String = ""
	for i in line_index:
		shown += lines[i] + " "
	line_label.type_text(shown + lines[line_index], "general")
	line_label.visible_ratio = float(shown.length()) / maxf(float((shown + lines[line_index]).length()), 1.0)
	# The same label types every line, so connect only once at a time.
	if not line_label.typed.is_connected(_on_line_typed):
		line_label.typed.connect(_on_line_typed, CONNECT_ONE_SHOT)


func _on_line_typed() -> void:
	if line_index + 1 < lines.size():
		await get_tree().create_timer(0.3).timeout
		if is_inside_tree() and line_index + 1 < lines.size() and not line_label.is_typing():
			next_line()


func _unhandled_input(event: InputEvent) -> void:
	if leaving:
		return
	if event.is_action_pressed("confirm") or event.is_action_pressed("jump"):
		get_viewport().set_input_as_handled()
		if line_label.is_typing() or line_index + 1 < lines.size():
			# Enter once: the whole beat shows.
			line_label.finish()
			line_index = lines.size() - 1
			line_label.text = " ".join(PackedStringArray(lines))
			line_label.visible_ratio = 1.0
		else:
			AudioManager.play_sfx("preview")
			next_beat()
	elif event.is_action_pressed("skip_lesson") and GameState.school_seen:
		get_viewport().set_input_as_handled()
		leave()


func leave() -> void:
	if leaving:
		return
	leaving = true
	GameState.school_seen = true
	AudioManager.stop_talk()
	StageManager.go_next()


# The Q card: the resource being taught.
func get_question_id() -> String:
	if beat_index >= 0 and beat_index < beats.size() and beats[beat_index] != "ripple":
		return beats[beat_index]
	return ""


# ---------- the wall screen ----------

func refresh_wall(beat: String) -> void:
	for child in wall_root.get_children():
		child.queue_free()
	var background := Panel.new()
	background.theme_type_variation = &"ScreenBackground"
	background.size = wall_root.size
	wall_root.add_child(background)
	var margin := MarginContainer.new()
	margin.size = wall_root.size
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	wall_root.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	margin.add_child(column)
	var title := Label.new()
	title.theme_type_variation = &"TitleText"
	title.text = words["title"]
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	column.add_child(grid)
	var limits: Dictionary = GameState.get_limits()
	for res_id in Data.resources:
		var tile := PanelContainer.new()
		tile.theme_type_variation = &"NavyPanel"
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # three equal tiles across the wall
		var lit: bool = res_id == beat
		tile.modulate = Color.WHITE if lit or beat == "ripple" else Color(1, 1, 1, 0.4)
		if lit:
			tile.theme_type_variation = &"CardSelected"   # the one lit tile: the theme's selected look
		grid.add_child(tile)
		var box := VBoxContainer.new()
		tile.add_child(box)
		var name_label := Label.new()
		name_label.theme_type_variation = &"HeadingText"
		name_label.text = Data.resources[res_id]["name"]
		box.add_child(name_label)
		var limit := Label.new()
		limit.theme_type_variation = &"BodyText"
		var rule_words: Dictionary = Data.story["choice_room"]
		limit.text = rule_words["limit_max" if limits[res_id]["rule"] == "max" else "limit_min"].format({"value": GameState.fmt(limits[res_id]["value"])}) + " " + Data.resources[res_id]["unit"]
		box.add_child(limit)
	if beat == "ripple":
		var ripple := RichTextLabel.new()
		ripple.bbcode_enabled = true
		ripple.fit_content = true
		ripple.theme_type_variation = &"CardRich"
		ripple.text = "[b]" + words["ripple_title"] + ":[/b] " + ripple_demo_text()
		column.add_child(ripple)
	else:
		var trip := Label.new()
		trip.theme_type_variation = &"BodyText"
		trip.text = words["trip_line"].format({"days": GameState.fmt(roundf(GameState.get_trip_days()))})
		column.add_child(trip)


# The ripple demo: the solar panel swapped for the biggest one, and what
# that does to the other numbers. The design is put back right after.
func ripple_demo_text() -> String:
	var text: Dictionary = Data.story["ripple"]
	var colors: Dictionary = Data.game_data["dashboard"]["colors"]
	var part_id: String = "solar_panel"
	var old_version: String = GameState.choices[part_id]
	var versions: Array = Data.parts[part_id]["versions"].keys()
	var new_version: String = versions[-1] if versions[-1] != old_version else versions[0]
	var before: Dictionary = GameState.get_totals()
	GameState.choices[part_id] = new_version
	var after: Dictionary = GameState.get_totals()
	GameState.choices[part_id] = old_version
	var pieces: PackedStringArray = [text["swap"].format({
		"part": Data.part_name(part_id), "new": Data.version_name(part_id, new_version), "old": Data.version_name(part_id, old_version),
	})]
	for step in GameState.get_ripple_steps(before, after):
		var amount: float = step["amount"]
		var line: String = text["change"].format({
			"resource": Data.resources[step["res_id"]]["name"],
			"amount": ("+" if amount > 0 else "") + GameState.fmt(amount),
			"unit": Data.resources[step["res_id"]]["unit"],
		})
		pieces.append("[color=%s]%s[/color]" % [colors["safe"] if step["good"] else colors["danger"], line])
	return text["arrow"].join(pieces)
