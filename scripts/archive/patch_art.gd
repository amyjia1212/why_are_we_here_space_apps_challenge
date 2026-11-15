# patch_art.gd
# Draws the player's mission patch (the "more stuff" list, 2026-11-14): a
# shape (circle, shield or hexagon) with a gold border, the picked color, a
# white icon (rocket, planet, star or moon) and the destination's name.
# Used as a Control on 2D screens (the patch maker, the report, the
# leaderboard), and as a picture on 3D things (the rocket's logo panel, the suit):
#     var art = PATCH_ART.new()            a Control that draws GameState's patch
#     PATCH_ART.make_texture(node, 256)    a picture of it for a 3D material
# Choices and colors: extras.json "patch". Words: story.json extras > patch.
extends Control

var patch: Dictionary = {}      # {} = GameState's patch
var caption: String = "-"       # "-" = the destination's name


func _ready() -> void:
	if theme == null:
		theme = ThemeDB.get_project_theme()
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_patch(self, Rect2(Vector2.ZERO, size), patch if not patch.is_empty() else GameState.get_patch(), caption_text())


func caption_text() -> String:
	if caption != "-":
		return caption
	return str(Data.story["destinations"][GameState.get_destination_key()]["name"]).to_upper()


# The outline of a shape, as points around rect's middle (scale 1 = fills rect).
static func shape_points(shape: String, rect: Rect2, scale: float) -> PackedVector2Array:
	var c: Vector2 = rect.get_center()
	var r: float = minf(rect.size.x, rect.size.y) / 2.0 * scale
	var points := PackedVector2Array()
	match shape:
		"shield":
			# Flat top, straight sides, then a rounded point at the bottom.
			points.append(c + Vector2(-0.85, -0.9) * r)
			points.append(c + Vector2(0.85, -0.9) * r)
			for k in 11:
				var t: float = float(k) / 10.0
				points.append(c + Vector2(0.85 * (1.0 - t * t), 0.1 + 0.9 * t) * r)
			for k in 10:
				var t: float = float(9 - k) / 10.0
				points.append(c + Vector2(-0.85 * (1.0 - t * t), 0.1 + 0.9 * t) * r)
		"hexagon":
			for k in 6:
				var a: float = PI / 6.0 + k * TAU / 6.0
				points.append(c + Vector2(cos(a), sin(a)) * r)
		_:
			for k in 48:
				var a: float = k * TAU / 48.0
				points.append(c + Vector2(cos(a), sin(a)) * r)
	return points


static func draw_patch(canvas: CanvasItem, rect: Rect2, patch: Dictionary, caption: String) -> void:
	var settings: Dictionary = Data.extras["patch"]
	var colors: Array = settings["colors"]
	var fill := Color(colors[clampi(int(patch.get("color", 0)), 0, colors.size() - 1)])
	var border := Color(settings["border_color"])
	var shape: String = patch.get("shape", "circle")
	canvas.draw_colored_polygon(shape_points(shape, rect, 1.0), border)
	canvas.draw_colored_polygon(shape_points(shape, rect, 0.86), fill)
	var c: Vector2 = rect.get_center() - Vector2(0, rect.size.y * 0.06)
	var s: float = minf(rect.size.x, rect.size.y) * 0.22
	draw_icon(canvas, patch.get("icon", "rocket"), c, s, fill)
	if caption != "":
		var font: Font = canvas.get_theme_default_font()
		var font_size: int = maxi(int(rect.size.y * 0.09), 8)
		var width: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		canvas.draw_string(font, Vector2(rect.get_center().x - width / 2.0, rect.position.y + rect.size.y * 0.74), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, border)


static func draw_icon(canvas: CanvasItem, icon: String, c: Vector2, s: float, fill: Color) -> void:
	var white := Color(1, 1, 1)
	match icon:
		"planet":
			canvas.draw_circle(c, s * 0.75, white)
			canvas.draw_set_transform(c, -0.35, Vector2(1.0, 0.32))
			canvas.draw_arc(Vector2.ZERO, s * 1.3, 0.0, TAU, 48, white, s * 0.22)
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"star":
			var points := PackedVector2Array()
			for k in 10:
				var a: float = -PI / 2.0 + k * PI / 5.0
				var radius: float = s * (1.1 if k % 2 == 0 else 0.45)
				points.append(c + Vector2(cos(a), sin(a)) * radius)
			canvas.draw_colored_polygon(points, white)
		"moon":
			canvas.draw_circle(c, s, white)
			canvas.draw_circle(c + Vector2(s * 0.45, -s * 0.2), s * 0.85, fill)
		_:
			# A little rocket: body, nose, two fins and a window.
			canvas.draw_rect(Rect2(c.x - s * 0.28, c.y - s * 0.6, s * 0.56, s * 1.3), white)
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.28, -s * 0.6), c + Vector2(s * 0.28, -s * 0.6), c + Vector2(0, -s * 1.2)]), white)
			for side in [-1.0, 1.0]:
				canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(side * s * 0.28, s * 0.25), c + Vector2(side * s * 0.7, s * 0.75), c + Vector2(side * s * 0.28, s * 0.7)]), white)
			canvas.draw_circle(c + Vector2(0, -s * 0.2), s * 0.15, fill)


# A picture of the patch for a 3D material. The SubViewport is added under
# owner (so it lives as long as the thing wearing the patch) and draws once.
static func make_texture(owner: Node, pixels: int) -> ViewportTexture:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(pixels, pixels)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	owner.add_child(viewport)
	var art = load("res://scripts/patch_art.gd").new()
	art.size = Vector2(pixels, pixels)
	viewport.add_child(art)
	return viewport.get_texture()


# A flat patch for a 3D thing: a square, meters wide, showing its +Z side.
static func make_quad(owner: Node3D, meters: float) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(meters, meters)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = make_texture(owner, int(Data.extras["patch"]["texture_pixels"]))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = mat
	owner.add_child(node)
	return node
