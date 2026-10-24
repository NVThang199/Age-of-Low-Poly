extends Control
## Vẽ khung hình chữ nhật bôi chọn quân (Selection Box)

var selection_system: SelectionSystem = null

const BOX_FILL_COLOR: Color = Color(0.2, 0.65, 1.0, 0.25)
const BOX_BORDER_COLOR: Color = Color(0.4, 0.85, 1.0, 1.0)
const BORDER_WIDTH: float = 2.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	await get_tree().process_frame
	selection_system = get_tree().root.get_node_or_null("Main/SelectionSystem")

func _process(_delta: float) -> void:
	if not selection_system:
		selection_system = get_tree().root.get_node_or_null("Main/SelectionSystem")
	queue_redraw()

func _draw() -> void:
	if not selection_system or not selection_system.is_dragging:
		return

	var start: Vector2 = selection_system.drag_start
	var end: Vector2 = selection_system.drag_end
	var rect_size: Vector2 = end - start

	if abs(rect_size.x) < 3.0 and abs(rect_size.y) < 3.0:
		return

	var top_left: Vector2 = Vector2(minf(start.x, end.x), minf(start.y, end.y))
	var box_rect_size: Vector2 = rect_size.abs()
	var rect: Rect2 = Rect2(top_left, box_rect_size)

	# Vẽ ruột bán trong suốt
	draw_rect(rect, BOX_FILL_COLOR, true)
	# Vẽ viền
	draw_rect(rect, BOX_BORDER_COLOR, false, BORDER_WIDTH)
