extends Node3D

@onready var fill: MeshInstance3D = $HealthBarFill
@onready var bg: MeshInstance3D = $HealthBarBG

var camera: Camera3D = null

func _ready() -> void:
	# Get parent unit and connect to health signal
	var unit = get_parent()
	if unit and unit.has_signal("health_changed"):
		unit.health_changed.connect(_on_health_changed)

	# Find camera
	await get_tree().process_frame
	camera = get_viewport().get_camera_3d()

	# Initial health update
	if unit and "current_hp" in unit and "max_hp" in unit:
		_on_health_changed(unit.current_hp, unit.max_hp)

func _process(_delta: float) -> void:
	# Billboard effect - always face camera
	if camera:
		look_at(camera.global_position, Vector3.UP)

func _on_health_changed(current: int, max_val: int) -> void:
	if not fill:
		return

	var health_ratio: float = float(current) / float(max_val) if max_val > 0 else 0.0
	# Update fill scale on X axis to show health percentage
	fill.scale.x = health_ratio * 0.95

	# Change color based on health
	var mat: StandardMaterial3D = fill.get_surface_override_material(0)
	if mat:
		if health_ratio > 0.6:
			mat.albedo_color = Color(0.2, 1.0, 0.2, 1.0)  # Green
		elif health_ratio > 0.3:
			mat.albedo_color = Color(1.0, 0.8, 0.0, 1.0)  # Yellow
		else:
			mat.albedo_color = Color(1.0, 0.2, 0.2, 1.0)  # Red
