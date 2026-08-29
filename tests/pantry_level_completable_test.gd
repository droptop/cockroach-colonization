extends "res://tests/support/level_completable.gd"

## Can the PANTRY be finished? The Toad, then out under the door to the ending.
##
## The Toad is the "what you FEED it" boss: immune to every attack, beaten by
## dropping poo bombs inside tongue range until its appetite is gone. This
## test presses the actual bomb button (glide / Z) — the bomb needs fullness,
## which the harness tops up the way it tops up health: the pantry's shelves
## carry the food economy for humans, and pre_fight_checks proves they exist.


func level_id() -> String:
	return "pantry_level"


func title() -> String:
	return "PANTRY"


func fight_timeout() -> float:
	return 60.0 # five gulps, each with its own little digestion pause


## The gorge half must actually offer the weight the level runs on.
func pre_fight_checks() -> void:
	var food := 0
	for child in level.get_children():
		var script: Script = child.get_script()
		if script and (script.resource_path.ends_with("food_crumb_3d.gd")
				or script.resource_path.ends_with("fruit_3d.gd")):
			food += 1
	# Scene-instanced pickups may carry their scene's root script; count
	# anything on the pickup layer as food-shaped too.
	if food == 0:
		for child in level.get_children():
			if child is Area3D and (child as Area3D).collision_layer & 16 != 0 \
					and not (child is RewardPickup3D):
				food += 1
	check(food >= 10, "the pantry is stocked (%d food pickups)" % food)


var _bomb_down := false


func fight(_delta: float) -> void:
	# Stand where the tongue can reach the drop, keep the weight on, and keep
	# pressing the one button this fight is about.
	stand_beside(boss, 3.2)
	player.fullness = 1.0
	player._bomb_cooldown_timer = 0.0
	_bomb_down = not _bomb_down
	if _bomb_down:
		Input.action_press("glide")
	else:
		Input.action_release("glide")
