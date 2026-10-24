class_name RTSCameraController
extends Node3D

@export var move_speed: float = 30.0
@export var edge_scroll_enabled: bool = false
@export var edge_margin: float = 20.0
@export var zoom_speed: float = 5.0
@export var min_zoom: float = 10.0
@export var max_zoom: float = 60.0

@export var map_bounds_min: Vector2 = Vector2(-100.0, -100.0)
@export var map_bounds_max: Vector2 = Vector2(100.0, 100.0)

var _target_zoom: float = 20.0
@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	if not camera:
		camera = $Camera3D if has_node("Camera3D") else null
	if not camera:
		camera = Camera3D.new()
		add_child(camera)
	camera.transform.origin = Vector3(0.0, 20.0, 14.0)
	camera.rotation_degrees = Vector3(-55.0, 0.0, 0.0)
	camera.make_current()
	_target_zoom = camera.position.y

func _process(delta: float) -> void:
	_handle_movement(delta)
	_handle_zoom(delta)

func _handle_movement(delta: float) -> void:
	var move_dir := Vector3.ZERO
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		move_dir.x += 1.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		move_dir.x -= 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		move_dir.z += 1.0
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		move_dir.z -= 1.0

	var viewport := get_viewport()
	if edge_scroll_enabled and viewport and DisplayServer.window_is_focused() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		var mouse_pos := viewport.get_mouse_position()
		var v_size := viewport.get_visible_rect().size
		if mouse_pos.x > 0.0 and mouse_pos.x < v_size.x and mouse_pos.y > 0.0 and mouse_pos.y < v_size.y:
			if mouse_pos.x <= edge_margin:
				move_dir.x -= 1.0
			elif mouse_pos.x >= v_size.x - edge_margin:
				move_dir.x += 1.0
			if mouse_pos.y <= edge_margin:
				move_dir.z -= 1.0
			elif mouse_pos.y >= v_size.y - edge_margin:
				move_dir.z += 1.0

	if move_dir.length_squared() > 0.0:
		move_dir = move_dir.normalized()
		global_position += move_dir * move_speed * delta
		global_position.x = clampf(global_position.x, map_bounds_min.x, map_bounds_max.x)
		global_position.z = clampf(global_position.z, map_bounds_min.y, map_bounds_max.y)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.is_pressed():
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_target_zoom = clampf(_target_zoom - zoom_speed, min_zoom, max_zoom)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_target_zoom = clampf(_target_zoom + zoom_speed, min_zoom, max_zoom)

func _handle_zoom(delta: float) -> void:
	if camera:
		var current_y := camera.position.y
		var new_y := lerpf(current_y, _target_zoom, delta * 8.0)
		camera.position.y = new_y
		camera.position.z = new_y * 0.7
