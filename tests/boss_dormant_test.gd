extends SceneTree

## Does every boss WAIT for the player?
##
## This exists because four of them did not. `BaseBoss3D` declares a SIGNAL
## called `engaged` and keeps the actual flag in `_engaged`. The wasp, the dust
## worm, the janitor and the tripod each guarded their fight with
## `if not engaged: return`, and a signal is always truthy, so the guard never
## fired and all four were live from the first frame of their level:
##
##   - the War Tripod walked its arena and heat-rayed Harry at the Mars spawn,
##     53 m away and off-screen, a heart every four seconds
##   - the Janitor-Bot's suction dragged him across the whole ship
##   - the wasp laid its brood before anyone had reached the counter
##   - the dust worm hunted footsteps from the far end of the moon
##
## Every completability suite passed, because walking up to a boss engages it
## properly on the way. Nothing stood still at the spawn and watched.
##
## Two halves. The source scan catches the mistake itself in any script, for
## any signal. The idle watch catches the symptom however it is caused: park
## Harry at every spawn and require the boss to do nothing at all.
##
## Run with:
##   godot --headless --path . --script tests/boss_dormant_test.gd

const LEVELS := [
	"drain_level", "street_level", "kitchen_level",
	"counter_level", "granny_kitchen_level", "tabletop_level", "pantry_level", "roof_level",
	"roof_garden_level", "tree_level", "abduction_level", "moon_level", "ship_level", "mars_level",
]

## REAL seconds (idle frames run far faster than 60/s headless). Long enough
## for the wasp's first egg (6 s) and two heat rays.
const WATCH_SECONDS := 7.5
## A boss may breathe, bob and sway on the spot. It may not go anywhere.
const MAX_DRIFT := 0.6
## Levels with nothing else near the spawn, so ANY lost health is the boss's.
const QUIET_SPAWNS := ["moon_level", "ship_level", "mars_level"]
## Two bosses move before the fight ON PURPOSE: the rat paces its arena and the
## wasp hovers, leaning toward him. Level3D copes with a boss that wanders
## (it is put back inside its arena when the walls go up), so these are held
## to every other claim here but not to standing still.
const ROAMERS := ["kitchen_level", "counter_level"]
const SCAN_DIRS := ["res://enemies", "res://world", "res://player", "res://items", "res://ui", "res://autoload"]

var _index := -1
var _level: Node3D
var _player: Node3D
var _boss: Node3D
var _started_ms := 0
var _boss_start := Vector3.ZERO
var _health_start := 0.0
var _threats_start := 0
var _engaged_fired := false
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	SaveGame.save_path = "user://test_boss_dormant.cfg"
	SaveGame.clear()
	print("-- no script reads a signal as if it were a flag")
	_scan_sources()
	print("-- parked at the spawn, no boss starts without him")


## `if not engaged` where `engaged` is a signal: always false, never an error.
func _scan_sources() -> void:
	var scripts: Array[String] = []
	for dir in SCAN_DIRS:
		_gd_files(dir, scripts)
	var signals_of := {}
	var sig := RegEx.create_from_string("(?m)^signal\\s+(\\w+)")
	var parent := RegEx.create_from_string("(?m)^extends\\s+(\\w+)")
	var named := RegEx.create_from_string("(?m)^class_name\\s+(\\w+)")
	var text_of := {}
	var by_class := {}
	for path in scripts:
		var text := FileAccess.get_file_as_string(path)
		text_of[path] = text
		var names: Array[String] = []
		for found in sig.search_all(text):
			names.append(found.get_string(1))
		signals_of[path] = names
		var cls := named.search(text)
		if cls:
			by_class[cls.get_string(1)] = path
	var misuses: Array[String] = []
	for path in scripts:
		var text: String = text_of[path]
		# Its own signals, and everything inherited from a scripted parent.
		var names: Array[String] = []
		var at: String = path
		while at != "":
			names.append_array(signals_of[at])
			var up := parent.search(text_of[at])
			at = by_class.get(up.get_string(1), "") if up else ""
		for signal_name in names:
			var as_flag := RegEx.create_from_string(
				"(?m)^[^#\\n]*\\b(if|elif|while|not|and|or)\\s+%s\\b(?!\\s*[.(\\[])" % signal_name)
			for found in as_flag.search_all(text):
				misuses.append("%s: \"%s\"" % [path.get_file(), found.get_string().strip_edges()])
	_check(misuses.is_empty(), "%d scripts scanned, no signal used as a condition%s" % [
		scripts.size(), "" if misuses.is_empty() else "\n         " + "\n         ".join(misuses)])


func _gd_files(dir: String, out: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_gd_files(dir.path_join(sub), out)
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))


func _threats() -> int:
	var count := get_nodes_in_group("enemies").size()
	for node in _level.get_children():
		if node is BroodEgg3D:
			count += 1
	return count


func _process(_delta: float) -> bool:
	if _level == null:
		_index += 1
		if _index >= LEVELS.size():
			if _failures.is_empty():
				print("BOSS DORMANT TEST PASS")
			else:
				print("BOSS DORMANT TEST FAIL (%d)" % _failures.size())
			quit(0 if _failures.is_empty() else 1)
			return true
		_level = (load("res://world/levels/%s.tscn" % LEVELS[_index]) as PackedScene).instantiate()
		root.add_child(_level)
		_player = null
		_boss = null
		_started_ms = Time.get_ticks_msec()
		return false
	var elapsed := (Time.get_ticks_msec() - _started_ms) / 1000.0
	if _boss == null:
		# One beat for _ready and the deferred spawns, then take the baseline.
		if elapsed < 0.4:
			return false
		for node in get_nodes_in_group("player"):
			_player = node
		for node in get_nodes_in_group("bosses"):
			if _level.is_ancestor_of(node):
				_boss = node
		if _boss == null or _player == null:
			_check(false, "%s: has a player and a boss to watch" % LEVELS[_index])
			_next()
			return false
		_boss_start = _boss.global_position
		_health_start = _player.health
		_threats_start = _threats()
		_engaged_fired = false
		_boss.engaged.connect(func() -> void: _engaged_fired = true)
		_started_ms = Time.get_ticks_msec()
		return false
	if elapsed < WATCH_SECONDS:
		return false
	var level_name: String = LEVELS[_index]
	var gap := absf(_boss_start.x - _player.global_position.x) if is_instance_valid(_boss) else 0.0
	_check(not _engaged_fired, "%s: the boss has not engaged from %.0f m away" % [level_name, gap])
	var drift := _boss.global_position.distance_to(_boss_start) if is_instance_valid(_boss) else 99.0
	if ROAMERS.has(level_name):
		print("  --   %s: roams before the fight by design (moved %.2f m)" % [level_name, drift])
	else:
		_check(drift <= MAX_DRIFT, "%s: the boss stayed put (moved %.2f m)" % [level_name, drift])
	_check(_threats() <= _threats_start, "%s: nothing was spawned (%d threats, was %d)" % [
		level_name, _threats(), _threats_start])
	_check(is_zero_approx(_player.get("_wind_force")) or level_name == "roof_level",
		"%s: nothing is pulling him (wind %.1f)" % [level_name, _player.get("_wind_force")])
	if QUIET_SPAWNS.has(level_name):
		_check(_player.health >= _health_start, "%s: he was not hurt at a quiet spawn (%.1f of %.1f)" % [
			level_name, _player.health, _health_start])
	_next()
	return false


func _next() -> void:
	_level.free()
	_level = null
