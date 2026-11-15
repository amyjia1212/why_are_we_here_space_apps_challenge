# spacecraft_model.gd
# The player's spacecraft, built from their choices, WITH an inside
# (UPGRADE_PLAN_V2 step 15). The gold shell can turn see-through ("Inside"
# view) to show the battery, the computer, the fuel tanks, the pointing
# wheels, the antenna and every packed instrument.
#     build()                    rebuild from GameState (call after a choice changes)
#     set_inside(true)           see-through shell
#     highlight("battery", "Battery: Large")   the part glows, with a label
# Sizes and colors: game_data.json "spacecraft_model".
class_name SpacecraftModel
extends Node3D

var look: Dictionary
var holders: Dictionary = {}     # category id -> Node3D (structure, battery, instruments...)
var shell: MeshInstance3D
var inside: bool = false
var label: Label3D
var lit: String = ""


func _ready() -> void:
	build()


# The size step of a choice: the first card 0.8, the second 1.0, the third 1.25.
func size_step(part_id: String) -> float:
	var versions: Array = Data.parts[part_id]["versions"].keys()
	var index: int = versions.find(GameState.choices.get(part_id, versions[0]))
	return [0.8, 1.0, 1.25][clampi(index, 0, 2)]


func build() -> void:
	for child in get_children():
		child.queue_free()
	holders.clear()
	look = Data.game_data["spacecraft_model"]
	GameState.fill_default_choices()
	var body: Vector3 = MeshKit.vec3(look["body_size"])

	var shell_color := Color(look["shell_color"])
	shell = MeshKit.box(self, body, Vector3.ZERO, shell_color)
	Textures.apply(shell.material_override, Data.game_data["spacecraft_base"]["look"]["texture"])

	# The frame: four corner posts, thicker for a bigger structure.
	var frame := holder("structure")
	var post: float = 0.06 * size_step("structure")
	for x in [-1, 1]:
		for z in [-1, 1]:
			MeshKit.box(frame, Vector3(post, body.y * 1.04, post), Vector3(x * body.x / 2.0, 0, z * body.z / 2.0), Color(look["structure"]["color"]))

	# Solar panels: two wings on arms (sizes from the part's look in the data).
	var solar := holder("solar_panel")
	var wing: Array = Data.parts["solar_panel"]["versions"][GameState.choices["solar_panel"]]["look"]["size"]
	for side in [-1, 1]:
		MeshKit.box(solar, Vector3(0.4, 0.06, 0.06), Vector3(side * (body.x / 2.0 + 0.2), 0, 0), Color(0.6, 0.6, 0.6))
		var panel := MeshKit.box(solar, Vector3(wing[0] * 0.6, wing[1], wing[2] * 0.6), Vector3(side * (body.x / 2.0 + 0.4 + wing[0] * 0.3), 0, 0), Color(Data.parts["solar_panel"]["look"]["color"]))
		Textures.apply(panel.material_override, Data.parts["solar_panel"]["look"]["texture"])

	# The antenna dish on top.
	var antenna := holder("antenna")
	var dish: Array = Data.parts["antenna"]["versions"][GameState.choices["antenna"]]["look"]["size"]
	MeshKit.cylinder(antenna, 0.05, 0.05, 0.35, Vector3(0, body.y / 2.0 + 0.17, 0), Color(0.7, 0.7, 0.7), 8)
	MeshKit.lathe(antenna, [Vector2(0.04, 0.0), Vector2(dish[0] * 0.5, dish[1] * 0.2), Vector2(dish[0], dish[1])], Vector3(0, body.y / 2.0 + 0.35, 0), Color(Data.parts["antenna"]["look"]["color"]), 0.0, TAU, 16)

	# Heat control: panels on the front and back (radiators bigger, heaters small).
	var thermal := holder("thermal_control")
	var heat: float = size_step("thermal_control")
	for z in [-1, 1]:
		MeshKit.box(thermal, Vector3(body.x * 0.6 * heat, body.y * 0.5 * heat, 0.04), Vector3(0, 0, z * (body.z / 2.0 + 0.03)), Color(look["thermal_control"]["color"]))

	# Inside: battery, computer, tanks, pointing wheels.
	var battery := holder("battery")
	var b: Dictionary = look["battery"]
	MeshKit.box(battery, MeshKit.vec3(b["size"]) * size_step("battery"), MeshKit.vec3(b["pos"]), Color(b["color"]))
	var computer := holder("computer")
	var c: Dictionary = look["computer"]
	MeshKit.box(computer, MeshKit.vec3(c["size"]) * size_step("computer"), MeshKit.vec3(c["pos"]), Color(c["color"]))
	MeshKit.add(computer, SphereMesh.new(), MeshKit.vec3(c["pos"]) + Vector3(0, 0.12, 0.18), MeshKit.glow(Color(0.3, 1.0, 0.4))).scale = Vector3.ONE * 0.06
	var tanks := holder("tanks")
	for spot in look["tanks"]["spots"]:
		MeshKit.sphere(tanks, look["tanks"]["radius"], MeshKit.vec3(spot), Color(look["tanks"]["color"]), 12)
	var wheels := holder("attitude_control")
	var wheel_count: int = int(round(size_step("attitude_control") * 2.4))   # 2, 2 or 3 wheels
	for i in mini(wheel_count, look["attitude_control"]["spots"].size()):
		var w := MeshKit.cylinder(wheels, look["attitude_control"]["radius"], look["attitude_control"]["radius"], 0.08, MeshKit.vec3(look["attitude_control"]["spots"][i]), Color(look["attitude_control"]["color"]), 12)
		w.rotation.z = PI / 2.0 * (i % 2)

	# Instruments: one small box each under the body, in its own color.
	var instruments := holder("instruments")
	var packed: Array = GameState.instruments_packed
	var colors: Array = look["instrument_colors"]
	var all_ids: Array = GameState.get_instruments().keys()
	for i in all_ids.size():
		var instrument_id: String = all_ids[i]
		var one := Node3D.new()
		one.name = instrument_id
		instruments.add_child(one)
		holders["instrument:" + instrument_id] = one
		one.visible = packed.has(instrument_id)
		var x: float = lerpf(-body.x * 0.35, body.x * 0.35, float(i) / maxf(all_ids.size() - 1, 1))
		MeshKit.box(one, Vector3(0.22, 0.22, 0.22), Vector3(x, -body.y / 2.0 - 0.12, 0.2), Color(colors[i % colors.size()]))
		MeshKit.cylinder(one, 0.06, 0.06, 0.14, Vector3(x, -body.y / 2.0 - 0.28, 0.2), Color(0.15, 0.15, 0.18), 8)

	label = MeshKit.label(self, "", Vector3(0, body.y / 2.0 + 1.3, 0), 0.006)
	label.visible = false
	set_inside(inside)
	if lit != "":
		highlight(lit, label.text)


