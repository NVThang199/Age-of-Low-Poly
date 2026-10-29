class_name SelectionSystem
extends Node3D

signal selection_changed(selected_units: Array)

var selected_units: Array = []
var is_dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
var drag_end: Vector2 = Vector2.ZERO

@onready var camera: Camera3D = get_viewport().get_camera_3d()

func _ready() -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	var hovered_control := get_viewport().gui_get_hovered_control()
	if hovered_control and hovered_control.is_visible_in_tree() and hovered_control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		is_dragging = false
		return
	if not camera:
		camera = get_viewport().get_camera_3d()
	if not camera:
		return

	var placer = get_node_or_null("../BuildingPlacer")
	if placer and "is_placing" in placer and placer.is_placing:
		is_dragging = false
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.is_pressed():
				is_dragging = true
				drag_start = mb.position
				drag_end = mb.position
			else:
				if is_dragging:
					is_dragging = false
					drag_end = mb.position
					_finish_selection()
	elif event is InputEventMouseMotion and is_dragging:
		var mm := event as InputEventMouseMotion
		drag_end = mm.position

func _finish_selection() -> void:
	var drag_box_size := (drag_end - drag_start).abs()
	if drag_box_size.x < 4.0 and drag_box_size.y < 4.0:
		_single_select(drag_start)
	else:
		_box_select(drag_start, drag_end)

func _single_select(screen_pos: Vector2) -> void:
	_clear_selection()
	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_end := ray_origin + camera.project_ray_normal(screen_pos) * 1000.0
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var hit := space_state.intersect_ray(query)

	if hit.has("collider"):
		var collider: Node = hit["collider"]
		if collider.is_in_group("units"):
			_select_unit(collider)
		elif collider.is_in_group("buildings"):
			_select_building(collider)
		elif collider.is_in_group("resources"):
			_select_resource(collider)
		elif collider.is_in_group("animals"):
			_select_animal(collider)
	selection_changed.emit(selected_units)

func _select_resource(res: Node) -> void:
	selected_units.append(res)
	if res.has_method("set_selected"):
		res.set_selected(true)
	if res.has_method("flash_highlight"):
		res.flash_highlight()

func _select_animal(animal: Node) -> void:
	selected_units.append(animal)
	if animal.has_method("set_selected"):
		animal.set_selected(true)
	if animal.has_method("flash_highlight"):
		animal.flash_highlight()

func _select_building(b: Node) -> void:
	selected_units.append(b)
	if b.has_method("set_selected"):
		b.set_selected(true)
	if b.has_method("flash_highlight"):
		b.flash_highlight()

func _box_select(start_pos: Vector2, end_pos: Vector2) -> void:
	_clear_selection()
	var top_left := Vector2(minf(start_pos.x, end_pos.x), minf(start_pos.y, end_pos.y))
	var bottom_right := Vector2(maxf(start_pos.x, end_pos.x), maxf(start_pos.y, end_pos.y))
	var rect := Rect2(top_left, bottom_right - top_left)

	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var units := get_tree().get_nodes_in_group("units")
	for unit in units:
		if unit is Node3D and is_instance_valid(unit):
			var unit_peer: int = unit.owner_peer_id if "owner_peer_id" in unit else 1
			if multiplayer.has_multiplayer_peer() and unit_peer != my_id:
				continue
			var screen_coord := camera.unproject_position((unit as Node3D).global_position)
			if rect.has_point(screen_coord):
				_select_unit(unit)
	selection_changed.emit(selected_units)

func _select_unit(unit: Node) -> void:
	selected_units.append(unit)
	if unit.has_method("set_selected"):
		unit.set_selected(true)

func _clear_selection() -> void:
	for unit in selected_units:
		if is_instance_valid(unit) and unit.has_method("set_selected"):
			unit.set_selected(false)
	selected_units.clear()
