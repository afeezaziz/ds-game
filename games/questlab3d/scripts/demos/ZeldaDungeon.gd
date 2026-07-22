extends MechDemo3D
## DUNGEON QUEST — items unlock the path (Zelda). Sword the guardians, open chests
## for the KEY, BOMB and BOW, then USE each where it fits: key opens the locked door,
## a bomb blows the cracked wall, the bow hits the far switch to raise the boss gate.
## Beat the boss for a deeper dungeon. Desktop: WASD move, J sword, K use item.

var hero: Node3D
var hpos := Vector3(0, 0, 14)
var facing := Vector3(0, 0, -1)
var hp := 6
var maxhp := 6
var atk := 0.0
var inv := {"key": false, "bomb": false, "bow": false}
var chests: Array = []        # {node,item,pos,open}
var gates: Array = []         # {node,pos,kind,open}  kind: locked/cracked/boss
var switch_node: Node3D
var switch_hit := false
var enemies: Array = []
var boss = null
var depth := 1
var hurt_cd := 0.0
var tc: TouchControls
var hud: Label3D


func start() -> void:
	super.start()
	setup_world(Color(0.08, 0.09, 0.13), 0.8, Vector3(-60, -20, 0))
	static_box(Vector3(28, 1, 90), Vector3(0, -0.5, -30), Color(0.24, 0.24, 0.3))
	hero = Node3D.new()
	add_child(hero)
	mesh_box(Vector3(1.2, 2.0, 1.2), Vector3(0, 1.0, 0), Color(0.35, 0.8, 0.4), hero)
	mesh_box(Vector3(0.25, 0.25, 1.6), Vector3(0.5, 1.1, 0.8), Color(0.9, 0.9, 1.0), hero)
	make_camera(Vector3(0, 18, 14), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(0, 10, 0), 30, Color.WHITE)
	tc = add_touch_controls([
		{"id": "sword", "label": "SWORD", "col": Color(0.9, 0.6, 0.4)},
		{"id": "use", "label": "USE", "col": Color(0.6, 0.7, 0.95)},
	])
	tc.action.connect(func(id):
		if id == "sword": _sword()
		elif id == "use": _use())
	_build_dungeon()


func _build_dungeon() -> void:
	for c in chests: c.node.queue_free()
	for g in gates: g.node.queue_free()
	for e in enemies: e.node.queue_free()
	if boss != null: boss.node.queue_free()
	chests = []; gates = []; enemies = []; boss = null
	switch_hit = false
	inv = {"key": false, "bomb": false, "bow": false}
	hp = maxhp
	hpos = Vector3(0, 0, 14)
	_chest(Vector3(-8, 0, 4), "key")
	_chest(Vector3(8, 0, -26), "bomb")
	_chest(Vector3(-8, 0, -46), "bow")
	_gate(Vector3(0, 0, -20), "locked", Color(0.7, 0.6, 0.2))
	_gate(Vector3(0, 0, -40), "cracked", Color(0.5, 0.45, 0.4))
	_gate(Vector3(0, 0, -60), "boss", Color(0.6, 0.2, 0.6))
	switch_node = Node3D.new()
	add_child(switch_node)
	mesh_box(Vector3(1.4, 2.4, 1.4), Vector3(0, 1.2, 0), Color(0.9, 0.85, 0.2), switch_node)
	switch_node.position = Vector3(10, 0, -52)
	for z in [-8, -30, -50]:
		for i in 2:
			_enemy(Vector3(randf_range(-9, 9), 0, z + randf_range(-4, 4)))
	# boss behind the boss gate
	var bn := Node3D.new()
	add_child(bn)
	mesh_box(Vector3(4, 5, 4), Vector3(0, 2.5, 0), Color(0.7, 0.25, 0.5), bn)
	bn.position = Vector3(0, 0, -70)
	boss = {"node": bn, "pos": bn.position, "hp": 30 + depth * 10, "cd": 1.5}


func _chest(p: Vector3, item: String) -> void:
	var node := mesh_box(Vector3(1.4, 1.2, 1.4), p + Vector3(0, 0.6, 0), Color(0.75, 0.55, 0.25))
	chests.append({"node": node, "item": item, "pos": p, "open": false})


func _gate(p: Vector3, kind: String, col: Color) -> void:
	var node := mesh_box(Vector3(28, 4, 1.2), p + Vector3(0, 2, 0), col)
	gates.append({"node": node, "pos": p, "kind": kind, "open": false})


func _enemy(p: Vector3) -> void:
	var node := mesh_box(Vector3(1.2, 1.8, 1.2), p + Vector3(0, 0.9, 0), Color(0.8, 0.4, 0.4))
	enemies.append({"node": node, "pos": p, "hp": 3, "cd": 0.0})


