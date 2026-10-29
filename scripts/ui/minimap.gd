# Fact 1: Called by scenes/ui/hud.tscn
# Fact 2: Verified minimap structure via Grep in scripts/ui/minimap.gd
# Fact 3: In-memory only; connects to FogOfWar singleton
# Fact 4: User request: "ok nếu cần dùng animation thì dùng trong folder C:\Users\nguye\Godot_v4.7.2-stable_win64.exe\git\Age-of-Low-Poly\assets\animations nếu không có thì tự làm cho tôi dùng blender mcp và godot mcp"

extends SubViewportContainer

@onready var viewport: SubViewport = $SubViewport
var minimap_camera: Camera3D = null
var _fog_rect: TextureRect = null

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

	# Overlay sương mù chiến trận trên Minimap
	_fog_rect = TextureRect.new()
	_fog_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fog_rect.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_fog_rect)

func _process(_delta: float) -> void:
	var fow = get_node_or_null("/root/FogOfWar")
	if _fog_rect and fow and _fog_rect.texture == null:
		_fog_rect.texture = fow.get_fog_texture()

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
