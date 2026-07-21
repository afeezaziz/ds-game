extends MechDemo
## BILLIARDS — drag the cue ball back and release to break. Elastic physics,
## six pockets. Pot colour balls to score; re-rack when the table clears.
## (8-Ball Pool.) Endless. Sink the cue = it just respawns.

const TX := 40.0
const TY := 330.0
const TW := 640.0
const TH := 780.0
const R := 24.0
const PR := 42.0

var balls: Array = []
var aiming := false
var aim := Vector2.ZERO


func start() -> void:
	super.start()
	_rack()
	queue_redraw()


func _pockets() -> Array:
	return [Vector2(TX, TY), Vector2(TX + TW, TY), Vector2(TX, TY + TH),
		Vector2(TX + TW, TY + TH), Vector2(TX, TY + TH * 0.5), Vector2(TX + TW, TY + TH * 0.5)]


func _rack() -> void:
	balls = []
	balls.append({"pos": Vector2(TX + TW * 0.5, TY + TH * 0.78), "vel": Vector2.ZERO,
		"col": Color.WHITE, "potted": false, "cue": true})
	var start_p := Vector2(TX + TW * 0.5, TY + TH * 0.28)
	var i := 0
	for row in 4:
		for k in row + 1:
			var p := start_p + Vector2((k - row * 0.5) * (R * 2.1), row * R * 1.9)
			balls.append({"pos": p, "vel": Vector2.ZERO,
				"col": Color.from_hsv(fmod(i * 0.13, 1.0), 0.7, 0.9), "potted": false, "cue": false})
			i += 1


func _cue():
	for b in balls:
		if b.cue and not b.potted:
			return b
	return null


func _settled() -> bool:
	for b in balls:
		if not b.potted and b.vel.length() > 6.0:
			return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not running or not _settled():
		return
	var cue = _cue()
	if cue == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed and event.position.distance_to(cue.pos) < 120.0:
			aiming = true
		elif not event.pressed and aiming:
			aiming = false
			cue.vel = aim * 7.0
			Juice.sfx("thud")
	elif event is InputEventScreenDrag and aiming:
		aim = (cue.pos - event.position).limit_length(180.0)
	queue_redraw()


func _process(delta: float) -> void:
	if not running:
		return
	var steps := 4
	var dt := delta / steps
	for s in steps:
		_step(dt)
	queue_redraw()


func _step(dt: float) -> void:
	for b in balls:
		if b.potted:
			continue
		b.pos += b.vel * dt
		b.vel *= 0.988
		if b.vel.length() < 3.0:
			b.vel = Vector2.ZERO
		if b.pos.x < TX + R:
			b.pos.x = TX + R
			b.vel.x = absf(b.vel.x)
		elif b.pos.x > TX + TW - R:
			b.pos.x = TX + TW - R
			b.vel.x = -absf(b.vel.x)
		if b.pos.y < TY + R:
			b.pos.y = TY + R
			b.vel.y = absf(b.vel.y)
		elif b.pos.y > TY + TH - R:
			b.pos.y = TY + TH - R
			b.vel.y = -absf(b.vel.y)
	for i in balls.size():
		if balls[i].potted:
			continue
		for j in range(i + 1, balls.size()):
			if balls[j].potted:
				continue
			var d: Vector2 = balls[j].pos - balls[i].pos
			var dist := d.length()
			if dist < 2 * R and dist > 0.01:
				var nrm := d / dist
				var overlap := 2 * R - dist
				balls[i].pos -= nrm * overlap * 0.5
				balls[j].pos += nrm * overlap * 0.5
				var vin: float = balls[i].vel.dot(nrm)
				var vjn: float = balls[j].vel.dot(nrm)
				balls[i].vel += nrm * (vjn - vin)
				balls[j].vel += nrm * (vin - vjn)
	for b in balls:
		if b.potted:
			continue
		for pk in _pockets():
			if b.pos.distance_to(pk) < PR:
				b.potted = true
				if b.cue:
					b.pos = Vector2(TX + TW * 0.5, TY + TH * 0.78)
					b.vel = Vector2.ZERO
					b.potted = false
				else:
					add_points(10)
					Juice.sfx("coin")
	var any := false
	for b in balls:
		if not b.cue and not b.potted:
			any = true
	if not any:
		add_points(25)
		_rack()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.08, 0.1, 0.09))
	draw_rect(Rect2(TX - 14, TY - 14, TW + 28, TH + 28), Color(0.35, 0.22, 0.12))
	draw_rect(Rect2(TX, TY, TW, TH), Color(0.15, 0.45, 0.25))
	for pk in _pockets():
		draw_circle(pk, PR * 0.7, Color(0, 0, 0))
	for b in balls:
		if not b.potted:
			draw_circle(b.pos, R, b.col)
	var cue = _cue()
	if aiming and cue:
		draw_line(cue.pos, cue.pos + aim, Color(1, 1, 1, 0.6), 3.0)
	draw_string(f(), Vector2(20, 300), "drag cue ball back, release to shoot",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.55))