func _sword() -> void:
	atk = 0.2
	Juice.sfx("tick")
	for e in enemies.duplicate():
		var to: Vector3 = e.pos - hpos
		if to.length() < 3.2 and facing.dot(to.normalized()) > 0.2:
			e.hp -= 2
			if e.hp <= 0:
				e.node.queue_free()
				enemies.erase(e)
				Juice.sfx("boom")
	if boss != null and _gate_open("boss"):
		var to: Vector3 = boss.pos - hpos
		if to.length() < 4.5 and facing.dot(to.normalized()) > 0.2:
			boss.hp -= 2
			Juice.sfx("thud")
			if boss.hp <= 0:
				_win()


func _gate_open(kind: String) -> bool:
	for g in gates:
		if g.kind == kind:
			return g.open
	return false


func _open_gate(kind: String) -> void:
	for g in gates:
		if g.kind == kind and not g.open:
			g.open = true
			g.node.visible = false
			Juice.sfx("chime")
			Juice.flash(Color(0.9, 0.9, 0.6), 0.2)


func _use() -> void:
	# context-sensitive item use
	for g in gates:
		if g.open:
			continue
		var near := hpos.distance_to(g.pos) < 5.0
		if g.kind == "cracked" and near and inv.bomb:
			inv.bomb = false
			_open_gate("cracked")
			Juice.sfx("boom")
			return
	if inv.bow and not switch_hit and hpos.distance_to(switch_node.position) < 18.0 and facing.dot((switch_node.position - hpos).normalized()) > 0.4:
		switch_hit = true
		switch_node.get_child(0).rotation.z = 1.2
		_open_gate("boss")
		Juice.popup("SWITCH!", Vector2(W * 0.5, H * 0.36), Color(1, 0.9, 0.4))
		return
	Juice.sfx("thud")


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J: _sword()
		elif event.keycode == KEY_K: _use()


func _process(delta: float) -> void:
	if not running:
		return
	atk = maxf(0.0, atk - delta)
	hurt_cd = maxf(0.0, hurt_cd - delta)
	var mv := Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())
	if mv.length() > 1.0:
		mv = mv.normalized()
	var np := hpos + mv * 8.0 * delta
	# block on closed gates
	for g in gates:
		if not g.open and absf(np.z - g.pos.z) < 1.2 and absf(np.x) < 13.0:
			np.z = hpos.z
	hpos = np
	hpos.x = clampf(hpos.x, -12, 12)
	hpos.z = clampf(hpos.z, -74, 15)
	if mv.length() > 0.1:
		facing = mv.normalized()
		hero.rotation.y = atan2(mv.x, mv.z)
	hero.position = hpos

	# chest pickups
	for c in chests:
		if not c.open and hpos.distance_to(c.pos) < 2.2:
			c.open = true
			c.node.rotation.x = -0.6
			inv[c.item] = true
			Juice.sfx("coin")
			Juice.popup("GOT %s" % c.item.to_upper(), Vector2(W * 0.5, H * 0.36), Color(1, 0.9, 0.4))
			if c.item == "key":
				_open_gate("locked")

	# enemies chase + hurt
	for e in enemies:
		var to: Vector3 = hpos - e.pos
		e.pos += to.normalized() * 3.0 * delta
		e.node.position = e.pos + Vector3(0, 0.9, 0)
		if hurt_cd <= 0.0 and to.length() < 1.6:
			hurt_cd = 1.0
			hp -= 1
			Juice.flash(Color(1, 0.3, 0.3), 0.2)
			Juice.haptic(25)
			if hp <= 0:
				end_demo()
				return
	# boss
	if boss != null and _gate_open("boss"):
		boss.cd -= delta
		var to: Vector3 = hpos - boss.pos
		boss.pos += to.normalized() * 2.2 * delta
		boss.node.position = boss.pos + Vector3(0, 2.5, 0)
		if hurt_cd <= 0.0 and to.length() < 3.4:
			hurt_cd = 1.0
			hp -= 2
			Juice.flash(Color(1, 0.25, 0.25), 0.25)
			Juice.haptic(30)
			if hp <= 0:
				end_demo()
				return

	cam.position = hpos + Vector3(0, 18, 14)
	cam.look_at(hpos + Vector3(0, 0, -4), Vector3.UP)
	var items := ""
	for k in inv.keys():
		if inv[k]:
			items += k + " "
	hud.text = "DEPTH %d   HP %d/%d   items: %s" % [depth, hp, maxhp, items if items != "" else "-"]
	hud.position = hpos + Vector3(0, 10, 0)


func _win() -> void:
	depth += 1
	maxhp += 1
	add_points(5)
	Juice.sfx("chime")
	Juice.flash(Color(1, 0.95, 0.6), 0.4)
	Juice.popup("DUNGEON CLEARED!", Vector2(W * 0.5, H * 0.34), Color(1, 0.9, 0.4))
	_build_dungeon()
