# ship_builder.gd
# Builds the ship interior from game_data.json "ship": five rooms and a
# hallway, doorways, windows with glass, orange wall stripes, ceiling lights,
# orange room signs, furniture and the station props.
# Used by the flight (scripts/flight.gd, with the glowing station pads) and by
# the Venus arrival (scripts/arrival.gd, without pads: the arrival has its own
# task spots), so both are the SAME ship (UPGRADE_PLAN_V2 step 21).
#     const SHIP_BUILDER = preload("res://scripts/ship_builder.gd")
#     var builder: Node3D = SHIP_BUILDER.new()
#     add_child(builder)
#     builder.build(true)        # true = add the station pads and labels
#     builder.room_rects         # room id -> Rect2 (x, z, width, depth)
#     builder.stations           # station id -> { "pos", "pad", "light", "label", "room" }
extends Node3D

const DIRECTIONS := {
	"north": Vector3(0, 0, -1), "south": Vector3(0, 0, 1),
	"east": Vector3(1, 0, 0), "west": Vector3(-1, 0, 0),
}

var ship: Dictionary
var height: float
var thickness: float
var room_rects: Dictionary = {}
var stations: Dictionary = {}


func build(with_pads: bool) -> void:
	ship = Data.game_data["ship"]
	height = ship["wall_height"]
	thickness = ship["wall_thickness"]
	for room_id in ship["rooms"]:
		var room: Dictionary = ship["rooms"][room_id]
		var rect := to_rect(room)
		room_rects[room_id] = rect
		build_room(rect, room["door"], room_id)
		add_ceiling_light(Vector3(rect.get_center().x, height - 0.05, rect.get_center().y))
		add_room_signs(room_id, rect, room["door"])
	build_hallway()
	for item in ship["decor"]:
		add_prop(item["type"], v2_to_v3(item["pos"]), DIRECTIONS[item["face"]])
	for station_id in ship["stations"]:
		var info: Dictionary = ship["stations"][station_id]
		var face: Vector3 = DIRECTIONS[info["face"]]
		add_prop(info["prop"], v2_to_v3(info["pos"]) + face * 1.0, face)
		if with_pads:
			add_pad(station_id)


# One room: floor, ceiling and four walls. The door side gets a doorway,
# an outside wall can get a window (game_data.json "ship" > "windows").
func build_room(rect: Rect2, door: String, room_id: String) -> void:
	add_floor_and_ceiling(rect)
	var half_door: float = ship["door_width"] / 2.0
	var sides := {
		"north": ["x", rect.position.y, rect.position.x, rect.end.x, rect.get_center().x],
		"south": ["x", rect.end.y, rect.position.x, rect.end.x, rect.get_center().x],
		"west": ["z", rect.position.x, rect.position.y, rect.end.y, rect.get_center().y],
		"east": ["z", rect.end.x, rect.position.y, rect.end.y, rect.get_center().y],
	}
	for side in sides:
		var s: Array = sides[side]
		var gaps: Array = []
		if side == door:
			gaps.append([s[4] - half_door, s[4] + half_door, 0.0, float(ship["door_height"])])
		for window in ship["windows"]:
			if window["room"] == room_id and window["wall"] == side:
				var half: float = float(window["width"]) / 2.0
				var c: float = float(window["center"])
				gaps.append([c - half, c + half, float(ship["window_bottom"]), float(ship["window_top"])])
		add_wall(s[0], s[1], s[2], s[3], gaps)


# The hallway: floor, ceiling and its two long walls. Where a room's door wall
# sits on the hallway's side, the hallway leaves that stretch out (the room's
# own wall, with its doorway, is already there).
func build_hallway() -> void:
	var rect := to_rect(ship["hallway"])
	add_floor_and_ceiling(rect)
	var east_gaps: Array = []
	var west_gaps: Array = []
	for room_id in ship["rooms"]:
		var room: Dictionary = ship["rooms"][room_id]
		var span: Array = [float(room["z"][0]), float(room["z"][1]), 0.0, height]
		if room["door"] == "west":
			east_gaps.append(span)
		elif room["door"] == "east":
			west_gaps.append(span)
	add_wall("z", rect.position.x, rect.position.y, rect.end.y, west_gaps)
	add_wall("z", rect.end.x, rect.position.y, rect.end.y, east_gaps)
	var count: int = ship["hallway_lights"]
	for i in count:
		add_ceiling_light(Vector3(rect.get_center().x, height - 0.05, lerpf(rect.position.y, rect.end.y, (i + 0.5) / count)))


