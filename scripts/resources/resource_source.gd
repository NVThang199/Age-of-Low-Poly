class_name ResourceSource
extends StaticBody3D

enum ResourceType {
	FOOD = 0,
	WOOD = 1,
	GOLD = 2,
	STONE = 3,
}

@export var resource_type: ResourceType = ResourceType.WOOD
@export var is_meat: bool = false
@export var max_amount: int = 300
@export var current_amount: int = 300

signal resource_depleted(source: ResourceSource)
signal resource_gathered(type: ResourceType, amount: int)

var _pulse_light: OmniLight3D = null
var selection_ring: MeshInstance3D = null
var is_selected: bool = false

func _ready() -> void:
	add_to_group("resources")
	current_amount = max_amount
	_create_selection_ring()

func _get_resource_radius() -> float:
	match resource_type:
		ResourceType.STONE, ResourceType.GOLD:
			return 1.6
		ResourceType.FOOD:
			return 1.15
		_:
			return 0.9

func _create_selection_ring() -> void:
	if selection_ring:
		return
	selection_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	var r := _get_resource_radius()
	torus.inner_radius = r - 0.15
	torus.outer_radius = r
	selection_ring.mesh = torus
	selection_ring.position.y = 0.08

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2, 0.9)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection_ring.material_override = mat
	selection_ring.visible = false
	add_child(selection_ring)

func set_selected(selected: bool) -> void:
	is_selected = selected
	if not selection_ring:
		_create_selection_ring()
	if selection_ring:
		selection_ring.visible = selected

func flash_highlight() -> void:
	if not selection_ring:
		_create_selection_ring()
	if selection_ring:
		selection_ring.visible = true
		var t := create_tween()
		t.tween_property(selection_ring, "scale", Vector3(1.25, 1.0, 1.25), 0.15)
		t.tween_property(selection_ring, "scale", Vector3.ONE, 0.15)
		t.chain().tween_callback(func():
			if is_instance_valid(selection_ring):
				selection_ring.visible = is_selected
		)
	_show_gather_pulse()

func gather(requested_amount: int) -> int:
	if current_amount <= 0:
		return 0

	var harvested := mini(requested_amount, current_amount)
	current_amount -= harvested
	resource_gathered.emit(resource_type, harvested)
	_show_gather_pulse()

	if current_amount <= 0:
		resource_depleted.emit(self)
		queue_free()

	return harvested

func _show_gather_pulse() -> void:
	if not _pulse_light:
		_pulse_light = OmniLight3D.new()
		_pulse_light.light_color = Color(0.2, 1.0, 0.3, 1.0) # Màu xanh lá nổi bật
		_pulse_light.light_energy = 4.0
		_pulse_light.omni_range = 6.0
		_pulse_light.position = Vector3(0.0, 1.4, 0.0)
		add_child(_pulse_light)

	_pulse_light.visible = true
	_pulse_light.light_energy = 4.0
	var tween := create_tween()
	tween.tween_property(_pulse_light, "light_energy", 0.0, 0.25)
	tween.chain().tween_callback(func():
		if is_instance_valid(_pulse_light):
			_pulse_light.visible = false
	)

	# Nháy kích thước mesh để báo hiệu NPC đang khai thác
	for child in get_children():
		if child is MeshInstance3D and child != selection_ring:
			var m := child as MeshInstance3D
			var mt := m.create_tween()
			m.scale = Vector3(1.08, 1.08, 1.08)
			mt.tween_property(m, "scale", Vector3.ONE, 0.2)
