# rocket_model.gd
# A clean low-poly rocket built from parts (UPGRADE_PLAN_V2 step 15):
# engine bells, the first stage, a ring between the stages, the second stage,
# a nose cone (fairing) that splits in two, and two plain stripes.
# Each rocket (small = Falcon 9, medium = Atlas V 401, large = Atlas V 541)
# looks clearly different. Sizes and colors: game_data.json "rocket_models".
#
# There is one scene per rocket (scenes/rockets/), so the Art Designer can
# swap in a real model later: put a model scene path in "model" in the data.
#
# The launch uses these:
#   set_flame(0..1)        the engine flame (0 = off)
#   drop_first_stage()     the first stage falls away (gives back its node)
#   split_fairing()        the nose cone opens and the halves fly off
#   release_payload()      the spacecraft leaves (gives back its node)
class_name RocketModel
extends Node3D

@export var vehicle_id: String = "small":
	set(value):
		vehicle_id = value
		if is_inside_tree():
			build()

var look: Dictionary
var first_stage: Node3D       # falls away at staging
var upper: Node3D             # the second stage, the payload and the fairing
var payload: Node3D           # where the spacecraft sits, inside the fairing
var fairing_halves: Array = []
var flame: MeshInstance3D
var upper_flame: MeshInstance3D
var height: float = 0.0       # the whole rocket, bottom to nose tip


func _ready() -> void:
	build()


func build() -> void:
	for child in get_children():
		child.queue_free()
	fairing_halves.clear()
	look = Data.game_data["rocket_models"][vehicle_id]
	if look.get("model", "") != "" and ResourceLoader.exists(look["model"]):
		add_child(load(look["model"]).instantiate())
		return

	var body := Color(look["body_color"])
	var r: float = look["radius"]
	var h1: float = look["first_height"]
	var ring_h: float = look["interstage_height"]
	var h2: float = look["second_height"]

	# ----- first stage -----
	first_stage = Node3D.new()
	first_stage.name = "FirstStage"
	add_child(first_stage)
	var bell_h: float = look["bell_height"]
	MeshKit.cylinder(first_stage, r, r, h1, Vector3(0, bell_h + h1 / 2.0, 0), body)
	# Two plain stripes (the mission patch and its logo panel were removed,
	# UPGRADE_PLAN_V3 A1: the second stripe sits where the panel was).
	MeshKit.cylinder(first_stage, r * 1.01, r * 1.01, look["stripe_height"], Vector3(0, bell_h + h1 * 0.78, 0), Color(look["stripe_color"]))
	MeshKit.cylinder(first_stage, r * 1.01, r * 1.01, float(look["stripe_height"]) * 0.5, Vector3(0, bell_h + h1 * 0.55, 0), Color(look["logo_color"]))
	# Engine bells under the first stage.
	var bells: int = look["engines"]
	for i in bells:
		var spot := Vector3.ZERO
		if bells == 2:
			spot = Vector3((i - 0.5) * r * 0.8, 0, 0)   # two bells side by side
		elif bells > 2 and i > 0:
			var angle: float = TAU * (i - 1) / (bells - 1)   # one in the middle, the rest in a ring
			spot = Vector3(cos(angle), 0, sin(angle)) * r * 0.6
		var bell_r: float = look["bell_radius"]
		MeshKit.lathe(first_stage, [Vector2(bell_r, 0.0), Vector2(bell_r * 0.75, bell_h * 0.5), Vector2(bell_r * 0.4, bell_h)], spot, Color(look["bell_color"]), 0.0, TAU, 12)
	# Side boosters (the Atlas V 541 has four).
	var boosters: int = look.get("boosters", 0)
	for i in boosters:
		var angle: float = TAU * (i + 0.5) / boosters
		var br: float = look["booster_radius"]
		var bh: float = look["booster_height"]
		var spot := Vector3(cos(angle) * (r + br), 0, sin(angle) * (r + br))
		MeshKit.cylinder(first_stage, br, br, bh, spot + Vector3(0, bell_h * 0.5 + bh / 2.0, 0), Color(look["booster_color"]), 12)
		MeshKit.cylinder(first_stage, 0.0, br, br * 2.5, spot + Vector3(0, bell_h * 0.5 + bh + br * 1.25, 0), Color(look["booster_color"]), 12)
	# Landing legs folded along the side (the Falcon 9 lands and flies again).
	var legs: int = look.get("legs", 0)
	for i in legs:
		var angle: float = TAU * i / maxf(legs, 1) + PI / 4.0
		var leg := MeshKit.box(first_stage, Vector3(0.12, h1 * 0.22, 0.25), Vector3(cos(angle) * r * 1.02, bell_h + h1 * 0.12, sin(angle) * r * 1.02), Color(look["interstage_color"]))
		leg.rotation.y = -angle
	flame = MeshKit.add(first_stage, cone_mesh(r * 0.7, look["flame_length"]), Vector3(0, -look["flame_length"] / 2.0, 0), MeshKit.glow(Color(look["flame_color"]), 3.0))
	flame.rotation.x = PI
	flame.visible = false

	# ----- upper part: ring, second stage, payload, fairing -----
	upper = Node3D.new()
	upper.name = "Upper"
	upper.position.y = bell_h + h1
	add_child(upper)
	MeshKit.cylinder(upper, r, r, ring_h, Vector3(0, ring_h / 2.0, 0), Color(look["interstage_color"]))
	var r2: float = look["second_radius"]
	MeshKit.cylinder(upper, r2, r2, h2, Vector3(0, ring_h + h2 / 2.0, 0), Color(look["second_color"]))
	upper_flame = MeshKit.add(upper, cone_mesh(r2 * 0.5, look["flame_length"] * 0.5), Vector3(0, ring_h - look["flame_length"] * 0.25, 0), MeshKit.glow(Color(look["flame_color"]), 3.0))
	upper_flame.rotation.x = PI
	upper_flame.visible = false

	var fr: float = look["fairing_radius"]
	var fh: float = look["fairing_height"]
	var base_y: float = ring_h + h2
	payload = Node3D.new()
	payload.name = "Payload"
	payload.position.y = base_y + fh * 0.3
	upper.add_child(payload)
	# The fairing: a straight part, then an ogive nose, in two halves.
	var profile: Array = [Vector2(r2, 0.0), Vector2(fr, fh * 0.08), Vector2(fr, fh * 0.5)]
	for k in 6:
		var t: float = float(k + 1) / 6.0
		profile.append(Vector2(fr * cos(t * PI / 2.0), fh * 0.5 + fh * 0.5 * sin(t * PI / 2.0)))
	for half in 2:
		var holder := Node3D.new()
		holder.position.y = base_y
		upper.add_child(holder)
		var a0: float = PI / 2.0 + PI * half
		MeshKit.lathe(holder, profile, Vector3.ZERO, Color(look["fairing_color"]), a0, a0 + PI, 16)
		fairing_halves.append(holder)
	height = bell_h + h1 + ring_h + h2 + fh


