extends Node
## Local persistence + session state. Template file: copy unchanged to every game.
## Supports per-board (per-mode) best scores; best_score is the best across all.

const SAVE_PATH := "user://local_save.cfg"

var game_id := "CHANGE_ME"      # <-- change per game
var best_score := 0             # best across all boards/modes
var bests: Dictionary = {}      # board/mode -> best score
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

func best_for(board: String) -> int:
	return int(bests.get(board, 0))

func report_score(score: int, board: String = "main") -> bool:
	var improved := score > best_for(board)
	if improved:
		bests[board] = score
		if score > best_score:
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
	bests = cfg.get_value("save", "bests", {})
	total_deaths = cfg.get_value("save", "total_deaths", 0)
	muted = cfg.get_value("save", "muted", false)
	device_id = cfg.get_value("save", "device_id", "")

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("save", "best_score", best_score)
	cfg.set_value("save", "bests", bests)
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
