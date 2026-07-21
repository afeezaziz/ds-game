class_name ZigWorld
extends Node3D
## ZigRoll core: a ball rolls along a floating zigzag path of tiles.
## Tap toggles the roll direction between +X and +Z. Leave the path and you
## fall. Gems give bonus score. Tiles crumble away behind you.
## All tuning comes from remote config with safe local defaults.

signal score_changed(score: int)
signal gems_changed(gems: int)
signal game_ended(score: int)

const TILE := 2.0
const DIR_A := Vector3(1, 0, 0)
const DIR_B := Vector3(0, 0, 1)

var playing := false
var score := 0
var gems := 0

# tunables (remote config)
var speed0 := 4.2
var speed_gain := 0.05
var max_speed := 9.5
var gem_rate := 0.16
var gem_bonus := 5
var drop_margin := 0.22

var _ball: MeshInstance3D
var _dir := DIR_A
var _speed := 4.2
var _tiles: Array = []  # {c: Vector3, node: MeshInstance3D, gem: MeshInstance3D|null, passed: bool}
var _last_center := Vector3.ZERO
var _falling := false
var _fall_vel := 0.0
var _fall_t := 0.0
var _count := 0


func start_game() -> void:
	for child in get_children():
		child.queue_free()
	_tiles.clear()
	score = 0
	gems = 0
	_count = 0
	speed0 = float(Backend.cfg("speed", speed0))
	speed_gain = float(Backend.cfg("speed_gain", speed_gain))
	max_speed = float(Backend.cfg("max_speed", max_speed))
	gem_rate = float(Backend.cfg("gem_rate", gem_rate))
	gem_bonus = int(Backend.cfg("gem_bonus", gem_bonus))
	drop_margin = float(Backend.cfg("drop_margin", drop_margin))
	_speed = speed0
	_dir = DIR_A
	_falling = false
	_fall_vel = 0.0
	_fall_t = 0.0

	# Starting runway, then a procedural zigzag ahead.
	_last_center = Vector3.ZERO
	_spawn_tile(_last_center, false)
	for i in 5:
		_last_center += DIR_A * TILE
		_spawn_tile(_last_center, false)
	for i in 26:
		_add_next()

	_ball = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1)
	mat.roughness = 0.3
	sphere.material = mat
	_ball.mesh = sphere
	_ball.position = Vector3(0, 0.35, 0)
	add_child(_ball)

	playing = true


func tap() -> void:
	if playing and not _falling:
		_dir = DIR_B if _dir == DIR_A else DIR_A


func ball_pos() -> Vector3:
	if _ball != null and is_instance_valid(_ball):
		return _ball.position
	return Vector3.ZERO


func _process(delta: float) -> void:
	if not playing or _ball == null:
		return

	if _falling:
		_fall_vel += 30.0 * delta
		_ball.position.y -= _fall_vel * delta
		_ball.position += _dir * _speed * 0.35 * delta
		_fall_t += delta
		if _fall_t > 0.9:
			playing = false
			game_ended.emit(score)
		return

	_ball.position += _dir * _speed * delta
	_ball.rotate_x(_dir.z * _speed * delta * 2.0)
	_ball.rotate_z(-_dir.x * _speed * delta * 2.0)

	# Support check: is the ball over any tile?
	var supported := false
	for t in _tiles:
		if absf(_ball.position.x - t.c.x) <= TILE * 0.5 + drop_margin \
				and absf(_ball.position.z - t.c.z) <= TILE * 0.5 + drop_margin:
			supported = true
			break
	if not supported:
		_falling = true
		return

	# Gems + tile passing (duplicate: we mutate the list as we go).
	var progress := _ball.position.x + _ball.position.z
	for t in _tiles.duplicate():
		if t.gem != null and is_instance_valid(t.gem) \
				and _ball.position.distance_to(t.gem.position) < 0.7:
			gems += 1
			score += gem_bonus
			t.gem.queue_free()
			t.gem = null
			gems_changed.emit(gems)
			score_changed.emit(score)
		if not t.passed and progress > (t.c.x + t.c.z) + TILE * 0.6:
			t.passed = true
			score += 1
			score_changed.emit(score)
			_speed = minf(max_speed, _speed + speed_gain)
			_crumble(t)
			_add_next()


func _add_next() -> void:
	var dir := DIR_A if randf() < 0.5 else DIR_B
	_last_center += dir * TILE
	_spawn_tile(_last_center, randf() < gem_rate)


func _spawn_tile(c: Vector3, with_gem: bool) -> void:
	_count += 1
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(TILE, 0.5, TILE)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.from_hsv(fmod(0.58 + float(_count) * 0.006, 1.0), 0.45, 0.85)
	mat.roughness = 0.9
	box.material = mat
	node.mesh = box
	node.position = c + Vector3(0, -0.25, 0)
	add_child(node)

	var gem: MeshInstance3D = null
	if with_gem:
		gem = MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.18
		s.height = 0.36
		var gmat := StandardMaterial3D.new()
		gmat.albedo_color = Color(1, 0.8, 0.2)
		gmat.emission_enabled = true
		gmat.emission = Color(1, 0.75, 0.1)
		gmat.emission_energy_multiplier = 1.4
		s.material = gmat
		gem.mesh = s
		gem.position = c + Vector3(0, 0.55, 0)
		add_child(gem)

	_tiles.append({"c": c, "node": node, "gem": gem, "passed": false})


func _crumble(t: Dictionary) -> void:
	var tw := create_tween()
	tw.tween_interval(0.65)
	tw.tween_property(t.node, "position:y", -9.0, 0.55).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if t.gem != null and is_instance_valid(t.gem):
			t.gem.queue_free()
		if is_instance_valid(t.node):
			t.node.queue_free()
		_tiles.erase(t))
