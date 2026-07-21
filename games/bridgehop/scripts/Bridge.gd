class_name BridgeWorld
extends Node3D
## BridgeHop core: hold to grow a beam, release to drop it across the gap.
## Land the tip on the next pillar to cross; hit the red center strip for a
## perfect (+bonus, combo). Miss and the beam tips into the void with you.
## No physics engine — a small state machine with tweens. Remote-config tuned.

signal score_changed(score: int)
signal game_ended(score: int)
signal perfect_landed(combo: int)

enum S { DEAD, IDLE, GROWING, DROPPING, WALKING, FALLING }

const BEAM_THICK := 0.12
const MAX_BEAM := 10.0
const PLAYER_SIZE := 0.5

var playing := false
var state: S = S.DEAD
var score := 0
var combo := 0

# tunables (remote config)
var grow_speed := 5.5
var gap_min := 1.2
var gap_max := 4.0
var width_min := 1.0
var width_max := 2.4
var perfect_zone := 0.22
var perfect_bonus := 1

var _plats: Array = []  # [{x0, w, node}] — index 0 = current, 1 = next target
var _player: MeshInstance3D
var _pivot: Node3D
var _beam: MeshInstance3D
var _beam_len := 0.0
var _cur_end := 0.0
var _count := 0


func start_game() -> void:
	for child in get_children():
		child.queue_free()
	_plats.clear()
	score = 0
	combo = 0
	_count = 0
	grow_speed = float(Backend.cfg("grow_speed", grow_speed))
	gap_min = float(Backend.cfg("gap_min", gap_min))
	gap_max = float(Backend.cfg("gap_max", gap_max))
	width_min = float(Backend.cfg("width_min", width_min))
	width_max = float(Backend.cfg("width_max", width_max))
	perfect_zone = float(Backend.cfg("perfect_zone", perfect_zone))
	perfect_bonus = int(Backend.cfg("perfect_bonus", perfect_bonus))

	_spawn_plat(-2.0, 2.0)
	_cur_end = 0.0
	_spawn_next()

	_player = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(PLAYER_SIZE, PLAYER_SIZE * 1.2, PLAYER_SIZE)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1)
	mat.roughness = 0.35
	box.material = mat
	_player.mesh = box
	_player.position = Vector3(-0.4, PLAYER_SIZE * 0.6, 0)
	add_child(_player)

	playing = true
	state = S.IDLE


func player_x() -> float:
	if _player != null and is_instance_valid(_player):
		return _player.position.x
	return 0.0


func press_start() -> void:
	if not playing or state != S.IDLE:
		return
	state = S.GROWING
	_beam_len = 0.05
	_pivot = Node3D.new()
	_pivot.position = Vector3(_cur_end, 0, 0)
	add_child(_pivot)
	_beam = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(BEAM_THICK, _beam_len, BEAM_THICK)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.85, 0.3)
	mat.roughness = 0.5
	box.material = mat
	_beam.mesh = box
	_beam.position = Vector3(0, _beam_len * 0.5, 0)
	_pivot.add_child(_beam)


func press_end() -> void:
	if not playing or state != S.GROWING:
		return
	state = S.DROPPING
	Analytics.track("beam_drop", {"len": _beam_len})
	var tw := create_tween()
	tw.tween_property(_pivot, "rotation_degrees:z", -90.0, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(_evaluate)


func _process(delta: float) -> void:
	if state == S.GROWING:
		_beam_len = minf(MAX_BEAM, _beam_len + grow_speed * delta)
		var box := _beam.mesh as BoxMesh
		box.size = Vector3(BEAM_THICK, _beam_len, BEAM_THICK)
		_beam.position = Vector3(0, _beam_len * 0.5, 0)


func _evaluate() -> void:
	var tip := _cur_end + _beam_len
	var nxt: Dictionary = _plats[1]
	var landed: bool = tip >= float(nxt.x0) and tip <= float(nxt.x0) + float(nxt.w)

	if landed:
		var center := float(nxt.x0) + float(nxt.w) * 0.5
		var is_perfect := absf(tip - center) <= perfect_zone
		state = S.WALKING
		var target_x := float(nxt.x0) + float(nxt.w) - 0.35
		var dur := clampf((target_x - _player.position.x) * 0.13, 0.2, 1.4)
		var tw := create_tween()
		tw.tween_property(_player, "position:x", target_x, dur)
		tw.tween_callback(func(): _crossed(nxt, is_perfect))
	else:
		state = S.FALLING
		var walk_x := _cur_end + _beam_len - 0.1
		var tw := create_tween()
		tw.tween_property(_player, "position:x", walk_x, clampf(_beam_len * 0.13, 0.2, 1.2))
		tw.tween_callback(func():
			var tw2 := create_tween()
			tw2.set_parallel(true)
			tw2.tween_property(_player, "position:y", -9.0, 0.6).set_ease(Tween.EASE_IN)
			tw2.tween_property(_pivot, "rotation_degrees:z", -180.0, 0.45).set_ease(Tween.EASE_IN)
			tw2.chain().tween_callback(func():
				playing = false
				state = S.DEAD
				game_ended.emit(score)))


func _crossed(nxt: Dictionary, is_perfect: bool) -> void:
	score += 1
	if is_perfect:
		score += perfect_bonus
		combo += 1
		perfect_landed.emit(combo)
	else:
		combo = 0
	score_changed.emit(score)

	# retire old platform + beam
	var old: Dictionary = _plats.pop_front()
	var tw := create_tween()
	tw.tween_property(old.node, "position:y", -14.0, 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(old.node.queue_free)
	if _pivot != null and is_instance_valid(_pivot):
		var tw2 := create_tween()
		tw2.tween_property(_pivot, "position:y", -14.0, 0.5).set_ease(Tween.EASE_IN)
		tw2.tween_callback(_pivot.queue_free)

	_cur_end = float(nxt.x0) + float(nxt.w)
	_spawn_next()
	state = S.IDLE


func _spawn_next() -> void:
	var gap := randf_range(gap_min, gap_max)
	var w := randf_range(width_min, width_max)
	_spawn_plat(_cur_end + gap, w)


func _spawn_plat(x0: float, w: float) -> void:
	_count += 1
	var node := Node3D.new()
	node.position = Vector3(x0 + w * 0.5, 0, 0)
	add_child(node)

	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(w, 7.0, 2.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.from_hsv(fmod(0.72 + float(_count) * 0.05, 1.0), 0.4, 0.75)
	mat.roughness = 0.9
	box.material = mat
	body.mesh = box
	body.position = Vector3(0, -3.5, 0)
	node.add_child(body)

	var strip := MeshInstance3D.new()
	var sbox := BoxMesh.new()
	sbox.size = Vector3(minf(perfect_zone * 2.0, w * 0.5), 0.06, 2.04)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(1, 0.25, 0.25)
	smat.emission_enabled = true
	smat.emission = Color(1, 0.2, 0.2)
	smat.emission_energy_multiplier = 1.2
	sbox.material = smat
	strip.mesh = sbox
	strip.position = Vector3(0, 0.03, 0)
	node.add_child(strip)

	_plats.append({"x0": x0, "w": w, "node": node})
