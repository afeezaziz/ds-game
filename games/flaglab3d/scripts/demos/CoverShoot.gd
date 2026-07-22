extends MechDemo3D
## Third-person COVER SHOOTER (Gears loop). Stick moves; COVER snaps you to the
## nearest chest-high block (safe — enemy fire blocked); FIRE from cover PEEKS you
## out (risky window) to shoot. Enemies pop from their own cover to fire; hold fire
## on one to SUPPRESS it. Clear the wave to ADVANCE. HP 0 = out. Keys: SPACE / C.

enum State { EXPOSED, COVER }

const SPEED := 6.0
const RANGE := 26.0
const AIM_COS := 0.8          # auto-aim cone (cos ~37 deg)
const FIRE_CD := 0.16
const PEEK_TIME := 0.6        # player pop-out window when firing from cover
const ENEMY_PEEK := 1.4       # window an enemy is hittable/dangerous
const ENEMY_DMG := 8
const SUPPRESS := 1.3         # how long one shot pins an enemy behind cover
const COVER_REACH := 3.2
const CAM_OFF := Vector3(0, 5.5, 8.0)

var tc: TouchControls
var player: MeshInstance3D
var _hud: Label
var enemies: Array[Dictionary] = []
var props: Array[Node3D] = []          # all static boxes (freed on rebuild)
var covers: Array[Node3D] = []         # player-snappable cover subset
var state := State.EXPOSED
var hp := 100
var wave := 1
var kills := 0
var peek_t := 0.0
var fire_cd := 0.0
var _shake := 0.0

func start() -> void:
	super.start()
	setup_world(Color(0.14, 0.15, 0.19), 0.75, Vector3(-60, -35, 0))
	static_box(Vector3(40, 1, 140), Vector3(0, -0.5, -30), Color(0.2, 0.22, 0.26))
	player = mesh_box(Vector3(0.8, 1.8, 0.8), Vector3(0, 0.9, 6), Color(0.42, 0.72, 0.55))
	mesh_box(Vector3(0.5, 0.28, 1.1), Vector3(0.25, 0.2, -0.5), Color(0.18, 0.18, 0.2), player)
	make_camera(player.position + CAM_OFF, player.position, 62.0)
	tc = add_touch_controls([
		{"id": "fire", "label": "FIRE", "col": Color(0.9, 0.4, 0.35)},
		{"id": "cover", "label": "COVER", "col": Color(0.5, 0.7, 0.9)},
	])
	tc.action.connect(func(id):
		if id == "fire":
			_fire()
		elif id == "cover":
			_toggle_cover())
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	_hud = Label.new()
	_hud.add_theme_font_size_override("font_size", 34)
	_hud.position = Vector2(24, 42)
	layer.add_child(_hud)
	hp = 100
	wave = 1
	kills = 0
	state = State.EXPOSED
	_build_wave()

func _cool() -> float:
	# harder waves = enemies pop out more often
	return randf_range(maxf(0.5, 1.8 - wave * 0.12), maxf(1.2, 3.2 - wave * 0.18))

func _build_wave() -> void:
	for e in enemies:
		(e["node"] as Node).queue_free()
	enemies.clear()
	for p in props:
		p.queue_free()
	props.clear()
	covers.clear()
	var pz: float = player.position.z
	for i in 3:
		var c := static_box(Vector3(2.4, 1.2, 0.8), Vector3(-5.0 + i * 5.0, 0.6, pz - 4.0),
			Color(0.4, 0.42, 0.48))
		props.append(c)
		covers.append(c)
	var n := mini(1 + wave, 6)
	var ez := pz - 16.0
	for i in n:
		var x := (-6.0 + i * (12.0 / maxf(1.0, n - 1))) if n > 1 else 0.0
		props.append(static_box(Vector3(2.4, 1.2, 0.8), Vector3(x, 0.6, ez), Color(0.5, 0.4, 0.42)))
		var soldier := mesh_box(Vector3(0.7, 1.4, 0.7), Vector3(x, 0.7, ez - 0.6), Color(0.82, 0.35, 0.35))
		var side := 1.4 if i % 2 == 0 else -1.4
		enemies.append({
			"node": soldier, "alive": true, "exposed": false, "peek": 0.0,
			"cd": randf_range(0.6, 2.2), "shot": 0.0, "sup": 0.0, "hp": 2,
			"tuckpos": Vector3(x, 0.7, ez - 0.6), "peekpos": Vector3(x + side, 1.0, ez + 0.4),
		})

func _vulnerable() -> bool:
	# safe only when fully tucked; peeking or moving = can be hit
	return state == State.EXPOSED or peek_t > 0.0

func _aim_target() -> int:
	# nearest live enemy inside the forward auto-aim cone within range
	var best := -1
	var best_d := RANGE
	for i in enemies.size():
		var e := enemies[i]
		if not e["alive"]:
			continue
		var to: Vector3 = (e["node"] as Node3D).position - player.position
		var d := to.length()
		if d < 0.1 or d > RANGE or to.z >= 0.0:
			continue
		if Vector3(0, 0, -1).dot(to / d) < AIM_COS:
			continue
		if d < best_d:
			best_d = d
			best = i
	return best

