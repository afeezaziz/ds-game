extends MechDemo3D
## LOOT ARPG — the kill → loot → upgrade treadmill (Diablo). Hold ATTACK to auto-swing
## at the nearest pack; SKILL fires a nova. Fallen enemies drop gear whose colour is its
## rarity — walk over an upgrade and it auto-equips, raising your damage or armour so you
## can grind deeper, tougher packs. Desktop: WASD move, SPACE attack, K skill.

var hero: Node3D
var ppos := Vector3.ZERO
var facing := Vector3(0, 0, -1)
var hp := 100.0
var maxhp := 100.0
var wpn := 6.0                # weapon power (damage)
var arm := 0.0               # armor power (max hp)
var atk_cd := 0.0
var skill_cd := 0.0
var enemies: Array = []       # {node,pos,hp,lvl}
var loot: Array = []          # {node,pos,slot,power}
var mlvl := 1
var spawn_t := 0.0
var t := 0.0
var tc: TouchControls
var hud: Label3D


func start() -> void:
	super.start()
	setup_world(Color(0.1, 0.09, 0.13), 0.85, Vector3(-60, -25, 0))
	static_box(Vector3(70, 1, 70), Vector3(0, -0.5, 0), Color(0.22, 0.2, 0.25))
	hero = Node3D.new()
	add_child(hero)
	mesh_box(Vector3(1.1, 1.9, 1.1), Vector3(0, 0.95, 0), Color(0.5, 0.85, 1.0), hero)
	mesh_box(Vector3(0.25, 0.25, 1.4), Vector3(0.5, 1.0, 0.6), Color(0.95, 0.9, 0.6), hero)
	ppos = Vector3.ZERO
	hp = 100.0
	maxhp = 100.0
	wpn = 6.0
	arm = 0.0
	mlvl = 1
	enemies = []
	loot = []
	spawn_t = 0.4
	t = 0.0
	make_camera(Vector3(0, 18, 14), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(0, 10, 0), 30, Color.WHITE)
	tc = add_touch_controls([
		{"id": "attack", "label": "ATTACK", "col": Color(0.9, 0.6, 0.4)},
		{"id": "skill", "label": "SKILL", "col": Color(0.6, 0.5, 0.95)},
	])
	tc.action.connect(func(id):
		if id == "skill": _skill())


func _rarity(power: float) -> Color:
	if power < 8: return Color(0.8, 0.8, 0.8)      # common
	elif power < 14: return Color(0.4, 0.7, 1.0)   # rare (blue)
	elif power < 22: return Color(0.7, 0.4, 1.0)   # epic (purple)
	return Color(1.0, 0.6, 0.2)                     # legendary (orange)


func _attack() -> void:
	if atk_cd > 0.0:
		return
	atk_cd = 0.35
	var hit := false
	for e in enemies.duplicate():
		var to: Vector3 = e.pos - ppos
		if to.length() < 3.6 and facing.dot(to.normalized()) > 0.2:
			e.hp -= wpn
			hit = true
			if e.hp <= 0.0:
				_kill(e)
	if hit:
		Juice.sfx("thud"); Juice.hitstop(30)


func _skill() -> void:
	if skill_cd > 0.0:
		return
	skill_cd = 2.2
	Juice.sfx("boom"); Juice.flash(Color(0.6, 0.5, 1.0), 0.2)
	for e in enemies.duplicate():
		if e.pos.distance_to(ppos) < 8.0:
			e.hp -= wpn * 1.6
			if e.hp <= 0.0:
				_kill(e)


func _kill(e) -> void:
	e.node.queue_free()
	enemies.erase(e)
	add_points(1)
	# drop loot ~half the time, power scaling with monster level
	if randf() < 0.55:
		var slot := 0 if randf() < 0.5 else 1
		var power := e.lvl * randf_range(1.5, 4.5)
		var node := mesh_box(Vector3(0.7, 0.7, 0.7), e.pos + Vector3(0, 0.4, 0), _rarity(power))
		loot.append({"node": node, "pos": e.pos, "slot": slot, "power": power})


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		_skill()


func _process(delta: float) -> void:
	if not running:
		return
	t += delta
	atk_cd = maxf(0.0, atk_cd - delta)
	skill_cd = maxf(0.0, skill_cd - delta)
	mlvl = 1 + int(t / 15.0)
	var mv := Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())
	if mv.length() > 1.0:
		mv = mv.normalized()
	ppos += mv * 8.0 * delta
	ppos.x = clampf(ppos.x, -33, 33)
	ppos.z = clampf(ppos.z, -33, 33)
	if mv.length() > 0.1:
		facing = mv.normalized()
		hero.rotation.y = atan2(mv.x, mv.z)
	hero.position = ppos

	# hold ATTACK (button or SPACE) to auto-swing
	if tc.held("attack") or Input.is_key_pressed(KEY_SPACE):
		_attack()

	spawn_t -= delta
	if spawn_t <= 0.0 and enemies.size() < 14:
		spawn_t = maxf(0.4, 1.6 - t * 0.01)
		var a := randf() * TAU
		var p := ppos + Vector3(cos(a), 0, sin(a)) * 26.0
		var node := mesh_box(Vector3(1.1, 1.6, 1.1), p + Vector3(0, 0.8, 0), Color(0.85, 0.35, 0.35).lerp(Color(0.5, 0.2, 0.6), clampf(mlvl * 0.1, 0, 1)))
		enemies.append({"node": node, "pos": p, "hp": 8.0 + mlvl * 5.0, "lvl": mlvl})

	for e in enemies:
		var to: Vector3 = ppos - e.pos
		e.pos += to.normalized() * (3.0 + mlvl * 0.1) * delta
		e.node.position = e.pos + Vector3(0, 0.8, 0)
		if to.length() < 1.4:
			hp -= (2.0 + mlvl * 0.6) * delta * 3.0
			if hp <= 0.0:
				end_demo()
				return

	for l in loot.duplicate():
		if ppos.distance_to(l.pos) < 1.8:
			var cur: float = wpn if l.slot == 0 else arm
			if l.power > cur:
				if l.slot == 0:
					wpn = l.power
				else:
					arm = l.power
					maxhp = 100.0 + arm * 3.0
				Juice.sfx("coin"); Juice.flash(Color(1, 0.9, 0.5), 0.2)
				Juice.popup("%s +%.0f" % ["WEAPON" if l.slot == 0 else "ARMOR", l.power], Vector2(W * 0.5, H * 0.36), _rarity(l.power))
			l.node.queue_free()
			loot.erase(l)
	hp = minf(maxhp, hp + 3.0 * delta)

	cam.position = ppos + Vector3(0, 18, 14)
	cam.look_at(ppos, Vector3.UP)
	hud.text = "HP %d/%d   DMG %.0f   ARM %.0f   mLvl %d   kills %d" % [
		int(max(0, hp)), int(maxhp), wpn, arm, mlvl, score]
	hud.position = ppos + Vector3(0, 10, 0)
