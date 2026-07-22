extends Node
## Event queue with periodic flush. Template file: copy unchanged to every game.

const FLUSH_INTERVAL := 20.0
const FLUSH_AT := 15  # flush early if queue grows

var _queue: Array = []
var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = FLUSH_INTERVAL
	_timer.autostart = true
	_timer.timeout.connect(flush)
	add_child(_timer)
	track("session_start", {"version": ProjectSettings.get_setting("application/config/version", "0")})

func track(event_name: String, props: Dictionary = {}) -> void:
	_queue.append({
		"name": event_name,
		"props": props,
		"ts": Time.get_unix_time_from_system(),
	})
	if _queue.size() >= FLUSH_AT:
		flush()

func flush() -> void:
	if _queue.is_empty():
		return
	var batch := _queue.duplicate()
	_queue.clear()
	Backend.send_events(batch)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush()
