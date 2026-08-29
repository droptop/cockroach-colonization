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


## Where each banked baby CAME FROM (BACKLOG item 23) — the shop grid's rows.
## The chain order doubles as the matrix's row order, and as the order losses
## drain from: babies die with him mid-level and come back as ghosts, so the
## ledger has to absorb the count going DOWN too, and the newest rescues are
## the ones still trailing at the back when it does.
const LEVEL_CHAIN := ["drain_level", "street_level", "kitchen_level",
	"counter_level", "granny_kitchen_level", "tabletop_level", "pantry_level",
	"roof_level", "roof_garden_level", "tree_level", "abduction_level"]

## Which level's ledger row gains credit for new babies. Set by every level on
## load; not persisted — it is context, not progress. Writers with no context
## (tests, tools) credit "unknown".
static var _provenance_hint := ""


static func set_provenance_hint(level_id: String) -> void:
	_provenance_hint = level_id


static func babies_by_level() -> Dictionary:
	return _data().get_value("progress", "babies_by_level", {})


## The TOTAL stays the one source of truth every caller already relies on;
## the per-level ledger is reconciled against it here, on every write, so the
## two can never drift apart.
static func set_babies_banked(count: int) -> void:
	var old_total := babies_banked()
	var ledger := babies_by_level().duplicate()
	var diff := count - old_total
	if diff > 0:
		var credit := _provenance_hint if _provenance_hint != "" else "unknown"
		ledger[credit] = int(ledger.get(credit, 0)) + diff
	elif diff < 0:
		var to_shed := -diff
		var order := LEVEL_CHAIN.duplicate()
		order.reverse()
		order.append("unknown")
		for level_id in order:
			if to_shed <= 0:
				break
			var here := int(ledger.get(level_id, 0))
			var shed := mini(here, to_shed)
			if shed > 0:
				ledger[level_id] = here - shed
				to_shed -= shed
	_data().set_value("progress", "babies_banked", count)
	_data().set_value("progress", "babies_by_level", ledger)
	flush()


# --- coins and upgrades ------------------------------------------------------
# Run-scoped by inheritance: NEW GAME calls clear(), which wipes these along
# with everything else, and nothing else ever resets them — so a purchase
# survives death and level chaining, exactly as decided (BACKLOG item 25).

static func coins() -> int:
	return _data().get_value("progress", "coins", 0)


static func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	_data().set_value("progress", "coins", coins() + amount)
	# EARNED runs up forever within the run; spending never touches it. The
	# leaderboard scores this one, so buying at the stash cannot cost points.
	_data().set_value("progress", "coins_earned", coins_earned() + amount)
	flush()


static func coins_earned() -> int:
	return _data().get_value("progress", "coins_earned", 0)


## Returns whether the spend happened. A shop that could drive the balance
## negative would be a shop that silently gives things away.
static func spend_coins(amount: int) -> bool:
	if amount < 0 or coins() < amount:
		return false
	_data().set_value("progress", "coins", coins() - amount)
	flush()
	return true


static func upgrade_level(id: String) -> int:
	return _data().get_value("upgrades", id, 0)


static func set_upgrade_level(id: String, level: int) -> void:
	_data().set_value("upgrades", id, level)
	flush()


# --- achievements ------------------------------------------------------------

static func has_achievement(id: String) -> bool:
	return _data().get_value("achievements", id, false)


static func mark_achievement(id: String) -> void:
	_data().set_value("achievements", id, true)
	flush()
