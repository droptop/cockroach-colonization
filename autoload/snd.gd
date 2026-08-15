class_name Snd
extends Object

## Static audio facade. Gameplay code calls Snd.* instead of the AudioManager
## autoload directly, so scripts still compile and run in contexts where
## autoloads aren't registered (e.g. the SceneTree --script test harness).


static func _manager() -> Node:
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		return (main_loop as SceneTree).root.get_node_or_null("AudioManager")
	return null


static func sfx(sfx_name: String, volume_db := 0.0, pitch_jitter := 0.08) -> void:
	var manager := _manager()
	if manager:
		manager.play_sfx(sfx_name, volume_db, pitch_jitter)


static func music(path: String) -> void:
	var manager := _manager()
	if manager:
		manager.play_music(path)


static func wings(active: bool) -> void:
	var manager := _manager()
	if manager:
		manager.set_wings_active(active)


# --- settings ----------------------------------------------------------------
# Gameplay and UI go through here, never at AudioManager directly, so the
# whole lot still compiles under the test harness.

static func music_enabled() -> bool:
	return Settings.music_enabled()


static func sfx_enabled() -> bool:
	return Settings.sfx_enabled()


## Applies immediately and persists. Safe with no AudioManager present (tests):
## the preference is still written, there is simply no bus to mute.
static func set_music_enabled(enabled: bool) -> void:
	var manager := _manager()
	if manager:
		manager.set_music_enabled(enabled)
	else:
		Settings.set_music_enabled(enabled)


static func set_sfx_enabled(enabled: bool) -> void:
	var manager := _manager()
	if manager:
		manager.set_sfx_enabled(enabled)
	else:
		Settings.set_sfx_enabled(enabled)
