# Fact 1: Called by scripts/ui/minimap.gd, scripts/entities/base_unit.gd, and scripts/systems/fog_of_war.gd
# Fact 2: Verified no existing fog of war via Glob in scripts/systems/
# Fact 3: In-memory only; no external data files read or written
# Fact 4: User request: "ok nếu cần dùng animation thì dùng trong folder C:\Users\nguye\Godot_v4.7.2-stable_win64.exe\git\Age-of-Low-Poly\assets\animations nếu không có thì tự làm cho tôi dùng blender mcp và godot mcp"

extends Node

## FogOfWar
## Hệ thống Sương Mù Chiến Trận 3 Trạng Thái theo chuẩn Age of Empires 1.
## - UNEXPLORED (Đen kịt): Chưa từng nhìn thấy. Địa hình, tài nguyên và quân thù bị ẩn hoàn toàn.
## - EXPLORED (Tối mờ): Đã từng khám phá nhưng hiện không có quân/nhà canh gác. Địa hình hiện rõ nhưng quân thù bị tàng hình.
## - VISIBLE (Sáng tỏ): Đang trong tầm nhìn trực tiếp (Line of Sight) của quân hoặc công trình đồng minh.

enum FogState {
	UNEXPLORED = 0,
	EXPLORED = 1,
	VISIBLE = 2
}

enum VisibilityMode {
	NORMAL_FOG = 0,   # Sương mù đen chuẩn AoE 1
	EXPLORED = 1,     # Đã mở toàn bộ địa hình và tài nguyên
	ALL_VISIBLE = 2   # Sáng toàn bộ bản đồ (Marco Polo)
}

const GRID_RES: int = 128
var map_size: float = 180.0
var half_size: float = 90.0
var cell_size: float = 180.0 / float(GRID_RES)
var visibility_mode: int = VisibilityMode.NORMAL_FOG

var instance: Node = null

# Mảng lưu trạng thái sương mù 128x128
var _grid: PackedByteArray = PackedByteArray()
var _fog_image: Image = null
var _fog_texture: ImageTexture = null

var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.2 # 5Hz tick để tiết kiệm CPU

# Mesh phủ sương mù trên toàn bản đồ và viền đen vũ trụ (outer void)
var _fog_mesh_instance: MeshInstance3D = null
var _void_skirt_nodes: Array[Node] = []

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _ready() -> void:
	_grid.resize(GRID_RES * GRID_RES)
	_grid.fill(FogState.UNEXPLORED)

	_fog_image = Image.create(GRID_RES, GRID_RES, false, Image.FORMAT_RGBA8)
	_fog_image.fill(Color(0.0, 0.0, 0.0, 1.0))
	_fog_texture = ImageTexture.create_from_image(_fog_image)

	_create_world_overlay()
	_create_void_borders()

## Thiết lập kích thước map và chế độ hiển thị từ RandomMapGenerator hoặc Lobby
func setup_fog_map(dim: float, mode: int = VisibilityMode.NORMAL_FOG) -> void:
	map_size = dim
	half_size = dim * 0.5
	cell_size = map_size / float(GRID_RES)
	visibility_mode = mode

	if _fog_mesh_instance and _fog_mesh_instance.mesh is PlaneMesh:
		(_fog_mesh_instance.mesh as PlaneMesh).size = Vector2(map_size, map_size)

	_rebuild_void_borders()

	if visibility_mode == VisibilityMode.ALL_VISIBLE:
		_grid.fill(FogState.VISIBLE)
	elif visibility_mode == VisibilityMode.EXPLORED:
		_grid.fill(FogState.EXPLORED)
	else:
		_grid.fill(FogState.UNEXPLORED)

	_refresh_texture()

func _create_world_overlay() -> void:
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(map_size, map_size)

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _fog_texture
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_fog_mesh_instance = MeshInstance3D.new()
	_fog_mesh_instance.name = "FogOverlayMesh"
	_fog_mesh_instance.mesh = plane_mesh
	_fog_mesh_instance.material_override = mat
	add_child(_fog_mesh_instance)
	_fog_mesh_instance.position = Vector3(0.0, 0.15, 0.0) # Đặt ngay trên mặt đất

