# start_menu.gd
# The first screen (UPGRADE_PLAN_V2 step 7). Behind it, a 3D backdrop: the
# rocket on the pad at dawn, next to a white tower and two tall masts, the sea
# and a low sun, with soft floating dust. The camera circles slowly.
# In front: the title, three lines of story, and the buttons
# Start, Leaderboard, Controls, Settings (volume sliders) and Credits.
# Browsers block sound until the first click, so the music starts then.
# Numbers: game_data.json "start_menu". Words: story.json "start_menu".
extends Node3D

var settings: Dictionary
var camera: Camera3D
var angle: float = 0.0
var music_started: bool = false


func _ready() -> void:
	settings = Data.game_data["start_menu"]
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	build_world()
	build_menu()


# ---------- the 3D backdrop ----------

func build_world() -> void:
	LaunchPad.build(self, settings)   # the pad at dawn (shared with the launch)
	var rocket: Node3D = load("res://scenes/rockets/rocket_" + settings["rocket"] + ".tscn").instantiate()
	rocket.position.y = 1.0
	add_child(rocket)

	camera = Camera3D.new()
	camera.fov = 55
	add_child(camera)
	camera.current = true
	place_camera()


func _process(delta: float) -> void:
	angle += delta * TAU / float(settings["camera_orbit_seconds"])
	place_camera()


func place_camera() -> void:
	var radius: float = settings["camera_radius"]
	camera.position = Vector3(sin(angle) * radius, settings["camera_height"], cos(angle) * radius)
	camera.look_at(Vector3(0, settings["look_height"], 0), Vector3.UP)


# ---------- the menu ----------

func build_menu() -> void:
	var words: Dictionary = Data.story["start_menu"]
	var layer := CanvasLayer.new()
	add_child(layer)
	# A dark band on the left so the words stay easy to read over the sky.
	# UI_POLISH_PLAN_V4 Step 5: a soft navy gradient (dark on the left, clear by
	# the middle) instead of a hard dark rectangle, so the rocket still shows.
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	var navy: Color = (ThemeDB.get_project_theme().get_stylebox("panel", &"ScreenBackground") as StyleBoxFlat).bg_color
	gradient.set_color(0, Color(navy, 0.85))
	gradient.set_color(1, Color(navy, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 4
	shade.texture = texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.anchor_bottom = 1.0
	shade.offset_right = 760
	layer.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_top", 80)
	margin.add_theme_constant_override("margin_bottom", 48)
	layer.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	margin.add_child(column)

	var title := Label.new()
	title.text = words["title"]
	title.theme_type_variation = &"TitleText"
	column.add_child(title)
	for line in words["story"]:
		var story := Label.new()
		story.text = line
		story.theme_type_variation = &"BodyText"
		column.add_child(story)
	var gap := Control.new()
	gap.custom_minimum_size.y = 24
	column.add_child(gap)

	var start := add_menu_button(column, words["start"], _on_start_pressed)
	start.custom_minimum_size = Vector2(360, 60)
	start.theme_type_variation = &""
	start.grab_focus()
	add_menu_button(column, words["leaderboard"], Hud.open_page.bind("leaderboard"))
	add_menu_button(column, words["controls"], Hud.open_page.bind("controls"))
	add_menu_button(column, words["settings"], Hud.open_page.bind("settings"))
	add_menu_button(column, words["credits"], Hud.open_page.bind("credits"))

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(filler)
	var team := Label.new()
	team.text = words["team_line"]
	team.theme_type_variation = &"SmallText"
	column.add_child(team)


func add_menu_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(300, 48)
	button.theme_type_variation = &"SmallButton"   # Start is changed back to the big orange button
	button.pressed.connect(action)
	button.pressed.connect(start_music)
	parent.add_child(button)
	return button


# The first click unlocks sound in the browser, so start the menu music then.
func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventKey) and event.pressed:
		start_music()


func start_music() -> void:
	if not music_started:
		music_started = true
		AudioManager.play_music("menu")


func _on_start_pressed() -> void:
	AudioManager.play_sfx("confirm")
	GameState.start_new_mission()
	StageManager.go_next()
