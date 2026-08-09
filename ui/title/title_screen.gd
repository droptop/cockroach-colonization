extends Control

## Intro screen: COCKROACH COLONISATION — A COLECLAN GAME.
## Any key or tap starts the game.

const FIRST_LEVEL := "res://world/levels/drain_level.tscn"

var _starting := false

@onready var _prompt: Label = $Prompt


func _ready() -> void:
	Snd.music("res://audio/music/lanterns_in_the_drain.mp3")
	var tween := create_tween().set_loops()
	tween.tween_property(_prompt, "modulate:a", 0.25, 0.9).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_prompt, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)


func _unhandled_input(event: InputEvent) -> void:
	if _starting:
		return
	var pressed: bool = (event is InputEventKey and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if pressed:
		_start()


func _start() -> void:
	_starting = true
	Snd.sfx("complete")
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file(FIRST_LEVEL))
