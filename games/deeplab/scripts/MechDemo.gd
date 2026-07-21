class_name MechDemo
extends Node2D
## Base class for every mechanic demo in MechLab.
## Contract: override start(); guard everything on `running`;
## call add_points() for score and end_demo() exactly once when the run dies.
## Endless demos (e.g. idle) never call end_demo() — the shell submits their
## score when the player backs out. Render with _draw() + queue_redraw().

signal score_changed(score: int)
signal demo_over(score: int)

const W := 720.0
const H := 1280.0

var score := 0
var running := false


func start() -> void:
	score = 0
	running = true


func add_points(d: int) -> void:
	score += d
	score_changed.emit(score)


func set_score(s: int) -> void:
	if s == score:
		return
	score = s
	score_changed.emit(score)


func end_demo() -> void:
	if not running:
		return
	running = false
	demo_over.emit(score)


func f() -> Font:
	return ThemeDB.fallback_font
