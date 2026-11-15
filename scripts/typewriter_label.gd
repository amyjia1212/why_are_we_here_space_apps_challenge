# typewriter_label.gd
# TypewriterLabel (UPGRADE_PLAN_V3 B3): ONE reusable piece for text that types
# itself out, letter by letter, while the speaker "talks" in beeps
# (AudioManager.talk). Used by the Mission Briefing cards, Mission School,
# the Q cards (Hud) and the inner-voice bar.
#
# As a node (it is a RichTextLabel, so [b]bold[/b] key words work):
#     const TYPEWRITER = preload("res://scripts/typewriter_label.gd")
#     var line = TYPEWRITER.new()
#     line.type_text("Hello there", "general")
#     line.finish()          # show the whole line now (Enter once)
#     line.is_typing()       # still typing?
#     line.typed             # signal: the line is fully shown
# On any other Label or RichTextLabel (the inner-voice bar does this):
#     TYPEWRITER.type_into(label, "Hello", "general")
extends RichTextLabel

signal typed

const LETTERS_PER_SECOND := 60.0

var tween: Tween


func _init() -> void:
	bbcode_enabled = true
	fit_content = true
	scroll_active = false
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# Types new_text out. key = whose beep voice ("" = the player's character).
func type_text(new_text: String, key: String = "", letters_per_second: float = LETTERS_PER_SECOND) -> void:
	if tween:
		tween.kill()
	text = new_text
	tween = type_into(self, new_text, key, letters_per_second)
	tween.finished.connect(func(): typed.emit())


# Shows the whole line at once (and stops the beeps).
func finish() -> void:
	if tween:
		tween.kill()
		tween = null
	if visible_ratio < 1.0:
		visible_ratio = 1.0
		AudioManager.stop_talk()
		typed.emit()


func is_typing() -> bool:
	return visible_ratio < 1.0


# The typing itself, for any Label or RichTextLabel. Gives back the Tween.
static func type_into(node: Control, new_text: String, key: String = "", letters_per_second: float = LETTERS_PER_SECOND) -> Tween:
	var plain: String = new_text
	if node is RichTextLabel:
		node.text = new_text
		plain = (node as RichTextLabel).get_parsed_text()
	else:
		node.set("text", new_text)
	node.set("visible_ratio", 0.0)
	var t: Tween = node.create_tween()
	t.tween_property(node, "visible_ratio", 1.0, maxf(plain.length(), 1) / letters_per_second)
	var speaker: String = key if key != "" else GameState.character_id
	AudioManager.talk(speaker, plain, letters_per_second)
	return t
