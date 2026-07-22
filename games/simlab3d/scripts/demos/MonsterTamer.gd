extends MechDemo3D
## MONSTER TAMER — catch, team, battle (Pokémon / Palworld). Roam the grass; bump a
## wild creature to start a turn-based duel. ATTACK to whittle it down, then CATCH
## (odds rise as its HP drops) to add it to your team, or SWITCH your active fighter.
## Build a roster and win battles. Desktop: WASD roam; J attack, K catch, L switch.

enum Mode { ROAM, BATTLE }
var mode: Mode = Mode.ROAM
var player: Node3D
var ppos := Vector3.ZERO
var wilds: Array = []         # {node,pos}
var team: Array = []          # {name,hp,maxhp,atk}
var active := 0
var foe := {}                 # {name,hp,maxhp,atk,node}
var msg := ""
var msg_t := 0.0
var caught := 0
var wins := 0
var tc: TouchControls
var hud: Label3D
const NAMES := ["Emberling", "Aquatot", "Leafkin", "Sparkmouse", "Rockpup", "Gustling"]


func start() -> void:
	super.start()
	setup_world(Color(0.55, 0.78, 0.6), 0.95, Vector3(-55, -30, 0))
	static_box(Vector3(60, 1, 60), Vector3(0, -0.5, 0), Color(0.3, 0.6, 0.35))
	player = Node3D.new()
	add_child(player)
	mesh_box(Vector3(1.0, 1.8, 1.0), Vector3(0, 0.9, 0), Color(0.9, 0.85, 0.4), player)
	team = [{"name": "Emberling", "hp": 30, "maxhp": 30, "atk": 8}]
	active = 0
	caught = 1
	wins = 0
	wilds = []
	for i in 6:
		_spawn_wild()
	make_camera(Vector3(0, 16, 16), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(0, 10, 0), 30, Color.WHITE)
	tc = add_touch_controls([
		{"id": "attack", "label": "ATTACK", "col": Color(0.9, 0.5, 0.4)},
		{"id": "catch", "label": "CATCH", "col": Color(0.9, 0.8, 0.3)},
		{"id": "switch", "label": "SWITCH", "col": Color(0.5, 0.75, 0.95)},
	])
	tc.action.connect(func(id):
		if id == "attack": _attack()
		elif id == "catch": _catch()
		elif id == "switch": _switch())


func _spawn_wild() -> void:
	var node := Node3D.new()
	add_child(node)
	mesh_box(Vector3(1.4, 1.4, 1.4), Vector3(0, 0.7, 0), hue_col(randi() % 6 * 0.16, 0.6, 0.9), node)
	node.position = Vector3(randf_range(-26, 26), 0, randf_range(-26, 26))
	wilds.append({"node": node, "pos": node.position})


func _start_battle(w: Dictionary) -> void:
	mode = Mode.BATTLE
	var lvl := 1 + wins / 2
	var mx := 22 + lvl * 6
	foe = {"name": NAMES[randi() % NAMES.size()], "hp": mx, "maxhp": mx, "atk": 5 + lvl * 2, "node": w.node}
	w.node.position = Vector3(6, 1, -6)
	w.node.scale = Vector3.ONE * 2.0
	wilds.erase(w)
	_say("A wild %s appeared!" % foe.name)


func _active_mon():
	return team[active]


func _attack() -> void:
	if mode != Mode.BATTLE:
		return
	var m = _active_mon()
	foe.hp -= m.atk + randi_range(0, 4)
	Juice.sfx("thud")
	Juice.hitstop(30)
	if foe.hp <= 0:
		wins += 1
		add_points(2)
		Juice.sfx("boom")
		_end_battle("%s fainted — you won!" % foe.name)
		return
	_foe_turn()


func _catch() -> void:
	if mode != Mode.BATTLE:
		return
	var odds := 0.15 + (1.0 - float(foe.hp) / foe.maxhp) * 0.7
	if randf() < odds:
		team.append({"name": foe.name, "hp": foe.maxhp, "maxhp": foe.maxhp, "atk": foe.atk})
		caught += 1
		add_points(3)
		Juice.sfx("coin")
		Juice.flash(Color(1, 0.9, 0.5), 0.3)
		_end_battle("Gotcha! %s joined the team." % foe.name)
	else:
		_say("Almost! It broke free.")
		_foe_turn()


func _switch() -> void:
	if mode != Mode.BATTLE or team.size() < 2:
		return
	for k in team.size():
		active = (active + 1) % team.size()
		if team[active].hp > 0:
			break
	_say("Go, %s!" % _active_mon().name)
	_foe_turn()


func _foe_turn() -> void:
	var m = _active_mon()
	m.hp -= foe.atk + randi_range(0, 3)
	Juice.flash(Color(1, 0.4, 0.4), 0.15)
	Juice.haptic(15)
	if m.hp <= 0:
		m.hp = 0
		var any := team.filter(func(t): return t.hp > 0)
		if any.is_empty():
			end_demo()
		else:
			_say("%s fainted! Switch." % m.name)
			for i in team.size():
				if team[i].hp > 0:
					active = i
					break


func _end_battle(text: String) -> void:
	if is_instance_valid(foe.node):
		foe.node.queue_free()
	foe = {}
	mode = Mode.ROAM
	_say(text)
	# heal team a little and repopulate the grass
	for t in team:
		t.hp = mini(t.maxhp, t.hp + 8)
	if wilds.size() < 6:
		_spawn_wild()


func _say(t: String) -> void:
	msg = t
	msg_t = 2.5


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J: _attack()
		elif event.keycode == KEY_K: _catch()
		elif event.keycode == KEY_L: _switch()


func _process(delta: float) -> void:
	if not running:
		return
	msg_t = maxf(0.0, msg_t - delta)
	if mode == Mode.ROAM:
		var mv := Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())
		if mv.length() > 1.0:
			mv = mv.normalized()
		ppos += mv * 9.0 * delta
		ppos.x = clampf(ppos.x, -28, 28)
		ppos.z = clampf(ppos.z, -28, 28)
		player.position = ppos
		if mv.length() > 0.1:
			player.rotation.y = atan2(mv.x, mv.z)
		for w in wilds:
			w.node.position = w.pos + Vector3(0, sin(Time.get_ticks_msec() * 0.003 + w.pos.x) * 0.2, 0)
			if ppos.distance_to(w.pos) < 2.0:
				_start_battle(w)
				break
		cam.position = ppos + Vector3(0, 16, 16)
		cam.look_at(ppos, Vector3.UP)
	else:
		player.position = Vector3(-6, 0, 4)
		cam.position = Vector3(0, 6, 12)
		cam.look_at(Vector3(0, 1, -2), Vector3.UP)

	var m = _active_mon()
	if mode == Mode.BATTLE:
		hud.text = "%s HP %d/%d   vs   %s HP %d/%d\ncatch odds ~%d%%   team %d\n%s" % [
			m.name, maxi(0, m.hp), m.maxhp, foe.get("name", "?"), maxi(0, foe.get("hp", 0)), foe.get("maxhp", 1),
			int((0.15 + (1.0 - float(foe.get("hp", 0)) / maxi(1, foe.get("maxhp", 1))) * 0.7) * 100), team.size(),
			msg if msg_t > 0.0 else ""]
		hud.position = Vector3(0, 6, -2)
	else:
		hud.text = "roam the grass — caught %d, wins %d, team %d\n%s" % [
			caught, wins, team.size(), msg if msg_t > 0.0 else ""]
		hud.position = ppos + Vector3(0, 9, 0)
