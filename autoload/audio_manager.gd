extends Node

## Central audio: pooled one-shot SFX, looping music with crossfade, and a
## dedicated looping wing-buzz channel. Most streams are now real recordings;
## the few still missing keep their generated placeholder from
## tools/generate_audio.py, so an unrecorded hook is quiet, never broken.

const SFX := {
	"jump": "res://audio/sfx_jump.wav",
	"whoosh": "res://audio/sfx_whoosh.wav",
	"bite": "res://audio/sfx_bite.wav",
	"crumb": "res://audio/sfx_crumb.wav",
	"fruit": "res://audio/sfx_fruit.wav",
	"hurt": "res://audio/sfx_hurt.wav",
	"death": "res://audio/sfx_death.wav",
	"splat": "res://audio/sfx_splat.wav",
	# The small enemies get their own death rather than sharing `splat` with the
	# player and the wasp: repurposed from the unused random_death recording,
	# because the splat takes kept reading as an animal call.
	"enemy_die": "res://audio/sfx_enemy_die.wav",
	"step": "res://audio/sfx_step.wav",
	"complete": "res://audio/sfx_complete.wav",
	"sizzle": "res://audio/sfx_sizzle.wav",
	# Granny's kit. Still synthesised placeholders, but each is now its OWN
	# placeholder — swat and stomp shared sfx_thud, so two different attacks
	# landed identically and the player could not tell them apart. Swapping in
	# real recordings is one path change each.
	"granny_eek": "res://audio/sfx_granny_eek.wav",
	"granny_swat": "res://audio/sfx_granny_swat.wav",
	"granny_stomp": "res://audio/sfx_granny_stomp.wav",
	"granny_spray": "res://audio/sfx_granny_spray.wav",
	# Her voice. Both were recorded and sat unused: she shrieked once and was
	# otherwise a silent pair of hands coming out of the sky.
	"granny_cockroach_exclaim": "res://audio/sfx_granny_cockroach_exclaim.wav",
	"granny_not_in_my_house": "res://audio/sfx_granny_not_in_my_house.wav",
	"water_splash": "res://audio/sfx_water_splash.wav",
	# The split names. `thud` was played from sixteen places and `squeak` from
	# thirteen, so every boss shared one hurt AND one death sound and a blocked
	# shield was indistinguishable from a rat landing. Still synthesised, but
	# each is its own file now, so a real recording drops in over one path with
	# no code change. Recording briefs: docs/audio-brief.md.
	"impact_heavy": "res://audio/sfx_impact_heavy.wav",
	"impact_light": "res://audio/sfx_impact_light.wav",
	"block": "res://audio/sfx_block.wav",
	"locked": "res://audio/sfx_locked.wav",
	"crack": "res://audio/sfx_crack.wav",
	"guard": "res://audio/sfx_guard.wav",
	"rat_cry": "res://audio/sfx_rat_cry.wav",
	"rat_hurt": "res://audio/sfx_rat_hurt.wav",
	"rat_death": "res://audio/sfx_rat_death.wav",
	"cat_hurt": "res://audio/sfx_cat_hurt.wav",
	"cat_death": "res://audio/sfx_cat_death.wav",
	"mantis_cry": "res://audio/sfx_mantis_cry.wav",
	"mantis_hurt": "res://audio/sfx_mantis_hurt.wav",
	"mantis_death": "res://audio/sfx_mantis_death.wav",
	"wasp_hurt": "res://audio/sfx_wasp_hurt.wav",
	"wasp_death": "res://audio/sfx_wasp_death.wav",
	"queen_drop": "res://audio/sfx_queen_drop.wav",
	"queen_hurt": "res://audio/sfx_queen_hurt.wav",
	"queen_death": "res://audio/sfx_queen_death.wav",
	# Breaking a wall used to play `splat`, the enemy-death sound, so smashing
	# masonry squelched. Weapon swaps were silent altogether.
	"wall_break": "res://audio/sfx_wall_break.wav",
	"weapon_load": "res://audio/sfx_weapon_load.wav",
}
## Extra takes for the sounds that repeat hardest. `step` fires every few frames
## and one `whoosh` covers all nine weapons, so a single sample reads as a loop
## rather than as footsteps. play_sfx() picks among the canonical sample and
## these at random.
##
## Deliberately NO entry for `wings` or `granny_spray`: those are looped through
## set_loop_active/set_wings_active, which hold one stream and set a loop point
## on it. A random take there would move the seam every time it restarted.
const SFX_VARIANTS := {
	"step": [
		"res://audio/sfx_step_2.wav",
		"res://audio/sfx_step_3.wav",
		"res://audio/sfx_step_4.wav",
	],
	"whoosh": [
		"res://audio/sfx_whoosh_2.wav",
		"res://audio/sfx_whoosh_3.wav",
		"res://audio/sfx_whoosh_4.wav",
	],
	"hurt": ["res://audio/sfx_hurt_2.wav"],
	"block": ["res://audio/sfx_block_2.wav"],
	"rat_hurt": ["res://audio/sfx_rat_hurt_2.wav"],
	# NO second take for `splat`. Splat_3 was long and tonal where the other is
	# short and broadband, and it read as an animal call rather than something
	# small bursting. Enemy death now always uses the dry one.
}
const POOL_SIZE := 10
## EVERYTHING PLAYS ON MASTER, and muting is a gate in here rather than a bus.
##
## This used to create Music and SFX buses at runtime and route the pool, the
## music player and the wing channel onto them. That works on desktop, where
## the Master bus peaks at 8.3 dB and every channel is audible. On the WEB
## export it produced silence: context running, driver AudioWorklet, sounds
## firing, and not one sample reaching the speakers, with no error anywhere.
##
## Proven by a control: a minimal Godot 4.7.1 web export playing one sound on
## the default bus is audible in the same browser on the same machine. Same
## engine, same templates. The only difference was the runtime buses.
const MASTER_BUS := "Master"

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_index := 0
var _music: AudioStreamPlayer
var _current_track := ""
var _wings: AudioStreamPlayer
var _loop: AudioStreamPlayer
var _loop_key := ""
## Music volume when on, and the level that stands in for a mute.
const MUSIC_DB := -10.0
const SILENT_DB := -80.0
var _music_on := true
var _sfx_on := true
## Diagnostics for the F3 overlay only.
var _play_count := 0
var _last_key := ""


