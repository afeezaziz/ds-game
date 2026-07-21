class_name OpenNPC
extends CharacterBody3D
## Crowd AI: civilians wander and flee trouble; cops chase you when you're
## wanted. Gray-box capsules. States are simple and readable on purpose —
## this file is where richer AI experiments (schedules, dialogue, groups) go.

signal downed(npc)

enum M { WANDER, FLEE, CHASE, DOWN }

const GRAVITY := 22.0

var is_cop := false
var state: M = M.WANDER
var walk_speed := 2.2
var run_speed := 5.2
var chase_speed := 6.4

var _target_pos := Vector3.ZERO
var _repick := 0.0
var _flee_t := 0.0
var _down_t := 0.0
var _player: Node3D
var _mesh: MeshInstance3D
var _bounds := 45.0


func setup(cop: bool, player: Node3D, bounds: float) -> void:
	is_cop = cop
	_player = player
	_bounds = bounds

	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.5
	shape.shape = cap
	shape.position = Vector3(0, 0.75, 0)
	add_child(shape)

	_mesh = MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.32
	cm.height = 1.5
	var mat := StandardMaterial3D.new()
	if is_cop:
		mat.albedo_color = Color(0.2, 0.35, 0.95)
	else:
		mat.albedo_color = Color.from_hsv(randf(), 0.4, 0.85)
	cm.material = mat
	_mesh.mesh = cm
	_mesh.position = Vector3(0, 0.75, 0)
	add_child(_mesh)

	if is_cop:
		var light := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = Vector3(0.24, 0.12, 0.24)
		var lmat := StandardMaterial3D.new()
		lmat.albedo_color = Color(1, 0.2, 0.2)
		lmat.emission_enabled = true
		lmat.emission = Color(1, 0.1, 0.1)
		lmat.emission_energy_multiplier = 1.6
		lb.material = lmat
		light.mesh = lb
		light.position = Vector3(0, 1.65, 0)
		add_child(light)

	_pick_wander()


func hit() -> void:
	if state == M.DOWN:
		return
	state = M.DOWN
	_down_t = 0.0
	_mesh.rotation.x = -PI / 2.0
	_mesh.position.y = 0.35
	downed.emit(self)


func alert_flee() -> void:
	if is_cop or state == M.DOWN:
		return
	state = M.FLEE
	_flee_t = 4.0


func set_chasing(on: bool) -> void:
	if not is_cop or state == M.DOWN:
		return
	state = M.CHASE if on else M.WANDER
	if not on:
		_pick_wander()


func _physics_process(delta: float) -> void:
	velocity.y -= GRAVITY * delta

	match state:
		M.DOWN:
			_down_t += delta
			velocity.x = 0
			velocity.z = 0
			move_and_slide()
			if _down_t > 2.5:
				queue_free()
			return
		M.WANDER:
			_repick -= delta
			if _repick <= 0.0 or position.distance_to(_target_pos) < 1.0:
				_pick_wander()
			_go_to(_target_pos, walk_speed, delta)
		M.FLEE:
			_flee_t -= delta
			if _flee_t <= 0.0:
				state = M.WANDER
				_pick_wander()
			else:
				var away := position - _player.position
				away.y = 0
				_go_to(position + away.normalized() * 5.0, run_speed, delta)
		M.CHASE:
			_go_to(_player.position, chase_speed, delta)

	move_and_slide()


func _go_to(pos: Vector3, speed: float, delta: float) -> void:
	var dir := pos - position
	dir.y = 0
	if dir.length() < 0.2:
		velocity.x = 0
		velocity.z = 0
		return
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	var target_yaw := atan2(dir.x, dir.z)
	_mesh.rotation.y = lerp_angle(_mesh.rotation.y, target_yaw, 8.0 * delta)


func _pick_wander() -> void:
	_repick = randf_range(4.0, 9.0)
	_target_pos = Vector3(
		randf_range(-_bounds, _bounds), 0, randf_range(-_bounds, _bounds))
