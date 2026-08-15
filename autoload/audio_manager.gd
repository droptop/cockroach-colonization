extends Node

## Central audio: pooled one-shot SFX, looping music with crossfade, and a
## dedicated looping wing-buzz channel. All streams are generated placeholder
## WAVs from tools/generate_audio.py.

const SFX := {
	"jump": "res://audio/sfx_jump.wav",
	"whoosh": "res://audio/sfx_whoosh.wav",
	"bite": "res://audio/sfx_bite.wav",
	"crumb": "res://audio/sfx_crumb.wav",
	"fruit": "res://audio/sfx_fruit.wav",
	"hurt": "res://audio/sfx_hurt.wav",
	"death": "res://audio/sfx_death.wav",
	"splat": "res://audio/sfx_splat.wav",
	"step": "res://audio/sfx_step.wav",
	"complete": "res://audio/sfx_complete.wav",
	"squeak": "res://audio/sfx_squeak.wav",
	"thud": "res://audio/sfx_thud.wav",
	"sizzle": "res://audio/sfx_sizzle.wav",
}
const POOL_SIZE := 10
## Separate buses so muting one genuinely cannot touch the other. Created at
## runtime rather than shipped as a bus layout resource, so there is no .tres
## to drift out of sync with this file.
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_index := 0
var _music: AudioStreamPlayer
var _current_track := ""
var _wings: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	for key in SFX:
		_streams[key] = load(SFX[key])
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.volume_db = -6.0
		player.bus = SFX_BUS
		add_child(player)
		_pool.append(player)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -10.0
	_music.bus = MUSIC_BUS
	add_child(_music)
	_wings = AudioStreamPlayer.new()
	_wings.volume_db = -14.0
	_wings.bus = SFX_BUS
	var wing_stream: AudioStreamWAV = load("res://audio/sfx_wings.wav")
	wing_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wing_stream.loop_end = wing_stream.data.size() / 2
	_wings.stream = wing_stream
	add_child(_wings)
	# Apply whatever the player last chose, before a single note plays.
	apply_settings()


func _ensure_buses() -> void:
	for bus_name in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


## Push the saved preferences onto the buses. Muting a bus rather than stopping
## the player means music resumes where it was and never restarts doubled.
func apply_settings() -> void:
	_set_bus_muted(MUSIC_BUS, not Settings.music_enabled())
	_set_bus_muted(SFX_BUS, not Settings.sfx_enabled())


func _set_bus_muted(bus_name: String, muted: bool) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_mute(idx, muted)


func set_music_enabled(enabled: bool) -> void:
	Settings.set_music_enabled(enabled)
	_set_bus_muted(MUSIC_BUS, not enabled)


func set_sfx_enabled(enabled: bool) -> void:
	Settings.set_sfx_enabled(enabled)
	_set_bus_muted(SFX_BUS, not enabled)


func play_sfx(name_key: String, volume_db := 0.0, pitch_jitter := 0.08) -> void:
	if not _streams.has(name_key):
		return
	var player := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	player.stream = _streams[name_key]
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
		stream.loop_end = stream.data.size() / 2
	elif stream is AudioStreamMP3:
		stream.loop = true
	_music.stream = stream
	_music.volume_db = -40.0
	_music.play()
	var tween := create_tween()
	tween.tween_property(_music, "volume_db", -10.0, 1.2)


func set_wings_active(active: bool) -> void:
	if active and not _wings.playing:
		_wings.play()
	elif not active and _wings.playing:
		_wings.stop()
