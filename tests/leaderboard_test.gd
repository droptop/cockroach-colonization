extends SceneTree

## The arcade board (BACKLOG item 24): scores are computed the way the rules
## say, the table sorts, caps and PERSISTS - most importantly across NEW GAME,
## which wipes the run's save and must never wipe its glory - and the ending
## screen actually collects initials and carves the run in, driven by the
## same button presses a player would use.
##
## Run with:
##   godot --headless --path . --script tests/leaderboard_test.gd

var _phase := 0
var _t := 0.0
var _ending: Node
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _all(node: Node, out: Array[Node]) -> void:
	out.append(node)
	for child in node.get_children():
		_all(child, out)


func _initialize() -> void:
	SaveGame.save_path = "user://test_leaderboard_save.cfg"
	SaveGame.clear()
	Leaderboard.board_path = "user://test_leaderboard.cfg"
	Leaderboard.clear()

	print("-- the score is what the rules say")
	_check(Leaderboard.score_for(0, 0, 0.0) == 0, "an empty run scores nothing")
	_check(Leaderboard.score_for(0, 0, 0.0, 2400.0) == 0,
		"finishing exactly at par earns no speed bonus")
	_check(Leaderboard.score_for(0, 0, 0.0, 1800.0) == 600,
		"ten minutes under par is 600 points")
	_check(Leaderboard.score_for(0, 0, 0.0, 4000.0) == 0,
		"a slow run is never punished below zero")
	_check(Leaderboard.score_for(3, 10, 8.0) == 3 * 500 + 10 * 25 + 8 * 75,
		"babies, coins earned and hearts all pay (%d)"
			% Leaderboard.score_for(3, 10, 8.0))

	print("-- the table sorts, caps, and holds its ground")
	_check(Leaderboard.qualifies(1), "an open board takes anyone")
	for i in 10:
		Leaderboard.submit("P%d" % i, 1000 + i * 100, i, 0, 0.0)
	_check(Leaderboard.entries().size() == 10, "ten entries fill it")
	_check(int(Leaderboard.best().score) == 1900, "best sits on top")
	_check(not Leaderboard.qualifies(1000), "matching the bottom is not beating it")
	_check(Leaderboard.qualifies(1001), "beating it is")
	# 1500 TIES the sitting 1500 and goes below it: you beat a score to pass
	# it, matching was never enough on the machines.
	var rank := Leaderboard.submit("NEW", 1500, 0, 0, 0.0)
	_check(rank == 5, "a mid score lands mid-table, below its tie (rank %d)" % (rank + 1))
	_check(Leaderboard.entries().size() == 10, "and the bottom falls off")

	# The board must survive a NEW GAME.
	SaveGame.clear()
	Leaderboard.invalidate()
	_check(Leaderboard.entries().size() == 10, "the board survives NEW GAME")

	print("-- the ending screen carves a run in")
	Leaderboard.clear()
	SaveGame.set_babies_banked(4)
	SaveGame.add_coins(20)
	EndingScreen.run_hearts = 6.0
	_ending = (load("res://ui/ending/ending_screen.tscn") as PackedScene).instantiate()
	root.add_child(_ending)


func _process(delta: float) -> bool:
	_t += delta
	match _phase:
		0:
			if _t < 0.5:
				return false
			var expected := Leaderboard.score_for(4, 20, 6.0)
			var stats: Label = _ending.get_node("Stats")
			_check("SCORE  %d" % expected in stats.text,
				"the run's score is on screen (%d)" % expected)
			# Turn the first initial B-ward, then carve it in.
			var buttons: Array[Node] = []
			_all(_ending, buttons)
			var up: Button = null
			var confirm: Button = null
			for node in buttons:
				if node is Button and (node as Button).text == "^" and up == null:
					up = node
				if node is Button and node.name == "ConfirmInitials":
					confirm = node
			_check(up != null and confirm != null, "the initials wheel is there")
			if up == null or confirm == null:
				_phase = 2
				return false
			up.pressed.emit()
			confirm.pressed.emit()
			_phase = 1
			_t = 0.0
		1:
			if _t < 0.3:
				return false
			var board := Leaderboard.entries()
			_check(board.size() == 1, "the run is on the board")
			if board.size() == 1:
				_check(board[0].name == "BAA", "under the carved initials (%s)" % board[0].name)
				_check(int(board[0].babies) == 4, "with its babies counted")
			var labels: Array[Node] = []
			_all(_ending, labels)
			var shown := false
			for node in labels:
				if node is Label and "BEST COLONIES" in (node as Label).text:
					shown = true
			_check(shown, "and the table is shown after")
			_phase = 2
		2:
			if _failures.is_empty():
				print("LEADERBOARD TEST PASS")
			else:
				print("LEADERBOARD TEST FAIL (%d): %s"
					% [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
			return true
	return false
