extends Node

## Global signal bus + session flags. Deliberately tiny in Phase 1 — systems talk
## to a player *instance*, not this singleton, so co-op stays possible later.

signal level_completed

var debug_enabled := false


func complete_level() -> void:
	level_completed.emit()
