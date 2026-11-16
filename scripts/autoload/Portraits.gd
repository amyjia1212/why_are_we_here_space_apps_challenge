# Portraits.gd
# Takes a picture of each character model (UPGRADE_PLAN_V2 step 10): the
# Scientist, the Janitor, the Student and the General. Each one is put in a
# small hidden 3D studio (a SubViewport), photographed once when the game
# starts, and saved to user://portraits/<id>.png.
#     Portraits.get_texture("janitor")  -> the picture (null until it is ready)
# The pictures are used in the dialogue boxes, the HUD corner, Your File and
# the leaderboard. Settings: game_data.json "portraits".
extends Node

signal portrait_ready(character_id: String)

var textures: Dictionary = {}   # character id -> ImageTexture
var studio: SubViewport
var camera: Camera3D
var holder: Node3D


func _ready() -> void:
	# A headless run (the self-check) draws nothing, so there is nothing to photograph.
	if DisplayServer.get_name() == "headless":
		return
	load_saved()
	build_studio()
	take_all.call_deferred()


# Pictures saved by an earlier run show at once, before the new ones are ready.
func load_saved() -> void:
	for character_id in Data.game_data["portraits"]["list"]:
		var path: String = "user://portraits/" + character_id + ".png"
		if FileAccess.file_exists(path):
			var image := Image.load_from_file(path)
			if image != null:
				textures[character_id] = ImageTexture.create_from_image(image)


func build_studio() -> void:
	var settings: Dictionary = Data.game_data["portraits"]
	studio = SubViewport.new()
	studio.size = Vector2i(int(settings["size"]), int(settings["size"]))
	studio.own_world_3d = true
	studio.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(studio)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(settings["background"])
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.82, 0.9)
	environment.ambient_light_energy = 0.7
	var world := WorldEnvironment.new()
	world.environment = environment
	studio.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, -35, 0)
	key.light_energy = 1.2
	studio.add_child(key)
	holder = Node3D.new()
	studio.add_child(holder)
	camera = Camera3D.new()
	camera.fov = settings["fov"]
	studio.add_child(camera)


# One character at a time: put it in the studio, draw one frame, keep the picture.
func take_all() -> void:
	var settings: Dictionary = Data.game_data["portraits"]
	DirAccess.make_dir_recursive_absolute("user://portraits")
	# The real astronauts too (UPGRADE_PLAN_V6 C1): ids "crew_<id>", one figure scene.
	var jobs: Dictionary = settings["list"].duplicate()
	for crew_id in Data.crew.get("people", {}):
		if Data.crew["people"][crew_id].get("show", false):
			jobs["crew_" + crew_id] = "res://scenes/characters/astronaut.tscn"
	for character_id in jobs:
		for child in holder.get_children():
			child.queue_free()
		var person: Node3D = load(jobs[character_id]).instantiate()
		if character_id.begins_with("crew_"):
			person.set("crew_id", character_id.substr(5))
		holder.add_child(person)
		for label in person.find_children("*", "Label3D", true, false):
			if (label as Label3D).billboard != BaseMaterial3D.BILLBOARD_DISABLED:
				label.visible = false   # no floating name in the picture
		person.set("idle_bob", false)
		person.rotation_degrees.y = 180.0 - 20.0   # face the camera, turned a little
		var height: float = float(person.get("height")) if person.get("height") != null else 1.8
		var look := Vector3(0, height * float(settings["camera_height"]), 0)
		camera.position = look + Vector3(0, 0.05, float(settings["distance"]))
		camera.look_at(look, Vector3.UP)
		studio.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var image: Image = studio.get_texture().get_image()
		if image == null or image.is_empty():
			continue
		textures[character_id] = ImageTexture.create_from_image(image)
		image.save_png("user://portraits/" + character_id + ".png")
		portrait_ready.emit(character_id)
	for child in holder.get_children():
		child.queue_free()


func get_texture(character_id: String) -> Texture2D:
	return textures.get(character_id, null)
