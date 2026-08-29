class_name Leaderboard
extends Object

## The arcade table (BACKLOG item 24): top ten runs, three initials each,
## kept LOCALLY like a cabinet's board — GitHub Pages is static files, so
## there is no server for a global one, and a per-browser table with initials
## is exactly how the old machines worked anyway.
##
## A static facade over its OWN ConfigFile, same shape as SaveGame — but a
## SEPARATE file on purpose: NEW GAME and RUN IT AGAIN call SaveGame.clear(),
## and high scores that die with the run they were earned in are not high
## scores. Only tests point `board_path` elsewhere.

const PATH := "user://leaderboard.cfg"
const VERSION := 1
const MAX_ENTRIES := 10

## What a run is worth. Babies are the game's stated point; coins EARNED
## (not held - spending at the stash must never cost score) reward fighting
## and exploring; hearts left reward not being hit. Health is in half-heart
## units, so the multiplier is per half.
const BABY_POINTS := 500
const COIN_POINTS := 25
const HALF_HEART_POINTS := 75
## Par for the whole run; every second under it is a point. Forty minutes
## is comfortable for 14 levels - the bonus rewards mastery, not rushing
## a first playthrough.
const SPEED_PAR_SECONDS := 2400.0

static var board_path := PATH

static var _config: ConfigFile
static var _loaded := false


static func _data() -> ConfigFile:
	if _loaded and _config:
		return _config
	_config = ConfigFile.new()
	var err := _config.load(board_path)
	if err != OK or _config.get_value("meta", "version", 0) != VERSION:
		_config = ConfigFile.new()
		_config.set_value("meta", "version", VERSION)
	_loaded = true
	return _config


static func invalidate() -> void:
	_loaded = false
	_config = null


static func clear() -> void:
	_config = ConfigFile.new()
	_config.set_value("meta", "version", VERSION)
	_loaded = true
	_flush()


static func _flush() -> void:
	var err := _data().save(board_path)
	if err != OK:
		push_warning("Could not write leaderboard to %s (error %d)" % [board_path, err])


static func score_for(babies: int, coins_earned: int, health_left: float,
		run_seconds := 0.0) -> int:
	var score := babies * BABY_POINTS + coins_earned * COIN_POINTS \
		+ int(health_left) * HALF_HEART_POINTS
	if run_seconds > 0.0:
		score += maxi(0, int(SPEED_PAR_SECONDS - run_seconds))
	return score


## Sorted best-first. Each entry: {name, score, babies, coins, hearts}.
static func entries() -> Array:
	var raw: Array = _data().get_value("board", "entries", [])
	return raw


## Whether this score would make the table at all.
static func qualifies(score: int) -> bool:
	var board := entries()
	if board.size() < MAX_ENTRIES:
		return true
	return score > int(board[board.size() - 1].score)


## Records the run and returns its RANK (0 = top), or -1 if it fell off the
## bottom. Ties break in favour of the sitting entry - the old machines made
## you BEAT the score on the board, not match it.
static func submit(player_name: String, score: int, babies: int,
		coins_earned: int, health_left: float) -> int:
	var entry := {
		"name": player_name.strip_edges().to_upper().left(3),
		"score": score,
		"babies": babies,
		"coins": coins_earned,
		"hearts": int(health_left),
	}
	if entry.name == "":
		entry.name = "???"
	var board := entries().duplicate()
	var rank := board.size()
	for i in board.size():
		if score > int(board[i].score):
			rank = i
			break
	board.insert(rank, entry)
	if board.size() > MAX_ENTRIES:
		board.resize(MAX_ENTRIES)
	_data().set_value("board", "entries", board)
	_flush()
	return rank if rank < MAX_ENTRIES else -1


static func best() -> Dictionary:
	var board := entries()
	return board[0] if board.size() > 0 else {}
