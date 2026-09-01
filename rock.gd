extends MeshInstance3D

@export var water_y: float = 0.94
@export var start_position: Vector3 = Vector3(0, 1.5, 4)
@export var speed_scale: float = 0.05
@export var max_speed: float = 40.0
@export var min_speed: float = 3.0
@export var bounce_decay: float = 0.72
@export var gravity: float = 30.0
@export var base_hop_height: float = 1.6
@export var min_flick_speed_px: float = 50.0

enum State { IDLE, FLYING, SINKING }

var state: State = State.IDLE
var horizontal_speed: float = 0.0
var direction: Vector3 = Vector3.ZERO
var vertical_velocity: float = 0.0

var _drag_active: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_start_time: int = 0

func _ready() -> void:
	position = start_position

func _unhandled_input(event: InputEvent) -> void:
	if state != State.IDLE:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_active = true
			_drag_start_pos = event.position
			_drag_start_time = Time.get_ticks_msec()
		elif _drag_active:
			_drag_active = false
			_try_throw(event.position)

func _try_throw(end_pos: Vector2) -> void:
	var flick: Vector2 = end_pos - _drag_start_pos
	var elapsed_ms: int = maxi(Time.get_ticks_msec() - _drag_start_time, 16)
	var flick_speed_px: float = flick.length() / (elapsed_ms / 1000.0)
	if flick.y >= 0.0 or flick_speed_px < min_flick_speed_px:
		return

	var forward := Vector3(0, 0, 1)
	var right := Vector3(1, 0, 0)
	var cam := get_viewport().get_camera_3d()
	if cam:
		forward = -cam.global_transform.basis.z
		forward.y = 0
		forward = forward.normalized()
		right = cam.global_transform.basis.x
		right.y = 0
		right = right.normalized()

	direction = (forward * -flick.y + right * flick.x).normalized()
	horizontal_speed = clampf(flick_speed_px * speed_scale, min_speed, max_speed)
	position = start_position
	state = State.FLYING
	_start_hop()

func _start_hop() -> void:
	var height: float = base_hop_height * (horizontal_speed / max_speed)
	vertical_velocity = sqrt(2.0 * gravity * maxf(height, 0.05))

func _process(delta: float) -> void:
	if state != State.FLYING:
		return

	position += direction * horizontal_speed * delta
	vertical_velocity -= gravity * delta
	position.y += vertical_velocity * delta

	if position.y <= water_y and vertical_velocity < 0.0:
		position.y = water_y
		horizontal_speed *= bounce_decay
		if horizontal_speed < min_speed:
			_sink()
		else:
			_start_hop()

func _sink() -> void:
	state = State.SINKING
	var tw := create_tween()
	tw.tween_property(self, "position:y", water_y - 1.0, 0.6)
	tw.tween_callback(_reset)

func _reset() -> void:
	horizontal_speed = 0.0
	vertical_velocity = 0.0
	position = start_position
	state = State.IDLE
