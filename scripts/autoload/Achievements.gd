# Achievements.gd
# The achievements (UPGRADE_PLAN_V6 C3): rewards for looking around, for doing
# things a certain way, and for every kind of ending.
#     Achievements.unlock("first_hunger")   earns one (a pop-up shows the first time)
#     Achievements.has("win_mars")
#     Achievements.check_report()           the report calls this: outcome achievements
# Saved on this computer: user://achievements.json. The list: data/achievements.json.
# Badge pictures are drawn in code (draw_badge), no downloaded images.
extends Node

const SAVE_PATH := "user://achievements.json"

var earned: Array = []
var questions_opened: int = 0   # Q cards opened this game (for "So Many Questions")
var toast: PanelContainer
var toast_title: Label
var toast_name: Label
var toast_badge: Control
var toast_tween: Tween
var toast_icon: String = "star"
var toast_color: Color = Color.WHITE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_earned()
	build_toast()


func load_earned() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if saved is Array:
		earned = saved


func save_earned() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(earned))


func has(id: String) -> bool:
	return earned.has(id)


func info(id: String) -> Dictionary:
	return Data.achievements.get("list", {}).get(id, {})


func unlock(id: String) -> void:
	if info(id).is_empty() or earned.has(id):
		return
	earned.append(id)
	save_earned()
	show_toast(id)


func count_text() -> String:
	return Data.story["achievements"]["count"].format({"got": earned.size(), "total": Data.achievements["order"].size()})


# Called by the Hud every time a Q card opens.
func question_opened() -> void:
	questions_opened += 1
	if questions_opened >= int(Data.achievements.get("curious_count", 10)):
		unlock("curious")


# The report: one achievement for every kind of ending (and a few skills).
func check_report() -> void:
	var success: bool = GameState.is_mission_success()
	if success:
		unlock("win_" + GameState.get_destination_key())
	if GameState.goals.size() > 0 and GameState.goals.values().all(func(s): return s == "done"):
		unlock("perfect_run")
	if not GameState.get_missing_key_instruments().is_empty():
		unlock("forgot_point")
	if GameState.get_failed_resources().has("budget"):
		unlock("over_budget")
	if int(GameState.get_report_score()["total"]) < int(Data.achievements.get("pretty_bad_below", 300)):
		unlock("pretty_bad")
	if GameState.get_launch_window_id() == "best":
		unlock("best_date")
	if GameState.quick_fixes.is_empty() and GameState.trips_flown > 0:
		unlock("no_quick_fix")
	if GameState.timing_results.size() > 0 and not GameState.timing_results.any(func(r): return str(r.get("result", "")) == "Miss"):
		unlock("perfect_launch")


# ---------- the pop-up ----------

func build_toast() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 70
	add_child(layer)
	toast = PanelContainer.new()
	toast.theme_type_variation = &"CardSelected"
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.anchor_left = 1.0
	toast.anchor_right = 1.0
	toast.offset_left = -400
	toast.offset_right = -16
	toast.offset_top = 96
	toast.modulate.a = 0.0
	layer.add_child(toast)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	toast.add_child(row)
	toast_badge = Control.new()
	toast_badge.custom_minimum_size = Vector2(64, 64)
	toast_badge.draw.connect(func(): draw_badge(toast_badge, Rect2(Vector2.ZERO, toast_badge.size), toast_icon, toast_color, true))
	row.add_child(toast_badge)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	row.add_child(column)
	toast_title = Label.new()
	toast_title.theme_type_variation = &"AccentText"
	toast_title.text = Data.story["achievements"]["toast_title"]
	column.add_child(toast_title)
	toast_name = Label.new()
	toast_name.theme_type_variation = &"HeadingText"
	toast_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_name.custom_minimum_size.x = 280
	column.add_child(toast_name)


func show_toast(id: String) -> void:
	var a: Dictionary = info(id)
	toast_name.text = a["name"]
	toast_icon = a.get("icon", "star")
	toast_color = Color(a.get("color", "#ffd700"))
	toast_badge.queue_redraw()
	AudioManager.play_sfx("done")
	if toast_tween:
		toast_tween.kill()
	toast_tween = toast.create_tween()
	toast_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	toast_tween.tween_property(toast, "modulate:a", 1.0, 0.2)
	toast_tween.tween_interval(float(Data.achievements.get("toast_seconds", 3.5)))
	toast_tween.tween_property(toast, "modulate:a", 0.0, 0.4)


