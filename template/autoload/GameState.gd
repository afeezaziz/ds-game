extends Node
## Local persistence + session state. Template file: copy unchanged to every game.

const SAVE_PATH := "user://local_save.cfg"

var game_id := "CHANGE_ME"  # set per game before shipping       # <-- change per game
var best_score := 0
var total_deaths := 0
var muted := false
var device_id := ""

func _ready() -> void:
	_load()
	if device_id == "":
		device_id = OS.get_unique_id()
		if device_id == "":
			device_id = _random_id()
		_save()

func report_score(score: int) -> bool:
	var improved := score > best_score
	if improved:
		best_score = score
		_save()
	return improved

func register_death() -> void:
	total_deaths += 1
	_save()

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	best_score = cfg.get_value("save", "best_score", 0)
	total_deaths = cfg.get_value("save", "total_deaths", 0)
	muted = cfg.get_value("save", "muted", false)
	device_id = cfg.get_value("save", "device_id", "")

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("save", "best_score", best_score)
	cfg.set_value("save", "total_deaths", total_deaths)
	cfg.set_value("save", "muted", muted)
	cfg.set_value("save", "device_id", device_id)
	cfg.save(SAVE_PATH)

func _random_id() -> String:
	randomize()
	var chars := "abcdef0123456789"
	var out := ""
	for i in 32:
		out += chars[randi() % chars.length()]
	return out
