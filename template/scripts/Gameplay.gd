class_name Gameplay
extends Node2D
## THE CONTRACT every game's core implements. Main.gd only ever talks to this
## interface — replace the placeholder logic below with your actual mechanic
## and the whole shell (menu, HUD, game over, leaderboard, ads, analytics)
## keeps working untouched.
##
## Required:
##   signal score_changed(score)   — emit whenever the score changes
##   signal game_ended(score)      — emit exactly once when the run ends
##   func start_game()             — reset state and begin a run
## Optional but recommended:
##   emit Analytics.track(...) for interesting moments (fever, near-miss, etc.)

signal score_changed(score: int)
signal game_ended(score: int)

var score := 0
var playing := false
var _elapsed := 0.0

# ------------------------------------------------------------------
# PLACEHOLDER MECHANIC (replace everything below): score ticks up
# once per second; tapping ends the run. It exists only to prove the
# contract wiring end-to-end on first F5.
# ------------------------------------------------------------------

func start_game() -> void:
	for child in get_children():
		child.queue_free()
	score = 0
	_elapsed = 0.0
	playing = true
	score_changed.emit(score)


func on_tap() -> void:
	## Main.gd forwards taps here while state == PLAYING.
	if not playing:
		return
	playing = false
	game_ended.emit(score)


func _process(delta: float) -> void:
	if not playing:
		return
	_elapsed += delta
	if _elapsed >= 1.0:
		_elapsed -= 1.0
		score += 1
		score_changed.emit(score)
