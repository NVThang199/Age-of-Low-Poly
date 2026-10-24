# AOE Project - Agent Guidelines

## Kiến Trúc và Quy Chuẩn Cho Agent / AI
1. **Tránh Fix Cứng (No Hardcoding)**:
   - Các thông số hiển thị, offset vũ khí/công cụ phải expose qua `@export` hoặc thông qua các Socket node (`RightHandSocket`, `LeftHandSocket`).
   - Thiết kế scene sao cho developer có thể mở Godot Editor 3D và dùng Gizmo điều chỉnh trực quan mà không cần sửa code.
2. **Quy Tắc Multiplayer An Toàn (Từ PanicParty)**:
   - **Targeting**: Tuyệt đối không dùng `.rpc(...)` broadcast toàn mạng; dùng `rpc_id(target_id, ...)` gửi đích danh tới các peer trong trận.
   - **Handshake Late-join**: Client load xong scene chủ động gửi `request_game_sync.rpc_id(1)` lên Server thay vì tin tưởng 100% Client load cùng thời điểm với Server.
   - **Bảo Vệ RPC Callback**: Kiểm tra đầy đủ 4 điều kiện (`is_inside_tree()`, `multiplayer.multiplayer_peer`, `local_id`, `is_instance_valid(target)`) trước khi truy xuất dữ liệu trong mọi hàm `@rpc`.
   - **Dọn dẹp Node**: Gọi `remove_child(node)` trước `queue_free()` để giữ sạch NodePath đồng bộ mạng.
   - **Chuyển Scene 2 Giai Đoạn**: Freeze traffic → Delay 0.1s xả gói in-flight → Switch scene.
3. **Quy Chuẩn Scene Tree & Input**:
   - Thêm node vào Scene Tree bằng `add_child()` trước khi set toạ độ toàn cục (`global_position`, `global_transform`).
   - Dùng `_unhandled_input` kèm kiểm tra `get_viewport().gui_get_hovered_control() == null` cho các hệ thống raycast 3D để tránh xung đột với GUI Control nodes.
