class_name SaveGame
extends Object

## Versioned save state, as a static facade over a ConfigFile in `user://`.
##
## Static rather than an autoload on purpose. Autoloads are not compile-time
## globals under the headless `--script` harness (the same trap documented on
## Snd), and none of this needs a node in the tree — it is a file and some
## accessors. Gameplay code calls SaveGame.* directly and works everywhere.
##
## Everything is cached in memory and only touches disk on `flush()`, so a level
## can ask `is_boss_defeated()` freely without hitting the filesystem.

const PATH := "user://save.cfg"
## Bump when the stored shape changes. A save from a different version is
## discarded rather than half-read: guessing at an old layout corrupts a real
## player's progress far more thoroughly than starting them over does.
const VERSION := 1

## Override the save location. Tests point this at a scratch file so they can
## never clobber a real player's progress.
static var save_path := PATH

static var _config: ConfigFile
static var _loaded := false


static func _data() -> ConfigFile:
	if _loaded and _config:
		return _config
	_config = ConfigFile.new()
	var err := _config.load(save_path)
	if err != OK:
		_reset_config()
	elif _config.get_value("meta", "version", 0) != VERSION:
		push_warning("Save version mismatch — starting fresh.")
		_reset_config()
	_loaded = true
	return _config


static func _reset_config() -> void:
	_config = ConfigFile.new()
	_config.set_value("meta", "version", VERSION)


## Drop the in-memory cache so the next read comes off disk. Mostly for tests
## and for a "the file changed underneath us" reload.
static func invalidate() -> void:
	_loaded = false
	_config = null


static func flush() -> void:
	var err := _data().save(save_path)
	if err != OK:
		push_warning("Could not write save to %s (error %d)" % [save_path, err])


## Wipe everything — new game.
static func clear() -> void:
	_reset_config()
	_loaded = true
	flush()


# --- bosses ------------------------------------------------------------------
# The point of persisting these: a boss beaten in an earlier session must not
# have to be fought again to get back through a gated exit.

static func is_boss_defeated(boss_id: String) -> bool:
	if boss_id == "":
		return false
	return _data().get_value("bosses", boss_id, false)


static func mark_boss_defeated(boss_id: String) -> void:
	if boss_id == "":
		return
	_data().set_value("bosses", boss_id, true)
	flush()


static func defeated_boss_count() -> int:
	var data := _data()
	if not data.has_section("bosses"):
		return 0
	var n := 0
	for key in data.get_section_keys("bosses"):
		if data.get_value("bosses", key, false):
			n += 1
	return n


# --- progress ----------------------------------------------------------------

## Deepest level the player has reached. Stored but not yet used to resume —
## see BACKLOG: how a run resumes is a design call, not a code one.
static func furthest_level() -> String:
	return _data().get_value("progress", "furthest_level", "")


static func set_furthest_level(scene_path: String) -> void:
	if scene_path == "":
		return
	_data().set_value("progress", "furthest_level", scene_path)
	flush()


static func babies_banked() -> int:
	return _data().get_value("progress", "babies_banked", 0)


static func set_babies_banked(count: int) -> void:
	_data().set_value("progress", "babies_banked", count)
	flush()


# --- achievements ------------------------------------------------------------

static func has_achievement(id: String) -> bool:
	return _data().get_value("achievements", id, false)


static func mark_achievement(id: String) -> void:
	_data().set_value("achievements", id, true)
	flush()