## Frames in a sample. NOT `data.size() / 2` — that only holds for uncompressed
## 16-bit PCM, and these import as QOA (`compress/mode=2`), where the byte count
## is about a fifth of the frame count. The byte formula was setting every loop
## point to 20% of its sample, so the wing buzz looped 0.10 s of a 0.50 s clip
## and machine-gunned.
func _sample_frames(stream: AudioStreamWAV) -> int:
	return int(stream.get_length() * stream.mix_rate)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in SFX:
		var takes: Array[AudioStream] = [load(SFX[key])]
		for extra_path in SFX_VARIANTS.get(key, []):
			takes.append(load(extra_path))
		_streams[key] = takes
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.volume_db = -6.0
		add_child(player)
		_pool.append(player)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -10.0
	add_child(_music)
	_wings = AudioStreamPlayer.new()
	_wings.volume_db = -14.0
	var wing_stream: AudioStreamWAV = load("res://audio/sfx_wings.wav")
	wing_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wing_stream.loop_end = _sample_frames(wing_stream)
	_wings.stream = wing_stream
	add_child(_wings)
	# One channel for any sustained hazard sound. PAUSABLE, unlike the manager
	# itself, so a hiss goes quiet when the game does instead of droning on
	# over a pause menu.
	_loop = AudioStreamPlayer.new()
	_loop.volume_db = -12.0
	_loop.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_loop)
	# Apply whatever the player last chose, before a single note plays.
	apply_settings()


## Push the saved preferences onto the players. Music is turned DOWN rather
## than stopped, which keeps the old guarantee that turning it back on cannot
## produce two overlapping tracks: the stream never stopped, so there is nothing
## to restart.
func apply_settings() -> void:
	_music_on = Settings.music_enabled()
	_sfx_on = Settings.sfx_enabled()
	_apply_gates()


