extends SceneTree

## Every named sound hook resolves to a real file, and no two hooks that need to
## be told apart share one.
##
## The bug this exists for: granny_swat and granny_stomp both pointed at
## sfx_thud.wav, so a swatter and a boot landed with an identical sound. Nothing
## errored — it just quietly made two attacks indistinguishable.
##
## Run with:
##   godot --headless --path . --script tests/audio_hooks_test.gd

## Hooks the player must be able to tell apart by ear alone.
const MUST_DIFFER := [
	["granny_swat", "granny_stomp"],
	["granny_eek", "granny_spray"],
	["water_splash", "granny_spray"],
	["bite", "hurt"],
	["jump", "death"],
]

var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	var sfx: Dictionary = load("res://autoload/audio_manager.gd").SFX
	print("-- every hook resolves to a real file")
	_check(not sfx.is_empty(), "there are sound hooks at all (%d)" % sfx.size())
	for key in sfx:
		var path: String = sfx[key]
		var exists := ResourceLoader.exists(path)
		if not exists:
			_check(false, "%s -> %s is missing" % [key, path])
	_check(_failures.is_empty(), "all %d hooks point at files that exist" % sfx.size())

	# Extra takes fail the same silent way a bad hook does: load() on a missing
	# path yields null, play_sfx() sets a null stream, and the sound simply never
	# comes out. Nothing errors.
	print("-- every extra take resolves, and belongs to a registered hook")
	var variants: Dictionary = load("res://autoload/audio_manager.gd").SFX_VARIANTS
	for key in variants:
		_check(sfx.has(key), "%s is a registered hook" % key)
		for path in variants[key]:
			_check(ResourceLoader.exists(path), "%s take %s exists" % [key, path.get_file()])
			_check(path != sfx.get(key, ""), "%s take %s is not the canonical sample"
				% [key, path.get_file()])

	print("-- sounds that must be distinguishable are distinct files")
	for pair in MUST_DIFFER:
		var a: String = sfx.get(pair[0], "")
		var b: String = sfx.get(pair[1], "")
		_check(a != "" and b != "", "%s and %s are both mapped" % [pair[0], pair[1]])
		_check(a != b, "%s and %s are different sounds" % [pair[0], pair[1]])

	print("-- Granny's kit is hers, not borrowed")
	for key in ["granny_eek", "granny_swat", "granny_stomp", "granny_spray", "water_splash"]:
		var path: String = sfx.get(key, "")
		_check(path.contains(key), "%s has its own sample (%s)" % [key, path.get_file()])

	# The spray channel loops, so its sample has to be long enough to hold a
	# loop point without machine-gunning.
	var spray: AudioStreamWAV = load(sfx["granny_spray"])
	_check(spray != null and spray.data.size() > 0, "the spray sample has audio in it")
	if spray:
		# get_length(), not data.size()/2 — these import as QOA, where the byte
		# count is about a fifth of the frame count. That formula was setting
		# every loop point in AudioManager to 20% of its sample.
		_check(spray.get_length() > 0.3,
			"and is long enough to loop cleanly (%.2f s)" % spray.get_length())
		var assumed := float(spray.data.size() / 2) / float(spray.mix_rate)
		_check(assumed < spray.get_length(),
			"and the byte-count shortcut really would have truncated it (%.2f s vs %.2f s)"
				% [assumed, spray.get_length()])

	# Every name the GAME calls must be registered, because play_sfx() returns
	# SILENTLY on an unknown key. A typo or a missed registration is not an
	# error, it is just a sound that never plays — which is exactly how `thud`
	# came to be doing sixteen jobs without anyone noticing the split was
	# never finished. This walks the real source rather than a list someone
	# has to remember to update.
	print("-- every sfx() call in the codebase is a registered name")
	var called := {}
	_scan("res://", called)
	_check(called.size() > 20, "found %d distinct sfx names in the source" % called.size())
	var unregistered: Array[String] = []
	for name_key in called:
		if not AudioManager.SFX.has(name_key):
			unregistered.append("%s (%s)" % [name_key, called[name_key]])
	_check(unregistered.is_empty(), "all of them are registered%s"
		% ("" if unregistered.is_empty() else " — SILENT: " + ", ".join(unregistered)))

	# And nothing registered is dead weight: the export ships every file under
	# the project root, so an unused sample is bloat in the web build.
	var unused: Array[String] = []
	for name_key in AudioManager.SFX:
		if not called.has(name_key):
			unused.append(name_key)
	_check(unused.is_empty(), "and nothing is registered but never played%s"
		% ("" if unused.is_empty() else " — DEAD: " + ", ".join(unused)))

	# And nothing on disk is orphaned. The export ships EVERY file under the
	# project root, so an audio file nothing loads is pure weight in a 40 MB
	# web build — three synthesised music placeholders were riding along at
	# 2.5 MB after the real MP3s replaced them.
	print("-- no orphaned audio files on disk")
	var referenced := {}
	for name_key in AudioManager.SFX:
		referenced[AudioManager.SFX[name_key]] = true
	referenced["res://audio/sfx_wings.wav"] = true # played via Snd.wings()
	_scan_music_refs("res://", referenced)
	var orphans: Array[String] = []
	_scan_audio_files("res://audio", referenced, orphans)
	_check(orphans.is_empty(), "every audio file is loaded by something%s"
		% ("" if orphans.is_empty() else " — ORPHANED: " + ", ".join(orphans)))

	if _failures.is_empty():
		print("AUDIO HOOKS TEST PASS")
	else:
		print("AUDIO HOOKS TEST FAIL (%d): %s" % [_failures.size(), ", ".join(_failures)])
	quit(0 if _failures.is_empty() else 1)


## Walks .gd files for sfx("name") and loop("name"), returning name -> where.
func _scan(dir_path: String, out: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			# Game code only: tests/ contains regexes and assertion strings that
			# look exactly like call sites, and a test is not a call site.
			if not entry.begins_with(".") and entry != "build" and entry != "tests":
				_scan(full, out)
		elif entry.ends_with(".gd"):
			var text := FileAccess.get_file_as_string(full)
			for method in ["sfx", "loop"]:
				var re := RegEx.new()
				re.compile('%s\\("([a-z_0-9]+)"' % method)
				for m in re.search_all(text):
					var key := m.get_string(1)
					if not out.has(key):
						out[key] = entry
		entry = dir.get_next()
	dir.list_dir_end()


## Collects res:// audio paths referenced from scripts and scenes, so music
## tracks named in a .tscn count as used.
func _scan_music_refs(dir_path: String, out: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with(".") and entry != "build":
				_scan_music_refs(full, out)
		elif entry.ends_with(".gd") or entry.ends_with(".tscn"):
			var re := RegEx.new()
			re.compile('res://audio/[A-Za-z0-9_/.]+')
			for m in re.search_all(FileAccess.get_file_as_string(full)):
				out[m.get_string(0)] = true
		entry = dir.get_next()
	dir.list_dir_end()


## Every .wav/.mp3 under audio/ that nothing above referenced.
func _scan_audio_files(dir_path: String, referenced: Dictionary,
		orphans: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			_scan_audio_files(full, referenced, orphans)
		elif entry.ends_with(".wav") or entry.ends_with(".mp3"):
			if not referenced.has(full):
				orphans.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
