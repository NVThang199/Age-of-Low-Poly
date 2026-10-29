# Fact 1: Called by scripts/entities/base_unit.gd:503, scripts/entities/villager.gd:286, scripts/systems/command_manager.gd:98
# Fact 2: Verified no existing spatial grid via Glob in scripts/systems/
# Fact 3: In-memory only; no external data files read or written
# Fact 4: User request: "ok nếu cần dùng animation thì dùng trong folder C:\Users\nguye\Godot_v4.7.2-stable_win64.exe\git\Age-of-Low-Poly\assets\animations nếu không có thì tự làm cho tôi dùng blender mcp và godot mcp"

extends Node

## SpatialGrid
## Hệ thống phân vùng không gian 2D Grid Bucket cho AOE RTS.
## Tối ưu hóa truy vấn bán kính từ O(N) xuống O(1) cục bộ.

const CELL_SIZE: float = 16.0

# Singleton instance
var instance: Node = null

# Map: Vector2i -> Array[Node3D]
var _cells: Dictionary = {}
# Map: Node3D -> Vector2i (cache vị trí ô hiện tại của entity)
var _entity_cells: Dictionary = {}

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null
	_cells.clear()
	_entity_cells.clear()

func get_instance() -> Node:
	return instance

func pos_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(pos.x / CELL_SIZE)), int(floor(pos.z / CELL_SIZE)))

func register_entity(entity: Node3D) -> void:
	if not is_instance_valid(entity):
		return
	var cell := pos_to_cell(entity.global_position)
	_add_to_cell(entity, cell)
	_entity_cells[entity] = cell

func unregister_entity(entity: Node3D) -> void:
	if not entity in _entity_cells:
		return
	var cell: Vector2i = _entity_cells[entity]
	_remove_from_cell(entity, cell)
	_entity_cells.erase(entity)

func update_entity(entity: Node3D) -> void:
	if not is_instance_valid(entity):
		unregister_entity(entity)
		return
	var new_cell := pos_to_cell(entity.global_position)
	if not _entity_cells.has(entity):
		_add_to_cell(entity, new_cell)
		_entity_cells[entity] = new_cell
		return

	var old_cell: Vector2i = _entity_cells[entity]
	if old_cell != new_cell:
		_remove_from_cell(entity, old_cell)
		_add_to_cell(entity, new_cell)
		_entity_cells[entity] = new_cell

func _add_to_cell(entity: Node3D, cell: Vector2i) -> void:
	if not _cells.has(cell):
		_cells[cell] = []
	var arr: Array = _cells[cell]
	if not arr.has(entity):
		arr.append(entity)

func _remove_from_cell(entity: Node3D, cell: Vector2i) -> void:
	if _cells.has(cell):
		var arr: Array = _cells[cell]
		arr.erase(entity)
		if arr.is_empty():
			_cells.erase(cell)

func search_radius(center: Vector3, radius: float, group: String = "") -> Array[Node3D]:
	var results: Array[Node3D] = []
	var min_c := pos_to_cell(center - Vector3(radius, 0.0, radius))
	var max_c := pos_to_cell(center + Vector3(radius, 0.0, radius))
	var r2 := radius * radius

	for cx in range(min_c.x, max_c.x + 1):
		for cz in range(min_c.y, max_c.y + 1):
			var cell := Vector2i(cx, cz)
			if not _cells.has(cell):
				continue
			var list: Array = _cells[cell]
			for item in list:
				if is_instance_valid(item) and item is Node3D:
					if group.is_empty() or item.is_in_group(group):
						var d2 := center.distance_squared_to((item as Node3D).global_position)
						if d2 <= r2:
							results.append(item as Node3D)
	return results
# ponytail: Hash-grid 16m; add quadtree when unit count exceeds 800.
