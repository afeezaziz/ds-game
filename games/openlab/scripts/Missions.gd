class_name MissionManager
extends Node3D
## Procedural mission loop: DELIVER (pick up at A, drop at B) and RACE
## (5 checkpoints in sequence). Works on foot, by car, or on horseback.
## Rewards flow back to Main via signals. Marker = glowing yellow pillar.

signal mission_text(text: String)
signal mission_reward(points: int, done: bool)

enum T { NONE, DELIVER_PICK, DELIVER_DROP, RACE }

var deliver_reward := 100
var checkpoint_bonus := 20
var race_complete_bonus := 60

var _type: T = T.NONE
var _marker: MeshInstance3D
var _race_left := 0
var _bounds := 42.0
var _cooldown := 0.0


func _ready() -> void:
	_marker = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.1
	cyl.bottom_radius = 1.1
	cyl.height = 7.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.85, 0.2, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1, 0.8, 0.1)
	mat.emission_energy_multiplier = 0.9
	cyl.material = mat
	_marker.mesh = cyl
	_marker.visible = false
	add_child(_marker)


func begin() -> void:
	deliver_reward = int(Backend.cfg("mission_reward_deliver", deliver_reward))
	checkpoint_bonus = int(Backend.cfg("checkpoint_bonus", checkpoint_bonus))
	race_complete_bonus = int(Backend.cfg("race_complete_bonus", race_complete_bonus))
	_new_mission()


func stop() -> void:
	_type = T.NONE
	_marker.visible = false


func marker_pos() -> Vector3:
	return _marker.position


func active() -> bool:
	return _type != T.NONE and _marker.visible


func tick(player_pos: Vector3, delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
		if _cooldown <= 0.0:
			_new_mission()
		return
	if _type == T.NONE:
		return
	var flat_dist := Vector2(player_pos.x - _marker.position.x,
		player_pos.z - _marker.position.z).length()
	if flat_dist > 2.4:
		return

	match _type:
		T.DELIVER_PICK:
			_type = T.DELIVER_DROP
			_place_marker()
			mission_text.emit("PACKAGE PICKED UP — deliver it to the marker")
			Analytics.track("mission_step", {"type": "deliver_pick"})
		T.DELIVER_DROP:
			mission_reward.emit(deliver_reward, true)
			Analytics.track("mission_done", {"type": "deliver"})
			_between_missions("DELIVERED! +%d" % deliver_reward)
		T.RACE:
			_race_left -= 1
			if _race_left > 0:
				mission_reward.emit(checkpoint_bonus, false)
				_place_marker()
				mission_text.emit("CHECKPOINT! %d to go" % _race_left)
			else:
				mission_reward.emit(checkpoint_bonus + race_complete_bonus, true)
				Analytics.track("mission_done", {"type": "race"})
				_between_missions("RACE COMPLETE! +%d" % race_complete_bonus)


func _between_missions(text: String) -> void:
	_type = T.NONE
	_marker.visible = false
	mission_text.emit(text)
	_cooldown = 2.5


func _new_mission() -> void:
	if randf() < 0.5:
		_type = T.DELIVER_PICK
		_place_marker()
		mission_text.emit("NEW JOB: pick up the package at the marker")
		Analytics.track("mission_start", {"type": "deliver"})
	else:
		_type = T.RACE
		_race_left = 5
		_place_marker()
		mission_text.emit("RACE: hit 5 checkpoints — any vehicle you like")
		Analytics.track("mission_start", {"type": "race"})


func _place_marker() -> void:
	# Road positions sit on the gaps of the 14m building grid.
	var lane := (randi() % 7 - 3) * 14.0 + 7.0
	var along := randf_range(-_bounds, _bounds)
	var pos := Vector3(lane, 3.5, along) if randf() < 0.5 else Vector3(along, 3.5, lane)
	pos.x = clampf(pos.x, -_bounds, _bounds)
	pos.z = clampf(pos.z, -_bounds, _bounds)
	_marker.position = pos
	_marker.visible = true