func cone_mesh(radius: float, length: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 12
	return mesh


# 0 = no flame, 1 = full flame. A little flicker every frame.
func set_flame(strength: float, upper_stage: bool = false) -> void:
	var node: MeshInstance3D = upper_flame if upper_stage else flame
	if node == null:
		return
	node.visible = strength > 0.01
	node.scale = Vector3(1.0, maxf(strength, 0.01) * randf_range(0.85, 1.1), 1.0)


func drop_first_stage() -> Node3D:
	var stage := first_stage
	var world_transform := stage.global_transform
	remove_child(stage)
	get_parent().add_child(stage)
	stage.global_transform = world_transform
	first_stage = null
	return stage


# The two halves swing open and drift away.
func split_fairing() -> void:
	for i in fairing_halves.size():
		var half: Node3D = fairing_halves[i]
		var side: float = -1.0 if i == 0 else 1.0
		var tween := half.create_tween().set_parallel(true)
		tween.tween_property(half, "rotation:z", -side * 0.9, 1.6)   # the top tips outward
		tween.tween_property(half, "position:x", side * 3.0, 2.0)
		tween.tween_property(half, "position:y", half.position.y - 2.0, 2.0)
		tween.chain().tween_callback(half.hide)


func release_payload() -> Node3D:
	var node := payload
	var world_transform := node.global_transform
	upper.remove_child(node)
	get_parent().add_child(node)
	node.global_transform = world_transform
	return node