func holder(category: String) -> Node3D:
	var node := Node3D.new()
	node.name = category
	add_child(node)
	holders[category] = node
	return node


# The see-through shell for the Inside view.
func set_inside(on: bool) -> void:
	inside = on
	if shell == null:
		return
	var mat: StandardMaterial3D = shell.material_override
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if on else BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.albedo_color.a = float(look["shell_alpha"]) if on else 1.0


# Make one part glow and show a label above it ("" = nothing glows).
func highlight(category: String, text: String = "") -> void:
	lit = category
	var glow_color := Color(look["glow_color"])
	for key in holders:
		var on: bool = key == category or (category == "instruments" and key.begins_with("instrument:"))
		for mesh in holders[key].find_children("*", "MeshInstance3D", true, false):
			var mat := (mesh as MeshInstance3D).material_override as StandardMaterial3D
			if mat == null:
				continue
			mat.emission_enabled = on
			mat.emission = glow_color
			mat.emission_energy_multiplier = 1.4
	label.text = text
	label.visible = text != ""
	if holders.has(category):
		var target: Node3D = holders[category]
		var box := AABB()
		for mesh in target.find_children("*", "MeshInstance3D", true, false):
			box = box.merge(AABB((mesh as MeshInstance3D).position - Vector3.ONE * 0.2, Vector3.ONE * 0.4))
		label.position = box.get_center() + Vector3(0, 1.2, 0)
