class_name SkyStack
extends Node2D
## Sky Stack — MECHANICS LAB edition.
##
## One stacking engine, many mechanics. Every mode is an entry in MODES plus
## (at most) a small branch in _process/_place — see MECHANICS.md for the
## "add a new mechanic" guide. Per-mode tuning can be overridden live from
## the backend remote config under "modes": {"<mode>": {...}}.

signal layer_placed(score: int, was_perfect: bool, combo: int)
signal stack_failed(score: int)
signal wind_changed(wind: float)

const LAYER_H := 70.0
const START_WIDTH := 340.0
const CENTER_X := 360.0
const BASE_Y := 1100.0
const SLIDE_RANGE := 320.0
const FAIL_WIDTH := 26.0
const GRAVITY := 2400.0

## The experiment registry. movement: "slide" | "pendulum" | "pulse".
## falls: block drops through the air after release (adds aim-ahead skill).
## wind: sideways drift while falling. chaos: random flips/speed bursts.
const MODES := {
	"classic": {
		"title": "CLASSIC", "tagline": "Slide. Tap. Stack.",
		"movement": "slide", "falls": false, "wind": false, "chaos": false,
	},
	"pendulum": {
		"title": "PENDULUM", "tagline": "Momentum matters.",
		"movement": "pendulum", "falls": true, "wind": false, "chaos": false,
	},
	"pulse": {
		"title": "PULSE", "tagline": "Time the size, not the spot.",
		"movement": "pulse", "falls": false, "wind": false, "chaos": false,
	},
	"wind": {
		"title": "WIND", "tagline": "Aim where it will land.",
		"movement": "slide", "falls": true, "wind": true, "chaos": false,
	},
	"rush": {
		"title": "RUSH", "tagline": "It cheats. Keep up.",
		"movement": "slide", "falls": false, "wind": false, "chaos": true,
	},
}

var mode := "classic"
var md: Dictionary = MODES["classic"]  # mode definition
var mp: Dictionary = {}                # merged tuning params
var fever_streak := 5                  # exposed for Main.gd fever flash

var layers := 0
var combo := 0
var playing := false

var _current: Polygon2D
var _prev_center := CENTER_X
var _prev_width := START_WIDTH
var _dir := 1.0
var _speed := 260.0
var _t := 0.0

# pendulum state
var _rope: Line2D
var _pivot := Vector2.ZERO
var _vel_est := Vector2.ZERO
var _last_pos := Vector2.ZERO

# pulse state
var _pulse_w := START_WIDTH

# falling state (pendulum / wind)
var _falling := false
var _fall_vel := Vector2.ZERO
var _fall_target_y := 0.0

# chaos state (rush)
var _chaos_cd := 0.0
var _burst_t := 0.0

# wind state
var _wind := 0.0


static func enabled_modes() -> Array:
	var enabled: Variant = Backend.cfg("enabled_modes", [])
	if enabled is Array and not (enabled as Array).is_empty():
		var known := (enabled as Array).filter(func(m): return MODES.has(str(m)))
		if not known.is_empty():
			return known
	return MODES.keys()


func start_game(m: String = "classic") -> void:
	for child in get_children():
		child.queue_free()
	mode = m if MODES.has(m) else "classic"
	md = MODES[mode]
	mp = _mode_params(mode)

	layers = 0
	combo = 0
	_prev_center = CENTER_X
	_prev_width = START_WIDTH
	_speed = float(mp["base_speed"])
	fever_streak = int(mp["fever_streak"])
	_falling = false
	_rope = null
	_wind = 0.0
	playing = true

	_make_block(CENTER_X, BASE_Y, START_WIDTH, _layer_color(0))
	if md["movement"] == "pendulum":
		_rope = Line2D.new()
		_rope.width = 4.0
		_rope.default_color = Color(1, 1, 1, 0.35)
		add_child(_rope)
	if md["wind"]:
		_roll_wind()
	_spawn_moving()