# A wall along one line with holes in it. along = "x": runs left/right at z = at;
# along = "z": runs front/back at x = at. Each gap = [start, end, bottom, top]:
# a doorway has bottom 0, a window has wall below and above it.
func add_wall(along: String, at: float, from: float, to: float, gaps: Array) -> void:
	var pieces: Array = []   # [start, end, bottom, top]
	var start := from
	var sorted_gaps := gaps.duplicate()
	sorted_gaps.sort_custom(func(a, b): return a[0] < b[0])
	for gap in sorted_gaps:
		if gap[0] > start:
			pieces.append([start, float(gap[0]), 0.0, height])
		if gap[2] > 0.0:
			pieces.append([float(gap[0]), float(gap[1]), 0.0, float(gap[2])])
			add_glass(along, at, gap)
		if gap[3] < height:
			pieces.append([float(gap[0]), float(gap[1]), float(gap[3]), height])
		start = maxf(start, gap[1])
	if start < to:
		pieces.append([start, to, 0.0, height])
	var wall_color := Color(ship["wall_color"])
	var trim_color := Color(ship["trim_color"])
	for piece in pieces:
		var length: float = piece[1] - piece[0]
		if length <= 0.01:
			continue
		var middle: float = (piece[0] + piece[1]) / 2.0
		var size := Vector3(length, piece[3] - piece[2], thickness)
		var spot := Vector3(middle, (piece[2] + piece[3]) / 2.0, at)
		if along == "z":
			size = Vector3(thickness, piece[3] - piece[2], length)
			spot = Vector3(at, (piece[2] + piece[3]) / 2.0, middle)
		add_solid(size, spot, wall_color)
		# An orange stripe along the bottom of every wall (the ship's accent color).
		if piece[2] == 0.0 and piece[3] >= 0.5:
			var stripe := Vector3(size.x + 0.02, 0.12, size.z + 0.02)
			MeshKit.box(self, stripe, Vector3(spot.x, 0.35, spot.z), trim_color)


# A see-through pane in a window, so you can't fall out into space.
func add_glass(along: String, at: float, gap: Array) -> void:
	var length: float = gap[1] - gap[0]
	var size := Vector3(length, gap[3] - gap[2], 0.04)
	var spot := Vector3((gap[0] + gap[1]) / 2.0, (gap[2] + gap[3]) / 2.0, at)
	if along == "z":
		size = Vector3(0.04, gap[3] - gap[2], length)
		spot = Vector3(at, (gap[2] + gap[3]) / 2.0, (gap[0] + gap[1]) / 2.0)
	var body := add_body(size, spot)
	MeshKit.add(body, box_mesh(size), Vector3.ZERO, MeshKit.material(Color(0.6, 0.85, 1.0, 0.12), 0.0, 0.05))


func add_floor_and_ceiling(rect: Rect2) -> void:
	add_solid(Vector3(rect.size.x, 0.2, rect.size.y), Vector3(rect.get_center().x, -0.1, rect.get_center().y), Color(ship["floor_color"]))
	add_solid(Vector3(rect.size.x, 0.2, rect.size.y), Vector3(rect.get_center().x, height + 0.1, rect.get_center().y), Color(ship["ceiling_color"]))


# A box you bump into (walls, floors).
func add_solid(size: Vector3, spot: Vector3, color: Color) -> void:
	var body := add_body(size, spot)
	MeshKit.add(body, box_mesh(size), Vector3.ZERO, MeshKit.material(color))


