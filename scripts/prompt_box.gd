# prompt_box.gd
# The "E: do this" line at the bottom of the 3D screens (Choice Rooms, ship,
# arrival). It sits on a dark box, so it reads on light walls and bright sand,
# and it stays ABOVE the voice bar, so nothing covers it. The box hides itself
# when the text is empty.
#     const PROMPT_BOX = preload("res://scripts/prompt_box.gd")
#     var box = PROMPT_BOX.new()
#     layer.add_child(box)          # a CanvasLayer (or a full-screen Control)
#     prompt_label = box.label      # then just set prompt_label.text
extends PanelContainer

const BOTTOM_GAP := 172.0   # pixels from the bottom of the screen: just above the voice bar

var label: Label


func _init() -> void:
	theme_type_variation = &"HintPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_top = -BOTTOM_GAP
	offset_bottom = -BOTTOM_GAP
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN   # grows upward from just above the voice bar
	label = Label.new()
	label.theme_type_variation = &"HeadingText"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	visible = false


func _process(_delta: float) -> void:
	visible = label.text != ""
