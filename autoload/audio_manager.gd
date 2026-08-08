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

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_index := 0
var _music: AudioStreamPlayer
var _current_track := ""
var _wings: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in SFX:
		_streams[key] = load(SFX[key])
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
	wing_stream.loop_end = wing_stream.data.size() / 2
	_wings.stream = wing_stream
	add_child(_wings)


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
	var stream: AudioStreamWAV = load(path)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2
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
