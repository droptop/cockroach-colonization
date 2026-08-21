class_name ClimberWave3D
extends Area3D

## A gauntlet that comes UP at you out of the dark before a boss.
##
## The drain is a chamber over standing water, and nothing ever came out of it.
## This is the run-up: cross the trigger and the colony boils up over the lip of
## the ledge in waves, and only once they are dealt with does the way on matter.
##
## Deliberately NOT a boss and NOT a level gate: it hands out `cleared` and lets
## the level decide what that is worth. Every wave still answers to `Encounter`,
## so the cap of two committed attackers and the no-attacks-from-off-screen rule
## hold exactly as they do for a hand-placed enemy. A crowd is meant to be a
## crowd, not an ambush that cannot be read.

signal started
signal cleared

const ANT := preload("res://enemies/ant/ant_3d.tscn")
const SPIDER := preload("res://enemies/spider/spider_3d.tscn")

@export var waves := 3
## Per wave. Ramps by `extra_per_wave` so the last one is the big one.
@export var per_wave := 2
@export var extra_per_wave := 1
## Seconds between individuals inside a wave, and between waves.
@export var spawn_interval := 0.55
@export var wave_gap := 1.6
## How long a wave will wait for the floor to clear before moving on
## regardless. Stops a run-past from stalling the encounter forever.
@export var wave_timeout := 22.0
## How wide along X they come up, centred on this node.
@export var span := 7.0
## How far below the ledge top they start their climb, and how long it takes.
@export var climb_depth := 3.4
@export var climb_time := 0.85
## Every third one is a spider: heavier, and it lunges.
@export var spider_every := 3

var _fired := false
var _wave := 0
var _spawned: Array[Node] = []
var _timer := 0.0
var _in_wave := 0
var _index := 0
var _done := false
var _stalled := 0.0


func _ready() -> void:
	collision_layer = 16 # pickup layer: it only has to notice the player
	collision_mask = 2
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 5.0, 3.0)
	shape.shape = box
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _fired or not body.has_method("take_damage"):
		return
	_fired = true
	started.emit()
	_wave = 0
	_begin_wave()


func _begin_wave() -> void:
	_in_wave = per_wave + _wave * extra_per_wave
	_timer = 0.0


func _process(delta: float) -> void:
	if not _fired or _done:
		return
	# Prune as they die, so "cleared" means the floor is actually clear rather
	# than that the spawner finished spawning.
	for i in range(_spawned.size() - 1, -1, -1):
		if not is_instance_valid(_spawned[i]):
			_spawned.remove_at(i)

	if _in_wave > 0:
		_timer -= delta
		if _timer <= 0.0:
			_timer = spawn_interval
			_in_wave -= 1
			_spawn_one()
		return

	# Wave spent. The next one waits for the floor to clear, so a slow player is
	# never buried by a wave they have not had a chance to answer.
	#
	# But it does NOT wait forever. Harry can simply run past a crowd, and an
	# encounter that only advances on kills would then sit half-finished for the
	# rest of the level and never emit `cleared` — which is a soft lock waiting
	# for the first level that gates anything on it.
	_stalled += delta
	if not _spawned.is_empty() and _stalled < wave_timeout:
		return
	_stalled = 0.0
	_wave += 1
	if _wave >= waves:
		_done = true
		cleared.emit()
		return
	_timer -= delta
	if _timer <= -wave_gap:
		_begin_wave()


func _spawn_one() -> void:
	var scene: PackedScene = SPIDER if (_index % spider_every == spider_every - 1) else ANT
	_index += 1
	var climber := scene.instantiate()
	get_parent().add_child(climber)
	var offset := randf_range(-span * 0.5, span * 0.5)
	var top := global_position + Vector3(offset, 0.0, 0.0)
	var node := climber as Node3D
	node.global_position = top - Vector3(0.0, climb_depth, 0.0)

	# Their own FSM would apply gravity and drop them straight back into the
	# water, so it is held off until they are over the lip. The tween lives on
	# THIS node, not on the climber, or disabling the climber would freeze it.
	node.process_mode = Node.PROCESS_MODE_DISABLED
	var tween := create_tween()
	tween.tween_property(node, "global_position", top, climb_time
		).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		if is_instance_valid(node):
			node.process_mode = Node.PROCESS_MODE_INHERIT)
	_spawned.append(climber)
	Snd.sfx("crack", -8.0, 0.3)