func _apply_gates() -> void:
	if _music:
		_music.volume_db = MUSIC_DB if _music_on else SILENT_DB
	if not _sfx_on:
		if _wings and _wings.playing:
			_wings.stop()
		if _loop and _loop.playing:
			_loop.stop()


func set_music_enabled(enabled: bool) -> void:
	Settings.set_music_enabled(enabled)
	_music_on = enabled
	_apply_gates()


func set_sfx_enabled(enabled: bool) -> void:
	Settings.set_sfx_enabled(enabled)
	_sfx_on = enabled
	_apply_gates()


## One line of truth about the audio chain, for the F3 overlay.
##
## "No sound" has been unfalsifiable from the outside: the settings can read ON,
## every hook can resolve, and the game can still be silent because the browser
## never gave the driver an output. PEAK is the decider. It is the Master bus's
## real output level, so a moving number means this game IS producing audio and
## the silence is downstream (tab muted, system output, autoplay policy). A
## number pinned at -200 while sounds fire means the fault is in here.
func debug_state() -> String:
	var master := AudioServer.get_bus_index(MASTER_BUS)
	var peak := -200.0
	if master != -1:
		peak = maxf(AudioServer.get_bus_peak_volume_left_db(master, 0),
			AudioServer.get_bus_peak_volume_right_db(master, 0))
	var live := 0
	for player in _pool:
		if player.playing:
			live += 1
	return "sfx %s  music %s  plays %d  last %s\nmst %.0f  act %d/%d\nrate %d  dev %s  ctx %s" % [
		"ON" if _sfx_on else "MUTED",
		"ON" if _music_on else "MUTED",
		_play_count, _last_key if _last_key != "" else "-",
		peak, live, _pool.size(),
		AudioServer.get_mix_rate(), _driver_name(), _web_ctx_state(),
	]


## What the BROWSER thinks of its own audio clock, read back out of the shim in
## html/head_include. Godot reports the driver it asked for, not whether the
## context ever started.
func _web_ctx_state() -> String:
	if not OS.has_feature("web"):
		return "n/a"
	var v = JavaScriptBridge.eval(
		"window.__gdaudio ? window.__gdaudio.state() : 'no-shim'", true)
	return "?" if v == null else str(v)


func _driver_name() -> String:
	if AudioServer.has_method("get_driver_name"):
		return str(AudioServer.get_driver_name())
	return AudioServer.get_output_device()


func play_sfx(name_key: String, volume_db := 0.0, pitch_jitter := 0.08) -> void:
	if not _sfx_on or not _streams.has(name_key):
		return
	var player := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	var takes: Array = _streams[name_key]
	player.stream = takes[0] if takes.size() == 1 else takes[randi() % takes.size()]
	_play_count += 1
	_last_key = name_key
	player.volume_db = -6.0 + volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()


func play_music(path: String) -> void:
	if path == _current_track:
		return
	_current_track = path
	if path == "":
		_music.stop()
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = _sample_frames(stream)
	elif stream is AudioStreamMP3:
		stream.loop = true
	_music.stream = stream
	_music.play()
	if not _music_on:
		_music.volume_db = SILENT_DB
		return
	_music.volume_db = -40.0
	var tween := create_tween()
	tween.tween_property(_music, "volume_db", MUSIC_DB, 1.2)


## Sustained hazard sound, keyed so two hazards can't fight over the channel.
## Idempotent: a hazard may assert its state as often as it likes. Turning off
## a key that isn't playing does nothing, so a dying cloud can't cut short the
## hiss of one that started after it.
func set_loop_active(key: String, active: bool) -> void:
	if active:
		if not _sfx_on or not SFX.has(key):
			return
		if _loop_key == key and _loop.playing:
			return
		var stream: AudioStreamWAV = load(SFX[key]).duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = _sample_frames(stream)
		_loop.stream = stream
		_loop_key = key
		_loop.play()
	elif _loop_key == key or key == "":
		_loop.stop()
		_loop_key = ""


func set_wings_active(active: bool) -> void:
	if active and not _sfx_on:
		return
	if active and not _wings.playing:
		_wings.play()
	elif not active and _wings.playing:
		_wings.stop()