## Sinh viền đen bao quanh bên ngoài bản đồ (Pitch Black Void) triệt tiêu hoàn toàn cỏ thừa
func _create_void_borders() -> void:
	_rebuild_void_borders()

func _rebuild_void_borders() -> void:
	for n in _void_skirt_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_void_skirt_nodes.clear()

	var black_mat := StandardMaterial3D.new()
	black_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black_mat.albedo_color = Color(0.0, 0.0, 0.0, 1.0) # Đen tuyệt đối

	var border_thickness: float = 600.0
	var total_span: float = map_size + border_thickness * 2.0

	# 4 tấm chắn đen bao quanh 4 phía Bắc, Nam, Tây, Đông
	var specs: Array = [
		{"pos": Vector3(0.0, 0.16, -half_size - border_thickness * 0.5), "size": Vector2(total_span, border_thickness)},
		{"pos": Vector3(0.0, 0.16, half_size + border_thickness * 0.5), "size": Vector2(total_span, border_thickness)},
		{"pos": Vector3(-half_size - border_thickness * 0.5, 0.16, 0.0), "size": Vector2(border_thickness, map_size)},
		{"pos": Vector3(half_size + border_thickness * 0.5, 0.16, 0.0), "size": Vector2(border_thickness, map_size)},
	]

	for sp in specs:
		var skirt := MeshInstance3D.new()
		skirt.name = "VoidBorder"
		var pm := PlaneMesh.new()
		pm.size = sp["size"]
		skirt.mesh = pm
		skirt.material_override = black_mat
		add_child(skirt)
		skirt.position = sp["pos"]
		_void_skirt_nodes.append(skirt)

func get_fog_texture() -> ImageTexture:
	return _fog_texture

func world_to_grid(world_pos: Vector3) -> Vector2i:
	var gx := int(clampf((world_pos.x + half_size) / cell_size, 0.0, float(GRID_RES - 1)))
	var gz := int(clampf((world_pos.z + half_size) / cell_size, 0.0, float(GRID_RES - 1)))
	return Vector2i(gx, gz)

func is_pos_visible(world_pos: Vector3) -> bool:
	if visibility_mode == VisibilityMode.ALL_VISIBLE:
		return true
	var g := world_to_grid(world_pos)
	var idx := g.y * GRID_RES + g.x
	return _grid[idx] == FogState.VISIBLE

func is_pos_explored(world_pos: Vector3) -> bool:
	if visibility_mode == VisibilityMode.ALL_VISIBLE or visibility_mode == VisibilityMode.EXPLORED:
		return true
	var g := world_to_grid(world_pos)
	var idx := g.y * GRID_RES + g.x
	return _grid[idx] != FogState.UNEXPLORED

## Chức năng Cheat / DevTool
func toggle_all_visible() -> void:
	if visibility_mode == VisibilityMode.ALL_VISIBLE:
		visibility_mode = VisibilityMode.NORMAL_FOG
		_grid.fill(FogState.UNEXPLORED)
	else:
		visibility_mode = VisibilityMode.ALL_VISIBLE
		_grid.fill(FogState.VISIBLE)
	_refresh_texture()

func set_all_explored() -> void:
	visibility_mode = VisibilityMode.EXPLORED
	for i in range(_grid.size()):
		if _grid[i] == FogState.UNEXPLORED:
			_grid[i] = FogState.EXPLORED
	_refresh_texture()

func reset_to_black() -> void:
	visibility_mode = VisibilityMode.NORMAL_FOG
	_grid.fill(FogState.UNEXPLORED)
	_refresh_texture()

func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer < UPDATE_INTERVAL:
		return
	_update_timer = 0.0

	_update_fog_grid()

