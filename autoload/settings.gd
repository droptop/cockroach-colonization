class_name Settings
extends Object

## Player preferences, in their own file — deliberately NOT part of SaveGame.
## Starting a new game should not silently turn the music back on, and wiping
## progress should not reset how someone has set up their sound.
##
## Static like Snd and SaveGame, for the same reason: autoloads are not
## compile-time globals under the headless `--script` harness.

const PATH := "user://settings.cfg"

## Tests point this at a scratch file so they never clobber real preferences.
static var settings_path := PATH

static var _config: ConfigFile
static var _loaded := false


static func _data() -> ConfigFile:
	if _loaded and _config:
		return _config
	_config = ConfigFile.new()
	if _config.load(settings_path) != OK:
		_config = ConfigFile.new()
	_loaded = true
	return _config


static func invalidate() -> void:
	_loaded = false
	_config = null


static func _write(key: String, value: Variant) -> void:
	_data().set_value("audio", key, value)
	var err := _data().save(settings_path)
	if err != OK:
		push_warning("Could not write settings to %s (error %d)" % [settings_path, err])


## Both default ON: a fresh install should sound like the game, not like a
## muted one someone has to go and fix.
static func music_enabled() -> bool:
	return _data().get_value("audio", "music_enabled", true)


static func set_music_enabled(enabled: bool) -> void:
	_write("music_enabled", enabled)


static func sfx_enabled() -> bool:
	return _data().get_value("audio", "sfx_enabled", true)


static func set_sfx_enabled(enabled: bool) -> void:
	_write("sfx_enabled", enabled)
