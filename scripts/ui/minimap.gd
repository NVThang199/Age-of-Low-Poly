extends SubViewportContainer

@onready var viewport: SubViewport = $SubViewport
var minimap_camera: Camera3D = null

func _ready() -> void:
	# Find the minimap camera in the main scene
	await get_tree().process_frame
	minimap_camera = get_tree().root.get_node_or_null("Main/MinimapCamera")

	if minimap_camera and viewport:
		# Reparent camera to viewport
		if minimap_camera.get_parent():
			minimap_camera.reparent(viewport)
		else:
			viewport.add_child(minimap_camera)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		var click_pos: Vector2 = mb.position
		var rect_size: Vector2 = size
		var world_x: float = (click_pos.x / rect_size.x - 0.5) * 120.0
		var world_z: float = (click_pos.y / rect_size.y - 0.5) * 120.0

		if event.button_index == MOUSE_BUTTON_LEFT:
			var cam_ctrl := get_tree().root.get_node_or_null("Main/CameraController")
			if cam_ctrl:
				cam_ctrl.global_position.x = world_x
				cam_ctrl.global_position.z = world_z
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var cmd_mgr := get_tree().root.get_node_or_null("Main/CommandManager")
			if cmd_mgr and cmd_mgr.has_method("_execute_move"):
				cmd_mgr._execute_move(Vector3(world_x, 0.0, world_z))
			accept_event()