# A round badge with a simple icon, drawn in code. Not earned = gray.
static func draw_badge(canvas: CanvasItem, rect: Rect2, icon: String, color: Color, got: bool) -> void:
	var c: Vector2 = rect.get_center()
	var r: float = minf(rect.size.x, rect.size.y) * 0.5
	var main: Color = color if got else Color(0.35, 0.38, 0.45)
	var ink := Color(0.08, 0.1, 0.18) if got else Color(0.22, 0.24, 0.3)
	canvas.draw_circle(c, r, main.darkened(0.35))
	canvas.draw_circle(c, r * 0.84, main)
	var s: float = r * 0.5
	match icon:
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var a: float = -PI / 2.0 + i * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * (s if i % 2 == 0 else s * 0.45))
			canvas.draw_colored_polygon(pts, ink)
		"planet":
			canvas.draw_circle(c, s * 0.7, ink)
			canvas.draw_arc(c, s * 1.1, -0.4, PI - 0.4, 24, ink, 3.0)
		"rocket":
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.4, s * 0.3), c + Vector2(-s * 0.4, s * 0.3)]), ink)
			canvas.draw_rect(Rect2(c + Vector2(-s * 0.4, s * 0.3), Vector2(s * 0.8, s * 0.5)), ink)
		"heart":
			canvas.draw_circle(c + Vector2(-s * 0.35, -s * 0.2), s * 0.42, ink)
			canvas.draw_circle(c + Vector2(s * 0.35, -s * 0.2), s * 0.42, ink)
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.75, -s * 0.05), c + Vector2(s * 0.75, -s * 0.05), c + Vector2(0, s * 0.8)]), ink)
		"drop":
			canvas.draw_circle(c + Vector2(0, s * 0.25), s * 0.5, ink)
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.8), c + Vector2(s * 0.48, s * 0.15), c + Vector2(-s * 0.48, s * 0.15)]), ink)
		"wind":
			for k in 3:
				canvas.draw_line(c + Vector2(-s * 0.8, (k - 1) * s * 0.5), c + Vector2(s * 0.8, (k - 1) * s * 0.5), ink, 4.0)
		"book":
			canvas.draw_rect(Rect2(c + Vector2(-s * 0.8, -s * 0.6), Vector2(s * 0.75, s * 1.2)), ink)
			canvas.draw_rect(Rect2(c + Vector2(s * 0.05, -s * 0.6), Vector2(s * 0.75, s * 1.2)), ink)
		"camera":
			canvas.draw_rect(Rect2(c + Vector2(-s * 0.8, -s * 0.45), Vector2(s * 1.6, s * 1.0)), ink)
			canvas.draw_circle(c + Vector2(0, s * 0.05), s * 0.32, main)
		"person":
			canvas.draw_circle(c + Vector2(0, -s * 0.45), s * 0.32, ink)
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.6, s * 0.75), c + Vector2(s * 0.6, s * 0.75), c + Vector2(s * 0.35, -s * 0.05), c + Vector2(-s * 0.35, -s * 0.05)]), ink)
		"wrench":
			canvas.draw_line(c + Vector2(-s * 0.6, s * 0.6), c + Vector2(s * 0.4, -s * 0.4), ink, 6.0)
			canvas.draw_circle(c + Vector2(s * 0.5, -s * 0.5), s * 0.3, ink)
		"skull":
			canvas.draw_circle(c + Vector2(0, -s * 0.15), s * 0.6, ink)
			canvas.draw_rect(Rect2(c + Vector2(-s * 0.35, s * 0.3), Vector2(s * 0.7, s * 0.4)), ink)
			canvas.draw_circle(c + Vector2(-s * 0.22, -s * 0.15), s * 0.15, main)
			canvas.draw_circle(c + Vector2(s * 0.22, -s * 0.15), s * 0.15, main)
		"trophy":
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.6, -s * 0.7), c + Vector2(s * 0.6, -s * 0.7), c + Vector2(s * 0.3, s * 0.1), c + Vector2(-s * 0.3, s * 0.1)]), ink)
			canvas.draw_rect(Rect2(c + Vector2(-s * 0.1, s * 0.1), Vector2(s * 0.2, s * 0.4)), ink)
			canvas.draw_rect(Rect2(c + Vector2(-s * 0.45, s * 0.5), Vector2(s * 0.9, s * 0.2)), ink)
		_:
			canvas.draw_circle(c, s * 0.5, ink)
