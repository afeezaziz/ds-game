extends MechDemo3D
## PARTY GAMES — a microgame gauntlet (Mario Party). Each round is a different quick
## test: MASH the button, DODGE the falling blocks, or REACT the instant it says GO.
## Win to score; flub three and the party's over. Desktop: WASD move, SPACE / J action.

enum Ph { INTRO, PLAY, RESULT }
var game := 0                 # 0 mash, 1 dodge, 2 react
var ph: Ph = Ph.INTRO
var timer := 0.0
var taps := 0
var target := 0
var go_time := 0.0
var reacted := false
var won_round := false
var fails := 0
var player: Node3D
var px := 0.0
var blocks: Array = []        # {node,x,z}
var tc: TouchControls
var hud: Label3D
const NAMES := ["MASH!", "DODGE!", "REACT!"]


func start() -> void:
	super.start()
	setup_world(Color(0.5, 0.4, 0.7), 0.95, Vector3(-50, -20, 0))
	static_box(Vector3(24, 1, 24), Vector3(0, -0.5, 0), Color(0.4, 0.35, 0.5))
	player = Node3D.new()
	add_child(player)
	mesh_box(Vector3(1.4, 1.6, 1.4), Vector3(0, 0.8, 0), Color(0.95, 0.85, 0.3), player)
	fails = 0
	make_camera(Vector3(0, 12, 14), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(0, 9, 0), 34, Color.WHITE)
	tc = add_touch_controls([{"id": "act", "label": "ACT!", "col": Color(0.9, 0.7, 0.3)}])
	tc.action.connect(func(_id): _action())
	_next_game()


func _next_game() -> void:
	game = randi() % 3
	ph = Ph.INTRO
	timer = 1.4
	for b in blocks:
		b.node.queue_free()
	blocks = []
	px = 0.0
	Juice.sfx("tick")


func _begin_play() -> void:
	ph = Ph.PLAY
	won_round = false
	if game == 0:
		taps = 0
		target = 14 + score
		timer = 4.0
	elif game == 1:
		timer = 5.0
		px = 0.0
	else:
		reacted = false
		go_time = randf_range(1.2, 3.5)
		timer = go_time + 1.2


func _action() -> void:
	if ph != Ph.PLAY:
		return
	if game == 0:
		taps += 1
		Juice.sfx("tick")
	elif game == 2:
		if go_time > 0.0:
			_finish(false)       # jumped the gun
		else:
			reacted = true
			_finish(true)


func _finish(win: bool) -> void:
	ph = Ph.RESULT
	timer = 1.6
	won_round = win
	if win:
		add_points(1)
		Juice.sfx("coin")
		Juice.flash(Color(0.6, 1, 0.6), 0.25)
		Juice.popup("WIN!", Vector2(W * 0.5, H * 0.36), Color(1, 0.9, 0.4))
	else:
		fails += 1
		Juice.sfx("boom")
		Juice.flash(Color(1, 0.3, 0.3), 0.3)
		Juice.haptic(30)
		Juice.popup("FAIL (%d/3)" % fails, Vector2(W * 0.5, H * 0.36), Color(1, 0.5, 0.4))


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_J):
		_action()


func _process(delta: float) -> void:
	if not running:
		return
	timer -= delta
	match ph:
		Ph.INTRO:
			if timer <= 0.0:
				_begin_play()
		Ph.PLAY:
			_play(delta)
		Ph.RESULT:
			if timer <= 0.0:
				if fails >= 3:
					end_demo()
					return
				_next_game()

	player.position.x = px
	cam.position = Vector3(0, 12, 14)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	var line := ""
	match ph:
		Ph.INTRO: line = "GET READY:  %s" % NAMES[game]
		Ph.RESULT: line = "WIN!" if won_round else "missed!"
		Ph.PLAY:
			if game == 0: line = "MASH!  %d / %d" % [taps, target]
			elif game == 1: line = "DODGE!  %.1fs" % maxf(0.0, timer)
			else: line = "wait..." if go_time > 0.0 else ">>> GO! TAP! <<<"
	hud.text = "%s\nscore %d   fails %d/3" % [line, score, fails]
	hud.position = Vector3(0, 9, 0)


func _play(delta: float) -> void:
	if game == 0:
		if timer <= 0.0:
			_finish(taps >= target)
	elif game == 1:
		px = clampf(px + (tc.move.x + key_axis_x()) * 12.0 * delta, -10, 10)
		if randf() < delta * 6.0:
			var x := randf_range(-10, 10)
			var node := mesh_box(Vector3(1.4, 1.4, 1.4), Vector3(x, 12, 0), Color(0.9, 0.4, 0.4))
			blocks.append({"node": node, "x": x, "z": 0.0})
		for b in blocks.duplicate():
			b.node.position.y -= 16.0 * delta
			if b.node.position.y <= 0.8:
				if absf(b.x - px) < 1.4:
					_finish(false)
					return
				b.node.queue_free()
				blocks.erase(b)
		if timer <= 0.0:
			_finish(true)
	else:
		go_time = maxf(0.0, go_time - delta)
		if timer <= 0.0 and not reacted:
			_finish(false)
