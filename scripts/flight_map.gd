# flight_map.gd
# The map on the Flight screen: Earth on the left, the destination on the
# right, and the ship moving along a curved path between them.
# set_progress(0.0) = at Earth, set_progress(1.0) = arrived.
# Colors come from the theme ("FlightMap"), words from story.json.
extends Control

const EARTH_RADIUS := 26.0
const PLANET_RADIUS := 20.0
const SHIP_RADIUS := 9.0
const SIDE_GAP := 60.0      # space between the planets and the edges
const CURVE_POINTS := 48    # how smooth the path is

var progress: float = 0.0
var planet_name: String = ""
# Three views, like NASA's mission viewers (NASA_RESOURCES_PLAN.md N9):
# 0 = the whole trip, 1 = follow the ship, 2 = the destination. Keys 1/2/3 on the ship.
var view: int = 0
const ZOOM := 2.4


func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func set_view(new_view: int) -> void:
	view = clampi(new_view, 0, 2)
	clip_contents = true
	queue_redraw()


# A point on the curved path, 0 = Earth, 1 = the planet.
# (A "quadratic Bezier curve": it bends toward the control point at the top.)
func path_point(t: float) -> Vector2:
	var start := Vector2(SIDE_GAP, size.y * 0.62)
	var finish := Vector2(size.x - SIDE_GAP, size.y * 0.62)
	var bend := Vector2(size.x / 2.0, size.y * 0.02)
	return start.lerp(bend, t).lerp(bend.lerp(finish, t), t)


func _draw() -> void:
	var path_color: Color = get_theme_color("path_color", &"FlightMap")
	var done_color: Color = get_theme_color("path_done_color", &"FlightMap")
	var font: Font = get_theme_default_font()
	var font_size: int = get_theme_default_font_size()

	# The view's name in the corner, then zoom in on the ship or the planet.
	draw_string(font, Vector2(8, font_size + 2), Data.story["nasa"]["map_views"][view], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, done_color)
	if view > 0:
		var focus: Vector2 = path_point(progress if view == 1 else 1.0)
		draw_set_transform(size / 2.0 - focus * ZOOM, 0.0, Vector2.ONE * ZOOM)

	# The whole path, then the part already flown on top of it.
	var all_points := PackedVector2Array()
	var done_points := PackedVector2Array()
	for i in CURVE_POINTS + 1:
		var t: float = float(i) / CURVE_POINTS
		all_points.append(path_point(t))
		if t <= progress:
			done_points.append(path_point(t))
	done_points.append(path_point(progress))
	draw_polyline(all_points, path_color, 3.0, true)
	if done_points.size() >= 2:
		draw_polyline(done_points, done_color, 6.0, true)

	# The planets and their names.
	draw_planet(path_point(0.0), EARTH_RADIUS, get_theme_color("earth_color", &"FlightMap"), Data.story["flight_screen"]["earth"], font, font_size)
	draw_planet(path_point(1.0), PLANET_RADIUS, get_theme_color("planet_color", &"FlightMap"), planet_name, font, font_size)

	# The ship.
	draw_circle(path_point(progress), SHIP_RADIUS, get_theme_color("ship_color", &"FlightMap"))


func draw_planet(center: Vector2, radius: float, color: Color, label: String, font: Font, font_size: int) -> void:
	draw_circle(center, radius, color)
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, center + Vector2(-text_size.x / 2.0, radius + text_size.y), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, get_theme_color("font_color", &"SmallText"))