func _mode_params(m: String) -> Dictionary:
	var p := {
		# shared
		"base_speed": 260.0, "speed_per_layer": 6.0, "max_speed": 700.0,
		"perfect_window": 7.0, "fever_streak": 5, "regrow_on_perfect": 4.0,
		# pendulum
		"rope_length": 430.0, "swing_amp": 1.05, "swing_speed": 2.4,
		"momentum_factor": 0.9,
		# pulse
		"pulse_speed": 2.6, "pulse_min": 0.35, "pulse_max": 1.45,
		# wind
		"wind_max": 220.0,
		# rush
		"chaos_period_min": 0.35, "chaos_period_max": 0.95,
		"chaos_flip_chance": 0.4, "chaos_burst": 1.8,
	}
	# Shared top-level config keys apply to every mode...
	p["fever_streak"] = int(Backend.cfg("fever_streak", p["fever_streak"]))
	p["regrow_on_perfect"] = float(Backend.cfg("regrow_on_perfect", p["regrow_on_perfect"]))
	# ...then per-mode overrides win.
	var cfg_modes: Variant = Backend.cfg("modes", {})
	if cfg_modes is Dictionary and cfg_modes.has(m) and cfg_modes[m] is Dictionary:
		for k in cfg_modes[m]:
			p[k] = cfg_modes[m][k]
	return p


func top_y() -> float:
	return BASE_Y - float(layers + 1) * LAYER_H


# ---------- per-frame movement ----------

func _process(delta: float) -> void:
	if not playing or _current == null:
		return
	_t += delta

	if _falling:
		_fall_vel.y += GRAVITY * delta
		_current.position += _fall_vel * delta
		if md["wind"]:
			_current.position.x += _wind * delta
		if _current.position.y >= _fall_target_y:
			_current.position.y = _fall_target_y
			_falling = false
			_place()
		return

	match md["movement"]:
		"slide":
			var speed := _speed
			if md["chaos"]:
				_chaos_tick(delta)
				if _burst_t > 0.0:
					_burst_t -= delta
					speed *= float(mp["chaos_burst"])
			_current.position.x += speed * _dir * delta
			var half := _prev_width * 0.5
			if _current.position.x > CENTER_X + SLIDE_RANGE - half:
				_current.position.x = CENTER_X + SLIDE_RANGE - half
				_dir = -1.0
			elif _current.position.x < CENTER_X - SLIDE_RANGE + half:
				_current.position.x = CENTER_X - SLIDE_RANGE + half
				_dir = 1.0
		"pendulum":
			var theta := float(mp["swing_amp"]) * sin(_t * float(mp["swing_speed"]))
			var pos := _pivot + float(mp["rope_length"]) * Vector2(sin(theta), cos(theta))
			if delta > 0.0:
				_vel_est = (pos - _last_pos) / delta
			_last_pos = pos
			_current.position = pos
			_rope.points = PackedVector2Array([_pivot, pos])
		"pulse":
			var span := float(mp["pulse_max"]) - float(mp["pulse_min"])
			var factor := float(mp["pulse_min"]) + span * (0.5 + 0.5 * sin(_t * float(mp["pulse_speed"])))
			_pulse_w = _prev_width * factor
			_rebuild(_current, _pulse_w)


func _chaos_tick(delta: float) -> void:
	_chaos_cd -= delta
	if _chaos_cd > 0.0:
		return
	_chaos_cd = randf_range(float(mp["chaos_period_min"]), float(mp["chaos_period_max"]))
	if randf() < float(mp["chaos_flip_chance"]):
		_dir *= -1.0
	else:
		_burst_t = 0.35


# ---------- input ----------

func drop() -> void:
	if not playing or _current == null or _falling:
		return
	if bool(md["falls"]):
		_falling = true
		_fall_target_y = BASE_Y - float(layers + 1) * LAYER_H
		if md["movement"] == "pendulum":
			_fall_vel = Vector2(_vel_est.x * float(mp["momentum_factor"]), maxf(_vel_est.y, 0.0))
			_rope.points = PackedVector2Array()
		else:
			_fall_vel = Vector2.ZERO  # wind drift is applied during the fall
		return
	_place()


# ---------- placement / slicing ----------

func _place() -> void:
	if md["movement"] == "pulse":
		_place_pulse()
	else:
		_place_positional()


func _place_positional() -> void:
	var delta_x := _current.position.x - _prev_center
	var overlap := _prev_width - absf(delta_x)

	if overlap <= 0.0:
		_fail_with_debris(signf(delta_x) if delta_x != 0.0 else 1.0)
		return

	var was_perfect := absf(delta_x) <= float(mp["perfect_window"])
	if was_perfect:
		combo += 1
		_current.position.x = _prev_center
		_regrow()
	else:
		combo = 0
		var new_center := _prev_center + delta_x * 0.5
		var debris_center := _prev_center + signf(delta_x) * (_prev_width * 0.5 + absf(delta_x) * 0.5)
		_to_debris(debris_center, _current.position.y, absf(delta_x), _current.color, signf(delta_x))
		_prev_width = overlap
		_prev_center = new_center
		_rebuild(_current, _prev_width)
		_current.position.x = new_center

	_finish_placement(was_perfect)


