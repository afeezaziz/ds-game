class_name SkyStack
extends Node2D
## Core Sky Stack gameplay: a block slides above the tower; tap to drop it.
## Overhang is sliced off. Perfect drops build a combo that regrows width.
## All tuning values come from remote config (with safe local defaults),
## so difficulty can be adjusted live from the backend without an update.

signal layer_placed(score: int, was_perfect: bool, combo: int)
signal stack_failed(score: int)

const LAYER_H := 70.0
const START_WIDTH := 340.0
const CENTER_X := 360.0
const BASE_Y := 1100.0
const SLIDE_RANGE := 320.0

var layers := 0
var combo := 0
var playing := false

var _current: Polygon2D
var _prev_center := CENTER_X
var _prev_width := START_WIDTH
var _dir := 1.0
var _speed := 260.0

# Tunables (refreshed from remote config each run)
var base_speed := 260.0
var speed_per_layer := 6.0
var max_speed := 700.0
var perfect_window := 7.0
var fever_streak := 5
var regrow_on_perfect := 4.0


func start_game() -> void:
	for child in get_children():
		child.queue_free()
	base_speed = float(Backend.cfg("base_speed", base_speed))
	speed_per_layer = float(Backend.cfg("speed_per_layer", speed_per_layer))
	max_speed = float(Backend.cfg("max_speed", max_speed))
	perfect_window = float(Backend.cfg("perfect_window", perfect_window))
	fever_streak = int(Backend.cfg("fever_streak", fever_streak))
	regrow_on_perfect = float(Backend.cfg("regrow_on_perfect", regrow_on_perfect))

	layers = 0
	combo = 0
	_prev_center = CENTER_X
	_prev_width = START_WIDTH
	_speed = base_speed
	playing = true
	_make_block(CENTER_X, BASE_Y, START_WIDTH, _layer_color(0))
	_spawn_moving()


func top_y() -> float:
	return BASE_Y - float(layers + 1) * LAYER_H


func _process(delta: float) -> void:
	if not playing or _current == null:
		return
	_current.position.x += _speed * _dir * delta
	var half := _prev_width * 0.5
	if _current.position.x > CENTER_X + SLIDE_RANGE - half:
		_current.position.x = CENTER_X + SLIDE_RANGE - half
		_dir = -1.0
	elif _current.position.x < CENTER_X - SLIDE_RANGE + half:
		_current.position.x = CENTER_X - SLIDE_RANGE + half
		_dir = 1.0


func drop() -> void:
	if not playing or _current == null:
		return
	var delta_x := _current.position.x - _prev_center
	var overlap := _prev_width - absf(delta_x)

	if overlap <= 0.0:
		# Complete miss: the block tumbles, run ends.
		playing = false
		_to_debris(_current.position.x, _current.position.y, _prev_width,
			_current.color, signf(delta_x))
		_current.queue_free()
		_current = null
		stack_failed.emit(layers)
		return

	var was_perfect := absf(delta_x) <= perfect_window
	if was_perfect:
		combo += 1
		_current.position.x = _prev_center  # snap
		if regrow_on_perfect > 0.0:
			_prev_width = minf(START_WIDTH, _prev_width + regrow_on_perfect)
			_rebuild(_current, _prev_width)
	else:
		combo = 0
		# Slice: keep the overlapping part, spill the rest as debris.
		var new_center := _prev_center + delta_x * 0.5
		var debris_center := _prev_center + signf(delta_x) * (_prev_width * 0.5 + absf(delta_x) * 0.5)
		_to_debris(debris_center, _current.position.y, absf(delta_x),
			_current.color, signf(delta_x))
		_prev_width = overlap
		_prev_center = new_center
		_rebuild(_current, _prev_width)
		_current.position.x = new_center

	layers += 1
	_speed = minf(max_speed, base_speed + float(layers) * speed_per_layer)
	layer_placed.emit(layers, was_perfect, combo)
	_current = null
	_spawn_moving()


func _spawn_moving() -> void:
	var y := BASE_Y - float(layers + 1) * LAYER_H
	_dir = 1.0 if (layers % 2 == 0) else -1.0
	var start_x := CENTER_X - SLIDE_RANGE * _dir
	_current = _make_block(start_x, y, _prev_width, _layer_color(layers + 1))


func _make_block(cx: float, y: float, w: float, col: Color) -> Polygon2D:
	var p := Polygon2D.new()
	_set_rect(p, w)
	p.color = col
	p.position = Vector2(cx, y)
	# Darker base strip for a little depth.
	var strip := Polygon2D.new()
	strip.name = "Strip"
	var h := LAYER_H * 0.5
	strip.polygon = PackedVector2Array([
		Vector2(-w * 0.5, h - 12.0), Vector2(w * 0.5, h - 12.0),
		Vector2(w * 0.5, h), Vector2(-w * 0.5, h),
	])
	strip.color = col.darkened(0.25)
	p.add_child(strip)
	add_child(p)
	return p


func _rebuild(p: Polygon2D, w: float) -> void:
	_set_rect(p, w)
	var strip: Polygon2D = p.get_node("Strip")
	var h := LAYER_H * 0.5
	strip.polygon = PackedVector2Array([
		Vector2(-w * 0.5, h - 12.0), Vector2(w * 0.5, h - 12.0),
		Vector2(w * 0.5, h), Vector2(-w * 0.5, h),
	])


func _set_rect(p: Polygon2D, w: float) -> void:
	var hw := w * 0.5
	var hh := LAYER_H * 0.5
	p.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
	])


func _to_debris(cx: float, y: float, w: float, col: Color, side: float) -> void:
	var d := Debris.new()
	_set_rect(d, w)
	d.color = col
	d.position = Vector2(cx, y)
	d.vel = Vector2(side * randf_range(60.0, 160.0), randf_range(-120.0, 0.0))
	d.spin = side * randf_range(1.5, 4.0)
	d.kill_y = BASE_Y + 600.0
	add_child(d)


func _layer_color(i: int) -> Color:
	var hue := fmod(0.55 + float(i) * 0.035, 1.0)
	return Color.from_hsv(hue, 0.55, 0.95)


class Debris extends Polygon2D:
	var vel := Vector2.ZERO
	var spin := 0.0
	var kill_y := 2000.0

	func _process(delta: float) -> void:
		vel.y += 2200.0 * delta
		position += vel * delta
		rotation += spin * delta
		if position.y > kill_y:
			queue_free()
