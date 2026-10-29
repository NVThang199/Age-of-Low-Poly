# Fact 1: Attached to scenes/core/main.tscn root node (Main)
# Fact 2: Verified no existing main_game.gd via Glob in scripts/core/
# Fact 3: Node3D script orchestrating RandomMapGenerator from GameManager settings, positioning Camera, configuring FogOfWar, and instantiating DevTool
# Fact 4: User verbatim instruction: "hiện tại map vẫn chưa đen toàn bộ cũng như bạn làm cho tôi công cụ devtool để tôi có thể spawn mọi thứ ra dễ dàng và tôi chưa hề thấy chọn maptype hay có cho phép đen bản đồ hay là sáng toàn bản đồ hoặc chọn loại map medium, large, gigantic bạn xem để chọn các loại map bạn bảo thì chọn ở đâu tôi muốn ở bên ngoài lobby là phải có rồi"

class_name MainGame
extends Node3D

## MainGame
## Điều phối trận đấu RTS:
## - Đọc cấu hình từ GameManager (MapType, MapSize, MapVisibility, StartingAge, StartingResources).
## - Khởi tạo RandomMapGenerator sinh địa hình và phân bổ tài nguyên chuẩn AoE 1.
## - Cấu hình FogOfWar theo kích thước bản đồ và chế độ hiển thị (Đen toàn bộ hoặc Sáng bản đồ).
## - Định vị Camera khởi đầu ngay tại Town Center của người chơi.
## - Tích hợp DevTool cho phép spawn mọi thứ tức thì và dùng cheats.

const RandomMapGeneratorScript = preload("res://scripts/systems/random_map_generator.gd")
const DevToolScene = preload("res://scenes/ui/dev_tool.tscn")

@onready var camera_controller: Node3D = $CameraController
@onready var canvas_layer: CanvasLayer = $CanvasLayer

var map_generator: RandomMapGenerator = null
var dev_tool_instance: DevTool = null

func _ready() -> void:
	_cleanup_static_placeholders()
	_initialize_procedural_map()
	_setup_fog_and_camera()
	_setup_dev_tool()

## Dọn dẹp các node mẫu tĩnh từ scene dev cũ để nhường chỗ cho bản đồ RMS sinh tự động
func _cleanup_static_placeholders() -> void:
	var placeholders := [
		"Ground", "TownCenter", "Villager1", "Villager2", "Villager3",
		"Tree1", "Tree2", "Tree3", "BerryBush1", "BerryBush2", "BerryBush3",
		"GoldMine1", "GoldMine2", "StoneMine1", "StoneMine2",
		"Barracks", "MyArcher", "House"
	]
	for p_name in placeholders:
		var n := get_node_or_null(p_name)
		if n and is_instance_valid(n):
			remove_child(n)
			n.queue_free()

## Sinh thế giới ngẫu nhiên theo cấu hình đã chọn tại Lobby
func _initialize_procedural_map() -> void:
	var gm := get_node_or_null("/root/GameManager")
	var m_type: int = gm.selected_map_type if gm else 4 # Highland
	var m_size: int = gm.selected_map_size if gm else 2 # Medium
	var p_count: int = gm.selected_player_count if gm else 2
	var m_seed: int = gm.selected_map_seed if (gm and gm.selected_map_seed != 0) else randi()

	map_generator = RandomMapGeneratorScript.new()
	map_generator.name = "RandomMapGenerator"
	map_generator.map_type = m_type as RandomMapGenerator.MapType
	map_generator.map_size = m_size as RandomMapGenerator.MapSize
	map_generator.num_players = p_count
	map_generator.map_seed = m_seed

	add_child(map_generator)
	map_generator.generate_map()

## Cấu hình Sương mù & Định vị Camera
func _setup_fog_and_camera() -> void:
	var gm := get_node_or_null("/root/GameManager")
	var vis_mode: int = gm.selected_map_visibility if gm else 0
	var fow := get_node_or_null("/root/FogOfWar")

	if fow and map_generator:
		var dim := map_generator.get_map_dimension()
		fow.setup_fog_map(dim, vis_mode)

	# Đặt camera tại vị trí Town Center của người chơi
	if map_generator and not map_generator.player_spawn_positions.is_empty():
		var p0: Vector3 = map_generator.player_spawn_positions[0]
		if camera_controller:
			camera_controller.position = Vector3(p0.x, 0.0, p0.z)

## Tích hợp DevTool & Nút kích hoạt nhanh trên màn hình
func _setup_dev_tool() -> void:
	if not canvas_layer:
		return

	dev_tool_instance = DevToolScene.instantiate() as DevTool
	canvas_layer.add_child(dev_tool_instance)

	# Thêm nút bấm mở DevTool ở góc trên bên phải thanh trạng thái
	var dev_toggle_btn := Button.new()
	dev_toggle_btn.name = "DevToolQuickBtn"
	dev_toggle_btn.text = "🛠 DEVTOOL (F10)"
	dev_toggle_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dev_toggle_btn.offset_left = -160.0
	dev_toggle_btn.offset_top = 4.0
	dev_toggle_btn.offset_right = -10.0
	dev_toggle_btn.offset_bottom = 28.0
	dev_toggle_btn.add_theme_font_size_override("font_size", 11)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.12, 0.1, 0.08, 0.85)
	btn_style.border_color = Color(0.85, 0.72, 0.35, 1.0)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(3)
	dev_toggle_btn.add_theme_stylebox_override("normal", btn_style)

	dev_toggle_btn.pressed.connect(func():
		if dev_tool_instance:
			dev_tool_instance.toggle_dev_tool()
	)

	canvas_layer.add_child(dev_toggle_btn)
