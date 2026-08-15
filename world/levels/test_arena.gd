extends Node2D

## Phase 1 test arena: wires the player to spawn point, hazards, exit and camera limits.

@export var camera_limits := Rect2(-100, -150, 2840, 850)

@onready var _player: Player = $Player
@onready var _hud: CanvasLayer = $HUD


func _ready() -> void:
	_player.spawn_position = $SpawnPoint.global_position
	_player.global_position = _player.spawn_position

	var camera: Camera2D = $Player/Camera2D
	camera.limit_left = int(camera_limits.position.x)
	camera.limit_top = int(camera_limits.position.y)
	camera.limit_right = int(camera_limits.end.x)
	camera.limit_bottom = int(camera_limits.end.y)
	camera.reset_smoothing()

	$DeathZone.body_entered.connect(_on_death_zone_body_entered)
	$ExitZone.body_entered.connect(_on_exit_zone_body_entered)
	_hud.show_message("Reach the crack that leads to the pantry -->", 3.0)


func _on_death_zone_body_entered(body: Node2D) -> void:
	if body is Player:
		body.fall_into_pit()


func _on_exit_zone_body_entered(body: Node2D) -> void:
	if body is Player:
		$ExitZone.set_deferred("monitoring", false)
		var gm := get_node_or_null("/root/GameManager")
		if gm:
			gm.complete_level()
		_hud.show_message("LEVEL COMPLETE — the pantry awaits!", 0.0)
