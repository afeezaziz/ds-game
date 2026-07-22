extends MechDemo3D
## TURN-BASED JRPG — party + ATB (Final Fantasy). Each hero's ATB bar fills in real
## time; when one is READY, pick ATTACK, a SKILL (spends MP — fire-all / heal / heavy)
## or TARGET the next foe. Enemies act on their own bars. Wipe the waves; a party wipe
## ends it. Desktop: J attack, K skill, L cycle target, SPACE guard.

var heroes: Array = []        # {node,name,hp,maxhp,mp,atb,alive,guard}
var foes: Array = []          # {node,hp,maxhp,atb,alive}
var ready := -1               # hero index awaiting orders, else -1
var target := 0
var wave := 1
var tc: TouchControls
var hud: Label3D
const SKILLS := ["FIRE-ALL", "HEAL", "HEAVY"]


func start() -> void:
	super.start()
	setup_world(Color(0.1, 0.12, 0.2), 0.85, Vector3(-55, -20, 0))
	static_box(Vector3(40, 1, 24), Vector3(0, -0.5, 0), Color(0.25, 0.28, 0.34))
	heroes = []
	var hnames := ["KNIGHT", "MAGE", "ROGUE"]
	for i in 3:
		var node := Node3D.new()
		add_child(node)
		mesh_box(Vector3(1.6, 3.0, 1.6), Vector3(0, 1.5, 0), hue_col(i * 0.2, 0.5, 0.9), node)
		node.position = Vector3(8, 0, (i - 1) * 5.0)
		heroes.append({"node": node, "name": hnames[i], "hp": 90 + i * 20, "maxhp": 90 + i * 20,
			"mp": 40, "atb": randf() * 0.4, "alive": true, "guard": false})
	make_camera(Vector3(0, 12, 16), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(0, 8, 0), 30, Color.WHITE)
	tc = add_touch_controls([
		{"id": "attack", "label": "ATTACK", "col": Color(0.9, 0.6, 0.4)},
		{"id": "skill", "label": "SKILL", "col": Color(0.6, 0.5, 0.95)},
		{"id": "target", "label": "TARGET", "col": Color(0.7, 0.7, 0.75)},
		{"id": "guard", "label": "GUARD", "col": Color(0.5, 0.8, 0.7)},
	], false, false)
	tc.action.connect(func(id):
		if id == "attack": _act("attack")
		elif id == "skill": _act("skill")
		elif id == "target": _cycle_target()
		elif id == "guard": _act("guard"))
	_spawn_wave()


func _spawn_wave() -> void:
	foes = []
	var n := 2 + wave
	for i in n:
		var node := Node3D.new()
		add_child(node)
		mesh_box(Vector3(1.8, 2.6, 1.8), Vector3(0, 1.3, 0), Color(0.8, 0.35, 0.4), node)
		node.position = Vector3(-8, 0, (i - (n - 1) * 0.5) * 3.4)
		var hpv := 40 + wave * 12
		foes.append({"node": node, "hp": hpv, "maxhp": hpv, "atb": randf() * 0.3, "alive": true})
	target = 0


func _cycle_target() -> void:
	for k in foes.size():
		target = (target + 1) % foes.size()
		if foes[target].alive:
			return


func _live_target() -> int:
	if target < foes.size() and foes[target].alive:
		return target
	for i in foes.size():
		if foes[i].alive:
			target = i
			return i
	return -1


func _act(kind: String) -> void:
	if ready < 0:
		return
	var h = heroes[ready]
	if kind == "attack":
		var ti := _live_target()
		if ti >= 0:
			_hit_foe(ti, 18 + ready * 4)
	elif kind == "skill":
		if h.mp < 20:
			return
		h.mp -= 20
		if ready == 1:                       # MAGE heals the party
			for g in heroes:
				if g.alive:
					g.hp = mini(g.maxhp, g.hp + 45)
			Juice.sfx("chime")
			Juice.popup("HEAL", Vector2(W * 0.5, H * 0.36), Color(0.5, 1, 0.6))
		elif ready == 0:                     # KNIGHT hits all foes
			for i in foes.size():
				if foes[i].alive:
					_hit_foe(i, 16)
		else:                                # ROGUE heavy single
			var ti := _live_target()
			if ti >= 0:
				_hit_foe(ti, 46)
	elif kind == "guard":
		h.guard = true
		h.mp = mini(60, h.mp + 12)
	h.atb = 0.0
	ready = -1


func _hit_foe(i: int, dmg: int) -> void:
	foes[i].hp -= dmg
	Juice.sfx("thud")
	Juice.popup(str(dmg), Vector2(W * 0.5, H * 0.4), Color(1, 0.9, 0.5), 34)
	if foes[i].hp <= 0:
		foes[i].alive = false
		foes[i].node.visible = false
		add_points(1)
		Juice.sfx("boom")


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J: _act("attack")
		elif event.keycode == KEY_K: _act("skill")
		elif event.keycode == KEY_L: _cycle_target()
		elif event.keycode == KEY_SPACE: _act("guard")


func _process(delta: float) -> void:
	if not running:
		return
	# wave cleared?
	if foes.filter(func(f): return f.alive).is_empty():
		wave += 1
		add_points(3)
		Juice.sfx("chime")
		_spawn_wave()

	if ready < 0:
		# fill ATB bars (paused while a hero waits for orders)
		for i in heroes.size():
			var h = heroes[i]
			if h.alive:
				h.atb = minf(1.0, h.atb + delta * 0.32)
				if h.atb >= 1.0:
					ready = i
					h.guard = false
					break
		for f in foes:
			if f.alive:
				f.atb = minf(1.0, f.atb + delta * 0.22)
				if f.atb >= 1.0:
					f.atb = 0.0
					_foe_attack()

	# bob the ready hero
	for i in heroes.size():
		var h = heroes[i]
		h.node.position.y = 0.4 if i == ready else 0.0
	cam.look_at(Vector3.ZERO, Vector3.UP)
	var party := ""
	for i in heroes.size():
		var h = heroes[i]
		party += "%s HP%d MP%d %s%s\n" % [h.name, maxi(0, h.hp), h.mp,
			("ATB%d%%" % int(h.atb * 100)), "  <READY>" if i == ready else ""]
	hud.text = "WAVE %d   foes %d   target #%d\n%s" % [
		wave, foes.filter(func(f): return f.alive).size(), target, party]


func _foe_attack() -> void:
	var alive := []
	for i in heroes.size():
		if heroes[i].alive:
			alive.append(i)
	if alive.is_empty():
		return
	var hi = alive[randi() % alive.size()]
	var h = heroes[hi]
	var dmg := (10 + wave * 3)
	if h.guard:
		dmg = dmg / 3
	h.hp -= dmg
	Juice.flash(Color(1, 0.3, 0.3), 0.15)
	Juice.haptic(15)
	if h.hp <= 0:
		h.alive = false
		h.node.visible = false
		if alive.size() <= 1:
			end_demo()
