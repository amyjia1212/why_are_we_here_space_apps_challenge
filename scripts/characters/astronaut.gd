@tool
# astronaut.gd
# A real astronaut as a toy figure (UPGRADE_PLAN_V6 C1). The look comes from
# data/crew.json > people > <crew_id> > look: skin, hair style and color, suit
# color, older (gray hair, a little wider), female (a little smaller), beard,
# mustache, camera. A name tag sits on the chest and a small name floats over
# the head, so players know who it is at a glance. Set crew_id BEFORE the node
# enters the tree.
extends "res://scripts/characters/character_base.gd"

@export var crew_id: String = ""


func _ready() -> void:
	apply_look()
	super._ready()


# Body shape and colors from the data (before the shapes are built).
func apply_look() -> void:
	if crew_id == "" or Engine.is_editor_hint():
		return
	var person: Dictionary = Data.crew["people"].get(crew_id, {})
	var look: Dictionary = person.get("look", {})
	skin_color = Color(look.get("skin", "#e0b090"))
	body_color = Color(look.get("suit_color", "#2f5aa8"))
	var female: bool = look.get("female", false)
	var older: bool = look.get("older", false)
	height = 1.62 if female else 1.74
	top_width = 0.42 if female else 0.46
	bottom_width = (0.44 if older else 0.38) if not female else (0.42 if older else 0.36)
	idle_bob = true


func _build_extras() -> void:
	if crew_id == "" or Engine.is_editor_hint():
		return
	var person: Dictionary = Data.crew["people"].get(crew_id, {})
	var look: Dictionary = person.get("look", {})
	var hair := StandardMaterial3D.new()
	hair.albedo_color = Color(look.get("hair_color", "#333333"))
	hair.roughness = 0.9
	match str(look.get("hair_style", "short")):
		"buzz":
			cap_hair(hair, 0.55, 1.02)
		"short":
			cap_hair(hair, 0.35, 1.06)
			side_hair(hair, 0.55)
		"curly_short":
			cap_hair(hair, 0.25, 1.08)
			curls(hair)
		"ponytail":
			cap_hair(hair, 0.3, 1.05)
			side_hair(hair, 0.75)
			ponytail(hair)
		"bun":
			cap_hair(hair, 0.3, 1.05)
			bun(hair)
		"bald_fringe":
			fringe(hair)
	if look.get("beard", false):
		beard(hair)
	if look.get("mustache", false):
		add_mustache(0.8)
	if look.get("camera", false):
		camera_prop()
	name_tag(str(person.get("name", "")))


# A smooth hair cap over the top of the dome. from_y = where it starts (0 = mouth line).
func cap_hair(mat: Material, from_y: float, puff: float) -> void:
	var cap := SphereMesh.new()
	cap.radius = top_r * puff
	cap.height = top_r * puff
	cap.is_hemisphere = true
	cap.radial_segments = 24
	cap.rings = 8
	add_shape(lid, cap, mat, Vector3(0, from_y * dome_h, top_r * 0.08), Vector3(1, DOME_FRACTION * (1.0 - from_y * 0.6), 1))


# Hair down the sides and back of the head, to the chin or the shoulders.
func side_hair(mat: Material, length: float) -> void:
	var back := CylinderMesh.new()
	back.top_radius = top_r * 1.04
	back.bottom_radius = top_r * 1.06
	back.height = top_r * length
	back.radial_segments = 24
	back.rings = 1
	var node := add_shape(head, back, mat, Vector3(0, jaw_h - top_r * length * 0.35, top_r * 0.18))
	node.scale = Vector3(1.0, 1.0, 0.75)


func curls(mat: Material) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 16:
		var around := TAU * float(i) / 16.0
		var up := rng.randf_range(0.2, 0.75)
		var p := Vector3(cos(around) * top_r * 1.02 * sqrt(1.0 - up * up), up * dome_h, sin(around) * top_r * 1.02 * sqrt(1.0 - up * up))
		if p.z < -top_r * 0.6 and up < 0.5:
			continue   # keep the face clear
		var ball := SphereMesh.new()
		ball.radius = top_r * 0.24
		ball.height = top_r * 0.48
		add_shape(lid, ball, mat, p)


func ponytail(mat: Material) -> void:
	var tail := CapsuleMesh.new()
	tail.radius = top_r * 0.18
	tail.height = top_r * 1.2
	var node := add_shape(lid, tail, mat, Vector3(0, dome_h * 0.25, top_r * 1.05))
	node.rotation.x = 0.5


func bun(mat: Material) -> void:
	var ball := SphereMesh.new()
	ball.radius = top_r * 0.32
	ball.height = top_r * 0.64
	add_shape(lid, ball, mat, Vector3(0, dome_h * 0.75, top_r * 0.75))


# Older look with a bald top: a ring of gray hair around the back and sides.
func fringe(mat: Material) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = top_r * 0.9
	ring.outer_radius = top_r * 1.1
	ring.rings = 24
	ring.ring_segments = 8
	var node := add_shape(head, ring, mat, Vector3(0, jaw_h + dome_h * 0.15, top_r * 0.12))
	node.scale = Vector3(1, 0.6, 0.85)


func beard(mat: Material) -> void:
	var chin := SphereMesh.new()
	chin.radius = top_r * 0.95
	chin.height = top_r * 0.9
	var node := add_shape(head, chin, mat, Vector3(0, jaw_h * 0.35, -top_r * 0.12))
	node.scale = Vector3(1.0, 0.55, 0.95)


func camera_prop() -> void:
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.08, 0.08, 0.1)
	var body := BoxMesh.new()
	body.size = Vector3(0.16, 0.1, 0.07)
	add_shape(rig, body, black, Vector3(0, height * 0.62, -top_r - 0.04))
	var lens := CylinderMesh.new()
	lens.top_radius = 0.035
	lens.bottom_radius = 0.035
	lens.height = 0.06
	add_shape(rig, lens, black, Vector3(0, height * 0.62, -top_r - 0.1), Vector3.ONE, Vector3(PI / 2.0, 0, 0))


# A white name tag on the chest, and the name over the head.
func name_tag(text: String) -> void:
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.96, 0.96, 0.96)
	var tag := BoxMesh.new()
	tag.size = Vector3(top_r * 0.9, 0.07, 0.01)
	var chest_y: float = height * 0.58
	add_shape(rig, tag, white, Vector3(0, chest_y, -top_r * 0.98))
	var label := Label3D.new()
	label.text = text.get_slice(" ", text.get_slice_count(" ") - 1).to_upper()   # the family name, like a real name tag
	label.font_size = 24
	label.pixel_size = 0.0022
	label.modulate = Color(0.1, 0.12, 0.2)
	label.outline_size = 0
	label.position = Vector3(0, chest_y, -top_r * 0.98 - 0.008)
	label.rotation.y = PI
	label.set_meta("gen", true)
	rig.add_child(label)
	var over := Label3D.new()
	over.text = text
	over.font_size = 48
	over.pixel_size = 0.004
	over.outline_size = 10
	over.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	over.position = Vector3(0, height + 0.35, 0)
	over.set_meta("gen", true)
	rig.add_child(over)