func _fire() -> void:
	if not running or fire_cd > 0.0:
		return
	fire_cd = FIRE_CD
	if state == State.COVER and peek_t <= 0.0:
		peek_t = PEEK_TIME             # firing from cover pops you out
	Juice.sfx("tick", 1.2)
	var i := _aim_target()
	if i < 0:
		return
	var e := enemies[i]
	e["sup"] = SUPPRESS                # suppression: pin them behind cover
	_tracer(player.position + Vector3(0, 1, -0.6), (e["node"] as Node3D).position, Color(1, 0.9, 0.45))
	if e["exposed"]:                   # only a peeking enemy can be hit
		e["hp"] -= 1
		Juice.haptic(12)
		if e["hp"] <= 0:
			_kill(i)

func _kill(i: int) -> void:
	var e := enemies[i]
	e["alive"] = false
	(e["node"] as MeshInstance3D).visible = false
	kills += 1
	add_points(5)
	Juice.sfx("thud", 0.9)
	Juice.flash(Color(1, 0.8, 0.4), 0.18)
	Juice.haptic(25)
	_shake = maxf(_shake, 0.3)
	for en in enemies:
		if en["alive"]:
			return
	_advance()

func _advance() -> void:
	wave += 1
	add_points(10)
	Juice.sfx("chime")
	Juice.flash(Color(0.4, 0.9, 0.5), 0.3)
	_shake = maxf(_shake, 0.25)
	player.position.z -= 12.0          # territory gained: push forward
	state = State.EXPOSED
	peek_t = 0.0
	_build_wave()

func _toggle_cover() -> void:
	if not running:
		return
	if state == State.COVER:
		state = State.EXPOSED
		peek_t = 0.0
		Juice.sfx("tick", 0.8)
		return
	var best := -1
	var bd := COVER_REACH
	for i in covers.size():
		var d: float = covers[i].position.distance_to(player.position)
		if d < bd:
			bd = d
			best = i
	if best < 0:
		Juice.sfx("tick", 0.6)         # nothing in reach to grab
		return
	player.position = covers[best].position + Vector3(0, 0.9, 0.9)
	state = State.COVER
	peek_t = 0.0
	Juice.sfx("thud", 1.3)
	Juice.haptic(15)

func _enemy_fire(e: Dictionary) -> void:
	_tracer((e["node"] as Node3D).position, player.position + Vector3(0, 1, 0), Color(1, 0.5, 0.4))
	if not _vulnerable():
		return                         # blocked by cover
	hp -= ENEMY_DMG
	Juice.sfx("thud")
	Juice.flash(Color(1, 0.3, 0.3), 0.3)
	Juice.haptic(20)
	_shake = maxf(_shake, 0.35)
	if hp <= 0:
		hp = 0
		Juice.sfx("boom")
		Juice.flash(Color(1, 0.2, 0.2), 0.5)
		_shake = 0.9
		end_demo()

func _update_enemies(delta: float) -> void:
	for e in enemies:
		if not e["alive"]:
			continue
		if e["sup"] > 0.0:
			e["sup"] -= delta
		var tp: Vector3 = e["tuckpos"]
		if e["exposed"]:
			e["peek"] -= delta
			e["shot"] -= delta
			if e["shot"] <= 0.0:
				e["shot"] = 0.5
				_enemy_fire(e)
			if e["peek"] <= 0.0:
				e["exposed"] = false
				e["cd"] = _cool()
			tp = e["peekpos"]
		else:
			e["cd"] -= delta
			if e["sup"] > 0.0:
				e["cd"] = maxf(e["cd"], 0.4)   # suppressed: stays pinned
			if e["cd"] <= 0.0:
				e["exposed"] = true
				e["peek"] = ENEMY_PEEK
				e["shot"] = 0.25
		var nd: Node3D = e["node"]
		nd.position = nd.position.lerp(tp, 8.0 * delta)

func _tracer(a: Vector3, b: Vector3, col: Color) -> void:
	var t := mesh_box(Vector3(0.12, 0.12, a.distance_to(b)), (a + b) * 0.5, col)
	t.look_at(b, Vector3.UP)
	var tw := create_tween()
	tw.tween_property(t, "scale", Vector3(0.1, 0.1, 1.0), 0.1)
	tw.tween_callback(t.queue_free)

func _process(delta: float) -> void:
	if not running:
		return
	fire_cd = maxf(0.0, fire_cd - delta)
	peek_t = maxf(0.0, peek_t - delta)
	if state == State.EXPOSED:
		var mv := Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())
		if mv.length() > 0.05:
			player.position += mv.limit_length(1.0) * SPEED * delta
			player.position.x = clampf(player.position.x, -12.0, 12.0)
	if tc.held("fire") or Input.is_key_pressed(KEY_SPACE):
		_fire()
	var crouch := state == State.COVER and peek_t <= 0.0
	player.scale.y = lerpf(player.scale.y, 0.6 if crouch else 1.0, 12.0 * delta)
	_update_enemies(delta)
	_shake = maxf(0.0, _shake - delta * 1.5)
	cam.position = player.position + CAM_OFF + Vector3(randf_range(-_shake, _shake), randf_range(-_shake, _shake), 0)
	cam.look_at(player.position + Vector3(0, 1.0, -6.0), Vector3.UP)
	var st := "IN COVER" if state == State.COVER else "EXPOSED"
	if state == State.COVER and peek_t > 0.0:
		st = "PEEKING!"
	_hud.text = "HP %d\nSTATE: %s\nWAVE %d   KILLS %d" % [hp, st, wave, kills]

func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_fire()
		elif event.keycode == KEY_C:
			_toggle_cover()