func _update_fog_grid() -> void:
	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1

	if visibility_mode == VisibilityMode.ALL_VISIBLE:
		_grid.fill(FogState.VISIBLE)
		_apply_visibility_to_entities(my_id)
		_refresh_texture()
		return

	# Bước 1: Chuyển các ô đang VISIBLE về EXPLORED (hoặc duy trì EXPLORED nếu ở chế độ EXPLORED)
	for i in range(_grid.size()):
		if _grid[i] == FogState.VISIBLE:
			_grid[i] = FogState.EXPLORED
		elif visibility_mode == VisibilityMode.EXPLORED and _grid[i] == FogState.UNEXPLORED:
			_grid[i] = FogState.EXPLORED

	# Bước 2: Quét tầm nhìn của tất cả đơn vị và công trình đồng minh
	var friendly_entities: Array[Node3D] = []
	for u in get_tree().get_nodes_in_group("units"):
		if u is BaseUnit and is_instance_valid(u) and (u.owner_peer_id == my_id or my_id == 1):
			if u.state != BaseUnit.UnitState.DEAD:
				friendly_entities.append(u)

	for b in get_tree().get_nodes_in_group("buildings"):
		if b is BaseBuilding and is_instance_valid(b) and (b.owner_peer_id == my_id or my_id == 1):
			friendly_entities.append(b)

	for ent in friendly_entities:
		var sight_radius: float = 6.0
		if ent is BaseUnit:
			match ent.unit_type:
				BaseUnit.UnitType.ARCHER: sight_radius = 9.0
				BaseUnit.UnitType.INFANTRY: sight_radius = 5.0
				BaseUnit.UnitType.CAVALRY: sight_radius = 8.0
				BaseUnit.UnitType.PRIEST: sight_radius = 10.0
				BaseUnit.UnitType.SIEGE: sight_radius = 11.0
				_: sight_radius = 6.0
		elif ent is BaseBuilding:
			match ent.building_type:
				BaseBuilding.BuildingType.TOWN_CENTER: sight_radius = 12.0
				BaseBuilding.BuildingType.WATCH_TOWER: sight_radius = 14.0
				_: sight_radius = 6.0

		_reveal_circle(ent.global_position, sight_radius)

	# Bước 3: Cập nhật hiển thị ẩn/hiện của quân thù và tài nguyên
	_apply_visibility_to_entities(my_id)

	# Bước 4: Cập nhật Texture sương mù
	_refresh_texture()

func _reveal_circle(center: Vector3, radius: float) -> void:
	var g_center := world_to_grid(center)
	var cell_r := int(ceilf(radius / cell_size))
	var r2 := (radius / cell_size) * (radius / cell_size)

	var min_x := maxi(0, g_center.x - cell_r)
	var max_x := mini(GRID_RES - 1, g_center.x + cell_r)
	var min_z := maxi(0, g_center.y - cell_r)
	var max_z := mini(GRID_RES - 1, g_center.y + cell_r)

	for z in range(min_z, max_z + 1):
		var dz: float = float(z - g_center.y)
		var dz2 := dz * dz
		var row_offset := z * GRID_RES
		for x in range(min_x, max_x + 1):
			var dx: float = float(x - g_center.x)
			if dx * dx + dz2 <= r2:
				_grid[row_offset + x] = FogState.VISIBLE

func _apply_visibility_to_entities(my_id: int) -> void:
	# Quân địch: Chỉ nhìn thấy khi ô ở trạng thái VISIBLE
	for u in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u) or not (u is BaseUnit):
			continue
		var bu := u as BaseUnit
		if bu.owner_peer_id != my_id and my_id != 1:
			var vis := is_pos_visible(bu.global_position)
			bu.visible = vis
		else:
			bu.visible = true

	# Công trình địch: Hiện khi đã được EXPLORED
	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b) or not (b is BaseBuilding):
			continue
		var bb := b as BaseBuilding
		if bb.owner_peer_id != my_id and my_id != 1:
			var exp := is_pos_explored(bb.global_position)
			bb.visible = exp
		else:
			bb.visible = true

	# Tài nguyên thiên nhiên: Ẩn khi còn ở UNEXPLORED
	for r in get_tree().get_nodes_in_group("resources"):
		if not is_instance_valid(r) or not (r is Node3D):
			continue
		var rn := r as Node3D
		rn.visible = is_pos_explored(rn.global_position)

func _refresh_texture() -> void:
	if not _fog_image or not _fog_texture:
		return

	for y in range(GRID_RES):
		var row := y * GRID_RES
		for x in range(GRID_RES):
			var state: int = _grid[row + x]
			match state:
				FogState.UNEXPLORED:
					_fog_image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 1.0))
				FogState.EXPLORED:
					_fog_image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.55))
				FogState.VISIBLE:
					_fog_image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))

	_fog_texture.update(_fog_image)
# ponytail: CPU pixel blit 128x128; upgrade to compute shader if grid exceeds 512x512.