func add_body(size: Vector3, spot: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	body.add_child(shape)
	body.position = spot
	add_child(body)
	return body


func box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func cylinder_mesh(radius: float, length: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 16
	return mesh


# A ceiling light: a glowing panel and a lamp. No shadows (browser speed).
func add_ceiling_light(spot: Vector3) -> void:
	MeshKit.add(self, box_mesh(Vector3(1.2, 0.05, 0.5)), spot, MeshKit.glow(Color(ship["light_color"]), 1.5))
	var light := OmniLight3D.new()
	light.position = spot - Vector3(0, 0.3, 0)
	light.light_color = Color(ship["light_color"])
	light.light_energy = ship["light_energy"]
	light.omni_range = ship["light_range"]
	light.shadow_enabled = false
	add_child(light)


# The room's name above its doorway, on both sides of the wall (orange 3D signs).
func add_room_signs(room_id: String, rect: Rect2, door: String) -> void:
	var spots := {
		"north": [Vector3(rect.get_center().x, 0, rect.position.y), Vector3(0, 0, -1)],
		"south": [Vector3(rect.get_center().x, 0, rect.end.y), Vector3(0, 0, 1)],
		"west": [Vector3(rect.position.x, 0, rect.get_center().y), Vector3(-1, 0, 0)],
		"east": [Vector3(rect.end.x, 0, rect.get_center().y), Vector3(1, 0, 0)],
	}
	var door_middle: Vector3 = spots[door][0]
	var out: Vector3 = spots[door][1]
	door_middle.y = (float(ship["door_height"]) + height) / 2.0
	for side in [out, -out]:
		var sign := Label3D.new()
		sign.text = Data.story["ship"]["room_names"][room_id]
		sign.font_size = 96
		# Softer door signs (UI_POLISH_PLAN_V4 Step 3a): smaller, a thin navy
		# outline instead of the thick black one, so they belong to the walls.
		sign.pixel_size = float(ship["sign_letter_size"]) * float(ship.get("sign_scale", 0.7)) / 96.0
		sign.modulate = Color(ship["sign_color"])
		sign.outline_size = 6
		sign.outline_modulate = Color(0.04, 0.086, 0.2, 0.9)
		sign.double_sided = false
		sign.position = door_middle + side * (thickness / 2.0 + 0.01)
		sign.rotation.y = atan2(side.x, side.z)
		add_child(sign)


# Furniture and station props, built from simple boxes. The front faces the
# player (opposite to `face`, the way the player looks when using it).
func add_prop(type: String, pos: Vector3, face: Vector3) -> void:
	var holder := Node3D.new()
	add_child(holder)
	holder.position = pos
	holder.rotation.y = atan2(-face.x, -face.z)   # local +Z (the front) points back at the player
	var prop_color := Color(ship["prop_color"])
	var accent := Color(ship["accent_color"])
	var trim := Color(ship["trim_color"])
	var dark := Color(ship["screen_color"])
	var block := Vector3(1.0, 1.0, 0.6)   # the size that blocks walking
	match type:
		"console":
			MeshKit.box(holder, Vector3(1.3, 0.9, 0.6), Vector3(0, 0.45, 0), prop_color)
			var screen := MeshKit.add(holder, box_mesh(Vector3(1.2, 0.05, 0.55)), Vector3(0, 0.95, 0.05), MeshKit.glow(accent, 0.9))
			screen.rotation.x = 0.45
			MeshKit.box(holder, Vector3(1.3, 0.06, 0.62), Vector3(0, 0.9, 0), trim)
			block = Vector3(1.3, 1.0, 0.6)
		"panel":
			MeshKit.box(holder, Vector3(1.1, 1.3, 0.16), Vector3(0, 1.4, -0.3), prop_color)
			for i in 3:
				MeshKit.add(holder, box_mesh(Vector3(0.18, 0.18, 0.04)), Vector3(-0.3 + i * 0.3, 1.6, -0.2), MeshKit.glow(trim if i == 1 else accent, 1.5))
			MeshKit.add(holder, box_mesh(Vector3(0.8, 0.35, 0.04)), Vector3(0, 1.15, -0.2), MeshKit.glow(dark, 0.5))
			block = Vector3(1.1, 2.0, 0.3)
		"tank":
			MeshKit.cylinder(holder, 0.45, 0.45, 1.8, Vector3(0, 0.9, 0), Color(ship["wall_color"]))
			MeshKit.add(holder, cylinder_mesh(0.47, 0.15), Vector3(0, 1.2, 0), MeshKit.glow(accent, 1.2))
			block = Vector3(1.0, 1.8, 1.0)
		"rack":
			MeshKit.box(holder, Vector3(1.0, 2.0, 0.5), Vector3(0, 1.0, 0), dark)
			for i in 4:
				MeshKit.add(holder, box_mesh(Vector3(0.8, 0.05, 0.02)), Vector3(0, 0.5 + i * 0.4, 0.26), MeshKit.glow(accent if i % 2 == 0 else trim, 1.3))
			block = Vector3(1.0, 2.0, 0.5)
		"crate":
			MeshKit.box(holder, Vector3(0.9, 0.7, 0.7), Vector3(0, 0.35, 0), trim.darkened(0.2))
			MeshKit.box(holder, Vector3(0.92, 0.08, 0.72), Vector3(0, 0.55, 0), prop_color)
			block = Vector3(0.9, 0.7, 0.7)
		"dish":
			MeshKit.cylinder(holder, 0.12, 0.2, 1.0, Vector3(0, 0.5, 0), prop_color)
			var dish := MeshKit.cylinder(holder, 0.75, 0.12, 0.25, Vector3(0, 1.25, 0), Color(ship["wall_color"]))
			dish.rotation.x = -0.7
			MeshKit.add(holder, cylinder_mesh(0.06, 0.4), Vector3(0, 1.45, 0.15), MeshKit.glow(accent, 1.5))
			block = Vector3(1.2, 1.6, 1.0)
		"seat":
			MeshKit.box(holder, Vector3(0.7, 0.5, 0.7), Vector3(0, 0.25, 0), dark)
			MeshKit.box(holder, Vector3(0.7, 0.9, 0.15), Vector3(0, 0.9, 0.3), trim)
			block = Vector3(0.7, 1.2, 0.8)
		"bench":
			MeshKit.box(holder, Vector3(2.4, 0.08, 0.8), Vector3(0, 0.9, 0), Color(ship["wall_color"]))
			MeshKit.box(holder, Vector3(2.2, 0.86, 0.7), Vector3(0, 0.43, 0), prop_color)
			MeshKit.add(holder, box_mesh(Vector3(0.35, 0.3, 0.3)), Vector3(-0.6, 1.1, 0), MeshKit.glow(accent, 0.8))
			MeshKit.cylinder(holder, 0.08, 0.1, 0.3, Vector3(0.5, 1.1, 0.1), trim)
			block = Vector3(2.4, 1.0, 0.8)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = block
	shape.position = Vector3(0, block.y / 2.0, 0)
	body.add_child(shape)
	holder.add_child(body)


# A station pad (flight only): a glowing square on the floor, a small light
# and a floating label one step toward the prop.
func add_pad(station_id: String) -> void:
	var info: Dictionary = ship["stations"][station_id]
	var pos: Vector3 = v2_to_v3(info["pos"])
	var face: Vector3 = DIRECTIONS[info["face"]]
	var size: float = ship["pad_size"]
	var pad := MeshKit.add(self, box_mesh(Vector3(size, 0.03, size)), pos + Vector3(0, 0.015, 0), MeshKit.glow(Color(ship["accent_color"]), ship["pad_glow"]))
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, 0.5, 0)
	light.light_color = Color(ship["accent_color"])
	light.light_energy = 0.8
	light.omni_range = 2.5
	light.shadow_enabled = false
	add_child(light)
	var label := MeshKit.label(self, Data.story["flight_ship"]["stations"][station_id]["label"], pos + Vector3(0, ship["label_height"], 0) + face * 0.6, float(ship["label_letter_size"]) / 48.0, Color(ship["accent_color"]))
	label.outline_size = 6
	label.outline_modulate = Color(0.04, 0.086, 0.2, 0.9)
	stations[station_id] = {"pos": pos, "pad": pad, "light": light, "label": label, "room": info["room"]}


func to_rect(box: Dictionary) -> Rect2:
	var x0: float = box["x"][0]
	var z0: float = box["z"][0]
	return Rect2(x0, z0, float(box["x"][1]) - x0, float(box["z"][1]) - z0)


func v2_to_v3(a: Array) -> Vector3:
	return Vector3(a[0], 0, a[1])