func _place_pulse() -> void:
	var w := _pulse_w
	var delta_w := w - _prev_width
	var was_perfect := absf(delta_w) <= float(mp["perfect_window"])

	if was_perfect:
		combo += 1
		_regrow()
		_rebuild(_current, _prev_width)
	elif delta_w > 0.0:
		# Oversized: trim both sides, spill two slivers.
		combo = 0
		var sliver := delta_w * 0.5
		var y := _current.position.y
		_to_debris(_prev_center - (_prev_width * 0.5 + sliver * 0.5), y, sliver, _current.color, -1.0)
		_to_debris(_prev_center + (_prev_width * 0.5 + sliver * 0.5), y, sliver, _current.color, 1.0)
		_rebuild(_current, _prev_width)
	else:
		# Undersized: the tower narrows to what you locked in.
		combo = 0
		_prev_width = w
		_rebuild(_current, _prev_width)
		if _prev_width < FAIL_WIDTH:
			_fail_with_debris(1.0 if randf() > 0.5 else -1.0)
			return

	_finish_placement(was_perfect)


func _regrow() -> void:
	var regrow := float(mp["regrow_on_perfect"])
	if regrow > 0.0:
		_prev_width = minf(START_WIDTH, _prev_width + regrow)
		_rebuild(_current, _prev_width)


func _finish_placement(was_perfect: bool) -> void:
	layers += 1
	_speed = minf(float(mp["max_speed"]), float(mp["base_speed"]) + float(layers) * float(mp["speed_per_layer"]))
	if md["wind"]:
		_roll_wind()
	layer_placed.emit(layers, was_perfect, combo)
	_current = null
	_spawn_moving()


func _fail_with_debris(side: float) -> void:
	playing = false
	_to_debris(_current.position.x, _current.position.y, maxf(_prev_width, 30.0), _current.color, side)
	_current.queue_free()
	_current = null
	if _rope != null and is_instance_valid(_rope):
		_rope.points = PackedVector2Array()
	stack_failed.emit(layers)


func _roll_wind() -> void:
	_wind = randf_range(-float(mp["wind_max"]), float(mp["wind_max"]))
	wind_changed.emit(_wind)


# ---------- spawning ----------

func _spawn_moving() -> void:
	var target_y := BASE_Y - float(layers + 1) * LAYER_H
	var col := _layer_color(layers + 1)
	_t = 0.0
	match md["movement"]:
		"pendulum":
			_pivot = Vector2(CENTER_X, target_y - float(mp["rope_length"]) - 60.0)
			var pos := _pivot + float(mp["rope_length"]) * Vector2(0.0, 1.0)
			_current = _make_block(pos.x, pos.y, _prev_width, col)
			_last_pos = pos
			_vel_est = Vector2.ZERO
		"pulse":
			_pulse_w = _prev_width * float(mp["pulse_min"])
			_current = _make_block(_prev_center, target_y, _pulse_w, col)
		_:
			var spawn_y := target_y - (170.0 if bool(md["falls"]) else 0.0)
			_dir = 1.0 if (layers % 2 == 0) else -1.0
			var start_x := CENTER_X - SLIDE_RANGE * _dir
			_current = _make_block(start_x, spawn_y, _prev_width, col)
			if md["chaos"]:
				_chaos_cd = randf_range(float(mp["chaos_period_min"]), float(mp["chaos_period_max"]))
				_burst_t = 0.0


# ---------- block helpers ----------

func _make_block(cx: float, y: float, w: float, col: Color) -> Polygon2D:
	var p := Polygon2D.new()
	_set_rect(p, w)
	p.color = col
	p.position = Vector2(cx, y)
	var strip := Polygon2D.new()
	strip.name = "Strip"
	strip.color = col.darkened(0.25)
	p.add_child(strip)
	_set_strip(strip, w)
	add_child(p)
	return p


func _rebuild(p: Polygon2D, w: float) -> void:
	_set_rect(p, w)
	_set_strip(p.get_node("Strip") as Polygon2D, w)


func _set_rect(p: Polygon2D, w: float) -> void:
	var hw := w * 0.5
	var hh := LAYER_H * 0.5
	p.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
	])


func _set_strip(strip: Polygon2D, w: float) -> void:
	var h := LAYER_H * 0.5
	strip.polygon = PackedVector2Array([
		Vector2(-w * 0.5, h - 12.0), Vector2(w * 0.5, h - 12.0),
		Vector2(w * 0.5, h), Vector2(-w * 0.5, h),
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
